import 'package:flutter/material.dart';
import 'package:doorlock/qr_scanner_service.dart';

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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
              size: 100,
            ),
            const SizedBox(height: 20),
            const Text(
              'Mock QR Scanner',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            if (mockQrCode != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Will scan: $mockQrCode',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}