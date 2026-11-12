import 'dart:convert';
import 'dart:io';

import 'package:flutter_libmwc/lib.dart';
import 'package:flutter_test/flutter_test.dart';

// A compact slate from the MWC integration docs. Encoding requires both the
// transaction body and the participant data, even when the lists are empty.
const _compactSlateJson =
    '{\n'
    '  "amount": "200000000",\n'
    '  "coin_type": "mwc",\n'
    '  "compact_slate": true,\n'
    '  "fee": "7000000",\n'
    '  "height": "2793169",\n'
    '  "id": "e2757000-4a03-47f9-b6fe-ed91dc2ceb9f",\n'
    '  "lock_height": "0",\n'
    '  "network_type": "mainnet",\n'
    '  "num_participants": 2,\n'
    '  "participant_data": [\n'
    '    {\n'
    '      "id": "0",\n'
    '      "message": null,\n'
    '      "message_sig": null,\n'
    '      "part_sig": null,\n'
    '      "public_blind_excess": "028d440ffa605a04cc92ca9e77b6be3295042fdc088b12565c73ae3bb4c7fbabae",\n'
    '      "public_nonce": "0309338aec074b65e82e6077aab0e5a9b052df9948207e047bbedca1477f17a6cd"\n'
    '    }\n'
    '  ],\n'
    '  "payment_proof": null,\n'
    '  "ttl_cutoff_height": "2794609",\n'
    '  "tx": {\n'
    '    "body": {\n'
    '      "inputs": [],\n'
    '      "kernels": [],\n'
    '      "outputs": []\n'
    '    },\n'
    '    "offset": "0000000000000000000000000000000000000000000000000000000000000000"\n'
    '  },\n'
    '  "version_info": {\n'
    '    "block_header_version": 2,\n'
    '    "orig_version": 3,\n'
    '    "version": 3\n'
    '  }\n'
    '}';

String _walletConfig(String walletDir) => jsonEncode({
  'wallet_dir': walletDir,
  'check_node_api_http_addr': 'https://mwc713.mwc.mw:443',
  'chain': 'mainnet',
  'account': 'default',
});

void main() {
  test('generates a 24-word mnemonic', () {
    final words = Libmwc.getMnemonic().trim().split(RegExp(r'\s+'));
    expect(words, hasLength(24));
  });

  test('rejects an invalid send address', () {
    expect(Libmwc.validateSendAddress(address: 'invalid_address'), isFalse);
  });

  test('creates a wallet and opens it', () async {
    final walletDir = await Directory.systemTemp.createTemp(
      'flutter_libmwc_wallet_',
    );
    addTearDown(() async {
      try {
        await walletDir.delete(recursive: true);
      } on FileSystemException {
        // The wallet library may still hold files open on Windows.
      }
    });

    final config = _walletConfig(walletDir.path);
    final name = 'ffi_test_${DateTime.now().microsecondsSinceEpoch}';
    final handle = await Libmwc.initializeNewWallet(
      config: config,
      mnemonic: Libmwc.getMnemonic(),
      password: 'test_password_123',
      name: name,
    );
    expect(handle.toUpperCase(), isNot(contains('ERROR')));

    final opened = await Libmwc.openWallet(
      config: config,
      password: 'test_password_123',
    );
    expect(opened.toUpperCase(), isNot(contains('ERROR')));
  });

  test('round-trips an unencrypted slatepack', () async {
    final encoded = await Libmwc.encodeSlatepack(
      slateJson: _compactSlateJson,
      encrypt: false,
    );

    expect(encoded.slatepack, contains('BEGINSLATE'));
    expect(encoded.slatepack, contains('ENDSLATE'));
    expect(encoded.wasEncrypted, isFalse);

    final decoded = await Libmwc.decodeSlatepack(slatepack: encoded.slatepack);
    final slate = jsonDecode(decoded.slateJson) as Map<String, dynamic>;
    expect(slate['id'], 'e2757000-4a03-47f9-b6fe-ed91dc2ceb9f');
    expect(await Libmwc.isSlatepackEncrypted(encoded.slatepack), isFalse);
  });

  test('requires wallet context for encrypted slatepacks', () async {
    await expectLater(
      Libmwc.encodeSlatepack(
        slateJson: _compactSlateJson,
        recipientAddress: 'dummy@mwcmqs.mwc.mw',
        encrypt: true,
        wallet: null,
      ),
      throwsA(
        predicate((error) {
          final message = error.toString().toLowerCase();
          return message.contains('wallet') && message.contains('required');
        }),
      ),
    );
  });

  test('rejects a malformed slatepack', () async {
    await expectLater(
      Libmwc.decodeSlatepack(slatepack: 'NOT_A_SLATEPACK'),
      throwsA(anything),
    );
  });
}
