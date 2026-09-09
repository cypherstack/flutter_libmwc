import 'package:flutter_libmwc/mwc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calls Rust through the bundled native asset', () {
    expect(walletMnemonic().trim().split(RegExp(r'\s+')), hasLength(24));
  });
}
