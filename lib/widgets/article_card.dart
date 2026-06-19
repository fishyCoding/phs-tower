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
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category + issue tag
            Row(children: [
              Text(
                _catLabel(article.category).toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: Color(0xFF666666),
                ),
              ),
              if (isLatest) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Latest',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 6),
            // Title
            Text(
              article.title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A2E),
                height: 1.2,
              ),
            ),
            if (article.authors.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                article.authors.join(', '),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _minuteRead(article.content.isNotEmpty
                  ? article.content
                  : article.contentInfo),
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            // Image below text
            if (article.img.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  article.img,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(200),
                ),
              )
            else
              _placeholder(200),
            if (article.contentInfo.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: Text(
                  _capitalizeFirstLine(article.contentInfo),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _placeholder(double height) => Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(6),
        ),
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
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vertical separator before every item except the first
                if (index != 0)
                  Container(
                    width: 1,
                    height: 100,
                    color: const Color(0xFFDDDDDD),
                  ),
                SizedBox(
                  width: 148,
                  height: 100,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Category + Latest tag
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _catLabel(article.category).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.9,
                                color: Color(0xFF888888),
                              ),
                            ),
                            if (isLatest)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A2E),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'Latest',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          article.title,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A2E),
                            height: 1.25,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}