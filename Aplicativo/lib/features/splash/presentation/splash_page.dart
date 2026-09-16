import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.ready, required this.onDone});
  final Future<void> ready;
  final VoidCallback onDone;
  @override State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();
  bool leaving = false;

  @override
  void initState() {
    super.initState();
    _finishWhenReady();
  }

  Future<void> _finishWhenReady() async {
    await Future.wait([widget.ready, Future<void>.delayed(const Duration(milliseconds: 3600))]);
    if (!mounted) return;
    setState(() => leaving = true);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (mounted) widget.onDone();
  }

  @override void dispose() { _intro.dispose(); _ambient.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    return Scaffold(
      backgroundColor: AppTheme.deepGreen,
      body: AnimatedOpacity(
        opacity: leaving ? 0 : 1,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
        child: AnimatedBuilder(
          animation: _ambient,
          builder: (_, child) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + _ambient.value * .3, -1),
                end: Alignment(1, 1 - _ambient.value * .25),
                colors: const [Color(0xFF042E29), Color(0xFF07614F), Color(0xFF13B77A), Color(0xFF0A7F83)],
              ),
            ),
            child: child,
          ),
          child: Stack(children: [
            Positioned(top: -70, right: -80, child: _orb(230, Colors.white.withValues(alpha: .07))),
            Positioned(bottom: -95, left: -65, child: _orb(250, const Color(0xFF54E6B0).withValues(alpha: .1))),
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: fade,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, .08), end: Offset.zero).animate(fade),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ScaleTransition(
                        scale: Tween(begin: .72, end: 1.0).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutBack)),
                        child: Container(
                          width: 206,
                          height: 206,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .13))),
                          child: Lottie.asset('assets/lottie/splash.json', repeat: true),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text('Lixeira Inteligente', style: TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: -.7)),
                      const SizedBox(height: 8),
                      Text('Reciclagem • IoT • Inteligência Artificial', style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 26),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(22)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF84F0C3))),
                          SizedBox(width: 10),
                          Text('Preparando o sistema', style: TextStyle(color: Color(0xFFD8F4E9), fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}
