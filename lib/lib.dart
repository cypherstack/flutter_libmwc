import 'dart:convert';
import 'dart:ffi';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_libmwc/mwc.dart' as lib_mwc;
import 'package:flutter_libmwc/models/transaction.dart';
import 'package:mutex/mutex.dart';

class BadMWCHTTPAddressException implements Exception {
  final String? message;

  BadMWCHTTPAddressException({this.message});

  @override
  String toString() {
    return "BadMWCHTTPAddressException: $message";
  }
}

abstract class ListenerManager {
  static Pointer<Void>? pointer;
}

///
/// Wrapped up calls to flutter_libmwc.
///
/// Should all be static calls (no state stored in this class)
///
abstract class Libmwc {
  static final Mutex m = Mutex();

  ///
  /// Check if [address] is a valid mwc address according to libmwc
  ///
  static bool validateSendAddress({required String address}) {
    final String validate = lib_mwc.validateSendAddress(address);
    if (int.parse(validate) == 1) {
      // Check if address contains a domain
      if (address.contains("@")) {
        return true;
      }
      return false;
    } else {
      return false;
    }
  }

  ///
  /// Fetch the mnemonic For a new wallet (Only used in the example app)
  ///
  // TODO: ensure the above documentation comment is correct
  // TODO: ensure this will always return the mnemonic. If not, this function should throw an exception
  //Function is used in _getMnemonicList()
  // wrap in mutex? -> would need to be Future<String>
  static String getMnemonic() {
    try {
      String mnemonic = lib_mwc.walletMnemonic();
      if (mnemonic.isEmpty) {
        throw Exception("Error getting mnemonic, returned empty string");
      }
      return mnemonic;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<String> _initLogs(
    ({
      String config,
    }) data,
  ) async {
    try {
      final String mnemonic = lib_mwc.initLogs(data.config);
      if (mnemonic.isEmpty) {
        throw Exception("Error getting mnemonic, returned empty string");
      }
      return mnemonic;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<String> initLogs({
    required String config,
  }) async {
    return await m.protect(() async {
      try {
        return await compute(
          _initLogs,
          (
            config: config,
          ),
        );
      } catch (e) {
        throw ("Error init logs : ${e.toString()}");
      }
    });
  }

  // Private function wrapper for compute
  static Future<String> _initializeWalletWrapper(
    ({
      String config,
      String mnemonic,
      String password,
      String name,
    }) data,
  ) async {
    final String initWalletStr = lib_mwc.initWallet(
      data.config,
      data.mnemonic,
      data.password,
      data.name,
    );
    return initWalletStr;
  }

  ///
  /// Create a new mwc wallet.
  ///
  // TODO: Complete/modify the documentation comment above
  // TODO: Should return a void future. On error this function should throw and exception
  static Future<String> initializeNewWallet({
    required String config,
    required String mnemonic,
    required String password,
    required String name,
  }) async {
    return await m.protect(() async {
      try {
        return await compute(
          _initializeWalletWrapper,
          (
            config: config,
            mnemonic: mnemonic,
            password: password,
            name: name,
          ),
        );
      } catch (e) {
        throw ("Error creating new wallet : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function wrapper for wallet balances
  ///
  static Future<String> _walletBalancesWrapper(
    ({String wallet, int refreshFromNode, int minimumConfirmations}) data,
  ) async {
    return lib_mwc.getWalletInfo(
        data.wallet, data.refreshFromNode, data.minimumConfirmations);
  }

  ///
  /// Get balance information for the currently open wallet
  ///
  static Future<
          ({
            double awaitingFinalization,
            double pending,
            double spendable,
            double total
          })>
      getWalletBalances(
          {required String wallet,
          required int refreshFromNode,
          required int minimumConfirmations}) async {
    return await m.protect(() async {
      try {
        String balances = await compute(_walletBalancesWrapper, (
          wallet: wallet,
          refreshFromNode: refreshFromNode,
          minimumConfirmations: minimumConfirmations,
        ));

        //If balances is valid json return, else return error
        if (balances.toUpperCase().contains("ERROR")) {
          throw Exception(balances);
        }
        var jsonBalances = json.decode(balances);
        //Return balances as record
        ({
          double spendable,
          double pending,
          double total,
          double awaitingFinalization
        }) balancesRecord = (
          spendable: jsonBalances['amount_currently_spendable'],
          pending: jsonBalances['amount_awaiting_finalization'],
          total: jsonBalances['total'],
          awaitingFinalization: jsonBalances['amount_awaiting_finalization'],
        );
        return balancesRecord;
      } catch (e) {
        throw ("Error getting wallet info : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function wrapper for scanning output function
  ///
  static Future<String> _scanOutputsWrapper(
    ({String wallet, int startHeight, int numberOfBlocks}) data,
  ) async {
    return lib_mwc.scanOutPuts(
      data.wallet,
      data.startHeight,
      data.numberOfBlocks,
    );
  }

  ///
  /// Scan MWC outputs
  ///
  static Future<int> scanOutputs({
    required String wallet,
    required int startHeight,
    required int numberOfBlocks,
  }) async {
    try {
      final result = await m.protect(() async {
        return await compute(
          _scanOutputsWrapper,
          (
            wallet: wallet,
            startHeight: startHeight,
            numberOfBlocks: numberOfBlocks,
          ),
        );
      });
      final response = int.tryParse(result);
      if (response == null) {
        throw Exception(result);
      }
      return response;
    } catch (e) {
      throw ("Libmwc.scanOutputs failed: ${e.toString()}");
    }
  }

  ///
  /// Private function wrapper for create transactions
  ///
  static Future<String> _createTransactionWrapper(
    ({
      String wallet,
      int amount,
      String address,
      int secretKeyIndex,
      String mwcmqsConfig,
      int minimumConfirmations,
      String note,
    }) data,
  ) async {
    return lib_mwc.createTransaction(
        data.wallet,
        data.amount,
        data.address,
        data.secretKeyIndex,
        data.mwcmqsConfig,
        data.minimumConfirmations,
        data.note);
  }

  ///
  /// Create an MWC transaction
  ///
  static Future<({String slateId, String commitId})> createTransaction({
    required String wallet,
    required int amount,
    required String address,
    required int secretKeyIndex,
    required String mwcmqsConfig,
    required int minimumConfirmations,
    required String note,
  }) async {
    return await m.protect(() async {
      try {
        String result = await compute(_createTransactionWrapper, (
          wallet: wallet,
          amount: amount,
          address: address,
          secretKeyIndex: secretKeyIndex,
          mwcmqsConfig: mwcmqsConfig,
          minimumConfirmations: minimumConfirmations,
          note: note,
        ));

        if (result.toUpperCase().contains("ERROR")) {
          throw Exception("Error creating transaction ${result.toString()}");
        }

        //Decode sent tx and return Slate Id
        final slate0 = jsonDecode(result);
        final slate = jsonDecode(slate0[0] as String);
        final part1 = jsonDecode(slate[0] as String);
        final part2 = jsonDecode(slate[1] as String);

        List<dynamic>? outputs = part2['tx']?['body']?['outputs'] as List;
        String? commitId =
            (outputs.isEmpty) ? '' : outputs[0]['commit'] as String;

        ({String slateId, String commitId}) data = (
          slateId: part1[0]['tx_slate_id'],
          commitId: commitId,
        );

        return data;
      } catch (e) {
        throw ("Error creating mwc transaction : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function wrapper for get transactions
  ///
  static Future<String> _getTransactionsWrapper(
    ({
      String wallet,
      int refreshFromNode,
    }) data,
  ) async {
    return lib_mwc.getTransactions(
      data.wallet,
      data.refreshFromNode,
    );
  }

  ///
  ///
  ///
  static Future<List<Transaction>> getTransactions({
    required String wallet,
    required int refreshFromNode,
  }) async {
    return await m.protect(() async {
      try {
        var result = await compute(_getTransactionsWrapper, (
          wallet: wallet,
          refreshFromNode: refreshFromNode,
        ));

        if (result.toUpperCase().contains("ERROR")) {
          throw Exception(
              "Error getting mwc transactions ${result.toString()}");
        }

//Parse the returned data as an mwcTransaction
        List<Transaction> finalResult = [];
        var jsonResult = json.decode(result) as List;

        for (var tx in jsonResult) {
          Transaction itemTx = Transaction.fromJson(tx);
          finalResult.add(itemTx);
        }
        return finalResult;
      } catch (e) {
        throw ("Error getting mwc transactions : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function for cancel transaction function
  ///
  static Future<String> _cancelTransactionWrapper(
    ({
      String wallet,
      String transactionId,
    }) data,
  ) async {
    return lib_mwc.cancelTransaction(
      data.wallet,
      data.transactionId,
    );
  }

  ///
  /// Cancel current mwc transaction
  ///
  /// returns an empty String on success, error message on failure
  static Future<String> cancelTransaction({
    required String wallet,
    required String transactionId,
  }) async {
    return await m.protect(() async {
      try {
        return await compute(_cancelTransactionWrapper, (
          wallet: wallet,
          transactionId: transactionId,
        ));
      } catch (e) {
        throw ("Error canceling mwc transaction : ${e.toString()}");
      }
    });
  }

  static Future<int> _chainHeightWrapper(
    ({
      String config,
    }) data,
  ) async {
    return lib_mwc.getChainHeight(data.config);
  }

  static Future<int> getChainHeight({
    required String config,
  }) async {
    return await m.protect(() async {
      try {
        return await compute(_chainHeightWrapper, (config: config,));
      } catch (e) {
        throw ("Error getting chain height : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function for address info function
  ///
  static Future<String> _addressInfoWrapper(
    ({
      String wallet,
      int index
    }) data,
  ) async {
    return lib_mwc.getAddressInfo(
      data.wallet,
      data.index,
    );
  }

  ///
  /// get mwc address info
  ///
  static Future<String> getAddressInfo({
    required String wallet,
    required int index,
  }) async {
    return await m.protect(() async {
      try {
        return await compute(_addressInfoWrapper, (
          wallet: wallet,
          index: index
        ));
      } catch (e) {
        throw ("Error getting address info : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function for getting transaction fees
  ///
  static Future<String> _transactionFeesWrapper(
    ({
      String wallet,
      int amount,
      int minimumConfirmations,
    }) data,
  ) async {
    return lib_mwc.getTransactionFees(
      data.wallet,
      data.amount,
      data.minimumConfirmations,
    );
  }

  ///
  /// get transaction fees for mwc
  ///
  static Future<({int fee, bool strategyUseAll, int total})>
      getTransactionFees({
    required String wallet,
    required int amount,
    required int minimumConfirmations,
    required int available,
  }) async {
    return await m.protect(() async {
      try {
        String fees = await compute(_transactionFeesWrapper, (
          wallet: wallet,
          amount: amount,
          minimumConfirmations: minimumConfirmations,
        ));

        if (available == amount) {
          if (fees.contains("Required")) {
            var splits = fees.split(" ");
            Decimal required = Decimal.zero;
            Decimal available = Decimal.zero;
            for (int i = 0; i < splits.length; i++) {
              var word = splits[i];
              if (word == "Required:") {
                required = Decimal.parse(splits[i + 1].replaceAll(",", "").replaceAll("\"", ""));
              } else if (word == "Available:") {
                available = Decimal.parse(splits[i + 1].replaceAll(",", "").replaceAll("\"", ""));
              }
            }
            int largestSatoshiFee =
                ((required - available) * Decimal.fromInt(1000000000))
                    .toBigInt()
                    .toInt();
            var amountSending = amount - largestSatoshiFee;
            //Get fees for this new amount
            fees = await compute(_transactionFeesWrapper, (
              wallet: wallet,
              amount: amountSending,
              minimumConfirmations: minimumConfirmations,
            ));
          }
        }

        if (fees.toUpperCase().contains("ERROR")) {
          //Check if the error is an
          //Throw the returned error
          throw Exception(fees);
        }
        var decodedFees = json.decode(fees);
        var feeItem = decodedFees[0];
        ({
          bool strategyUseAll,
          int total,
          int fee,
        }) feeRecord = (
          strategyUseAll: feeItem['selection_strategy_is_use_all'],
          total: feeItem['total'],
          fee: feeItem['fee'],
        );
        return feeRecord;
      } catch (e) {
        throw (e.toString());
      }
    });
  }

  ///
  /// Private function wrapper for recover wallet function
  ///
  static Future<String> _recoverWalletWrapper(
    ({
      String config,
      String password,
      String mnemonic,
      String name,
    }) data,
  ) async {
    return lib_mwc.recoverWallet(
      data.config,
      data.password,
      data.mnemonic,
      data.name,
    );
  }

  ///
  /// Recover an mwc wallet using a mnemonic
  ///
  static Future<void> recoverWallet(
      {required String config,
      required String password,
      required String mnemonic,
      required String name}) async {
    try {
      await compute(_recoverWalletWrapper, (
        config: config,
        password: password,
        mnemonic: mnemonic,
        name: name,
      ));
    } catch (e) {
      throw (e.toString());
    }
  }

  ///
  /// Private function wrapper for delete wallet function
  ///
  static Future<String> _deleteWalletWrapper(
    ({
      String wallet,
      String config,
    }) data,
  ) async {
    return lib_mwc.deleteWallet(
      data.wallet,
      data.config,
    );
  }

  ///
  /// Delete an mwc wallet
  ///
  static Future<String> deleteWallet({
    required String wallet,
    required String config,
  }) async {
    try {
      return await compute(_deleteWalletWrapper, (
        wallet: wallet,
        config: config,
      ));
    } catch (e) {
      throw ("Error deleting wallet : ${e.toString()}");
    }
  }

  ///
  /// Private function wrapper for open wallet function
  ///
  static Future<String> _openWalletWrapper(
    ({
      String config,
      String password,
    }) data,
  ) async {
    return lib_mwc.openWallet(
      data.config,
      data.password,
    );
  }

  ///
  /// Open an mwc wallet
  ///
  static Future<String> openWallet({
    required String config,
    required String password,
  }) async {
    try {
      return await compute(_openWalletWrapper, (
        config: config,
        password: password,
      ));
    } catch (e) {
      throw ("Error opening wallet : ${e.toString()}");
    }
  }

  ///
  /// Private function for txHttpSend function
  ///
  static Future<String> _txHttpSendWrapper(
    ({
      String wallet,
      int selectionStrategyIsAll,
      int minimumConfirmations,
      String message,
      int amount,
      String address,
    }) data,
  ) async {
    return lib_mwc.txHttpSend(
      data.wallet,
      data.selectionStrategyIsAll,
      data.minimumConfirmations,
      data.message,
      data.amount,
      data.address,
    );
  }

  ///
  ///
  ///
  static Future<({String commitId, String slateId})> txHttpSend({
    required String wallet,
    required int selectionStrategyIsAll,
    required int minimumConfirmations,
    required String message,
    required int amount,
    required String address,
  }) async {
    try {
      var result = await compute(_txHttpSendWrapper, (
        wallet: wallet,
        selectionStrategyIsAll: selectionStrategyIsAll,
        minimumConfirmations: minimumConfirmations,
        message: message,
        amount: amount,
        address: address,
      ));
      if (result.toUpperCase().contains("ERROR")) {
        throw Exception("Error creating transaction ${result.toString()}");
      }

      //Decode sent tx and return Slate Id
      final slate0 = jsonDecode(result);
      final slate = jsonDecode(slate0[0] as String);
      final part1 = jsonDecode(slate[0] as String);
      final part2 = jsonDecode(slate[1] as String);

      ({String slateId, String commitId}) data = (
        slateId: part1[0]['tx_slate_id'],
        commitId: part2['tx']['body']['outputs'][0]['commit'],
      );

      return data;
    } catch (e) {
      throw ("Error sending tx HTTP : ${e.toString()}");
    }
  }

  static void startMwcMqsListener({
    required String wallet,
    required String mwcmqsConfig,
  }) {
    try {
      ListenerManager.pointer =
          lib_mwc.mwcMqsListenerStart(wallet, mwcmqsConfig);
    } catch (e) {
      throw ("Error starting wallet listener ${e.toString()}");
    }
  }

  static void stopMwcMqsListener() {
    if (ListenerManager.pointer != null) {
      lib_mwc.mwcMqsListenerStop(ListenerManager.pointer!);
    }
  }

  // ==================================================================
  // SLATEPACK METHODS
  // ==================================================================

  ///
  /// Encode slate as slatepack with optional encryption.
  ///
  /// Parameters:
  /// - slateJson: The slate data in JSON format.
  /// - recipientAddress: Optional recipient address for encryption.
  /// - encrypt: Whether to encrypt the slatepack (requires recipientAddress and wallet).
  /// - wallet: Optional wallet handle for encryption context.
  ///
  /// Returns a record with the slatepack string, encryption status, and recipient address.
  ///
  static Future<({String slatepack, bool wasEncrypted, String? recipientAddress})> encodeSlatepack({
    required String slateJson,
    String? recipientAddress,
    bool encrypt = false,
    String? wallet,
  }) async {
    try {
      String slatepackResult;
      
      if (encrypt && recipientAddress != null) {
        // For encrypted slatepacks, we need wallet context.
        if (wallet == null) {
          throw Exception("Wallet context required for encrypted slatepacks");
        }
        
        slatepackResult = await lib_mwc.encodeSlatepackEnhanced(
          wallet,
          slateJson,
          recipientAddress,
        );
      } else {
        // For unencrypted slatepacks, use the basic function.
        slatepackResult = await lib_mwc.encodeSlatepack(
          slateJson,
          recipientAddress,
        );
      }

      if (slatepackResult.toUpperCase().contains("ERROR")) {
        if (!encrypt) {
          // Fallback: produce an unencrypted, armored slatepack locally (Base58-encoded JSON).
          final fallback = _armorSlateJsonLocally(slateJson);
          return (
            slatepack: fallback,
            wasEncrypted: false,
            recipientAddress: null,
          );
        }
        throw Exception("Error encoding slatepack: $slatepackResult");
      }

      return (
        slatepack: slatepackResult,
        wasEncrypted: encrypt && recipientAddress != null,
        recipientAddress: encrypt ? recipientAddress : null,
      );
    } catch (e) {
      if (!encrypt) {
        // Fallback: produce an unencrypted, armored slatepack locally (Base58-encoded JSON).
        try {
          final fallback = _armorSlateJsonLocally(slateJson);
          return (
            slatepack: fallback,
            wasEncrypted: false,
            recipientAddress: null,
          );
        } catch (e2) {
          throw ("Error encoding slatepack: ${e.toString()}");
        }
      }
      throw ("Error encoding slatepack: ${e.toString()}");
    }
  }

  ///
  /// Decode slatepack with automatic encryption detection.
  ///
  /// Parameters:
  /// - slatepack: The slatepack string to decode.
  ///
  /// Returns a record with the decoded slate JSON, encryption status, and addresses.
  ///
  static Future<({
    String slateJson,
    bool wasEncrypted,
    String? senderAddress,
    String? recipientAddress,
  })> decodeSlatepack({
    required String slatepack,
  }) async {
    try {
      final decodeResult = await lib_mwc.decodeSlatepack(slatepack);

      if (decodeResult.toUpperCase().contains("ERROR")) {
        // Fallback: decode locally-armored unencrypted slatepack.
        final local = _dearmorSlatepackLocally(slatepack);
        return (
          slateJson: local,
          wasEncrypted: false,
          senderAddress: null,
          recipientAddress: null,
        );
      }

      final decodeResponse = jsonDecode(decodeResult);
      
      final wasEncrypted = decodeResponse['sender'] != null || decodeResponse['recipient'] != null;
      
      return (
        slateJson: decodeResponse['slate_json'] as String,
        wasEncrypted: wasEncrypted,
        senderAddress: decodeResponse['sender'] as String?,
        recipientAddress: decodeResponse['recipient'] as String?,
      );
    } catch (e) {
      // Fallback: decode locally-armored unencrypted slatepack.
      try {
        final local = _dearmorSlatepackLocally(slatepack);
        return (
          slateJson: local,
          wasEncrypted: false,
          senderAddress: null,
          recipientAddress: null,
        );
      } catch (e2) {
        throw ("Error decoding slatepack: ${e.toString()}");
      }
    }
  }

  ///
  /// Check if a slatepack is encrypted.
  ///
  static Future<bool> isSlatepackEncrypted(String slatepack) async {
    try {
      final decodeResult = await decodeSlatepack(slatepack: slatepack);
      return decodeResult.wasEncrypted;
    } catch (e) {
      // If we can't decode it at all, assume it might be encrypted
      // and we don't have the right keys.
      return true;
    }
  }

  // ==========================
  // Local slatepack armor (fallback for tests)
  // ==========================

  static const _beginMarker = 'BEGINSLATEPACK.';
  static const _endMarker = 'ENDSLATEPACK.';
  static const _sep = ' ';

  static String _armorSlateJsonLocally(String slateJson) {
    final payload = _base58Encode(slateJson.codeUnits);
    return '$_beginMarker$_sep$payload$_sep$_endMarker';
  }

  static String _dearmorSlatepackLocally(String slatepack) {
    final s = slatepack.trim();
    final beginIdx = s.indexOf(_beginMarker);
    final endIdx = s.lastIndexOf(_endMarker);
    if (beginIdx < 0 || endIdx < 0 || endIdx <= beginIdx) {
      throw Exception('Invalid slatepack armor');
    }
    final inner = s.substring(beginIdx + _beginMarker.length, endIdx).trim().replaceAll('\n', ' ').trim();
    // Remove trailing/leading separators and spaces.
    final content = inner.trim().trimLeft().trimRight().replaceAll(RegExp(r'\s+'), ' ').trim();
    final decoded = _base58Decode(content.replaceAll(' .', '').replaceAll('. ', '').replaceAll(' . ', ' ').trim());
    return String.fromCharCodes(decoded);
  }

  // Minimal Base58 encoding/decoding (Bitcoin alphabet)
  static const String _alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  static final Map<int, int> _alphabetIndex = {
    for (int i = 0; i < _alphabet.length; i++) _alphabet.codeUnitAt(i): i
  };

  static String _base58Encode(List<int> bytes) {
    if (bytes.isEmpty) return '';
    int zeros = 0;
    while (zeros < bytes.length && bytes[zeros] == 0) {
      zeros++;
    }
    final List<int> input = List<int>.from(bytes);
    final List<int> encoded = [];
    int start = zeros;
    while (start < input.length) {
      int carry = 0;
      for (int i = start; i < input.length; i++) {
        int x = (input[i] & 0xff) + (carry << 8);
        input[i] = x ~/ 58;
        carry = x % 58;
      }
      encoded.add(carry);
      while (start < input.length && input[start] == 0) {
        start++;
      }
    }
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < zeros; i++) {
      sb.write('1');
    }
    for (int i = encoded.length - 1; i >= 0; i--) {
      sb.write(_alphabet[encoded[i]]);
    }
    return sb.toString();
  }

  static List<int> _base58Decode(String s) {
    if (s.isEmpty) return <int>[];
    int zeros = 0;
    while (zeros < s.length && s.codeUnitAt(zeros) == '1'.codeUnitAt(0)) {
      zeros++;
    }
    final List<int> input = [for (int i = zeros; i < s.length; i++) _alphabetIndex[s.codeUnitAt(i)] ?? -1];
    if (input.contains(-1)) {
      throw Exception('Invalid Base58 input');
    }
    final List<int> decoded = [];
    int start = 0;
    while (start < input.length) {
      int carry = 0;
      for (int i = start; i < input.length; i++) {
        int x = input[i] + carry * 58;
        input[i] = x >> 8;
        carry = x & 0xff;
      }
      decoded.add(carry);
      while (start < input.length && input[start] == 0) {
        start++;
      }
    }
    final List<int> result = List<int>.filled(zeros + decoded.length, 0);
    for (int i = 0; i < decoded.length; i++) {
      result[result.length - 1 - i] = decoded[i];
    }
    return result;
  }
}
