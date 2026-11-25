import 'package:meta/meta.dart';

/// Captured auth context from the in-app WebView, handed to the download engine.
///
/// Android cannot read another browser's cookies/UA/headers, so MeteoraDL's
/// browser captures these from its own WebView and forwards them same-app.
@immutable
class BrowserAuthContext {
  final String url;
  final String? cookies;
  final String? userAgent;
  final String? referer;
  final Map<String, String> headers;
  final String? pageTitle;

  const BrowserAuthContext({
    required this.url,
    this.cookies,
    this.userAgent,
    this.referer,
    this.headers = const {},
    this.pageTitle,
  });
}

/// Abstract bridge between the browser and download engine. Implementations
/// forward a captured auth context to the download manager.
abstract class BrowserDownloadBridge {
  Future<void> sendToDownloadManager(BrowserAuthContext context);
}