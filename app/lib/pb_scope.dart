import 'package:flutter/widgets.dart';
import 'package:pocketbase/pocketbase.dart';

/// Provides a [PocketBase] client to the widget tree.
/// Mount above [MaterialApp] in production; mount around the widget under test in tests.
class PBScope extends InheritedWidget {
  final PocketBase pb;

  const PBScope({super.key, required this.pb, required super.child});

  /// Retrieves the nearest [PocketBase] instance from the widget tree.
  /// Safe to call from [State.initState], [State.build], and event handlers.
  static PocketBase of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PBScope>();
    assert(
      scope != null,
      'No PBScope found in context. Wrap your app or widget under test with PBScope.',
    );
    return scope!.pb;
  }

  @override
  bool updateShouldNotify(PBScope oldWidget) => pb != oldWidget.pb;
}
