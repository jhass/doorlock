import 'package:flutter/material.dart';

import 'locks_page.dart';

class HomeAssistantsPage extends StatelessWidget {
  final List<dynamic> assistants;
  final VoidCallback onSignOut;
  final VoidCallback onAdd;
  const HomeAssistantsPage({super.key, required this.assistants, required this.onSignOut, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Assistants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: onSignOut,
            tooltip: 'Sign Out',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: onAdd,
            tooltip: 'Add Home Assistant',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: assistants.length,
        itemBuilder: (context, index) {
          final item = assistants[index];
          return ListTile(
            title: Text(item['url']),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LocksPage(homeAssistantId: item['id'], homeAssistantUrl: item['url']),
              ),
            ),
          );
        },
      ),
    );
  }
}
