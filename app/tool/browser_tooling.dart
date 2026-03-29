int extractChromeMajor(String versionLine) {
  final match = RegExp(r'(\d+)\.').firstMatch(versionLine);
  if (match == null) {
    throw FormatException('Unable to parse Chrome version from: $versionLine');
  }
  return int.parse(match.group(1)!);
}

int extractChromeDriverMajor(String versionLine) {
  final match = RegExp(r'(\d+)\.').firstMatch(versionLine);
  if (match == null) {
    throw FormatException(
      'Unable to parse ChromeDriver version from: $versionLine',
    );
  }
  return int.parse(match.group(1)!);
}

String? browserCompatibilityError(int chromeMajor, int chromeDriverMajor) {
  if (chromeMajor == chromeDriverMajor) {
    return null;
  }
  return 'Chrome major $chromeMajor does not match ChromeDriver major $chromeDriverMajor';
}
