import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vanguard.dart';
import '../vanguard/camera.dart';

/// Fullscreen guided pan-and-zoom reader for a Vanguard issue.
///
/// The camera visits each authored stop in order (page 1's stops, then
/// page 2's, …) and finishes on a full-page overview. One gesture = one step:
/// swipe up / tap / scroll down / arrow keys advance, swipe down / scroll up
/// goes back. At the overview the reader can enter free pinch-zoom explore.
class VanguardViewerScreen extends StatefulWidget {
  final VanguardIssue issue;
  const VanguardViewerScreen({super.key, required this.issue});

  @override
  State<VanguardViewerScreen> createState() => _VanguardViewerScreenState();
}

/// One entry in the flattened stop sequence.
class _Entry {
  final int page;
  final Rect rect; // normalized region of the page image
  final bool overview;
  const _Entry(this.page, this.rect, {this.overview = false});
}

class _VanguardViewerScreenState extends State<VanguardViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final CurvedAnimation _curved =
      CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic);

  late final List<_Entry> _entries;

  int _index = 0;
  int? _target; // entry being animated toward
  VanguardCamera? _fromOverride; // set when gliding back out of free explore
  bool _freeMode = false;
  bool _ready = false;
  bool _precacheStarted = false;
  final Set<int> _precachedPages = {};

  Size _viewport = Size.zero;
  final _freeController = TransformationController();

  double _dragAccum = 0;
  double _wheelAccum = 0;
  DateTime _lastWheel = DateTime.fromMillisecondsSinceEpoch(0);

  // First-open hint, suppressed for the rest of the session once seen.
  static bool _hintSeen = false;
  bool _hintVisible = !_hintSeen;
  Timer? _hintTimer;

  List<VanguardPage> get _pages => widget.issue.pages;
  int get _stopCount => _entries.length - 1; // excludes the overview entry

  @override
  void initState() {
    super.initState();
    _entries = [
      for (var p = 0; p < _pages.length; p++)
        for (final s in _pages[p].stops)
          _Entry(p, Rect.fromLTWH(s.x, s.y, s.w, s.h)),
      if (_pages.isNotEmpty)
        _Entry(_pages.length - 1, const Rect.fromLTWH(0, 0, 1, 1),
            overview: true),
    ];

    _anim.addStatusListener((status) {
      if (status == AnimationStatus.completed && _target != null) {
        setState(() {
          _index = _target!;
          _target = null;
          _fromOverride = null;
        });
        _precacheUpcomingPage();
      }
    });

    _hintTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precacheStarted && _pages.isNotEmpty) {
      _precacheStarted = true;
      precacheImage(
        CachedNetworkImageProvider(_pages.first.image),
        context,
        onError: (_, __) {},
      ).then((_) {
        if (mounted) setState(() => _ready = true);
      });
      _precachedPages.add(0);
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _curved.dispose();
    _anim.dispose();
    _freeController.dispose();
    super.dispose();
  }

  // ── camera helpers ──────────────────────────────────────────────────────────

  VanguardCamera _cameraOf(int i) {
    final e = _entries[i];
    final page = _pages[e.page];
    return cameraForRect(_viewport, Size(page.width, page.height), e.rect);
  }

  /// Decode the next page's image while the reader dwells on the last stop of
  /// the current page, so the crossfade lands on ready pixels.
  void _precacheUpcomingPage() {
    if (_index + 1 >= _entries.length) return;
    final nextPage = _entries[_index + 1].page;
    if (nextPage != _entries[_index].page && _precachedPages.add(nextPage)) {
      precacheImage(
        CachedNetworkImageProvider(_pages[nextPage].image),
        context,
        onError: (_, __) {},
      );
    }
  }

  // ── stepping ────────────────────────────────────────────────────────────────

  void _step(int dir) {
    if (!_ready || _freeMode || _anim.isAnimating || _viewport == Size.zero) {
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
    // Glide from wherever the reader wandered back to the overview framing.
    final cam = VanguardCamera.fromMatrix(_freeController.value, _viewport);
    setState(() {
      _freeMode = false;
      _fromOverride = cam;
      _target = _index;
    });
    _anim.duration = const Duration(milliseconds: 500);
    _anim.forward(from: 0);
  }

  // ── input ───────────────────────────────────────────────────────────────────

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -250 || _dragAccum < -60) {
      _step(1); // swipe up → next
    } else if (v > 250 || _dragAccum > 60) {
      _step(-1); // swipe down → previous
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

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty || _entries.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: const Center(
          child: Text('This issue has no pages yet.',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
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
                onPointerSignal: _freeMode ? null : _onPointerSignal,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _freeMode ? null : () => _step(1),
                  onVerticalDragUpdate:
                      _freeMode ? null : (d) => _dragAccum += d.delta.dy,
                  onVerticalDragEnd: _freeMode ? null : _onDragEnd,
                  child: Stack(
                    children: [
                      if (!_ready)
                        const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white54))
                      else if (_freeMode)
                        _buildFreeExplore()
                      else
                        _buildGuided(),
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

  /// Guided mode: page layers driven by the animation controller.
  Widget _buildGuided() {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final layers = <Widget>[];
        if (_anim.isAnimating && _target != null) {
          final t = _curved.value;
          final fromE = _entries[_index];
          final toE = _entries[_target!];
          final camFrom = _fromOverride ?? _cameraOf(_index);
          final camTo = _cameraOf(_target!);
          if (fromE.page == toE.page) {
            final cam = VanguardCamera.lerp(camFrom, camTo, t);
            layers.add(_pageLayer(fromE.page, cam, 1));
          } else {
            // Crossfade: outgoing holds its framing, incoming arrives already
            // framed at its target stop.
            layers.add(_pageLayer(fromE.page, camFrom, 1 - t));
            layers.add(_pageLayer(toE.page, camTo, t));
          }
        } else {
          layers.add(_pageLayer(_entries[_index].page, _cameraOf(_index), 1));
        }
        return Stack(children: layers);
      },
    );
  }

  Widget _pageLayer(int pageIndex, VanguardCamera cam, double opacity) {
    final page = _pages[pageIndex];
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
              child: _pageImage(page),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageImage(VanguardPage page) => SizedBox(
        width: page.width,
        height: page.height,
        child: CachedNetworkImage(
          imageUrl: page.image,
          fit: BoxFit.fill,
          fadeInDuration: Duration.zero,
          placeholder: (_, __) => Container(color: const Color(0xFF1A1A1A)),
          errorWidget: (_, __, ___) => Container(
            color: const Color(0xFF1A1A1A),
            child: const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white24, size: 64),
            ),
          ),
        ),
      );

  /// Free explore at the overview: same page, same coordinate convention, so
  /// the handoff from the guided Transform is seamless.
  Widget _buildFreeExplore() {
    final page = _pages[_entries[_index].page];
    return Positioned.fill(
      child: ClipRect(
        child: InteractiveViewer(
          transformationController: _freeController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.01,
          maxScale: 4.0,
          child: _pageImage(page),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final logical = _target ?? _index;
    final atOverview = _entries[logical].overview;
    final String counter;
    if (_freeMode) {
      counter = 'Explore';
    } else if (atOverview) {
      counter = 'Overview';
    } else {
      counter = '${logical + 1} / $_stopCount';
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
          Positioned(
            right: 12,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                counter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Bottom-center affordance: first-open hint, explore invitation at
          // the overview, or the way back out of free explore.
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(child: _bottomPill(atOverview)),
          ),
        ],
      ),
    );
  }

  Widget _bottomPill(bool atOverview) {
    if (_freeMode) {
      return _PillButton(
        icon: Icons.undo,
        label: 'Back to overview',
        onTap: _exitFreeMode,
      );
    }
    if (atOverview && !_anim.isAnimating) {
      return _PillButton(
        icon: Icons.pinch_outlined,
        label: 'Pinch & explore',
        onTap: _enterFreeMode,
      );
    }
    if (_hintVisible && _index == 0 && _target == null) {
      return AnimatedOpacity(
        opacity: _hintVisible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
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
