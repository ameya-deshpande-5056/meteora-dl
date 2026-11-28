import 'package:flutter_test/flutter_test.dart';
import 'package:meteora/services/app_update_service.dart';

void main() {
  group('AppUpdateService Version Comparison', () {
    test('correctly identifies newer patch, minor, and major versions', () {
      expect(AppUpdateService.isNewerVersion('v0.0.5', '0.0.4'), isTrue);
      expect(AppUpdateService.isNewerVersion('0.0.5', '0.0.4'), isTrue);
      expect(AppUpdateService.isNewerVersion('v0.1.0', '0.0.4'), isTrue);
      expect(AppUpdateService.isNewerVersion('v1.0.0', '0.0.4'), isTrue);
      expect(AppUpdateService.isNewerVersion('v0.0.4.1', '0.0.4'), isTrue);
    });

    test('correctly identifies equal or older versions', () {
      expect(AppUpdateService.isNewerVersion('v0.0.4', '0.0.4'), isFalse);
      expect(AppUpdateService.isNewerVersion('0.0.4', '0.0.4'), isFalse);
      expect(AppUpdateService.isNewerVersion('v0.0.4', '0.0.4+1'), isFalse);
      expect(AppUpdateService.isNewerVersion('v0.0.3', '0.0.4'), isFalse);
      expect(AppUpdateService.isNewerVersion('v0.0.2', '0.0.4'), isFalse);
      expect(AppUpdateService.isNewerVersion('v0.0.1', '0.0.4'), isFalse);
    });
  });

  group('AppUpdateService Release Parser', () {
    test('parses release JSON and extracts APK download URL', () async {
      const mockJson = '''
      {
        "tag_name": "v0.0.6",
        "name": "Meteora v0.0.6",
        "html_url": "https://github.com/ameya-deshpande-5056/meteora-dl/releases/tag/v0.0.6",
        "body": "Bug fixes and improvements",
        "published_at": "2026-11-28T12:00:00Z",
        "assets": [
          {
            "name": "checksums.txt",
            "browser_download_url": "https://github.com/.../checksums.txt"
          },
          {
            "name": "meteora-v0.0.6-arm64-v8a.apk",
            "browser_download_url": "https://github.com/.../meteora-v0.0.6-arm64-v8a.apk"
          }
        ]
      }
      ''';

      final release = await AppUpdateService.checkForUpdate(
        fetcher: (_) async => mockJson,
      );

      expect(release, isNotNull);
      expect(release!.tagName, equals('v0.0.6'));
      expect(release.name, equals('Meteora v0.0.6'));
      expect(release.apkDownloadUrl, contains('meteora-v0.0.6-arm64-v8a.apk'));
      expect(release.body, equals('Bug fixes and improvements'));
      expect(AppUpdateService.isNewerVersion(release.tagName), isTrue);
    });
  });
}
