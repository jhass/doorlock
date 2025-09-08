import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doorlock/add_home_assistant_page.dart';

void main() {
  group('Home Assistant Management', () {
    testWidgets('Add Home Assistant page displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {},
        ),
      ));

      // Verify form elements
      expect(find.text('Add Home Assistant'), findsOneWidget);
      expect(find.text('Home Assistant Base URL'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Add'), findsOneWidget);
    });

    testWidgets('Add Home Assistant form validation', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {},
        ),
      ));

      // Try to submit empty form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('Enter the base URL'), findsOneWidget);
    });

    testWidgets('Add Home Assistant form submission', (WidgetTester tester) async {
      String? submittedUrl, submittedCallback;

      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {
            submittedUrl = url;
            submittedCallback = callback;
          },
        ),
      ));

      // Fill form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Home Assistant Base URL'),
        'http://mock-ha:8123'
      );
      await tester.pumpAndSettle();

      // Submit form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      // Verify submission
      expect(submittedUrl, equals('http://mock-ha:8123'));
      expect(submittedCallback, isNotNull); // Auto-generated callback
    });

    testWidgets('Add Home Assistant shows error message', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {},
          error: 'Failed to connect to Home Assistant',
        ),
      ));

      // Should show error message
      expect(find.text('Failed to connect to Home Assistant'), findsOneWidget);
    });

    testWidgets('Add Home Assistant URL trimming', (WidgetTester tester) async {
      String? submittedUrl;

      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {
            submittedUrl = url;
          },
        ),
      ));

      // Enter URL with whitespace
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Home Assistant Base URL'),
        '  http://mock-ha:8123  '
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      // URL should be trimmed
      expect(submittedUrl, equals('http://mock-ha:8123'));
    });

    testWidgets('Add Home Assistant loading state', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {
            await Future.delayed(const Duration(milliseconds: 100));
          },
        ),
      ));

      // Fill form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Home Assistant Base URL'),
        'http://mock-ha:8123'
      );
      await tester.pumpAndSettle();

      // Submit form and check loading state
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump(); // Don't settle to see intermediate state

      // Should show loading state (circular progress indicator in button)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Wait for the operation to complete
      await tester.pumpAndSettle();
      
      // Should return to normal state
      expect(find.widgetWithText(ElevatedButton, 'Add'), findsOneWidget);
    });
  });
}