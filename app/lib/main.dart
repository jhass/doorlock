import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_home_assistant_page.dart';
import 'env_config.dart';
import 'grant_qr_scanner_page.dart';
import 'home_assistants_page.dart';
import 'open_door_page.dart';
import 'pb.dart';
import 'session_storage.dart';
import 'sign_in_page.dart';
import 'qr_scanner_service.dart';

// Global QR scanner service for dependency injection
QrScannerService? _qrScannerService;

void main() {
  // Initialize PB with environment config
  PB.initialize(EnvConfig.pocketBaseUrl);
  runApp(const MyApp());
}

/// Set QR scanner service for testing
void setQrScannerService(QrScannerService? service) {
  _qrScannerService = service;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final uri = Uri.base;
    final grantToken = uri.queryParameters['grant'];
    if (grantToken != null && grantToken.isNotEmpty) {
      return MaterialApp(
        title: 'Doorlock app',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: GrantFlow(grantToken: grantToken),
      );
    }

    return MaterialApp(
      title: 'Doorlock app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: AuthGate(
        builder: (context) => HomeAssistantsPageWrapper(),
      ),
    );
  }
}

class GrantFlow extends StatefulWidget {
  final String grantToken;
  const GrantFlow({super.key, required this.grantToken});
  @override
  State<GrantFlow> createState() => _GrantFlowState();
}

class _GrantFlowState extends State<GrantFlow> {
  String? _lockToken;

  @override
  Widget build(BuildContext context) {
    if (_lockToken == null) {
      return GrantQrScannerPage(
        onScanned: (lockToken) {
          setState(() => _lockToken = lockToken);
        },
        qrScannerService: _qrScannerService,
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
    final session = await SessionStorage.loadSession();
    if (session != null && session['token'] != null) {
      PB.instance.authStore.save(session['token'] as String, null);
    }
    setState(() { _loading = false; });
  }

  Future<void> _signIn(String username, String password) async {
    setState(() { _loading = true; _error = null; });
    try {
      await PB.instance.collection('doorlock_users').authWithPassword(username, password);
      await SessionStorage.saveSession({'token': PB.instance.authStore.token});
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!PB.instance.authStore.isValid) {
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
    setState(() { _loading = true; _error = null; });
    try {
      final result = await PB.instance.collection('doorlock_homeassistants').getFullList();
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
    setState(() { _addError = null; });
    try {
      final resp = await PB.instance.send(
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
        await SessionStorage.clearSession();
        PB.instance.authStore.clear();
        Navigator.of(context).pushReplacementNamed('/');
      },
      onAdd: _showAddPage,
    );
  }
}
