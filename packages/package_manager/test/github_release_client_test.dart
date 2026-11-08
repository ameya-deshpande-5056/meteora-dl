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
  });
}
