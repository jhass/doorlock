import 'dart:convert';
import 'dart:typed_data';

sealed class GrantTokenPayload {
  const GrantTokenPayload();
}

class ScanRequiredPayload extends GrantTokenPayload {
  const ScanRequiredPayload({required this.grantToken});

  final String grantToken;
}

class NoScanPayload extends GrantTokenPayload {
  const NoScanPayload({required this.grantToken, required this.lockToken});

  final String grantToken;
  final String lockToken;
}

class GrantTokenEncoder {
  static const int _scanRequiredType = 0x01;
  static const int _noScanType = 0x02;
  static final RegExp _tokenPattern = RegExp(r'^[a-f0-9]{32}$');

  static String encodeScanRequired(String grantTokenHex) {
    final grantBytes = _hexToBytes(grantTokenHex);
    final payload = Uint8List(1 + grantBytes.length)
      ..[0] = _scanRequiredType
      ..setRange(1, 1 + grantBytes.length, grantBytes);
    return _encodeBase64UrlNoPadding(payload);
  }

  static String encodeNoScan(String grantTokenHex, String lockTokenHex) {
    final grantBytes = _hexToBytes(grantTokenHex);
    final lockBytes = _hexToBytes(lockTokenHex);
    final lockStart = 1 + grantBytes.length;
    final lockEnd = lockStart + lockBytes.length;
    final payload = Uint8List(1 + grantBytes.length + lockBytes.length)
      ..[0] = _noScanType
      ..setRange(1, 1 + grantBytes.length, grantBytes)
      ..setRange(lockStart, lockEnd, lockBytes);
    return _encodeBase64UrlNoPadding(payload);
  }

  static GrantTokenPayload decode(String encoded) {
    final bytes = _decodeBase64UrlNoPadding(encoded);
    if (bytes.isEmpty) {
      throw const FormatException('Empty payload');
    }

    switch (bytes.first) {
      case _scanRequiredType:
        if (bytes.length != 17) {
          throw const FormatException('Invalid scan-required payload length');
        }
        return ScanRequiredPayload(grantToken: _bytesToHex(bytes.sublist(1, 17)));
      case _noScanType:
        if (bytes.length != 33) {
          throw const FormatException('Invalid no-scan payload length');
        }
        return NoScanPayload(
          grantToken: _bytesToHex(bytes.sublist(1, 17)),
          lockToken: _bytesToHex(bytes.sublist(17, 33)),
        );
      default:
        throw const FormatException('Unsupported payload type');
    }
  }

  static Uint8List _hexToBytes(String hex) {
    if (!_tokenPattern.hasMatch(hex)) {
      throw const FormatException('Token must match [a-f0-9]{32}');
    }

    final output = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      output[i] = int.parse(hex.substring(i * 2, (i * 2) + 2), radix: 16);
    }
    return output;
  }

  static String _bytesToHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final value in bytes) {
      buffer.write(value.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static String _encodeBase64UrlNoPadding(Uint8List bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Uint8List _decodeBase64UrlNoPadding(String encoded) {
    final padLen = (4 - encoded.length % 4) % 4;
    final padded = encoded + ('=' * padLen);
    try {
      return Uint8List.fromList(base64Url.decode(padded));
    } catch (_) {
      throw const FormatException('Invalid base64url payload');
    }
  }
}