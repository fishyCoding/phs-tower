import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../screens/article_screen.dart';

/// OneSignal App ID (dashboard → Settings → Keys & IDs).
const String kOneSignalAppId = '2297527a-75df-4f38-9241-ebb50e93b268';

/// Global navigator key so a notification tap can push a route without needing
/// a BuildContext. Wired onto MaterialApp in main.dart.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static bool get _configured =>
      kOneSignalAppId.isNotEmpty && !kOneSignalAppId.startsWith('YOUR-');

  /// Initialise OneSignal, ask for permission, and route taps to articles.
  /// Safe to call unconditionally — it no-ops until an App ID is set.
  static Future<void> init() async {
    if (!_configured) return;

    // Verbose logging during development makes registration issues visible.
    if (kDebugMode) OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    OneSignal.initialize(kOneSignalAppId);

    // Everyone gets general announcements ("new issue is out"). Editors can
    // still target this segment from the OneSignal dashboard.
    OneSignal.User.addTagWithKey('audience', 'all');

    // Android 13+ / iOS show the OS permission prompt; harmless if already set.
    await OneSignal.Notifications.requestPermission(true);

    OneSignal.Notifications.addClickListener(_onClick);
  }

  /// If the notification carries an `article_id` in its additional data, open
  /// that article. (Set this field when composing a push in OneSignal to
  /// deep-link straight to a story.)
  static void _onClick(OSNotificationClickEvent event) {
    final data = event.notification.additionalData;
    final raw = data?['article_id'];
    final id = raw is int ? raw : int.tryParse('${raw ?? ''}');
    if (id == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ArticleScreen(articleId: id)),
    );
  }
}
