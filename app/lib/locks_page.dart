import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'pb.dart';
import 'grants_sheet.dart';

class LocksPage extends StatefulWidget {
  final String homeAssistantId;
  final String homeAssistantUrl;
  const LocksPage({super.key, required this.homeAssistantId, required this.homeAssistantUrl});

  @override
  State<LocksPage> createState() => _LocksPageState();
}

class _LocksPageState extends State<LocksPage> {
  final _pb = PB.instance;
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
    _fetchLocks();
  }

  Future<void> _fetchLocks() async {
    setState(() { _loading = true; _error = null; });
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
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
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
    setState(() { _addLockError = null; });
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
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
        return;
      }
      setState(() { _addLockError = 'Failed to fetch available locks: $e'; });
    } catch (e) {
      setState(() { _addLockError = 'Failed to fetch available locks: $e'; });
    }
  }

  Future<void> _addLock(Map<String, dynamic> lock) async {
    setState(() { _addLockError = null; });
    try {
      await _pb.collection('doorlock_locks').create(body: {
        'homeassistant': widget.homeAssistantId,
        'entity_id': lock['id'],
        'name': lock['name'],
      });
      setState(() { _showAddLock = false; });
      await _fetchLocks();
    } on ClientException catch (e) {
      if (e.statusCode == 401) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
        return;
      }
      setState(() { _addLockError = 'Failed to add lock: $e'; });
    } catch (e) {
      setState(() { _addLockError = 'Failed to add lock: $e'; });
    }
  }

  Future<void> _fetchGrants(String lockId) async {
    setState(() {
      _showGrants = true;
      _selectedLock = _locks.firstWhere(
        (l) => l['id'] == lockId,
        orElse: () => <String, dynamic>{}, // Return an empty map if not found
      );
    });
  }

  void _showLockQr(BuildContext context, Map<String, dynamic> lock) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Lock QR Code'),
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
                    <style>
                      @page { margin: 0; }
                      body { margin: 0; }
                    </style>
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
                final encoded = Uri.encodeComponent(qrHtml);
                windowOpenHtmlContent(encoded);
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
          ? Center(child: Text(_addLockError!, style: const TextStyle(color: Colors.red)))
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
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  itemCount: _locks.length,
                  itemBuilder: (context, index) {
                    final lock = _locks[index];
                    return ListTile(
                      title: Text(lock['name'] ?? lock['id'] ?? 'Unknown lock'),
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

// Helper for opening HTML content in a new window (Flutter web, no dart:html)
void windowOpenHtmlContent(String encodedHtml) {
  // Use JS interop to open a new window and write the HTML content (Flutter web only, no dart:html)
  // Fix: properly escape single quotes in the JS string to avoid syntax errors
  final js = "var w = window.open(); w.document.write(decodeURIComponent('" + encodedHtml.replaceAll("'", "\\'") + "')); w.document.close();";
  js_util.callMethod(js_util.globalThis, 'eval', [js]);
}
