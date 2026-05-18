import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/crossword.dart';
import '../widgets/crossword_widget.dart';
import 'minesweeper_screen.dart';

// ── Games Hub ─────────────────────────────────────────────────────────────────

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text('Games',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text('Play games from the PHS Tower',
                style: TextStyle(fontSize: 14, color: Colors.black54)),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _GameCard(
                  title: 'Crossword',
                  description: 'Classic crossword puzzles from the Tower',
                  icon: Icons.grid_on,
                  color: Colors.blue[700]!,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CrosswordListScreen())),
                ),
                _GameCard(
                  title: 'Minesweeper',
                  description: 'Clear the board without hitting a mine',
                  icon: Icons.blur_on,
                  color: Colors.green[700]!,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MinesweeperScreen())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Game Card ─────────────────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _GameCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const Spacer(),
              Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Crossword List Screen ─────────────────────────────────────────────────────

class CrosswordListScreen extends StatefulWidget {
  const CrosswordListScreen({super.key});

  @override
  State<CrosswordListScreen> createState() => _CrosswordListScreenState();
}

class _CrosswordListScreenState extends State<CrosswordListScreen> {
  List<Crossword> _crosswords = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCrosswords();
  }

  Future<void> _fetchCrosswords() async {
    try {
      final response = await Supabase.instance.client
          .from('crossword')
          .select()
          .order('date', ascending: false);

      debugPrint('Raw crossword response: ${response.runtimeType} length=${response.length}');
      if (response.isNotEmpty) {
        debugPrint('First row keys: ${response.first.keys.toList()}');
        debugPrint('First row clues type: ${response.first['clues'].runtimeType}');
      }

      final list = <Crossword>[];
      for (final row in response) {
        try {
          final map = Map<String, dynamic>.from(row as Map);
          // Handle clues whether it comes as String or Map
          final rawClues = map['clues'];
          if (rawClues is String) {
            map['clues'] = jsonDecode(rawClues);
          } else if (rawClues is Map) {
            map['clues'] = Map<String, dynamic>.from(rawClues);
          }
          list.add(Crossword.fromMap(map));
        } catch (rowError, rowStack) {
          debugPrint('Error parsing row id=${row['id']}: $rowError');
          debugPrint('$rowStack');
        }
      }

      debugPrint('Parsed ${list.length} crosswords');
      setState(() { _crosswords = list; _loading = false; });
    } catch (e, stack) {
      debugPrint('CROSSWORD FETCH ERROR: $e');
      debugPrint('$stack');
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _formatDate(DateTime date) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Crossword'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: SelectableText('Error: $_error'))
              : _crosswords.isEmpty
                  ? const Center(child: Text('No crosswords yet.'))
                  : ListView.separated(
                      itemCount: _crosswords.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final cw = _crosswords[index];
                        return ListTile(
                          leading: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: Colors.blue[700]!.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.grid_on, color: Colors.blue[700]),
                          ),
                          title: Text(cw.title,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${cw.author} · ${_formatDate(cw.date)}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CrosswordPlayScreen(crossword: cw),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

// ── Crossword Play Screen ─────────────────────────────────────────────────────

class CrosswordPlayScreen extends StatelessWidget {
  final Crossword crossword;
  const CrosswordPlayScreen({super.key, required this.crossword});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(crossword.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(crossword.author, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: CrosswordWidget(crossword: crossword),
      ),
    );
  }
}