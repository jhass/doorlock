import 'dart:js_interop';
import 'window_service.dart';

@JS('eval')
external void jsEval(String code);

/// Web-specific window service that uses dart:js_interop for actual functionality
class WebWindowService implements WindowService {
  @override
  void openWindow(String url) {
    try {
      // Use modern JS interop to open a new window and write the HTML content
      final js = "var w = window.open(); w.document.write(decodeURIComponent('${url.replaceAll("'", "\\'")}')); w.document.close();";
      jsEval(js);
    } catch (e) {
      // Fallback if JS interop fails
      print('Cannot open window: $url');
    }
  }
}