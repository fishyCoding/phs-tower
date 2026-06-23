import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Embeds a Google Form in a WebView. Appends `embedded=true` so Google strips
/// its own page chrome, and shows a spinner while the form loads.
class GoogleFormWebView extends StatefulWidget {
  final String formUrl;
  const GoogleFormWebView({super.key, required this.formUrl});

  String get _embeddedUrl {
    if (formUrl.contains('embedded=true')) return formUrl;
    final sep = formUrl.contains('?') ? '&' : '?';
    return '$formUrl${sep}embedded=true';
  }

  @override
  State<GoogleFormWebView> createState() => _GoogleFormWebViewState();
}

class _GoogleFormWebViewState extends State<GoogleFormWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget._embeddedUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
