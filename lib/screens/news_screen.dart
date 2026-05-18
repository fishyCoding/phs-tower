import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../screens/article_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => NewsScreenState();
}

class NewsScreenState extends State<NewsScreen> {
  List<Article> _articles = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'All';
  String? _layoutScript;
  Map<int, Article> _articleCache = {};

  final List<String> _categories = [
    'All', 'News-Features', 'Sports', 'Opinions', 'Arts-Entertainment',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get selectedCategory => _selectedCategory;

  Future<void> _loadData() async {
    await Future.wait([_fetchArticles(), _loadLayout()]);
  }

  Future<void> _loadLayout() async {
    try {
      final script = await rootBundle.loadString('lib/home_layout.txt');
      setState(() => _layoutScript = script);
    } catch (_) {}
  }

  Future<void> _fetchArticles() async {
    try {
      var query = Supabase.instance.client
          .from('article')
          .select('id, title, authors, month, year, category, img')
          .eq('published', true);

      if (_selectedCategory != 'All') {
        query = query.ilike('category', _selectedCategory);
      }

      final response = await query
          .order('year', ascending: false)
          .order('month', ascending: false);

      final list = (response as List).map((m) => Article.fromMap(Map<String, dynamic>.from(m))).toList();

      final cache = <int, Article>{};
      if (_selectedCategory == 'All' && list.isNotEmpty) {
        final seen = <String>{};
        final months = <(int, int)>[];
        for (final a in list) {
          final key = '${a.year}-${a.month}';
          if (!seen.contains(key)) { seen.add(key); months.add((a.year, a.month)); }
        }
        final keepMonths = months.take(4).toSet();
        for (final a in list) {
          if (keepMonths.contains((a.year, a.month))) cache[a.id] = a;
        }
      } else {
        for (final a in list) { cache[a.id] = a; }
      }

      setState(() { _articles = list; _articleCache = cache; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void selectCategory(String category) {
    setState(() { _selectedCategory = category; _loading = true; _error = null; });
    _fetchArticles();
  }

  String _monthName(int month) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return month >= 1 && month <= 12 ? months[month] : '';
  }

  int get _latestYear => _articles.isNotEmpty ? _articles.first.year : 0;
  int get _latestMonth => _articles.isNotEmpty ? _articles.first.month : 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => selectCategory(cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        )),
                  ),
                );
              },
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _selectedCategory == 'All' && _layoutScript != null
                      ? _buildLayoutView()
                      : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildLayoutView() {
    if (_articles.isEmpty) return const SizedBox.shrink();
    final lines = _layoutScript!.split('\n');
    final widgets = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('LargeArticle(')) {
        final id = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
        if (id != null && _articleCache.containsKey(id)) {
          widgets.add(LargeArticleCard(
            article: _articleCache[id]!,
            latestYear: _latestYear,
            latestMonth: _latestMonth,
          ));
        }
      } else if (line.startsWith('Sidescroll(')) {
        final inner = line.substring('Sidescroll('.length, line.lastIndexOf(')'));
        final ids = inner.split(',').map((s) => int.tryParse(s.trim())).whereType<int>().toList();
        final articles = ids.where((id) => _articleCache.containsKey(id)).map((id) => _articleCache[id]!).toList();
        if (articles.isNotEmpty) {
          widgets.add(SidescrollRow(
            articles: articles,
            latestYear: _latestYear,
            latestMonth: _latestMonth,
          ));
        }
      } else if (line == 'Divider') {
        widgets.add(const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Divider(thickness: 1, color: Colors.black26),
        ));
      } else if (line.startsWith('Text(')) {
        final match = RegExp(r'Text\("(.+)"\)').firstMatch(line);
        if (match != null) {
          widgets.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(match.group(1)!.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        letterSpacing: 1.8, color: Colors.black54)),
                const SizedBox(height: 4),
                Container(height: 2, width: 32, color: Colors.black87),
              ],
            ),
          ));
        }
      }
    }

    return ListView(children: widgets);
  }

  Widget _buildListView() {
    if (_articles.isEmpty) return const Center(child: Text('No articles found.'));

    final List<dynamic> listItems = [];
    bool dividerInserted = false;

    for (final article in _articles) {
      final isLatest = article.year == _latestYear && article.month == _latestMonth;
      if (!isLatest && !dividerInserted) {
        listItems.add('divider');
        dividerInserted = true;
      }
      listItems.add(article);
    }

    return ListView.builder(
      itemCount: listItems.length,
      itemBuilder: (context, index) {
        final item = listItems[index];

        if (item == 'divider') {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const Expanded(child: Divider(thickness: 1.5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('Earlier Issues',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
              ),
              const Expanded(child: Divider(thickness: 1.5)),
            ]),
          );
        }

        final article = item as Article;
        final isLatest = article.year == _latestYear && article.month == _latestMonth;

        bool showHeader = false;
        if (index == 0) {
          showHeader = true;
        } else {
          final prev = listItems[index - 1];
          if (prev == 'divider') {
            showHeader = true;
          } else if (prev is Article && (prev.year != article.year || prev.month != article.month)) {
            showHeader = true;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  Text('${_monthName(article.month)} ${article.year}',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: isLatest ? Theme.of(context).colorScheme.primary : Colors.grey[600],
                      )),
                  if (isLatest) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Latest',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
              ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: article.img.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(article.img,
                          width: 90, height: 90, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder()),
                    )
                  : _placeholder(),
              title: Text(article.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${article.authors.join(', ')} · ${article.category}',
                    style: const TextStyle(fontSize: 12)),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ArticleScreen(articleId: article.id))),
            ),
            const Divider(height: 1),
          ],
        );
      },
    );
  }

  Widget _placeholder() => Container(
      width: 90, height: 90,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.article, color: Colors.grey, size: 32));
}