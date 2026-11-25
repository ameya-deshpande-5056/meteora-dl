import 'download_request.dart';
import 'download_status.dart';
import 'segment.dart';

/// A persisted, resumable download task.
class DownloadTask {
  final String id;
  final DownloadRequest request;
  DownloadStatus status;
  final List<Segment> segments;
  int totalBytes;
  int downloadedBytes;
  String? filePath;
  String? errorMessage;
  int retryCount;
  final DateTime createdAt;
  DateTime updatedAt;

  DownloadTask({
    required this.id,
    required this.request,
    this.status = DownloadStatus.queued,
    List<Segment>? segments,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.filePath,
    this.errorMessage,
    this.retryCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : segments = segments ?? const [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get progress {
    if (totalBytes <= 0) {
      if (segments.isEmpty) return 0.0;
      final total = segments.fold<int>(0, (s, e) => s + e.total);
      if (total <= 0) return 0.0;
      final done = segments.fold<int>(0, (s, e) => s + e.downloaded);
      return done / total;
    }
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  bool get isResumable =>
      request.allowResume &&
      (status == DownloadStatus.paused ||
          status == DownloadStatus.failed ||
          status == DownloadStatus.retrying);

  void touch() => updatedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'request': {
          'url': request.url,
          'suggestedFilename': request.suggestedFilename,
          'destinationDirectory': request.destinationDirectory,
          'headers': request.headers,
          'cookies': request.cookies,
          'userAgent': request.userAgent,
          'referer': request.referer,
          'expectedBytes': request.expectedBytes,
          'maxSegments': request.maxSegments,
          'maxRetries': request.maxRetries,
          'allowResume': request.allowResume,
        },
        'status': status.name,
        'segments': segments.map((s) => s.toJson()).toList(),
        'totalBytes': totalBytes,
        'downloadedBytes': downloadedBytes,
        'filePath': filePath,
        'errorMessage': errorMessage,
        'retryCount': retryCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final r = json['request'] as Map<String, dynamic>;
    return DownloadTask(
      id: json['id'] as String,
      request: DownloadRequest(
        url: r['url'] as String,
        suggestedFilename: r['suggestedFilename'] as String?,
        destinationDirectory: r['destinationDirectory'] as String?,
        headers: (r['headers'] as Map?)?.cast<String, String>() ?? const {},
        cookies: r['cookies'] as String?,
        userAgent: r['userAgent'] as String?,
        referer: r['referer'] as String?,
        expectedBytes: (r['expectedBytes'] as num?)?.toInt(),
        maxSegments: (r['maxSegments'] as num?)?.toInt() ?? 8,
        maxRetries: (r['maxRetries'] as num?)?.toInt() ?? 5,
        allowResume: r['allowResume'] as bool? ?? true,
      ),
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DownloadStatus.queued,
      ),
      segments: (json['segments'] as List?)
              ?.map((e) => Segment.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      filePath: json['filePath'] as String?,
      errorMessage: json['errorMessage'] as String?,
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}