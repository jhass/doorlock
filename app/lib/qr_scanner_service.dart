import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Interface for QR scanning functionality to enable testing
abstract class QrScannerService {
  Widget buildQrScanner({required void Function(String) onScanned});
}

/// Real QR scanner implementation using mobile_scanner
class RealQrScannerService implements QrScannerService {
  @override
  Widget buildQrScanner({required void Function(String) onScanned}) {
    bool scanned = false;
    
    void onDetect(BarcodeCapture capture) {
      if (scanned) return;
      final code = capture.barcodes.firstOrNull?.rawValue;
      if (code != null && code.isNotEmpty) {
        scanned = true;
        onScanned(code);
      }
    }

    return Stack(
      children: [
        MobileScanner(onDetect: onDetect),
        if (scanned) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}