// lib/resumo_notificacao_modal.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

Future<void> showResumoNotificacaoModal(
  BuildContext context, {
  required Map<String, dynamic> dados,
  required int pontuacao,
  required String classificacao,
}) async {
  final Color corClasse = _badgeColor(classificacao);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.6,
        maxChildSize: 0.98,
        builder: (context, scrollController) {
          final nome = (dados["nome"] ?? "") as String;
          final tipo = (dados["tipoIncidente"] ?? "-") as String;
          final local = (dados["localIncidente"] ?? "-") as String;
          final turno = (dados["turno"] ?? "-") as String;
          final sintomas =
              (dados["sintomas"] as List?)?.cast<String>() ?? const <String>[];
          final dataHora = _fmtData(dados["dataHora"] as String?);
          final observacoes = (dados["observacoes"] ?? "") as String;

          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          return Padding(
            padding: EdgeInsets.only(
                top: 8, bottom: bottomInset > 0 ? bottomInset : 0),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      const Icon(Icons.fact_check_outlined, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Resumo da Ocorrência",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: corClasse,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          classificacao,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _riskProgress(pontuacao),
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      color: corClasse,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Pontuação total: $pontuacao",
                    style: TextStyle(color: Colors.black.withOpacity(0.6)),
                  ),

                  const SizedBox(height: 18),

                  _grupoCard(
                    titulo: "Identificação",
                    icon: Icons.badge_outlined,
                    children: [
                      _linha("Nome da ocorrência", nome.isEmpty ? "-" : nome),
                      _linha("Data/Hora", dataHora),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _grupoCard(
                    titulo: "Incidente",
                    icon: Icons.local_hospital_outlined,
                    children: [
                      _linha("Tipo de Incidente", tipo),
                      _linha("Local do Incidente", local),
                      _linha("Turno", turno),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _grupoCard(
                    titulo: "Sintomas Selecionados",
                    icon: Icons.healing_outlined,
                    children: [
                      if (sintomas.isEmpty)
                        Text(
                          "Nenhum sintoma selecionado",
                          style:
                              TextStyle(color: Colors.black.withOpacity(0.6)),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: sintomas
                              .map((s) => Chip(
                                    label: Text(s),
                                    backgroundColor: Colors.grey[100],
                                    side: BorderSide(
                                        color: Colors.grey.withOpacity(0.3)),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _grupoCard(
                    titulo: "Observações",
                    icon: Icons.notes_outlined,
                    children: [
                      SelectableText(
                        observacoes.trim().isEmpty
                            ? "Sem observações."
                            : observacoes,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.85),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _grupoCard(
                    titulo: "Grau da Ocorrência",
                    icon: Icons.verified_outlined,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: corClasse,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              classificacao,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Classificação calculada com base nos campos selecionados.",
                              style: TextStyle(
                                  color: Colors.black.withOpacity(0.6)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true)
                                .pushNamedAndRemoveUntil(
                              '/home',
                              (Route<dynamic> route) => false,
                            );
                          },
                          icon: const Icon(Icons.check),
                          label: const Text("Concluir"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlueAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.home_outlined),
                          label: const Text("Voltar"),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // NOVO BOTÃO DE ENVIAR POR E-MAIL (VIA EMAILJS)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () async {
                      final TextEditingController emailController =
                          TextEditingController();

                      final destino = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Enviar resumo por e-mail"),
                          content: TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "E-mail do destinatário",
                              hintText: "exemplo@dominio.com",
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Cancelar"),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(
                                  ctx, emailController.text.trim()),
                              child: const Text("Enviar"),
                            ),
                          ],
                        ),
                      );

                      if (destino == null || destino.isEmpty) return;

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        final remetente =
                            user?.email ?? "desconhecido@classimed.com";

                        final serviceId = "SEU_SERVICE_ID";
                        final templateId = "SEU_TEMPLATE_ID";
                        final publicKey = "SEU_PUBLIC_KEY";

                        final conteudo = '''
Resumo da Ocorrência:

🧾 Nome: ${dados["nome"]}
🏥 Tipo: ${dados["tipoIncidente"]}
📍 Local: ${dados["localIncidente"]}
🕒 Turno: ${dados["turno"]}
⚖️ Classificação: $classificacao
💯 Pontuação: $pontuacao
📅 Data/Hora: ${dados["dataHora"]}
🗒️ Observações: ${dados["observacoes"] ?? "-"}

Enviado automaticamente pelo sistema ClassiMed.
''';

                        final url =
                            Uri.parse("https://api.emailjs.com/api/v1.0/email/send");
                        final response = await http.post(
                          url,
                          headers: {
                            "origin": "http://localhost",
                            "Content-Type": "application/json",
                          },
                          body: json.encode({
                            "service_id": serviceId,
                            "template_id": templateId,
                            "user_id": publicKey,
                            "template_params": {
                              "to_email": destino,
                              "from_email": remetente,
                              "message": conteudo,
                              "subject":
                                  "Resumo da Ocorrência — ${dados["nome"] ?? "Sem nome"}",
                            },
                          }),
                        );

                        if (response.statusCode == 200) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("Resumo enviado com sucesso!")),
                          );
                        } else {
                          throw Exception(
                              "Erro ${response.statusCode}: ${response.body}");
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Erro ao enviar e-mail: $e")),
                        );
                      }
                    },
                    icon: const Icon(Icons.email_outlined),
                    label: const Text("Enviar por e-mail"),
                  ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ----------------- Helpers -----------------

Widget _grupoCard({
  required String titulo,
  required IconData icon,
  required List<Widget> children,
}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.lightBlueAccent.withOpacity(0.15),
              child: Icon(icon, color: Colors.lightBlueAccent, size: 18),
            ),
            const SizedBox(width: 8),
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}

Widget _linha(String rotulo, String valor) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(
            "$rotulo:",
            style: TextStyle(
              color: Colors.black.withOpacity(0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            valor.isEmpty ? "-" : valor,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

String _fmtData(String? iso) {
  if (iso == null) return "-";
  try {
    final dt = DateTime.parse(iso).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "$d/$m/$y $hh:$mm";
  } catch (_) {
    return iso ?? "-";
  }
}

double _riskProgress(int p) {
  if (p >= 1000) return 1.0;
  final capped = p.clamp(0, 10);
  return capped / 10.0;
}

Color _badgeColor(String classe) {
  switch (classe) {
    case "Sem dano":
      return Colors.grey.shade700;
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
