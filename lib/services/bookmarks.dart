import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locally saved articles, persisted as JSON in SharedPreferences.
/// Each entry stores just enough to render a list tile offline
/// (`id`, `title`, `category`, `authors`); the full article is fetched by id
/// when opened.
class BookmarksService extends ChangeNotifier {
  BookmarksService._();
  static final BookmarksService instance = BookmarksService._();

  static const _prefsKey = 'bookmarked_articles';

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        _items = List<Map<String, dynamic>>.from(
            (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
        notifyListeners();
      }
    } catch (_) {
      // Corrupt store — start fresh rather than crash.
      _items = [];
    }
  }

  bool isSaved(int id) => _items.any((e) => e['id'] == id);

  Future<void> toggle(Map<String, dynamic> article) async {
    final id = article['id'] as int;
    if (isSaved(id)) {
      _items.removeWhere((e) => e['id'] == id);
    } else {
      _items.insert(0, {
        'id': id,
        'title': article['title'] ?? '',
        'category': article['category'] ?? '',
        'authors': article['authors'] ?? [],
      });
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_items));
    } catch (_) {}
  }
}
