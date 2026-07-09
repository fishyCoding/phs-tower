import 'package:flutter/material.dart';

import '../debug/typography.dart';
import '../section_labels.dart';
import '../services/bookmarks.dart';
import 'article_screen.dart';

/// Locally saved (bookmarked) articles.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Saved',
            style: headline(context, size: 20, color: Colors.black)),
      ),
      body: AnimatedBuilder(
        animation: BookmarksService.instance,
        builder: (context, _) {
          final items = BookmarksService.instance.items;
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text('No saved articles yet',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                  const SizedBox(height: 4),
                  Text('Tap the bookmark on any article to save it.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
            itemBuilder: (context, index) {
              final item = items[index];
              final authors = (item['authors'] as List?) ?? [];
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArticleScreen(articleId: item['id'] as int),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sectionName(item['category'] as String? ?? '')
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                                color: Color(0xFFA31621),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['title'] as String? ?? '',
                              style: headline(context,
                                  size: 16, color: Colors.black),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (authors.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                authors.join(', '),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark,
                            color: Color(0xFF072636), size: 20),
                        onPressed: () =>
                            BookmarksService.instance.toggle(item),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
