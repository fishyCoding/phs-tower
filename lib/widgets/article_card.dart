import 'package:flutter/material.dart';
import '../models/article.dart';
import '../screens/article_screen.dart';

// ── Category helpers ──────────────────────────────────────────────────────────

Color catColor(String cat) {
  switch (cat.toLowerCase()) {
    case 'sports': return Colors.green[700]!;
    case 'opinions': return Colors.orange[700]!;
    case 'arts-entertainment': return Colors.purple[700]!;
    case 'news-features': return Colors.blue[700]!;
    default: return Colors.grey[700]!;
  }
}

String catLabel(String cat) {
  switch (cat.toLowerCase()) {
    case 'sports': return 'Sports';
    case 'opinions': return 'Ops';
    case 'arts-entertainment': return 'Arts';
    case 'news-features': return 'News';
    default: return cat;
  }
}

Widget catBubble(String cat) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: catColor(cat), borderRadius: BorderRadius.circular(12)),
    child: Text(catLabel(cat),
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
  );
}

Widget issueBubble(int month, int year, int latestYear, int latestMonth) {
  final isLatest = year == latestYear && month == latestMonth;
  const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final label = isLatest ? 'Latest' : '${monthNames[month]} $year';
  final color = isLatest ? Colors.red[700]! : Colors.black54;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Text(label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}

// ── Large Article Card ────────────────────────────────────────────────────────

class LargeArticleCard extends StatelessWidget {
  final Article article;
  final int latestYear;
  final int latestMonth;

  const LargeArticleCard({
    super.key,
    required this.article,
    required this.latestYear,
    required this.latestMonth,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ArticleScreen(articleId: article.id))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              article.img.isNotEmpty
                  ? Image.network(article.img,
                      width: double.infinity, height: 220, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _errorBox(220))
                  : _errorBox(220),
              Positioned.fill(child: _gradient()),
              Positioned(
                left: 12, right: 12, bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      catBubble(article.category),
                      const SizedBox(width: 6),
                      issueBubble(article.month, article.year, latestYear, latestMonth),
                    ]),
                    const SizedBox(height: 6),
                    Text(article.title,
                        style: const TextStyle(color: Colors.white, fontSize: 17,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBox(double height) => Container(
      height: height, color: Colors.grey[300],
      child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey));

  Widget _gradient() => DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.78)],
        ),
      ));
}

// ── Sidescroll Row ────────────────────────────────────────────────────────────

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
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          return GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ArticleScreen(articleId: article.id))),
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10), color: Colors.grey[200]),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (article.img.isNotEmpty)
                    Image.network(article.img, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image_not_supported, color: Colors.grey))
                  else
                    const Icon(Icons.article, color: Colors.grey, size: 40),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.78)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8, right: 8, bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          catBubble(article.category),
                          const SizedBox(width: 4),
                          issueBubble(article.month, article.year, latestYear, latestMonth),
                        ]),
                        const SizedBox(height: 4),
                        Text(article.title,
                            style: const TextStyle(color: Colors.white, fontSize: 12,
                                fontWeight: FontWeight.w600),
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
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