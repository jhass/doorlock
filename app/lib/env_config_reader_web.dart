import 'dart:js_interop';

@JS('window.env')
external JSObject? get _env;

extension EnvJSObjectExt on JSObject {
  // JS environment key naming intentionally follows UPPER_SNAKE_CASE.
  // ignore: non_constant_identifier_names
  external String? get POCKETBASE_URL;
}

String? readWindowPocketBaseUrl() {
  final env = _env;
  if (env == null) return null;
  return env.POCKETBASE_URL;
}
