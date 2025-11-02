import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardsPage extends StatefulWidget {
  const DashboardsPage({super.key});

  @override
  State<DashboardsPage> createState() => _DashboardsPageState();
}

class _DashboardsPageState extends State<DashboardsPage> {
  String _range = '30d'; // 7d | 30d | 90d | all

  DateTime? _fromDateForRange(String range) {
    final now = DateTime.now();
    switch (range) {
      case '7d':  return now.subtract(const Duration(days: 7));
      case '30d': return now.subtract(const Duration(days: 30));
      case '90d': return now.subtract(const Duration(days: 90));
      case 'all':
      default:    return null;
    }
  }

  /// Stream SEM orderBy/inequality para evitar índice composto.
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamSemIndice() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('createdByUid', isEqualTo: uid) // apenas igualdade
        .snapshots();
  }

  /// Converte qualquer campo de data pra DateTime (createdAt/dataHora ou null)
  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) {
      try { return DateTime.tryParse(v); } catch (_) { return null; }
    }
    return null;
  }

  /// Pega a “data de referência” do doc (createdAt preferencial; fallback em dataHora; por fim updatedAt)
  DateTime? _docDate(Map<String, dynamic> n) {
    return _toDate(n['createdAt']) ?? _toDate(n['dataHora']) ?? _toDate(n['updatedAt']);
  }

  @override
  Widget build(BuildContext context) {
    final rangeItems = <String, String>{
      '7d':  'Últimos 7 dias',
      '30d': 'Últimos 30 dias',
      '90d': 'Últimos 90 dias',
      'all': 'Tudo',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboards'),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: Column(
        children: [
          // Filtro de período
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_outlined, color: Colors.lightBlueAccent),
                const SizedBox(width: 8),
                const Text('Período:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _range,
                  items: rangeItems.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _range = v ?? '30d'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _streamSemIndice(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Erro ao carregar: ${snapshot.error}'),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                // Mapeia docs e normaliza
                var list = docs.map((d) => {'id': d.id, ...d.data()}).toList();

                // Ordena por data (desc) em memória
                list.sort((a, b) {
                  final da = _docDate(a);
                  final db = _docDate(b);
                  if (da == null && db == null) return 0;
                  if (da == null) return 1;  // nulls por último
                  if (db == null) return -1;
                  return db.compareTo(da);   // desc
                });

                // Filtra por período em memória, se aplicável
                final from = _fromDateForRange(_range);
                if (from != null) {
                  list = list.where((n) {
                    final d = _docDate(n);
                    return d != null && !d.isBefore(from);
                  }).toList();
                }

                // KPIs
                final total  = list.length;
                final drafts = list.where((e) => (e['status'] ?? '') == 'draft').length;
                final finals = list.where((e) => (e['status'] ?? '') == 'final').length;

                // Por classificação
                final byClass = <String, int>{
                  'Sem dano': 0,
                  'Leve': 0,
                  'Médio': 0,
                  'Grave': 0,
                  'Óbito': 0,
                };
                for (final n in list) {
                  final c = (n['resultado'] ?? '').toString();
                  if (byClass.containsKey(c)) {
                    byClass[c] = byClass[c]! + 1;
                  } else {
                    byClass[c] = (byClass[c] ?? 0) + 1; // outros/indefinidos
                  }
                }

                // últimos registros
                final latest = List<Map<String, dynamic>>.from(list.take(8));

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPIs
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _KpiCard(title: 'Total',       value: total.toString(),  icon: Icons.all_inbox,             color: Colors.indigo),
                          _KpiCard(title: 'Rascunhos',   value: drafts.toString(), icon: Icons.edit_note,             color: Colors.orange),
                          _KpiCard(title: 'Finalizadas', value: finals.toString(), icon: Icons.assignment_turned_in,  color: Colors.green),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Text('Distribuição por Classificação',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.blueGrey[800], fontSize: 16)),
                      const SizedBox(height: 8),
                      _ClassDistribution(byClass: byClass),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          const Icon(Icons.schedule_outlined, size: 18),
                          const SizedBox(width: 6),
                          Text('Últimos Registros',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.blueGrey[800], fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (latest.isEmpty)
                        Text('Nenhum registro no período selecionado.',
                            style: TextStyle(color: Colors.black.withOpacity(0.6)))
                      else
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: latest.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final n = latest[i];
                              final nome  = (n['nome'] ?? 'Sem nome').toString();
                              final classe = (n['resultado'] ?? '—').toString();
                              final tipo   = (n['tipoIncidente'] ?? '—').toString();

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _classColor(classe).withOpacity(0.15),
                                  child: Icon(Icons.local_hospital_outlined, color: _classColor(classe)),
                                ),
                                title: Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('Tipo: $tipo'),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _classColor(classe),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(classe, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F9FC),
    );
  }

  // --------- helpers de UI ---------

  Color _classColor(String classe) {
    switch (classe) {
      case 'Sem dano': return Colors.grey.shade700;
      case 'Leve':     return Colors.green.shade600;
      case 'Médio':    return Colors.orange.shade700;
      case 'Grave':    return Colors.red.shade600;
      case 'Óbito':    return Colors.black87;
      default:         return Colors.indigo;
    }
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.black12.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.black.withOpacity(0.6), fontWeight: FontWeight.w600)),
              Text(value, style: TextStyle(color: Colors.blueGrey[900], fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassDistribution extends StatelessWidget {
  const _ClassDistribution({required this.byClass});
  final Map<String, int> byClass;

  int get total => byClass.values.fold(0, (a, b) => a + b);
  double _percent(int v) => total == 0 ? 0.0 : (v / total);

  Color _color(String k) {
    switch (k) {
      case 'Sem dano': return Colors.grey.shade700;
      case 'Leve':     return Colors.green.shade600;
      case 'Médio':    return Colors.orange.shade700;
      case 'Grave':    return Colors.red.shade600;
      case 'Óbito':    return Colors.black87;
      default:         return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = byClass.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // ordena por quantidade desc

    // mostra todas na barra (mesmo 0), mas legenda só com > 0
    final allKeys = byClass.keys.toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra empilhada proporcional
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: allKeys.map((k) {
                  final p = _percent(byClass[k] ?? 0);
                  return Expanded(
                    flex: ((p * 1000).round()).clamp(0, 1000),
                    child: Container(height: 16, color: _color(k)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // Legenda (apenas classes presentes)
            if (total == 0)
              Text('Sem dados no período selecionado.',
                  style: TextStyle(color: Colors.black.withOpacity(0.6)))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entries.map((e) {
                  final k = e.key;
                  final v = e.value;
                  final p = (_percent(v) * 100).round();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: _color(k).withOpacity(0.12),
                      border: Border.all(color: _color(k).withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10,
                            decoration: BoxDecoration(color: _color(k), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text("$k — $v (${p}%)",
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
