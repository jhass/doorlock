import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Builds the actual scanner widget. Swap in tests with a stub that calls
/// [onDetect] programmatically.
typedef BarcodeScannerBuilder = Widget Function(
  void Function(BarcodeCapture) onDetect,
);

class GrantQrScannerPage extends StatefulWidget {
  final void Function(String) onScanned;

  /// Optional: override the scanner widget. Defaults to [MobileScanner].
  /// In tests, pass a builder that triggers [onDetect] with fake values.
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
    final scanner =
        widget.scannerBuilder ??
        (onDetect) => MobileScanner(
          onDetect: onDetect,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Lock QR Code')),
      body: Stack(
        children: [
          scanner(_onDetect),
          if (_scanned)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
