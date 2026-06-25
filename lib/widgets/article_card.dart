import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/article.dart';
import '../screens/article_screen.dart';

// ── Category helpers ──────────────────────────────────────────────────────────

String _catLabel(String cat) {
  switch (cat.toLowerCase()) {
    case 'news-features': return 'News';
    case 'arts-entertainment': return 'Arts';
    case 'sports': return 'Sports';
    case 'opinions': return 'Opinions';
    default: return cat;
  }
}

String _minuteRead(String text) {
  if (text.trim().isEmpty) return '';
  final wordCount = text.trim().split(RegExp(r'\s+')).length;
  final minutes = (wordCount / 200).ceil();
  return '$minutes min read';
}

String _capitalizeFirstLine(String s) {
  final lines = s
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return '';
  lines[0] = lines[0].replaceAllMapped(
    RegExp(r'\S+'),
    (m) => '${m[0]![0].toUpperCase()}${m[0]!.substring(1)}',
  );
  return lines.join('\n');
}

// ── Shared palette (from the home-feed design) ────────────────────────────────

const _navy = Color(0xFF1A1A2E); // primary ink
const _gold = Color(0xFF715C00); // newspaper accent for eyebrow labels
const _cardBg = Color(0xFFF0F3FF); // surface-container-low
const _cardBorder = Color(0xFFE3E8F2); // outline-variant tint
const _meta = Color(0xFF666666); // on-surface-variant
const _dot = Color(0xFFBFC4CF); // separator dot

/// Eyebrow category label — uppercase, tracked, gold.
Widget _eyebrow(String category, {double size = 10, double tracking = 1.2}) {
  return Text(
    _catLabel(category).toUpperCase(),
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: tracking,
      color: _gold,
    ),
  );
}

/// Small navy "Latest" pill shown on current-issue articles.
Widget _latestPill({double fontSize = 10}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: _navy,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      'Latest',
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// ── Hero Article Card (featured — text above image, no overlay) ───────────────

class HeroArticleCard extends StatelessWidget {
  final Article article;
  final int latestYear;
  final int latestMonth;

  const HeroArticleCard({
    super.key,
    required this.article,
    required this.latestYear,
    required this.latestMonth,
  });

  @override
  Widget build(BuildContext context) {
    final isLatest =
        article.year == latestYear && article.month == latestMonth;

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ArticleScreen(articleId: article.id))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category eyebrow + issue tag
            Row(children: [
              _eyebrow(article.category, tracking: 1.4),
              if (isLatest) ...[
                const SizedBox(width: 10),
                _latestPill(),
              ],
            ]),
            const SizedBox(height: 14),
            // Title
            Text(
              article.title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _navy,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            // Author · read-time meta line
            _metaLine(article),
            const SizedBox(height: 20),
            // Image + caption wrapped in a bordered, shadowed card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _cardBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D002045), // ~5% navy
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: article.img.isNotEmpty
                        ? Image.network(
                            article.img,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(null),
                          )
                        : _placeholder(null),
                  ),
                  if (article.contentInfo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        _capitalizeFirstLine(article.contentInfo),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: _meta,
                          height: 1.6,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Author · read-time line, dot-separated, omitting whichever parts are absent.
  Widget _metaLine(Article article) {
    final parts = <String>[
      if (article.authors.isNotEmpty) article.authors.join(', '),
      _minuteRead(article.content.isNotEmpty
          ? article.content
          : article.contentInfo),
    ].where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: CircleAvatar(radius: 2, backgroundColor: _dot),
        ));
      }
      children.add(Text(
        parts[i],
        style: const TextStyle(fontSize: 13, color: _meta),
      ));
    }
    return Row(children: children);
  }

  Widget _placeholder([double? height]) => Container(
        height: height,
        decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
        child: const Center(
            child: Icon(Icons.image_not_supported,
                size: 36, color: Color(0xFFCCCCCC))),
      );
}

// ── Sidescroll Row (no boxes, vertical line separators, top-left text) ────────

class SidescrollRow extends StatelessWidget {
  final List<Article> articles;
  final int latestYear;
  final int latestMonth;

  const SidescrollRow({
    super.key,
    required this.articles,
    required this.latestYear,
    required this.latestMonth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          final isLatest =
              article.year == latestYear && article.month == latestMonth;
          return GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ArticleScreen(articleId: article.id))),
            child: Container(
              width: 244,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category eyebrow + Latest tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _eyebrow(article.category, size: 9, tracking: 1.0),
                      if (isLatest) _latestPill(fontSize: 8),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Text(
                      article.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (article.authors.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      article.authors.join(', '),
                      style: const TextStyle(fontSize: 11, color: _meta),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}