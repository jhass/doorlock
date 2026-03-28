# Integration Test Suite Design

**Date:** 2026-03-28
**Scope:** Flutter app (`app/`) — widget tests + browser integration tests
**Constraint:** PocketBase server code (`pb_hooks/`, `pb_migrations/`) must not be modified for testing. Home Assistant is replaced by a mock HTTP server. PocketBase runs as a real process against that mock.

---

## 1. Goals

- Provide automated test coverage for both the admin flow (sign-in, HA management, lock management, grant management) and the grantee flow (open-door sequence) without requiring a real Home Assistant instance.
- Tests must be runnable in GitHub Actions with no external services.
- Widget tests run in the Dart VM (fast, no browser required). Integration tests run in Chrome (exercises JS interop and routing).

---

## 2. Architecture

```
Widget tests (Dart VM, app/test/)
  └─ real PocketBase process  ──→  MockHomeAssistantServer (dart:io, localhost:0)
  └─ mocked platform abstractions (WindowService, ShareService, BarcodeScannerBuilder)

Integration tests (Chrome, app/integration_test/)
  └─ real PocketBase process  ──→  MockHomeAssistantServer (dart:io, localhost:0)
  └─ real browser JS interop; platform abstractions injectable via test entry point
```

PocketBase is started with its real `pb_hooks/` and `pb_migrations/` so all custom routes and business logic run exactly as in production. The only difference is its `hooksDir` and `migrationsDir` point at the working-tree paths and its `dataDir` is a fresh temp directory.

---

## 3. Flutter Refactoring for Testability

Four minimal changes are made to the app code. No business logic changes.

### 3.1 `PBScope` — replace `PB.instance` singleton

**New file:** `lib/pb_scope.dart`

```dart
class PBScope extends InheritedWidget {
  final PocketBase pb;
  // ...
  static PocketBase of(BuildContext context) { ... }
}
```

- `main.dart` wraps the widget tree in `PBScope(pb: PocketBase(EnvConfig.pocketBaseUrl), child: ...)`.
- Every widget that currently reads `PB.instance` is updated to `PBScope.of(context)`.
- The `PB` class and its static singleton are deleted.
- Tests mount any widget inside `PBScope(pb: testPbClient, child: ...)`.

### 3.2 `WindowService` — isolate `dart:js_util`

**New files:** `lib/services/window_service.dart`

```dart
abstract class WindowService {
  void openHtmlContent(String html);
}

class WebWindowService implements WindowService { ... } // dart:js_util, web only
class NoOpWindowService implements WindowService { ... } // test/non-web
```

- `LocksPage` gains an optional `windowService` constructor parameter defaulting to `WebWindowService()`.
- The free function `windowOpenHtmlContent` in `locks_page.dart` is deleted and its logic moved into `WebWindowService`.

### 3.3 `ShareService` — isolate `share_plus`

**New files:** `lib/services/share_service.dart`

```dart
abstract class ShareService {
  Future<void> shareText(String text);
}

class RealShareService implements ShareService { ... } // delegates to Share.share()
class MockShareService implements ShareService { ... } // records calls for assertions
```

- `GrantsSheet` gains an optional `shareService` constructor parameter defaulting to `RealShareService()`.

### 3.4 `BarcodeScannerBuilder` — stub the camera

In `grant_qr_scanner_page.dart`:

```dart
typedef BarcodeScannerBuilder = Widget Function(void Function(BarcodeCapture) onDetect);
```

- `GrantQrScannerPage` gains an optional `scannerBuilder` parameter defaulting to `(onDetect) => MobileScanner(onDetect: onDetect)`.
- Tests pass a builder that renders a button immediately invoking `onDetect` with a controlled value.

### 3.5 `EnvConfig` — `--dart-define` override

`EnvConfig.pocketBaseUrl` checks `const String.fromEnvironment('POCKETBASE_URL')` first, before the JS interop block. This allows `flutter test integration_test/ --dart-define=POCKETBASE_URL=http://localhost:PORT` in Chrome without injecting `env.js`.

---

## 4. Test Infrastructure (`app/test_support/`)

Not a Dart package, just a set of shared helpers imported by both test tiers.

### 4.1 `MockHomeAssistantServer`

File: `app/test_support/mock_ha_server.dart`

- `dart:io` `HttpServer` bound to `localhost:0` (OS-assigned port).
- Exposes `int get port` and `String get baseUrl`.
- Handles:

| Route | Default response |
|---|---|
| `POST /auth/token` | `{"access_token":"test-token","expires_in":3600,"token_type":"Bearer","refresh_token":"test-refresh"}` |
| `GET /api/states` | configurable list of `lock.*` entity objects with `supported_features: 1` |
| `POST /api/services/lock/open` | `{}` (HTTP 200) |

- `List<HttpRequest> get recordedRequests` — all received requests in order.
- `void setNextResponseFor(String path, int statusCode, Map body)` — override response for one call.
- `Future<void> stop()` — closes the server.

### 4.2 `TestPocketBase`

File: `app/test_support/test_pocketbase.dart`

Lifecycle:

1. Resolves PocketBase binary: `Platform.environment['POCKETBASE_BINARY']` → `pocketbase` on `$PATH`.
2. Creates a temp directory (`<tempDir>`). Within it, creates `pb_data/` and symlinks `pb_hooks/` and `pb_migrations/` to the real repo directories (resolved relative to this file's location via `Platform.script`).
3. Finds a free port.
4. Runs `pocketbase superuser create admin@test.local testpassword --dir <tempDir>` to seed the superuser before first start (PocketBase initialises `pb_data` on first run).
5. Starts `pocketbase serve --http=localhost:<port> --dev --dir <tempDir>`. PocketBase uses `<tempDir>/pb_hooks` and `<tempDir>/pb_migrations` automatically because they live inside `--dir`.
6. Polls `GET /api/health` until HTTP 200 (timeout 15s).
7. Returns a `PocketBase` SDK client authenticated as superuser via `authWithPassword`.

Public API:
- `static Future<TestPocketBase> start()` — async factory.
- `String get baseUrl` — `http://localhost:<port>`.
- `PocketBase get adminClient` — authenticated superuser client.
- `Future<void> stop()` — kills process, deletes temp dir.

### 4.3 `TestFixtures`

File: `app/test_support/test_fixtures.dart`

Takes `PocketBase adminClient` and `MockHomeAssistantServer mockHa`. Provides:

- `Future<String> createUser({String username, String password})` → user record ID. Creates in `doorlock_users` collection.
- `Future<PocketBase> userClient(String username, String password)` → SDK client authenticated as that user.
- `Future<String> createHomeAssistant(String userId)` → HA record ID pointing at `mockHa.baseUrl`, with `access_token = "test-token"` and `access_token_expires_at` set 1 hour in the future.
- `Future<String> createLock(String haId)` → lock record ID with a known `identification_token`.
- `Future<String> createGrant(String lockId, {DateTime? notBefore, DateTime? notAfter, int usageLimit = -1})` → grant record ID.

---

## 5. Test Cases

### 5.1 Widget Tests (`app/test/`)

All test files use `setUpAll` / `tearDownAll` to start/stop `TestPocketBase` and `MockHomeAssistantServer`. Widgets are mounted with `pumpWidget(PBScope(pb: userClient, child: widget))`.

**`sign_in_test.dart`**
- Valid credentials → `AuthGate` transitions to home page (HA list visible)
- Wrong password → error message displayed
- Saved session token → `AuthGate` skips sign-in form and shows home page directly

**`home_assistants_test.dart`**
- Seeded HA record appears in `HomeAssistantsPage` list
- Tapping HA record navigates to `LocksPage`

**`locks_test.dart`**
- Seeded lock appears in `LocksPage` list
- Tapping "Add Lock" icon calls `MockHaServer GET /api/states`; returns entity list; entity name shown
- Tapping an entity creates a `doorlock_locks` record (verified via admin client) and re-lists
- Tapping QR icon opens dialog containing lock's `identification_token`

**`grants_test.dart`**
- Seeded grant appears in `GrantsSheet`
- Creating a grant with name + `not_after` + `usage_limit = 2` → record appears, verified via admin client
- Deleting a grant → disappears from list, verified via admin client
- Tapping share on a grant calls `MockShareService.shareText` with a URL containing `?grant=<token>`

**`open_door_test.dart`**
- Valid grant token + matching lock token → tapping "Open Door" calls `MockHaServer POST /api/services/lock/open` with correct `entity_id`; "Door opened!" text shown
- Grant with `not_after` in the past → PocketBase hook rejects → error message shown
- Grant with `usage_limit = 1` already used → hook rejects → error message shown
- `MockHaServer` returns 500 for `/api/services/lock/open` → error message shown

### 5.2 Integration Tests (`app/integration_test/`)

**Important:** integration tests run inside Chrome, where `dart:io` is unavailable. Infrastructure cannot be started from within the tests. Instead, a host-side Dart program `tools/start_test_infra.dart` starts `MockHomeAssistantServer` and `TestPocketBase` on OS-assigned ports, writes port info to a file (`tools/.test_ports`, gitignored), and keeps running until terminated. The Makefile / CI script reads those ports and passes `--dart-define=POCKETBASE_URL=http://localhost:<pbPort>` when invoking `flutter test -d chrome`.

`flutter_test_config.dart` in `integration_test/` is used only for test-level setup that does not require `dart:io` (e.g. binding `IntegrationTestWidgetsFlutterBinding`).

**`auth_flow_test.dart`**
- App loads → sign-in form shown
- Fill username/password, tap "Sign in" → HA list page shown
- Simulate reload (`flutter_driver` or `integration_test` navigation reset) → session restored, HA list shown without sign-in form

**`admin_flow_test.dart`**
- Sign in → tap HA record → `LocksPage` shown
- Tap "Add Lock" icon → entity list shown (sourced from mock HA)
- Tap entity → lock appears in list
- Tap QR icon → QR dialog visible with `identification_token` content

**`grants_flow_test.dart`**
- Navigate to locks → tap lock → grants sheet opens
- Tap "Add Grant", fill name and `not_after`, submit → grant appears in list
- Tap share → `MockShareService` records call with correct URL

**`open_door_flow_test.dart`**
- Navigate to `/?grant=<token>` → scanner page shown
- Scanner stub immediately fires with lock's `identification_token` → `OpenDoorPage` shown
- Tap "Open Door" → "Door opened!" visible → `MockHaServer` recorded the request

---

## 6. GitHub Actions Workflow

File: `.github/workflows/test.yml`

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - name: Download PocketBase
        run: |
          PB_VERSION=0.28.2
          curl -L "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip" -o pb.zip
          unzip pb.zip -d tools/
          chmod +x tools/pocketbase
          echo "POCKETBASE_BINARY=$PWD/tools/pocketbase" >> $GITHUB_ENV
      - name: Flutter pub get
        run: flutter pub get
        working-directory: app
      - name: Widget tests (Dart VM)
        run: flutter test
        working-directory: app
      - name: Start test infra (Chrome integration tests)
        run: |
          dart run tools/start_test_infra.dart &
          echo $! > .test-infra.pid
          # Poll until the port file is written (max 15s)
          for i in $(seq 1 30); do
            [ -f tools/.test_ports ] && break
            sleep 0.5
          done
          cat tools/.test_ports >> $GITHUB_ENV
        working-directory: app
      - name: Integration tests (Chrome)
        run: |
          flutter test integration_test/ \
            -d chrome \
            --dart-define=POCKETBASE_URL=$PB_URL
        working-directory: app
      - name: Stop test infra
        if: always()
        run: kill $(cat app/.test-infra.pid) || true
```

`tools/start_test_infra.dart` starts `MockHomeAssistantServer` and `TestPocketBase`, then writes:
```
PB_URL=http://localhost:18432
HA_URL=http://localhost:19877
```
to `tools/.test_ports` before blocking on `stdin` (so it keeps running until the CI step kills its PID).

### Local development

Three targets are added to `Makefile`:
```makefile
install-pb-test: ## Download PocketBase binary for tests
    # downloads pocketbase 0.28.2 (matching Dockerfile.dev) to tools/pocketbase

test: ## Run widget tests (Dart VM)
    cd app && flutter test

integration-test: ## Run integration tests (Chrome, requires install-pb-test)
    # starts tools/start_test_infra.dart in background
    # reads PB_URL from tools/.test_ports
    # runs flutter test integration_test/ -d chrome --dart-define=POCKETBASE_URL=$$PB_URL
    # stops background infra process
```

`tools/pocketbase` and `tools/.test_ports` are added to `.gitignore`.

---

## 7. File Layout After Implementation

```
app/
  lib/
    pb_scope.dart                    # NEW: InheritedWidget replacing PB.instance
    services/
      window_service.dart            # NEW: WindowService abstraction
      share_service.dart             # NEW: ShareService abstraction
    env_config.dart                  # MODIFIED: --dart-define override
    locks_page.dart                  # MODIFIED: windowService param, PBScope
    grants_sheet.dart                # MODIFIED: shareService param, PBScope
    grant_qr_scanner_page.dart       # MODIFIED: scannerBuilder param
    home_assistants_page.dart        # MODIFIED: PBScope
    main.dart                        # MODIFIED: PBScope wrap, PB singleton removed
    # pb.dart deleted
  test_support/
    mock_ha_server.dart              # NEW
    test_pocketbase.dart             # NEW
    test_fixtures.dart               # NEW
  test/
    sign_in_test.dart                # NEW
    home_assistants_test.dart        # NEW
    locks_test.dart                  # NEW
    grants_test.dart                 # NEW
    open_door_test.dart              # NEW
  integration_test/
    flutter_test_config.dart         # NEW: IntegrationTestWidgetsFlutterBinding setup only
    auth_flow_test.dart              # NEW
    admin_flow_test.dart             # NEW
    grants_flow_test.dart            # NEW
    open_door_flow_test.dart         # NEW
.github/
  workflows/
    test.yml                         # NEW
tools/
  .gitkeep                           # NEW: dir placeholder (pocketbase binary and .test_ports are gitignored)
  start_test_infra.dart              # NEW: host-side program that starts MockHA + PocketBase for Chrome tests
  pocketbase                         # gitignored, downloaded locally/CI
  .test_ports                        # gitignored, written by start_test_infra.dart
```

---

## 8. Dependencies to Add (`app/pubspec.yaml`)

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter        # already present
  # No new pub packages needed; dart:io covers the mock server
```
