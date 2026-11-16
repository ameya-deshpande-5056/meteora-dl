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
  ///
  /// Every binary belonging to the package — the primary
  /// [PackageType.executableName] plus any [PackageType.additionalExecutableNames]
  /// (e.g. `ffprobe` alongside `ffmpeg`) — is downloaded, checksum-verified and
  /// written into staging *before* the atomic swap. A partial or corrupt download
  /// can therefore never leave `active/` in a mixed state.
  Future<PackageUpdateResult> installPackage({
    required PackageRelease release,
    Uint8List? preloadedBytes, // for testing or local mocks (primary binary)
    Map<String, Uint8List> preloadedAdditionalBytes = const {}, // keyed by executable name
  }) async {
    final type = release.packageType;
    final executables = type.allExecutableNames;

    // Sanity-check that the release describes every co-shipped binary.
    if (release.additionalDownloadUrls.length != type.additionalExecutableNames.length) {
      return PackageUpdateResult(
        success: false,
        errorMessage:
            'Release does not provide a download URL for every additional executable of ${type.displayName}',
      );
    }
    if (release.additionalSha256Checksums.length != type.additionalExecutableNames.length) {
      return PackageUpdateResult(
        success: false,
        errorMessage:
            'Release does not provide a checksum for every additional executable of ${type.displayName}',
      );
    }

    try {
      final stagingDir = await directoryManager.prepareStaging(type);

      // Download + verify every binary before writing anything to staging.
      final Map<String, Uint8List> payloads = {};
      String? error;

      for (var i = 0; i < executables.length; i++) {
        final name = executables[i];
        final bool isPrimary = i == 0;

        final String url;
        final String? checksum;
        final Uint8List? preloaded;
        if (isPrimary) {
          url = release.downloadUrl;
          checksum = release.sha256Checksum;
          preloaded = preloadedBytes;
        } else {
          final additionalIndex = i - 1;
          url = release.additionalDownloadUrls[additionalIndex];
          checksum = release.additionalSha256Checksums[additionalIndex];
          preloaded = preloadedAdditionalBytes[name];
        }

        final Uint8List payload;
        if (preloaded != null) {
          payload = preloaded;
        } else {
          final resp = await httpClient.get(Uri.parse(url));
          if (resp.statusCode != 200) {
            error = 'HTTP ${resp.statusCode} downloading $name from $url';
            break;
          }
          payload = resp.bodyBytes;
        }

        // Checksum verification (empty/missing checksum is skipped)
        if (checksum != null && checksum.isNotEmpty) {
          final valid = ChecksumVerifier.verifySha256(payload, checksum);
          if (!valid) {
            error = 'SHA-256 Checksum verification failed for $name';
            break;
          }
        }

        payloads[name] = payload;
      }

      if (error != null) {
        return PackageUpdateResult(success: false, errorMessage: error);
      }

      // Write every verified payload into the staging directory.
      for (final entry in payloads.entries) {
        final destFile = File('${stagingDir.path}/${entry.key}');
        await destFile.writeAsBytes(entry.value, flush: true);
      }

      // Save version metadata
      final versionFile = File('${stagingDir.path}/version.json');
      await versionFile.writeAsString(jsonEncode({
        'version': release.versionTag,
        'installed_at': DateTime.now().toIso8601String(),
        'channel': release.channel.name,
        'executables': executables,
      }));

      // Atomic swap to active (entire package directory, all binaries together)
      final committed = await directoryManager.commitStaging(type);
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
      final rolled = await directoryManager.rollback(type);
      return PackageUpdateResult(
        success: false,
        errorMessage: e.toString(),
        rolledBack: rolled,
      );
    }
  }
}
