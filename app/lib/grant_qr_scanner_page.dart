import 'package:flutter/material.dart';
import 'qr_scanner_service.dart';

class GrantQrScannerPage extends StatefulWidget {
  final void Function(String) onScanned;
  final QrScannerService? qrScannerService;
  
  const GrantQrScannerPage({
    super.key, 
    required this.onScanned,
    this.qrScannerService,
  });

  @override
  State<GrantQrScannerPage> createState() => _GrantQrScannerPageState();
}

class _GrantQrScannerPageState extends State<GrantQrScannerPage> {
  bool _scanned = false;
  late final QrScannerService _qrScannerService;

  @override
  void initState() {
    super.initState();
    _qrScannerService = widget.qrScannerService ?? RealQrScannerService();
  }

  void _onScanned(String code) {
    if (_scanned) return;
    setState(() => _scanned = true);
    widget.onScanned(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Lock QR Code')),
      body: _qrScannerService.buildQrScanner(onScanned: _onScanned),
    );
  }
}
