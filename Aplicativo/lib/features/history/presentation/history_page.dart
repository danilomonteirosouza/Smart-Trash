import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/motion.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, Object?>>> _future;
  String filter = 'Todos';
  final filters = const ['Todos', 'IA', 'Comandos', 'Status'];

  @override void didChangeDependencies() { super.didChangeDependencies(); _future = AppScope.of(context).database.recentEvents(); }

  bool _visible(Map<String, Object?> row) {
    final type = row['type']?.toString().toLowerCase() ?? '';
    if (filter == 'Todos') return true;
    if (filter == 'IA') return type.contains('classification');
    if (filter == 'Comandos') return type.contains('command') || type.contains('ack');
    return type.contains('status');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Histórico')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snap.data!.where(_visible).toList();
        return RefreshIndicator(
          onRefresh: () async { setState(() => _future = AppScope.of(context).database.recentEvents()); await _future; },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            children: [
              StaggeredReveal(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0B6D59), Color(0xFF13B77A)]), borderRadius: BorderRadius.circular(28)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Linha do tempo', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text('Eventos locais da lixeira, IA e comandos enviados.', style: TextStyle(color: Colors.white.withValues(alpha: .84), height: 1.4)),
                    ])),
                    SizedBox(width: 86, height: 86, child: Lottie.asset('assets/lottie/hub.json')),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: filters.map((f) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(f), selected: filter == f, onSelected: (_) => setState(() => filter = f)),
                )).toList()),
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 34),
                  child: Column(children: [SizedBox(width: 150, height: 150, child: Lottie.asset('assets/lottie/unknown.json')), const Text('Nenhum evento neste filtro.', style: TextStyle(color: Color(0xFF61736C)))]),
                )
              else
                ...List.generate(rows.length, (i) {
                  final row = rows[i];
                  final type = row['type']?.toString() ?? '';
                  final data = _style(type);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StaggeredReveal(
                      delay: Duration(milliseconds: i.clamp(0, 6).toInt() * 50),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(width: 44, height: 44, decoration: BoxDecoration(color: data.$2.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)), child: Icon(data.$1, color: data.$2)),
                            const SizedBox(width: 13),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(row['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.deepGreen)),
                              const SizedBox(height: 4),
                              Text(row['detail']?.toString() ?? '', style: const TextStyle(color: Color(0xFF61736C), height: 1.35)),
                              const SizedBox(height: 7),
                              Text(row['created_at']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF8A9893))),
                            ])),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    ),
  );

  (IconData, Color) _style(String type) {
    final t = type.toLowerCase();
    if (t.contains('classification')) return (Icons.auto_awesome_rounded, AppTheme.violet);
    if (t.contains('command')) return (Icons.send_rounded, AppTheme.cyan);
    if (t.contains('ack')) return (Icons.done_all_rounded, AppTheme.emerald);
    return (Icons.info_outline_rounded, AppTheme.amber);
  }
}
