/// JavaScript injected into every page to discover playable/downloadable media.
///
/// WebView exposes no `webRequest` API, so instead of watching response
/// headers (what the qtIDM extension does via `chrome.webRequest`) the page
/// itself reports `<video>`/`<audio>` sources plus resource-timing entries.
/// The Dart side re-classifies each URL with [MediaProbe].
const String mediaCaptureScript = r'''
(function () {
  if (window.__meteoraMediaCapture) return;
  window.__meteoraMediaCapture = true;

  var seen = Object.create(null);
  var MAX = 400;

  function report(url, contentType) {
    try {
      if (!url || typeof url !== 'string') return;
      if (seen[url]) return;
      if (Object.keys(seen).length > MAX) return;
      seen[url] = true;
      MeteoraMedia.postMessage(JSON.stringify({
        url: url,
        contentType: contentType || '',
        filename: '',
        title: document.title || ''
      }));
    } catch (e) {}
  }

  function scanNode(node) {
    if (!node || node.nodeType !== 1) return;
    var tag = node.tagName ? node.tagName.toLowerCase() : '';
    if (tag === 'video' || tag === 'audio' || tag === 'source') {
      if (node.currentSrc) report(node.currentSrc, '');
      if (node.src) report(node.src, '');
    }
    if (node.querySelectorAll) {
      var media = node.querySelectorAll('video, audio, source');
      for (var i = 0; i < media.length; i++) {
        if (media[i].currentSrc) report(media[i].currentSrc, '');
        if (media[i].src) report(media[i].src, '');
      }
    }
  }

  function scanAll() {
    scanNode(document.documentElement);
    try {
      var entries = performance.getEntriesByType('resource') || [];
      for (var i = 0; i < entries.length; i++) {
        var type = entries[i].initiatorType;
        if (type === 'video' || type === 'audio' || type === 'xmlhttprequest' ||
            type === 'fetch' || type === 'other') {
          report(entries[i].name, '');
        }
      }
    } catch (e) {}
  }

  scanAll();
  document.addEventListener('DOMContentLoaded', scanAll);
  window.addEventListener('load', scanAll);
  // Players inject sources after the page settles; catch those too.
  setTimeout(scanAll, 1500);
  setTimeout(scanAll, 4000);

  try {
    new MutationObserver(function (records) {
      for (var i = 0; i < records.length; i++) {
        var added = records[i].addedNodes;
        for (var j = 0; j < added.length; j++) scanNode(added[j]);
      }
    }).observe(document.documentElement, { childList: true, subtree: true });
  } catch (e) {}
})();
''';
