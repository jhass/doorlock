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

/// Mock QR scanner implementation for testing
class MockQrScannerService implements QrScannerService {
  final String? mockQrCode;
  final Duration? mockDelay;

  MockQrScannerService({this.mockQrCode, this.mockDelay});

  @override
  Widget buildQrScanner({required void Function(String) onScanned}) {
    // Auto-trigger the scan after a delay if mockQrCode is provided
    if (mockQrCode != null) {
      Future.delayed(mockDelay ?? const Duration(milliseconds: 100), () {
        onScanned(mockQrCode!);
      });
    }

    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 80, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Mock QR Scanner\n(for testing)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}