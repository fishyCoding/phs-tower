import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../debug/typography.dart';
import '../debug/vanguard_author.dart';
import '../models/vanguard.dart';
import 'vanguard_viewer.dart';

/// Vanguard section: list of published visual-spread issues, newest first.
/// Lives inside the News tab's IndexedStack (like SearchScreen), so it fetches
/// once on creation and offers pull-to-refresh.
class VanguardListScreen extends StatefulWidget {
  const VanguardListScreen({super.key});

  @override
  State<VanguardListScreen> createState() => _VanguardListScreenState();
}

class _VanguardListScreenState extends State<VanguardListScreen> {
  List<VanguardIssue> _issues = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final response = await Supabase.instance.client
          .from('vanguard')
          .select('id, title, month, year, pages')
          .eq('published', true)
          .order('year', ascending: false)
          .order('month', ascending: false);

      if (!mounted) return;
      setState(() {
        _issues = (response as List)
            .map((m) => VanguardIssue.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _monthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return month >= 1 && month <= 12 ? months[month] : '';
  }

  void _open(VanguardIssue issue) {
    // Warm the first page while the route transition plays.
    if (issue.pages.isNotEmpty) {
      precacheImage(
        CachedNetworkImageProvider(issue.pages.first.image),
        context,
        onError: (_, __) {},
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VanguardViewerScreen(issue: issue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vanguard',
                            style: headline(context,
                                size: 28, color: Colors.black)),
                        const SizedBox(height: 3),
                        const Text(
                          'Visual stories from The Tower',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF888888)),
                        ),
                      ],
                    ),
                  ),
                  if (kDebugMode)
                    IconButton(
                      tooltip: 'Author tool (debug)',
                      icon: const Icon(Icons.edit_outlined,
                          color: Color(0xFF072636)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VanguardAuthorScreen()),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_issues.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF072636),
        onRefresh: _fetch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Icon(Icons.auto_stories_outlined,
                size: 48, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Center(
              child: Text('No Vanguard issues yet',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400])),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF072636),
      onRefresh: _fetch,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _issues.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
        itemBuilder: (context, index) {
          final issue = _issues[index];
          return InkWell(
            onTap: () => _open(issue),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
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
                            '${_monthName(issue.month).toUpperCase()} ${issue.year}',
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
                        Text(
                          issue.title.isEmpty ? 'Vanguard' : issue.title,
                          style: headline(context,
                              size: 18, color: Colors.black),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${issue.pages.length} page${issue.pages.length == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF999999)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
