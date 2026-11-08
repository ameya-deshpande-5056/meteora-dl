import 'package:meta/meta.dart';

@immutable
class DownloadTaskRecord {
  final String taskId;
  final String url;
  final String title;
  final String? thumbnailUrl;
  final String formatLabel;
  final double progressPercent;
  final String speedText;
  final String etaText;
  final String totalSizeText;
  final String status;
  final String? filePath;
  final String? errorMessage;
  final DateTime createdAt;

  const DownloadTaskRecord({
    required this.taskId,
    required this.url,
    required this.title,
    this.thumbnailUrl,
    required this.formatLabel,
    this.progressPercent = 0.0,
    this.speedText = '0 B/s',
    this.etaText = '--:--',
    this.totalSizeText = '',
    this.status = 'queued',
    this.filePath,
    this.errorMessage,
    required this.createdAt,
  });

  DownloadTaskRecord copyWith({
    double? progressPercent,
    String? speedText,
    String? etaText,
    String? totalSizeText,
    String? status,
    String? filePath,
    String? errorMessage,
  }) {
    return DownloadTaskRecord(
      taskId: taskId,
      url: url,
      title: title,
      thumbnailUrl: thumbnailUrl,
      formatLabel: formatLabel,
      progressPercent: progressPercent ?? this.progressPercent,
      speedText: speedText ?? this.speedText,
      etaText: etaText ?? this.etaText,
      totalSizeText: totalSizeText ?? this.totalSizeText,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
    );
  }

  factory DownloadTaskRecord.fromJson(Map<String, dynamic> json) {
    return DownloadTaskRecord(
      taskId: json['task_id'] as String,
      url: json['url'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      formatLabel: json['format_label'] as String,
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      speedText: (json['speed_text'] as String?) ?? '0 B/s',
      etaText: (json['eta_text'] as String?) ?? '--:--',
      totalSizeText: (json['total_size_text'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'queued',
      filePath: json['file_path'] as String?,
      errorMessage: json['error_message'] as String?,
      createdAt: json['created_at'] != null
          ? (json['created_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int)
              : DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'task_id': taskId,
    'url': url,
    'title': title,
    'thumbnail_url': thumbnailUrl,
    'format_label': formatLabel,
    'progress_percent': progressPercent,
    'speed_text': speedText,
    'eta_text': etaText,
    'total_size_text': totalSizeText,
    'status': status,
    'file_path': filePath,
    'error_message': errorMessage,
    'created_at': createdAt.millisecondsSinceEpoch,
  };
}
