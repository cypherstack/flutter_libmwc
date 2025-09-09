import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('MWC Wallet App starts up', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MWCWalletApp());

    // Verify that the main navigation is displayed.
    expect(find.text('MWC Wallet & FFI Tests'), findsOneWidget);
  });
}
