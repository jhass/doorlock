import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_home_assistant_page.dart';
import 'env_config.dart';
import 'grant_token_encoder.dart';
import 'grant_qr_scanner_page.dart';
import 'home_assistants_page.dart';
import 'invalid_link_page.dart';
import 'open_door_page.dart';
import 'pb_scope.dart';
import 'session_storage.dart';
import 'sign_in_page.dart';

sealed class GrantRouteDecision {
  const GrantRouteDecision();
}

class NoGrantRouteDecision extends GrantRouteDecision {
  const NoGrantRouteDecision();
}

class ScanRequiredRouteDecision extends GrantRouteDecision {
  const ScanRequiredRouteDecision({required this.grantToken});

  final String grantToken;
}

class NoScanRouteDecision extends GrantRouteDecision {
  const NoScanRouteDecision({required this.grantToken, required this.lockToken});

  final String grantToken;
  final String lockToken;
}

class InvalidGrantRouteDecision extends GrantRouteDecision {
  const InvalidGrantRouteDecision();
}

const String githubRepoUrl = 'https://github.com/jhass/doorlock';
const String _buildCommit = String.fromEnvironment('BUILD_COMMIT');

String shortBuildCommit(String commit) {
  final trimmed = commit.trim();
  if (trimmed.isEmpty) return 'dev';
  return trimmed.length <= 7 ? trimmed : trimmed.substring(0, 7);
}

Future<void> _openGitHubRepo() async {
  final uri = Uri.parse(githubRepoUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Widget globalAppBuilder(BuildContext context, Widget? child) {
  return Column(
    children: [
      Expanded(child: child ?? const SizedBox.shrink()),
      const _BuildFooter(),
    ],
  );
}

class _BuildFooter extends StatelessWidget {
  const _BuildFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          TextButton(
            onPressed: () async {
              await _openGitHubRepo();
            },
            child: const Text('GitHub'),
          ),
          Text(
            'Build ${shortBuildCommit(_buildCommit)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

GrantRouteDecision resolveGrantRoute(String? encodedGrant) {
  if (encodedGrant == null) {
    return const NoGrantRouteDecision();
  }

  try {
    final payload = GrantTokenEncoder.decode(encodedGrant);
    if (payload is ScanRequiredPayload) {
      return ScanRequiredRouteDecision(grantToken: payload.grantToken);
    }
    if (payload is NoScanPayload) {
      return NoScanRouteDecision(
        grantToken: payload.grantToken,
        lockToken: payload.lockToken,
      );
    }
    return const InvalidGrantRouteDecision();
  } on FormatException {
    return const InvalidGrantRouteDecision();
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final grantRouteDecision = resolveGrantRoute(Uri.base.queryParameters['grant']);
    if (grantRouteDecision is! NoGrantRouteDecision) {
      return PBScope(
        pb: PocketBase(EnvConfig.pocketBaseUrl),
        child: MaterialApp(
          title: 'Doorlock app',
          builder: globalAppBuilder,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          home: GrantFlow(decision: grantRouteDecision),
        ),
      );
    }

    return PBScope(
      pb: PocketBase(EnvConfig.pocketBaseUrl),
      child: MaterialApp(
        title: 'Doorlock app',
        builder: globalAppBuilder,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: AuthGate(
          builder: (context) => HomeAssistantsPageWrapper(),
        ),
      ),
    );
  }
}

class GrantFlow extends StatelessWidget {
  const GrantFlow({super.key, required this.decision});

  final GrantRouteDecision decision;

  @override
  Widget build(BuildContext context) {
    if (decision is ScanRequiredRouteDecision) {
      final scanDecision = decision as ScanRequiredRouteDecision;
      return _ScanRequiredGrantFlow(grantToken: scanDecision.grantToken);
    }

    if (decision is NoScanRouteDecision) {
      final noScanDecision = decision as NoScanRouteDecision;
      return OpenDoorPage(
        grantToken: noScanDecision.grantToken,
        lockToken: noScanDecision.lockToken,
      );
    }

    return const InvalidLinkPage();
  }
}

class _ScanRequiredGrantFlow extends StatefulWidget {
  const _ScanRequiredGrantFlow({required this.grantToken});

  final String grantToken;

  @override
  State<_ScanRequiredGrantFlow> createState() => _ScanRequiredGrantFlowState();
}

class _ScanRequiredGrantFlowState extends State<_ScanRequiredGrantFlow> {
  String? _lockToken;

  @override
  Widget build(BuildContext context) {
    if (_lockToken == null) {
      return GrantQrScannerPage(
        onScanned: (lockToken) {
          setState(() => _lockToken = lockToken);
        },
      );
    }
    return OpenDoorPage(grantToken: widget.grantToken, lockToken: _lockToken!);
  }
}

class AuthGate extends StatefulWidget {
  final Widget Function(BuildContext context) builder;
  const AuthGate({super.key, required this.builder});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initAuthStore();
  }

  Future<void> _initAuthStore() async {
    final pb = PBScope.of(context);
    final session = await SessionStorage.loadSession();
    if (session != null && session['token'] != null) {
      pb.authStore.save(session['token'] as String, null);
    }
    setState(() { _loading = false; });
  }

  Future<void> _signIn(String username, String password) async {
    final pb = PBScope.of(context);
    setState(() { _loading = true; _error = null; });
    try {
      await pb.collection('doorlock_users').authWithPassword(username, password);
      await SessionStorage.saveSession({'token': pb.authStore.token});
      setState(() { _loading = false; });
    } on ClientException catch (e) {
      setState(() {
        _error = e.statusCode == 401 ? 'Session expired, please sign in again.' : 'Sign in failed';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Sign in failed';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pb = PBScope.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!pb.authStore.isValid) {
      return SignInPage(onSignIn: _signIn, error: _error);
    }
    return widget.builder(context);
  }
}

class HomeAssistantsPageWrapper extends StatefulWidget {
  const HomeAssistantsPageWrapper({super.key});

  @override
  State<HomeAssistantsPageWrapper> createState() => _HomeAssistantsPageWrapperState();
}

class _HomeAssistantsPageWrapperState extends State<HomeAssistantsPageWrapper> {
  List<dynamic> _assistants = [];
  bool _loading = true;
  String? _error;
  String? _addError;

  @override
  void initState() {
    super.initState();
    _fetchAssistants();
  }

  Future<void> _fetchAssistants() async {
    final pb = PBScope.of(context);
    setState(() { _loading = true; _error = null; });
    try {
      final result = await pb.collection('doorlock_homeassistants').getFullList();
      setState(() {
        _assistants = result.map((r) => r.toJson()).toList();
        _loading = false;
      });
    } on ClientException catch (e) {
      if (e.statusCode == 401) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
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

  Future<void> _addHomeAssistant(String url, String frontendCallback) async {
    final pb = PBScope.of(context);
    setState(() { _addError = null; });
    try {
      final resp = await pb.send(
        '/doorlock/homeassistant',
        method: 'POST',
        body: {
          'url': url,
          'frontend_callback': frontendCallback,
        },
      );
      // If auth_url is returned, redirect to it using url_launcher
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
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
        return;
      }
      setState(() { _addError = 'Failed to add: \\${e.response['message'] ?? e.toString()}'; });
    } catch (e) {
      setState(() { _addError = 'Failed to add: \\${e.toString()}'; });
    }
  }

  void _showAddPage() {
    setState(() { _addError = null; });
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AddHomeAssistantPage(
          onSubmit: _addHomeAssistant,
          error: _addError,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))));
    }
    return HomeAssistantsPage(
      assistants: _assistants,
      onSignOut: () async {
        final pb = PBScope.of(context);
        await SessionStorage.clearSession();
        pb.authStore.clear();
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      },
      onAdd: _showAddPage,
    );
  }
}
