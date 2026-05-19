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
      setState(() { _article = response; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Article', style: GoogleFonts.playfairDisplay()),
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
                          width: double.infinity, height: 220, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_article!['title'] ?? '',
                                style: GoogleFonts.playfairDisplay(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text((_article!['authors'] as List?)?.join(', ') ?? '',
                                style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text(
                              '${_article!['category'] ?? ''} · ${_article!['month']}/${_article!['year']}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
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