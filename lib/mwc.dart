import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef WalletMnemonic = Pointer<Utf8> Function();
typedef WalletMnemonicFFI = Pointer<Utf8> Function();

typedef InitLogs = Pointer<Utf8> Function(Pointer<Utf8>);
typedef InitLogsFFI = Pointer<Utf8> Function(Pointer<Utf8>);

typedef WalletInit = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef WalletInitFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef WalletInfo = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);
typedef WalletInfoFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);

typedef RecoverWallet = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef RecoverWalletFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef WalletPhrase = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef WalletPhraseFFI = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef ScanOutPuts = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);
typedef ScanOutPutsFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);

typedef CreateTransaction = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Int8>,
    Pointer<Utf8>, Pointer<Int8>, Pointer<Utf8>, Pointer<Int8>, Pointer<Utf8>);
typedef CreateTransactionFFI = Pointer<Utf8> Function(
    Pointer<Utf8>,
    Pointer<Int8>,
    Pointer<Utf8>,
    Pointer<Int8>,
    Pointer<Utf8>,
    Pointer<Int8>,
    Pointer<Utf8>);

typedef MwcMqsListenerStart = Pointer<Void> Function(
    Pointer<Utf8>, Pointer<Utf8>);
typedef MwcMqsListenerStartFFI = Pointer<Void> Function(
    Pointer<Utf8>, Pointer<Utf8>);

typedef MwcMqsListenerStop = Pointer<Utf8> Function(Pointer<Void>);
typedef MwcMqsListenerStopFFI = Pointer<Utf8> Function(Pointer<Void>);

typedef GetTransactions = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Int8>);
typedef GetTransactionsFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>);

typedef CancelTransaction = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);
typedef CancelTransactionFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);

typedef GetChainHeight = Pointer<Utf8> Function(Pointer<Utf8>);
typedef GetChainHeightFFI = Pointer<Utf8> Function(Pointer<Utf8>);

typedef AddressInfo = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Int8>);
typedef AddressInfoFFI = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Int8>);

typedef ValidateAddress = Pointer<Utf8> Function(Pointer<Utf8>);
typedef ValidateAddressFFI = Pointer<Utf8> Function(Pointer<Utf8>);

typedef TransactionFees = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);
typedef TransactionFeesFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);

typedef DeleteWallet = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef DeleteWalletFFI = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef OpenWallet = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef OpenWalletFFI = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef TxHttpSend = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Int8>,
    Pointer<Int8>, Pointer<Utf8>, Pointer<Int8>, Pointer<Utf8>);
typedef TxHttpSendFFI = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Int8>,
    Pointer<Int8>, Pointer<Utf8>, Pointer<Int8>, Pointer<Utf8>);

typedef EncodeSlatepack = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef EncodeSlatepackFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);

typedef EncodeSlatepackEnhanced = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef EncodeSlatepackEnhancedFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef DecodeSlatepack = Pointer<Utf8> Function(Pointer<Utf8>);
typedef DecodeSlatepackFFI = Pointer<Utf8> Function(Pointer<Utf8>);

typedef DecodeSlatepackEnhanced = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);
typedef DecodeSlatepackEnhancedFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);

typedef TxReceive = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef TxReceiveFFI = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef TxFinalize = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef TxFinalizeFFI = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef TxInit = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>, Pointer<Utf8>, Pointer<Int8>);
typedef TxInitFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>, Pointer<Utf8>, Pointer<Int8>);

@Native<WalletMnemonicFFI>(symbol: 'mwc_get_mnemonic')
external Pointer<Utf8> _walletMnemonic();

String walletMnemonic() {
  return _walletMnemonic().toDartString();
}

@Native<InitLogsFFI>(symbol: 'mwc_rust_init_logs')
external Pointer<Utf8> _initLogs(Pointer<Utf8> config);

String initLogs(String config) {
  return _initLogs(config.toNativeUtf8()).toDartString();
}

@Native<WalletInitFFI>(symbol: 'mwc_wallet_init')
external Pointer<Utf8> _initWallet(
  Pointer<Utf8> config,
  Pointer<Utf8> mnemonic,
  Pointer<Utf8> password,
  Pointer<Utf8> name,
);

String initWallet(
    String config, String mnemonic, String password, String name) {
  return _initWallet(config.toNativeUtf8(), mnemonic.toNativeUtf8(),
          password.toNativeUtf8(), name.toNativeUtf8())
      .toDartString();
}

@Native<WalletInfoFFI>(symbol: 'mwc_rust_wallet_balances')
external Pointer<Utf8> _walletInfo(
  Pointer<Utf8> wallet,
  Pointer<Int8> refresh,
  Pointer<Int8> min_confirmations,
);

Future<String> getWalletInfo(
    String wallet, int refreshFromNode, int min_confirmations) async {
  return _walletInfo(
          wallet.toNativeUtf8(),
          refreshFromNode.toString().toNativeUtf8().cast<Int8>(),
          min_confirmations.toString().toNativeUtf8().cast<Int8>())
      .toDartString();
}

@Native<RecoverWalletFFI>(symbol: 'mwc_rust_recover_from_mnemonic')
external Pointer<Utf8> _recoverWallet(
  Pointer<Utf8> config,
  Pointer<Utf8> password,
  Pointer<Utf8> mnemonic,
  Pointer<Utf8> name,
);

String recoverWallet(
    String config, String password, String mnemonic, String name) {
  return _recoverWallet(config.toNativeUtf8(), password.toNativeUtf8(),
          mnemonic.toNativeUtf8(), name.toNativeUtf8())
      .toDartString();
}

@Native<ScanOutPutsFFI>(symbol: 'mwc_rust_wallet_scan_outputs')
external Pointer<Utf8> _scanOutPuts(
  Pointer<Utf8> wallet,
  Pointer<Int8> start_height,
  Pointer<Int8> number_of_blocks,
);

Future<String> scanOutPuts(
    String wallet, int startHeight, int numberOfBlocks) async {
  return _scanOutPuts(
    wallet.toNativeUtf8(),
    startHeight.toString().toNativeUtf8().cast<Int8>(),
    numberOfBlocks.toString().toNativeUtf8().cast<Int8>(),
  ).toDartString();
}

@Native<MwcMqsListenerStartFFI>(symbol: 'mwc_rust_mwcmqs_listener_start')
external Pointer<Void> _MwcMqsListenerStart(
  Pointer<Utf8> wallet,
  Pointer<Utf8> mwcmqs_config,
);

Pointer<Void> mwcMqsListenerStart(String wallet, String MWCMQSConfig) {
  return _MwcMqsListenerStart(
    wallet.toNativeUtf8(),
    MWCMQSConfig.toNativeUtf8(),
  );
}

@Native<MwcMqsListenerStopFFI>(symbol: 'mwc_listener_cancel')
external Pointer<Utf8> _MwcMqsListenerStop(Pointer<Void> handler);

String mwcMqsListenerStop(Pointer<Void> handler) {
  return _MwcMqsListenerStop(
    handler,
  ).toDartString();
}

@Native<CreateTransactionFFI>(symbol: 'mwc_rust_create_tx')
external Pointer<Utf8> _createTransaction(
  Pointer<Utf8> wallet,
  Pointer<Int8> amount,
  Pointer<Utf8> to_address,
  Pointer<Int8> secret_key_index,
  Pointer<Utf8> mwcmqs_config,
  Pointer<Int8> confirmations,
  Pointer<Utf8> note,
);

Future<String> createTransaction(
    String wallet,
    int amount,
    String address,
    int secretKey,
    String MWCMQSConfig,
    int minimumConfirmations,
    String note) async {
  return _createTransaction(
    wallet.toNativeUtf8(),
    amount.toString().toNativeUtf8().cast<Int8>(),
    address.toNativeUtf8(),
    secretKey.toString().toNativeUtf8().cast<Int8>(),
    MWCMQSConfig.toNativeUtf8(),
    minimumConfirmations.toString().toNativeUtf8().cast<Int8>(),
    note.toNativeUtf8(),
  ).toDartString();
}

@Native<GetTransactionsFFI>(symbol: 'mwc_rust_txs_get')
external Pointer<Utf8> _getTransactions(
  Pointer<Utf8> wallet,
  Pointer<Int8> refresh_from_node,
);

Future<String> getTransactions(String wallet, int refreshFromNode) async {
  return _getTransactions(wallet.toNativeUtf8(),
          refreshFromNode.toString().toNativeUtf8().cast<Int8>())
      .toDartString();
}

@Native<CancelTransactionFFI>(symbol: 'mwc_rust_tx_cancel')
external Pointer<Utf8> _cancelTransaction(
  Pointer<Utf8> wallet,
  Pointer<Utf8> tx_id,
);

String cancelTransaction(String wallet, String transactionId) {
  return _cancelTransaction(wallet.toNativeUtf8(), transactionId.toNativeUtf8())
      .toDartString();
}

@Native<GetChainHeightFFI>(symbol: 'mwc_rust_get_chain_height')
external Pointer<Utf8> _getChainHeight(Pointer<Utf8> config);

int getChainHeight(String config) {
  String latestHeight = _getChainHeight(config.toNativeUtf8()).toDartString();
  return int.parse(latestHeight);
}

@Native<AddressInfoFFI>(symbol: 'mwc_rust_get_wallet_address')
external Pointer<Utf8> _addressInfo(Pointer<Utf8> wallet, Pointer<Int8> index);

String getAddressInfo(String wallet, int index) {
  return _addressInfo(
          wallet.toNativeUtf8(), index.toString().toNativeUtf8().cast<Int8>())
      .toDartString();
}

@Native<ValidateAddressFFI>(symbol: 'mwc_rust_validate_address')
external Pointer<Utf8> _validateSendAddress(Pointer<Utf8> address);

String validateSendAddress(String address) {
  return _validateSendAddress(address.toNativeUtf8()).toDartString();
}

@Native<TransactionFeesFFI>(symbol: 'mwc_rust_get_tx_fees')
external Pointer<Utf8> _transactionFees(
  Pointer<Utf8> wallet,
  Pointer<Int8> c_amount,
  Pointer<Int8> min_confirmations,
);

Future<String> getTransactionFees(
    String wallet, int amount, int minimumConfirmations) async {
  return _transactionFees(
          wallet.toNativeUtf8(),
          amount.toString().toNativeUtf8().cast<Int8>(),
          minimumConfirmations.toString().toNativeUtf8().cast<Int8>())
      .toDartString();
}

@Native<DeleteWalletFFI>(symbol: 'mwc_rust_delete_wallet')
external Pointer<Utf8> _deleteWallet(
  Pointer<Utf8> _wallet,
  Pointer<Utf8> config,
);

Future<String> deleteWallet(String wallet, String config) async {
  return _deleteWallet(wallet.toNativeUtf8(), config.toNativeUtf8())
      .toDartString();
}

@Native<OpenWalletFFI>(symbol: 'mwc_rust_open_wallet')
external Pointer<Utf8> _openWallet(
  Pointer<Utf8> config,
  Pointer<Utf8> password,
);

@Native<Void Function(Pointer<Utf8>)>(symbol: 'mwc_string_free')
external void _freeWalletString(Pointer<Utf8> value);

String openWallet(String config, String password) {
  final handle = using((arena) {
    final handlePointer = _openWallet(
      config.toNativeUtf8(allocator: arena),
      password.toNativeUtf8(allocator: arena),
    );
    if (handlePointer == nullptr) {
      throw Exception("Failed to open wallet: Received null pointer from rust!");
    }
    try {
      return handlePointer.toDartString().trim();
    } finally {
      _freeWalletString(handlePointer);
    }
  });

  if (handle.startsWith("[") && handle.endsWith("]")) {
    final parts = handle.split(",");
    if (parts.length != 2 ||
        BigInt.tryParse(parts.first.substring(1)) == null) {
      throw Exception(handle);
    }

    return handle;
  } else {
    // probably an error
    throw Exception(handle);
  }
}

@Native<TxHttpSendFFI>(symbol: 'mwc_rust_tx_send_http')
external Pointer<Utf8> _txHttpSend(
  Pointer<Utf8> wallet,
  Pointer<Int8> selection_strategy_is_use_all,
  Pointer<Int8> minimum_confirmations,
  Pointer<Utf8> message,
  Pointer<Int8> amount,
  Pointer<Utf8> address,
);

Future<String> txHttpSend(
    String wallet,
    int selectionStrategyIsAll,
    int minimumConfirmations,
    String message,
    int amount,
    String address) async {
  return _txHttpSend(
          wallet.toNativeUtf8(),
          selectionStrategyIsAll.toString().toNativeUtf8().cast<Int8>(),
          minimumConfirmations.toString().toNativeUtf8().cast<Int8>(),
          message.toNativeUtf8(),
          amount.toString().toNativeUtf8().cast<Int8>(),
          address.toNativeUtf8())
      .toDartString();
}

@Native<EncodeSlatepackFFI>(symbol: 'mwc_rust_encode_slatepack')
external Pointer<Utf8> _encodeSlatepack(
  Pointer<Utf8> slate_json,
  Pointer<Utf8> recipient_address,
);

Future<String> encodeSlatepack(
    String slateJson, String? recipientAddress) async {
  return _encodeSlatepack(
          slateJson.toNativeUtf8(), (recipientAddress ?? "").toNativeUtf8())
      .toDartString();
}

@Native<EncodeSlatepackEnhancedFFI>(
    symbol: 'mwc_rust_encode_slatepack_enhanced')
external Pointer<Utf8> _encodeSlatepackEnhanced(
  Pointer<Utf8> wallet,
  Pointer<Utf8> slate_json,
  Pointer<Utf8> recipient_address,
);

Future<String> encodeSlatepackEnhanced(
    String wallet, String slateJson, String recipientAddress) async {
  return _encodeSlatepackEnhanced(wallet.toNativeUtf8(),
          slateJson.toNativeUtf8(), recipientAddress.toNativeUtf8())
      .toDartString();
}

@Native<DecodeSlatepackFFI>(symbol: 'mwc_rust_decode_slatepack')
external Pointer<Utf8> _decodeSlatepack(Pointer<Utf8> slatepack_str);

Future<String> decodeSlatepack(String slatepack) async {
  return _decodeSlatepack(slatepack.toNativeUtf8()).toDartString();
}

@Native<DecodeSlatepackEnhancedFFI>(
    symbol: 'mwc_rust_decode_slatepack_enhanced')
external Pointer<Utf8> _decodeSlatepackEnhanced(
  Pointer<Utf8> wallet,
  Pointer<Utf8> slatepack_str,
);

Future<String> decodeSlatepackEnhanced(String wallet, String slatepack) async {
  return _decodeSlatepackEnhanced(
          wallet.toNativeUtf8(), slatepack.toNativeUtf8())
      .toDartString();
}

@Native<TxReceiveFFI>(symbol: 'mwc_rust_tx_receive')
external Pointer<Utf8> _txReceive(
  Pointer<Utf8> wallet,
  Pointer<Utf8> slate_json,
);

String txReceive(String wallet, String slateJson) {
  return _txReceive(wallet.toNativeUtf8(), slateJson.toNativeUtf8())
      .toDartString();
}

@Native<TxFinalizeFFI>(symbol: 'mwc_rust_tx_finalize')
external Pointer<Utf8> _txFinalize(
  Pointer<Utf8> wallet,
  Pointer<Utf8> slate_json,
);

String txFinalize(String wallet, String slateJson) {
  return _txFinalize(wallet.toNativeUtf8(), slateJson.toNativeUtf8())
      .toDartString();
}

@Native<TxInitFFI>(symbol: 'mwc_rust_tx_init')
external Pointer<Utf8> _txInit(
  Pointer<Utf8> wallet,
  Pointer<Int8> selection_strategy_is_use_all,
  Pointer<Int8> minimum_confirmations,
  Pointer<Utf8> message,
  Pointer<Int8> amount,
);

Future<String> txInit(String wallet, int selectionStrategyIsAll,
    int minimumConfirmations, String message, int amount) async {
  return _txInit(
          wallet.toNativeUtf8(),
          selectionStrategyIsAll.toString().toNativeUtf8().cast<Int8>(),
          minimumConfirmations.toString().toNativeUtf8().cast<Int8>(),
          message.toNativeUtf8(),
          amount.toString().toNativeUtf8().cast<Int8>())
      .toDartString();
}
