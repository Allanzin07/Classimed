import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class DashboardsPage extends StatefulWidget {
  const DashboardsPage({super.key});

  @override
  State<DashboardsPage> createState() => _DashboardsPageState();
}

class _DashboardsPageState extends State<DashboardsPage> {
  String _range = '30d';
  String _tipoFiltro = 'Todos';

  DateTime? _fromDateForRange(String range) {
    final now = DateTime.now();
    switch (range) {
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      case '90d':
        return now.subtract(const Duration(days: 90));
      default:
        return null;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamSemIndice() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('createdByUid', isEqualTo: uid)
        .snapshots();
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) {
      try {
        return DateTime.tryParse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  DateTime? _docDate(Map<String, dynamic> n) {
    return _toDate(n['createdAt']) ??
        _toDate(n['dataHora']) ??
        _toDate(n['updatedAt']);
  }

  // Exportar para PDF profissional
  Future<void> _exportarPDF(
      List<Map<String, dynamic>> list, Map<String, int> byClass) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Text(
              'Relatório de Dashboard - ClassiMed',
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.Text(
              'Gerado em: ${now.day}/${now.month}/${now.year} às ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 16),
          pw.Text('Resumo de Classificações',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Table.fromTextArray(
            headers: ['Classificação', 'Quantidade'],
            data: byClass.entries
                .map((e) => [e.key, e.value.toString()])
                .toList(),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.lightBlue),
            headerStyle: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Notificações Detalhadas',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Nome', 'Tipo', 'Local', 'Turno', 'Classificação'],
            data: list
                .map((n) => [
                      (n['nome'] ?? 'Sem nome').toString(),
                      (n['tipoIncidente'] ?? '—').toString(),
                      (n['localIncidente'] ?? '—').toString(),
                      (n['turno'] ?? '—').toString(),
                      (n['resultado'] ?? '—').toString(),
                    ])
                .toList(),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blueGrey800),
            headerStyle: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 11),
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
          ),
          pw.SizedBox(height: 24),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('ClassiMed © ${DateTime.now().year}',
                style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final rangeItems = {
      '7d': 'Últimos 7 dias',
      '30d': 'Últimos 30 dias',
      '90d': 'Últimos 90 dias',
      'all': 'Tudo',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboards'),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _streamSemIndice(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          var list = docs.map((d) => {'id': d.id, ...d.data()}).toList();

          // Filtragem
          final from = _fromDateForRange(_range);
          if (from != null) {
            list = list
                .where((n) => _docDate(n)?.isAfter(from) ?? false)
                .toList();
          }

          // Tipos disponíveis + prevenção de erro no Dropdown
          final tiposSet = <String>{'Todos'};
          for (final n in list) {
            final tipo = (n['tipoIncidente'] ?? '—').toString();
            tiposSet.add(tipo);
          }
          final tipos = tiposSet.toList();
          if (!tipos.contains(_tipoFiltro)) _tipoFiltro = 'Todos';
          if (_tipoFiltro != 'Todos') {
            list = list.where((n) => n['tipoIncidente'] == _tipoFiltro).toList();
          }

          // Estatísticas
          final total = list.length;
          final drafts = list.where((e) => e['status'] == 'draft').length;
          final finals = list.where((e) => e['status'] == 'final').length;

          final byClass = <String, int>{
            'Sem dano': 0,
            'Leve': 0,
            'Médio': 0,
            'Grave': 0,
            'Óbito': 0,
          };
          for (final n in list) {
            final c = (n['resultado'] ?? 'Sem dano').toString();
            byClass[c] = (byClass[c] ?? 0) + 1;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Filtros superiores
                Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined,
                        color: Colors.lightBlueAccent),
                    const SizedBox(width: 6),
                    DropdownButton<String>(
                      value: _range,
                      items: rangeItems.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _range = v ?? '30d'),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _tipoFiltro,
                      items: tipos
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _tipoFiltro = v ?? 'Todos'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                      ),
                      onPressed: () => _exportarPDF(list, byClass),
                      label: const Text('Exportar PDF'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                // 🔹 KPIs principais
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _KpiCard('Total', total.toString(), Icons.all_inbox,
                        Colors.indigo),
                    _KpiCard('Rascunhos', drafts.toString(),
                        Icons.edit_note, Colors.orange),
                    _KpiCard('Finalizadas', finals.toString(),
                        Icons.assignment_turned_in, Colors.green),
                  ],
                ),
                const SizedBox(height: 20),

                _ClassDistribution(byClass: byClass),

                const SizedBox(height: 20),
                const Text('Últimas notificações',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...list.take(10).map((n) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.local_hospital,
                          color: Colors.lightBlueAccent),
                      title: Text(n['nome'] ?? 'Sem nome'),
                      subtitle: Text(
                          'Tipo: ${n['tipoIncidente'] ?? '—'} • ${n['resultado'] ?? 'Sem dano'}'),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
      backgroundColor: const Color(0xFFF7F9FC),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String titulo, valor;
  final IconData icone;
  final Color cor;
  const _KpiCard(this.titulo, this.valor, this.icone, this.cor);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: cor.withOpacity(0.15),
              child: Icon(icone, color: cor)),
          const SizedBox(width: 10),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(valor,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
        ],
      ),
    );
  }
}

class _ClassDistribution extends StatelessWidget {
  final Map<String, int> byClass;
  const _ClassDistribution({required this.byClass});

  Color _cor(String c) {
    switch (c) {
      case 'Sem dano':
        return Colors.grey;
      case 'Leve':
        return Colors.green;
      case 'Médio':
        return Colors.orange;
      case 'Grave':
        return Colors.red;
      case 'Óbito':
        return Colors.black87;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = byClass.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return const Text('Sem dados no período selecionado.');
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Distribuição por classificação',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Row(
              children: byClass.entries.map((e) {
                final p = total == 0 ? 0.0 : e.value / total;
                return Expanded(
                  flex: (p * 1000).round().clamp(0, 1000),
                  child: Container(height: 16, color: _cor(e.key)),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: byClass.entries
                  .map((e) => Text('${e.key}: ${e.value}',
                      style: TextStyle(
                          color: _cor(e.key),
                          fontWeight: FontWeight.w700)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
