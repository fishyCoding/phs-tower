import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';

import '../models/vanguard.dart';

/// Shared camera math for the Vanguard guided viewer and its author tool.
///
/// Convention: a page image is laid out at its intrinsic pixel size with its
/// top-left at (0,0), and the camera is a translate·rotate·scale [Matrix4]
/// mapping image pixels → viewport pixels. Rotation lets the reader's camera
/// turn a slanted paragraph upright.
///
/// Stops are stored aspect-independently, normalized by image *width* (so both
/// axes share one unit and rotation stays true): center (cx,cy), half-extents
/// (hw,hh) measured in the rotated/screen frame, and rotation [rot] in radians.

class VanguardCamera {
  final double cx, cy; // image-pixel point shown at the viewport center
  final double scale;
  final double rot; // radians applied to the image

  const VanguardCamera(this.cx, this.cy, this.scale, this.rot);

  Matrix4 toMatrix(Size viewport) => Matrix4.identity()
    ..translateByDouble(viewport.width / 2, viewport.height / 2, 0, 1)
    ..rotateZ(rot)
    ..scaleByDouble(scale, scale, scale, 1)
    ..translateByDouble(-cx, -cy, 0, 1);

  /// Center lerps linearly, scale geometrically (constant-speed zoom), rotation
  /// along the shortest arc.
  static VanguardCamera lerp(VanguardCamera a, VanguardCamera b, double t) =>
      VanguardCamera(
        lerpDouble(a.cx, b.cx, t)!,
        lerpDouble(a.cy, b.cy, t)!,
        a.scale * math.pow(b.scale / a.scale, t).toDouble(),
        a.rot + _shortestAngle(a.rot, b.rot) * t,
      );

  /// Recover a camera from a translate·rotate·scale matrix (e.g. the author's
  /// live gesture matrix).
  factory VanguardCamera.fromMatrix(Matrix4 m, Size viewport) {
    final s = m.getMaxScaleOnAxis();
    final rot = math.atan2(m.storage[1], m.storage[0]); // atan2(m10, m00)
    final inv = Matrix4.inverted(m);
    final c = MatrixUtils.transformPoint(
        inv, Offset(viewport.width / 2, viewport.height / 2));
    return VanguardCamera(c.dx, c.dy, s, rot);
  }
}

/// Camera that frames [stop] fully visible and centered in [viewport]
/// (contain), rotating the page by the stop's angle. [imageWidth] is the
/// rendered page width in pixels.
VanguardCamera cameraForStop(Size viewport, double imageWidth, VanguardStop s) {
  final hw = s.hw * imageWidth;
  final hh = s.hh * imageWidth;
  final scale = math.min(viewport.width / (2 * hw), viewport.height / (2 * hh));
  return VanguardCamera(s.cx * imageWidth, s.cy * imageWidth, scale, s.rot);
}

/// Full-page overview framing (no rotation).
VanguardCamera overviewCamera(Size viewport, Size imageSize) {
  final scale = math.min(
      viewport.width / imageSize.width, viewport.height / imageSize.height);
  return VanguardCamera(
      imageSize.width / 2, imageSize.height / 2, scale, 0);
}

/// The region the viewport currently shows, as a storable stop. Inverse of
/// [cameraForStop]: works for any translate·rotate·scale matrix.
VanguardStop captureStop(Matrix4 m, Size viewport, double imageWidth) {
  final s = m.getMaxScaleOnAxis();
  final rot = math.atan2(m.storage[1], m.storage[0]);
  final inv = Matrix4.inverted(m);
  final c = MatrixUtils.transformPoint(
      inv, Offset(viewport.width / 2, viewport.height / 2));
  return VanguardStop(
    cx: c.dx / imageWidth,
    cy: c.dy / imageWidth,
    hw: (viewport.width / 2) / s / imageWidth,
    hh: (viewport.height / 2) / s / imageWidth,
    rot: rot,
  );
}

/// Animation duration scaled by pan distance, zoom ratio, and rotation.
Duration cameraMoveDuration(VanguardCamera from, VanguardCamera to) {
  final panScreen = (Offset(to.cx, to.cy) - Offset(from.cx, from.cy)).distance *
      math.min(from.scale, to.scale);
  final zoom = math.log(to.scale / from.scale).abs();
  final turn = _shortestAngle(from.rot, to.rot).abs();
  final ms =
      (450 + 0.35 * panScreen + 250 * zoom + 260 * turn).clamp(450, 1100).round();
  return Duration(milliseconds: ms);
}

double _shortestAngle(double a, double b) {
  var d = (b - a) % (2 * math.pi);
  if (d > math.pi) d -= 2 * math.pi;
  if (d < -math.pi) d += 2 * math.pi;
  return d;
}
