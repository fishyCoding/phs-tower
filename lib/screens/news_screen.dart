import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../screens/article_screen.dart';

class NewsScreen extends StatefulWidget {
  final GoogleSignInAccount? user;
  final VoidCallback? onSignIn;
  final VoidCallback? onSignOut;

  const NewsScreen({
    super.key,
    this.user,
    this.onSignIn,
    this.onSignOut,
  });

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
    // Load the layout first so _fetchArticles knows which articles are rendered
    // as hero cards (the only place a read time is shown) and can pull their
    // full content for an accurate word count.
    await _loadLayout();
    await _fetchArticles();
  }

  /// Article ids referenced by `LargeArticle(id)` lines in the home layout —
  /// these render as HeroArticleCards, the only cards that display a read time.
  Set<int> _heroIds() {
    final script = _layoutScript;
    if (script == null) return {};
    final ids = <int>{};
    for (final raw in script.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('LargeArticle(')) {
        final id = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
        if (id != null) ids.add(id);
      }
    }
    return ids;
  }

  /// Fetches full `content` for just the hero articles and merges it into the
  /// cache so HeroArticleCard can compute a real read time. Kept targeted (a
  /// handful of ids) instead of selecting `content` for all ~1k articles.
  Future<void> _attachHeroContent() async {
    final ids = _heroIds().where(_articleCache.containsKey).toList();
    if (ids.isEmpty) return;
    try {
      final rows = await Supabase.instance.client
          .from('article')
          .select('id, content')
          .inFilter('id', ids);
      for (final row in (rows as List)) {
        final id = row['id'] as int;
        final content = row['content'] as String? ?? '';
        final existing = _articleCache[id];
        if (existing != null) {
          _articleCache[id] = existing.copyWith(content: content);
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
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

      // Pull full content for the hero cards so their read time is accurate.
      if (_selectedCategory == 'All') {
        await _attachHeroContent();
      }
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
    final user = widget.user;
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered title + subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                const SizedBox(height: 4),
                Text(
                  _selectedCategory.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ],
          ),
          // Sign-in button top-right
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: user != null ? widget.onSignOut : widget.onSignIn,
              child: user != null
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: user.photoUrl != null
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      backgroundColor: const Color(0xFF1A1A2E),
                      child: user.photoUrl == null
                          ? Text(
                              (user.displayName ?? user.email)[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFDDDDDD)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.network(
                            'https://www.google.com/favicon.ico',
                            width: 14,
                            height: 14,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.login,
                              size: 14,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Sign in',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
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
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SidescrollRow(
              articles: articles,
              latestYear: _latestYear,
              latestMonth: _latestMonth,
            ),
          ));
        }
      } else if (line == 'Divider') {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Divider(height: 1, color: Color(0xFFE0E0E0)),
        ));
      } else if (line.startsWith('Text(')) {
        final match = RegExp(r'Text\("(.+)"\)').firstMatch(line);
        if (match != null) {
          widgets.add(Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                match.group(1)!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
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

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      children: widgets,
    );
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
      padding: EdgeInsets.zero,
      itemCount: listItems.length,
      itemBuilder: (context, index) {
        final item = listItems[index];

        if (item == 'divider') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
            child: Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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

// ── Article list tile ────────────────────────────────────────────────────────

class _ArticleListTile extends StatefulWidget {
  final Article article;
  final VoidCallback onTap;

  const _ArticleListTile({required this.article, required this.onTap});

  @override
  State<_ArticleListTile> createState() => _ArticleListTileState();
}

class _ArticleListTileState extends State<_ArticleListTile> {
  bool _imgFailed = false;

  String _catLabel(String cat) {
    switch (cat.toLowerCase()) {
      case 'news-features': return 'News';
      case 'arts-entertainment': return 'Arts';
      default: return cat;
    }
  }

  @override
  Widget build(BuildContext context) {
    const imgSize = 90.0;
    final rawImg = widget.article.img.trim();
    final showImg = rawImg.isNotEmpty && !_imgFailed;

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Text first — grows to fill available space
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _catLabel(widget.article.category).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: Color(0xFF715C00), // newspaper gold eyebrow
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.article.title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A2E),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.article.authors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.article.authors.join(', '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFAAAAAA),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Thumbnail — only if image loaded successfully
            if (showImg) ...[
              const SizedBox(width: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  rawImg,
                  width: imgSize,
                  height: imgSize,
                  // Decode at roughly display resolution instead of full-res so
                  // each thumbnail holds a small bitmap, not several MB.
                  cacheWidth: 270,
                  cacheHeight: 270,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _imgFailed = true);
                    });
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}