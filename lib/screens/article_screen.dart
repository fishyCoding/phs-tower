import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ArticleScreen extends StatefulWidget {
  final int articleId;
  const ArticleScreen({super.key, required this.articleId});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  Map<String, dynamic>? _article;
  List<Map<String, dynamic>> _related = [];
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
      await _fetchRelated(response['category'] as String?, response['id'] as int);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _fetchRelated(String? category, int excludeId) async {
    if (category == null) return;
    try {
      final response = await Supabase.instance.client
          .from('article')
          .select('id, title, authors, month, year, category, img')
          .eq('published', true)
          .eq('category', category)
          .neq('id', excludeId)
          .order('year', ascending: false)
          .order('month', ascending: false)
          .limit(3);
      setState(() {
        _related = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (_) {}
  }

  String _catLabel(String cat) {
    switch (cat.toLowerCase()) {
      case 'news-features': return 'News';
      case 'arts-entertainment': return 'Arts';
      case 'sports': return 'Sports';
      case 'opinions': return 'Opinions';
      default: return cat;
    }
  }

  /// Splits content on blank lines into paragraphs, collapses soft line-breaks
  /// (single \n used as word-wrap hints in the DB) into spaces.
  List<Widget> _buildParagraphs(String raw) {
    // Normalise line endings
    final normalised = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // Split on one or more blank lines → real paragraph breaks
    final paragraphs = normalised
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.replaceAll('\n', ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final widgets = <Widget>[];
    for (int i = 0; i < paragraphs.length; i++) {
      widgets.add(Text(
        paragraphs[i],
        style: const TextStyle(
          fontSize: 16,
          height: 1.65,
          color: Color(0xFF1A1A2E),
        ),
      ));
      if (i < paragraphs.length - 1) {
        widgets.add(const SizedBox(height: 16));
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(),
        title: Text('Article', style: GoogleFonts.playfairDisplay(
          color: const Color(0xFF1A1A2E),
        )),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero image — hidden if missing or broken
                      if ((_article!['img'] as String?)?.trim().isNotEmpty == true)
                        Image.network(
                          _article!['img'],
                          width: double.infinity, height: 220, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),

                      // Article body
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _catLabel(_article!['category'] ?? '').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_article!['title'] ?? '',
                                style: GoogleFonts.playfairDisplay(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1A2E),
                                    height: 1.25)),
                            const SizedBox(height: 10),
                            Text(
                              (_article!['authors'] as List?)?.join(', ') ?? '',
                              style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_article!['month']}/${_article!['year']}',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            const SizedBox(height: 18),
                            const Divider(color: Color(0xFFE0E0E0)),
                            const SizedBox(height: 18),
                            ..._buildParagraphs(_article!['content'] ?? ''),
                          ],
                        ),
                      ),

                      // Related articles
                      if (_related.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Divider(color: Color(0xFFE0E0E0)),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Text(
                            'MORE FROM THIS SECTION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                        ..._related.map((a) => _RelatedArticleTile(
                          article: a,
                          catLabel: _catLabel(a['category'] ?? ''),
                        )),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
    );
  }
}

// ── Related article tile ───────────────────────────────────────────────────────

class _RelatedArticleTile extends StatelessWidget {
  final Map<String, dynamic> article;
  final String catLabel;

  const _RelatedArticleTile({required this.article, required this.catLabel});

  @override
  Widget build(BuildContext context) {
    final img = article['img'] as String? ?? '';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleScreen(articleId: article['id'] as int),
        ),
      ),
      child: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text side
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        catLabel.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: Color(0xFF888888),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article['title'] ?? '',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A2E),
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((article['authors'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 5),
                        Text(
                          (article['authors'] as List).join(', '),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ],
                  ),
                ),
                // Thumbnail
                if (img.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      img,
                      width: 72, height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}