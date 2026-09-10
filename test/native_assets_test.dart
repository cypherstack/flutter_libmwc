import 'package:flutter_libmwc/mwc.dart';
import 'package:flutter_libmwc/lib.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calls Rust through the bundled native asset', () {
    expect(walletMnemonic().trim().split(RegExp(r'\s+')), hasLength(24));
  });
  test('releases Rust-owned open-wallet error strings', () {
    for (var i = 0; i < 100; i++) {
      expect(
        () => openWallet('{}', 'unused'),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Unable to get wallet config'),
          ),
        ),
      );
    }
  });

  test('resolves native assets in a compute isolate', () async {
    // openWallet uses Flutter compute(), as real wallet consumers do.
    await expectLater(
      Libmwc.openWallet(config: '{}', password: 'unused'),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Unable to get wallet config'),
        ),
      ),
    );
  });
}
