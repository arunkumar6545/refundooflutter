/// Integration smoke tests for Refundoo.
///
/// Run with:
///   flutter test integration_test/
///
/// For a connected device / emulator, use:
///   flutter test integration_test/ -d <device-id>
///
/// These tests verify the app boots without crashing and that key screens
/// render the expected UI.  They are intentionally lightweight so they can
/// run quickly on every feature branch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:refundoo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches without crashing', (tester) async {
    app.main();
    // Give services (notification init, ad init) time to settle.
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // The app should be rendering something (not a blank black screen).
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Splash / login screen renders', (tester) async {
    app.main();
    // Pump a few frames so the router resolves.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Either the splash logo or the login screen must be visible.
    // Both share either an AppLogo widget or a "Sign in" button.
    final splashOrLogin =
        find.textContaining('Refundoo').evaluate().isNotEmpty ||
        find.textContaining('Sign in').evaluate().isNotEmpty ||
        find.textContaining('Guest').evaluate().isNotEmpty;
    expect(splashOrLogin, isTrue);
  });
}
