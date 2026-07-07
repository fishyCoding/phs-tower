import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../debug/typography.dart';
import '../debug/vanguard_author.dart';
import '../models/vanguard.dart';
import 'vanguard_viewer.dart';

/// Vanguard section: list of visual spreads from the `spreads` table, newest
/// first. Lives inside the News tab's IndexedStack (like SearchScreen), so it
/// fetches once on creation and offers pull-to-refresh.
class VanguardListScreen extends StatefulWidget {
  const VanguardListScreen({super.key});

  @override
  State<VanguardListScreen> createState() => _VanguardListScreenState();
}

class _VanguardListScreenState extends State<VanguardListScreen> {
  List<Spread> _spreads = [];
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
          .from('spreads')
          .select('id, title, src, month, year, camera_path')
          .eq('category', 'vanguard')
          .order('year', ascending: false)
          .order('month', ascending: false);

      if (!mounted) return;
      setState(() {
        _spreads = (response as List)
            .map((m) => Spread.fromMap(Map<String, dynamic>.from(m)))
            .where((s) => s.hasValidSrc)
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

  void _open(Spread spread) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VanguardViewerScreen(spread: spread),
      ),
    );
  }

  void _author(Spread spread) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VanguardAuthorScreen(src: spread.src, title: spread.title),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vanguard',
                      style: headline(context, size: 28, color: Colors.black)),
                  const SizedBox(height: 3),
                  const Text('Visual stories from The Tower',
                      style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
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
    if (_spreads.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF072636),
        onRefresh: _fetch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Icon(Icons.auto_stories_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Center(
              child: Text('No Vanguard spreads yet',
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
        itemCount: _spreads.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
        itemBuilder: (context, index) {
          final spread = _spreads[index];
          return InkWell(
            onTap: () => _open(spread),
            onLongPress: kDebugMode ? () => _author(spread) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFA31621),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${_monthName(spread.month).toUpperCase()} ${spread.year}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  height: 1.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (spread.hasGuidedPath) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.auto_stories,
                                  size: 13, color: Color(0xFF072636)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          spread.title.isEmpty ? 'Vanguard' : spread.title,
                          style: headline(context, size: 18, color: Colors.black),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
