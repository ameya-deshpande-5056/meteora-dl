import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_manager/package_manager.dart';
import 'package:test/test.dart';

void main() {
  group('GitHubReleaseClient', () {
    test('fetches latest stable release and matches ARM64 asset', () async {
      final mockReleasesJson = [
        {
          'tag_name': '2026.11.08',
          'prerelease': false,
          'draft': false,
          'published_at': '2026-11-08T12:00:00Z',
          'assets': [
            {
              'name': 'yt-dlp',
              'browser_download_url': 'https://github.com/yt-dlp/yt-dlp/releases/download/2026.11.08/yt-dlp',
              'size': 3500000,
            },
            {
              'name': 'yt-dlp.sha256',
              'browser_download_url': 'https://github.com/yt-dlp/yt-dlp/releases/download/2026.11.08/yt-dlp.sha256',
              'size': 64,
            }
          ]
        }
      ];

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/releases')) {
          return http.Response(jsonEncode(mockReleasesJson), 200);
        } else if (request.url.path.endsWith('.sha256')) {
          return http.Response('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  yt-dlp', 200);
        }
        return http.Response('Not found', 404);
      });

      final client = GitHubReleaseClient(client: mockClient);
      final release = await client.fetchLatestRelease(
        packageType: PackageType.ytdlp,
        targetAbi: 'arm64-v8a',
        channel: UpdateChannel.stable,
      );

      expect(release, isNotNull);
      expect(release!.versionTag, equals('2026.11.08'));
      expect(release.downloadUrl, contains('yt-dlp'));
      expect(release.sha256Checksum, equals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'));
    });

    test('matches Deno aarch64 asset for ARM64', () async {
      final mockDenoReleases = [
        {
          'tag_name': 'v1.46.3',
          'prerelease': false,
          'draft': false,
          'published_at': '2026-10-20T10:00:00Z',
          'assets': [
            {
              'name': 'deno-x86_64-unknown-linux-gnu.zip',
              'browser_download_url': 'https://example.com/deno-x86.zip',
              'size': 45000000,
            },
            {
              'name': 'deno-aarch64-unknown-linux-gnu.zip',
              'browser_download_url': 'https://example.com/deno-arm64.zip',
              'size': 42000000,
            }
          ]
        }
      ];

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockDenoReleases), 200);
      });

      final client = GitHubReleaseClient(client: mockClient);
      final release = await client.fetchLatestRelease(
        packageType: PackageType.deno,
        targetAbi: 'arm64-v8a',
        channel: UpdateChannel.stable,
      );

      expect(release, isNotNull);
      expect(release!.downloadUrl, contains('deno-arm64.zip'));
    });

    test('matches yt-dlp-ejs JavaScript bundle asset', () async {
      final mockEjsReleases = [
        {
          'tag_name': '0.8.0',
          'prerelease': false,
          'draft': false,
          'published_at': '2026-03-17T22:49:33Z',
          'assets': [
            {
              'name': 'yt-dlp-ejs.bundle.js',
              'browser_download_url': 'https://github.com/yt-dlp/ejs/releases/download/0.8.0/yt-dlp-ejs.bundle.js',
              'size': 45000,
            },
            {
              'name': 'yt_dlp_ejs-0.8.0.tar.gz',
              'browser_download_url': 'https://github.com/yt-dlp/ejs/releases/download/0.8.0/yt_dlp_ejs-0.8.0.tar.gz',
              'size': 96571,
            }
          ]
        }
      ];

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockEjsReleases), 200);
      });

      final client = GitHubReleaseClient(client: mockClient);
      final release = await client.fetchLatestRelease(
        packageType: PackageType.ytdlpEjs,
        targetAbi: 'arm64-v8a',
        channel: UpdateChannel.stable,
      );

      expect(release, isNotNull);
      expect(release!.downloadUrl, contains('yt-dlp-ejs.bundle.js'));
      expect(release.packageType, equals(PackageType.ytdlpEjs));
    });

    test('matches FFmpeg linux arm64 archive asset', () async {
      final mockFfmpegReleases = [
        {
          'tag_name': 'latest',
          'prerelease': false,
          'draft': false,
          'published_at': '2026-11-15T21:56:53Z',
          'assets': [
            {
              'name': 'ffmpeg-master-latest-linuxarm64-gpl.tar.xz',
              'browser_download_url': 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linuxarm64-gpl.tar.xz',
              'size': 126400000,
            },
            {
              'name': 'ffmpeg-master-latest-linux64-gpl.tar.xz',
              'browser_download_url': 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz',
              'size': 150300000,
            },
            {
              'name': 'checksums.sha256',
              'browser_download_url': 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/checksums.sha256',
              'size': 848,
            }
          ]
        }
      ];

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockFfmpegReleases), 200);
      });

      final client = GitHubReleaseClient(client: mockClient);
      final release = await client.fetchLatestRelease(
        packageType: PackageType.ffmpeg,
        targetAbi: 'arm64-v8a',
        channel: UpdateChannel.stable,
      );

      expect(release, isNotNull);
      expect(release!.downloadUrl, contains('linuxarm64-gpl.tar.xz'));
      expect(release.packageType, equals(PackageType.ffmpeg));
    });
  });
}
