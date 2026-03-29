import 'package:flutter/material.dart';

class InvalidLinkPage extends StatelessWidget {
  const InvalidLinkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This link is invalid or has been corrupted.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
