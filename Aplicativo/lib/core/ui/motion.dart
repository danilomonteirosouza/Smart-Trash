import 'package:flutter/material.dart';

class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;
  @override State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal> {
  bool visible = false;
  @override void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => visible = true);
    });
  }
  @override Widget build(BuildContext context) => AnimatedOpacity(
    opacity: visible ? 1 : 0,
    duration: const Duration(milliseconds: 520),
    curve: Curves.easeOutCubic,
    child: AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, .12),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: visible ? 1 : .96,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    ),
  );
}

Route<T> motionRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 420),
  reverseTransitionDuration: const Duration(milliseconds: 300),
  pageBuilder: (_, animation, _) => page,
  transitionsBuilder: (_, animation, _, child) {
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(.05, .03), end: Offset.zero).animate(curve),
        child: child,
      ),
    );
  },
);

class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 10});
  final Color color;
  final double size;
  @override State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, _) => Container(
      width: widget.size + 8 * controller.value,
      height: widget.size + 8 * controller.value,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: .15 + .1 * controller.value),
      ),
      alignment: Alignment.center,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    ),
  );
}
