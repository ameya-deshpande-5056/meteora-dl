import '../models/filter_rule.dart';

/// Manages filter lists, element-hiding CSS, and userscript injection for a
/// WebView. This is an adaptation of uBlock/Dark Reader/Violentmonkey ideas to
/// WebView's available APIs; full WebExtension parity requires GeckoView.
class ContentBlocker {
  final List<FilterRule> _rules = [];
  final List<UserScript> _scripts = [];
  DarkReaderSettings darkReader = const DarkReaderSettings();

  List<FilterRule> get rules => List.unmodifiable(_rules);
  List<UserScript> get scripts => List.unmodifiable(_scripts);

  void addRule(FilterRule rule) => _rules.add(rule);
  void removeRule(FilterRule rule) => _rules.remove(rule);

  void addUserScript(UserScript script) => _scripts.add(script);
  void removeUserScript(String name) =>
      _scripts.removeWhere((s) => s.name == name);

  /// Builds a CSS string to inject into a page (element hiding + Dark Reader).
  String buildInjectedCss() {
    final buffer = StringBuffer();
    for (final rule in _rules.where((r) => r.isCosmetic)) {
      buffer.writeln('${rule.pattern} { display: none !important; }');
    }
    if (darkReader.enabled) {
      final brightness = _num(darkReader.brightness);
      final contrast = _num(darkReader.contrast);
      final sepia = _num(darkReader.sepia);
      buffer.writeln(
        'html { filter: brightness($brightness%) '
        'contrast($contrast%) sepia($sepia%); }',
      );
    }
    return buffer.toString();
  }

  /// Formats a percentage without a pointless trailing `.0`.
  static String _num(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  /// Builds a JS snippet to inject userscripts matching [url].
  String buildInjectedJs(String url) {
    final buffer = StringBuffer();
    for (final script in _scripts) {
      if (_matches(script.matchPatterns, url)) {
        buffer.writeln('// ==UserScript: ${script.name}==');
        buffer.writeln(script.code);
      }
    }
    return buffer.toString();
  }

  bool _matches(List<String> patterns, String url) {
    // Minimal glob-ish matching: '*' matches any chars.
    for (final p in patterns) {
      final escaped = RegExp.escape(p).replaceAll(r'\*', '.*');
      final regex = RegExp('^$escaped\$');
      if (regex.hasMatch(url)) return true;
    }
    return patterns.isEmpty;
  }
}