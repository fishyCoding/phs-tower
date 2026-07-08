import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:pdfx/pdfx.dart';

/// A single PDF page rasterized to PNG bytes, plus its rendered pixel size.
class RenderedPage {
  final Uint8List bytes;
  final double width, height;
  const RenderedPage(this.bytes, this.width, this.height);
}

/// Downloads a spread PDF (cached on disk via flutter_cache_manager, shared
/// with the image cache) and renders every page to an image.
///
/// [maxLongEdge] caps raster resolution: high enough that zoomed text stays
/// legible, low enough to stay under the ~4096 px GPU texture limit and keep
/// memory reasonable for a two-page spread.
Future<List<RenderedPage>> renderSpreadPages(
  String pdfUrl, {
  double maxLongEdge = 2600,
}) async {
  final file = await DefaultCacheManager().getSingleFile(pdfUrl);
  final doc = await PdfDocument.openFile(file.path);
  final pages = <RenderedPage>[];
  final int count = doc.pagesCount;
  Object? lastRenderError;
  try {
    for (var i = 1; i <= count; i++) {
      final page = await doc.getPage(i);
      try {
        final pw = page.width, ph = page.height;
        if (pw <= 0 || ph <= 0) continue;
        final double w, h;
        if (pw >= ph) {
          w = maxLongEdge;
          h = maxLongEdge * ph / pw;
        } else {
          h = maxLongEdge;
          w = maxLongEdge * pw / ph;
        }
        final img = await page.render(
          width: w,
          height: h,
          format: PdfPageImageFormat.png,
        );
        if (img != null) pages.add(RenderedPage(img.bytes, w, h));
      } catch (e) {
        lastRenderError = e;
        debugPrint('Vanguard: page $i render failed: $e');
      } finally {
        await page.close();
      }
    }
  } finally {
    await doc.close();
  }
  if (pages.isEmpty) {
    throw StateError(
        'Rendered 0 of $count page(s)${lastRenderError != null ? ' — $lastRenderError' : ''}');
  }
  return pages;
}
