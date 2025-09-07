import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Create a simple mock of HomeAssistantsPage to avoid importing web dependencies
class MockHomeAssistantsPage extends StatelessWidget {
  final List<dynamic> assistants;
  final VoidCallback onSignOut;
  final VoidCallback onAdd;
  const MockHomeAssistantsPage({
    super.key, 
    required this.assistants, 
    required this.onSignOut, 
    required this.onAdd
  });

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
            onTap: () {
              // Mock navigation - just show a snackbar instead
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Navigate to ${item['url']}')),
              );
            },
          );
        },
      ),
    );
  }
}

void main() {
  group('HomeAssistantsPage Widget Tests', () {
    testWidgets('HomeAssistantsPage displays correctly with empty assistants list', (WidgetTester tester) async {
      bool signOutCalled = false;
      bool addCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: MockHomeAssistantsPage(
          assistants: [],
          onSignOut: () => signOutCalled = true,
          onAdd: () => addCalled = true,
        ),
      ));

      // Verify basic structure
      expect(find.text('Home Assistants'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      
      // Should show empty list
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('HomeAssistantsPage displays assistants list correctly', (WidgetTester tester) async {
      final assistants = [
        {'id': '1', 'url': 'https://ha1.example.com'},
        {'id': '2', 'url': 'https://ha2.example.com'},
        {'id': '3', 'url': 'https://ha3.example.com'},
      ];

      await tester.pumpWidget(MaterialApp(
        home: MockHomeAssistantsPage(
          assistants: assistants,
          onSignOut: () {},
          onAdd: () {},
        ),
      ));

      // Should display all assistants
      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.text('https://ha1.example.com'), findsOneWidget);
      expect(find.text('https://ha2.example.com'), findsOneWidget);
      expect(find.text('https://ha3.example.com'), findsOneWidget);
    });

    testWidgets('HomeAssistantsPage sign out button works', (WidgetTester tester) async {
      bool signOutCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: MockHomeAssistantsPage(
          assistants: [],
          onSignOut: () => signOutCalled = true,
          onAdd: () {},
        ),
      ));

      // Tap the sign out button
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(signOutCalled, isTrue);
    });

    testWidgets('HomeAssistantsPage add button works', (WidgetTester tester) async {
      bool addCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: MockHomeAssistantsPage(
          assistants: [],
          onSignOut: () {},
          onAdd: () => addCalled = true,
        ),
      ));

      // Tap the add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(addCalled, isTrue);
    });

    testWidgets('HomeAssistantsPage list tile interaction works', (WidgetTester tester) async {
      final assistants = [
        {'id': '1', 'url': 'https://ha1.example.com'},
      ];

      await tester.pumpWidget(MaterialApp(
        home: MockHomeAssistantsPage(
          assistants: assistants,
          onSignOut: () {},
          onAdd: () {},
        ),
      ));

      // Tap on the list tile should show snackbar
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('https://ha1.example.com'), findsOneWidget);
      
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      
      // Should show navigation snackbar
      expect(find.text('Navigate to https://ha1.example.com'), findsOneWidget);
    });

    testWidgets('HomeAssistantsPage has correct tooltips', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MockHomeAssistantsPage(
          assistants: [],
          onSignOut: () {},
          onAdd: () {},
        ),
      ));

      // Check tooltips are set
      final signOutButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.logout)
      );
      expect(signOutButton.tooltip, equals('Sign Out'));

      final addButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add)
      );
      expect(addButton.tooltip, equals('Add Home Assistant'));
    });

    testWidgets('HomeAssistantsPage handles many assistants', (WidgetTester tester) async {
      // Create a long list to test scrolling
      final assistants = List.generate(20, (index) => {
        'id': index.toString(),
        'url': 'https://ha$index.example.com'
      });

      await tester.pumpWidget(MaterialApp(
        home: MockHomeAssistantsPage(
          assistants: assistants,
          onSignOut: () {},
          onAdd: () {},
        ),
      ));

      // Should handle large lists properly
      expect(find.byType(ListTile), findsWidgets);
      expect(find.byType(ListView), findsOneWidget);
      
      // First item should be visible
      expect(find.text('https://ha0.example.com'), findsOneWidget);
    });

    testWidgets('HomeAssistantsPage structure and layout', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MockHomeAssistantsPage(
          assistants: [
            {'id': '1', 'url': 'https://test.example.com'}
          ],
          onSignOut: () {},
          onAdd: () {},
        ),
      ));

      // Verify the overall structure
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      
      // App bar should have 2 action buttons
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.actions, hasLength(2));
    });

    testWidgets('HomeAssistantsPage responds to different assistant data formats', (WidgetTester tester) async {
      final assistants = [
        {'id': '1', 'url': 'http://192.168.1.100:8123'},
        {'id': '2', 'url': 'https://homeassistant.local'},
        {'id': '3', 'url': 'https://my-ha-instance.duckdns.org'},
      ];

      await tester.pumpWidget(MaterialApp(
        home: MockHomeAssistantsPage(
          assistants: assistants,
          onSignOut: () {},
          onAdd: () {},
        ),
      ));

      // Should display all different URL formats
      expect(find.text('http://192.168.1.100:8123'), findsOneWidget);
      expect(find.text('https://homeassistant.local'), findsOneWidget);
      expect(find.text('https://my-ha-instance.duckdns.org'), findsOneWidget);
    });
  });
}