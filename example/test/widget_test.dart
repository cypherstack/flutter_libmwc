import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('FFI Test App starts up', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FFITestApp());

    // Verify that the test runner view is displayed.
    expect(find.text('MWC FFI Integration Tests'), findsOneWidget);
  });
}
