import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('FFI Test App starts up', (WidgetTester tester) async {
    // Mock the MethodChannel for the test
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_libmwc'),
      (MethodCall methodCall) async {
        // Return empty string for any method call during testing
        return '';
      },
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(const FFITestApp());

    // Verify that the main navigation is displayed.
    expect(find.text('flutter_libmwc example'), findsOneWidget);
  });
}
