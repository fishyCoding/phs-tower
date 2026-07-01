import 'package:flutter/material.dart';
import '../models/article.dart';
import '../screens/article_screen.dart';
import '../debug/typography.dart';

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

const _ink = Color(0xFF000000); // headline/body text — black
const _accent2 = Color(0xFFA31621); // secondary accent — editorial red (kickers & Latest)
const _cardBg = Color(0xFF072636); // side-scroll box fill — blue (primary accent)
const _cardBorder = Color(0xFFE3E8F2); // outline-variant tint
const _meta = Color(0xFF666666); // on-surface-variant
const _dot = Color(0xFFBFC4CF); // separator dot

/// Eyebrow category label — a filled red box with white text (the editorial
/// kicker). Pass [boxed] = false for a plain coloured label, e.g. white text
/// on the blue side-scroll boxes.
Widget _eyebrow(String category,
    {double size = 10,
    double tracking = 1.2,
    bool boxed = true,
    Color color = Colors.white}) {
  final label = Text(
    _catLabel(category).toUpperCase(),
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: tracking,
      height: 1.0,
      color: boxed ? Colors.white : color,
    ),
  );
  if (!boxed) return label;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: _accent2,
      borderRadius: BorderRadius.circular(4),
    ),
    child: label,
  );
}

/// Small "Latest" pill shown on current-issue articles. [onDark] inverts it
/// (white fill, blue text) for use inside the blue side-scroll boxes.
Widget _latestPill({double fontSize = 10, bool onDark = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: onDark ? Colors.white : _accent2,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      'Latest',
      style: TextStyle(
        color: onDark ? _accent2 : Colors.white,
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
              style: headline(context, size: 32, color: _ink),
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
      article.authorLine,
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
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category eyebrow + Latest tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _eyebrow(article.category,
                          size: 9, tracking: 1.0, boxed: false, color: Colors.white),
                      if (isLatest) _latestPill(fontSize: 8, onDark: true),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Text(
                      article.title,
                      style: headline(context, size: 16, color: Colors.white),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    article.authorLine,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}