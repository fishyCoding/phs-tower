/// A single camera stop: a normalized (0–1) rectangle of a page image, in
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

/// One page of a Vanguard issue: the page-scan image plus its ordered stops.
/// [width]/[height] are the image's intrinsic pixel dimensions, stored in the
/// data so framing can be computed before the network image resolves.
class VanguardPage {
  final String image;
  final double width, height;
  final List<VanguardStop> stops;

  const VanguardPage({
    required this.image,
    required this.width,
    required this.height,
    required this.stops,
  });

  factory VanguardPage.fromMap(Map<String, dynamic> map) => VanguardPage(
        image: map['image'] as String? ?? '',
        width: (map['width'] as num?)?.toDouble() ?? 0,
        height: (map['height'] as num?)?.toDouble() ?? 0,
        stops: (map['stops'] as List? ?? [])
            .map((s) => VanguardStop.fromMap(Map<String, dynamic>.from(s)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'image': image,
        'width': width,
        'height': height,
        'stops': stops.map((s) => s.toMap()).toList(),
      };
}

/// A Vanguard issue: ordered pages, published per month/year like app_layout.
class VanguardIssue {
  final int id;
  final String title;
  final int month, year;
  final List<VanguardPage> pages;

  const VanguardIssue({
    required this.id,
    required this.title,
    required this.month,
    required this.year,
    required this.pages,
  });

  factory VanguardIssue.fromMap(Map<String, dynamic> map) => VanguardIssue(
        id: map['id'] as int? ?? 0,
        title: map['title'] as String? ?? '',
        month: map['month'] as int? ?? 0,
        year: map['year'] as int? ?? 0,
        // Supabase returns jsonb columns already decoded.
        pages: (map['pages'] as List? ?? [])
            .map((p) => VanguardPage.fromMap(Map<String, dynamic>.from(p)))
            .toList(),
      );
}
