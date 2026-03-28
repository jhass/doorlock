// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';

import 'window_service.dart';

@JS('eval')
external JSAny? _eval(JSString code);

/// Web implementation: opens HTML content in a new window using JS interop.
class DefaultWindowService implements WindowService {
  @override
  void openHtmlContent(String html) {
    final encoded = Uri.encodeComponent(html);
    // Escape single quotes to avoid breaking the JS string literal.
    final safe = encoded.replaceAll("'", "\\'");
    final js =
        "var w = window.open(); w.document.write(decodeURIComponent('$safe')); w.document.close();";
    _eval(js.toJS);
  }
}
