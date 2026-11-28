import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

@immutable
class AppReleaseInfo {
  final String tagName;
  final String name;
  final String htmlUrl;
  final String body;
  final DateTime? publishedAt;
  final String? apkDownloadUrl;

  const AppReleaseInfo({
    required this.tagName,
    required this.name,
    required this.htmlUrl,
    required this.body,
    this.publishedAt,
    this.apkDownloadUrl,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    final name = json['name'] as String? ?? tagName;
    final htmlUrl = json['html_url'] as String? ?? '';
    final body = json['body'] as String? ?? '';
    final publishedAtStr = json['published_at'] as String?;
    final publishedAt =
        publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

    String? apkUrl;
    final assets = json['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final assetName = (asset['name'] as String? ?? '').toLowerCase();
        if (assetName.endsWith('.apk') &&
            (assetName.contains('arm64') || assetName.contains('universal'))) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
    }
    // Fallback to any APK if arm64/universal not explicitly found
    if (apkUrl == null) {
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final assetName = (asset['name'] as String? ?? '').toLowerCase();
          if (assetName.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }
    }

    return AppReleaseInfo(
      tagName: tagName,
      name: name,
      htmlUrl: htmlUrl,
      body: body,
      publishedAt: publishedAt,
      apkDownloadUrl: apkUrl ?? htmlUrl,
    );
  }
}

class AppUpdateService {
  static const String currentVersion = '0.0.5';
  static const int currentBuildNumber = 1;
  static const String githubRepo = 'ameya-deshpande-5056/meteora-dl';
  static const String githubUrl = 'https://github.com/$githubRepo';

  /// Compare two versions. Returns true if [latestTag] is newer than [current].
  static bool isNewerVersion(String latestTag, [String current = currentVersion]) {
    final cleanLatest = latestTag.replaceAll(RegExp(r'^[vV]'), '').trim();
    final cleanCurrent =
        current.replaceAll(RegExp(r'^[vV]'), '').split('+').first.trim();

    final latestParts =
        cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts =
        cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLength = math.max(latestParts.length, currentParts.length);
    while (latestParts.length < maxLength) {
      latestParts.add(0);
    }
    while (currentParts.length < maxLength) {
      currentParts.add(0);
    }

    for (int i = 0; i < maxLength; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  /// Checks GitHub for the latest release.
  /// An optional [fetcher] can be passed for testing or mocking.
  static Future<AppReleaseInfo?> checkForUpdate({
    Future<String> Function(Uri uri)? fetcher,
  }) async {
    final endpoint = Uri.parse(
      'https://api.github.com/repos/$githubRepo/releases/latest',
    );

    try {
      final String rawJson;
      if (fetcher != null) {
        rawJson = await fetcher(endpoint);
      } else {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 8);
        try {
          final request = await client.getUrl(endpoint);
          request.headers.set('User-Agent', 'Meteora-Android-App/$currentVersion');
          request.headers.set('Accept', 'application/vnd.github.v3+json');
          final response = await request.close().timeout(
                const Duration(seconds: 10),
              );
          if (response.statusCode != 200) {
            return null;
          }
          rawJson = await response.transform(utf8.decoder).join();
        } finally {
          client.close();
        }
      }

      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      return AppReleaseInfo.fromJson(decoded);
    } catch (e) {
      debugPrint('Error checking for app updates: $e');
      return null;
    }
  }
}
