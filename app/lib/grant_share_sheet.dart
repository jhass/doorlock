import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'grant_token_encoder.dart';
import 'services/share_service.dart';

class GrantShareSheet extends StatelessWidget {
  const GrantShareSheet({
    super.key,
    required this.shareService,
    required this.grantToken,
    required this.lockToken,
  });

  final ShareService shareService;
  final String grantToken;
  final String lockToken;

  String _scanRequiredLink() {
    final encoded = GrantTokenEncoder.encodeScanRequired(grantToken);
    return Uri.base.replace(queryParameters: {'grant': encoded}).toString();
  }

  String _noScanLink() {
    final encoded = GrantTokenEncoder.encodeNoScan(grantToken, lockToken);
    return Uri.base.replace(queryParameters: {'grant': encoded}).toString();
  }

  Future<void> _copy(BuildContext context, String deeplink) async {
    await Clipboard.setData(ClipboardData(text: deeplink));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deeplink copied to clipboard')),
    );
  }

  Future<void> _shareWithFallback(BuildContext context, String deeplink) async {
    try {
      await shareService.shareText(deeplink);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      await _copy(context, deeplink);
    }
  }

  Widget _optionCard({
    required BuildContext context,
    required String title,
    required String description,
    required String deeplink,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async => _copy(context, deeplink),
                  child: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async => _shareWithFallback(context, deeplink),
                  child: const Text('Share'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanRequiredLink = _scanRequiredLink();
    final noScanLink = _noScanLink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share Grant', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _optionCard(
              context: context,
              title: 'Requires QR scan at the door',
              description: 'The recipient must physically scan the QR code on the lock.',
              deeplink: scanRequiredLink,
            ),
            _optionCard(
              context: context,
              title: 'No scan required (remote open)',
              description: 'The recipient can open the door from anywhere. Only share with trusted people.',
              deeplink: noScanLink,
            ),
          ],
        ),
      ),
    );
  }
}
