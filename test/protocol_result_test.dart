import 'dart:convert';
import 'dart:ffi';

import 'package:flutter_libmwc/lib.dart';
import 'package:flutter_libmwc/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native errors are recognized only at the start of a result', () {
    expect(isMwcNativeError('Error wallet unavailable'), isTrue);
    expect(isMwcNativeError('  ERROR: wallet unavailable'), isTrue);
    expect(
      isMwcNativeError(jsonEncode({'message': 'no error occurred'})),
      isFalse,
    );
  });

  test('structured native decode failures are recognized', () {
    expect(
      isMwcDecodeFailure(
        jsonEncode({'slate_json': '', 'success': false, 'error': 'invalid'}),
      ),
      isTrue,
    );
    expect(isMwcDecodeFailure(jsonEncode({'slate_json': '{}'})), isFalse);
  });

  test('null native messages remain null', () {
    final message = Message.fromJson({
      'id': '1',
      'public_key': 'key',
      'message': null,
      'message_sig': null,
    });

    expect(message.message, isNull);
    expect(message.messageSig, isNull);
  });

  test('finalize metadata reports whether the transaction was posted', () {
    expect(
      parseMwcFinalizePosted(jsonEncode(['payload', '{"posted":false}'])),
      isFalse,
    );
    expect(
      parseMwcFinalizePosted(jsonEncode(['payload', '{"posted":true}'])),
      isTrue,
    );
  });

  test('legacy finalize metadata remains compatible', () {
    expect(
      parseMwcFinalizePosted(jsonEncode(['payload', '{"slate_msg":""}'])),
      isTrue,
    );
    expect(
      parseMwcFinalizePosted(jsonEncode(['payload', r'{\"slate_msg\": \"\"}'])),
      isTrue,
    );
  });

  test('listener ownership is wallet-specific', () {
    ListenerManager.pointer = Pointer<Void>.fromAddress(1);
    ListenerManager.wallet = 'wallet-a';
    addTearDown(() {
      ListenerManager.pointer = null;
      ListenerManager.wallet = null;
    });

    expect(ListenerManager.owns('wallet-a'), isTrue);
    expect(ListenerManager.owns('wallet-b'), isFalse);
  });

  test('listener readiness waits for native startup', () async {
    var probes = 0;
    final running = await Libmwc.waitForMwcMqsListener(
      isRunning: () => ++probes == 3,
      attempts: 3,
      pollInterval: Duration.zero,
    );

    expect(running, isTrue);
    expect(probes, 3);
    expect(
      await Libmwc.waitForMwcMqsListener(
        isRunning: () => false,
        attempts: 2,
        pollInterval: Duration.zero,
      ),
      isFalse,
    );
  });

  test(
    'owned listener is reused only while native listener is healthy',
    () async {
      ListenerManager.pointer = Pointer<Void>.fromAddress(1);
      ListenerManager.wallet = 'wallet-a';
      addTearDown(() {
        ListenerManager.pointer = null;
        ListenerManager.wallet = null;
      });

      expect(
        await Libmwc.canReuseMwcMqsListener(
          wallet: 'wallet-a',
          isRunning: () => true,
        ),
        isTrue,
      );
      expect(
        await Libmwc.canReuseMwcMqsListener(
          wallet: 'wallet-a',
          isRunning: () => false,
        ),
        isFalse,
      );
      expect(
        await Libmwc.canReuseMwcMqsListener(
          wallet: 'wallet-b',
          isRunning: () => true,
        ),
        isFalse,
      );
    },
  );

  test(
    'background listener start cannot evict a different healthy wallet',
    () async {
      ListenerManager.pointer = Pointer<Void>.fromAddress(1);
      ListenerManager.wallet = 'wallet-a';
      addTearDown(() {
        ListenerManager.pointer = null;
        ListenerManager.wallet = null;
      });

      expect(
        await Libmwc.shouldKeepCurrentMwcMqsListener(
          wallet: 'wallet-b',
          allowTakeover: false,
          isRunning: () => true,
        ),
        isTrue,
      );
      expect(
        await Libmwc.shouldKeepCurrentMwcMqsListener(
          wallet: 'wallet-b',
          allowTakeover: false,
          isRunning: () => false,
        ),
        isFalse,
      );
      expect(
        await Libmwc.shouldKeepCurrentMwcMqsListener(
          wallet: 'wallet-b',
          allowTakeover: true,
          isRunning: () => true,
        ),
        isFalse,
      );
      expect(
        await Libmwc.shouldKeepCurrentMwcMqsListener(
          wallet: 'wallet-a',
          allowTakeover: false,
          isRunning: () => true,
        ),
        isFalse,
      );
    },
  );

  test('active wallet keeps priority while its listener is recovering', () {
    ListenerManager.preferredWallet = 'wallet-a';
    addTearDown(() => ListenerManager.preferredWallet = null);

    expect(
      Libmwc.shouldDeferToPreferredMwcMqsWallet(
        wallet: 'wallet-b',
        allowTakeover: false,
      ),
      isTrue,
    );
    expect(
      Libmwc.shouldDeferToPreferredMwcMqsWallet(
        wallet: 'wallet-a',
        allowTakeover: false,
      ),
      isFalse,
    );
    expect(
      Libmwc.shouldDeferToPreferredMwcMqsWallet(
        wallet: 'wallet-b',
        allowTakeover: true,
      ),
      isFalse,
    );
  });

  test('wallet exit releases listener priority without native ownership', () async {
    ListenerManager.preferredWallet = 'wallet-a';
    addTearDown(() => ListenerManager.preferredWallet = null);

    expect(
      await Libmwc.stopMwcMqsListener(
        wallet: 'wallet-a',
        releasePreference: true,
      ),
      isFalse,
    );
    expect(ListenerManager.preferredWallet, isNull);
  });
}
