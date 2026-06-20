import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Games',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A2E))),
                const SizedBox(height: 4),
                const Text('Play games from The Tower',
                    style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF888888),
                        letterSpacing: 0.1)),
              ],
            ),
          ),
          // Cards
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                _GameCard(
                  title: 'Crossword',
                  subtitle: 'Weekly puzzles',
                  description: 'Test your vocabulary with crosswords written by Tower staff.',
                  icon: Icons.grid_on_rounded,
                  accentColor: const Color(0xFF1A1A2E),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CrosswordListScreen())),
                ),
                const SizedBox(height: 14),
                _GameCard(
                  title: 'Minesweeper',
                  subtitle: 'Classic puzzle',
                  description: 'Clear the minefield without triggering a single bomb.',
                  icon: Icons.blur_on_rounded,
                  accentColor: const Color(0xFF2D6A4F),
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
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon block
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 18),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.5), size: 16),
          ],
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
        title: Text('Crossword', style: GoogleFonts.playfairDisplay()),
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
                              style: GoogleFonts.playfairDisplay(
                                  fontWeight: FontWeight.w600)),
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
                style: GoogleFonts.playfairDisplay(
                    fontSize: 16, fontWeight: FontWeight.bold)),
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