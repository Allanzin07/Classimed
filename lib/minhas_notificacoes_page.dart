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
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.lightBlue)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text("${lista.length}",
                    style: const TextStyle(
                        color: Colors.lightBlueAccent, fontWeight: FontWeight.w700)),
              ),
            ]),
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
            ...lista.map((n) {
              final id = n["id"] as String;
              final nome = (n["nome"] ?? "Sem nome").toString();
              final classificacao = (n["resultado"] ?? "Não classificado").toString();

              return Dismissible(
                key: ValueKey(id),
                direction: isDraft
                    ? DismissDirection.horizontal
                    : DismissDirection.endToStart,
                background: Container(
                  color: isDraft ? Colors.green : Colors.grey,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: isDraft
                      ? const Row(children: [
                          Icon(Icons.edit, color: Colors.white),
                          SizedBox(width: 8),
                          Text("Editar",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ])
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
                  if (direction == DismissDirection.startToEnd && isDraft) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NovaNotificacaoPage(notificacao: n),
                      ),
                    );
                    return false;
                  }

                  if (direction == DismissDirection.endToStart) {
                    final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Confirmar exclusão"),
                            content: Text('Apagar “$nome”? Esta ação não pode ser desfeita.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Cancelar")),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Apagar",
                                      style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        ) ??
                        false;

                    if (!ok) return false;
                    try {
                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(id)
                          .delete();
                      return true;
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao apagar: $e')),
                        );
                      }
                      return false;
                    }
                  }
                  return false;
                },
                child: ListTile(
                  leading: Icon(
                    isDraft ? Icons.edit_note : Icons.assignment_turned_in,
                    color: Colors.lightBlue,
                  ),
                  title: Text(nome),
                  subtitle: isDraft
                      ? const Text("Rascunho em andamento")
                      : Text("Classificação: $classificacao",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    if (isDraft) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => NovaNotificacaoPage(notificacao: n)),
                      );
                    } else {
                      _verFinalizada(context, n);
                    }
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botão de exportar PDF (rascunho e final)
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined,
                            color: Colors.redAccent),
                        tooltip: 'Exportar PDF',
                        onPressed: () => _exportarPDFProfissional(context, n),
                      ),
                      if (isDraft)
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.lightBlue),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NovaNotificacaoPage(notificacao: n),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ---------------- PDF PROFISSIONAL ----------------

  // Cores conforme classificação
  PdfColor _statusColor(String? classe) {
    switch (classe) {
      case 'Grave':    return PdfColors.red700;
      case 'Médio':    return PdfColors.orange700;
      case 'Leve':     return PdfColors.green700;
      case 'Sem dano': return PdfColors.grey600;
      case 'Óbito':    return PdfColors.black;
      default:         return PdfColors.indigo600;
    }
  }

  String _safeJoin(List<dynamic>? xs) {
    if (xs == null || xs.isEmpty) return '-';
    return xs.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).join(', ');
    }

  String _fmt(dynamic v) => (v == null || (v is String && v.trim().isEmpty)) ? '-' : v.toString();

  String _formatNow() {
    final now = DateTime.now();
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final yyyy = now.year.toString();
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  Future<void> _exportarPDFProfissional(BuildContext context, Map<String, dynamic> n) async {
    try {
      // Carrega fontes profissionais (se houver internet); senão, cai no fallback padrão
      pw.Font? regular;
      pw.Font? bold;
      try {
        regular = await PdfGoogleFonts.openSansRegular();
        bold    = await PdfGoogleFonts.openSansSemiBold();
      } catch (_) {
        regular = null;
        bold    = null;
      }

      final pdf = pw.Document();

      // Tema opcional de página
      final pageTheme = pw.PageTheme(
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        theme: pw.ThemeData.withFont(
          base: regular,
          bold: bold,
        ),
      );

      final nome = _fmt(n['nome']);
      final tipo = _fmt(n['tipoIncidente']);
      final local = _fmt(n['localIncidente']);
      final turno = _fmt(n['turno']);
      final sintomas = _safeJoin(n['sintomas'] as List?);
      final resultado = _fmt(n['resultado']);
      final observacoes = _fmt(n['observacoes']);
      final pontuacao = _fmt(n['pontuacao']);
      final createdBy = _fmt(n['createdByName'] ?? n['createdByEmail']);
      final status = _fmt(n['status']);

      final statusColor = _statusColor(resultado);

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
                font: regular,
              ),
            ),
          ),
          build: (context) => [
            // Cabeçalho
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // “Logo” textual ClassiMed
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo50,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: PdfColors.indigo200),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ClassiMed',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo700,
                            font: bold,
                          )),
                      pw.SizedBox(height: 2),
                      pw.Text('Relatório de Notificação',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.indigo700,
                            font: regular,
                          )),
                    ],
                  ),
                ),

                pw.Spacer(),

                // Data + Badge
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      _formatNow(),
                      style: pw.TextStyle(
                        color: PdfColors.grey700,
                        fontSize: 10,
                        font: regular,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: statusColor,
                        borderRadius: pw.BorderRadius.circular(999),
                      ),
                      child: pw.Text(
                        resultado,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          font: bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 18),

            // Bloco com status e pontuação
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(999),
                      color: PdfColors.white,
                    ),
                    child: pw.Text(
                      'Status: $status',
                      style: pw.TextStyle(font: bold),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(999),
                      color: PdfColors.white,
                    ),
                    child: pw.Text(
                      'Pontuação: $pontuacao',
                      style: pw.TextStyle(font: bold),
                    ),
                  ),
                  pw.Spacer(),
                  pw.Text('Autor: $createdBy',
                      style: pw.TextStyle(color: PdfColors.grey700, font: regular)),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // Seção Dados da Ocorrência
            _sectionTitle('Dados da Ocorrência', bold),
            pw.SizedBox(height: 8),
            _kvTable(
              rows: [
                ['Nome', nome],
                ['Tipo de Incidente', tipo],
                ['Local', local],
                ['Turno', turno],
                ['Sintomas', sintomas],
              ],
              regular: regular,
              bold: bold,
            ),

            pw.SizedBox(height: 16),

            // Observações
            _sectionTitle('Observações', bold),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Text(
                observacoes,
                style: pw.TextStyle(
                  fontSize: 12,
                  lineSpacing: 2,
                  font: regular,
                ),
              ),
            ),

            pw.SizedBox(height: 20),

            // Assinatura / Observação final
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Documento gerado automaticamente pelo sistema ClassiMed.',
                    style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10, font: regular),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Container(
                  width: 160,
                  height: 40,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'Assinatura',
                    style: pw.TextStyle(color: PdfColors.grey600, font: regular),
                  ),
                ),
              ],
            ),
          ],
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

  // Título de seção
  pw.Widget _sectionTitle(String text, pw.Font? bold) {
    return pw.Row(
      children: [
        pw.Container(width: 4, height: 16, color: PdfColors.indigo500),
        pw.SizedBox(width: 8),
        pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo800,
            font: bold,
          ),
        ),
      ],
    );
  }

  // Tabela chave:valor
  pw.Widget _kvTable({
    required List<List<String>> rows,
    required pw.Font? regular,
    required pw.Font? bold,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(4),
      },
      children: rows.map((r) {
        return pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey50),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                r[0],
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(r[1], style: pw.TextStyle(font: regular)),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ---------------- Modais ----------------

  void _verFinalizada(BuildContext context, Map<String, dynamic> n) {
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
              child: const Text("Fechar")),
        ],
      ),
    );
  }
}
