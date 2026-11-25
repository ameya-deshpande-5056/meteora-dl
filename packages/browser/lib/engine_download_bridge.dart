import 'package:download_engine/download_engine.dart';

import 'browser_bridge.dart';

/// Bridges a captured WebView auth context into the download engine.
///
/// This is the Android answer to qtIDM's Native Messaging host: instead of a
/// browser extension forwarding cookies/UA/referer to a desktop app over
/// native messaging, the in-app WebView hands its own first-party context
/// straight to the queue.
class EngineDownloadBridge implements BrowserDownloadBridge {
  final DownloadEngine engine;
  final String? destinationDirectory;

  EngineDownloadBridge({
    required this.engine,
    this.destinationDirectory,
  });

  @override
  Future<void> sendToDownloadManager(BrowserAuthContext context) async {
    final url = context.url;
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ArgumentError.value(url, 'url', 'Only http(s) URLs can be queued');
    }
    await engine.enqueue(
      DownloadRequest(
        url: url,
        suggestedFilename: context.pageTitle,
        destinationDirectory: destinationDirectory,
        cookies: context.cookies,
        userAgent: context.userAgent,
        referer: context.referer,
        headers: context.headers,
      ),
    );
  }
}
