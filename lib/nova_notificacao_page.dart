import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// IMPORTA a modal nova (arquivo separado)
import 'resumo_notificacao_modal.dart';

class NovaNotificacaoPage extends StatefulWidget {
  final Map<String, dynamic>? notificacao; // <- pode vir preenchida (edição)

  const NovaNotificacaoPage({super.key, this.notificacao});

  @override
  State<NovaNotificacaoPage> createState() => _NovaNotificacaoPageState();
}

class _NovaNotificacaoPageState extends State<NovaNotificacaoPage> {
  final TextEditingController _nomeController = TextEditingController();

  String? tipoIncidente;
  String? localIncidente;
  String? turno;
  List<String> sintomas = [];

  @override
  void initState() {
    super.initState();

    if (widget.notificacao != null) {
      final n = widget.notificacao!;
      _nomeController.text = n["nome"] ?? "";
      tipoIncidente = n["tipoIncidente"];
      localIncidente = n["localIncidente"];
      turno = n["turno"];
      sintomas = List<String>.from(n["sintomas"] ?? []);
    }
  }

  // === MAPAS DE PONTUAÇÃO ===
  final Map<String, int> tipoIncidentePontuacao = {
    "Queda": 2,
    "Erro de Medicação": 3,
    "Falha de Equipamento": 2,
    "Infecção Relacionada à Assistência": 4,
    "Identificação incorreta do paciente": 3,
    "Comunicação incorreta": 2,
    "Fuga / Paciente desaparecido": 4,
    "Suicídio / tentativa": 5,
    "Queimadura": 3,
    "Outros": 1,
  };

  final Map<String, int> localIncidentePontuacao = {
    "Banheiro": 2,
    "Corredor": 1,
    "Leito": 1,
    "Centro Cirúrgico": 4,
    "UTI": 5,
    "Pronto-Socorro": 4,
    "Ambulatório": 2,
    "Refeitório": 1,
    "Sala de Medicação": 3,
    "Recepção": 1,
    "Estacionamento": 1,
    "Outro": 1,
  };

  final Map<String, int> turnoPontuacao = {
    "Manhã (07h-13h)": 1,
    "Tarde (13h-19h)": 1,
    "Noite (19h-01h)": 2,
    "Madrugada (01h-07h)": 3,
  };

  final Map<String, int> sintomasPontuacao = {
    "Near miss": 0,
    "Tontura": 1,
    "Náusea": 1,
    "Dor leve": 1,
    "Dor intensa": 2,
    "Queda com hematoma": 2,
    "Reação alérgica controlada": 2,
    "Fratura": 3,
    "Convulsão": 4,
    "Hemorragia externa": 3,
    "Hemorragia interna": 4,
    "Infecção grave": 4,
    "Parada cardiorrespiratória": 5,
    "Óbito": 1000,
  };

  // === SALVAR RASCUNHO ===
  Future<void> _salvarRascunho() async {
    final prefs = await SharedPreferences.getInstance();
    final rascunhos = prefs.getStringList("draft_notifications") ?? [];

    final notificacao = {
      "nome": _nomeController.text,
      "tipoIncidente": tipoIncidente,
      "localIncidente": localIncidente,
      "turno": turno,
      "sintomas": sintomas,
    };

    if (widget.notificacao != null) {
      rascunhos.removeWhere((e) {
        final data = jsonDecode(e) as Map<String, dynamic>;
        return data["nome"] == widget.notificacao!["nome"];
      });
    }

    rascunhos.add(jsonEncode(notificacao));
    await prefs.setStringList("draft_notifications", rascunhos);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rascunho salvo com sucesso!")),
      );
    }
  }

  // === ENVIAR NOTIFICAÇÃO ===
  Future<void> _enviarNotificacao() async {
    // (Opcional) Validação básica
    final faltando = <String>[];
    if (_nomeController.text.trim().isEmpty) faltando.add("Nome");
    if (tipoIncidente == null) faltando.add("Tipo de Incidente");
    if (localIncidente == null) faltando.add("Local do Incidente");
    if (turno == null) faltando.add("Turno");
    if (faltando.isNotEmpty) {
      final msg = "Preencha: ${faltando.join(", ")}";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final notificacoes = prefs.getStringList("final_notifications") ?? [];

    final resultadoClassificacao = _classificarNotificacao();
    final pontuacao = _pontuacaoAtual;

    final notificacao = {
      "nome": _nomeController.text,
      "tipoIncidente": tipoIncidente,
      "localIncidente": localIncidente,
      "turno": turno,
      "sintomas": sintomas,
      "resultado": resultadoClassificacao,
      "pontuacao": pontuacao,
      "dataHora": DateTime.now().toIso8601String(),
    };

    notificacoes.add(jsonEncode(notificacao));
    await prefs.setStringList("final_notifications", notificacoes);

    if (!mounted) return;

    // ➜ Abre a NOVA MODAL (arquivo separado) com o resumo detalhado
    await showResumoNotificacaoModal(
      context,
      dados: notificacao,
      pontuacao: pontuacao,
      classificacao: resultadoClassificacao,
    );
  }

  // === CLASSIFICAÇÃO ===
  String _classificarNotificacao() {
    final p = _pontuacaoAtual;
    if (p >= 1000) return "Óbito";
    if (p >= 9) return "Grave";
    if (p >= 5) return "Médio";
    if (p >= 2) return "Leve";
    return "Sem dano";
  }

  int get _pontuacaoAtual {
    int pontuacaoTotal = 0;
    if (tipoIncidente != null) {
      pontuacaoTotal += tipoIncidentePontuacao[tipoIncidente] ?? 0;
    }
    if (localIncidente != null) {
      pontuacaoTotal += localIncidentePontuacao[localIncidente] ?? 0;
    }
    if (turno != null) {
      pontuacaoTotal += turnoPontuacao[turno] ?? 0;
    }
    for (var sintoma in sintomas) {
      pontuacaoTotal += sintomasPontuacao[sintoma] ?? 0;
    }
    return pontuacaoTotal;
  }

  Color _badgeColor(String classe) {
    switch (classe) {
      case "Sem dano":
        return Colors.grey.shade600;
      case "Leve":
        return Colors.green.shade600;
      case "Médio":
        return Colors.orange.shade700;
      case "Grave":
        return Colors.red.shade600;
      case "Óbito":
        return Colors.black87;
      default:
        return Colors.blueGrey;
    }
  }

  double _riskProgress(int p) {
    if (p >= 1000) return 1.0;
    // Normaliza numa escala prática 0..10
    final capped = p.clamp(0, 10);
    return capped / 10.0;
  }

  // === UI HELPERS ===

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.lightBlueAccent.withOpacity(0.15),
                child: Icon(icon, color: Colors.lightBlueAccent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ]),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                    fontSize: 13, color: Colors.black.withOpacity(0.6)),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _chipGroupSingle({
    required List<String> options,
    required String? selected,
    required void Function(String) onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((op) {
        final isSelected = selected == op;
        return ChoiceChip(
          label: Text(op),
          selected: isSelected,
          onSelected: (_) => setState(() => onSelect(op)),
          shape: StadiumBorder(
            side: BorderSide(
              color: isSelected
                  ? Colors.lightBlueAccent
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
          selectedColor: Colors.lightBlueAccent,
          backgroundColor: Colors.grey[100],
          labelStyle:
              TextStyle(color: isSelected ? Colors.white : Colors.black87),
          elevation: isSelected ? 2 : 0,
          pressElevation: 2,
        );
      }).toList(),
    );
  }

  Widget _chipGroupMulti({
    required List<String> options,
    required List<String> current,
    required void Function(String, bool) onToggle,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((op) {
        final isSelected = current.contains(op);
        return FilterChip(
          label: Text(op),
          selected: isSelected,
          onSelected: (value) => setState(() => onToggle(op, value)),
          shape: StadiumBorder(
            side: BorderSide(
              color: isSelected
                  ? Colors.lightBlueAccent
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
          selectedColor: Colors.lightBlueAccent,
          backgroundColor: Colors.grey[100],
          labelStyle:
              TextStyle(color: isSelected ? Colors.white : Colors.black87),
          elevation: isSelected ? 2 : 0,
          pressElevation: 2,
        );
      }).toList(),
    );
  }

  Widget _classificacaoPreview() {
    final classe = _classificarNotificacao();
    final color = _badgeColor(classe);
    final p = _pontuacaoAtual;
    final progress = _riskProgress(p);

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(Icons.assessment, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Pré-visualização da Classificação",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  classe,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Pontuação atual: $p",
              style:
                  TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // === BUILD ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.notificacao != null
            ? "Editar Notificação"
            : "Nova Notificação"),
        backgroundColor: Colors.lightBlueAccent,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              icon: Icons.description_outlined,
              title: "Identificação",
              subtitle:
                  "Dê um nome para localizar esta notificação depois (ex.: “Queda no banheiro – Paciente X”).",
              child: TextField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: "Nome da Notificação",
                  hintText: "Ex.: Queda no banheiro – Paciente X",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),

            _sectionCard(
              icon: Icons.report_problem_outlined,
              title: "Tipo de Incidente",
              child: _chipGroupSingle(
                options: tipoIncidentePontuacao.keys.toList(),
                selected: tipoIncidente,
                onSelect: (v) => tipoIncidente = v,
              ),
            ),

            _sectionCard(
              icon: Icons.place_outlined,
              title: "Local do Incidente",
              child: _chipGroupSingle(
                options: localIncidentePontuacao.keys.toList(),
                selected: localIncidente,
                onSelect: (v) => localIncidente = v,
              ),
            ),

            _sectionCard(
              icon: Icons.schedule_outlined,
              title: "Turno",
              child: _chipGroupSingle(
                options: turnoPontuacao.keys.toList(),
                selected: turno,
                onSelect: (v) => turno = v,
              ),
            ),

            _sectionCard(
              icon: Icons.healing_outlined,
              title: "Sintomas",
              subtitle:
                  "Selecione todos os sintomas observados. Isso impacta diretamente a classificação.",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _chipGroupMulti(
                    options: sintomasPontuacao.keys.toList(),
                    current: sintomas,
                    onToggle: (op, value) {
                      if (value) {
                        sintomas.add(op);
                      } else {
                        sintomas.remove(op);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => sintomas.clear());
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text("Limpar sintomas selecionados"),
                    ),
                  ),
                ],
              ),
            ),

            _classificacaoPreview(),
          ],
        ),
      ),

      // Barra fixa de ações
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _salvarRascunho,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text("Salvar Rascunho"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _enviarNotificacao,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text("Enviar Notificação"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF7F9FC),
    );
  }
}