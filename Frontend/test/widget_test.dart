import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'resqgo_auth_page.dart';

void main() {
  testWidgets('ResQGoAuthPage displays login form', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: ResQGoAuthPage()));

    // Check for Login title
    expect(find.text('Login'), findsOneWidget);

    // Check for Email and Password fields
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);

    // Check for Login button
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
  });

  testWidgets('ResQGoAuthPage toggles to sign up form', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: ResQGoAuthPage()));

    // Tap the toggle button
    await tester.tap(find.text("Don't have an account? Sign Up"));
    await tester.pumpAndSettle();

    // Check for Sign Up title and Username field
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);

    // Check for Sign Up button
    expect(find.widgetWithText(ElevatedButton, 'Sign Up'), findsOneWidget);
  });
}