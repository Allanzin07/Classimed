import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

    // Se veio uma notificação, preencher os campos
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

  // === FUNÇÃO DE SALVAR RASCUNHO ===
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

    // Se estou editando, substituo o rascunho original
    if (widget.notificacao != null) {
      // Apagar o antigo
      rascunhos.removeWhere((e) {
        final data = jsonDecode(e) as Map<String, dynamic>;
        return data["nome"] == widget.notificacao!["nome"];
      });
    }

    // Adicionar o novo/atualizado
    rascunhos.add(jsonEncode(notificacao));
    await prefs.setStringList("draft_notifications", rascunhos);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Rascunho salvo com sucesso!")),
    );
  }

  // === FUNÇÃO DE ENVIAR NOTIFICAÇÃO ===
  Future<void> _enviarNotificacao() async {
    final prefs = await SharedPreferences.getInstance();
    final notificacoes = prefs.getStringList("final_notifications") ?? [];

    final resultadoClassificacao = _classificarNotificacao();

    final notificacao = {
      "nome": _nomeController.text,
      "tipoIncidente": tipoIncidente,
      "localIncidente": localIncidente,
      "turno": turno,
      "sintomas": sintomas,
      "resultado": resultadoClassificacao,
    };

    notificacoes.add(jsonEncode(notificacao));
    await prefs.setStringList("final_notifications", notificacoes);

    // Exibir resultado
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Resultado da Análise"),
        content: Text("Classificação: $resultadoClassificacao"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // === FUNÇÃO DE CLASSIFICAÇÃO AUTOMÁTICA ===
  String _classificarNotificacao() {
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

    // Regras de classificação
    if (pontuacaoTotal >= 1000) {
      return "Óbito";
    } else if (pontuacaoTotal >= 9) {
      return "Grave";
    } else if (pontuacaoTotal >= 5) {
      return "Médio";
    } else if (pontuacaoTotal >= 2) {
      return "Leve";
    } else {
      return "Sem dano";
    }
  }

  // === WIDGET DE BOTÕES DE OPÇÃO ===
  Widget _buildOptionButtons(String titulo, List<String> opcoes,
      String? selecionado, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: opcoes.map((opcao) {
            final isSelected = selecionado == opcao;
            return ChoiceChip(
              label: Text(opcao),
              selected: isSelected,
              onSelected: (_) => setState(() => onSelect(opcao)),
              selectedColor: Colors.lightBlue,
              backgroundColor: Colors.grey[200],
              labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // === WIDGET DE BOTÕES MULTIPLOS (SINTOMAS) ===
  Widget _buildMultiSelect(String titulo, List<String> opcoes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: opcoes.map((opcao) {
            final isSelected = sintomas.contains(opcao);
            return FilterChip(
              label: Text(opcao),
              selected: isSelected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    sintomas.add(opcao);
                  } else {
                    sintomas.remove(opcao);
                  }
                });
              },
              selectedColor: Colors.lightBlue,
              backgroundColor: Colors.grey[200],
              labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.notificacao != null
            ? "Editar Notificação"
            : "Nova Notificação"),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome da notificação
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: "Nome da Notificação",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Tipo
            _buildOptionButtons("Tipo de Incidente",
                tipoIncidentePontuacao.keys.toList(), tipoIncidente, (v) => tipoIncidente = v),

            // Local
            _buildOptionButtons("Local do Incidente",
                localIncidentePontuacao.keys.toList(), localIncidente, (v) => localIncidente = v),

            // Turno
            _buildOptionButtons("Turno",
                turnoPontuacao.keys.toList(), turno, (v) => turno = v),

            // Sintomas
            _buildMultiSelect("Sintomas", sintomasPontuacao.keys.toList()),

            const SizedBox(height: 30),

            // Botões
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _salvarRascunho,
                    child: const Text("Salvar Rascunho"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _enviarNotificacao,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlueAccent),
                    child: const Text("Enviar Notificação"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
