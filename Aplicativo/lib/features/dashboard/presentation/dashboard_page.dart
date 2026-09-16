import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/motion.dart';
import '../../sensors/presentation/sensor_detail_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final t = c.telemetry;
    final connected = c.mqttConnected;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF063E35), Color(0xFF0B6D59), Color(0xFF13B77A)],
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
              child: SafeArea(
                bottom: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  StaggeredReveal(
                    child: Row(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(18)),
                        child: const Icon(Icons.recycling_rounded, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Lixeira Inteligente', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('Seu HUB de reciclagem conectada', style: TextStyle(color: Color(0xFFD2EFE4), fontSize: 13)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  StaggeredReveal(
                    delay: const Duration(milliseconds: 80),
                    child: Row(children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .11), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: .1))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              PulseDot(color: connected ? const Color(0xFF64F0AE) : const Color(0xFFFF837A)),
                              const SizedBox(width: 8),
                              Text(connected ? 'HiveMQ conectado' : 'HiveMQ offline', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 12),
                            Text(t == null ? 'Aguardando telemetria do ESP32' : '${t.network.toUpperCase()} • ${t.rssi} dBm', style: const TextStyle(color: Color(0xFFD2EFE4))),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(width: 96, height: 96, child: Lottie.asset('assets/lottie/hub.json')),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                StaggeredReveal(
                  delay: const Duration(milliseconds: 120),
                  child: Text('Leituras agora', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.deepGreen)),
                ),
                const SizedBox(height: 14),
                _grid(context, c),
                const SizedBox(height: 22),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 520),
                  child: _InsightCard(
                    title: 'Resumo inteligente',
                    message: _summary(c),
                    icon: Icons.auto_awesome_rounded,
                  ),
                ),
                const SizedBox(height: 18),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 600),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFEDF9F3), Color(0xFFE8F4FB)]),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Row(children: [
                      Icon(Icons.touch_app_rounded, color: AppTheme.emerald),
                      SizedBox(width: 12),
                      Expanded(child: Text('Toque em qualquer leitura para abrir uma tela dedicada com status, animação e detalhes.', style: TextStyle(height: 1.45, color: Color(0xFF496058)))),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, dynamic c) {
    final t = c.telemetry;
    final cards = <_HubCardData>[
      _HubCardData('Peso', t == null ? '--' : '${t.weightGrams.toStringAsFixed(0)} g', Icons.scale_rounded, AppTheme.cyan, SensorDetailType.weight),
      _HubCardData('Nível', t == null ? '--' : '${t.fillLevel.toStringAsFixed(0)}%', Icons.delete_outline_rounded, AppTheme.amber, SensorDetailType.level),
      _HubCardData('Presença', t == null ? '--' : (t.presence ? 'Objeto' : 'Livre'), Icons.sensors_rounded, AppTheme.violet, SensorDetailType.presence),
      _HubCardData('Metal', t == null ? '--' : (t.metalDetected ? 'Detectado' : 'Não'), Icons.precision_manufacturing_rounded, const Color(0xFF607D8B), SensorDetailType.metal),
      _HubCardData('Comporta', t?.gate?.toString().toUpperCase() ?? '--', Icons.door_sliding_rounded, AppTheme.coral, SensorDetailType.gate),
      _HubCardData('Rede', t == null ? '--' : t.network.toUpperCase(), Icons.wifi_rounded, AppTheme.emerald, SensorDetailType.network),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.12),
      itemBuilder: (_, i) => StaggeredReveal(
        delay: Duration(milliseconds: 170 + i * 65),
        child: _HubCard(data: cards[i]),
      ),
    );
  }

  String _summary(dynamic c) {
    final t = c.telemetry;
    if (t == null) return 'O HUB está pronto. Quando o ESP32 publicar telemetria, as leituras serão atualizadas em tempo real.';
    if (t.fillLevel >= 85) return 'A capacidade está crítica (${t.fillLevel.toStringAsFixed(0)}%). Priorize o esvaziamento do compartimento.';
    if (t.metalDetected) return 'O sensor indutivo detectou metal. Essa evidência será usada pela IA na classificação do resíduo.';
    if (t.presence) return 'Há um objeto na área de análise. Você pode usar o menu IA para iniciar uma classificação visual.';
    return 'Sistema estável: sensores ativos e sem alertas prioritários neste momento.';
  }
}

class _HubCardData {
  const _HubCardData(this.title, this.value, this.icon, this.color, this.type);
  final String title, value;
  final IconData icon;
  final Color color;
  final SensorDetailType type;
}

class _HubCard extends StatefulWidget {
  const _HubCard({required this.data});
  final _HubCardData data;
  @override State<_HubCard> createState() => _HubCardState();
}

class _HubCardState extends State<_HubCard> {
  bool pressed = false;
  @override Widget build(BuildContext context) {
    final d = widget.data;
    return GestureDetector(
      onTapDown: (_) => setState(() => pressed = true),
      onTapCancel: () => setState(() => pressed = false),
      onTapUp: (_) {
        setState(() => pressed = false);
        Navigator.of(context).push(motionRoute(SensorDetailPage(type: d.type)));
      },
      child: AnimatedScale(
        scale: pressed ? .965 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: d.color.withValues(alpha: .12), blurRadius: 22, offset: const Offset(0, 10))],
            border: Border.all(color: d.color.withValues(alpha: .12)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Hero(
              tag: 'sensor-${d.type.name}',
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: d.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
                child: Icon(d.icon, color: d.color),
              ),
            ),
            const Spacer(),
            Text(d.title, style: const TextStyle(color: Color(0xFF6A7B75), fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(d.value, key: ValueKey(d.value), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.deepGreen)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.title, required this.message, required this.icon});
  final String title, message;
  final IconData icon;
  @override Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.emerald.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: AppTheme.emerald)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(height: 1.45, color: Color(0xFF53665F))),
        ])),
      ]),
    ),
  );
}
