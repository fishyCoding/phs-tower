import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../debug/typography.dart';
import '../services/bookmarks.dart';

/// Byline for a raw article map, falling back to the masthead when no authors
/// are credited.
String _authorLine(List? authors) {
  final named = (authors ?? [])
      .where((a) => (a?.toString().trim() ?? '').isNotEmpty)
      .map((a) => a.toString())
      .toList();
  return named.isEmpty ? 'Editorial Board' : named.join(', ');
}

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

  static const _ink = Color(0xFF000000); // body & headline text — black
  static const _link = Color(0xFF1A4E8A);

  void _share() {
    final a = _article;
    if (a == null) return;
    final title = a['title'] as String? ?? '';
    final byline = _authorLine(a['authors'] as List?);
    final url = 'https://www.towerphs.com/articles/'
        '${a['year']}/${a['month']}/${a['category']}/${a['id']}';
    Share.share('"$title" by $byline — The Tower\n$url');
  }

  /// Renders the article body as Markdown. The DB stores single `\n` as soft
  /// word-wrap hints and blank lines as paragraph breaks — both of which map
  /// cleanly onto standard Markdown (soft breaks collapse to spaces, blank
  /// lines start new paragraphs), so the raw content is passed through as-is.
  Widget _buildBody(String raw) {
    final normalised = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    return MarkdownBody(
      data: normalised,
      selectable: true,
      onTapLink: (text, href, title) async {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 16, height: 1.65, color: _ink),
        pPadding: const EdgeInsets.only(bottom: 16),
        h1: headline(context, size: 24, color: _ink),
        h2: headline(context, size: 21, color: _ink),
        h3: headline(context, size: 18, color: _ink),
        h1Padding: const EdgeInsets.only(top: 8, bottom: 6),
        h2Padding: const EdgeInsets.only(top: 8, bottom: 6),
        h3Padding: const EdgeInsets.only(top: 8, bottom: 4),
        strong: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
        em: const TextStyle(fontStyle: FontStyle.italic, color: _ink),
        a: const TextStyle(
            color: _link, decoration: TextDecoration.underline),
        listBullet: const TextStyle(fontSize: 16, height: 1.65, color: _ink),
        blockquote: TextStyle(
            fontSize: 16, height: 1.6, color: Colors.grey[700], fontStyle: FontStyle.italic),
        blockquoteDecoration: const BoxDecoration(
          color: Color(0xFFF6F6F6),
          border: Border(left: BorderSide(color: Color(0xFFCCCCCC), width: 3)),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        code: GoogleFonts.robotoMono(
            fontSize: 14, backgroundColor: const Color(0xFFF0F0F0), color: _ink),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(6),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(),
        title: Text('Article', style: headline(context, size: 20, color: Colors.black)),
        actions: [
          if (_article != null) ...[
            AnimatedBuilder(
              animation: BookmarksService.instance,
              builder: (context, _) {
                final saved = BookmarksService.instance
                    .isSaved(_article!['id'] as int);
                return IconButton(
                  icon: Icon(
                    saved ? Icons.bookmark : Icons.bookmark_border,
                    color: const Color(0xFF072636),
                  ),
                  tooltip: saved ? 'Remove from saved' : 'Save article',
                  onPressed: () =>
                      BookmarksService.instance.toggle(_article!),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.black),
              tooltip: 'Share',
              onPressed: _share,
            ),
          ],
        ],
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
                        CachedNetworkImage(
                          imageUrl: _article!['img'],
                          width: double.infinity, height: 220, fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              height: 220, color: const Color(0xFFF0F0F0)),
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),

                      // Article body
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFA31621),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _catLabel(_article!['category'] ?? '')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                  height: 1.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_article!['title'] ?? '',
                                style: headline(context, size: 26, color: Colors.black)),
                            const SizedBox(height: 10),
                            Text(
                              _authorLine(_article!['authors'] as List?),
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
                            _buildBody(_article!['content'] ?? ''),
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
                        style: headline(context, size: 15, color: Colors.black),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _authorLine(article['authors'] as List?),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                // Thumbnail
                if (img.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: img,
                      width: 72, height: 72,
                      memCacheWidth: 216,
                      memCacheHeight: 216,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: const Color(0xFFF0F0F0)),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
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