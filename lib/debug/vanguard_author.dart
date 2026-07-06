import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../vanguard/camera.dart';

/// Debug-only authoring tool for Vanguard camera paths.
///
/// Workflow: add each page by pasting its Supabase Storage URL, pan/pinch to
/// frame a region exactly as readers should see it, tap "Add stop" — repeat in
/// reading order — then export the `pages` JSON to the clipboard and paste it
/// into the `vanguard.pages` column in Supabase. Tapping a stop in the list
/// re-frames it (a live round-trip check of the capture math).
class VanguardAuthorScreen extends StatefulWidget {
  const VanguardAuthorScreen({super.key});

  @override
  State<VanguardAuthorScreen> createState() => _VanguardAuthorScreenState();
}

class _AuthorPage {
  final String url;
  final Size size;
  final List<Rect> stops = [];
  _AuthorPage(this.url, this.size);
}

class _VanguardAuthorScreenState extends State<VanguardAuthorScreen> {
  final List<_AuthorPage> _pages = [];
  int _current = 0;
  final _controller = TransformationController();
  Size _viewport = Size.zero;
  bool _loadingPage = false;

  static const _blue = Color(0xFF072636);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── pages ───────────────────────────────────────────────────────────────────

  Future<void> _promptAddPage() async {
    final urlController = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Paste the page image URL…',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Keep page scans ≤ 4096 px on the long edge — larger images can '
              'render blank on some devices.',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, urlController.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    await _addPage(url);
  }

  Future<void> _addPage(String url) async {
    setState(() => _loadingPage = true);
    try {
      final size = await _resolveImageSize(url);
      if (!mounted) return;
      setState(() {
        _pages.add(_AuthorPage(url, size));
        _current = _pages.length - 1;
        _loadingPage = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitPage());
      if (size.longestSide > 4096 && mounted) {
        _toast(
            '⚠️ ${size.width.toInt()}×${size.height.toInt()} exceeds 4096 px — '
            'may render blank on some devices.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPage = false);
      _toast('Could not load that image URL.');
    }
  }

  Future<Size> _resolveImageSize(String url) {
    final completer = Completer<Size>();
    final stream = CachedNetworkImageProvider(url)
        .resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) {
          completer.complete(Size(
              info.image.width.toDouble(), info.image.height.toDouble()));
        }
        stream.removeListener(listener);
      },
      onError: (error, _) {
        if (!completer.isCompleted) completer.completeError(error);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  void _fitPage() {
    if (_pages.isEmpty || _viewport == Size.zero) return;
    final page = _pages[_current];
    _controller.value =
        overviewCamera(_viewport, page.size).toMatrix(_viewport);
  }

  void _selectPage(int i) {
    setState(() => _current = i);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitPage());
  }

  // ── stops ───────────────────────────────────────────────────────────────────

  void _addStop() {
    if (_pages.isEmpty || _viewport == Size.zero) return;
    final page = _pages[_current];
    final rect =
        captureNormalized(_controller.value, _viewport, page.size);
    setState(() => page.stops.add(rect));
  }

  void _previewStop(Rect rect) {
    final page = _pages[_current];
    _controller.value =
        cameraForRect(_viewport, page.size, rect).toMatrix(_viewport);
  }

  // ── export ──────────────────────────────────────────────────────────────────

  double _round4(double v) => (v * 10000).round() / 10000;

  void _export() {
    if (_pages.isEmpty) return;
    final data = {
      'pages': [
        for (final p in _pages)
          {
            'image': p.url,
            'width': p.size.width,
            'height': p.size.height,
            'stops': [
              for (final r in p.stops)
                {
                  'x': _round4(r.left),
                  'y': _round4(r.top),
                  'w': _round4(r.width),
                  'h': _round4(r.height),
                }
            ],
          }
      ],
    };
    Clipboard.setData(ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert(data['pages'])));
    _toast('Pages JSON copied — paste into the vanguard.pages column.');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Vanguard Author',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Fit page',
            icon: const Icon(Icons.fit_screen_outlined),
            onPressed: _fitPage,
          ),
          IconButton(
            tooltip: 'Copy pages JSON',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _export,
          ),
        ],
      ),
      floatingActionButton: _pages.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              onPressed: _addStop,
              icon: const Icon(Icons.center_focus_strong_outlined),
              label: const Text('Add stop'),
            ),
      body: _pages.isEmpty ? _buildEmpty() : _buildAuthor(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_stories_outlined,
                size: 48, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 14),
            const Text(
              'Add each page of the issue (in order), frame each paragraph '
              'by pan & pinch, and tap "Add stop". Export copies the pages '
              'JSON for the vanguard table.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
              ),
              onPressed: _loadingPage ? null : _promptAddPage,
              icon: _loadingPage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add page'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthor() {
    final page = _pages[_current];
    return Column(
      children: [
        // Page selector
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (var i = 0; i < _pages.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                  child: ChoiceChip(
                    label: Text('Page ${i + 1}'),
                    selected: _current == i,
                    onSelected: (_) => _selectPage(i),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: ActionChip(
                  avatar: _loadingPage
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add, size: 16),
                  label: const Text('Add page'),
                  onPressed: _loadingPage ? null : _promptAddPage,
                ),
              ),
            ],
          ),
        ),
        // Canvas
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewport = Size(constraints.maxWidth, constraints.maxHeight);
              return Container(
                color: Colors.black,
                child: ClipRect(
                  child: InteractiveViewer(
                    transformationController: _controller,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    minScale: 0.01,
                    maxScale: 10,
                    child: SizedBox(
                      width: page.size.width,
                      height: page.size.height,
                      child: CachedNetworkImage(
                        imageUrl: page.url,
                        fit: BoxFit.fill,
                        fadeInDuration: Duration.zero,
                        placeholder: (_, __) =>
                            Container(color: const Color(0xFF1A1A1A)),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Stops list
        Container(
          height: 180,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Text(
                      'Stops on page ${_current + 1} (${page.stops.length})',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    const Text(
                      'Tap to preview · drag to reorder',
                      style:
                          TextStyle(fontSize: 11, color: Color(0xFF999999)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: page.stops.isEmpty
                    ? const Center(
                        child: Text(
                          'Frame a region, then tap "Add stop".',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF999999)),
                        ),
                      )
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: true,
                        itemCount: page.stops.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final r = page.stops.removeAt(oldIndex);
                            page.stops.insert(newIndex, r);
                          });
                        },
                        itemBuilder: (context, i) {
                          final r = page.stops[i];
                          return ListTile(
                            key: ValueKey('stop-$_current-$i-${r.hashCode}'),
                            dense: true,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: _blue,
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white)),
                            ),
                            title: Text(
                              'x ${_round4(r.left)}  y ${_round4(r.top)}  '
                              'w ${_round4(r.width)}  h ${_round4(r.height)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () => _previewStop(r),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Color(0xFFA31621)),
                              onPressed: () =>
                                  setState(() => page.stops.removeAt(i)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
