import 'dart:math';
import 'package:flutter/material.dart';

enum CellState { hidden, revealed, flagged }

class MinesweeperScreen extends StatefulWidget {
  const MinesweeperScreen({super.key});

  @override
  State<MinesweeperScreen> createState() => _MinesweeperScreenState();
}

class _MinesweeperScreenState extends State<MinesweeperScreen> {
  static const int rows = 12;
  static const int cols = 9;
  static const int totalMines = 18;

  late List<List<bool>> _mines;
  late List<List<int>> _adjacency;
  late List<List<CellState>> _cellState;
  bool _gameOver = false;
  bool _won = false;
  bool _started = false;
  int _flagsPlaced = 0;
  late Stopwatch _stopwatch;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _initBoard();
  }

  void _initBoard() {
    _mines = List.generate(rows, (_) => List.filled(cols, false));
    _adjacency = List.generate(rows, (_) => List.filled(cols, 0));
    _cellState = List.generate(rows, (_) => List.filled(cols, CellState.hidden));
    _gameOver = false;
    _won = false;
    _started = false;
    _flagsPlaced = 0;
    _stopwatch.reset();
    _elapsedSeconds = 0;
  }

  void _placeMines(int safeRow, int safeCol) {
    final rand = Random();
    int placed = 0;
    while (placed < totalMines) {
      final r = rand.nextInt(rows);
      final c = rand.nextInt(cols);
      // Don't place on first tap or its neighbors
      if ((r - safeRow).abs() <= 1 && (c - safeCol).abs() <= 1) continue;
      if (_mines[r][c]) continue;
      _mines[r][c] = true;
      placed++;
    }
    // Calculate adjacency
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (_mines[r][c]) { _adjacency[r][c] = -1; continue; }
        int count = 0;
        for (final dr in [-1, 0, 1]) {
          for (final dc in [-1, 0, 1]) {
            final nr = r + dr, nc = c + dc;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && _mines[nr][nc]) count++;
          }
        }
        _adjacency[r][c] = count;
      }
    }
  }

  void _reveal(int r, int c) {
    if (_gameOver || _won) return;
    if (_cellState[r][c] != CellState.hidden) return;

    if (!_started) {
      _placeMines(r, c);
      _started = true;
      _stopwatch.start();
      _startTimer();
    }

    setState(() {
      if (_mines[r][c]) {
        // Hit a mine — reveal all mines
        _gameOver = true;
        _stopwatch.stop();
        for (int i = 0; i < rows; i++) {
          for (int j = 0; j < cols; j++) {
            if (_mines[i][j]) _cellState[i][j] = CellState.revealed;
          }
        }
      } else {
        _floodReveal(r, c);
        _checkWin();
      }
    });
  }

  void _floodReveal(int r, int c) {
    if (r < 0 || r >= rows || c < 0 || c >= cols) return;
    if (_cellState[r][c] != CellState.hidden) return;
    if (_mines[r][c]) return;

    _cellState[r][c] = CellState.revealed;
    if (_adjacency[r][c] == 0) {
      for (final dr in [-1, 0, 1]) {
        for (final dc in [-1, 0, 1]) {
          _floodReveal(r + dr, c + dc);
        }
      }
    }
  }

  void _toggleFlag(int r, int c) {
    if (_gameOver || _won) return;
    if (_cellState[r][c] == CellState.revealed) return;
    setState(() {
      if (_cellState[r][c] == CellState.flagged) {
        _cellState[r][c] = CellState.hidden;
        _flagsPlaced--;
      } else {
        _cellState[r][c] = CellState.flagged;
        _flagsPlaced++;
      }
    });
  }

  void _checkWin() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!_mines[r][c] && _cellState[r][c] != CellState.revealed) return;
      }
    }
    _won = true;
    _stopwatch.stop();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_stopwatch.isRunning) {
        setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
        return true;
      }
      return false;
    });
  }

  String _formatTime(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _numberColor(int n) {
    switch (n) {
      case 1: return Colors.blue[700]!;
      case 2: return Colors.green[700]!;
      case 3: return Colors.red[700]!;
      case 4: return Colors.indigo[900]!;
      case 5: return Colors.red[900]!;
      case 6: return Colors.cyan[700]!;
      case 7: return Colors.black;
      case 8: return Colors.grey[600]!;
      default: return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cellSize = (MediaQuery.of(context).size.width - 32) / cols;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Minesweeper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _initBoard()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Mines remaining
                Row(children: [
                  const Text('💣', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text('${totalMines - _flagsPlaced}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
                // Emoji face
                GestureDetector(
                  onTap: () => setState(() => _initBoard()),
                  child: Text(
                    _gameOver ? '😵' : _won ? '😎' : '🙂',
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                // Timer
                Row(children: [
                  const Icon(Icons.timer_outlined, size: 20),
                  const SizedBox(width: 4),
                  Text(_formatTime(_elapsedSeconds),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
              ],
            ),
          ),

          // Game over / win banner
          if (_gameOver || _won)
            Container(
              width: double.infinity,
              color: _won ? Colors.green[100] : Colors.red[100],
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _won ? '🎉 You won! Tap 🙂 to play again' : '💥 Game over! Tap 😵 to try again',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _won ? Colors.green[800] : Colors.red[800],
                ),
              ),
            ),

          // Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: cellSize * cols,
              height: cellSize * rows,
              child: Stack(
                children: [
                  for (int r = 0; r < rows; r++)
                    for (int c = 0; c < cols; c++)
                      Positioned(
                        left: c * cellSize,
                        top: r * cellSize,
                        child: GestureDetector(
                          onTap: () => _reveal(r, c),
                          onLongPress: () => _toggleFlag(r, c),
                          child: _buildCell(r, c, cellSize),
                        ),
                      ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text(
            'Long press to place a flag 🚩',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int r, int c, double size) {
    final state = _cellState[r][c];
    final isMine = _mines[r][c];
    final adj = _adjacency[r][c];

    if (state == CellState.revealed) {
      if (isMine) {
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: Colors.red[400],
            border: Border.all(color: Colors.grey[400]!, width: 0.5),
          ),
          child: const Center(child: Text('💣', style: TextStyle(fontSize: 16))),
        );
      }
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          border: Border.all(color: Colors.grey[400]!, width: 0.5),
        ),
        child: Center(
          child: adj > 0
              ? Text('$adj',
                  style: TextStyle(
                    fontSize: size * 0.5,
                    fontWeight: FontWeight.bold,
                    color: _numberColor(adj),
                  ))
              : null,
        ),
      );
    }

    if (state == CellState.flagged) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: Colors.grey[350],
          border: Border.all(color: Colors.grey[500]!, width: 0.5),
          boxShadow: [
            BoxShadow(color: Colors.white.withOpacity(0.8), offset: const Offset(-1, -1), blurRadius: 1),
            BoxShadow(color: Colors.grey.withOpacity(0.6), offset: const Offset(1, 1), blurRadius: 1),
          ],
        ),
        child: const Center(child: Text('🚩', style: TextStyle(fontSize: 16))),
      );
    }

    // Hidden cell — raised 3D look
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: Colors.grey[350],
        border: Border.all(color: Colors.grey[500]!, width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.white.withOpacity(0.8), offset: const Offset(-1, -1), blurRadius: 1),
          BoxShadow(color: Colors.grey.withOpacity(0.6), offset: const Offset(1, 1), blurRadius: 1),
        ],
      ),
    );
  }
}