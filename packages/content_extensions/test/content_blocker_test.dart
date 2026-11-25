import 'package:content_extensions/content_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('ContentBlocker', () {
    test('element hiding becomes injected CSS', () {
      final blocker = ContentBlocker()
        ..addRule(const FilterRule(pattern: '.sponsored', isCosmetic: true));

      expect(
        blocker.buildInjectedCss(),
        contains('.sponsored { display: none !important; }'),
      );
    });

    test('non-cosmetic network rules never reach the CSS', () {
      final blocker = ContentBlocker()
        ..addRule(const FilterRule(pattern: '||ads.test^'));

      expect(blocker.buildInjectedCss(), isEmpty);
      expect(blocker.rules, hasLength(1));
    });

    test('Dark Reader settings emit a filter declaration', () {
      final blocker = ContentBlocker()
        ..darkReader = const DarkReaderSettings(
          enabled: true,
          brightness: 90,
          contrast: 110,
          sepia: 5,
        );

      final css = blocker.buildInjectedCss();
      expect(css, contains('brightness(90%)'));
      expect(css, contains('contrast(110%)'));
      expect(css, contains('sepia(5%)'));
    });

    test('userscripts only inject on matching URLs', () {
      final blocker = ContentBlocker()
        ..addUserScript(const UserScript(
          name: 'Example only',
          code: 'console.log("hi")',
          matchPatterns: ['https://example.test/*'],
        ));

      expect(blocker.buildInjectedJs('https://example.test/page'),
          contains('console.log("hi")'));
      expect(blocker.buildInjectedJs('https://other.test/page'), isEmpty);
    });

    test('removing a userscript stops injection', () {
      final blocker = ContentBlocker()
        ..addUserScript(const UserScript(name: 'x', code: 'void 0;'))
        ..removeUserScript('x');

      expect(blocker.scripts, isEmpty);
      expect(blocker.buildInjectedJs('https://any.test'), isEmpty);
    });
  });
}
