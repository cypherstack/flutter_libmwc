import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_libmwc_example/main.dart';

void main() {
  testWidgets('FFI Test App starts up', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FFITestApp());

    // Verify that the main navigation is displayed.
    expect(find.text('flutter_libmwc example'), findsOneWidget);
  });
}
