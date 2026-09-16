import 'package:flutter/material.dart';
import '../../../app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/motion.dart';
import '../domain/mqtt_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final host = TextEditingController();
  final port = TextEditingController();
  final user = TextEditingController();
  final pass = TextEditingController();
  final sub = TextEditingController();
  final pub = TextEditingController();
  final device = TextEditingController();
  bool same = false, seeded = false, obscure = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!seeded) {
      final c = AppScope.of(context); final s = c.settings;
      host.text = s.host; port.text = '${s.port}'; user.text = s.username; pass.text = c.password;
      sub.text = s.subscribeTopic; pub.text = s.publishTopic; device.text = s.deviceId; same = s.sameTopic; seeded = true;
    }
  }

  @override void dispose() { for (final c in [host, port, user, pass, sub, pub, device]) { c.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
        StaggeredReveal(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: c.mqttConnected ? const [Color(0xFF0B6D59), Color(0xFF13B77A)] : const [Color(0xFF505B58), Color(0xFF76837F)]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(children: [
              PulseDot(color: c.mqttConnected ? const Color(0xFF82F0C2) : const Color(0xFFFFA49C), size: 12),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('HiveMQ', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(c.mqttConnected ? 'Conectado e recebendo mensagens' : 'Offline', style: TextStyle(color: Colors.white.withValues(alpha: .86))),
              ])),
              Icon(c.mqttConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: Colors.white, size: 32),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        StaggeredReveal(
          delay: const Duration(milliseconds: 100),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Conexão MQTT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.deepGreen)),
                const SizedBox(height: 14),
                _field(host, 'HiveMQ host', Icons.dns_rounded),
                _field(port, 'Porta', Icons.numbers_rounded, number: true),
                _field(user, 'Usuário', Icons.person_rounded),
                TextField(controller: pass, obscureText: obscure, decoration: InputDecoration(labelText: 'Senha', prefixIcon: const Icon(Icons.key_rounded), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded)))),
                const SizedBox(height: 12),
                _field(sub, 'Tópico de leitura/subscribe', Icons.download_rounded),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Usar o mesmo tópico'), subtitle: const Text('Leitura e envio compartilham o mesmo tópico.'), value: same, onChanged: (v) => setState(() => same = v)),
                TextField(controller: pub, enabled: !same, decoration: InputDecoration(labelText: 'Tópico de envio/publish', prefixIcon: const Icon(Icons.upload_rounded), helperText: same ? 'Desabilitado enquanto o tópico único estiver ativo.' : null)),
                const SizedBox(height: 12),
                _field(device, 'ID do dispositivo', Icons.memory_rounded),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final settings = MqttSettings(host: host.text.trim(), port: int.tryParse(port.text) ?? 8883, username: user.text.trim(), subscribeTopic: sub.text.trim(), publishTopic: pub.text.trim(), sameTopic: same, deviceId: device.text.trim());
          await c.saveSettings(settings, pass.text);
          if (!mounted) return;
          messenger.showSnackBar(const SnackBar(content: Text('Configurações salvas com segurança.')));
        }, icon: const Icon(Icons.save_rounded), label: const Text('Salvar configurações')),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: c.busy ? null : (c.mqttConnected ? c.disconnect : c.connect), icon: Icon(c.mqttConnected ? Icons.cloud_off_rounded : Icons.cloud_rounded), label: Text(c.busy ? 'Processando...' : c.mqttConnected ? 'Desconectar do HiveMQ' : 'Conectar ao HiveMQ')),
        if (c.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(c.error!, style: const TextStyle(color: AppTheme.coral))),
      ]),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {bool number = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: controller, keyboardType: number ? TextInputType.number : null, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon))),
  );
}
