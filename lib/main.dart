import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://yusjougmsdnhcsksadaw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl1c2pvdWdtc2RuaGNza3NhZGF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE2NDU1NzI4NzQsImV4cCI6MTk2MTE0ODg3NH0.DHLgiswzK6Y_z5_mXAkRn1xy60zvhdb_iQH5gAyJorg',
  );
  // Cache up to 1000 images, 500 MB
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 500 * 1024 * 1024; // 500 MB
  runApp(const PHSTowerApp());
}

class PHSTowerApp extends StatelessWidget {
  const PHSTowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PHS Tower',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    NewsScreen(),
    PlaceholderScreen(label: 'Games'),
    PlaceholderScreen(label: 'Outreach'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'News'),
          BottomNavigationBarItem(icon: Icon(Icons.sports_esports), label: 'Games'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Outreach'),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String label;
  const PlaceholderScreen({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)));
  }
}

// ── Category helpers ──────────────────────────────────────────────────────────

Color _catColor(String cat) {
  switch (cat.toLowerCase()) {
    case 'sports': return Colors.green[700]!;
    case 'opinions': return Colors.orange[700]!;
    case 'arts-entertainment': return Colors.purple[700]!;
    case 'news-features': return Colors.blue[700]!;
    default: return Colors.grey[700]!;
  }
}

String _catLabel(String cat) {
  switch (cat.toLowerCase()) {
    case 'sports': return 'Sports';
    case 'opinions': return 'Ops';
    case 'arts-entertainment': return 'Arts';
    case 'news-features': return 'News';
    default: return cat;
  }
}

Widget _catBubble(String cat) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _catColor(cat),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      _catLabel(cat),
      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );
}

// ── Navigation helper ─────────────────────────────────────────────────────────

void _openArticle(BuildContext context, int id) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleScreen(articleId: id)));
}

// ── News Screen ───────────────────────────────────────────────────────────────

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<Map<String, dynamic>> _articles = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All', 'News-Features', 'Sports', 'Opinions', 'Arts-Entertainment',
  ];

  // For the All tab: layout script + article cache
  String? _layoutScript;
  Map<int, Map<String, dynamic>> _articleCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_fetchArticles(), _loadLayout()]);
  }

  Future<void> _loadLayout() async {
    try {
      final script = await rootBundle.loadString('lib/home_layout.txt');
      setState(() => _layoutScript = script);
    } catch (_) {
      // File not found, layout tab won't show
    }
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

      final list = List<Map<String, dynamic>>.from(response);

      // For All tab, keep only last 4 months in cache (for layout rendering)
      // but keep full list for other tabs
      final cache = <int, Map<String, dynamic>>{};
      if (_selectedCategory == 'All' && list.isNotEmpty) {
        final latestYear = list.first['year'] as int;
        final latestMonth = list.first['month'] as int;
        // Collect unique months sorted desc
        final seen = <String>{};
        final months = <(int, int)>[];
        for (final a in list) {
          final key = '${a['year']}-${a['month']}';
          if (!seen.contains(key)) {
            seen.add(key);
            months.add((a['year'] as int, a['month'] as int));
          }
        }
        final keepMonths = months.take(4).toSet();
        for (final a in list) {
          if (keepMonths.contains((a['year'] as int, a['month'] as int))) {
            cache[a['id'] as int] = a;
          }
        }

      } else {
        for (final a in list) {
          cache[a['id'] as int] = a;
        }
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

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _loading = true;
      _error = null;
    });
    _fetchArticles();
  }

  String _monthName(int month) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return month >= 1 && month <= 12 ? months[month] : '';
  }

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
                  onTap: () => _selectCategory(cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
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

  // ── Layout renderer ─────────────────────────────────────────────────────────

  Widget _buildLayoutView() {
    final lines = _layoutScript!.split('\n');
    final widgets = <Widget>[];

    int? latestYear;
    int? latestMonth;
    if (_articles.isNotEmpty) {
      latestYear = _articles.first['year'] as int?;
      latestMonth = _articles.first['month'] as int?;
    }
    if (latestYear == null || latestMonth == null) return const SizedBox.shrink();

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('LargeArticle(')) {
        final id = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
        if (id != null && _articleCache.containsKey(id)) {
          widgets.add(_LargeArticleCard(
            article: _articleCache[id]!,
            showBubble: true,
            latestYear: latestYear!,
            latestMonth: latestMonth!,
          ));
        }
      } else if (line.startsWith('Sidescroll(')) {
        final inner = line.substring('Sidescroll('.length, line.lastIndexOf(')'));
        final ids = inner.split(',').map((s) => int.tryParse(s.trim())).whereType<int>().toList();
        final articles = ids.where((id) => _articleCache.containsKey(id)).map((id) => _articleCache[id]!).toList();
        if (articles.isNotEmpty) {
          widgets.add(_SidescrollRow(
            articles: articles,
            latestYear: latestYear!,
            latestMonth: latestMonth!,
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
                Text(
                  match.group(1)!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: Colors.black54,
                  ),
                ),
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

  // ── Standard list view ──────────────────────────────────────────────────────

  Widget _buildListView() {
    if (_articles.isEmpty) return const Center(child: Text('No articles found.'));

    int? latestYear = _articles.first['year'] as int?;
    int? latestMonth = _articles.first['month'] as int?;

    final List<dynamic> listItems = [];
    bool dividerInserted = false;

    for (final article in _articles) {
      final isLatest = article['year'] == latestYear && article['month'] == latestMonth;
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
            child: Row(
              children: [
                const Expanded(child: Divider(thickness: 1.5)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Earlier Issues',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                ),
                const Expanded(child: Divider(thickness: 1.5)),
              ],
            ),
          );
        }

        final article = item as Map<String, dynamic>;
        final authors = (article['authors'] as List?)?.join(', ') ?? '';
        final imgUrl = article['img'] as String?;
        final year = article['year'] as int?;
        final month = article['month'] as int?;
        final isLatest = year == latestYear && month == latestMonth;

        // Check if we need a month header
        bool showHeader = false;
        if (index == 0) {
          showHeader = true;
        } else {
          final prev = listItems[index - 1];
          if (prev == 'divider') {
            showHeader = true;
          } else if (prev is Map && (prev['year'] != year || prev['month'] != month)) {
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
                  Text(
                    '${_monthName(month ?? 0)} ${year ?? ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isLatest ? Theme.of(context).colorScheme.primary : Colors.grey[600],
                    ),
                  ),
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
              leading: imgUrl != null && imgUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imgUrl,
                        width: 90, height: 90, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderImage(),
                      ),
                    )
                  : _placeholderImage(),
              title: Text(article['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('$authors · ${article['category'] ?? ''}',
                    style: const TextStyle(fontSize: 12)),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openArticle(context, article['id']),
            ),
            const Divider(height: 1),
          ],
        );
      },
    );
  }

  Widget _placeholderImage() => Container(
    width: 90, height: 90,
    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.article, color: Colors.grey, size: 32),
  );
}

// ── Issue bubble ─────────────────────────────────────────────────────────────

Widget _issueBubble(int month, int year, int latestYear, int latestMonth) {
  final isLatest = year == latestYear && month == latestMonth;
  const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final label = isLatest ? 'Latest Issue' : '${monthNames[month]} $year';
  final color = isLatest ? Colors.red[700]! : Colors.black54;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}

// ── Large Article Card ────────────────────────────────────────────────────────

class _LargeArticleCard extends StatelessWidget {
  final Map<String, dynamic> article;
  final bool showBubble;
  final int latestYear;
  final int latestMonth;
  const _LargeArticleCard({
    required this.article,
    required this.latestYear,
    required this.latestMonth,
    this.showBubble = false,
  });

  @override
  Widget build(BuildContext context) {
    final imgUrl = article['img'] as String?;
    final cat = article['category'] as String? ?? '';
    final year = article['year'] as int? ?? 0;
    final month = article['month'] as int? ?? 0;

    return GestureDetector(
      onTap: () => _openArticle(context, article['id']),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              imgUrl != null && imgUrl.isNotEmpty
                  ? Image.network(imgUrl,
                      width: double.infinity, height: 220, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 220, color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey)),
                    )
                  : Container(height: 220, color: Colors.grey[300],
                      child: const Icon(Icons.article, size: 48, color: Colors.grey)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.78)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12, right: 12, bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (showBubble && cat.isNotEmpty) ...[
                        _catBubble(cat),
                        const SizedBox(width: 6),
                      ],
                      _issueBubble(month, year, latestYear, latestMonth),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      article['title'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sidescroll Row ────────────────────────────────────────────────────────────

class _SidescrollRow extends StatelessWidget {
  final List<Map<String, dynamic>> articles;
  final int latestYear;
  final int latestMonth;
  const _SidescrollRow({required this.articles, required this.latestYear, required this.latestMonth});

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
          final imgUrl = article['img'] as String?;
          final cat = article['category'] as String? ?? '';
          final year = article['year'] as int? ?? 0;
          final month = article['month'] as int? ?? 0;

          return GestureDetector(
            onTap: () => _openArticle(context, article['id']),
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[200],
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imgUrl != null && imgUrl.isNotEmpty)
                    Image.network(imgUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image_not_supported, color: Colors.grey))
                  else
                    const Icon(Icons.article, color: Colors.grey, size: 40),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
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
                          _catBubble(cat),
                          const SizedBox(width: 4),
                          _issueBubble(month, year, latestYear, latestMonth),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          article['title'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 12,
                              fontWeight: FontWeight.w600),
                          maxLines: 3, overflow: TextOverflow.ellipsis,
                        ),
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

// ── Article Screen ────────────────────────────────────────────────────────────

class ArticleScreen extends StatefulWidget {
  final int articleId;
  const ArticleScreen({super.key, required this.articleId});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  Map<String, dynamic>? _article;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchArticle();
  }

  Future<void> _fetchArticle() async {
    try {
      final response = await Supabase.instance.client
          .from('article').select().eq('id', widget.articleId).single();
      setState(() { _article = response; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Article')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((_article!['img'] as String?)?.isNotEmpty == true)
                        Image.network(_article!['img'],
                          width: double.infinity, height: 220, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_article!['title'] ?? '',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text((_article!['authors'] as List?)?.join(', ') ?? '',
                                style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text('${_article!['category'] ?? ''} · ${_article!['month']}/${_article!['year']}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(_article!['content'] ?? '',
                                style: const TextStyle(fontSize: 16, height: 1.6)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}