/// Lifecycle states for a [DownloadTask].
enum DownloadStatus {
  queued,
  running,
  paused,
  completed,
  cancelled,
  failed,
  retrying,
}

extension DownloadStatusX on DownloadStatus {
  bool get isActive =>
      this == DownloadStatus.queued ||
      this == DownloadStatus.running ||
      this == DownloadStatus.retrying;

  bool get isTerminal =>
      this == DownloadStatus.completed ||
      this == DownloadStatus.cancelled ||
      this == DownloadStatus.failed;
}