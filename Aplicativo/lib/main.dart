import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_controller.dart';
import 'app_scope.dart';
import 'core/database/app_database.dart';
import 'core/mqtt/mqtt_service.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/splash/presentation/splash_page.dart';
import 'home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  const secureStorage = FlutterSecureStorage();
  final controller = AppController(
    database: database,
    settingsRepository: SettingsRepository(database, secureStorage),
    mqtt: MqttService(),
  );
  runApp(LixeiraApp(controller: controller));
}

class LixeiraApp extends StatefulWidget {
  const LixeiraApp({super.key, required this.controller});
  final AppController controller;
  @override State<LixeiraApp> createState() => _LixeiraAppState();
}

class _LixeiraAppState extends State<LixeiraApp> {
  bool splash = true;
  late final Future<void> initialization;

  @override
  void initState() {
    super.initState();
    initialization = _initialize();
  }

  Future<void> _initialize() async {
    await widget.controller.database.open();
    await widget.controller.initialize();
  }

  @override
  void dispose() {
    widget.controller.disposeAsync();
    widget.controller.database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    controller: widget.controller,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lixeira Inteligente',
      theme: AppTheme.theme,
      home: splash
          ? SplashPage(ready: initialization, onDone: () => setState(() => splash = false))
          : const HomeShell(),
    ),
  );
}
