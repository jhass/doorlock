import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doorlock/add_home_assistant_page.dart';

void main() {
  group('AddHomeAssistantPage Widget Tests', () {
    testWidgets('AddHomeAssistantPage displays all UI elements correctly', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {},
        ),
      ));

      // Verify all UI elements are present
      expect(find.text('Add Home Assistant'), findsOneWidget);
      expect(find.text('Home Assistant Base URL'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('AddHomeAssistantPage shows error message when provided', (WidgetTester tester) async {
      const errorMessage = 'Failed to add Home Assistant';

      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {},
          error: errorMessage,
        ),
      ));

      expect(find.text(errorMessage), findsOneWidget);
      final errorText = tester.widget<Text>(find.text(errorMessage));
      expect(errorText.style?.color, equals(Colors.red));
    });

    testWidgets('AddHomeAssistantPage form validation works', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {},
        ),
      ));

      // Try to submit without filling the form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('Enter the base URL'), findsOneWidget);
    });

    testWidgets('AddHomeAssistantPage accepts input and submits correctly', (WidgetTester tester) async {
      String? capturedUrl;
      String? capturedCallback;

      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {
            capturedUrl = url;
            capturedCallback = callback;
          },
        ),
      ));

      // Enter URL
      const testUrl = 'https://homeassistant.example.com';
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Home Assistant Base URL'),
        testUrl
      );

      // Submit the form
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      // Verify the callback was called with correct values
      expect(capturedUrl, equals(testUrl));
      expect(capturedCallback, isNotNull);
      expect(capturedCallback, isNotEmpty);
    });

    testWidgets('AddHomeAssistantPage shows loading state during submission', (WidgetTester tester) async {
      bool submitStarted = false;

      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {
            submitStarted = true;
            // Simulate a quick async operation instead of using a timer
            await Future.delayed(Duration.zero);
          },
        ),
      ));

      // Enter URL and submit
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Home Assistant Base URL'),
        'https://test.com'
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump(); // Trigger one frame to start async operation

      // Should show loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Add'), findsNothing); // Button text should be hidden

      // Button should be disabled during submission
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      // Text field should be disabled during submission
      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.enabled, isFalse);

      // Complete the async operation
      await tester.pumpAndSettle();
      
      expect(submitStarted, isTrue);
    });

    testWidgets('AddHomeAssistantPage trims URL input', (WidgetTester tester) async {
      String? capturedUrl;

      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {
            capturedUrl = url;
          },
        ),
      ));

      // Enter URL with whitespace
      const testUrl = '  https://homeassistant.example.com  ';
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Home Assistant Base URL'),
        testUrl
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      // Should be trimmed
      expect(capturedUrl, equals('https://homeassistant.example.com'));
    });

    testWidgets('AddHomeAssistantPage handles empty input validation', (WidgetTester tester) async {
      bool submitCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {
            submitCalled = true;
          },
        ),
      ));

      // Submit without entering anything
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      // Should not call submit due to validation
      expect(submitCalled, isFalse);
      expect(find.text('Enter the base URL'), findsOneWidget);
    });

    testWidgets('AddHomeAssistantPage structure and layout', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {},
        ),
      ));

      // Verify the overall structure
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Padding), findsWidgets);
      expect(find.byType(Form), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);

      // Verify AppBar title
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.title, isA<Text>());
    });

    testWidgets('AddHomeAssistantPage generates frontend callback', (WidgetTester tester) async {
      String? capturedCallback;

      await tester.pumpWidget(MaterialApp(
        home: AddHomeAssistantPage(
          onSubmit: (url, callback) async {
            capturedCallback = callback;
          },
        ),
      ));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Home Assistant Base URL'),
        'https://test.com'
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      // Should generate a valid callback URL
      expect(capturedCallback, isNotNull);
      expect(capturedCallback, isNotEmpty);
      // In test environment, Uri.base should be something
      expect(Uri.tryParse(capturedCallback!), isNotNull);
    });
  });
}