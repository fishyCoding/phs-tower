/// A single camera stop: a normalized (0–1) rectangle of a rendered page, in
/// reading order.
class VanguardStop {
  final double x, y, w, h;

  const VanguardStop({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory VanguardStop.fromMap(Map<String, dynamic> map) {
    double f(String key) =>
        ((map[key] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
    return VanguardStop(x: f('x'), y: f('y'), w: f('w'), h: f('h'));
  }

  Map<String, dynamic> toMap() => {'x': x, 'y': y, 'w': w, 'h': h};
}

/// A Vanguard spread: a print-page PDF (usually two pages) stored in the
/// `spreads` table. [src] is the PDF URL; pages are rendered to images at view
/// time. [cameraPath] — the optional authored guided-camera path — is a list of
/// pages, each a list of stops in reading order. When null/empty the reader
/// falls back to free pinch-zoom.
class Spread {
  final int id;
  final String title;
  final int month, year;
  final String src;
  final List<List<VanguardStop>>? cameraPath;

  const Spread({
    required this.id,
    required this.title,
    required this.month,
    required this.year,
    required this.src,
    this.cameraPath,
  });

  /// True when at least one page has authored stops.
  bool get hasGuidedPath =>
      cameraPath != null && cameraPath!.any((page) => page.isNotEmpty);

  /// The PDF URL with any `#fragment` (e.g. `#pages=2`) stripped — fragments
  /// are never sent to the server and trip up some loaders.
  String get pdfUrl => src.split('#').first;

  /// A src is only usable if it looks like a URL (some legacy rows stored a
  /// title in the src column).
  bool get hasValidSrc =>
      pdfUrl.startsWith('http://') || pdfUrl.startsWith('https://');

  factory Spread.fromMap(Map<String, dynamic> map) {
    List<List<VanguardStop>>? path;
    final raw = map['camera_path'];
    if (raw is List && raw.isNotEmpty) {
      path = raw.map<List<VanguardStop>>((page) {
        // Accept either a bare list of stops or a {"stops": [...]} wrapper.
        final stops = (page is Map ? page['stops'] : page) as List? ?? [];
        return stops
            .map((s) => VanguardStop.fromMap(Map<String, dynamic>.from(s)))
            .toList();
      }).toList();
    }
    return Spread(
      id: map['id'] as int? ?? 0,
      title: (map['title'] as String? ?? '').trim(),
      month: map['month'] as int? ?? 0,
      year: map['year'] as int? ?? 0,
      src: map['src'] as String? ?? '',
      cameraPath: path,
    );
  }
}
