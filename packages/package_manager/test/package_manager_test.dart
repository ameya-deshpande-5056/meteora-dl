import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:package_manager/package_manager.dart';
import 'package:test/test.dart';

void main() {
  group('ChecksumVerifier', () {
    test('computes and verifies SHA-256 correctly', () {
      final sample = Uint8List.fromList(utf8.encode('meteora-yt-dlp-test-payload'));
      final digest = ChecksumVerifier.computeSha256(sample);

      expect(digest, isNotEmpty);
      expect(ChecksumVerifier.verifySha256(sample, digest), isTrue);
      expect(ChecksumVerifier.verifySha256(sample, 'deadbeef12345678'), isFalse);
    });
  });

  group('AtomicDirectoryManager', () {
    late Directory tempRoot;
    late AtomicDirectoryManager dirMgr;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('meteora_pkg_test_');
      dirMgr = AtomicDirectoryManager(rootPackagesDir: tempRoot.path);
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('prepares clean staging directory', () async {
      final staging = await dirMgr.prepareStaging(PackageType.ytdlp);
      expect(await staging.exists(), isTrue);
    });

    test('atomically moves staging to active and creates backup on second update', () async {
      // 1. Initial install
      final staging1 = await dirMgr.prepareStaging(PackageType.ytdlp);
      final exec1 = File('${staging1.path}/${PackageType.ytdlp.executableName}');
      await exec1.writeAsString('v1_binary_content');

      final commit1 = await dirMgr.commitStaging(PackageType.ytdlp);
      expect(commit1, isTrue);

      final activeExec = dirMgr.activeExecutable(PackageType.ytdlp);
      expect(await activeExec.exists(), isTrue);
      expect(await activeExec.readAsString(), equals('v1_binary_content'));

      // 2. Second update (should backup v1 and activate v2)
      final staging2 = await dirMgr.prepareStaging(PackageType.ytdlp);
      final exec2 = File('${staging2.path}/${PackageType.ytdlp.executableName}');
      await exec2.writeAsString('v2_binary_content');

      final commit2 = await dirMgr.commitStaging(PackageType.ytdlp);
      expect(commit2, isTrue);
      expect(await activeExec.readAsString(), equals('v2_binary_content'));

      // 3. Rollback should restore v1
      final rolledBack = await dirMgr.rollback(PackageType.ytdlp);
      expect(rolledBack, isTrue);
      expect(await activeExec.readAsString(), equals('v1_binary_content'));
    });
  });

  group('PackageUpdateManager', () {
    late Directory tempRoot;
    late AtomicDirectoryManager dirMgr;
    late PackageUpdateManager updater;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('meteora_updater_test_');
      dirMgr = AtomicDirectoryManager(rootPackagesDir: tempRoot.path);
      updater = PackageUpdateManager(directoryManager: dirMgr);
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('rejects corrupted download with invalid SHA-256', () async {
      final payload = Uint8List.fromList(utf8.encode('corrupted-data'));
      final release = PackageRelease(
        packageType: PackageType.ytdlp,
        versionTag: '2026.11.01',
        publishedAt: DateTime.now(),
        downloadUrl: 'https://example.com/yt-dlp',
        sha256Checksum: '0000000000000000000000000000000000000000000000000000000000000000',
        channel: UpdateChannel.stable,
      );

      final result = await updater.installPackage(release: release, preloadedBytes: payload);
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Checksum verification failed'));
    });

    test('installs package with matching SHA-256 and commits to active', () async {
      final payload = Uint8List.fromList(utf8.encode('#!/usr/bin/env python3\nprint("yt-dlp v2026.11.01")'));
      final validChecksum = ChecksumVerifier.computeSha256(payload);

      final release = PackageRelease(
        packageType: PackageType.ytdlp,
        versionTag: '2026.11.01',
        publishedAt: DateTime.now(),
        downloadUrl: 'https://example.com/yt-dlp',
        sha256Checksum: validChecksum,
        channel: UpdateChannel.stable,
      );

      final result = await updater.installPackage(release: release, preloadedBytes: payload);
      expect(result.success, isTrue);
      expect(result.versionInstalled, equals('2026.11.01'));

      final active = dirMgr.activeExecutable(PackageType.ytdlp);
      expect(await active.exists(), isTrue);
    });

    test('installs yt-dlp-ejs bundle and commits to active', () async {
      final payload = Uint8List.fromList(utf8.encode('/* yt-dlp-ejs challenge solver bundle */'));
      final validChecksum = ChecksumVerifier.computeSha256(payload);

      final release = PackageRelease(
        packageType: PackageType.ytdlpEjs,
        versionTag: '0.8.0',
        publishedAt: DateTime.now(),
        downloadUrl: 'https://example.com/yt-dlp-ejs.bundle.js',
        sha256Checksum: validChecksum,
        channel: UpdateChannel.stable,
      );

      final result = await updater.installPackage(release: release, preloadedBytes: payload);
      expect(result.success, isTrue);
      expect(result.versionInstalled, equals('0.8.0'));

      final active = dirMgr.activeExecutable(PackageType.ytdlpEjs);
      expect(await active.exists(), isTrue);
      expect(await active.readAsBytes(), equals(payload));
    });

    test('installs ffmpeg and ffprobe atomically as one package', () async {
      final ffmpegPayload = Uint8List.fromList(utf8.encode('#!ffmpeg binary'));
      final ffprobePayload = Uint8List.fromList(utf8.encode('#!ffprobe binary'));
      final ffmpegChecksum = ChecksumVerifier.computeSha256(ffmpegPayload);
      final ffprobeChecksum = ChecksumVerifier.computeSha256(ffprobePayload);

      final release = PackageRelease(
        packageType: PackageType.ffmpeg,
        versionTag: 'latest',
        publishedAt: DateTime.now(),
        downloadUrl: 'https://example.com/ffmpeg',
        sha256Checksum: ffmpegChecksum,
        additionalDownloadUrls: const ['https://example.com/ffprobe'],
        additionalSha256Checksums: [ffprobeChecksum],
        channel: UpdateChannel.stable,
      );

      final result = await updater.installPackage(
        release: release,
        preloadedBytes: ffmpegPayload,
        preloadedAdditionalBytes: {'ffprobe': ffprobePayload},
      );
      expect(result.success, isTrue);
      expect(result.versionInstalled, equals('latest'));

      // Both binaries must be present in the active directory together.
      final activeDir = dirMgr.packageActiveDir(PackageType.ffmpeg);
      final ffmpeg = File('${activeDir.path}/ffmpeg');
      final ffprobe = File('${activeDir.path}/ffprobe');
      expect(await ffmpeg.exists(), isTrue);
      expect(await ffprobe.exists(), isTrue);
      expect(await ffmpeg.readAsBytes(), equals(ffmpegPayload));
      expect(await ffprobe.readAsBytes(), equals(ffprobePayload));

      // activeExecutables() lists both binaries, primary first.
      final executables = dirMgr.activeExecutables(PackageType.ffmpeg);
      expect(executables.map((f) => f.path).toList(),
          equals([ffmpeg.path, ffprobe.path]));
    });

    test('rejects update when a co-shipped binary checksum mismatches', () async {
      final ffmpegPayload = Uint8List.fromList(utf8.encode('#!ffmpeg binary'));
      final ffprobePayload = Uint8List.fromList(utf8.encode('#!ffprobe binary'));

      final release = PackageRelease(
        packageType: PackageType.ffmpeg,
        versionTag: 'latest',
        publishedAt: DateTime.now(),
        downloadUrl: 'https://example.com/ffmpeg',
        sha256Checksum: ChecksumVerifier.computeSha256(ffmpegPayload),
        additionalDownloadUrls: const ['https://example.com/ffprobe'],
        // Deliberately wrong checksum for the co-shipped ffprobe binary.
        additionalSha256Checksums: const ['0000000000000000000000000000000000000000000000000000000000000000'],
        channel: UpdateChannel.stable,
      );

      final result = await updater.installPackage(
        release: release,
        preloadedBytes: ffmpegPayload,
        preloadedAdditionalBytes: {'ffprobe': ffprobePayload},
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Checksum verification failed for ffprobe'));

      // Nothing must have been committed to active on a failed verification.
      expect(await dirMgr.packageActiveDir(PackageType.ffmpeg).exists(), isFalse);
    });

    test('rejects release missing download URLs for co-shipped binaries', () async {
      final release = PackageRelease(
        packageType: PackageType.ffmpeg,
        versionTag: 'latest',
        publishedAt: DateTime.now(),
        downloadUrl: 'https://example.com/ffmpeg',
        sha256Checksum: 'abc',
        // ffmpeg ships ffprobe, but no download URL was provided for it.
        additionalDownloadUrls: const [],
        additionalSha256Checksums: const [],
        channel: UpdateChannel.stable,
      );

      final result = await updater.installPackage(
        release: release,
        preloadedBytes: Uint8List.fromList(utf8.encode('ffmpeg')),
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('download URL for every additional executable'));
    });
  });
}
