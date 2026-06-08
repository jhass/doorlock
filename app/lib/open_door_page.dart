import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'pb_scope.dart';

class OpenDoorPage extends StatefulWidget {
  final String grantToken;
  final String lockToken;
  const OpenDoorPage({super.key, required this.grantToken, required this.lockToken});

  @override
  State<OpenDoorPage> createState() => _OpenDoorPageState();
}

class _OpenDoorPageState extends State<OpenDoorPage> {
  bool _loading = false;
  String? _result;
  String? _error;
  RecordModel? lock;
  PocketBase? pb;

  @override
  void initState() {
    super.initState();
    pb = PBScope.of(context);
    _fetchLock();
  }

  Future<void> _fetchLock() async {
    setState(() { _loading = true; _error = null; });
    try {
      final locks = await pb!.collection('doorlock_locks').getList(query: {"token": widget.lockToken});

      if (locks.items.isEmpty) {
        setState(() {
          _error = 'Lock not found';
          _loading = false;
        });
        return;
      }
      lock = locks.items.first;
      setState(() { _loading = false; });
    } on ClientException catch (e) {
      if (e.statusCode == 401) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
        return;
      }
      setState(() {
        _error = 'Failed to fetch lock: ${e.response['message'] ?? e.toString()}';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openDoor() async {
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      await pb!.send(
        '/doorlock/locks/${widget.lockToken}/open',
        method: 'POST',
        body: {'token': widget.grantToken},
      );
      setState(() {
        _result = 'Door opened!';
      });
    } on ClientException catch (e) {
      setState(() {
        _error = 'Failed: ${e.response['message'] ?? e.toString()}';
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockName = lock?.get("name") ?? 'Door';
    return Scaffold(
      appBar: AppBar(title: Text(lockName)),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_result != null)
                    Text(_result!, style: const TextStyle(color: Colors.green, fontSize: 20)),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ElevatedButton(
                    onPressed: _openDoor,
                    child: Text('Open $lockName'),
                  ),
                ],
              ),
      ),
    );
  }
}
