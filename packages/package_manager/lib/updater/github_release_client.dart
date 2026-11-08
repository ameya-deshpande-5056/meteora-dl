import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/package_release.dart';
import '../models/package_type.dart';
import '../models/update_channel.dart';

class GitHubReleaseClient {
  final http.Client httpClient;

  GitHubReleaseClient({http.Client? client}) : httpClient = client ?? http.Client();

  /// Fetches the latest matching release from GitHub for the given package and channel.
  Future<PackageRelease?> fetchLatestRelease({
    required PackageType packageType,
    required String targetAbi, // e.g. 'arm64-v8a'
    UpdateChannel channel = UpdateChannel.stable,
  }) async {
    final endpoint = Uri.parse(
      'https://api.github.com/repos/${packageType.repository}/releases?per_page=10',
    );

    try {
      final response = await httpClient.get(
        endpoint,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Meteora-Android-Package-Manager/1.0',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final List<dynamic> releasesJson = jsonDecode(response.body) as List<dynamic>;
      if (releasesJson.isEmpty) return null;

      // Filter by channel (stable vs pre-release/nightly)
      Map<String, dynamic>? selectedReleaseJson;
      for (final r in releasesJson) {
        if (r is! Map<String, dynamic>) continue;
        final isPrerelease = r['prerelease'] as bool? ?? false;
        final isDraft = r['draft'] as bool? ?? false;
        if (isDraft) continue;

        if (channel == UpdateChannel.stable && !isPrerelease) {
          selectedReleaseJson = r;
          break;
        } else if (channel == UpdateChannel.nightly) {
          selectedReleaseJson = r;
          break;
        }
      }

      // Fallback to first non-draft release if none strictly matched
      selectedReleaseJson ??= releasesJson.firstWhere(
        (r) => r is Map<String, dynamic> && !(r['draft'] as bool? ?? false),
        orElse: () => null,
      ) as Map<String, dynamic>?;

      if (selectedReleaseJson == null) return null;

      final versionTag = (selectedReleaseJson['tag_name'] ?? '').toString();
      final publishedAtStr = selectedReleaseJson['published_at'] as String? ?? '';
      final publishedAt = DateTime.tryParse(publishedAtStr) ?? DateTime.now();

      final assets = selectedReleaseJson['assets'] as List<dynamic>? ?? [];

      // Find matching asset for target ABI
      final matchedAsset = _findMatchingAsset(packageType, targetAbi, assets);
      if (matchedAsset == null) return null;

      final downloadUrl = matchedAsset['browser_download_url'] as String? ?? '';
      final byteSize = (matchedAsset['size'] as num?)?.toInt() ?? 0;

      // Look for sha256 checksum in release assets or notes
      final checksum = await _extractChecksum(assets, matchedAsset['name'] as String? ?? '');

      return PackageRelease(
        packageType: packageType,
        versionTag: versionTag,
        publishedAt: publishedAt,
        downloadUrl: downloadUrl,
        sha256Checksum: checksum,
        targetAbi: targetAbi,
        channel: channel,
        byteSize: byteSize,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _findMatchingAsset(
    PackageType packageType,
    String targetAbi,
    List<dynamic> assets,
  ) {
    final isArm64 = targetAbi.contains('arm64') || targetAbi.contains('aarch64');
    final isArmv7 = targetAbi.contains('armeabi') || targetAbi.contains('armv7');
    final isX86_64 = targetAbi.contains('x86_64');

    for (final raw in assets) {
      if (raw is! Map<String, dynamic>) continue;
      final name = (raw['name'] as String? ?? '').toLowerCase();

      switch (packageType) {
        case PackageType.ytdlp:
          if (name == 'yt-dlp' || name == 'yt-dlp.tar.gz' || name.endsWith('tar.gz')) {
            return raw;
          }
          break;
        case PackageType.ytdlpEjs:
          if (name.contains('bundle.js') || name.contains('yt-dlp-ejs')) {
            return raw;
          }
          break;
        case PackageType.deno:
          if (isArm64 && (name.contains('aarch64') || name.contains('arm64'))) {
            return raw;
          } else if (isX86_64 && name.contains('x86_64')) {
            return raw;
          }
          break;
        case PackageType.quickjsNg:
          if (isArm64 && (name.contains('arm64') || name.contains('aarch64') || name.contains('android'))) {
            return raw;
          } else if (name.contains('qjs') || name.contains('quickjs')) {
            return raw;
          }
          break;
        case PackageType.ffmpeg:
          if (isArm64 && (name.contains('arm64') || name.contains('aarch64'))) {
            return raw;
          } else if (isArmv7 && (name.contains('armv7') || name.contains('armhf'))) {
            return raw;
          } else if (isX86_64 && name.contains('x86_64')) {
            return raw;
          }
          break;
      }
    }
    return null;
  }

  Future<String?> _extractChecksum(List<dynamic> assets, String assetName) async {
    // 1. Check for single asset checksum file (e.g. yt-dlp.sha256 or <assetName>.sha256)
    for (final raw in assets) {
      if (raw is! Map<String, dynamic>) continue;
      final name = (raw['name'] as String? ?? '').toLowerCase();
      if (name == '$assetName.sha256' || name == '${assetName}_sha256.txt') {
        final url = raw['browser_download_url'] as String? ?? '';
        try {
          final res = await httpClient.get(Uri.parse(url));
          if (res.statusCode == 200) {
            return _parseChecksumString(res.body);
          }
        } catch (_) {}
      }
    }

    // 2. Check for SHA256SUMS file
    for (final raw in assets) {
      if (raw is! Map<String, dynamic>) continue;
      final name = (raw['name'] as String? ?? '').toUpperCase();
      if (name == 'SHA256SUMS' || name == 'SHA256SUMS.TXT') {
        final url = raw['browser_download_url'] as String? ?? '';
        try {
          final res = await httpClient.get(Uri.parse(url));
          if (res.statusCode == 200) {
            final lines = res.body.split('\n');
            for (final line in lines) {
              if (line.contains(assetName)) {
                return _parseChecksumString(line);
              }
            }
          }
        } catch (_) {}
      }
    }
    return null;
  }

  String? _parseChecksumString(String text) {
    final tokens = text.trim().split(RegExp(r'\s+'));
    for (final token in tokens) {
      // 64-character hexadecimal SHA-256 string
      if (RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(token)) {
        return token.toLowerCase();
      }
    }
    return null;
  }
}
