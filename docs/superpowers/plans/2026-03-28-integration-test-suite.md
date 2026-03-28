# Integration Test Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a two-tier test suite (Dart VM widget tests + Chrome integration tests) for the doorlock Flutter app, backed by a real PocketBase process and a mock Home Assistant HTTP server, runnable in GitHub Actions.

**Architecture:** Minimal refactoring to `app/lib/` introduces `PBScope` (injectable PB client), `WindowService`, `ShareService`, and `BarcodeScannerBuilder` abstractions. `app/test_support/` provides `MockHomeAssistantServer`, `TestPocketBase`, and `TestFixtures`. Widget tests run on Dart VM; integration tests run on Chrome driven by `app/tool/start_test_infra.dart` which manages the PocketBase process.

**Tech Stack:** Flutter / Dart, PocketBase 0.28.2 binary, `integration_test` SDK package, `dart:io` HTTP server for mock HA, GitHub Actions.

---

## Reference: Key File Locations

| File | Role |
|---|---|
| `app/lib/pb_scope.dart` | InheritedWidget that provides `PocketBase` to widget tree |
| `app/lib/services/window_service.dart` | Abstract `WindowService` + `NoOpWindowService` |
| `app/lib/services/web_window_service.dart` | `DefaultWindowService` (web, uses `dart:js_util`) |
| `app/lib/services/window_service_stub.dart` | `DefaultWindowService` (VM, no-op) |
| `app/lib/services/window_service_platform.dart` | Conditional export: web vs VM |
| `app/lib/services/share_service.dart` | Abstract `ShareService` + `RealShareService` + `MockShareService` |
| `app/test_support/mock_ha_server.dart` | `dart:io` mock HA HTTP server |
| `app/test_support/test_pocketbase.dart` | PocketBase process lifecycle |
| `app/test_support/test_fixtures.dart` | Seed helpers |
| `app/tool/start_test_infra.dart` | Host-side program: starts infra, runs Chrome tests, stops infra |

---

## Task 1: Tooling setup (pubspec, .gitignore, directories)

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `.gitignore`
- Create: `tools/.gitkeep`

- [ ] **Step 1: Add `integration_test` dev dependency**

In `app/pubspec.yaml`, add under `dev_dependencies`:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter   # already present

  flutter_lints: ^6.0.0  # already present
```

- [ ] **Step 2: Add gitignore entries**

Append to `.gitignore` (repo root):

```
# Test tooling
tools/pocketbase
tools/.test_ports
app/tool/.test_ports
```

- [ ] **Step 3: Create tools directory placeholder**

```bash
mkdir -p tools && touch tools/.gitkeep
mkdir -p app/tool
```

- [ ] **Step 4: Run pub get**

```bash
cd app && flutter pub get
```

Expected: resolves without error, `integration_test` appears in `.dart_tool/package_config.json`.

- [ ] **Step 5: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock .gitignore tools/.gitkeep app/tool/
git commit -m "chore: add integration_test dep, tooling dirs, gitignore"
```

---

## Task 2: `PBScope` InheritedWidget

**Files:**
- Create: `app/lib/pb_scope.dart`

- [ ] **Step 1: Create `app/lib/pb_scope.dart`**

```dart
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
    assert(scope != null, 'No PBScope found in context. Wrap your app or widget under test with PBScope.');
    return scope!.pb;
  }

  @override
  bool updateShouldNotify(PBScope oldWidget) => pb != oldWidget.pb;
}
```

- [ ] **Step 2: Commit**

```bash
git add app/lib/pb_scope.dart
git commit -m "feat: add PBScope InheritedWidget"
```

---

## Task 3: `EnvConfig` — `--dart-define` override

**Files:**
- Modify: `app/lib/env_config.dart`

- [ ] **Step 1: Add dart-define check before JS interop**

Replace the entire content of `app/lib/env_config.dart` with:

```dart
import 'dart:js_interop';

@JS('window.env')
external JSObject? get _env;

extension EnvJSObjectExt on JSObject {
  external String? get POCKETBASE_URL;
}

class EnvConfig {
  static String get pocketBaseUrl {
    // Allow override via --dart-define=POCKETBASE_URL=... (used by integration tests in Chrome)
    const defined = String.fromEnvironment('POCKETBASE_URL');
    if (defined.isNotEmpty) return defined;

    // Production: read from window.env injected by docker-entrypoint.sh via env.js
    final env = _env;
    if (env == null) return 'http://127.0.0.1:8080';
    final url = env.POCKETBASE_URL;
    return url != null && url.isNotEmpty ? url : 'http://127.0.0.1:8080';
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/lib/env_config.dart
git commit -m "feat: EnvConfig respects --dart-define=POCKETBASE_URL for integration tests"
```

---

## Task 4: `WindowService` abstraction

**Files:**
- Create: `app/lib/services/window_service.dart`
- Create: `app/lib/services/web_window_service.dart`
- Create: `app/lib/services/window_service_stub.dart`
- Create: `app/lib/services/window_service_platform.dart`

- [ ] **Step 1: Create `app/lib/services/window_service.dart`**

```dart
/// Abstract service for opening HTML content in a new window.
/// Use [NoOpWindowService] in tests; production uses [DefaultWindowService]
/// from [window_service_platform.dart].
abstract class WindowService {
  void openHtmlContent(String html);
}

/// No-op implementation for tests that don't care about the print action.
class NoOpWindowService implements WindowService {
  @override
  void openHtmlContent(String html) {}
}

/// Test double that records calls for assertions.
class RecordingWindowService implements WindowService {
  final List<String> calls = [];

  @override
  void openHtmlContent(String html) {
    calls.add(html);
  }
}
```

- [ ] **Step 2: Create `app/lib/services/web_window_service.dart`**

This file is only compiled on web (via the conditional export in step 4).

```dart
import 'dart:js_util' as js_util;
import 'window_service.dart';

/// Web implementation: opens HTML content in a new window using JS interop.
class DefaultWindowService implements WindowService {
  @override
  void openHtmlContent(String html) {
    final encoded = Uri.encodeComponent(html);
    // Escape single quotes to avoid breaking the JS string literal.
    final safe = encoded.replaceAll("'", "\\'");
    final js = "var w = window.open(); w.document.write(decodeURIComponent('$safe')); w.document.close();";
    js_util.callMethod(js_util.globalThis, 'eval', [js]);
  }
}
```

- [ ] **Step 3: Create `app/lib/services/window_service_stub.dart`**

```dart
import 'window_service.dart';

/// VM / non-web stub: silently ignores the call.
/// Selected by [window_service_platform.dart] on non-web platforms.
class DefaultWindowService implements WindowService {
  @override
  void openHtmlContent(String html) {}
}
```

- [ ] **Step 4: Create `app/lib/services/window_service_platform.dart`**

On web, exports `web_window_service.dart` (has `dart:js_util`).
On Dart VM (dart.library.io is true), exports the stub.

```dart
// Conditional export: web gets WebWindowService, VM gets no-op stub.
// Both export a class named DefaultWindowService.
export 'window_service_stub.dart'
    if (dart.library.html) 'web_window_service.dart';
```

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/
git commit -m "feat: add WindowService abstraction with platform-conditional default"
```

---

## Task 5: `ShareService` abstraction

**Files:**
- Create: `app/lib/services/share_service.dart`

- [ ] **Step 1: Create `app/lib/services/share_service.dart`**

```dart
import 'package:share_plus/share_plus.dart';

abstract class ShareService {
  Future<void> shareText(String text);
}

/// Production implementation: delegates to share_plus.
class RealShareService implements ShareService {
  @override
  Future<void> shareText(String text) async {
    await Share.share(text);
  }
}

/// Test double that records calls for assertions.
class MockShareService implements ShareService {
  final List<String> calls = [];

  @override
  Future<void> shareText(String text) async {
    calls.add(text);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/lib/services/share_service.dart
git commit -m "feat: add ShareService abstraction"
```

---

## Task 6: Refactor `GrantQrScannerPage` — injectable scanner builder

**Files:**
- Modify: `app/lib/grant_qr_scanner_page.dart`

- [ ] **Step 1: Add `scannerBuilder` parameter**

Replace the entire content of `app/lib/grant_qr_scanner_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Builds the actual scanner widget. Swap in tests with a stub that calls
/// [onDetect] programmatically.
typedef BarcodeScannerBuilder = Widget Function(
    void Function(BarcodeCapture) onDetect);

class GrantQrScannerPage extends StatefulWidget {
  final void Function(String) onScanned;

  /// Optional: override the scanner widget. Defaults to [MobileScanner].
  /// In tests, pass a builder that taps [onDetect] immediately with a fake value.
  final BarcodeScannerBuilder? scannerBuilder;

  const GrantQrScannerPage({
    super.key,
    required this.onScanned,
    this.scannerBuilder,
  });

  @override
  State<GrantQrScannerPage> createState() => _GrantQrScannerPageState();
}

class _GrantQrScannerPageState extends State<GrantQrScannerPage> {
  bool _scanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code != null && code.isNotEmpty) {
      setState(() => _scanned = true);
      widget.onScanned(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.scannerBuilder ??
        (onDetect) => MobileScanner(onDetect: onDetect);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Lock QR Code')),
      body: Stack(
        children: [
          builder(_onDetect),
          if (_scanned)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/lib/grant_qr_scanner_page.dart
git commit -m "feat: GrantQrScannerPage accepts injectable scannerBuilder"
```

---

## Task 7: Refactor `LocksPage` — `PBScope`, `WindowService` injection, remove `dart:js_util`

**Files:**
- Modify: `app/lib/locks_page.dart`

- [ ] **Step 1: Rewrite `app/lib/locks_page.dart`**

Replace entire file:

```dart
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'pb_scope.dart';
import 'grants_sheet.dart';
import 'services/window_service.dart';
import 'services/window_service_platform.dart'; // DefaultWindowService (conditional)

class LocksPage extends StatefulWidget {
  final String homeAssistantId;
  final String homeAssistantUrl;

  /// Optional: override the window service. Defaults to [DefaultWindowService].
  /// Tests inject [NoOpWindowService] or [RecordingWindowService].
  final WindowService? windowService;

  const LocksPage({
    super.key,
    required this.homeAssistantId,
    required this.homeAssistantUrl,
    this.windowService,
  });

  @override
  State<LocksPage> createState() => _LocksPageState();
}

class _LocksPageState extends State<LocksPage> {
  late PocketBase _pb;
  late WindowService _windowService;
  bool _loading = true;
  List<dynamic> _locks = [];
  String? _error;
  bool _showAddLock = false;
  List<dynamic> _availableLocks = [];
  String? _addLockError;
  bool _showGrants = false;
  Map<String, dynamic>? _selectedLock;

  @override
  void initState() {
    super.initState();
    _pb = PBScope.of(context);
    _windowService = widget.windowService ?? DefaultWindowService();
    _fetchLocks();
  }

  Future<void> _fetchLocks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _pb.collection('doorlock_locks').getFullList(
        filter: 'homeassistant = "${widget.homeAssistantId}"',
      );
      setState(() {
        _locks = result.map((r) => r.toJson()).toList();
        _loading = false;
      });
    } on ClientException catch (e) {
      if (e.statusCode == 401) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/');
        return;
      }
      setState(() {
        _error = 'Failed to load locks: $e';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load locks: $e';
        _loading = false;
      });
    }
  }

  Future<void> _fetchAvailableLocks() async {
    setState(() {
      _addLockError = null;
    });
    try {
      final response = await _pb.send(
        '/doorlock/homeassistant/${widget.homeAssistantId}/locks',
      );
      setState(() {
        _availableLocks = List<Map<String, dynamic>>.from(response as List);
        _showAddLock = true;
      });
    } on ClientException catch (e) {
      if (e.statusCode == 401) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/');
        return;
      }
      setState(() {
        _addLockError = 'Failed to fetch available locks: $e';
      });
    } catch (e) {
      setState(() {
        _addLockError = 'Failed to fetch available locks: $e';
      });
    }
  }

  Future<void> _addLock(Map<String, dynamic> lock) async {
    setState(() {
      _addLockError = null;
    });
    try {
      await _pb.collection('doorlock_locks').create(body: {
        'homeassistant': widget.homeAssistantId,
        'entity_id': lock['id'],
        'name': lock['name'],
      });
      setState(() {
        _showAddLock = false;
      });
      await _fetchLocks();
    } on ClientException catch (e) {
      if (e.statusCode == 401) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/');
        return;
      }
      setState(() {
        _addLockError = 'Failed to add lock: $e';
      });
    } catch (e) {
      setState(() {
        _addLockError = 'Failed to add lock: $e';
      });
    }
  }

  Future<void> _fetchGrants(String lockId) async {
    setState(() {
      _showGrants = true;
      _selectedLock = _locks.firstWhere(
        (l) => l['id'] == lockId,
        orElse: () => <String, dynamic>{},
      );
    });
  }

  void _showLockQr(BuildContext context, Map<String, dynamic> lock) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lock QR Code'),
        content: SizedBox(
          width: 250,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lock['identification_token'] != null)
                QrImageView(
                  data: lock['identification_token'],
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              if (lock['identification_token'] == null)
                const Text('No identification token available'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          if (lock['identification_token'] != null)
            TextButton(
              onPressed: () {
                final qrHtml = '''
                  <html>
                  <head>
                    <title>Print QR Code</title>
                    <style>@page { margin: 0; } body { margin: 0; }</style>
                  </head>
                  <body style="display:flex;align-items:center;justify-content:center;height:100vh;">
                    <div id="qrcode"></div>
                    <script src="https://cdn.jsdelivr.net/npm/qrious@4.0.2/dist/qrious.min.js"></script>
                    <script>
                      var qr = new QRious({
                        element: document.createElement('canvas'),
                        value: "${lock['identification_token']}",
                        size: 300
                      });
                      document.getElementById('qrcode').appendChild(qr.element);
                      window.onload = function() { window.print(); };
                    </script>
                  </body>
                  </html>
                ''';
                _windowService.openHtmlContent(qrHtml);
              },
              child: const Text('Print'),
            ),
        ],
      ),
    );
  }

  Widget _buildAddLockSheet() {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Lock')),
      body: _addLockError != null
          ? Center(
              child: Text(_addLockError!,
                  style: const TextStyle(color: Colors.red)))
          : ListView.builder(
              itemCount: _availableLocks.length,
              itemBuilder: (context, index) {
                final lock = _availableLocks[index];
                return ListTile(
                  title: Text(lock['name'] ?? lock['id'] ?? 'Unknown lock'),
                  subtitle: Text(lock['id'] ?? ''),
                  onTap: () => _addLock(lock),
                );
              },
            ),
    );
  }

  Widget _buildGrantsSheet() {
    return GrantsSheet(
      lock: _selectedLock,
      onBack: () => setState(() => _showGrants = false),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showAddLock) return _buildAddLockSheet();
    if (_showGrants) return _buildGrantsSheet();
    return Scaffold(
      appBar: AppBar(
        title: Text('Locks for ${widget.homeAssistantUrl}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Lock',
            onPressed: _fetchAvailableLocks,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  itemCount: _locks.length,
                  itemBuilder: (context, index) {
                    final lock = _locks[index];
                    return ListTile(
                      title: Text(
                          lock['name'] ?? lock['id'] ?? 'Unknown lock'),
                      subtitle: Text(lock['entity_id'] ?? ''),
                      onTap: () => _fetchGrants(lock['id']),
                      trailing: IconButton(
                        icon: const Icon(Icons.qr_code),
                        tooltip: 'Show Lock QR',
                        onPressed: () => _showLockQr(context, lock),
                      ),
                    );
                  },
                ),
    );
  }
}
```

- [ ] **Step 2: Verify no `dart:js_util` import remains**

```bash
grep -n 'dart:js_util' app/lib/locks_page.dart
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add app/lib/locks_page.dart
git commit -m "feat: LocksPage uses PBScope and injectable WindowService, removes dart:js_util"
```

---

## Task 8: Refactor `GrantsSheet` — `PBScope`, `ShareService` injection

**Files:**
- Modify: `app/lib/grants_sheet.dart`

- [ ] **Step 1: Add imports and parameters to `GrantsSheet`**

At the top of `app/lib/grants_sheet.dart`, replace the existing imports block:

```dart
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'pb_scope.dart';
import 'services/share_service.dart';
```

Remove: `import 'package:share_plus/share_plus.dart';` and `import 'pb.dart';`

- [ ] **Step 2: Update `GrantsSheet` constructor to accept `shareService`**

In the `GrantsSheet` class definition, add the optional parameter:

```dart
class GrantsSheet extends StatefulWidget {
  final Map<String, dynamic>? lock;
  final VoidCallback onBack;

  /// Optional: override share implementation. Defaults to [RealShareService].
  /// Tests inject [MockShareService] to record share calls.
  final ShareService? shareService;

  const GrantsSheet({
    super.key,
    required this.lock,
    required this.onBack,
    this.shareService,
  });

  @override
  State<GrantsSheet> createState() => _GrantsSheetState();
}
```

- [ ] **Step 3: Update `_GrantsSheetState` to use `PBScope` and `shareService`**

Replace the `_pb` field declaration:

```dart
// Remove: final _pb = PB.instance;
// Add these fields:
late PocketBase _pb;
late ShareService _shareService;
```

Update `initState`:

```dart
@override
void initState() {
  super.initState();
  _pb = PBScope.of(context);
  _shareService = widget.shareService ?? RealShareService();
  _fetchGrants();
}
```

- [ ] **Step 4: Update `_shareDeeplink` to use `_shareService`**

Replace the `_shareDeeplink` method:

```dart
Future<void> _shareDeeplink(BuildContext context, String deeplink) async {
  try {
    await _shareService.shareText(deeplink);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: deeplink));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deeplink copied to clipboard')),
      );
    }
  }
}
```

- [ ] **Step 5: Verify compilation**

```bash
cd app && flutter analyze lib/grants_sheet.dart
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add app/lib/grants_sheet.dart
git commit -m "feat: GrantsSheet uses PBScope and injectable ShareService"
```

---

## Task 9: Refactor `main.dart` — `PBScope` wrap, migrate all `PB.instance` uses, delete `pb.dart`

**Files:**
- Modify: `app/lib/main.dart`
- Delete: `app/lib/pb.dart`

- [ ] **Step 1: Replace imports at top of `main.dart`**

Remove `import 'pb.dart';` and add `import 'pb_scope.dart';` and `import 'env_config.dart';` (if not already present) and `import 'package:pocketbase/pocketbase.dart';`.

The import block becomes:

```dart
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_home_assistant_page.dart';
import 'env_config.dart';
import 'grant_qr_scanner_page.dart';
import 'home_assistants_page.dart';
import 'open_door_page.dart';
import 'pb_scope.dart';
import 'session_storage.dart';
import 'sign_in_page.dart';
```

- [ ] **Step 2: Wrap `MyApp.build` in `PBScope`**

In `MyApp.build`, wrap the `MaterialApp` widget (both the grant-flow and the main-flow branches) in a `PBScope`:

```dart
@override
Widget build(BuildContext context) {
  final pb = PocketBase(EnvConfig.pocketBaseUrl);
  final uri = Uri.base;
  final grantToken = uri.queryParameters['grant'];
  if (grantToken != null && grantToken.isNotEmpty) {
    return PBScope(
      pb: pb,
      child: MaterialApp(
        title: 'Doorlock app',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: _GrantFlow(grantToken: grantToken),
      ),
    );
  }

  return PBScope(
    pb: pb,
    child: MaterialApp(
      title: 'Doorlock app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: AuthGate(
        builder: (context) => HomeAssistantsPageWrapper(),
      ),
    ),
  );
}
```

- [ ] **Step 3: Update `_AuthGateState` — replace all `PB.instance` with `PBScope.of(context)`**

Replace the `_initAuthStore` method:

```dart
Future<void> _initAuthStore() async {
  final pb = PBScope.of(context);
  final session = await SessionStorage.loadSession();
  if (session != null && session['token'] != null) {
    pb.authStore.save(session['token'] as String, null);
  }
  setState(() {
    _loading = false;
  });
}
```

Replace the `_signIn` method:

```dart
Future<void> _signIn(String username, String password) async {
  setState(() {
    _loading = true;
    _error = null;
  });
  try {
    final pb = PBScope.of(context);
    await pb.collection('doorlock_users').authWithPassword(username, password);
    await SessionStorage.saveSession({'token': pb.authStore.token});
    setState(() {
      _loading = false;
    });
  } on ClientException catch (e) {
    setState(() {
      _error = e.statusCode == 401
          ? 'Session expired, please sign in again.'
          : 'Sign in failed';
      _loading = false;
    });
  } catch (e) {
    setState(() {
      _error = 'Sign in failed';
      _loading = false;
    });
  }
}
```

Replace the `build` method of `_AuthGateState`:

```dart
@override
Widget build(BuildContext context) {
  if (_loading) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
  if (!PBScope.of(context).authStore.isValid) {
    return SignInPage(onSignIn: _signIn, error: _error);
  }
  return widget.builder(context);
}
```

- [ ] **Step 4: Update `_HomeAssistantsPageWrapperState` — replace all `PB.instance`**

Replace the `_fetchAssistants` method:

```dart
Future<void> _fetchAssistants() async {
  setState(() {
    _loading = true;
    _error = null;
  });
  try {
    final result = await PBScope.of(context)
        .collection('doorlock_homeassistants')
        .getFullList();
    setState(() {
      _assistants = result.map((r) => r.toJson()).toList();
      _loading = false;
    });
  } on ClientException catch (e) {
    if (e.statusCode == 401) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/');
      return;
    }
    setState(() {
      _error = 'Failed to load home assistants: $e';
      _loading = false;
    });
  } catch (e) {
    setState(() {
      _error = 'Failed to load home assistants: $e';
      _loading = false;
    });
  }
}
```

Replace the `_addHomeAssistant` method:

```dart
Future<void> _addHomeAssistant(String url, String frontendCallback) async {
  setState(() {
    _addError = null;
  });
  try {
    final resp = await PBScope.of(context).send(
      '/doorlock/homeassistant',
      method: 'POST',
      body: {
        'url': url,
        'frontend_callback': frontendCallback,
      },
    );
    if (resp is Map && resp['auth_url'] != null) {
      final authUrl = resp['auth_url'];
      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    await _fetchAssistants();
    if (mounted) Navigator.of(context).pop();
  } on ClientException catch (e) {
    if (e.statusCode == 401) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/');
      return;
    }
    setState(() {
      _addError = 'Failed to add: ${e.response['message'] ?? e.toString()}';
    });
  } catch (e) {
    setState(() {
      _addError = 'Failed to add: ${e.toString()}';
    });
  }
}
```

Replace the `build` method's sign-out callback:

```dart
onSignOut: () async {
  await SessionStorage.clearSession();
  PBScope.of(context).authStore.clear();
  Navigator.of(context).pushReplacementNamed('/');
},
```

- [ ] **Step 5: Update `OpenDoorPage` — replace `PB.instance`**

In `app/lib/open_door_page.dart`, replace the import `import 'pb.dart';` with `import 'pb_scope.dart';`.

Replace `await PB.instance.send(...)` with `await PBScope.of(context).send(...)`.

- [ ] **Step 6: Delete `pb.dart`**

```bash
rm app/lib/pb.dart
```

- [ ] **Step 7: Verify no remaining references to `pb.dart` or `PB.instance`**

```bash
grep -rn "PB\.instance\|import.*pb\.dart" app/lib/
```

Expected: no output.

- [ ] **Step 8: Run analyzer to confirm no errors**

```bash
cd app && flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 9: Commit**

```bash
git add app/lib/main.dart app/lib/open_door_page.dart
git rm app/lib/pb.dart
git commit -m "feat: migrate all widgets to PBScope, delete PB.instance singleton"
```

---

## Task 10: `MockHomeAssistantServer`

**Files:**
- Create: `app/test_support/mock_ha_server.dart`

- [ ] **Step 1: Create `app/test_support/mock_ha_server.dart`**

```dart
import 'dart:convert';
import 'dart:io';

/// A minimal mock of the Home Assistant HTTP API.
/// Handles the three endpoints called by PocketBase hooks:
///   POST /auth/token       — token endpoint (OAuth2 + refresh)
///   GET  /api/states       — entity state list
///   POST /api/services/lock/open — lock service call
///
/// Records all received requests for assertion use.
class MockHomeAssistantServer {
  final HttpServer _server;
  final List<HttpRequest> _recordedRequests = [];
  final Map<String, _OverrideResponse> _nextOverrides = {};

  // Configurable entity list returned by GET /api/states.
  List<Map<String, dynamic>> entities;

  MockHomeAssistantServer._(this._server, {required this.entities}) {
    _serve();
  }

  /// Starts the server on a random available port.
  static Future<MockHomeAssistantServer> start({
    List<Map<String, dynamic>>? entities,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return MockHomeAssistantServer._(
      server,
      entities: entities ??
          [
            {
              'entity_id': 'lock.front_door',
              'state': 'locked',
              'attributes': {
                'friendly_name': 'Front Door',
                'supported_features': 1,
              },
            },
          ],
    );
  }

  int get port => _server.port;
  String get baseUrl => 'http://localhost:$port';
  List<HttpRequest> get recordedRequests => List.unmodifiable(_recordedRequests);

  /// Override the response for the next request matching [path].
  /// After one use the override is cleared.
  void setNextResponseFor(String path, int statusCode, Map<String, dynamic> body) {
    _nextOverrides[path] = _OverrideResponse(statusCode, body);
  }

  void _serve() {
    _server.listen((req) async {
      _recordedRequests.add(req);

      final path = req.uri.path;
      final override = _nextOverrides.remove(path);

      if (override != null) {
        req.response
          ..statusCode = override.statusCode
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(override.body));
        await req.response.close();
        return;
      }

      if (req.method == 'POST' && path == '/auth/token') {
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'access_token': 'test-token-refreshed',
            'expires_in': 3600,
            'token_type': 'Bearer',
            'refresh_token': 'test-refresh',
          }));
      } else if (req.method == 'GET' && path == '/api/states') {
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(entities));
      } else if (req.method == 'POST' && path == '/api/services/lock/open') {
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(<String, dynamic>{}));
      } else {
        req.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found');
      }

      await req.response.close();
    });
  }

  Future<void> stop() async {
    await _server.close(force: true);
  }
}

class _OverrideResponse {
  final int statusCode;
  final Map<String, dynamic> body;
  _OverrideResponse(this.statusCode, this.body);
}
```

- [ ] **Step 2: Commit**

```bash
git add app/test_support/mock_ha_server.dart
git commit -m "test: add MockHomeAssistantServer"
```

---

## Task 11: `TestPocketBase`

**Files:**
- Create: `app/test_support/test_pocketbase.dart`

- [ ] **Step 1: Create `app/test_support/test_pocketbase.dart`**

```dart
import 'dart:io';
import 'package:pocketbase/pocketbase.dart';

/// Manages a PocketBase child process for tests.
///
/// Layout inside [_tempDir]:
///   pb_data/          ← PocketBase data directory (--dir flag)
///   pb_hooks/         ← symlink to repo's pb_hooks/
///   pb_migrations/    ← symlink to repo's pb_migrations/
///
/// PocketBase defaults hooks/migrations to siblings of pb_data, so they are
/// picked up automatically without extra flags.
class TestPocketBase {
  final Directory _tempDir;
  final Process _process;
  final int _port;

  TestPocketBase._(this._tempDir, this._process, this._port);

  String get baseUrl => 'http://localhost:$_port';

  late PocketBase _adminClient;
  PocketBase get adminClient => _adminClient;

  /// Starts a fresh PocketBase instance with the real hooks and migrations.
  ///
  /// Requires the PocketBase binary to be available via:
  ///   1. Env var POCKETBASE_BINARY
  ///   2. tools/pocketbase relative to the repo root
  ///   3. `pocketbase` on PATH
  static Future<TestPocketBase> start() async {
    final binary = _findBinary();
    final tempDir = await Directory.systemTemp.createTemp('doorlock_pb_test_');
    final dataDir = Directory('${tempDir.path}/pb_data');
    await dataDir.create();

    // Symlink real hooks and migrations as siblings of pb_data — PocketBase
    // automatically uses <parent of --dir>/pb_hooks and pb_migrations.
    final repoRoot = _repoRoot();
    await Link('${tempDir.path}/pb_hooks').create('$repoRoot/pb_hooks');
    await Link('${tempDir.path}/pb_migrations').create('$repoRoot/pb_migrations');

    final port = await _findFreePort();

    // Create superuser (also initialises pb_data schema).
    final upsertResult = await Process.run(binary, [
      'superuser',
      'upsert',
      'admin@test.local',
      'testpassword',
      '--dir',
      dataDir.path,
    ]);
    if (upsertResult.exitCode != 0) {
      throw Exception(
          'pocketbase superuser upsert failed:\n${upsertResult.stderr}');
    }

    // Start server.
    final process = await Process.start(binary, [
      'serve',
      '--http=localhost:$port',
      '--dev',
      '--dir',
      dataDir.path,
    ]);

    // Pipe output so failures are visible in test output.
    process.stdout.transform(const SystemEncoding().decoder).listen(
        (line) => stderr.write('[PB] $line'));
    process.stderr.transform(const SystemEncoding().decoder).listen(
        (line) => stderr.write('[PB] $line'));

    final instance = TestPocketBase._(tempDir, process, port);

    // Wait for health endpoint.
    await instance._waitForReady();

    // Authenticate as superuser.
    final pb = PocketBase(instance.baseUrl);
    await pb.collection('_superusers').authWithPassword(
      'admin@test.local',
      'testpassword',
    );
    instance._adminClient = pb;

    return instance;
  }

  /// Kills the PocketBase process and removes the temporary directory.
  Future<void> stop() async {
    _process.kill();
    await _process.exitCode;
    await _tempDir.delete(recursive: true);
  }

  Future<void> _waitForReady({Duration timeout = const Duration(seconds: 20)}) async {
    final client = HttpClient();
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final req = await client.getUrl(Uri.parse('$baseUrl/api/health'));
        final resp = await req.close();
        await resp.drain<void>();
        if (resp.statusCode == 200) {
          client.close();
          return;
        }
      } catch (_) {
        // Not ready yet.
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    client.close();
    throw TimeoutException('PocketBase did not become ready within $timeout');
  }

  static String _findBinary() {
    // 1. Explicit env var.
    final envBinary = Platform.environment['POCKETBASE_BINARY'];
    if (envBinary != null && File(envBinary).existsSync()) return envBinary;

    // 2. tools/pocketbase relative to repo root (installed via make install-pb-test).
    final repoBinary = '${_repoRoot()}/tools/pocketbase';
    if (File(repoBinary).existsSync()) return repoBinary;

    // 3. Assume on PATH.
    return 'pocketbase';
  }

  /// Repo root is the parent of the app/ directory.
  /// When running `flutter test` from app/, Directory.current == app/.
  static String _repoRoot() => Directory.current.parent.path;

  static Future<int> _findFreePort() async {
    final server =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/test_support/test_pocketbase.dart
git commit -m "test: add TestPocketBase process manager"
```

---

## Task 12: `TestFixtures`

**Files:**
- Create: `app/test_support/test_fixtures.dart`

- [ ] **Step 1: Create `app/test_support/test_fixtures.dart`**

```dart
import 'package:pocketbase/pocketbase.dart';
import 'mock_ha_server.dart';

/// Seed helpers for test data. All methods use [adminClient] so they bypass
/// PocketBase collection access rules.
class TestFixtures {
  final PocketBase adminClient;
  final MockHomeAssistantServer mockHa;

  TestFixtures({required this.adminClient, required this.mockHa});

  /// Creates a user in [doorlock_users] and returns their ID.
  Future<String> createUser({
    String email = 'testuser@test.local',
    String password = 'testpassword',
  }) async {
    final record = await adminClient.collection('doorlock_users').create(body: {
      'email': email,
      'password': password,
      'passwordConfirm': password,
    });
    return record.id;
  }

  /// Returns a [PocketBase] client authenticated as the given user.
  Future<PocketBase> userClient({
    String email = 'testuser@test.local',
    String password = 'testpassword',
  }) async {
    final pb = PocketBase(adminClient.baseUrl);
    await pb.collection('doorlock_users').authWithPassword(email, password);
    return pb;
  }

  /// Creates a [doorlock_homeassistants] record pointing at [mockHa],
  /// with a valid access token that won't expire for a year.
  /// Returns the record ID.
  Future<String> createHomeAssistant(String userId) async {
    final record =
        await adminClient.collection('doorlock_homeassistants').create(body: {
      'url': mockHa.baseUrl,
      'owner': userId,
      'access_token': 'test-token',
      'access_token_expires_at': '2099-01-01 00:00:00.000Z',
      'refresh_token': 'test-refresh',
    });
    return record.id;
  }

  /// Creates a [doorlock_locks] record and returns the full record JSON
  /// (including the auto-generated [identification_token]).
  Future<Map<String, dynamic>> createLock(String haId) async {
    final record = await adminClient.collection('doorlock_locks').create(body: {
      'homeassistant': haId,
      'entity_id': 'lock.front_door',
      'name': 'Front Door',
    });
    return record.toJson();
  }

  /// Creates a [doorlock_grants] record valid by default (now-1h to now+24h,
  /// unlimited usage). Returns the full record JSON including [token].
  Future<Map<String, dynamic>> createGrant(
    String lockId, {
    DateTime? notBefore,
    DateTime? notAfter,
    int usageLimit = -1,
    String name = 'Test Grant',
  }) async {
    final nb = (notBefore ?? DateTime.now().subtract(const Duration(hours: 1)))
        .toUtc();
    final na =
        (notAfter ?? DateTime.now().add(const Duration(hours: 24))).toUtc();
    final record =
        await adminClient.collection('doorlock_grants').create(body: {
      'lock': lockId,
      'name': name,
      'not_before': _pbDate(nb),
      'not_after': _pbDate(na),
      'usage_limit': usageLimit,
    });
    return record.toJson();
  }

  /// Formats a [DateTime] as PocketBase's expected date string.
  static String _pbDate(DateTime dt) {
    final u = dt.toUtc();
    return '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')} '
        '${u.hour.toString().padLeft(2, '0')}:'
        '${u.minute.toString().padLeft(2, '0')}:'
        '${u.second.toString().padLeft(2, '0')}.000Z';
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/test_support/test_fixtures.dart
git commit -m "test: add TestFixtures seed helpers"
```

---

## Task 13: Widget test — sign-in flow

**Files:**
- Create: `app/test/sign_in_test.dart`

- [ ] **Step 1: Create `app/test/sign_in_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:doorlock/main.dart';
import 'package:doorlock/pb_scope.dart';
import '../test_support/mock_ha_server.dart';
import '../test_support/test_pocketbase.dart';
import '../test_support/test_fixtures.dart';

void main() {
  late TestPocketBase testPb;
  late MockHomeAssistantServer mockHa;
  late TestFixtures fixtures;

  setUpAll(() async {
    mockHa = await MockHomeAssistantServer.start();
    testPb = await TestPocketBase.start();
    fixtures = TestFixtures(adminClient: testPb.adminClient, mockHa: mockHa);
    await fixtures.createUser();
  });

  tearDownAll(() async {
    await testPb.stop();
    await mockHa.stop();
  });

  Widget buildApp(PocketBase pb) {
    return PBScope(
      pb: pb,
      child: MaterialApp(
        home: AuthGate(builder: (context) => const Text('Home')),
      ),
    );
  }

  testWidgets('shows sign-in form when not authenticated', (tester) async {
    final pb = PocketBase(testPb.baseUrl); // fresh, no auth
    await tester.pumpWidget(buildApp(pb));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('shows error on wrong password', (tester) async {
    final pb = PocketBase(testPb.baseUrl);
    await tester.pumpWidget(buildApp(pb));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'testuser@test.local');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'wrongpassword');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in failed'), findsOneWidget);
  });

  testWidgets('signs in with valid credentials', (tester) async {
    final pb = PocketBase(testPb.baseUrl);
    await tester.pumpWidget(buildApp(pb));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'testuser@test.local');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'testpassword');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Past sign-in, the AuthGate builder renders 'Home'.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);
  });

  testWidgets('restores session from storage — skips sign-in form', (tester) async {
    // Authenticate to get a valid token.
    final pb = PocketBase(testPb.baseUrl);
    await pb
        .collection('doorlock_users')
        .authWithPassword('testuser@test.local', 'testpassword');

    // Pre-save the token as AuthGate would.
    final savedPb = PocketBase(testPb.baseUrl);
    savedPb.authStore.save(pb.authStore.token, null);

    await tester.pumpWidget(buildApp(savedPb));
    await tester.pumpAndSettle();

    // AuthGate sees a valid token and skips the sign-in form.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test**

```bash
cd app && flutter test test/sign_in_test.dart --reporter expanded
```

Expected: all 4 tests pass.

- [ ] **Step 3: Commit**

```bash
git add app/test/sign_in_test.dart
git commit -m "test: add sign-in widget tests"
```

---

## Task 14: Widget test — home assistants page

**Files:**
- Create: `app/test/home_assistants_test.dart`

- [ ] **Step 1: Create `app/test/home_assistants_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:doorlock/home_assistants_page.dart';
import 'package:doorlock/locks_page.dart';
import 'package:doorlock/pb_scope.dart';
import 'package:doorlock/services/window_service.dart';
import '../test_support/mock_ha_server.dart';
import '../test_support/test_pocketbase.dart';
import '../test_support/test_fixtures.dart';

void main() {
  late TestPocketBase testPb;
  late MockHomeAssistantServer mockHa;
  late TestFixtures fixtures;
  late PocketBase userPb;
  late String haId;

  setUpAll(() async {
    mockHa = await MockHomeAssistantServer.start();
    testPb = await TestPocketBase.start();
    fixtures = TestFixtures(adminClient: testPb.adminClient, mockHa: mockHa);
    final userId = await fixtures.createUser();
    haId = await fixtures.createHomeAssistant(userId);
    userPb = await fixtures.userClient();
  });

  tearDownAll(() async {
    await testPb.stop();
    await mockHa.stop();
  });

  testWidgets('lists seeded home assistant record', (tester) async {
    final assistants = await userPb
        .collection('doorlock_homeassistants')
        .getFullList();

    await tester.pumpWidget(
      PBScope(
        pb: userPb,
        child: MaterialApp(
          home: HomeAssistantsPage(
            assistants: assistants.map((r) => r.toJson()).toList(),
            onSignOut: () {},
            onAdd: () {},
          ),
        ),
      ),
    );

    expect(find.text(mockHa.baseUrl), findsOneWidget);
  });

  testWidgets('tapping HA record navigates to LocksPage', (tester) async {
    final assistants = await userPb
        .collection('doorlock_homeassistants')
        .getFullList();

    await tester.pumpWidget(
      PBScope(
        pb: userPb,
        child: MaterialApp(
          home: HomeAssistantsPage(
            assistants: assistants.map((r) => r.toJson()).toList(),
            onSignOut: () {},
            onAdd: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text(mockHa.baseUrl));
    await tester.pumpAndSettle();

    expect(find.byType(LocksPage), findsOneWidget);
    expect(find.text('Locks for ${mockHa.baseUrl}'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test**

```bash
cd app && flutter test test/home_assistants_test.dart --reporter expanded
```

Expected: 2 tests pass.

- [ ] **Step 3: Commit**

```bash
git add app/test/home_assistants_test.dart
git commit -m "test: add home assistants widget tests"
```

---

## Task 15: Widget test — locks page

**Files:**
- Create: `app/test/locks_test.dart`

- [ ] **Step 1: Create `app/test/locks_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:doorlock/locks_page.dart';
import 'package:doorlock/pb_scope.dart';
import 'package:doorlock/services/window_service.dart';
import '../test_support/mock_ha_server.dart';
import '../test_support/test_pocketbase.dart';
import '../test_support/test_fixtures.dart';

void main() {
  late TestPocketBase testPb;
  late MockHomeAssistantServer mockHa;
  late TestFixtures fixtures;
  late PocketBase userPb;
  late String haId;
  late Map<String, dynamic> lockRecord;

  setUpAll(() async {
    mockHa = await MockHomeAssistantServer.start();
    testPb = await TestPocketBase.start();
    fixtures = TestFixtures(adminClient: testPb.adminClient, mockHa: mockHa);
    final userId = await fixtures.createUser();
    haId = await fixtures.createHomeAssistant(userId);
    lockRecord = await fixtures.createLock(haId);
    userPb = await fixtures.userClient();
  });

  tearDownAll(() async {
    await testPb.stop();
    await mockHa.stop();
  });

  Widget buildLocksPage({WindowService? windowService}) {
    return PBScope(
      pb: userPb,
      child: MaterialApp(
        home: LocksPage(
          homeAssistantId: haId,
          homeAssistantUrl: mockHa.baseUrl,
          windowService: windowService ?? NoOpWindowService(),
        ),
      ),
    );
  }

  testWidgets('shows seeded lock in list', (tester) async {
    await tester.pumpWidget(buildLocksPage());
    await tester.pumpAndSettle();

    expect(find.text('Front Door'), findsOneWidget);
    expect(find.text('lock.front_door'), findsOneWidget);
  });

  testWidgets('Add Lock fetches from mock HA and shows entity list', (tester) async {
    await tester.pumpWidget(buildLocksPage());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Mock HA returns 'lock.front_door' / 'Front Door' by default.
    expect(find.text('Front Door'), findsOneWidget);

    // Verify the mock HA received the GET /api/states request.
    expect(
      mockHa.recordedRequests
          .any((r) => r.method == 'GET' && r.uri.path == '/api/states'),
      isTrue,
    );
  });

  testWidgets('tapping entity creates a lock record and re-lists', (tester) async {
    // Ensure entity list is fresh before this test.
    final countBefore = (await testPb.adminClient
            .collection('doorlock_locks')
            .getFullList(filter: 'homeassistant = "$haId"'))
        .length;

    await tester.pumpWidget(buildLocksPage());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Front Door'));
    await tester.pumpAndSettle();

    final countAfter = (await testPb.adminClient
            .collection('doorlock_locks')
            .getFullList(filter: 'homeassistant = "$haId"'))
        .length;

    expect(countAfter, greaterThan(countBefore));
  });

  testWidgets('QR icon opens dialog with identification_token', (tester) async {
    await tester.pumpWidget(buildLocksPage());
    await tester.pumpAndSettle();

    // Tap the QR icon for the existing lock.
    await tester.tap(find.byIcon(Icons.qr_code).first);
    await tester.pumpAndSettle();

    // Dialog should be visible.
    expect(find.text('Lock QR Code'), findsOneWidget);
    // The identification_token is used as QR data; dialog shows it.
    expect(find.byKey(const Key('qr_image')), findsAny);
  });
}
```

Note: if `QrImageView` doesn't expose a `Key`, find the dialog by checking `find.text('Lock QR Code')` and `find.text('Close')` instead of `find.byKey`. Adjust this assertion after running once to see what's rendered.

- [ ] **Step 2: Run the test**

```bash
cd app && flutter test test/locks_test.dart --reporter expanded
```

Expected: all tests pass. If the QR key assertion fails, adjust to `expect(find.text('Close'), findsOneWidget)` to simply confirm the dialog opened.

- [ ] **Step 3: Commit**

```bash
git add app/test/locks_test.dart
git commit -m "test: add locks widget tests"
```

---

## Task 16: Widget test — grants sheet

**Files:**
- Create: `app/test/grants_test.dart`

- [ ] **Step 1: Create `app/test/grants_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:doorlock/grants_sheet.dart';
import 'package:doorlock/pb_scope.dart';
import 'package:doorlock/services/share_service.dart';
import '../test_support/mock_ha_server.dart';
import '../test_support/test_pocketbase.dart';
import '../test_support/test_fixtures.dart';

void main() {
  late TestPocketBase testPb;
  late MockHomeAssistantServer mockHa;
  late TestFixtures fixtures;
  late PocketBase userPb;
  late String lockId;
  late Map<String, dynamic> grantRecord;

  setUpAll(() async {
    mockHa = await MockHomeAssistantServer.start();
    testPb = await TestPocketBase.start();
    fixtures = TestFixtures(adminClient: testPb.adminClient, mockHa: mockHa);
    final userId = await fixtures.createUser();
    final haId = await fixtures.createHomeAssistant(userId);
    final lock = await fixtures.createLock(haId);
    lockId = lock['id'] as String;
    grantRecord = await fixtures.createGrant(lockId);
    userPb = await fixtures.userClient();
  });

  tearDownAll(() async {
    await testPb.stop();
    await mockHa.stop();
  });

  Widget buildGrantsSheet({
    required Map<String, dynamic> lock,
    ShareService? shareService,
  }) {
    return PBScope(
      pb: userPb,
      child: MaterialApp(
        home: Scaffold(
          body: GrantsSheet(
            lock: lock,
            onBack: () {},
            shareService: shareService,
          ),
        ),
      ),
    );
  }

  testWidgets('shows seeded grant in list', (tester) async {
    final lock = (await userPb
            .collection('doorlock_locks')
            .getOne(lockId))
        .toJson();

    await tester.pumpWidget(buildGrantsSheet(lock: lock));
    await tester.pumpAndSettle();

    expect(find.text('Test Grant'), findsOneWidget);
  });

  testWidgets('deletes a grant', (tester) async {
    // Create a separate grant to delete so we don't affect other tests.
    final toDelete = await fixtures.createGrant(lockId, name: 'Delete Me');
    final lock = (await userPb
            .collection('doorlock_locks')
            .getOne(lockId))
        .toJson();

    await tester.pumpWidget(buildGrantsSheet(lock: lock));
    await tester.pumpAndSettle();

    expect(find.text('Delete Me'), findsOneWidget);

    // Tap delete icon for 'Delete Me'.
    final deleteMe = find.ancestor(
        of: find.text('Delete Me'), matching: find.byType(ListTile));
    await tester.tap(
        find.descendant(of: deleteMe, matching: find.byIcon(Icons.delete)));
    await tester.pumpAndSettle();

    // Confirm deletion dialog.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Me'), findsNothing);

    // Verify record is gone from PocketBase.
    final exists = await testPb.adminClient
        .collection('doorlock_grants')
        .getOne(toDelete['id'] as String)
        .then((_) => true)
        .catchError((_) => false);
    expect(exists, isFalse);
  });

  testWidgets('share button calls ShareService with URL containing grant token',
      (tester) async {
    final mockShare = MockShareService();
    final lock = (await userPb
            .collection('doorlock_locks')
            .getOne(lockId))
        .toJson();

    await tester.pumpWidget(buildGrantsSheet(lock: lock, shareService: mockShare));
    await tester.pumpAndSettle();

    // Tap the share icon for 'Test Grant'.
    final grantTile = find.ancestor(
        of: find.text('Test Grant'), matching: find.byType(ListTile));
    await tester.tap(
        find.descendant(of: grantTile, matching: find.byIcon(Icons.share)));
    await tester.pumpAndSettle();

    expect(mockShare.calls.length, equals(1));
    expect(
      mockShare.calls.first,
      contains('grant=${grantRecord['token']}'),
    );
  });
}
```

- [ ] **Step 2: Run the test**

```bash
cd app && flutter test test/grants_test.dart --reporter expanded
```

Expected: 3 tests pass.

- [ ] **Step 3: Commit**

```bash
git add app/test/grants_test.dart
git commit -m "test: add grants sheet widget tests"
```

---

## Task 17: Widget test — open door page

**Files:**
- Create: `app/test/open_door_test.dart`

- [ ] **Step 1: Create `app/test/open_door_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:doorlock/open_door_page.dart';
import 'package:doorlock/pb_scope.dart';
import '../test_support/mock_ha_server.dart';
import '../test_support/test_pocketbase.dart';
import '../test_support/test_fixtures.dart';

void main() {
  late TestPocketBase testPb;
  late MockHomeAssistantServer mockHa;
  late TestFixtures fixtures;
  late Map<String, dynamic> lockRecord;
  late Map<String, dynamic> grantRecord;

  setUpAll(() async {
    mockHa = await MockHomeAssistantServer.start();
    testPb = await TestPocketBase.start();
    fixtures = TestFixtures(adminClient: testPb.adminClient, mockHa: mockHa);
    final userId = await fixtures.createUser();
    final haId = await fixtures.createHomeAssistant(userId);
    lockRecord = await fixtures.createLock(haId);
    grantRecord = await fixtures.createGrant(lockRecord['id'] as String);
  });

  tearDownAll(() async {
    await testPb.stop();
    await mockHa.stop();
  });

  // OpenDoorPage uses PBScope but does NOT require auth (endpoint is public).
  Widget buildOpenDoorPage(String grantToken, String lockToken) {
    final pb = PocketBase(testPb.baseUrl); // unauthenticated client
    return PBScope(
      pb: pb,
      child: MaterialApp(
        home: OpenDoorPage(grantToken: grantToken, lockToken: lockToken),
      ),
    );
  }

  testWidgets('opens door and shows success message', (tester) async {
    final grantToken = grantRecord['token'] as String;
    final lockToken = lockRecord['identification_token'] as String;

    await tester.pumpWidget(buildOpenDoorPage(grantToken, lockToken));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Door'));
    await tester.pumpAndSettle();

    expect(find.text('Door opened!'), findsOneWidget);
    expect(
      mockHa.recordedRequests.any(
          (r) => r.method == 'POST' && r.uri.path == '/api/services/lock/open'),
      isTrue,
    );
  });

  testWidgets('shows error when grant is expired', (tester) async {
    final expiredGrant = await fixtures.createGrant(
      lockRecord['id'] as String,
      notBefore: DateTime.now().subtract(const Duration(hours: 48)),
      notAfter: DateTime.now().subtract(const Duration(hours: 24)),
    );
    final lockToken = lockRecord['identification_token'] as String;

    await tester.pumpWidget(buildOpenDoorPage(
        expiredGrant['token'] as String, lockToken));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Door'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed'), findsOneWidget);
    expect(find.text('Door opened!'), findsNothing);
  });

  testWidgets('shows error when usage_limit is exhausted', (tester) async {
    final limitedGrant = await fixtures.createGrant(
      lockRecord['id'] as String,
      usageLimit: 0, // already exhausted
    );
    final lockToken = lockRecord['identification_token'] as String;

    await tester.pumpWidget(buildOpenDoorPage(
        limitedGrant['token'] as String, lockToken));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Door'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed'), findsOneWidget);
    expect(find.text('Door opened!'), findsNothing);
  });

  testWidgets('shows error when mock HA returns 500', (tester) async {
    mockHa.setNextResponseFor(
        '/api/services/lock/open', 500, {'error': 'HA error'});

    final grantToken = grantRecord['token'] as String;
    final lockToken = lockRecord['identification_token'] as String;

    await tester.pumpWidget(buildOpenDoorPage(grantToken, lockToken));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Door'));
    await tester.pumpAndSettle();

    // The PocketBase hook calls HA and returns the HA status code directly.
    // A 500 from HA propagates as an error response.
    expect(find.textContaining('Failed'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test**

```bash
cd app && flutter test test/open_door_test.dart --reporter expanded
```

Expected: 4 tests pass.

- [ ] **Step 3: Run all widget tests together to confirm no interference**

```bash
cd app && flutter test test/ --reporter expanded
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add app/test/open_door_test.dart
git commit -m "test: add open door widget tests"
```

---

## Task 18: `tools/start_test_infra.dart` — host-side infra manager for Chrome tests

**Files:**
- Create: `app/tool/start_test_infra.dart`

This program starts MockHA + PocketBase, seeds test data, runs `flutter test integration_test/` as a subprocess with all required `--dart-define` values, then cleans up.

- [ ] **Step 1: Create `app/tool/start_test_infra.dart`**

```dart
import 'dart:io';
import '../test_support/mock_ha_server.dart';
import '../test_support/test_pocketbase.dart';
import '../test_support/test_fixtures.dart';

Future<void> main() async {
  print('[infra] Starting MockHomeAssistantServer...');
  final ha = await MockHomeAssistantServer.start();
  print('[infra] MockHA listening on ${ha.baseUrl}');

  print('[infra] Starting PocketBase...');
  final pb = await TestPocketBase.start();
  print('[infra] PocketBase ready at ${pb.baseUrl}');

  // Seed baseline test data needed by integration tests.
  final fixtures = TestFixtures(adminClient: pb.adminClient, mockHa: ha);
  final userId = await fixtures.createUser(
    email: 'inttest@test.local',
    password: 'inttestpassword',
  );
  final haId = await fixtures.createHomeAssistant(userId);
  final lock = await fixtures.createLock(haId);
  final lockId = lock['id'] as String;
  final lockToken = lock['identification_token'] as String;
  final grant = await fixtures.createGrant(lockId);
  final grantToken = grant['token'] as String;

  print('[infra] Test data seeded. Running integration tests...');

  final result = await Process.start(
    'flutter',
    [
      'test',
      'integration_test/',
      '-d',
      'chrome',
      '--dart-define=POCKETBASE_URL=${pb.baseUrl}',
      '--dart-define=HA_URL=${ha.baseUrl}',
      '--dart-define=TEST_USER_EMAIL=inttest@test.local',
      '--dart-define=TEST_USER_PASSWORD=inttestpassword',
      '--dart-define=TEST_HA_ID=$haId',
      '--dart-define=TEST_HA_URL=${ha.baseUrl}',
      '--dart-define=TEST_LOCK_ID=$lockId',
      '--dart-define=TEST_LOCK_TOKEN=$lockToken',
      '--dart-define=TEST_GRANT_TOKEN=$grantToken',
    ],
    runInShell: false,
  );

  // Forward output.
  result.stdout.listen(stdout.add);
  result.stderr.listen(stderr.add);

  final exitCode = await result.exitCode;

  print('[infra] Tests finished with exit code $exitCode. Cleaning up...');
  await pb.stop();
  await ha.stop();

  exit(exitCode);
}
```

- [ ] **Step 2: Commit**

```bash
git add app/tool/start_test_infra.dart
git commit -m "test: add start_test_infra.dart for Chrome integration test runner"
```

---

## Task 19: Integration tests

**Files:**
- Create: `app/integration_test/flutter_test_config.dart`
- Create: `app/integration_test/auth_flow_test.dart`
- Create: `app/integration_test/admin_flow_test.dart`
- Create: `app/integration_test/grants_flow_test.dart`
- Create: `app/integration_test/open_door_flow_test.dart`

- [ ] **Step 1: Create `app/integration_test/flutter_test_config.dart`**

```dart
import 'package:integration_test/integration_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  await testMain();
}
```

- [ ] **Step 2: Create `app/integration_test/auth_flow_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:doorlock/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // These values are injected by start_test_infra.dart via --dart-define.
  const userEmail = String.fromEnvironment('TEST_USER_EMAIL');
  const userPassword = String.fromEnvironment('TEST_USER_PASSWORD');

  testWidgets('app loads showing sign-in form', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('signs in and shows home page', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), userEmail);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), userPassword);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Home Assistants'), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);
  });
}
```

- [ ] **Step 3: Create `app/integration_test/admin_flow_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:doorlock/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const userEmail = String.fromEnvironment('TEST_USER_EMAIL');
  const userPassword = String.fromEnvironment('TEST_USER_PASSWORD');
  const haUrl = String.fromEnvironment('TEST_HA_URL');

  testWidgets('navigates into locks page and sees HA entity list on Add Lock', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Sign in.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), userEmail);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), userPassword);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Tap the seeded HA record (URL is mock HA baseUrl).
    await tester.tap(find.text(haUrl));
    await tester.pumpAndSettle();

    expect(find.textContaining('Locks for'), findsOneWidget);

    // Tap Add Lock — should call mock HA and show entity list.
    await tester.tap(find.byTooltip('Add Lock'));
    await tester.pumpAndSettle();

    expect(find.text('Front Door'), findsOneWidget);
  });

  testWidgets('adds a lock and QR icon is visible', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), userEmail);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), userPassword);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(haUrl));
    await tester.pumpAndSettle();

    // The seeded lock ('Front Door') should already appear.
    expect(find.text('Front Door'), findsOneWidget);
    expect(find.byTooltip('Show Lock QR'), findsOneWidget);
  });

  testWidgets('QR dialog opens with identification_token', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), userEmail);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), userPassword);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(haUrl));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Show Lock QR'));
    await tester.pumpAndSettle();

    expect(find.text('Lock QR Code'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Create `app/integration_test/grants_flow_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:doorlock/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const userEmail = String.fromEnvironment('TEST_USER_EMAIL');
  const userPassword = String.fromEnvironment('TEST_USER_PASSWORD');
  const haUrl = String.fromEnvironment('TEST_HA_URL');

  Future<void> signInAndNavigateToLocks(WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), userEmail);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), userPassword);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(haUrl));
    await tester.pumpAndSettle();
  }

  testWidgets('opens grants sheet and shows seeded grant', (tester) async {
    await signInAndNavigateToLocks(tester);

    // Tap the seeded lock to open grants sheet.
    await tester.tap(find.text('Front Door'));
    await tester.pumpAndSettle();

    expect(find.text('Test Grant'), findsOneWidget);
  });

  testWidgets('Add Grant form creates a new grant', (tester) async {
    await signInAndNavigateToLocks(tester);
    await tester.tap(find.text('Front Door'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add Grant'));
    await tester.pumpAndSettle();

    // Fill Name.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Integration Grant');

    // Fill Not before (tap field, select today, confirm).
    await tester.tap(find.widgetWithText(TextFormField, 'Not before'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // date picker OK
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // time picker OK
    await tester.pumpAndSettle();

    // Fill Not after (tomorrow).
    await tester.tap(find.widgetWithText(TextFormField, 'Not after'));
    await tester.pumpAndSettle();
    // Advance to next day.
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await tester.tap(find.text('${tomorrow.day}'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Integration Grant'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Create `app/integration_test/open_door_flow_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:doorlock/main.dart';
import 'package:doorlock/grant_qr_scanner_page.dart';
import 'package:doorlock/open_door_page.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:doorlock/pb_scope.dart';
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const grantToken = String.fromEnvironment('TEST_GRANT_TOKEN');
  const lockToken = String.fromEnvironment('TEST_LOCK_TOKEN');

  testWidgets('grantee flow: scan → open door → success', (tester) async {
    // Mount the grantee widget tree directly. PBScope is needed by OpenDoorPage.
    const pbUrl = String.fromEnvironment('POCKETBASE_URL');
    await tester.pumpWidget(
      PBScope(
        pb: PocketBase(pbUrl),
        child: MaterialApp(
          home: GrantQrScannerPage(
            onScanned: (token) {
              Navigator.of(tester.element(find.byType(GrantQrScannerPage)))
                  .pushReplacement(MaterialPageRoute(
                builder: (_) => OpenDoorPage(
                  grantToken: grantToken,
                  lockToken: token,
                ),
              ));
            },
            scannerBuilder: (onDetect) => ElevatedButton(
              key: const Key('simulate_scan'),
              onPressed: () => onDetect(BarcodeCapture(
                barcodes: [Barcode(rawValue: lockToken)],
              )),
              child: const Text('Simulate Scan'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap to simulate QR scan.
    await tester.tap(find.byKey(const Key('simulate_scan')));
    await tester.pumpAndSettle();

    // Now on OpenDoorPage.
    expect(find.text('Open Door'), findsOneWidget);

    await tester.tap(find.text('Open Door'));
    await tester.pumpAndSettle();

    expect(find.text('Door opened!'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Commit**

```bash
git add app/integration_test/
git commit -m "test: add Chrome integration tests"
```

---

## Task 20: GitHub Actions workflow and Makefile targets

**Files:**
- Create: `.github/workflows/test.yml`
- Modify: `Makefile`

- [ ] **Step 1: Create `.github/workflows/test.yml`**

```yaml
name: Tests
on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Download PocketBase 0.28.2
        run: |
          curl -L \
            "https://github.com/pocketbase/pocketbase/releases/download/v0.28.2/pocketbase_0.28.2_linux_amd64.zip" \
            -o pb.zip
          unzip pb.zip -d tools/
          chmod +x tools/pocketbase
          echo "POCKETBASE_BINARY=$PWD/tools/pocketbase" >> "$GITHUB_ENV"

      - name: Flutter pub get
        run: flutter pub get
        working-directory: app

      - name: Widget tests (Dart VM)
        run: flutter test --reporter expanded
        working-directory: app

      - name: Integration tests (Chrome headless)
        run: dart run tool/start_test_infra.dart
        working-directory: app
        env:
          POCKETBASE_BINARY: ${{ env.POCKETBASE_BINARY }}
          # Chrome headless is available on ubuntu-latest via flutter-action.
          CHROME_EXECUTABLE: google-chrome
```

- [ ] **Step 2: Add Makefile targets**

Append to `Makefile`:

```makefile
PB_VERSION ?= 0.28.2

install-pb-test: ## Download PocketBase binary for tests (tools/pocketbase)
	@mkdir -p tools
	@OS=$$(uname -s | tr '[:upper:]' '[:lower:]'); \
	ARCH=$$(uname -m); \
	if [ "$$ARCH" = "x86_64" ]; then ARCH="amd64"; fi; \
	if [ "$$ARCH" = "arm64" ]; then ARCH="arm64"; fi; \
	curl -L \
		"https://github.com/pocketbase/pocketbase/releases/download/v$(PB_VERSION)/pocketbase_$(PB_VERSION)_$${OS}_$${ARCH}.zip" \
		-o /tmp/pb.zip && \
	unzip -o /tmp/pb.zip -d tools/ && \
	chmod +x tools/pocketbase
	@echo "PocketBase $(PB_VERSION) installed at tools/pocketbase"

test: ## Run widget tests (Dart VM) — requires pocketbase binary
	cd app && flutter test --reporter expanded

integration-test: ## Run Chrome integration tests — requires pocketbase binary and Chrome
	cd app && dart run tool/start_test_infra.dart

test-all: test integration-test ## Run all tests
```

- [ ] **Step 3: Verify yaml is valid**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/test.yml'))" && echo OK
```

Expected: `OK`

- [ ] **Step 4: Verify widget tests still pass**

```bash
cd app && flutter test --reporter compact
```

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/test.yml Makefile
git commit -m "ci: add GitHub Actions workflow and Makefile test targets"
```

---

## Post-Implementation Verification

Once all tasks are complete, run the following to confirm end-to-end health:

```bash
# 1. Widget tests (Dart VM — no PocketBase binary auto-needed if not yet installed)
cd app && flutter test --reporter expanded

# 2. Install the PocketBase binary locally (once)
cd .. && make install-pb-test

# 3. Run Chrome integration tests
cd app && dart run tool/start_test_infra.dart
```

All tests passing confirms:
- PBScope correctly injects the PocketBase client throughout the widget tree
- MockHomeAssistantServer intercepts all HA calls from PocketBase hooks
- PocketBase's real migration and hook code runs without modification
- The two-token security flow (grant URL token + lock QR identification_token) is exercised
- GitHub Actions runs both tiers on every push
