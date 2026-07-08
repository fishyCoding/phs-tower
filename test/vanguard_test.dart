import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:ph_tower/models/vanguard.dart';
import 'package:ph_tower/vanguard/camera.dart';

void main() {
  const viewport = Size(400, 800);
  const imageSize = Size(1980, 3060);
  const w = 1980.0;

  group('cameraForStop', () {
    test('centers the region and contains it', () {
      const s = VanguardStop(cx: 0.3, cy: 0.4, hw: 0.2, hh: 0.15);
      final cam = cameraForStop(viewport, w, s);
      expect(cam.cx, closeTo(0.3 * w, 0.001));
      expect(cam.cy, closeTo(0.4 * w, 0.001));
      expect(cam.rot, 0);
      // Contain: the tighter axis binds. hw=0.2*1980=396 → vw/(2*396)=0.505;
      // hh=0.15*1980=297 → vh/(2*297)=1.347; min = width axis.
      expect(cam.scale, closeTo(viewport.width / (2 * 0.2 * w), 0.0001));
    });

    test('overview frames the whole page, unrotated', () {
      final cam = overviewCamera(viewport, imageSize);
      expect(cam.rot, 0);
      expect(cam.scale, closeTo(viewport.width / imageSize.width, 0.0001));
    });
  });

  group('captureStop round-trip', () {
    void roundTrip(VanguardStop s) {
      final m = cameraForStop(viewport, w, s).toMatrix(viewport);
      final back = captureStop(m, viewport, w);

      // Center and rotation reproduce exactly.
      expect(back.cx, closeTo(s.cx, 0.0001));
      expect(back.cy, closeTo(s.cy, 0.0001));
      expect(back.rot, closeTo(s.rot, 0.0001));
      // The binding axis (width, given these extents) matches; the other is
      // expanded to fill the viewport (contain).
      expect(back.hw, closeTo(s.hw, 0.0001));
      expect(back.hh, greaterThanOrEqualTo(s.hh - 0.0001));
      // Re-framing the captured stop yields the same camera.
      final c1 = cameraForStop(viewport, w, s);
      final c2 = cameraForStop(viewport, w, back);
      expect(c2.scale, closeTo(c1.scale, 0.0001));
      expect(c2.rot, closeTo(c1.rot, 0.0001));
      expect(c2.cx, closeTo(c1.cx, 0.001));
      expect(c2.cy, closeTo(c1.cy, 0.001));
    }

    test('unrotated region', () {
      roundTrip(const VanguardStop(cx: 0.3, cy: 0.4, hw: 0.2, hh: 0.15));
    });

    test('rotated region preserves the angle', () {
      roundTrip(const VanguardStop(cx: 0.5, cy: 0.7, hw: 0.2, hh: 0.15, rot: 0.6));
    });
  });

  group('VanguardCamera', () {
    test('lerp: geometric scale, shortest-arc rotation', () {
      const a = VanguardCamera(0, 0, 1, 0);
      final b = VanguardCamera(100, 100, 4, math.pi / 2);
      final mid = VanguardCamera.lerp(a, b, 0.5);
      expect(mid.scale, closeTo(2.0, 0.0001)); // sqrt(1*4)
      expect(mid.cx, closeTo(50, 0.0001));
      expect(mid.rot, closeTo(math.pi / 4, 0.0001));
    });

    test('fromMatrix inverts toMatrix, including rotation', () {
      const cam = VanguardCamera(990, 1530, 0.42, 0.6);
      final back = VanguardCamera.fromMatrix(cam.toMatrix(viewport), viewport);
      expect(back.cx, closeTo(cam.cx, 0.001));
      expect(back.cy, closeTo(cam.cy, 0.001));
      expect(back.scale, closeTo(cam.scale, 0.0001));
      expect(back.rot, closeTo(cam.rot, 0.0001));
    });
  });

  group('Spread.fromMap', () {
    test('parses a full row with an authored camera path', () {
      final spread = Spread.fromMap({
        'id': 51,
        'title': 'Vanguard Presents: Generation Gap ',
        'month': 4,
        'year': 2026,
        'src': 'https://example.com/gen-gap.pdf#pages=2',
        'camera_path': [
          [
            {'cx': 0.3, 'cy': 0.4, 'hw': 0.2, 'hh': 0.15, 'rot': 0.0},
            {'cx': 0.5, 'cy': 0.7, 'hw': 0.25, 'hh': 0.2, 'rot': 1.57},
          ],
          [],
        ],
      });
      expect(spread.id, 51);
      expect(spread.title, 'Vanguard Presents: Generation Gap'); // trimmed
      expect(spread.pdfUrl, 'https://example.com/gen-gap.pdf'); // fragment gone
      expect(spread.hasValidSrc, isTrue);
      expect(spread.hasGuidedPath, isTrue);
      expect(spread.cameraPath!.length, 2);
      expect(spread.cameraPath![0].length, 2);
      expect(spread.cameraPath![0][1].rot, closeTo(1.57, 0.0001));
      expect(spread.cameraPath![1], isEmpty);
    });

    test('null camera_path → no guided path', () {
      final spread = Spread.fromMap({
        'id': 1,
        'title': 'X',
        'src': 'https://example.com/x.pdf',
      });
      expect(spread.cameraPath, isNull);
      expect(spread.hasGuidedPath, isFalse);
    });

    test('empty stops on every page → not a guided path', () {
      final spread = Spread.fromMap({
        'id': 1,
        'src': 'https://example.com/x.pdf',
        'camera_path': [[], []],
      });
      expect(spread.hasGuidedPath, isFalse);
    });

    test('accepts a {"stops": [...]} page wrapper', () {
      final spread = Spread.fromMap({
        'id': 1,
        'src': 'https://example.com/x.pdf',
        'camera_path': [
          {
            'stops': [
              {'cx': 0.4, 'cy': 0.6, 'hw': 0.2, 'hh': 0.2, 'rot': -0.3},
            ],
          },
        ],
      });
      final stop = spread.cameraPath!.single.single;
      expect(stop.cx, closeTo(0.4, 0.0001));
      expect(stop.rot, closeTo(-0.3, 0.0001));
    });

    test('a title in the src column is treated as invalid', () {
      final spread = Spread.fromMap({
        'id': 6,
        'title': '2021–2022 School Year Club Recap',
        'src': '2021–2022 School Year Club Recap',
        'month': 6,
        'year': 2022,
      });
      expect(spread.hasValidSrc, isFalse);
    });
  });
}
