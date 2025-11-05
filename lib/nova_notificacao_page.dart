import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'resumo_notificacao_modal.dart';

class RiskConfig {
  final Map<String, int> tipo;
  final Map<String, int> local;
  final Map<String, int> turno;
  final Map<String, int> sintomas;
  final Map<String, double> localMult;
  final Map<String, double> turnoMult;
  final int capSintomas;
  final Map<String, int> thresholds;

  const RiskConfig({
    required this.tipo,
    required this.local,
    required this.turno,
    required this.sintomas,
    required this.localMult,
    required this.turnoMult,
    required this.capSintomas,
    required this.thresholds,
  });
}

class ScoreContext {
  final String? tipoIncidente;
  final String? localIncidente;
  final String? turno;
  final List<String> sintomas;

  const ScoreContext({
    required this.tipoIncidente,
    required this.localIncidente,
    required this.turno,
    required this.sintomas,
  });
}

class ScoredResult {
  final int raw;
  final double scaled;
  final String classe;
  const ScoredResult(this.raw, this.scaled, this.classe);
}

class RiskScorer {
  final RiskConfig cfg;
  RiskScorer(this.cfg);

  List<String> _sanitizeSymptoms(List<String> s) {
    final set = s.toSet();
    if (set.contains("Óbito")) return const ["Óbito"];
    if (set.contains("Parada cardiorrespiratória")) set.remove("Near miss");
    return set.toList();
  }

  int _synergyBonus(ScoreContext c) {
    int bonus = 0;
    final s = c.sintomas.toSet();
    if (c.tipoIncidente == "Queda" && s.contains("Fratura")) bonus += 2;
    if (c.tipoIncidente == "Erro de Medicação" &&
        s.contains("Reação alérgica controlada")) bonus += 2;
    if ((c.localIncidente == "UTI" || c.localIncidente == "Centro Cirúrgico") &&
        (s.contains("Hemorragia externa") || s.contains("Hemorragia interna"))) {
      bonus += 2;
    }
    return bonus;
  }

  String _classify(int p) {
    if (p >= (cfg.thresholds["Óbito"] ?? 1000)) return "Óbito";
    if (p >= (cfg.thresholds["Grave"] ?? 9)) return "Grave";
    if (p >= (cfg.thresholds["Médio"] ?? 5)) return "Médio";
    if (p >= (cfg.thresholds["Leve"] ?? 2)) return "Leve";
    return "Sem dano";
  }

  ScoredResult score(ScoreContext ctx0) {
    final ctx = ScoreContext(
      tipoIncidente: ctx0.tipoIncidente,
      localIncidente: ctx0.localIncidente,
      turno: ctx0.turno,
      sintomas: _sanitizeSymptoms(ctx0.sintomas),
    );

    if (ctx.sintomas.contains("Óbito")) return const ScoredResult(1000, 10.0, "Óbito");

    int total = 0;
    total += cfg.tipo[ctx.tipoIncidente] ?? 0;
    total += cfg.local[ctx.localIncidente] ?? 0;
    total += cfg.turno[ctx.turno] ?? 0;

    int sintSum = 0;
    for (final s in ctx.sintomas) {
      sintSum += cfg.sintomas[s] ?? 0;
    }
    sintSum = sintSum.clamp(0, cfg.capSintomas);
    total += sintSum;

    total += _synergyBonus(ctx);

    double mult = 1.0;
    if (ctx.localIncidente != null) mult *= (cfg.localMult[ctx.localIncidente] ?? 1.0);
    if (ctx.turno != null)          mult *= (cfg.turnoMult[ctx.turno] ?? 1.0);
    total = (total * mult).round();

    final scaled = (total >= 1000) ? 10.0 : (total / 10.0).clamp(0.0, 10.0);
    final classe = _classify(total);
    return ScoredResult(total, scaled, classe);
  }
}

class NovaNotificacaoPage extends StatefulWidget {
  /// Se vier com `id`, edita o documento correspondente.
  final Map<String, dynamic>? notificacao;
  const NovaNotificacaoPage({super.key, this.notificacao});

  @override
  State<NovaNotificacaoPage> createState() => _NovaNotificacaoPageState();
}

class _NovaNotificacaoPageState extends State<NovaNotificacaoPage> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _obsController  = TextEditingController();

  String? tipoIncidente;
  String? localIncidente;
  String? turno;
  List<String> sintomas = [];

  late RiskScorer scorer;

  // ---------- Pontuações ----------
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
    "Reação alérgica descontrolada": 4,
    "Fratura": 3,
    "Convulsão": 4,
    "Hemorragia externa": 3,
    "Hemorragia interna": 5,
    "Infecção leve": 2,
    "Infecção grave": 4,
    "Parada cardiorrespiratória": 5,
    "Óbito": 1000,
  };

  @override
  void initState() {
    super.initState();

    if (widget.notificacao != null) {
      final n = widget.notificacao!;
      _nomeController.text = (n["nome"] ?? "").toString();
      _obsController.text  = (n["observacoes"] ?? "").toString();
      tipoIncidente  = n["tipoIncidente"] as String?;
      localIncidente = n["localIncidente"] as String?;
      turno          = n["turno"] as String?;
      final s = n["sintomas"];
      if (s is List) sintomas = List<String>.from(s.map((e) => e.toString()));
    }

    scorer = RiskScorer(RiskConfig(
      tipo: tipoIncidentePontuacao,
      local: localIncidentePontuacao,
      turno: turnoPontuacao,
      sintomas: sintomasPontuacao,
      localMult: const {"UTI": 1.2, "Centro Cirúrgico": 1.2},
      turnoMult: const {"Madrugada (01h-07h)": 1.1},
      capSintomas: 6,
      thresholds: const {"Sem dano": 0, "Leve": 2, "Médio": 5, "Grave": 9, "Óbito": 1000},
    ));
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------
  ScoredResult _scoreAtual() => RiskScorer(scorer.cfg).score(
        ScoreContext(
          tipoIncidente: tipoIncidente,
          localIncidente: localIncidente,
          turno: turno,
          sintomas: sintomas,
        ),
      );

  Color _badgeColor(String classe) {
    switch (classe) {
      case "Sem dano": return Colors.grey.shade600;
      case "Leve":     return Colors.green.shade600;
      case "Médio":    return Colors.orange.shade700;
      case "Grave":    return Colors.red.shade600;
      case "Óbito":    return Colors.black87;
      default:         return Colors.blueGrey;
    }
  }

  // ---------- UI helpers ----------
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ]),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.6))),
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
      spacing: 8, runSpacing: 8,
      children: options.map((op) {
        final isSelected = selected == op;
        return ChoiceChip(
          label: Text(op),
          selected: isSelected,
          onSelected: (_) => setState(() => onSelect(op)),
          shape: StadiumBorder(side: BorderSide(color: isSelected ? Colors.lightBlueAccent : Colors.grey.withOpacity(0.3))),
          selectedColor: Colors.lightBlueAccent,
          backgroundColor: Colors.grey[100],
          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
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
      spacing: 8, runSpacing: 8,
      children: options.map((op) {
        final isSelected = current.contains(op);
        return FilterChip(
          label: Text(op),
          selected: isSelected,
          onSelected: (value) => setState(() => onToggle(op, value)),
          shape: StadiumBorder(side: BorderSide(color: isSelected ? Colors.lightBlueAccent : Colors.grey.withOpacity(0.3))),
          selectedColor: Colors.lightBlueAccent,
          backgroundColor: Colors.grey[100],
          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
          elevation: isSelected ? 2 : 0,
          pressElevation: 2,
        );
      }).toList(),
    );
  }

  Widget _classificacaoPreview() {
    final scored = _scoreAtual();
    final classe = scored.classe;
    final color  = _badgeColor(classe);
    final p      = scored.raw;
    final progress = (scored.scaled / 10.0).clamp(0.0, 1.0);

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
              CircleAvatar(radius: 16, backgroundColor: color.withOpacity(0.12),
                child: Icon(Icons.assessment, color: color, size: 18)),
              const SizedBox(width: 10),
              const Expanded(child: Text("Pré-visualização da Classificação",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                child: Text(classe, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ]), 
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress, minHeight: 10,
                backgroundColor: Colors.grey.shade200, color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text("Pontuação atual: $p",
              style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ---------- Firestore ----------
  Future<void> _salvarRascunho() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Faça login para salvar rascunho.")),
        );
      }
      return;
    }

    final scored = _scoreAtual();
    final data = <String, dynamic>{
      "createdByUid":   user.uid,
      "createdByEmail": user.email,
      "createdByName":  user.displayName,
      "status": "draft",
      "nome": _nomeController.text,
      "observacoes": _obsController.text,
      "tipoIncidente": tipoIncidente,
      "localIncidente": localIncidente,
      "turno": turno,
      "sintomas": sintomas,
      "resultado": scored.classe,
      "pontuacao": scored.raw,
      "dataHora": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    };

    final docId = widget.notificacao?["id"] as String?;
    try {
      if (docId != null && docId.isNotEmpty) {
        // update mantendo createdAt
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(docId)
            .set(data, SetOptions(merge: true));
      } else {
        // novo rascunho com createdAt
        await FirebaseFirestore.instance
            .collection('notifications')
            .add({...data, "createdAt": FieldValue.serverTimestamp()});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rascunho salvo no Firebase.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Falha ao salvar rascunho: $e")),
        );
      }
    }
  }

  Future<void> _enviarNotificacao() async {
    final faltando = <String>[];
    if (_nomeController.text.trim().isEmpty) faltando.add("Nome");
    if (tipoIncidente == null)             faltando.add("Tipo de Incidente");
    if (localIncidente == null)            faltando.add("Local do Incidente");
    if (turno == null)                     faltando.add("Turno");
    if (faltando.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Preencha: ${faltando.join(", ")}")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Faça login para enviar a notificação.")),
        );
      }
      return;
    }

    final scored = _scoreAtual();
    final data = <String, dynamic>{
      "createdByUid":   user.uid,
      "createdByEmail": user.email,
      "createdByName":  user.displayName,
      "status": "final",
      "nome": _nomeController.text,
      "observacoes": _obsController.text,
      "tipoIncidente": tipoIncidente,
      "localIncidente": localIncidente,
      "turno": turno,
      "sintomas": sintomas,
      "resultado": scored.classe,
      "pontuacao": scored.raw,
      "dataHora": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    };

    final docId = widget.notificacao?["id"] as String?;
    try {
      DocumentReference<Map<String, dynamic>> docRef;
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(docId)
            .set(data, SetOptions(merge: true));
        docRef = FirebaseFirestore.instance.collection('notifications').doc(docId);
      } else {
        docRef = await FirebaseFirestore.instance
            .collection('notifications')
            .add({...data, "createdAt": FieldValue.serverTimestamp()});
      }

      final dadosModal = {
        "id": docRef.id,
        "nome": _nomeController.text,
        "observacoes": _obsController.text,
        "tipoIncidente": tipoIncidente,
        "localIncidente": localIncidente,
        "turno": turno,
        "sintomas": sintomas,
        "resultado": scored.classe,
        "pontuacao": scored.raw,
        "dataHora": DateTime.now().toIso8601String(),
      };

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Notificação registrada no Firebase.")),
        );
      }
      if (!mounted) return;
      await showResumoNotificacaoModal(
        context,
        dados: dadosModal,
        pontuacao: scored.raw,
        classificacao: scored.classe,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Falha ao salvar no Firebase: $e")),
        );
      }
    }
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.notificacao != null ? "Editar Notificação" : "Nova Notificação"),
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
              subtitle: "Dê um nome (ex.: “Queda no banheiro – Paciente X”).",
              child: TextField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: "Nome da Notificação",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.white,
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
              subtitle: "Selecione todos os sintomas observados.",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _chipGroupMulti(
                    options: sintomasPontuacao.keys.toList(),
                    current: sintomas,
                    onToggle: (op, value) {
                      setState(() { value ? sintomas.add(op) : sintomas.remove(op); });
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => sintomas.clear()),
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text("Limpar sintomas selecionados"),
                    ),
                  ),
                ],
              ),
            ),
            _sectionCard(
              icon: Icons.notes_outlined,
              title: "Observações adicionais",
              subtitle: "Detalhes relevantes, medidas adotadas, etc.",
              child: TextField(
                controller: _obsController,
                maxLines: 6,
                minLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: "Ex.: dinâmica do evento, equipes, medidas...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.white,
                ),
              ),
            ),
            _classificacaoPreview(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
