import 'package:meta/meta.dart';
import 'package_type.dart';
import 'update_channel.dart';

@immutable
class PackageRelease {
  final PackageType packageType;
  final String versionTag;
  final DateTime publishedAt;
  final String downloadUrl;
  final String? sha256Checksum;
  final String? targetAbi; // e.g. arm64-v8a, armeabi-v7a, x86_64, or any
  final UpdateChannel channel;
  final int byteSize;

  /// Download URLs for additional co-shipped executables (e.g. `ffprobe`),
  /// ordered to match [PackageType.additionalExecutableNames].
  final List<String> additionalDownloadUrls;
  /// SHA-256 checksums for each additional download URL (parallel to above).
  /// Empty or null entries mean "no checksum provided" for that binary.
  final List<String?> additionalSha256Checksums;

  const PackageRelease({
    required this.packageType,
    required this.versionTag,
    required this.publishedAt,
    required this.downloadUrl,
    this.sha256Checksum,
    this.targetAbi,
    required this.channel,
    this.byteSize = 0,
    this.additionalDownloadUrls = const [],
    this.additionalSha256Checksums = const [],
  });

  factory PackageRelease.fromJson(Map<String, dynamic> json) {
    return PackageRelease(
      packageType: PackageType.values.firstWhere(
        (p) => p.name == json['package_type'],
        orElse: () => PackageType.ytdlp,
      ),
      versionTag: json['version_tag'] as String? ?? 'unknown',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
      downloadUrl: json['download_url'] as String? ?? '',
      sha256Checksum: json['sha256'] as String?,
      targetAbi: json['target_abi'] as String?,
      channel: UpdateChannel.values.firstWhere(
        (c) => c.name == json['channel'],
        orElse: () => UpdateChannel.stable,
      ),
      byteSize: json['byte_size'] is num ? (json['byte_size'] as num).toInt() : 0,
      additionalDownloadUrls: (json['additional_download_urls'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [],
      additionalSha256Checksums: (json['additional_sha256_checksums'] as List<dynamic>?)
              ?.whereType<String?>()
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'package_type': packageType.name,
    'version_tag': versionTag,
    'published_at': publishedAt.toIso8601String(),
    'download_url': downloadUrl,
    'sha256': sha256Checksum,
    'target_abi': targetAbi,
    'channel': channel.name,
    'byte_size': byteSize,
    'additional_download_urls': additionalDownloadUrls,
    'additional_sha256_checksums': additionalSha256Checksums,
  };
}
