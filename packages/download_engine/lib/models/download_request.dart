import 'package:meta/meta.dart';

/// A user/agent request to download a single resource.
///
/// Mirrors qtIDM's "download info" concept: URL + auth context (cookies, UA,
/// referer, headers) + destination + naming policy. On Android the auth context
/// comes from the in-app WebView bridge rather than an external browser.
@immutable
class DownloadRequest {
  final String url;
  final String? suggestedFilename;
  final String? destinationDirectory;
  final Map<String, String> headers;
  final String? cookies;
  final String? userAgent;
  final String? referer;
  final int? expectedBytes;
  final int maxSegments;
  final int maxRetries;
  final bool allowResume;

  const DownloadRequest({
    required this.url,
    this.suggestedFilename,
    this.destinationDirectory,
    this.headers = const {},
    this.cookies,
    this.userAgent,
    this.referer,
    this.expectedBytes,
    this.maxSegments = 8,
    this.maxRetries = 5,
    this.allowResume = true,
  });

  DownloadRequest copyWith({
    String? url,
    String? suggestedFilename,
    String? destinationDirectory,
    Map<String, String>? headers,
    String? cookies,
    String? userAgent,
    String? referer,
    int? expectedBytes,
    int? maxSegments,
    int? maxRetries,
    bool? allowResume,
  }) {
    return DownloadRequest(
      url: url ?? this.url,
      suggestedFilename: suggestedFilename ?? this.suggestedFilename,
      destinationDirectory: destinationDirectory ?? this.destinationDirectory,
      headers: headers ?? this.headers,
      cookies: cookies ?? this.cookies,
      userAgent: userAgent ?? this.userAgent,
      referer: referer ?? this.referer,
      expectedBytes: expectedBytes ?? this.expectedBytes,
      maxSegments: maxSegments ?? this.maxSegments,
      maxRetries: maxRetries ?? this.maxRetries,
      allowResume: allowResume ?? this.allowResume,
    );
  }

  /// Builds the effective HTTP headers for a request, merging auth context.
  Map<String, String> effectiveHeaders() {
    final result = <String, String>{...headers};
    if (cookies != null && cookies!.isNotEmpty) {
      result['Cookie'] = cookies!;
    }
    if (userAgent != null && userAgent!.isNotEmpty) {
      result['User-Agent'] = userAgent!;
    }
    if (referer != null && referer!.isNotEmpty) {
      result['Referer'] = referer!;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is DownloadRequest &&
      other.url == url &&
      other.suggestedFilename == suggestedFilename &&
      other.destinationDirectory == destinationDirectory &&
      other.cookies == cookies &&
      other.userAgent == userAgent &&
      other.referer == referer &&
      other.expectedBytes == expectedBytes &&
      other.maxSegments == maxSegments &&
      other.maxRetries == maxRetries &&
      other.allowResume == allowResume;

  @override
  int get hashCode => Object.hash(
        url,
        suggestedFilename,
        destinationDirectory,
        cookies,
        userAgent,
        referer,
        expectedBytes,
        maxSegments,
        maxRetries,
        allowResume,
      );
}