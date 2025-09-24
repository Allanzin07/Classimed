import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

    // Rascunhos
    final drafts = prefs.getStringList("draft_notifications") ?? [];
    rascunhos =
        drafts.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    // Finalizadas
    final finals = prefs.getStringList("final_notifications") ?? [];
    finalizadas =
        finals.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    setState(() {});
  }

  Future<void> _apagarNotificacao(
      int index, bool isRascunho) async {
    final prefs = await SharedPreferences.getInstance();
    if (isRascunho) {
      rascunhos.removeAt(index);
      final lista = rascunhos.map((e) => jsonEncode(e)).toList();
      await prefs.setStringList("draft_notifications", lista);
    } else {
      finalizadas.removeAt(index);
      final lista = finalizadas.map((e) => jsonEncode(e)).toList();
      await prefs.setStringList("final_notifications", lista);
    }
    setState(() {});
  }

  Widget _buildSection(String titulo, List<Map<String, dynamic>> lista,
      {bool mostrarClassificacao = false, bool isRascunho = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.lightBlue,
              ),
            ),
            const Divider(),
            if (lista.isEmpty)
              const Text("Nenhuma notificação encontrada."),
            ...lista.asMap().entries.map((entry) {
              final index = entry.key;
              final notificacao = entry.value;

              final nome = notificacao["nome"] ?? "Sem nome";
              final classificacao =
                  notificacao["resultado"] ?? "Não classificado";

              return Dismissible(
                key: UniqueKey(),
                background: Container(
                  color: Colors.green,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: isRascunho
                      ? const Row(
                          children: [
                            Icon(Icons.edit, color: Colors.white),
                            SizedBox(width: 8),
                            Text("Editar",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
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
                  if (direction == DismissDirection.startToEnd &&
                      isRascunho) {
                    // Editar rascunho
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Função de editar rascunho ainda não implementada")),
                    );
                    return false; // não remove da lista
                  } else if (direction == DismissDirection.endToStart) {
                    // Apagar
                    _apagarNotificacao(index, isRascunho);
                    return true;
                  }
                  return false;
                },
                child: ListTile(
                  leading: Icon(
                    mostrarClassificacao
                        ? Icons.assignment_turned_in
                        : Icons.edit,
                    color: Colors.lightBlue,
                  ),
                  title: Text(nome),
                  subtitle: mostrarClassificacao
                      ? Text("Classificação: $classificacao",
                          style: const TextStyle(fontWeight: FontWeight.bold))
                      : const Text("Rascunho em andamento"),
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

