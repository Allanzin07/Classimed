import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// importe a página de edição
import 'nova_notificacao_page.dart'; // ajuste o caminho conforme seu projeto

class MinhasNotificacoesPage extends StatefulWidget {
  const MinhasNotificacoesPage({super.key});

  @override
  State<MinhasNotificacoesPage> createState() => _MinhasNotificacoesPageState();
}

class _MinhasNotificacoesPageState extends State<MinhasNotificacoesPage> {
  List<Map<String, dynamic>> rascunhos = [];
  List<Map<String, dynamic>> finalizadas = [];

  @override
  void initState() {
    super.initState();
    _carregarNotificacoes();
  }

  Future<void> _carregarNotificacoes() async {
    final prefs = await SharedPreferences.getInstance();

    final drafts = prefs.getStringList("draft_notifications") ?? [];
    rascunhos = drafts
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList(growable: true);

    final finals = prefs.getStringList("final_notifications") ?? [];
    finalizadas = finals
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList(growable: true);

    setState(() {});
  }

  Future<void> _apagarNotificacao(int index, bool isRascunho) async {
    final prefs = await SharedPreferences.getInstance();
    if (isRascunho) {
      rascunhos.removeAt(index);
      await prefs.setStringList(
        "draft_notifications",
        rascunhos.map((e) => jsonEncode(e)).toList(),
      );
    } else {
      finalizadas.removeAt(index);
      await prefs.setStringList(
        "final_notifications",
        finalizadas.map((e) => jsonEncode(e)).toList(),
      );
    }
    setState(() {});
  }

  Future<void> _editarRascunho(Map<String, dynamic> notificacao) async {
    // Abre a tela de incidentes com dados preenchidos
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovaNotificacaoPage(notificacao: notificacao),
      ),
    );
    // Ao voltar, recarrega a lista (caso tenha salvo/alterado)
    await _carregarNotificacoes();
  }

  void _verFinalizada(Map<String, dynamic> n) {
    final nome = n["nome"] ?? "Sem nome";
    final tipo = n["tipoIncidente"] ?? "-";
    final local = n["localIncidente"] ?? "-";
    final turno = n["turno"] ?? "-";
    final sintomas = (n["sintomas"] as List?)?.join(", ") ?? "-";
    final result = n["resultado"] ?? "Não classificado";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Detalhes da Notificação"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nome: $nome"),
            Text("Tipo: $tipo"),
            Text("Local: $local"),
            Text("Turno: $turno"),
            Text("Sintomas: $sintomas"),
            const SizedBox(height: 8),
            Text("Classificação: $result",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fechar"),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String titulo,
    List<Map<String, dynamic>> lista, {
    bool mostrarClassificacao = false,
    bool isRascunho = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.lightBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.lightBlueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    "${lista.length}",
                    style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            if (lista.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text("Nenhuma notificação encontrada."),
              ),
            ...lista.asMap().entries.map((entry) {
              final index = entry.key;
              final notificacao = entry.value;

              final nome = notificacao["nome"] ?? "Sem nome";
              final classificacao =
                  notificacao["resultado"] ?? "Não classificado";

              return Dismissible(
                key: ValueKey("${nome}_${index}_${isRascunho ? 'D' : 'F'}"),
                background: Container(
                  color: isRascunho ? Colors.green : Colors.grey,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: isRascunho
                      ? const Row(
                          children: [
                            Icon(Icons.edit, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "Editar",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                secondaryBackground: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.delete, color: Colors.white),
                      SizedBox(width: 8),
                      Text("Apagar",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd && isRascunho) {
                    // Editar rascunho → abre a tela e não remove
                    await _editarRascunho(notificacao);
                    return false;
                  } else if (direction == DismissDirection.endToStart) {
                    // Apagar (pergunta de confirmação)
                    final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Confirmar exclusão"),
                            content: Text(
                                "Deseja realmente apagar “$nome”? Esta ação não pode ser desfeita."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancelar"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  "Apagar",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                    if (ok) {
                      await _apagarNotificacao(index, isRascunho);
                      return true;
                    }
                    return false;
                  }
                  return false;
                },
                child: ListTile(
                  leading: Icon(
                    isRascunho ? Icons.edit_note : Icons.assignment_turned_in,
                    color: Colors.lightBlue,
                  ),
                  title: Text(nome),
                  subtitle: mostrarClassificacao
                      ? Text(
                          "Classificação: $classificacao",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      : const Text("Rascunho em andamento"),
                  onTap: () async {
                    if (isRascunho) {
                      await _editarRascunho(notificacao);
                    } else {
                      _verFinalizada(notificacao);
                    }
                  },
                  trailing: isRascunho
                      ? IconButton(
                          icon: const Icon(Icons.edit, color: Colors.lightBlue),
                          tooltip: "Editar",
                          onPressed: () => _editarRascunho(notificacao),
                        )
                      : null,
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Minhas Notificações"),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: RefreshIndicator(
        onRefresh: _carregarNotificacoes,
        child: ListView(
          children: [
            _buildSection("Rascunhos", rascunhos, isRascunho: true),
            _buildSection("Finalizadas", finalizadas,
                mostrarClassificacao: true, isRascunho: false),
          ],
        ),
      ),
    );
  }
}
