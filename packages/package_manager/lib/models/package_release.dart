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

  const PackageRelease({
    required this.packageType,
    required this.versionTag,
    required this.publishedAt,
    required this.downloadUrl,
    this.sha256Checksum,
    this.targetAbi,
    required this.channel,
    this.byteSize = 0,
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
  };
}
