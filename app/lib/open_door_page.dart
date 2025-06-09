import 'package:flutter/material.dart';
import 'pb.dart';
import 'package:pocketbase/pocketbase.dart';

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

  Future<void> _openDoor() async {
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      await PB.instance.send(
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
    return Scaffold(
      appBar: AppBar(title: const Text('Open Door')),
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
                    child: const Text('Open Door'),
                  ),
                ],
              ),
      ),
    );
  }
}
