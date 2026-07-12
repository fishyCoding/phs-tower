import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vanguard.dart';
import '../vanguard/camera.dart';
import '../vanguard/pdf_pages.dart';
import '../widgets/shimmer.dart';

/// Fullscreen reader for a Vanguard spread (a 2-page print PDF).
///
/// If the spread has an authored camera path, the camera visits each stop in
/// reading order (one gesture = one step, animated pan+zoom) then zooms out to
/// an overview with free explore. Otherwise the reader gets plain pinch-zoom
/// over the rendered pages.
class VanguardViewerScreen extends StatefulWidget {
  final Spread spread;
  const VanguardViewerScreen({super.key, required this.spread});

  @override
  State<VanguardViewerScreen> createState() => _VanguardViewerScreenState();
}

class _Entry {
  final int page;
  final VanguardStop? stop; // null for the overview entry
  final bool overview;
  const _Entry(this.page, {this.stop, this.overview = false});
}

class _VanguardViewerScreenState extends State<VanguardViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final CurvedAnimation _curved =
      CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic);

  List<RenderedPage>? _pages;
  String? _error;
  List<_Entry> _entries = const [];

  int _index = 0;
  int? _target;
  VanguardCamera? _fromOverride;
  bool _freeMode = false;

  Size _viewport = Size.zero;
  final _freeController = TransformationController();
  bool _freeInit = false;

  double _dragAccum = 0;
  double _wheelAccum = 0;
  DateTime _lastWheel = DateTime.fromMillisecondsSinceEpoch(0);

  static bool _hintSeen = false;
  bool _hintVisible = !_hintSeen;
  Timer? _hintTimer;

  bool get _guided => _entries.isNotEmpty;
  int get _stopCount => _entries.isEmpty ? 0 : _entries.length - 1;

  @override
  void initState() {
    super.initState();
    _load();
    _anim.addStatusListener((status) {
      if (status == AnimationStatus.completed && _target != null) {
        setState(() {
          _index = _target!;
          _target = null;
          _fromOverride = null;
        });
      }
    });
    _hintTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }

  Future<void> _load() async {
    if (!widget.spread.hasValidSrc) {
      setState(() => _error = 'This spread has no valid PDF.');
      return;
    }
    try {
      final pages = await renderSpreadPages(widget.spread.pdfUrl);
      if (!mounted) return;
      if (pages.isEmpty) {
        setState(() => _error = 'Could not render this PDF.');
        return;
      }
      setState(() {
        _pages = pages;
        _entries = _buildEntries(pages);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = kDebugMode
            ? 'Could not load this PDF.\n\n$e'
            : 'Could not load this PDF.');
      }
    }
  }

  /// Flatten the authored path into a stop sequence + a final overview entry.
  /// Returns empty (→ free mode) when the spread has no path.
  List<_Entry> _buildEntries(List<RenderedPage> pages) {
    final path = widget.spread.cameraPath;
    if (path == null || !widget.spread.hasGuidedPath) return const [];
    final entries = <_Entry>[];
    for (var p = 0; p < path.length && p < pages.length; p++) {
      for (final s in path[p]) {
        entries.add(_Entry(p, stop: s));
      }
    }
    if (entries.isEmpty) return const [];
    entries.add(_Entry(pages.length - 1, overview: true));
    return entries;
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _curved.dispose();
    _anim.dispose();
    _freeController.dispose();
    super.dispose();
  }

  Size _pageSize(int i) => Size(_pages![i].width, _pages![i].height);

  VanguardCamera _cameraOf(int i) {
    final e = _entries[i];
    if (e.overview || e.stop == null) {
      return overviewCamera(_viewport, _pageSize(e.page));
    }
    return cameraForStop(_viewport, _pages![e.page].width, e.stop!);
  }

  // ── stepping (guided) ─────────────────────────────────────────────────────

  void _step(int dir) {
    if (!_guided || _freeMode || _anim.isAnimating || _viewport == Size.zero) {
      return;
    }
    final next = _index + dir;
    if (next >= _entries.length) {
      _enterFreeMode();
      return;
    }
    if (next < 0) return;

    if (_hintVisible) {
      _hintSeen = true;
      _hintVisible = false;
    }

    final from = _cameraOf(_index);
    final to = _cameraOf(next);
    final crossPage = _entries[_index].page != _entries[next].page;
    _anim.duration = crossPage
        ? const Duration(milliseconds: 650)
        : cameraMoveDuration(from, to);
    setState(() => _target = next);
    _anim.forward(from: 0);
  }

  void _enterFreeMode() {
    _freeController.value = _cameraOf(_index).toMatrix(_viewport);
    setState(() => _freeMode = true);
  }

  void _exitFreeMode() {
    final cam = VanguardCamera.fromMatrix(_freeController.value, _viewport);
    setState(() {
      _freeMode = false;
      _fromOverride = cam;
      _target = _index;
    });
    _anim.duration = const Duration(milliseconds: 500);
    _anim.forward(from: 0);
  }

  // ── input ─────────────────────────────────────────────────────────────────

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -250 || _dragAccum < -60) {
      _step(1);
    } else if (v > 250 || _dragAccum > 60) {
      _step(-1);
    }
    _dragAccum = 0;
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || _freeMode || _anim.isAnimating) return;
    final now = DateTime.now();
    if (now.difference(_lastWheel) > const Duration(milliseconds: 250)) {
      _wheelAccum = 0;
    }
    _lastWheel = now;
    _wheelAccum += e.scrollDelta.dy;
    if (_wheelAccum.abs() > 40) {
      _step(_wheelAccum > 0 ? 1 : -1);
      _wheelAccum = 0;
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5C4326), // wood-brown fallback
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _step(1),
          const SingleActivator(LogicalKeyboardKey.pageDown): () => _step(1),
          const SingleActivator(LogicalKeyboardKey.space): () => _step(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _step(-1),
          const SingleActivator(LogicalKeyboardKey.pageUp): () => _step(-1),
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewport = Size(constraints.maxWidth, constraints.maxHeight);
              return Listener(
                onPointerSignal:
                    (_guided && !_freeMode) ? _onPointerSignal : null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (_guided && !_freeMode) ? () => _step(1) : null,
                  onVerticalDragUpdate: (_guided && !_freeMode)
                      ? (d) => _dragAccum += d.delta.dy
                      : null,
                  onVerticalDragEnd:
                      (_guided && !_freeMode) ? _onDragEnd : null,
                  child: Stack(
                    children: [
                      // Wooden desk the pages lie on.
                      Positioned.fill(
                        child: Image.asset('assets/wood.jpg',
                            fit: BoxFit.cover),
                      ),
                      _buildContent(),
                      _buildOverlay(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 80, 28, 28),
          child: SelectableText(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF666666), fontSize: 13)),
        ),
      );
    }
    if (_pages == null) return const _VanguardLoading();
    if (!_guided || _freeMode) return _buildFree();
    return _buildGuided();
  }

  Widget _pageImage(int i) => Container(
        width: _pages![i].width,
        height: _pages![i].height,
        // A soft drop shadow so the page reads as paper resting on the desk.
        // (Shadow is in image space, so it scales with the zoom — subtle at the
        // overview, out of frame when zoomed into a paragraph.)
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Color(0x66000000),
                blurRadius: 90,
                spreadRadius: 6,
                offset: Offset(0, 30)),
          ],
        ),
        child: Image.memory(_pages![i].bytes,
            fit: BoxFit.fill, gaplessPlayback: true),
      );

  // Guided mode: page layers driven by the animation controller. The wooden
  // desk lives inside the same camera transform so it scrolls/zooms with the
  // pages.
  Widget _buildGuided() {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final layers = <Widget>[];
        int markerPage;
        VanguardCamera markerCam;
        if (_anim.isAnimating && _target != null) {
          final t = _curved.value;
          final fromE = _entries[_index];
          final toE = _entries[_target!];
          final camFrom = _fromOverride ?? _cameraOf(_index);
          final camTo = _cameraOf(_target!);
          final samePage = fromE.page == toE.page;
          if (samePage) {
            final cam = VanguardCamera.lerp(camFrom, camTo, t);
            layers.add(_woodLayer(fromE.page, cam));
            layers.add(_pageLayer(fromE.page, cam, 1));
            markerPage = fromE.page;
            markerCam = cam;
          } else {
            // The desk follows the destination framing (its motion is hidden
            // behind the opaque pages during the crossfade).
            layers.add(_woodLayer(toE.page, camTo));
            layers.add(_pageLayer(fromE.page, camFrom, 1 - t));
            layers.add(_pageLayer(toE.page, camTo, t));
            markerPage = toE.page;
            markerCam = camTo;
          }
        } else {
          final cam = _cameraOf(_index);
          layers.add(_woodLayer(_entries[_index].page, cam));
          layers.add(_pageLayer(_entries[_index].page, cam, 1));
          markerPage = _entries[_index].page;
          markerCam = cam;
        }
        if (kDebugMode) layers.add(_debugStopsLayer(markerPage, markerCam));
        return Stack(children: layers);
      },
    );
  }

  /// A large tiled wooden surface, centred on the page and transformed by the
  /// same [cam] as the page, so panning/zooming moves the desk with the paper.
  Widget _woodLayer(int page, VanguardCamera cam) {
    final pw = _pages![page].width;
    final ph = _pages![page].height;
    const k = 4.0; // desk extends well beyond the page on every side
    final ww = pw * k;
    final wh = ph * k;
    return Positioned.fill(
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform(
            transform: cam.toMatrix(_viewport),
            child: Transform.translate(
              offset: Offset(-(ww - pw) / 2, -(wh - ph) / 2),
              child: Container(
                width: ww,
                height: wh,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/wood.jpg'),
                    repeat: ImageRepeat.repeat,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Debug: numbered red dots at each stop's centre on [page], transformed by
  /// the same [cam] as the page. At a stop, that stop's dot should sit exactly
  /// at the screen centre.
  Widget _debugStopsLayer(int page, VanguardCamera cam) {
    final path = widget.spread.cameraPath;
    if (path == null || page >= path.length) return const SizedBox.shrink();
    final pw = _pages![page].width;
    final ph = _pages![page].height;
    final stops = path[page];
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform(
              transform: cam.toMatrix(_viewport),
              child: SizedBox(
                width: pw,
                height: ph,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var j = 0; j < stops.length; j++)
                      Positioned(
                        left: stops[j].cx * pw - 45,
                        top: stops[j].cy * pw - 45,
                        child: Container(
                          width: 90,
                          height: 90,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0x88FF0000),
                            shape: BoxShape.circle,
                          ),
                          child: Text('${j + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageLayer(int pageIndex, VanguardCamera cam, double opacity) {
    return Positioned.fill(
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform(
              transform: cam.toMatrix(_viewport),
              child: _pageImage(pageIndex),
            ),
          ),
        ),
      ),
    );
  }

  /// Free pinch-zoom over the whole spread (fallback, and the guided overview's
  /// explore mode). Pages are stacked vertically as one pannable canvas.
  Widget _buildFree() {
    final contentWidth =
        _pages!.map((p) => p.width).reduce((a, b) => a > b ? a : b);
    final contentHeight =
        _pages!.fold<double>(0, (s, p) => s + p.height);
    if (!_freeInit && _viewport != Size.zero) {
      _freeInit = true;
      final scale = _viewport.width / contentWidth;
      _freeController.value = Matrix4.identity()..scaleByDouble(scale, scale, scale, 1);
    }
    const k = 3.0;
    return ClipRect(
      child: InteractiveViewer(
        transformationController: _freeController,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.05,
        maxScale: 6.0,
        // Stack sizes to the pages column; the wooden desk extends around it
        // (Clip.none) and pans/zooms with it.
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -contentWidth * (k - 1) / 2,
              top: -contentHeight * (k - 1) / 2,
              width: contentWidth * k,
              height: contentHeight * k,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/wood.jpg'),
                    repeat: ImageRepeat.repeat,
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _pages!.length; i++) _pageImage(i),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final String? counter;
    if (_pages == null || _error != null) {
      counter = null;
    } else if (!_guided) {
      counter = null; // free-only spread: no step counter
    } else if (_freeMode) {
      counter = 'Explore';
    } else {
      final logical = _target ?? _index;
      counter = _entries[logical].overview
          ? 'Overview'
          : '${logical + 1} / $_stopCount';
    }

    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 8,
            child: _CircleButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          if (counter != null)
            Positioned(
              right: 12,
              top: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(counter,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(child: _bottomPill()),
          ),
          if (kDebugMode && _pages != null && _entries.isNotEmpty)
            Positioned(left: 8, top: 56, child: _debugHud()),
        ],
      ),
    );
  }

  /// Debug-only readout of the active stop + page/viewport dimensions so the
  /// reader's numbers can be compared against what was authored.
  Widget _debugHud() {
    final e = _entries[(_target ?? _index).clamp(0, _entries.length - 1)];
    final pageW = _pages![e.page].width;
    final pageH = _pages![e.page].height;
    final s = e.stop;
    final text = 'page ${e.page}  ${pageW.toStringAsFixed(0)}×'
        '${pageH.toStringAsFixed(0)}\n'
        'view ${_viewport.width.toStringAsFixed(0)}×'
        '${_viewport.height.toStringAsFixed(0)}\n'
        '${s == null ? 'OVERVIEW' : 'cx ${s.cx.toStringAsFixed(3)}  '
            'cy ${s.cy.toStringAsFixed(3)}\n'
            'hw ${s.hw.toStringAsFixed(3)}  hh ${s.hh.toStringAsFixed(3)}\n'
            'rot ${(s.rot * 57.29578).toStringAsFixed(0)}°'}';
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                height: 1.35,
                fontFamily: 'monospace')),
      ),
    );
  }

  Widget _bottomPill() {
    if (!_guided || _pages == null || _error != null) {
      return const SizedBox.shrink();
    }
    final atOverview = _entries[_target ?? _index].overview;
    if (_freeMode) {
      return _PillButton(
          icon: Icons.undo, label: 'Back to overview', onTap: _exitFreeMode);
    }
    if (atOverview && !_anim.isAnimating) {
      return _PillButton(
          icon: Icons.pinch_outlined,
          label: 'Pinch & explore',
          onTap: _enterFreeMode);
    }
    if (_hintVisible && _index == 0 && _target == null) {
      return AnimatedOpacity(
        opacity: _hintVisible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.black54, borderRadius: BorderRadius.circular(20)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Swipe up to read',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration:
            const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PillButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// A shimmering newspaper-page skeleton (kicker, headline, photo, text lines)
/// on a white sheet with a drop shadow — shown while a spread's PDF renders.
class _VanguardLoading extends StatelessWidget {
  const _VanguardLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, c) {
          // Portrait page silhouette that fits within the viewport.
          var pw = (c.maxWidth * 0.66).clamp(150.0, 440.0);
          var ph = pw * 1.3;
          if (ph > c.maxHeight * 0.84) {
            ph = c.maxHeight * 0.84;
            pw = ph / 1.3;
          }
          final pad = pw * 0.09;
          final contentW = pw - pad * 2;

          Widget bar(double widthFactor, double height) => Container(
                width: contentW * widthFactor,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBDBDB),
                  borderRadius: BorderRadius.circular(3),
                ),
              );

          return Container(
            width: pw,
            height: ph,
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x59000000),
                    blurRadius: 34,
                    spreadRadius: 2,
                    offset: Offset(0, 16)),
              ],
            ),
            child: Shimmer(
              base: const Color(0xFFD8D8D8),
              highlight: const Color(0xFFEFEFEF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(0.32, 10), // kicker
                  const SizedBox(height: 14),
                  bar(1.0, 18), // headline
                  const SizedBox(height: 7),
                  bar(0.68, 18),
                  const SizedBox(height: 18),
                  // Photo block.
                  Container(
                    width: contentW,
                    height: ph * 0.26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBDBDB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final f in const [1.0, 0.97, 1.0, 0.92, 1.0, 0.5]) ...[
                    bar(f, 8),
                    const SizedBox(height: 9),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
