// Generates assets/logo_icon.png: the Tower logo centered on a 1152x1152
// transparent canvas with padding, so it fits inside the circular/rounded mask
// that Android applies to adaptive launcher icons and the Android 12 splash.
//
// Run: dart run tool/make_icon.dart
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final src = img.decodeImage(File('assets/Logo.PNG').readAsBytesSync());
  if (src == null) {
    stderr.writeln('Could not decode assets/Logo.PNG');
    exit(1);
  }

  const canvas = 1152; // recommended icon canvas
  const safe = 660; // keep the logo within the inner ~57% safe zone

  final scale = safe / src.width < safe / src.height
      ? safe / src.width
      : safe / src.height;
  final w = (src.width * scale).round();
  final h = (src.height * scale).round();

  final resized = img.copyResize(src,
      width: w, height: h, interpolation: img.Interpolation.cubic);

  final out = img.Image(width: canvas, height: canvas, numChannels: 4);
  // (image 4.x fills a new RGBA image with transparent pixels by default.)

  img.compositeImage(out, resized,
      dstX: (canvas - w) ~/ 2, dstY: (canvas - h) ~/ 2);

  File('assets/logo_icon.png').writeAsBytesSync(img.encodePng(out));
  stdout.writeln('Wrote assets/logo_icon.png ($w x $h logo on $canvas canvas)');
}
