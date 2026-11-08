import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/package_release.dart';
import '../models/package_type.dart';
import '../security/checksum_verifier.dart';
import '../staging/atomic_directory_manager.dart';

class PackageUpdateResult {
  final bool success;
  final String? versionInstalled;
  final String? errorMessage;
  final bool rolledBack;

  const PackageUpdateResult({
    required this.success,
    this.versionInstalled,
    this.errorMessage,
    this.rolledBack = false,
  });
}

class PackageUpdateManager {
  final AtomicDirectoryManager directoryManager;
  final String targetAbi; // arm64-v8a, armeabi-v7a, x86_64
  final http.Client httpClient;

  PackageUpdateManager({
    required this.directoryManager,
    this.targetAbi = 'arm64-v8a',
    http.Client? client,
  }) : httpClient = client ?? http.Client();

  /// Matches the optimal release asset given the device ABI and package type.
  String? selectAssetUrl(Map<String, dynamic> releaseJson, PackageType type) {
    final assets = releaseJson['assets'] as List<dynamic>? ?? [];

    for (final raw in assets) {
      if (raw is! Map<String, dynamic>) continue;
      final name = (raw['name'] as String? ?? '').toLowerCase();
      final url = raw['browser_download_url'] as String? ?? '';

      switch (type) {
        case PackageType.ytdlp:
          // yt-dlp standalone python zipapp or binary
          if (name == 'yt-dlp' || name == 'yt-dlp.tar.gz') return url;
          break;
        case PackageType.ytdlpEjs:
          if (name.contains('bundle.js') || name.contains('ejs')) return url;
          break;
        case PackageType.deno:
          if (targetAbi.contains('arm64') && (name.contains('aarch64') || name.contains('arm64'))) {
            return url;
          }
          break;
        case PackageType.quickjsNg:
          if (name.contains('qjs') && (name.contains('android') || name.contains('aarch64') || name.contains('linux'))) {
            return url;
          }
          break;
        case PackageType.ffmpeg:
          if (targetAbi.contains('arm64') && (name.contains('arm64') || name.contains('aarch64'))) {
            return url;
          }
          break;
      }
    }
    return null;
  }

  /// Downloads, verifies SHA-256, stages, and atomically commits the package.
  Future<PackageUpdateResult> installPackage({
    required PackageRelease release,
    Uint8List? preloadedBytes, // for testing or local mocks
  }) async {
    try {
      final stagingDir = await directoryManager.prepareStaging(release.packageType);

      final Uint8List payload;
      if (preloadedBytes != null) {
        payload = preloadedBytes;
      } else {
        final resp = await httpClient.get(Uri.parse(release.downloadUrl));
        if (resp.statusCode != 200) {
          return PackageUpdateResult(
            success: false,
            errorMessage: 'HTTP ${resp.statusCode} downloading package from ${release.downloadUrl}',
          );
        }
        payload = resp.bodyBytes;
      }

      // Checksum verification
      if (release.sha256Checksum != null && release.sha256Checksum!.isNotEmpty) {
        final valid = ChecksumVerifier.verifySha256(payload, release.sha256Checksum!);
        if (!valid) {
          return const PackageUpdateResult(
            success: false,
            errorMessage: 'SHA-256 Checksum verification failed for downloaded asset',
          );
        }
      }

      // Write payload into staging directory
      final destFile = File('${stagingDir.path}/${release.packageType.executableName}');
      await destFile.writeAsBytes(payload, flush: true);

      // Save version metadata
      final versionFile = File('${stagingDir.path}/version.json');
      await versionFile.writeAsString(jsonEncode({
        'version': release.versionTag,
        'installed_at': DateTime.now().toIso8601String(),
        'channel': release.channel.name,
      }));

      // Atomic swap to active
      final committed = await directoryManager.commitStaging(release.packageType);
      if (!committed) {
        return const PackageUpdateResult(
          success: false,
          errorMessage: 'Failed to commit staging directory to active',
        );
      }

      return PackageUpdateResult(
        success: true,
        versionInstalled: release.versionTag,
      );
    } catch (e) {
      // Attempt rollback
      final rolled = await directoryManager.rollback(release.packageType);
      return PackageUpdateResult(
        success: false,
        errorMessage: e.toString(),
        rolledBack: rolled,
      );
    }
  }
}
