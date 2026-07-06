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

  group('VanguardIssue.fromMap', () {
    test('parses a full row', () {
      final issue = VanguardIssue.fromMap({
        'id': 3,
        'title': 'Generation Gap',
        'month': 4,
        'year': 2026,
        'pages': [
          {
            'image': 'https://example.com/p1.png',
            'width': 1980,
            'height': 3060,
            'stops': [
              {'x': 0.05, 'y': 0.03, 'w': 0.4, 'h': 0.25},
              {'x': 0.5, 'y': 0.6, 'w': 0.45, 'h': 0.3},
            ],
          },
          {
            'image': 'https://example.com/p2.png',
            'width': 3960,
            'height': 3060,
            'stops': [],
          },
        ],
      });
      expect(issue.id, 3);
      expect(issue.title, 'Generation Gap');
      expect(issue.pages.length, 2);
      expect(issue.pages[0].stops.length, 2);
      expect(issue.pages[0].stops[1].x, closeTo(0.5, 0.0001));
      expect(issue.pages[1].width, 3960);
      expect(issue.pages[1].stops, isEmpty);
    });

    test('defaults missing fields safely and clamps stops', () {
      final issue = VanguardIssue.fromMap({
        'id': 1,
        'pages': [
          {
            'stops': [
              {'x': -0.5, 'y': 2.0, 'w': 1.5},
            ],
          },
        ],
      });
      expect(issue.title, '');
      expect(issue.pages.single.image, '');
      final stop = issue.pages.single.stops.single;
      expect(stop.x, 0.0); // clamped
      expect(stop.y, 1.0); // clamped
      expect(stop.w, 1.0); // clamped
      expect(stop.h, 0.0); // missing → 0
    });

    test('round-trips through toMap', () {
      const page = VanguardPage(
        image: 'https://example.com/p.png',
        width: 100,
        height: 200,
        stops: [VanguardStop(x: 0.1, y: 0.2, w: 0.3, h: 0.4)],
      );
      final back = VanguardPage.fromMap(page.toMap());
      expect(back.image, page.image);
      expect(back.stops.single.w, closeTo(0.3, 0.0001));
    });
  });
}
