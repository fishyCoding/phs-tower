import 'package:flutter/material.dart';

/// Wraps [child] with an animated left-to-right shimmer sweep. Give the child
/// opaque shapes (e.g. grey blocks); the highlight sweeps across wherever the
/// child paints. Light-theme friendly by default.
class Shimmer extends StatefulWidget {
  final Widget child;
  final Color base;
  final Color highlight;

  const Shimmer({
    super.key,
    required this.child,
    this.base = const Color(0xFFDCDCDC),
    this.highlight = const Color(0xFFF4F4F4),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [widget.base, widget.highlight, widget.base],
            stops: const [0.25, 0.5, 0.75],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            transform: _SlideTransform(_c.value),
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

class _SlideTransform extends GradientTransform {
  final double t; // 0..1
  const _SlideTransform(this.t);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // Sweep the highlight from off-screen left to off-screen right.
    return Matrix4.translationValues((t * 2 - 1) * bounds.width, 0, 0);
  }
}
