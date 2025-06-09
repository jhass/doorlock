import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class GrantQrScannerPage extends StatefulWidget {
  final void Function(String) onScanned;
  const GrantQrScannerPage({super.key, required this.onScanned});

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
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Lock QR Code')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          if (_scanned)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
