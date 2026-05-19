import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
          .select('id, title, authors, month, year, category, img, content-info')
          .eq('published', true);

      if (_selectedCategory != 'All') {
        query = query.ilike('category', _selectedCategory);
      }

      final response = await query
          .order('year', ascending: false)
          .order('month', ascending: false);

      final list = (response as List)
          .map((m) => Article.fromMap(Map<String, dynamic>.from(m)))
          .toList();

      final cache = <int, Article>{};
      if (_selectedCategory == 'All' && list.isNotEmpty) {
        final seen = <String>{};
        final months = <(int, int)>[];
        for (final a in list) {
          final key = '${a.year}-${a.month}';
          if (!seen.contains(key)) {
            seen.add(key);
            months.add((a.year, a.month));
          }
        }
        final keepMonths = months.take(4).toSet();
        for (final a in list) {
          if (keepMonths.contains((a.year, a.month))) cache[a.id] = a;
        }
      } else {
        for (final a in list) cache[a.id] = a;
      }

      setState(() {
        _articles = list;
        _articleCache = cache;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _loading = true;
      _error = null;
    });
    _fetchArticles();
  }

  String _monthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return month >= 1 && month <= 12 ? months[month] : '';
  }

  int get _latestYear => _articles.isNotEmpty ? _articles.first.year : 0;
  int get _latestMonth => _articles.isNotEmpty ? _articles.first.month : 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _buildMasthead(),
          ),
          const Divider(height: 0, color: Color(0xFFE0E0E0)),
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
      ),
    );
  }

  Widget _buildMasthead() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The Tower',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A2E),
              letterSpacing: -0.5,
            ),
          ),
          if (_selectedCategory != 'All') ...[
            const SizedBox(height: 8),
            Text(
              _selectedCategory.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Layout view ────────────────────────────────────────────────────────────

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
          widgets.add(HeroArticleCard(
            article: _articleCache[id]!,
            latestYear: _latestYear,
            latestMonth: _latestMonth,
          ));
        }
      } else if (line.startsWith('Sidescroll(')) {
        final inner = line.substring(
            'Sidescroll('.length, line.lastIndexOf(')'));
        final ids = inner
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toList();
        final articles = ids
            .where((id) => _articleCache.containsKey(id))
            .map((id) => _articleCache[id]!)
            .toList();
        if (articles.isNotEmpty) {
          widgets.add(SidescrollRow(
            articles: articles,
            latestYear: _latestYear,
            latestMonth: _latestMonth,
          ));
        }
      } else if (line == 'Divider') {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Divider(height: 1, color: Color(0xFFE0E0E0)),
        ));
      } else if (line.startsWith('Text(')) {
        final match = RegExp(r'Text\("(.+)"\)').firstMatch(line);
        if (match != null) {
          widgets.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                match.group(1)!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ));
        }
      }
    }

    return ListView(children: widgets);
  }

  // ── List view ──────────────────────────────────────────────────────────────

  Widget _buildListView() {
    if (_articles.isEmpty) {
      return const Center(child: Text('No articles found.'));
    }

    final List<dynamic> listItems = [];
    bool dividerInserted = false;

    for (final article in _articles) {
      final isLatest =
          article.year == _latestYear && article.month == _latestMonth;
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
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Earlier Issues',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500),
                ),
              ),
              const Expanded(child: Divider()),
            ]),
          );
        }

        final article = item as Article;
        final isLatest =
            article.year == _latestYear && article.month == _latestMonth;

        bool showHeader = false;
        if (index == 0) {
          showHeader = true;
        } else {
          final prev = listItems[index - 1];
          if (prev == 'divider') {
            showHeader = true;
          } else if (prev is Article &&
              (prev.year != article.year ||
                  prev.month != article.month)) {
            showHeader = true;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(children: [
                  Text(
                    '${_monthName(article.month)} ${article.year}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isLatest
                          ? const Color(0xFF1A1A2E)
                          : Colors.grey[500],
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
              ),
            _ArticleListTile(
              article: article,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ArticleScreen(articleId: article.id))),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
          ],
        );
      },
    );
  }
}

// ── Article list tile (no image, clean text layout) ───────────────────────────

class _ArticleListTile extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;

  const _ArticleListTile({required this.article, required this.onTap});

  String _catLabel(String cat) {
    switch (cat.toLowerCase()) {
      case 'news-features': return 'News';
      case 'arts-entertainment': return 'Arts';
      default: return cat;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _catLabel(article.category).toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              article.title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A2E),
                height: 1.3,
              ),
            ),
            if (article.authors.isNotEmpty) ...[
              const SizedBox(height: 5),
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
  }
}