import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/motion.dart';

enum SensorDetailType { weight, level, presence, metal, gate, network }

class SensorDetailPage extends StatelessWidget {
  const SensorDetailPage({super.key, required this.type});
  final SensorDetailType type;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final t = c.telemetry;
    final data = _data(t, c.mqttConnected);
    return Scaffold(
      appBar: AppBar(title: Text(data.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        children: [
          StaggeredReveal(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [data.color, data.color.withValues(alpha: .72)]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: data.color.withValues(alpha: .25), blurRadius: 26, offset: const Offset(0, 12))],
              ),
              child: Column(children: [
                Hero(
                  tag: 'sensor-${type.name}',
                  child: SizedBox(width: 158, height: 158, child: Lottie.asset(data.lottie, repeat: true)),
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: data.numericValue),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, _) => Text(
                    data.format(value),
                    style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1),
                  ),
                ),
                const SizedBox(height: 6),
                Text(data.state, style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          StaggeredReveal(
            delay: const Duration(milliseconds: 100),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Icon(Icons.insights_rounded, color: data.color), const SizedBox(width: 10), Text('Leitura em tempo real', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))]),
                  const SizedBox(height: 12),
                  Text(data.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, color: const Color(0xFF4F625B))),
                  if (type == SensorDetailType.level) ...[
                    const SizedBox(height: 20),
                    ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: (data.numericValue / 100).clamp(0.0, 1.0).toDouble(), minHeight: 18, backgroundColor: data.color.withValues(alpha: .12), color: data.color)),
                  ],
                  if (type == SensorDetailType.network) ...[
                    const SizedBox(height: 16),
                    _infoRow(Icons.cloud_rounded, 'HiveMQ', c.mqttConnected ? 'Conectado' : 'Offline'),
                    _infoRow(Icons.router_rounded, 'Rede do ESP32', t?.network.toUpperCase() ?? 'Sem telemetria'),
                    _infoRow(Icons.network_check_rounded, 'Sinal', t == null ? '--' : '${t.rssi} dBm'),
                  ],
                ]),
              ),
            ),
          ),
          if (type == SensorDetailType.gate) ...[
            const SizedBox(height: 18),
            StaggeredReveal(
              delay: const Duration(milliseconds: 180),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Controle remoto', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: FilledButton.icon(onPressed: c.mqttConnected ? () => c.sendAction('open') : null, icon: const Icon(Icons.lock_open_rounded), label: const Text('Abrir'))),
                      const SizedBox(width: 12),
                      Expanded(child: OutlinedButton.icon(onPressed: c.mqttConnected ? () => c.sendAction('close') : null, icon: const Icon(Icons.lock_rounded), label: const Text('Fechar'))),
                    ]),
                    if (!c.mqttConnected) const Padding(padding: EdgeInsets.only(top: 10), child: Text('Conecte ao HiveMQ em Configurações para habilitar os comandos.')),
                  ]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(children: [Icon(icon, size: 20, color: AppTheme.deepGreen), const SizedBox(width: 10), Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]),
  );

  _SensorData _data(dynamic t, bool mqtt) {
    switch (type) {
      case SensorDetailType.weight:
        final v = t?.weightGrams?.toDouble() ?? 0.0;
        return _SensorData('Peso', AppTheme.cyan, 'assets/lottie/weight.json', v, v > 0 ? 'Objeto sobre a balança' : 'Aguardando objeto', 'A célula de carga informa o peso atual do resíduo e ajuda a registrar cada descarte.', (x) => '${x.toStringAsFixed(0)} g');
      case SensorDetailType.level:
        final v = t?.fillLevel?.toDouble() ?? 0.0;
        return _SensorData('Nível da lixeira', AppTheme.amber, 'assets/lottie/level.json', v, v >= 85 ? 'Capacidade crítica' : v >= 60 ? 'Atenção' : 'Capacidade disponível', 'Acompanhe o percentual de ocupação do compartimento. O indicador muda de estado conforme o enchimento.', (x) => '${x.toStringAsFixed(0)}%');
      case SensorDetailType.presence:
        final active = t?.presence == true;
        return _SensorData('Presença', AppTheme.violet, 'assets/lottie/presence.json', active ? 1 : 0, active ? 'Objeto detectado' : 'Área livre', 'O sensor de presença informa quando um objeto entrou na área de análise da lixeira.', (_) => active ? 'Detectado' : 'Livre');
      case SensorDetailType.metal:
        final active = t?.metalDetected == true;
        return _SensorData('Detecção de metal', const Color(0xFF607D8B), 'assets/lottie/metal.json', active ? 1 : 0, active ? 'Metal identificado' : 'Sem metal', 'O sensor indutivo fornece uma evidência física forte para classificação de resíduos metálicos.', (_) => active ? 'Metal' : 'Não');
      case SensorDetailType.gate:
        final state = t?.gate?.toString() ?? '--';
        return _SensorData('Comporta', AppTheme.coral, 'assets/lottie/gate.json', state.toLowerCase().contains('open') ? 1 : 0, 'Estado: $state', 'Consulte o estado da comporta e envie comandos de abertura ou fechamento quando o MQTT estiver conectado.', (_) => state.toUpperCase());
      case SensorDetailType.network:
        final rssi = t?.rssi?.toDouble() ?? 0.0;
        return _SensorData('Conectividade', AppTheme.emerald, 'assets/lottie/connectivity.json', rssi.abs(), mqtt ? 'HiveMQ conectado' : 'HiveMQ offline', 'A conectividade do aplicativo é configurada exclusivamente em Configurações. Aqui você acompanha apenas o estado atual.', (_) => t == null ? '--' : '${t.network.toString().toUpperCase()} • ${t.rssi} dBm');
    }
  }
}

class _SensorData {
  const _SensorData(this.title, this.color, this.lottie, this.numericValue, this.state, this.description, this.format);
  final String title, lottie, state, description;
  final Color color;
  final double numericValue;
  final String Function(double) format;
}
