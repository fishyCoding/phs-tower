class CrosswordClue {
  final String number;
  final String clue;
  final String answer;
  final int row;
  final int col;
  final String direction;

  CrosswordClue({
    required this.number,
    required this.clue,
    required this.answer,
    required this.row,
    required this.col,
    required this.direction,
  });
}

class Crossword {
  final int id;
  final String title;
  final String author;
  final DateTime date;
  final List<CrosswordClue> clues;
  final int gridRows;
  final int gridCols;

  Crossword({
    required this.id,
    required this.title,
    required this.author,
    required this.date,
    required this.clues,
    required this.gridRows,
    required this.gridCols,
  });

  factory Crossword.fromMap(Map<String, dynamic> map) {
    final cluesData = map['clues'];
    final List<CrosswordClue> clueList = [];
    int maxRow = 0, maxCol = 0;

    // Handle both Map<String,dynamic> and nested maps from jsonb
    Map<String, dynamic> cluesMap;
    if (cluesData is Map) {
      cluesMap = Map<String, dynamic>.from(cluesData);
    } else {
      throw Exception('clues is not a Map: ${cluesData.runtimeType}');
    }

    for (final direction in ['across', 'down']) {
      final dirData = cluesMap[direction];
      if (dirData == null) continue;
      final dirMap = Map<String, dynamic>.from(dirData as Map);

      for (final entry in dirMap.entries) {
        final data = Map<String, dynamic>.from(entry.value as Map);
        final row = (data['row'] as num).toInt();
        final col = (data['col'] as num).toInt();
        final answer = data['answer'] as String;

        clueList.add(CrosswordClue(
          number: entry.key,
          clue: data['clue'] as String,
          answer: answer,
          row: row,
          col: col,
          direction: direction,
        ));

        if (direction == 'across') {
          if (row > maxRow) maxRow = row;
          if (col + answer.length - 1 > maxCol) maxCol = col + answer.length - 1;
        } else {
          if (row + answer.length - 1 > maxRow) maxRow = row + answer.length - 1;
          if (col > maxCol) maxCol = col;
        }
      }
    }

    return Crossword(
      id: (map['id'] as num).toInt(),
      title: map['title'] as String? ?? '',
      author: map['author'] as String? ?? '',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      clues: clueList,
      gridRows: maxRow + 1,
      gridCols: maxCol + 1,
    );
  }

  List<List<String?>> buildGrid() {
    final grid = List.generate(gridRows, (_) => List<String?>.filled(gridCols, null));
    for (final clue in clues) {
      for (int i = 0; i < clue.answer.length; i++) {
        final r = clue.direction == 'across' ? clue.row : clue.row + i;
        final c = clue.direction == 'across' ? clue.col + i : clue.col;
        if (r < gridRows && c < gridCols) {
          grid[r][c] = clue.answer[i];
        }
      }
    }
    return grid;
  }

  Map<String, String> buildCellNumbers() {
    final Map<String, String> numbers = {};
    for (final clue in clues) {
      final key = '${clue.row},${clue.col}';
      if (!numbers.containsKey(key)) {
        numbers[key] = clue.number;
      }
    }
    return numbers;
  }
}