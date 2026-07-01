import 'package:flutter/material.dart';
import '../models/crossword.dart';

class CrosswordWidget extends StatefulWidget {
  final Crossword crossword;
  const CrosswordWidget({super.key, required this.crossword});

  @override
  State<CrosswordWidget> createState() => _CrosswordWidgetState();
}

class _CrosswordWidgetState extends State<CrosswordWidget> {
  late List<List<String?>> _solution;
  late List<List<String>> _userInput;
  late Map<String, String> _cellNumbers;
  late List<List<bool>> _blackCells;

  int? _selectedRow;
  int? _selectedCol;
  String _selectedDirection = 'across';
  String? _selectedClueNumber;
  bool _revealed = false;
  bool _autocorrect = false;

  @override
  void initState() {
    super.initState();
    _solution = widget.crossword.buildGrid();
    _cellNumbers = widget.crossword.buildCellNumbers();
    _userInput = List.generate(widget.crossword.gridRows,
        (_) => List.filled(widget.crossword.gridCols, ''));
    _blackCells = List.generate(
        widget.crossword.gridRows,
        (r) => List.generate(
            widget.crossword.gridCols, (c) => _solution[r][c] == null));
  }

  List<CrosswordClue> get _acrossClues => widget.crossword.clues
      .where((c) => c.direction == 'across')
      .toList()
    ..sort((a, b) => int.parse(a.number).compareTo(int.parse(b.number)));

  List<CrosswordClue> get _downClues => widget.crossword.clues
      .where((c) => c.direction == 'down')
      .toList()
    ..sort((a, b) => int.parse(a.number).compareTo(int.parse(b.number)));

  CrosswordClue? get _activeClue {
    if (_selectedClueNumber == null) return null;
    return widget.crossword.clues.firstWhere(
        (c) => c.number == _selectedClueNumber && c.direction == _selectedDirection,
        orElse: () => widget.crossword.clues.first);
  }

  bool _isCellInActiveClue(int r, int c) {
    final clue = _activeClue;
    if (clue == null) return false;
    if (clue.direction == 'across') {
      return r == clue.row && c >= clue.col && c < clue.col + clue.answer.length;
    } else {
      return c == clue.col && r >= clue.row && r < clue.row + clue.answer.length;
    }
  }

  void _onCellTap(int r, int c) {
    if (_blackCells[r][c]) return;
    if (_selectedRow == r && _selectedCol == c) {
      // Toggle direction
      setState(() {
        _selectedDirection = _selectedDirection == 'across' ? 'down' : 'across';
        _updateSelectedClue(r, c);
      });
    } else {
      setState(() {
        _selectedRow = r;
        _selectedCol = c;
        _updateSelectedClue(r, c);
      });
    }
  }

  void _updateSelectedClue(int r, int c) {
    // Find which clue covers this cell in the current direction
    for (final clue in widget.crossword.clues) {
      if (clue.direction != _selectedDirection) continue;
      if (clue.direction == 'across') {
        if (r == clue.row && c >= clue.col && c < clue.col + clue.answer.length) {
          _selectedClueNumber = clue.number;
          return;
        }
      } else {
        if (c == clue.col && r >= clue.row && r < clue.row + clue.answer.length) {
          _selectedClueNumber = clue.number;
          return;
        }
      }
    }
    // Try the other direction
    final other = _selectedDirection == 'across' ? 'down' : 'across';
    for (final clue in widget.crossword.clues) {
      if (clue.direction != other) continue;
      if (clue.direction == 'across') {
        if (r == clue.row && c >= clue.col && c < clue.col + clue.answer.length) {
          _selectedDirection = other;
          _selectedClueNumber = clue.number;
          return;
        }
      } else {
        if (c == clue.col && r >= clue.row && r < clue.row + clue.answer.length) {
          _selectedDirection = other;
          _selectedClueNumber = clue.number;
          return;
        }
      }
    }
  }

  void _onKeyTap(String letter) {
    if (_selectedRow == null || _selectedCol == null) return;
    setState(() {
      _userInput[_selectedRow!][_selectedCol!] = letter;
      _advanceCursor();
    });
  }

  void _onBackspace() {
    if (_selectedRow == null || _selectedCol == null) return;
    setState(() {
      if (_userInput[_selectedRow!][_selectedCol!].isNotEmpty) {
        _userInput[_selectedRow!][_selectedCol!] = '';
      } else {
        _retreatCursor();
      }
    });
  }

  void _advanceCursor() {
    if (_selectedRow == null || _selectedCol == null) return;
    int r = _selectedRow!, c = _selectedCol!;
    if (_selectedDirection == 'across') {
      c++;
      if (c >= widget.crossword.gridCols || _blackCells[r][c]) return;
    } else {
      r++;
      if (r >= widget.crossword.gridRows || _blackCells[r][c]) return;
    }
    _selectedRow = r;
    _selectedCol = c;
  }

  void _retreatCursor() {
    if (_selectedRow == null || _selectedCol == null) return;
    int r = _selectedRow!, c = _selectedCol!;
    if (_selectedDirection == 'across') {
      c--;
      if (c < 0 || _blackCells[r][c]) return;
    } else {
      r--;
      if (r < 0 || _blackCells[r][c]) return;
    }
    _selectedRow = r;
    _selectedCol = c;
  }

  bool get _isSolved {
    for (int r = 0; r < widget.crossword.gridRows; r++) {
      for (int c = 0; c < widget.crossword.gridCols; c++) {
        if (_solution[r][c] != null && _userInput[r][c] != _solution[r][c]) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cellSize = (MediaQuery.of(context).size.width - 32) / widget.crossword.gridCols;

    return Column(
      children: [
        // Active clue display
        if (_activeClue != null)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '${_activeClue!.number} ${_activeClue!.direction.toUpperCase()}: ${_activeClue!.clue}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),

        // Grid
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: cellSize * widget.crossword.gridCols,
            height: cellSize * widget.crossword.gridRows,
            child: Stack(
              children: [
                // Build grid cells
                for (int r = 0; r < widget.crossword.gridRows; r++)
                  for (int c = 0; c < widget.crossword.gridCols; c++)
                    Positioned(
                      left: c * cellSize,
                      top: r * cellSize,
                      child: GestureDetector(
                        onTap: () => _onCellTap(r, c),
                        child: _buildCell(r, c, cellSize),
                      ),
                    ),
              ],
            ),
          ),
        ),

        // Solved banner
        if (_isSolved)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Solved!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

        // Reveal button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _revealed = !_revealed;
                    if (_revealed) {
                      for (int r = 0; r < widget.crossword.gridRows; r++) {
                        for (int c = 0; c < widget.crossword.gridCols; c++) {
                          if (_solution[r][c] != null) {
                            _userInput[r][c] = _solution[r][c]!;
                          }
                        }
                      }
                    }
                  }),
                  child: Text(_revealed ? 'Hide Solution' : 'Reveal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _userInput = List.generate(widget.crossword.gridRows,
                        (_) => List.filled(widget.crossword.gridCols, ''));
                    _revealed = false;
                  }),
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
        ),

        // Autocorrect toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              Switch(
                value: _autocorrect,
                onChanged: (val) => setState(() => _autocorrect = val),
              ),
              const SizedBox(width: 8),
              const Text('Autocorrect', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                _autocorrect ? '— wrong letters shown in red' : '— off',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),

        // Keyboard
        _buildKeyboard(),

        // Clue lists
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('ACROSS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
        ),
        ..._acrossClues.map((clue) => _clueListTile(clue)),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('DOWN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
        ),
        ..._downClues.map((clue) => _clueListTile(clue)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCell(int r, int c, double size) {
    final isBlack = _blackCells[r][c];
    final isSelected = _selectedRow == r && _selectedCol == c;
    final isHighlighted = _isCellInActiveClue(r, c);
    final number = _cellNumbers['$r,$c'];
    final letter = _userInput[r][c];
    final correct = _solution[r][c] != null && letter == _solution[r][c];

    Color bgColor;
    if (isBlack) {
      bgColor = Colors.black;
    } else if (isSelected) {
      bgColor = Colors.blue[300]!;
    } else if (isHighlighted) {
      bgColor = Colors.blue[100]!;
    } else {
      bgColor = Colors.white;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: Colors.black26, width: 0.5),
      ),
      child: isBlack
          ? null
          : Stack(
              children: [
                if (number != null)
                  Positioned(
                    top: 1, left: 2,
                    child: Text(number,
                        style: TextStyle(fontSize: size * 0.22, fontWeight: FontWeight.bold)),
                  ),
                Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: size * 0.55,
                      fontWeight: FontWeight.bold,
                      color: _autocorrect && letter.isNotEmpty
                          ? (correct ? Colors.green[700] : Colors.red[700])
                          : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildKeyboard() {
    const rows = [
      ['Q','W','E','R','T','Y','U','I','O','P'],
      ['A','S','D','F','G','H','J','K','L'],
      ['⌫','Z','X','C','V','B','N','M','↵'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        children: rows.map((row) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            final isSpecial = key == '⌫' || key == '↵';
            return GestureDetector(
              onTap: () {
                if (key == '⌫') {
                  _onBackspace();
                } else if (key == '↵') {
                  setState(() {
                    _selectedDirection = _selectedDirection == 'across' ? 'down' : 'across';
                    if (_selectedRow != null && _selectedCol != null) {
                      _updateSelectedClue(_selectedRow!, _selectedCol!);
                    }
                  });
                } else {
                  _onKeyTap(key);
                }
              },
              child: Container(
                margin: const EdgeInsets.all(2),
                width: isSpecial ? 44 : 32,
                height: 40,
                decoration: BoxDecoration(
                  color: isSpecial ? Colors.grey[400] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 1, offset: const Offset(0, 1))],
                ),
                alignment: Alignment.center,
                child: Text(key,
                    style: TextStyle(fontSize: isSpecial ? 16 : 14, fontWeight: FontWeight.bold)),
              ),
            );
          }).toList(),
        )).toList(),
      ),
    );
  }

  Widget _clueListTile(CrosswordClue clue) {
    final isActive = _selectedClueNumber == clue.number && _selectedDirection == clue.direction;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDirection = clue.direction;
          _selectedClueNumber = clue.number;
          _selectedRow = clue.row;
          _selectedCol = clue.col;
        });
      },
      child: Container(
        color: isActive ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text('${clue.number}.',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isActive ? Theme.of(context).colorScheme.primary : Colors.black54)),
            ),
            Expanded(child: Text(clue.clue, style: const TextStyle(fontSize: 14))),
          ],
        ),
      ),
    );
  }
}