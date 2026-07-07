import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:ph_tower/models/vanguard.dart';
import 'package:ph_tower/vanguard/camera.dart';

void main() {
  const viewport = Size(400, 800);
  const imageSize = Size(1980, 3060);

  group('cameraForRect', () {
    test('contains the rect and centers it', () {
      const rect = Rect.fromLTWH(0.1, 0.2, 0.4, 0.25);
      final cam = cameraForRect(viewport, imageSize, rect);

      // Center of the rect in image px.
      expect(cam.cx, closeTo((0.1 + 0.2) * imageSize.width, 0.001));
      expect(cam.cy, closeTo((0.2 + 0.125) * imageSize.height, 0.001));

      // Contain: scale is the limiting axis (width here).
      final rw = 0.4 * imageSize.width;
      final rh = 0.25 * imageSize.height;
      expect(cam.scale,
          closeTo(
              (viewport.width / rw) < (viewport.height / rh)
                  ? viewport.width / rw
                  : viewport.height / rh,
              0.0001));
    });

    test('overview frames the whole page', () {
      final cam = overviewCamera(viewport, imageSize);
      final m = cam.toMatrix(viewport);
      final visible = captureNormalized(m, viewport, imageSize);
      expect(visible.left, closeTo(0, 0.0001));
      expect(visible.top, closeTo(0, 0.0001));
      // The binding axis spans exactly the full image.
      expect(visible.width == 1.0 || visible.height == 1.0, isTrue);
    });
  });

  group('captureNormalized round-trip', () {
    test('framing a rect then capturing recovers a region containing it', () {
      const rect = Rect.fromLTWH(0.1, 0.2, 0.4, 0.25);
      final m = cameraForRect(viewport, imageSize, rect).toMatrix(viewport);
      final captured = captureNormalized(m, viewport, imageSize);

      // The captured viewport region must fully contain the authored rect
      // (equal on the binding axis, expanded/letterboxed on the other).
      expect(captured.left, lessThanOrEqualTo(rect.left + 0.0001));
      expect(captured.top, lessThanOrEqualTo(rect.top + 0.0001));
      expect(captured.right, greaterThanOrEqualTo(rect.right - 0.0001));
      expect(captured.bottom, greaterThanOrEqualTo(rect.bottom - 0.0001));

      // Shared center on both axes.
      expect(captured.center.dx, closeTo(rect.center.dx, 0.0001));
      expect(captured.center.dy, closeTo(rect.center.dy, 0.0001));

      // Binding axis width matches exactly.
      expect(captured.width, closeTo(rect.width, 0.0001));

      // Re-framing the captured rect reproduces the same camera.
      final cam1 = cameraForRect(viewport, imageSize, rect);
      final cam2 = cameraForRect(viewport, imageSize, captured);
      expect(cam2.cx, closeTo(cam1.cx, 0.001));
      expect(cam2.cy, closeTo(cam1.cy, 0.001));
      expect(cam2.scale, closeTo(cam1.scale, 0.0001));
    });
  });

  group('VanguardCamera', () {
    test('lerp is geometric in scale', () {
      const a = VanguardCamera(0, 0, 1);
      const b = VanguardCamera(100, 100, 4);
      final mid = VanguardCamera.lerp(a, b, 0.5);
      expect(mid.scale, closeTo(2.0, 0.0001)); // sqrt(1*4), not 2.5
      expect(mid.cx, closeTo(50, 0.0001));
    });

    test('fromMatrix inverts toMatrix', () {
      const cam = VanguardCamera(990, 1530, 0.42);
      final back = VanguardCamera.fromMatrix(cam.toMatrix(viewport), viewport);
      expect(back.cx, closeTo(cam.cx, 0.001));
      expect(back.cy, closeTo(cam.cy, 0.001));
      expect(back.scale, closeTo(cam.scale, 0.0001));
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
            {'x': 0.05, 'y': 0.03, 'w': 0.4, 'h': 0.25},
            {'x': 0.5, 'y': 0.6, 'w': 0.45, 'h': 0.3},
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
      expect(spread.cameraPath![0][1].x, closeTo(0.5, 0.0001));
      expect(spread.cameraPath![1], isEmpty);
    });

    test('null camera_path → no guided path', () {
      final spread = Spread.fromMap({
        'id': 1,
        'title': 'X',
        'month': 2,
        'year': 2025,
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

    test('accepts {"stops": [...]} page wrapper and clamps values', () {
      final spread = Spread.fromMap({
        'id': 1,
        'src': 'https://example.com/x.pdf',
        'camera_path': [
          {
            'stops': [
              {'x': -0.5, 'y': 2.0, 'w': 1.5},
            ],
          },
        ],
      });
      final stop = spread.cameraPath!.single.single;
      expect(stop.x, 0.0); // clamped
      expect(stop.y, 1.0); // clamped
      expect(stop.w, 1.0); // clamped
      expect(stop.h, 0.0); // missing → 0
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
