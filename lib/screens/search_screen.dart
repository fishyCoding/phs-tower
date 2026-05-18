import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/article.dart';
import '../screens/article_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Article> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _hasSearched = true;
      _error = null;
      _results = [];
    });
    try {
      final response = await Supabase.instance.client
          .from('article')
          .select('id, title, authors, month, year, category, img')
          .eq('published', true)
          .ilike('title', '%$q%')
          .order('year', ascending: false)
          .order('month', ascending: false)
          .limit(40);

      setState(() {
        _results = (response as List)
            .map((m) => Article.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _catLabel(String cat) {
    switch (cat.toLowerCase()) {
      case 'news-features': return 'News';
      case 'arts-entertainment': return 'Arts';
      default: return cat;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Search field
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            const Icon(Icons.search,
                                color: Color(0xFF999999), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                onSubmitted: _search,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF1A1A2E),
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Search articles...',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFAAAAAA),
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            if (_controller.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _controller.clear();
                                  setState(() {
                                    _results = [];
                                    _hasSearched = false;
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(Icons.close,
                                      size: 16, color: Color(0xFF999999)),
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () => _search(_controller.text),
                                child: Container(
                                  margin: const EdgeInsets.all(5),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A2E),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Go',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE0E0E0)),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : !_hasSearched
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search,
                                    size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 10),
                                Text('Search by article title',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[400])),
                              ],
                            ),
                          )
                        : _results.isEmpty
                            ? Center(
                                child: Text('No results found',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[400])),
                              )
                            : ListView.separated(
                                itemCount: _results.length + 1,
                                separatorBuilder: (_, __) => const Divider(
                                    height: 1,
                                    color: Color(0xFFF0F0F0)),
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 4),
                                      child: Text(
                                        '${_results.length} result${_results.length == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    );
                                  }
                                  final article = _results[index - 1];
                                  return InkWell(
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => ArticleScreen(
                                                articleId: article.id))),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 13),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Text(
                                              _catLabel(article.category)
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.0,
                                                color: Color(0xFF666666),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${article.month}/${article.year}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFFAAAAAA),
                                              ),
                                            ),
                                          ]),
                                          const SizedBox(height: 4),
                                          Text(
                                            article.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1A1A2E),
                                              height: 1.3,
                                            ),
                                          ),
                                          if (article.authors.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              article.authors.join(', '),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
          ),
        ],
      ),
    );
  }
}