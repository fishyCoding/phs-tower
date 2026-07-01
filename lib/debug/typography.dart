import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Flip to `true` to show the live typography tuning panel again.
const bool kTypographyPanelEnabled = false;

// ─────────────────────────────────────────────────────────────────────────────
// Font registry — every headline in the app is drawn with one of these.
// GoogleFonts.* methods all share a compatible signature, so we can store them
// behind this narrowed typedef and call them uniformly.
// ─────────────────────────────────────────────────────────────────────────────

typedef GFont = TextStyle Function({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  double? letterSpacing,
  double? height,
});

final Map<String, GFont> kHeadlineFonts = {
  'Gelasio': GoogleFonts.gelasio,
  'Lora': GoogleFonts.lora,
  'Spectral': GoogleFonts.spectral,
  'Fraunces': GoogleFonts.fraunces,
  'Playfair Display': GoogleFonts.playfairDisplay,
  'Instrument Serif': GoogleFonts.instrumentSerif,
  'Cormorant Garamond': GoogleFonts.cormorantGaramond,
  'DM Serif Display': GoogleFonts.dmSerifDisplay,
  'EB Garamond': GoogleFonts.ebGaramond,
  'Libre Baskerville': GoogleFonts.libreBaskerville,
  'Bitter': GoogleFonts.bitter,
  'Noto Serif': GoogleFonts.notoSerif,
};

// ─────────────────────────────────────────────────────────────────────────────
// Controller + scope
// ─────────────────────────────────────────────────────────────────────────────

class TypographyController extends ChangeNotifier {
  // Baked-in app headline style (chosen via the debug panel).
  String fontKey = 'DM Serif Display';
  double sizeScale = 1.10; // multiplies each headline's base size
  FontWeight weight = FontWeight.w200;
  double letterSpacing = 0.0;
  double height = 1.00; // line spacing

  void update({
    String? fontKey,
    double? sizeScale,
    FontWeight? weight,
    double? letterSpacing,
    double? height,
  }) {
    if (fontKey != null) this.fontKey = fontKey;
    if (sizeScale != null) this.sizeScale = sizeScale;
    if (weight != null) this.weight = weight;
    if (letterSpacing != null) this.letterSpacing = letterSpacing;
    if (height != null) this.height = height;
    notifyListeners();
  }

  void reset() {
    fontKey = 'DM Serif Display';
    sizeScale = 1.10;
    weight = FontWeight.w200;
    letterSpacing = 0.0;
    height = 1.00;
    notifyListeners();
  }

  String get summary =>
      '$fontKey · ${sizeScale.toStringAsFixed(2)}× · w${weight.value}'
      ' · ls ${letterSpacing.toStringAsFixed(1)} · lh ${height.toStringAsFixed(2)}';
}

/// The single app-wide controller.
final TypographyController typography = TypographyController();

/// Makes [typography] available to descendants and rebuilds dependents (via
/// [headline]) whenever it changes — including routes pushed onto the Navigator,
/// since the scope sits above it.
class TypographyScope extends InheritedNotifier<TypographyController> {
  const TypographyScope({
    super.key,
    required TypographyController controller,
    required super.child,
  }) : super(notifier: controller);

  static TypographyController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TypographyScope>();
    return scope?.notifier ?? typography;
  }
}

/// Builds a headline TextStyle from the live typography settings. [size] is the
/// headline's natural size and gets scaled; weight / spacing / line-height come
/// from the panel so they stay uniform across the app.
TextStyle headline(BuildContext context, {required double size, Color? color}) {
  final t = TypographyScope.of(context);
  final font = kHeadlineFonts[t.fontKey] ?? GoogleFonts.gelasio;
  return font(
    fontSize: size * t.sizeScale,
    fontWeight: t.weight,
    letterSpacing: t.letterSpacing,
    height: t.height,
    color: color,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Debug panel overlay
// ─────────────────────────────────────────────────────────────────────────────

class TypographyDebugPanel extends StatefulWidget {
  const TypographyDebugPanel({super.key});

  @override
  State<TypographyDebugPanel> createState() => _TypographyDebugPanelState();
}

class _TypographyDebugPanelState extends State<TypographyDebugPanel> {
  bool _open = false;

  static const _blue = Color(0xFF072636);

  // Root is an Align (a plain widget), not a Positioned, and the panel is built
  // only from primitives (Container / Text / Icon / GestureDetector) — none of
  // which need a Material/Localizations ancestor, so it renders correctly when
  // hosted directly in MaterialApp.builder.
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 96),
          child: _open ? _panel() : _fab(),
        ),
      ),
    );
  }

  Widget _fab() => GestureDetector(
        onTap: () => setState(() => _open = true),
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: _blue,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          alignment: Alignment.center,
          child: const Text('Aa',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
        ),
      );

  Widget _panel() => AnimatedBuilder(
        animation: typography,
        builder: (context, _) {
          final t = typography;
          final fonts = kHeadlineFonts.keys.toList();
          final idx = fonts.indexOf(t.fontKey);
          return Container(
            width: 300,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0E0E0)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 16,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Typography',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _blue)),
                    const Spacer(),
                    GestureDetector(
                      onTap: typography.reset,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('Reset',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFFA31621))),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _open = false),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close,
                            size: 18, color: Color(0xFF888888)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Font cycler
                _cycler(
                  label: 'Font',
                  value: t.fontKey,
                  onPrev: () => typography.update(
                      fontKey: fonts[(idx - 1 + fonts.length) % fonts.length]),
                  onNext: () => typography.update(
                      fontKey: fonts[(idx + 1) % fonts.length]),
                ),
                _MiniSlider(
                  label: 'Size',
                  display: '${t.sizeScale.toStringAsFixed(2)}×',
                  value: t.sizeScale,
                  min: 0.6,
                  max: 1.8,
                  onChanged: (v) => typography.update(sizeScale: v),
                ),
                _MiniSlider(
                  label: 'Weight',
                  display: 'w${t.weight.value}',
                  value: (t.weight.value / 100).toDouble(),
                  min: 1,
                  max: 9,
                  divisions: 8,
                  onChanged: (v) => typography.update(
                      weight: FontWeight.values[v.round() - 1]),
                ),
                _MiniSlider(
                  label: 'Char spacing',
                  display: t.letterSpacing.toStringAsFixed(1),
                  value: t.letterSpacing,
                  min: -2,
                  max: 6,
                  onChanged: (v) => typography.update(letterSpacing: v),
                ),
                _MiniSlider(
                  label: 'Line height',
                  display: t.height.toStringAsFixed(2),
                  value: t.height,
                  min: 0.9,
                  max: 2.2,
                  onChanged: (v) => typography.update(height: v),
                ),
                const SizedBox(height: 8),
                Text(t.summary,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF888888))),
              ],
            ),
          );
        },
      );

  Widget _cycler({
    required String label,
    required String value,
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    Widget chip(IconData icon, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: _blue),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 84,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))),
          chip(Icons.chevron_left, onPrev),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: _blue, fontWeight: FontWeight.w600)),
          ),
          chip(Icons.chevron_right, onNext),
        ],
      ),
    );
  }
}

/// Lightweight slider built from primitives (no Material dependency).
class _MiniSlider extends StatelessWidget {
  final String label;
  final String display;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _MiniSlider({
    required this.label,
    required this.display,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });

  double _quantize(double v) {
    v = v.clamp(min, max);
    if (divisions == null) return v;
    final step = (max - min) / divisions!;
    return min + ((v - min) / step).round() * step;
  }

  @override
  Widget build(BuildContext context) {
    const trackColor = Color(0xFFE0E0E0);
    const activeColor = Color(0xFF072636);
    final frac = ((value.clamp(min, max) - min) / (max - min));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(display,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF888888))),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              void handle(double dx) {
                final f = (dx / w).clamp(0.0, 1.0);
                onChanged(_quantize(min + f * (max - min)));
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => handle(d.localPosition.dx),
                onPanUpdate: (d) => handle(d.localPosition.dx),
                child: SizedBox(
                  height: 22,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 9.5,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                              color: trackColor,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 9.5,
                        child: Container(
                          width: (w * frac).clamp(0.0, w),
                          height: 3,
                          decoration: BoxDecoration(
                              color: activeColor,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      Positioned(
                        left: (w * frac - 7).clamp(0.0, w - 14),
                        top: 4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                              color: activeColor, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
