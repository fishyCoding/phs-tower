import 'package:flutter/material.dart';
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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
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
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
                height: 1.25,
              ),
            ),
            if (article.authors.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                article.authors.join(', '),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
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

// ── Sidescroll Row (text above image, no overlay) ─────────────────────────────

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
      height: 195,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          return GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ArticleScreen(articleId: article.id))),
            child: Container(
              width: 155,
              margin: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                    color: const Color(0xFFE8E8E8), width: 0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text block
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _catLabel(article.category).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: Color(0xFF888888),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          article.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Thin separator
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  // Image fills remaining space
                  Expanded(
                    child: article.img.isNotEmpty
                        ? Image.network(
                            article.img,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF5F5F5),
                              child: const Center(
                                  child: Icon(Icons.image_not_supported,
                                      color: Color(0xFFCCCCCC), size: 24)),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFF5F5F5),
                            child: const Center(
                                child: Icon(Icons.article,
                                    color: Color(0xFFCCCCCC), size: 28)),
                          ),
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