import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../screens/article_screen.dart';
import '../section_labels.dart';
import '../widgets/tower_masthead.dart';
import '../debug/typography.dart';

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

  /// Loads the front-page layout script from the `app_layout` table (latest
  /// published row wins), so editors can re-arrange the front page without an
  /// app release. Falls back to the bundled layout if unreachable or empty.
  Future<void> _loadLayout() async {
    try {
      final row = await Supabase.instance.client
          .from('app_layout')
          .select('layout')
          .eq('published', true)
          .order('year', ascending: false)
          .order('month', ascending: false)
          .limit(1)
          .maybeSingle();
      final layout = row?['layout'] as String?;
      if (layout != null && layout.trim().isNotEmpty) {
        if (mounted) setState(() => _layoutScript = layout);
        return;
      }
    } catch (_) {}
    try {
      final script = await rootBundle.loadString('lib/home_layout.txt');
      if (mounted) setState(() => _layoutScript = script);
    } catch (_) {}
  }

  Future<void> _fetchArticles() async {
    try {
      var query = Supabase.instance.client
          .from('article')
          .select(
              'id, title, authors, month, year, category, img, content-info, blurb')
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

  /// Pull-to-refresh: re-fetch the layout script and articles.
  Future<void> _refresh() async {
    await _loadLayout();
    await _fetchArticles();
  }

  /// Grey placeholder blocks shown while the first load is in flight.
  Widget _buildSkeleton() {
    Widget block(double height, {double? width, double radius = 8}) =>
        Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: const Color(0xFFEDEDED),
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        block(10, width: 80, radius: 4),
        const SizedBox(height: 14),
        block(28),
        const SizedBox(height: 8),
        block(28, width: 220),
        const SizedBox(height: 16),
        AspectRatio(aspectRatio: 16 / 9, child: block(0)),
        const SizedBox(height: 28),
        for (var i = 0; i < 3; i++) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    block(9, width: 60, radius: 4),
                    const SizedBox(height: 8),
                    block(16),
                    const SizedBox(height: 6),
                    block(16, width: 140),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              block(72, width: 72),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

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
                ? _buildSkeleton()
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : RefreshIndicator(
                        color: const Color(0xFF072636),
                        onRefresh: _refresh,
                        child: _selectedCategory == 'All' &&
                                _layoutScript != null
                            ? _buildLayoutView()
                            : _buildListView(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasthead() {
    return TowerMasthead(
      user: widget.user,
      onSignIn: widget.onSignIn,
      onSignOut: widget.onSignOut,
      subtitle:
          _selectedCategory == 'All' ? null : sectionName(_selectedCategory),
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
                  color: Color(0xFF072636),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ));
        }
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
      physics: const AlwaysScrollableScrollPhysics(),
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
                          ? const Color(0xFF072636)
                          : Colors.grey[500],
                    ),
                  ),
                  if (isLatest) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA31621),
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
              // On a section screen every tile is the same category — skip it.
              showCategory: _selectedCategory == 'All',
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

  /// Hidden on section screens, where every article shares the same category.
  final bool showCategory;

  const _ArticleListTile({
    required this.article,
    required this.onTap,
    this.showCategory = true,
  });

  @override
  State<_ArticleListTile> createState() => _ArticleListTileState();
}

class _ArticleListTileState extends State<_ArticleListTile> {
  bool _imgFailed = false;

  @override
  Widget build(BuildContext context) {
    const imgW = 120.0;
    const imgH = 132.0;
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
                  if (widget.showCategory) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA31621), // editorial red kicker
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sectionName(widget.article.category).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          height: 1.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    widget.article.title,
                    style: headline(context, size: 16, color: Colors.black),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.article.authorLine,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFAAAAAA),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Thumbnail — only if image loaded successfully
            if (showImg) ...[
              const SizedBox(width: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: rawImg,
                  width: imgW,
                  height: imgH,
                  // Downscale the decode by width only — setting both dims
                  // resizes to an exact size and distorts aspect. BoxFit.cover
                  // then crops the aspect-correct image into the box.
                  memCacheWidth: 360,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFFF0F0F0)),
                  errorWidget: (_, __, ___) {
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