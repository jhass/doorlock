import 'package:flutter_test/flutter_test.dart';

import '../../tool/browser_tooling.dart';

void main() {
  test('extractChromeMajor parses Chrome version output', () {
    expect(extractChromeMajor('Google Chrome 147.0.7727.24'), 147);
  });

  test('extractChromeDriverMajor parses ChromeDriver version output', () {
    expect(extractChromeDriverMajor('ChromeDriver 147.0.7727.24'), 147);
  });

  test('browserCompatibilityError returns null for matching majors', () {
    expect(browserCompatibilityError(147, 147), isNull);
  });

  test('browserCompatibilityError reports mismatched majors', () {
    expect(
      browserCompatibilityError(146, 147),
      contains('Chrome major 146 does not match ChromeDriver major 147'),
    );
  });
}
