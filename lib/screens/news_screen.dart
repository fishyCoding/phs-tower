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
  List<Map<String, dynamic>> _layouts = [];
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
      // 1. 🔍 DIAGNOSTIC: Scan and print absolutely EVERYTHING in the table
      final databaseScan =
          await Supabase.instance.client.from('app_layout').select();

      print("\n================ 🛰️ SUPABASE TABLE SCAN ================");
      print("Total rows found in 'app_layout' table: ${databaseScan.length}");
      for (var row in databaseScan) {
        print("------------------------------------------------");
        print(
            "Row ID: ${row['id']} | Month: ${row['month']} | Year: ${row['year']} | Published: ${row['published']}");
        print("Layout Script Text Content:");
        print(row['layout']);
      }
      print("========================================================\n");

      // 2. Your active layout query
      final response = await Supabase.instance.client
          .from('app_layout')
          .select('layout, month, year')
          .eq('published', true)
          .order('year', ascending: false)
          .order('month', ascending: false)
          .order('id', ascending: false)
          .limit(3);

      setState(() {
        _layouts = (response as List)
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      });

      // 3. 🔍 DIAGNOSTIC: Check what articles are currently cached
      print("============ 🧠 APP ARTICLE CACHE CHECK ============");
      print("Active layouts loaded into memory: ${_layouts.length}");
      print(
          "Article IDs currently available in cache: ${_articleCache.keys.toList()}");
      print("====================================================\n");
    } catch (e) {
      debugPrint("❌ Error fetching app layout: $e");
      setState(() {
        _error = "Layout Error: $e";
      });
    }
  }

  Future<void> _fetchArticles() async {
    try {
      var query = Supabase.instance.client
          .from('article')
          .select(
              'id, title, authors, month, year, category, img, content-info')
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

  // 🚀 Fetch single article on demand from Supabase if missing from initial cache
  Future<Article?> _fetchSingleArticle(int id) async {
    try {
      final response = await Supabase.instance.client
          .from('article')
          .select(
              'id, title, authors, month, year, category, img, content-info')
          .eq('id', id)
          .maybeSingle();

      if (response != null) {
        final article = Article.fromMap(Map<String, dynamic>.from(response));
        _articleCache[id] = article; // Populate cache memory
        return article;
      }
    } catch (e) {
      debugPrint("Error fetching single article $id: $e");
    }
    return null;
  }

  // 🚀 Helper to resolve list of missing IDs concurrently for Sidescroll layouts
  Future<List<Article>> _fetchMultipleArticles(List<int> ids) async {
    final List<Article> results = [];
    final List<int> missingIds = [];

    for (final id in ids) {
      if (_articleCache.containsKey(id)) {
        results.add(_articleCache[id]!);
      } else {
        missingIds.add(id);
      }
    }

    if (missingIds.isNotEmpty) {
      try {
        final response = await Supabase.instance.client
            .from('article')
            .select(
                'id, title, authors, month, year, category, img, content-info')
            .inFilter('id', missingIds);

        if (response != null) {
          final fetched = (response as List)
              .map((m) => Article.fromMap(Map<String, dynamic>.from(m)))
              .toList();
          for (final article in fetched) {
            _articleCache[article.id] = article; // Sync to cache memory
            results.add(article);
          }
        }
      } catch (e) {
        debugPrint("Error fetching batch articles $missingIds: $e");
      }
    }

    // Sort to keep original sequence requested in the layout text script string
    final Map<int, Article> sortedMap = {for (var a in results) a.id: a};
    return ids
        .where((id) => sortedMap.containsKey(id))
        .map((id) => sortedMap[id]!)
        .toList();
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
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
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
                    : _selectedCategory == 'All' && _layouts.isNotEmpty
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
    if (_articles.isEmpty || _layouts.isEmpty) return const SizedBox.shrink();
    final widgets = <Widget>[];

    for (int i = 0; i < _layouts.length; i++) {
      final layoutData = _layouts[i];
      final script = layoutData['layout'] as String;
      final month = layoutData['month'] as int;
      final year = layoutData['year'] as int;
      final isLatest = i == 0;

      // ── Insert Divider / Header ──
      widgets.add(
        Padding(
          padding: EdgeInsets.fromLTRB(16, isLatest ? 8 : 24, 16, 12),
          child: Row(
            children: [
              if (!isLatest)
                const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
              if (!isLatest) const SizedBox(width: 12),
              Text(
                '${_monthName(month)} $year',
                style: TextStyle(
                  fontSize: isLatest ? 18 : 12,
                  fontWeight: FontWeight.bold,
                  color: isLatest ? const Color(0xFF1A1A2E) : Colors.grey[600],
                ),
              ),
              if (isLatest) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
              if (!isLatest) const SizedBox(width: 12),
              if (!isLatest)
                const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
            ],
          ),
        ),
      );

      // ── Parse the script for this specific layout ──
      final lines = script.split('\n');
      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        if (line.startsWith('LargeArticle(')) {
          final id = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
          if (id != null) {
            if (_articleCache.containsKey(id)) {
              widgets.add(HeroArticleCard(
                article: _articleCache[id]!,
                latestYear: _latestYear,
                latestMonth: _latestMonth,
              ));
            } else {
              // Asynchronously fetch on demand if missing from local memory map
              widgets.add(
                FutureBuilder<Article?>(
                  future: _fetchSingleArticle(id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasData && snapshot.data != null) {
                      return HeroArticleCard(
                        article: snapshot.data!,
                        latestYear: _latestYear,
                        latestMonth: _latestMonth,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              );
            }
          }
        } else if (line.startsWith('Sidescroll(')) {
          final inner =
              line.substring('Sidescroll('.length, line.lastIndexOf(')'));
          final ids = inner
              .split(',')
              .map((s) => int.tryParse(s.trim()))
              .whereType<int>()
              .toList();

          // Check if every single item is completely cached upfront
          final bool allCached =
              ids.every((id) => _articleCache.containsKey(id));

          if (allCached) {
            final articles = ids.map((id) => _articleCache[id]!).toList();
            if (articles.isNotEmpty) {
              widgets.add(SidescrollRow(
                articles: articles,
                latestYear: _latestYear,
                latestMonth: _latestMonth,
              ));
            }
          } else {
            // Asynchronously resolve missing array items concurrently
            widgets.add(
              FutureBuilder<List<Article>>(
                future: _fetchMultipleArticles(ids),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return SidescrollRow(
                      articles: snapshot.data!,
                      latestYear: _latestYear,
                      latestMonth: _latestMonth,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            );
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
    }

    widgets.add(const SizedBox(height: 32));
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
              (prev.year != article.year || prev.month != article.month)) {
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
                      color:
                          isLatest ? const Color(0xFF1A1A2E) : Colors.grey[500],
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
                      builder: (_) => ArticleScreen(articleId: article.id))),
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
      case 'news-features':
        return 'News';
      case 'arts-entertainment':
        return 'Arts';
      default:
        return cat;
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
