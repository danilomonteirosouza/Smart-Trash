import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/history/presentation/history_page.dart';
import 'features/camera_ai/presentation/camera_ai_page.dart';
import 'features/settings/presentation/settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final pages = const [DashboardPage(), HistoryPage(), CameraAiPage(), SettingsPage()];
  final items = const [
    (Icons.home_rounded, 'HUB'),
    (Icons.history_rounded, 'Histórico'),
    (Icons.auto_awesome_rounded, 'IA'),
    (Icons.tune_rounded, 'Config.'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: KeyedSubtree(key: ValueKey(index), child: pages[index])),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 10))]),
        child: Row(
          children: List.generate(items.length, (i) {
            final selected = index == i;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => index = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(color: selected ? AppTheme.emerald.withValues(alpha: .11) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedScale(scale: selected ? 1.13 : 1, duration: const Duration(milliseconds: 250), child: Icon(items[i].$1, color: selected ? AppTheme.emerald : const Color(0xFF83908B))),
                    const SizedBox(height: 4),
                    Text(items[i].$2, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? AppTheme.deepGreen : const Color(0xFF83908B))),
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}
