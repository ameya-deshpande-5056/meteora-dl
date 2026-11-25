import 'package:meta/meta.dart';

/// A single in-app browser tab.
@immutable
class BrowserTab {
  final String id;
  final String url;
  final String title;
  final double progress;
  final bool isLoading;
  final bool canGoBack;
  final bool canGoForward;

  const BrowserTab({
    required this.id,
    this.url = 'about:blank',
    this.title = 'New Tab',
    this.progress = 0.0,
    this.isLoading = false,
    this.canGoBack = false,
    this.canGoForward = false,
  });

  BrowserTab copyWith({
    String? url,
    String? title,
    double? progress,
    bool? isLoading,
    bool? canGoBack,
    bool? canGoForward,
  }) {
    return BrowserTab(
      id: id,
      url: url ?? this.url,
      title: title ?? this.title,
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
    );
  }
}