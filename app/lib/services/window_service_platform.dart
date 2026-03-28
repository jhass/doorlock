// Conditional export: web gets WebWindowService, VM gets no-op stub.
// Both export a class named DefaultWindowService.
export 'window_service_stub.dart' if (dart.library.html) 'web_window_service.dart';
