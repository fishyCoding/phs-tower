import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://yusjougmsdnhcsksadaw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl1c2pvdWdtc2RuaGNza3NhZGF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE2NDU1NzI4NzQsImV4cCI6MTk2MTE0ODg3NH0.DHLgiswzK6Y_z5_mXAkRn1xy60zvhdb_iQH5gAyJorg',
  );
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
    return Center(
      child: Text(label, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _fetchArticles();
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

      setState(() {
        _articles = List<Map<String, dynamic>>.from(response);
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
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return month >= 1 && month <= 12 ? months[month] : '';
  }

  @override
  Widget build(BuildContext context) {
    // Figure out the latest month/year in the list
    int? latestYear;
    int? latestMonth;
    if (_articles.isNotEmpty) {
      latestYear = _articles.first['year'] as int?;
      latestMonth = _articles.first['month'] as int?;
    }

    // Build a flat list of items: articles + divider marker
    // Each item is either a Map (article) or a String 'divider'
    final List<dynamic> listItems = [];
    bool dividerInserted = false;

    for (final article in _articles) {
      final year = article['year'] as int?;
      final month = article['month'] as int?;
      final isLatest = year == latestYear && month == latestMonth;

      if (!isLatest && !dividerInserted) {
        listItems.add('divider');
        dividerInserted = true;
      }
      listItems.add(article);
    }

    return Column(
      children: [
        // Category filter bar
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
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[200],
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
                  : _articles.isEmpty
                      ? const Center(child: Text('No articles found.'))
                      : ListView.builder(
                          itemCount: listItems.length,
                          itemBuilder: (context, index) {
                            final item = listItems[index];

                            // Divider between latest and older
                            if (item == 'divider') {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    const Expanded(child: Divider(thickness: 1.5)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        'Earlier Issues',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[600],
                                          letterSpacing: 0.5,
                                        ),
                                      ),
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

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Month/year header when first article of that group
                                if (index == 0 ||
                                    (index > 0 &&
                                        listItems[index - 1] == 'divider') ||
                                    (index > 0 &&
                                        listItems[index - 1] is Map &&
                                        ((listItems[index - 1] as Map)['year'] != year ||
                                            (listItems[index - 1] as Map)['month'] != month)))
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${_monthName(month ?? 0)} ${year ?? ''}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isLatest
                                                ? Theme.of(context).colorScheme.primary
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        if (isLatest) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'Latest',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  leading: imgUrl != null && imgUrl.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            imgUrl,
                                            width: 90,
                                            height: 90,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 90,
                                              height: 90,
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.image_not_supported,
                                                  color: Colors.grey, size: 32),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.article,
                                              color: Colors.grey, size: 32),
                                        ),
                                  title: Text(
                                    article['title'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 15),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '$authors · ${article['category'] ?? ''}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ArticleScreen(articleId: article['id']),
                                      ),
                                    );
                                  },
                                ),
                                const Divider(height: 1),
                              ],
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

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
          .from('article')
          .select()
          .eq('id', widget.articleId)
          .single();
      setState(() {
        _article = response;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Article'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((_article!['img'] as String?)?.isNotEmpty == true)
                        Image.network(
                          _article!['img'],
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _article!['title'] ?? '',
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (_article!['authors'] as List?)?.join(', ') ?? '',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_article!['category'] ?? ''} · ${_article!['month']}/${_article!['year']}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              _article!['content'] ?? '',
                              style: const TextStyle(fontSize: 16, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}