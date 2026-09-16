import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/motion.dart';
import '../data/vision_service.dart';
import '../domain/recycling_result.dart';

class CameraAiPage extends StatefulWidget {
  const CameraAiPage({super.key});
  @override State<CameraAiPage> createState() => _CameraAiPageState();
}

class _CameraAiPageState extends State<CameraAiPage> {
  CameraController? camera;
  final vision = VisionService();
  RecyclingResult? result;
  bool busy = false;
  bool openingCamera = false;
  bool cameraStarted = false;
  String? error;

  Future<void> _startCamera() async {
    if (openingCamera || cameraStarted) return;
    setState(() { openingCamera = true; error = null; });
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw StateError('Nenhuma câmera disponível.');
      final ctrl = CameraController(cams.first, ResolutionPreset.medium, enableAudio: false);
      await ctrl.initialize();
      if (!mounted) { await ctrl.dispose(); return; }
      setState(() { camera = ctrl; cameraStarted = true; openingCamera = false; });
    } catch (e) {
      if (mounted) setState(() { openingCamera = false; error = e.toString(); });
    }
  }

  Future<void> _stopCamera() async {
    final old = camera;
    camera = null;
    if (mounted) setState(() { cameraStarted = false; result = null; });
    await old?.dispose();
  }

  Future<void> _capture() async {
    final ctrl = camera;
    if (ctrl == null || busy) return;
    final app = AppScope.of(context);
    setState(() { busy = true; error = null; });
    try {
      final image = await ctrl.takePicture();
      final metal = app.telemetry?.metalDetected ?? false;
      final classified = await vision.classify(image.path, metalSensor: metal);
      await app.database.insertEvent(
        'classification',
        classified.categoryName,
        '${classified.label} • ${(classified.confidence * 100).toStringAsFixed(0)}%',
      );
      if (!mounted) return;
      setState(() => result = classified);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override void dispose() { camera?.dispose(); vision.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: cameraStarted ? _cameraExperience(context) : _landing(context),
        ),
      ),
    );
  }

  Widget _landing(BuildContext context) => ListView(
    key: const ValueKey('ai-landing'),
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
    children: [
      StaggeredReveal(
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF123F56), Color(0xFF167E78), Color(0xFF19B77A)]),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(children: [
            SizedBox(height: 190, child: Lottie.asset('assets/lottie/ai_scan.json')),
            const Text('Identificação inteligente', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('A câmera só será ativada quando você solicitar. A IA combina a imagem com evidências dos sensores para sugerir a categoria do resíduo.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .88), height: 1.45)),
          ]),
        ),
      ),
      const SizedBox(height: 20),
      StaggeredReveal(
        delay: const Duration(milliseconds: 120),
        child: FilledButton.icon(
          onPressed: openingCamera ? null : _startCamera,
          icon: openingCamera
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.camera_alt_rounded),
          label: Text(openingCamera ? 'Preparando câmera...' : 'Iniciar análise por câmera'),
        ),
      ),
      const SizedBox(height: 14),
      StaggeredReveal(
        delay: const Duration(milliseconds: 200),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              _AiStep(Icons.center_focus_strong_rounded, '1. Enquadre o objeto', 'Prefira fundo simples e boa iluminação.'),
              SizedBox(height: 16),
              _AiStep(Icons.auto_awesome_rounded, '2. A IA analisa', 'Image Labeling e sensores produzem evidências em conjunto.'),
              SizedBox(height: 16),
              _AiStep(Icons.recycling_rounded, '3. Receba a recomendação', 'O app evita forçar uma classe quando a confiança é baixa.'),
            ]),
          ),
        ),
      ),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(error!, style: const TextStyle(color: AppTheme.coral))),
    ],
  );

  Widget _cameraExperience(BuildContext context) => ListView(
    key: const ValueKey('ai-camera'),
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
    children: [
      Row(children: [
        IconButton.filledTonal(onPressed: _stopCamera, icon: const Icon(Icons.arrow_back_rounded)),
        const SizedBox(width: 12),
        const Expanded(child: Text('Análise por câmera', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.deepGreen))),
      ]),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(fit: StackFit.expand, children: [
            if (camera?.value.isInitialized == true) CameraPreview(camera!) else const ColoredBox(color: Colors.black12),
            IgnorePointer(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: .75), width: 2), borderRadius: BorderRadius.circular(30)))),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), borderRadius: BorderRadius.circular(20)), child: const Text('Centralize um único objeto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              ),
            ),
            if (busy) ColoredBox(color: Colors.black45, child: Center(child: SizedBox(width: 150, height: 150, child: Lottie.asset('assets/lottie/loading.json')))),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: busy ? null : _capture, icon: const Icon(Icons.document_scanner_rounded), label: Text(busy ? 'Analisando...' : 'Capturar e analisar')),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: AppTheme.coral))),
      if (result != null) ...[
        const SizedBox(height: 18),
        _ResultCard(result: result!),
      ],
    ],
  );
}

class _AiStep extends StatelessWidget {
  const _AiStep(this.icon, this.title, this.subtitle);
  final IconData icon; final String title, subtitle;
  @override Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(color: AppTheme.emerald.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppTheme.emerald)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF61736C), height: 1.35))])),
  ]);
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final RecyclingResult result;
  @override Widget build(BuildContext context) {
    final unknown = result.category == RecyclingCategory.unknown;
    final color = unknown ? AppTheme.amber : AppTheme.emerald;
    return StaggeredReveal(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(28), border: Border.all(color: color.withValues(alpha: .22))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(width: 64, height: 64, child: Lottie.asset(unknown ? 'assets/lottie/unknown.json' : 'assets/lottie/success.json')),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(result.categoryName, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppTheme.deepGreen)),
              Text('${(result.confidence * 100).toStringAsFixed(0)}% de confiança', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ])),
          ]),
          const SizedBox(height: 12),
          Text(result.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text('Evidências: ${result.evidence.join(', ')}', style: const TextStyle(color: Color(0xFF60716A), height: 1.4)),
          if (unknown) const Padding(padding: EdgeInsets.only(top: 10), child: Text('Reposicione o objeto e tente outra foto. O app não força uma categoria quando a confiança é baixa.', style: TextStyle(height: 1.4))),
        ]),
      ),
    );
  }
}
