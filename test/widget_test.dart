import 'package:flutter_test/flutter_test.dart';

import 'package:ph_tower/models/article.dart';

void main() {
  group('Article.fromMap', () {
    test('parses a full row', () {
      final a = Article.fromMap({
        'id': 7,
        'title': 'PHS wins states',
        'authors': ['Ada Lovelace', 'Alan Turing'],
        'month': 5,
        'year': 2026,
        'category': 'sports',
        'img': 'https://example.com/x.jpg',
        'content-info': 'A short deck.',
        'content': 'Full body.',
      });
      expect(a.id, 7);
      expect(a.title, 'PHS wins states');
      expect(a.authors, ['Ada Lovelace', 'Alan Turing']);
      expect(a.month, 5);
      expect(a.year, 2026);
      expect(a.category, 'sports');
      expect(a.contentInfo, 'A short deck.');
      expect(a.content, 'Full body.');
    });

    test('defaults missing fields safely', () {
      final a = Article.fromMap({'id': 1});
      expect(a.title, '');
      expect(a.authors, isEmpty);
      expect(a.month, 0);
      expect(a.year, 0);
      expect(a.category, '');
      expect(a.img, '');
      expect(a.contentInfo, '');
      expect(a.content, '');
    });
  });

  group('Article.authorLine', () {
    Article make(List<String> authors) => Article(
          id: 1,
          title: 't',
          authors: authors,
          month: 1,
          year: 2026,
          category: 'news-features',
          img: '',
        );

    test('joins named authors', () {
      expect(make(['A', 'B']).authorLine, 'A, B');
    });

    test('falls back to Editorial Board when empty', () {
      expect(make([]).authorLine, 'Editorial Board');
    });

    test('falls back when authors are blank strings', () {
      expect(make(['', '   ']).authorLine, 'Editorial Board');
    });
  });

  test('webUrl follows the towerphs.com article pattern', () {
    final a = Article.fromMap({
      'id': 1087,
      'title': 't',
      'month': 6,
      'year': 2026,
      'category': 'news-features',
    });
    expect(a.webUrl,
        'https://www.towerphs.com/articles/2026/6/news-features/1087');
  });

  test('copyWith replaces content and keeps the rest', () {
    final a = Article.fromMap({'id': 2, 'title': 'x'});
    final b = a.copyWith(content: 'body');
    expect(b.content, 'body');
    expect(b.id, 2);
    expect(b.title, 'x');
  });
}
