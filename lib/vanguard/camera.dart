import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

/// Shared camera math for the Vanguard guided viewer and its author tool.
///
/// Convention: a page image is laid out at its intrinsic pixel size with its
/// top-left at the viewport's top-left, and the camera is a pure
/// translate·scale [Matrix4] mapping image pixels → viewport pixels. Both the
/// viewer's Transform and the author tool's InteractiveViewer share this
/// convention, so matrices can be handed between them directly.

/// Camera state over a page image: the image-space point at the viewport
/// center, plus the zoom scale.
class VanguardCamera {
  final double cx, cy, scale;
  const VanguardCamera(this.cx, this.cy, this.scale);

  /// Center lerps linearly; scale lerps geometrically (log-space) so zooms
  /// feel constant-speed instead of crawl-then-rush.
  static VanguardCamera lerp(VanguardCamera a, VanguardCamera b, double t) =>
      VanguardCamera(
        lerpDouble(a.cx, b.cx, t)!,
        lerpDouble(a.cy, b.cy, t)!,
        a.scale * math.pow(b.scale / a.scale, t).toDouble(),
      );

  Matrix4 toMatrix(Size viewport) => Matrix4.identity()
    ..translateByDouble(viewport.width / 2 - scale * cx,
        viewport.height / 2 - scale * cy, 0, 1)
    ..scaleByDouble(scale, scale, scale, 1);

  /// Inverse of [toMatrix]: recover a camera from a pure translate·scale
  /// matrix (e.g. an InteractiveViewer's controller value).
  factory VanguardCamera.fromMatrix(Matrix4 m, Size viewport) {
    final s = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    return VanguardCamera(
      (viewport.width / 2 - t.x) / s,
      (viewport.height / 2 - t.y) / s,
      s,
    );
  }
}

/// Camera that frames [norm] — a normalized (0–1) rect of the image — fully
/// visible and centered in [viewport] (contain; letterboxed as needed).
VanguardCamera cameraForRect(Size viewport, Size imageSize, Rect norm) {
  final rw = norm.width * imageSize.width;
  final rh = norm.height * imageSize.height;
  final s = math.min(viewport.width / rw, viewport.height / rh);
  return VanguardCamera(
    (norm.left + norm.width / 2) * imageSize.width,
    (norm.top + norm.height / 2) * imageSize.height,
    s,
  );
}

/// Full-page overview framing.
VanguardCamera overviewCamera(Size viewport, Size imageSize) =>
    cameraForRect(viewport, imageSize, const Rect.fromLTWH(0, 0, 1, 1));

/// Inverse of the framing: the normalized region of the image the viewport
/// currently shows. [m] must be pure translate·scale (no rotation) — which is
/// what InteractiveViewer produces. Clamped into the image bounds.
Rect captureNormalized(Matrix4 m, Size viewport, Size imageSize) {
  final s = m.getMaxScaleOnAxis();
  final t = m.getTranslation();
  final w = math.min(viewport.width / s / imageSize.width, 1.0);
  final h = math.min(viewport.height / s / imageSize.height, 1.0);
  final left =
      (-t.x / s / imageSize.width).clamp(0.0, math.max(0.0, 1.0 - w)).toDouble();
  final top = (-t.y / s / imageSize.height)
      .clamp(0.0, math.max(0.0, 1.0 - h))
      .toDouble();
  return Rect.fromLTWH(left, top, w, h);
}

/// Animation duration scaled by how far the camera travels (screen-space pan
/// plus zoom ratio), clamped so short hops stay snappy and long jumps don't
/// drag.
Duration cameraMoveDuration(VanguardCamera from, VanguardCamera to) {
  final panScreen = (Offset(to.cx, to.cy) - Offset(from.cx, from.cy)).distance *
      math.min(from.scale, to.scale);
  final zoom = math.log(to.scale / from.scale).abs();
  final ms = (450 + 0.35 * panScreen + 250 * zoom).clamp(450, 950).round();
  return Duration(milliseconds: ms);
}
