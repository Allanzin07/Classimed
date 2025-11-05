import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'nova_notificacao_page.dart';

class MinhasNotificacoesPage extends StatelessWidget {
  const MinhasNotificacoesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("Faça login para ver suas notificações.")),
      );
    }

    final draftsStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('createdByUid', isEqualTo: uid)
        .where('status', isEqualTo: 'draft')
        .orderBy('createdAt', descending: true)
        .snapshots();

    final finalsStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('createdByUid', isEqualTo: uid)
        .where('status', isEqualTo: 'final')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Minhas Notificações"),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            Future<void>.delayed(const Duration(milliseconds: 250)),
        child: ListView(
          children: [
            _SectionStream(title: "Rascunhos", stream: draftsStream, isDraft: true),
            _SectionStream(title: "Finalizadas", stream: finalsStream, isDraft: false),
          ],
        ),
      ),
    );
  }
}

class _SectionStream extends StatelessWidget {
  const _SectionStream({
    required this.title,
    required this.stream,
    required this.isDraft,
  });

  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool isDraft;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          return _sectionCard(
            context,
            title,
            const [],
            isDraft: isDraft,
            errorText: "Erro ao carregar: ${snap.error}",
          );
        }

        final docs = snap.data?.docs ?? [];
        final items = docs.map((d) => {"id": d.id, ...d.data()}).toList();

        return _sectionCard(context, title, items, isDraft: isDraft);
      },
    );
  }

  Widget _sectionCard(
    BuildContext context,
    String titulo,
    List<Map<String, dynamic>> lista, {
    required bool isDraft,
    String? errorText,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da seção
            Row(
              children: [
                Icon(
                  isDraft ? Icons.note_alt_outlined : Icons.assignment_turned_in_outlined,
                  color: Colors.lightBlueAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.lightBlueAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(errorText, style: const TextStyle(color: Colors.red)),
              ),
            if (lista.isEmpty && errorText == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text("Nenhuma notificação encontrada."),
              ),

            ...lista.map((n) => _ExpandableNotificationCard(
                  notification: n,
                  isDraft: isDraft,
                  onDelete: () async {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(n['id'])
                        .delete();
                  },
                  onEdit: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NovaNotificacaoPage(notificacao: n)),
                    );
                  },
                  onExport: () => _exportarPDFProfissional(context, n),
                )),
          ],
        ),
      ),
    );
  }

  // ---------- Função PDF ----------
  Future<void> _exportarPDFProfissional(
      BuildContext context, Map<String, dynamic> n) async {
    try {
      pw.Font? regular;
      pw.Font? bold;
      try {
        regular = await PdfGoogleFonts.openSansRegular();
        bold = await PdfGoogleFonts.openSansSemiBold();
      } catch (_) {
        regular = null;
        bold = null;
      }

      final pdf = pw.Document();
      final nome = n['nome'] ?? 'Sem nome';
      final resultado = n['resultado'] ?? 'Não classificado';
      final status = n['status'] ?? '-';
      final pageTheme = pw.PageTheme(
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
      );

      pdf.addPage(
        pw.Page(
          pageTheme: pageTheme,
          build: (_) => pw.Center(
            child: pw.Column(
              children: [
                pw.Text("Relatório de Notificação", style: pw.TextStyle(fontSize: 18, font: bold)),
                pw.SizedBox(height: 12),
                pw.Text("Nome: $nome", style: pw.TextStyle(font: regular)),
                pw.Text("Classificação: $resultado", style: pw.TextStyle(font: regular)),
                pw.Text("Status: $status", style: pw.TextStyle(font: regular)),
              ],
            ),
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (format) => pdf.save());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDF gerado com sucesso.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Falha ao gerar PDF: $e")),
        );
      }
    }
  }
}

class _ExpandableNotificationCard extends StatefulWidget {
  const _ExpandableNotificationCard({
    required this.notification,
    required this.isDraft,
    required this.onDelete,
    required this.onEdit,
    required this.onExport,
  });

  final Map<String, dynamic> notification;
  final bool isDraft;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  @override
  State<_ExpandableNotificationCard> createState() =>
      _ExpandableNotificationCardState();
}

class _ExpandableNotificationCardState
    extends State<_ExpandableNotificationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final nome = (n["nome"] ?? "Sem nome").toString();
    final tipo = (n["tipoIncidente"] ?? "-").toString();
    final local = (n["localIncidente"] ?? "-").toString();
    final turno = (n["turno"] ?? "-").toString();
    final sintomas = (n["sintomas"] as List?)?.join(", ") ?? "-";
    final resultado = (n["resultado"] ?? "Não classificado").toString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 400),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.lightBlueAccent.withOpacity(0.1),
                  child: Icon(
                    widget.isDraft ? Icons.edit_note : Icons.assignment_turned_in,
                    color: Colors.lightBlueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        widget.isDraft
                            ? "Rascunho em andamento"
                            : "Classificação: $resultado",
                        style: TextStyle(
                          color: widget.isDraft
                              ? Colors.grey[700]
                              : (resultado == "Grave"
                                  ? Colors.redAccent
                                  : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey[600],
                ),
              ],
            ),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.lightBlueAccent.withOpacity(0.1),
                      child: Icon(
                        widget.isDraft
                            ? Icons.edit_note
                            : Icons.assignment_turned_in,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nome,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            widget.isDraft
                                ? "Rascunho em andamento"
                                : "Classificação: $resultado",
                            style: TextStyle(
                              color: widget.isDraft
                                  ? Colors.grey[700]
                                  : (resultado == "Grave"
                                      ? Colors.redAccent
                                      : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _infoLine("Tipo de incidente", tipo),
                _infoLine("Local", local),
                _infoLine("Turno", turno),
                _infoLine("Sintomas", sintomas),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined,
                          color: Colors.redAccent),
                      label: const Text("Exportar PDF"),
                      onPressed: widget.onExport,
                    ),
                    Row(
                      children: [
                        if (widget.isDraft)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.lightBlue),
                            onPressed: widget.onEdit,
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: widget.onDelete,
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          text: "$label: ",
          style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 13),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.normal,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
