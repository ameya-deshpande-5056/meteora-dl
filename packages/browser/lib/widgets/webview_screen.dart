import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/media_candidate.dart';
import '../media_candidate_collector.dart';
import 'media_capture_script.dart';

/// A minimal in-app browser backed by webview_flutter.
///
/// Aside from rendering pages it is the app's source of first-party auth
/// context: because Android sandboxes other browsers, cookies/UA/referer only
/// exist for pages loaded here.
///
/// Degrades gracefully when no platform implementation is available (unit tests
/// or unsupported platforms) by showing a placeholder.
class WebViewScreen extends StatefulWidget {
  final String initialUrl;
  final ValueChanged<String>? onUrlChanged;
  final ValueChanged<String>? onPageTitleChanged;

  /// Called once per newly discovered media candidate.
  final ValueChanged<MediaCandidate>? onMediaDetected;

  const WebViewScreen({
    super.key,
    this.initialUrl = 'https://www.google.com',
    this.onUrlChanged,
    this.onPageTitleChanged,
    this.onMediaDetected,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  WebViewController? _controller;
  final MediaCandidateCollector _collector = MediaCandidateCollector();
  double _progress = 0;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    late final WebViewController controller;
    try {
      controller = WebViewController();
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'MeteoraMedia',
          onMessageReceived: (message) => _handlePageMessage(message.message),
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (p) {
              if (mounted) setState(() => _progress = p / 100.0);
            },
            onPageStarted: (url) {
              _collector.clear();
              if (mounted) setState(() => _progress = 0.0);
              widget.onUrlChanged?.call(url);
            },
            onPageFinished: (url) {
              final title = controller.getTitle();
              widget.onUrlChanged?.call(url);
              title.then((value) {
                if (value != null) widget.onPageTitleChanged?.call(value);
              });
              controller.runJavaScript(mediaCaptureScript);
            },
          ),
        );
      _controller = controller;
      controller.loadRequest(_normalize(widget.initialUrl));
    } catch (_) {
      _unavailable = true;
    }
  }

  Uri _normalize(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) return uri;
    return Uri.parse('https://$raw');
  }

  void _handlePageMessage(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final url = decoded['url'];
    if (url is! String) return;
    final candidate = _collector.add(
      url: url,
      contentType: decoded['contentType'] as String?,
      pageTitle: decoded['title'] as String?,
    );
    if (candidate != null) widget.onMediaDetected?.call(candidate);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_unavailable || controller == null) {
      return const Center(
        child: Text('Browser engine unavailable in this environment.'),
      );
    }
    return Column(
      children: [
        if (_progress < 1.0)
          LinearProgressIndicator(value: _progress == 0 ? null : _progress),
        Expanded(child: WebViewWidget(controller: controller)),
      ],
    );
  }
}
