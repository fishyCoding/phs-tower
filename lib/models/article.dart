class Article {
  final int id;
  final String title;
  final List<String> authors;
  final int month;
  final int year;
  final String category;
  final String img;
  final String contentInfo;
  final String content;

  /// Short summary shown on the large front-page cards. Sourced from the
  /// `blurb` column (not yet populated) — falls back to placeholder text.
  final String blurb;

  Article({
    required this.id,
    required this.title,
    required this.authors,
    required this.month,
    required this.year,
    required this.category,
    required this.img,
    this.contentInfo = '',
    this.content = '',
    this.blurb = '',
  });

  /// Public web page for this article on towerphs.com.
  String get webUrl =>
      'https://www.towerphs.com/articles/$year/$month/$category/$id';

  /// Byline for display, falling back to the masthead when no authors are
  /// credited on the article.
  String get authorLine {
    final named = authors.where((a) => a.trim().isNotEmpty).toList();
    return named.isEmpty ? 'Editorial Board' : named.join(', ');
  }

  Article copyWith({String? content}) {
    return Article(
      id: id,
      title: title,
      authors: authors,
      month: month,
      year: year,
      category: category,
      img: img,
      contentInfo: contentInfo,
      content: content ?? this.content,
      blurb: blurb,
    );
  }

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: map['id'] as int,
      title: map['title'] as String? ?? '',
      authors: List<String>.from(map['authors'] as List? ?? []),
      month: map['month'] as int? ?? 0,
      year: map['year'] as int? ?? 0,
      category: map['category'] as String? ?? '',
      img: map['img'] as String? ?? '',
      contentInfo: map['content-info'] as String? ?? '',
      content: map['content'] as String? ?? '',
      blurb: map['blurb'] as String? ?? '',
    );
  }
}