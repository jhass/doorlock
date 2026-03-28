import 'dart:js_interop';

@JS('window.env')
external JSObject? get _env;

extension EnvJSObjectExt on JSObject {
  external String? get POCKETBASE_URL;
}

String? readWindowPocketBaseUrl() {
  final env = _env;
  if (env == null) return null;
  return env.POCKETBASE_URL;
}
