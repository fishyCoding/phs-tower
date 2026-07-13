import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Wraps the app so an animated splash plays once over it on cold start, then
/// fades out to reveal [child] (the main app).
class SplashGate extends StatefulWidget {
  final Widget child;
  const SplashGate({super.key, required this.child});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_done)
          _SplashOverlay(
            onDone: () {
              if (mounted) setState(() => _done = true);
            },
          ),
      ],
    );
  }
}

/// The animation: the logo fills the screen centered, then shrinks and moves
/// off-centre (left) as "The Tower" (in the masthead font) pops in beside it —
/// then the whole lockup fades out to the app.
class _SplashOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _SplashOverlay({required this.onDone});

  @override
  State<_SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<_SplashOverlay>
    with SingleTickerProviderStateMixin {
  // Logo aspect (width / height), from assets/Logo.PNG.
  static const double _logoAspect = 660.0 / 495.0;
  static const double _smallH = 84.0;
  static const double _gap = 10.0;
  static const double _textW = 200.0; // estimate for "The Tower" @ 44px
  static const double _fontSize = 44.0;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  late final Animation<double> _shrink =
      _curve(0.00, 0.50, Curves.easeInOutCubic);
  late final Animation<double> _textFade = _curve(0.52, 0.74, Curves.easeOut);
  late final Animation<double> _fadeOut = _curve(0.86, 1.00, Curves.easeIn);

  Animation<double> _curve(double a, double b, Curve c) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: c));

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const smallW = _smallH * _logoAspect;

    return AbsorbPointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Opacity(
            opacity: 1 - _fadeOut.value,
            // Material gives the Text a proper ancestor (no yellow underline)
            // and paints the white background.
            child: Material(
              color: Colors.white,
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final h = c.maxHeight;
                  final cy = h / 2;

                  // Final lockup (small logo + gap + text) centered on screen.
                  const total = smallW + _gap + _textW;
                  final lockupLeft = (w - total) / 2;
                  final logoCX1 = lockupLeft + smallW / 2; // settled centre
                  final logoCX0 = w / 2; // starts screen-centred

                  // Start scale: fill the screen (contain the whole logo).
                  final bigScale = math.min(w / smallW, h / _smallH);

                  final p = _shrink.value;
                  final scale = lerpDouble(bigScale, 1.0, p)!;
                  final logoCX = lerpDouble(logoCX0, logoCX1, p)!;

                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // Logo: centred at (logoCX, cy), scaled about its centre.
                      Positioned(
                        left: logoCX - smallW / 2,
                        top: cy - _smallH / 2,
                        child: Transform.scale(
                          scale: scale,
                          child: Image.asset('assets/Logo.PNG',
                              height: _smallH, fit: BoxFit.contain),
                        ),
                      ),
                      // "The Tower" pops in at the lockup text position.
                      Positioned(
                        left: lockupLeft + smallW + _gap,
                        top: cy - _fontSize * 0.72,
                        child: Opacity(
                          opacity: _textFade.value,
                          child: const Text(
                            'The Tower',
                            style: TextStyle(
                              fontFamily: 'Canterbury',
                              fontSize: _fontSize,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
