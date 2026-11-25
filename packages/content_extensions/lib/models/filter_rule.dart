/// A simplified uBlock-style filter rule.
class FilterRule {
  final String pattern;
  final bool isException;
  final bool isCosmetic; // element hiding
  const FilterRule({
    required this.pattern,
    this.isException = false,
    this.isCosmetic = false,
  });
}

/// A userscript (Violentmonkey-style) metadata + code.
class UserScript {
  final String name;
  final String code;
  final List<String> matchPatterns;
  final String runAt; // document-start | document-end | document-idle
  const UserScript({
    required this.name,
    required this.code,
    this.matchPatterns = const ['*://*/*'],
    this.runAt = 'document-end',
  });
}

/// Dark Reader-style appearance override.
class DarkReaderSettings {
  final bool enabled;
  final double brightness;
  final double contrast;
  final double sepia;
  const DarkReaderSettings({
    this.enabled = false,
    this.brightness = 100,
    this.contrast = 100,
    this.sepia = 0,
  });
}