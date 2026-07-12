import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vanguard.dart';
import '../vanguard/camera.dart';
import '../vanguard/pdf_pages.dart';

/// Debug-only tool for authoring a spread's guided-camera path.
///
/// Opens the spread's PDF, renders its pages, and lets you frame each region by
/// pan / pinch-zoom / two-finger-rotate (or the 90° buttons) and capture it as
/// a stop in reading order. Export copies the `camera_path` JSON to paste into
/// that row's `camera_path` column in the `spreads` table.
class VanguardAuthorScreen extends StatefulWidget {
  final String src;
  final String title;
  const VanguardAuthorScreen(
      {super.key, required this.src, required this.title});

  @override
  State<VanguardAuthorScreen> createState() => _VanguardAuthorScreenState();
}

class _VanguardAuthorScreenState extends State<VanguardAuthorScreen> {
  List<RenderedPage>? _pages;
  String? _error;
  int _current = 0;
  final List<List<VanguardStop>> _stops = [];

  Matrix4 _matrix = Matrix4.identity();
  Matrix4 _startMatrix = Matrix4.identity();
  Offset _startFocal = Offset.zero;
  Size _viewport = Size.zero;
  // The viewport size the page was last fit to — re-fit when it changes
  // (e.g. on rotation) or on page switch (reset to zero).
  Size _fittedFor = Size.zero;

  static const _blue = Color(0xFF072636);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pages = await renderSpreadPages(widget.src.split('#').first);
      if (!mounted) return;
      if (pages.isEmpty) {
        setState(() => _error = 'Could not render this PDF.');
        return;
      }
      setState(() {
        _pages = pages;
        _stops.clear();
        _stops.addAll(List.generate(pages.length, (_) => <VanguardStop>[]));
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load this PDF.\n\n$e');
    }
  }

  Size get _pageSize => Size(_pages![_current].width, _pages![_current].height);

  void _fitPage() {
    if (_pages == null || _viewport == Size.zero) return;
    setState(() =>
        _matrix = overviewCamera(_viewport, _pageSize).toMatrix(_viewport));
  }

  void _selectPage(int i) {
    setState(() {
      _current = i;
      _fittedFor = Size.zero; // force a re-fit for the new page
    });
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startMatrix = _matrix.clone();
    _startFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final f = d.localFocalPoint;
    final g = Matrix4.identity()
      ..translateByDouble(f.dx, f.dy, 0, 1)
      ..rotateZ(d.rotation)
      ..scaleByDouble(d.scale, d.scale, 1, 1)
      ..translateByDouble(-_startFocal.dx, -_startFocal.dy, 0, 1);
    setState(() => _matrix = g.multiplied(_startMatrix));
  }

  void _rotate90(int dir) {
    if (_viewport == Size.zero) return;
    final vc = Offset(_viewport.width / 2, _viewport.height / 2);
    final g = Matrix4.identity()
      ..translateByDouble(vc.dx, vc.dy, 0, 1)
      ..rotateZ(dir * math.pi / 2)
      ..translateByDouble(-vc.dx, -vc.dy, 0, 1);
    setState(() => _matrix = g.multiplied(_matrix));
  }

  void _addStop() {
    if (_pages == null || _viewport == Size.zero) return;
    setState(() => _stops[_current]
        .add(captureStop(_matrix, _viewport, _pageSize.width)));
  }

  void _previewStop(VanguardStop s) {
    setState(() =>
        _matrix = cameraForStop(_viewport, _pageSize.width, s).toMatrix(_viewport));
  }

  double _r(double v) => (v * 10000).round() / 10000;
  int _deg(double rad) => (rad * 180 / math.pi).round();

  void _export() {
    if (_pages == null) return;
    final data = [
      for (final page in _stops)
        [
          for (final s in page)
            {
              'cx': _r(s.cx),
              'cy': _r(s.cy),
              'hw': _r(s.hw),
              'hh': _r(s.hh),
              'rot': _r(s.rot),
            }
        ]
    ];
    Clipboard.setData(ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert(data)));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:
          Text('camera_path JSON copied — paste into spreads.camera_path.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(widget.title.isEmpty ? 'Author path' : widget.title,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          if (_pages != null) ...[
            IconButton(
                tooltip: 'Fit page',
                icon: const Icon(Icons.fit_screen_outlined),
                onPressed: _fitPage),
            IconButton(
                tooltip: 'Copy camera_path JSON',
                icon: const Icon(Icons.copy_all_outlined),
                onPressed: _export),
          ],
        ],
      ),
      floatingActionButton: _pages == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              onPressed: _addStop,
              icon: const Icon(Icons.center_focus_strong_outlined),
              label: const Text('Add stop'),
            ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _pages == null
              ? const Center(child: CircularProgressIndicator())
              : _buildAuthor(),
    );
  }

  Widget _buildAuthor() {
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final chips = _pages!.length > 1 ? _pageChips() : null;

    if (landscape) {
      // Canvas on the left, stops panel down the right side.
      return Row(
        children: [
          Expanded(
            child: Column(
              children: [
                if (chips != null) chips,
                Expanded(child: _canvas()),
              ],
            ),
          ),
          Container(
            width: 300,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xFFE0E0E0))),
            ),
            child: _stopsPanel(),
          ),
        ],
      );
    }

    // Portrait: canvas fills, stops panel across the bottom.
    return Column(
      children: [
        if (chips != null) chips,
        Expanded(child: _canvas()),
        Container(
          height: 176,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
          ),
          child: _stopsPanel(),
        ),
      ],
    );
  }

  Widget _pageChips() => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (var i = 0; i < _pages!.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                child: ChoiceChip(
                  label: Text('Page ${i + 1}  (${_stops[i].length})'),
                  selected: _current == i,
                  onSelected: (_) => _selectPage(i),
                ),
              ),
          ],
        ),
      );

  Widget _canvas() => LayoutBuilder(
        builder: (context, constraints) {
          _viewport = Size(constraints.maxWidth, constraints.maxHeight);
          if (_viewport != _fittedFor && _viewport != Size.zero) {
            _fittedFor = _viewport;
            _matrix = overviewCamera(_viewport, _pageSize).toMatrix(_viewport);
          }
          return Container(
            color: Colors.black,
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  child: ClipRect(
                    // OverflowBox → the page lays out at its full intrinsic
                    // size (not clamped to the canvas), so the camera matrix and
                    // captureStop share the same 1682×2600 image space the
                    // reader uses. Without this the SizedBox is squeezed to the
                    // canvas and every captured stop is shrunk toward (0,0).
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: 0,
                      minHeight: 0,
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: Transform(
                        transform: _matrix,
                        child: SizedBox(
                          width: _pageSize.width,
                          height: _pageSize.height,
                          child: Image.memory(_pages![_current].bytes,
                              fit: BoxFit.fill, gaplessPlayback: true),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      _RoundBtn(
                          icon: Icons.rotate_left,
                          onTap: () => _rotate90(-1)),
                      const SizedBox(height: 10),
                      _RoundBtn(
                          icon: Icons.rotate_right,
                          onTap: () => _rotate90(1)),
                    ],
                  ),
                ),
                if (kDebugMode && _viewport != Size.zero)
                  Positioned(left: 8, top: 8, child: _authorHud()),
              ],
            ),
          );
        },
      );

  /// Debug: live readout of the page size and what [captureStop] would record
  /// for the current framing — so author-side numbers can be compared with the
  /// reader's HUD to catch a page-dimension / normalization mismatch.
  Widget _authorHud() {
    final s = captureStop(_matrix, _viewport, _pageSize.width);
    final text = 'page ${_pageSize.width.toStringAsFixed(0)}×'
        '${_pageSize.height.toStringAsFixed(0)}\n'
        'view ${_viewport.width.toStringAsFixed(0)}×'
        '${_viewport.height.toStringAsFixed(0)}\n'
        'cx ${s.cx.toStringAsFixed(3)}  cy ${s.cy.toStringAsFixed(3)}\n'
        'hw ${s.hw.toStringAsFixed(3)}  hh ${s.hh.toStringAsFixed(3)}\n'
        'rot ${(s.rot * 57.29578).toStringAsFixed(0)}°';
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

  Widget _stopsPanel() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text('Stops on page ${_current + 1}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Text('tap · drag',
                    style:
                        TextStyle(fontSize: 11, color: Color(0xFF999999))),
              ],
            ),
          ),
          Expanded(
            child: _stops[_current].isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Frame a region, then tap "Add stop".',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF999999))),
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _stops[_current].length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final s = _stops[_current].removeAt(oldIndex);
                        _stops[_current].insert(newIndex, s);
                      });
                    },
                    itemBuilder: (context, i) {
                      final s = _stops[_current][i];
                      return ListTile(
                        key: ValueKey('s-$_current-$i-${s.hashCode}'),
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: _blue,
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white)),
                        ),
                        title: Text(
                          'c ${_r(s.cx)},${_r(s.cy)}  '
                          'h ${_r(s.hw)}×${_r(s.hh)}  ${_deg(s.rot)}°',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => _previewStop(s),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Color(0xFFA31621)),
                          onPressed: () =>
                              setState(() => _stops[_current].removeAt(i)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
            color: Colors.black54, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
