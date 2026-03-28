import 'dart:js_util' as js_util;

import 'window_service.dart';

/// Web implementation: opens HTML content in a new window using JS interop.
class DefaultWindowService implements WindowService {
  @override
  void openHtmlContent(String html) {
    final encoded = Uri.encodeComponent(html);
    // Escape single quotes to avoid breaking the JS string literal.
    final safe = encoded.replaceAll("'", "\\'");
    final js =
        "var w = window.open(); w.document.write(decodeURIComponent('$safe')); w.document.close();";
    js_util.callMethod(js_util.globalThis, 'eval', [js]);
  }
}
