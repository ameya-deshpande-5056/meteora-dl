import 'package:browser/browser.dart';
import 'package:flutter/material.dart';

import '../services/direct_download_bridge.dart';
import '../state/download_state.dart';
import '../theme/app_shapes.dart';
import '../theme/app_spacing.dart';

/// In-app browser. Because Android sandboxes other browsers, pages opened here
/// are the only ones whose cookies, user agent and referer the app can reuse for
/// a download.
class BrowserScreen extends StatefulWidget {
  /// Hands a discovered media URL to the Home extraction flow.
  final ValueChanged<String>? onSendToHome;

  const BrowserScreen({super.key, this.onSendToHome});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final TextEditingController _urlController =
      TextEditingController(text: 'https://www.google.com');
  final List<MediaCandidate> _candidates = [];
  String _currentUrl = 'https://www.google.com';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _navigate() {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    final url = (uri != null && uri.hasScheme) ? raw : 'https://$raw';
    setState(() {
      _currentUrl = url;
      _candidates.clear();
    });
  }

  void _addCandidate(MediaCandidate candidate) {
    if (_candidates.any((c) => c.url == candidate.url)) return;
    setState(() => _candidates.add(candidate));
  }

  Future<void> _openCaptureSheet() async {
    final selected = await showModalBottomSheet<MediaCandidate>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _candidates.length,
            itemBuilder: (context, index) {
              final candidate = _candidates[index];
              return ListTile(
                leading: Icon(_iconFor(candidate.kind)),
                title: Text(
                  candidate.suggestedFilename ?? candidate.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${candidate.kind.name.toUpperCase()} · ${candidate.contentType?.isNotEmpty == true ? candidate.contentType : 'detected on page'}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).pop(candidate),
              );
            },
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    // A plain file (mp4, zip, pdf...) goes through the segmented HTTP engine,
    // reusing this WebView's cookies. Pages and HLS/DASH manifests stay with
    // the extractor, which knows how to pick and merge formats.
    if (DownloadStateManager.instance.shouldUseDirectDownload(
      selected.url,
      contentType: selected.contentType,
      fileName: selected.suggestedFilename,
    )) {
      await _downloadDirectly(selected);
      return;
    }

    final onSendToHome = widget.onSendToHome;
    if (onSendToHome != null) {
      onSendToHome(selected.url);
      return;
    }
    // Fallback when no host is listening: keep the URL reachable for the user.
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(selected.suggestedFilename ?? 'Media found'),
        content: SelectableText(selected.url),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadDirectly(MediaCandidate candidate) async {
    final auth = await directDownloadEngine.authContextFor(candidate.url);
    final headers = <String, String>{'Referer': _currentUrl};
    if (auth.userAgent != null && auth.userAgent!.isNotEmpty) {
      headers['User-Agent'] = auth.userAgent!;
    }
    if (auth.hasCookies) {
      headers['Cookie'] = auth.cookie!;
    }

    final started = await DownloadStateManager.instance.startDirectDownload(
      url: candidate.url,
      title: candidate.suggestedFilename ?? _currentUrl,
      fileName: candidate.suggestedFilename,
      contentType: candidate.contentType,
      headers: headers,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          started
              ? 'Downloading in the background — see the Downloads tab.'
              : 'Could not start this download.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  IconData _iconFor(MediaKind kind) {
    switch (kind) {
      case MediaKind.video:
      case MediaKind.hls:
      case MediaKind.dash:
        return Icons.movie_outlined;
      case MediaKind.audio:
        return Icons.audiotrack_outlined;
      case MediaKind.subtitle:
        return Icons.subtitles_outlined;
      case MediaKind.image:
        return Icons.image_outlined;
      case MediaKind.document:
        return Icons.description_outlined;
      case MediaKind.archive:
        return Icons.folder_zip_outlined;
      case MediaKind.other:
        return Icons.download_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          margin: const EdgeInsets.only(right: AppSpacing.sm),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppShapes.full),
          ),
          child: TextField(
            controller: _urlController,
            onSubmitted: (_) => _navigate(),
            textInputAction: TextInputAction.go,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'Search or enter URL',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: _navigate,
            tooltip: 'Go',
          ),
        ],
      ),
      body: WebViewScreen(
        key: ValueKey(_currentUrl),
        initialUrl: _currentUrl,
        onUrlChanged: (url) {
          if (url != _currentUrl) _urlController.text = url;
        },
        onMediaDetected: _addCandidate,
      ),
      floatingActionButton: _candidates.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCaptureSheet,
              icon: const Icon(Icons.download_rounded),
              label: Text('${_candidates.length} found'),
            ),
    );
  }
}
