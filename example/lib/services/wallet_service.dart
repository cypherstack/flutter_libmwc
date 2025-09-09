import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_libmwc/lib.dart';

/// Wallet service that wraps the same FFI functions used in the test battery
/// to provide user-friendly wallet operations.
class WalletService {
  static bool _isInitialized = false;
  static String? _currentWalletHandle;
  static String? _currentWalletName;

/// Initialize the wallet service.
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    _logInfo('Wallet Service initialized successfully');
    _isInitialized = true;
  }

/// Create a new wallet using the same FFI functions as the test battery.
  static Future<WalletResult> createWallet({
    required String walletName,
    required String password,
    String? customMnemonic,
  }) async {
    try {
      _logInfo('Creating wallet: $walletName');
      
      // Use same configuration pattern as test battery.
      final config = _getWalletConfig(walletName);
      final mnemonic = customMnemonic ?? Libmwc.getMnemonic();
      
      // Use the same FFI function as test battery.
      final result = await Libmwc.initializeNewWallet(
        config: config,
        mnemonic: mnemonic,
        password: password,
        name: walletName,
      );
      
      if (result.toUpperCase().contains('ERROR')) {
        return WalletResult(
          success: false,
          error: 'Failed to create wallet: $result',
        );
      }
      
      // Store wallet handle for subsequent operations.
      _currentWalletHandle = result;
      _currentWalletName = walletName;
      
      _logInfo('Wallet created successfully: $walletName');
      return WalletResult(
        success: true,
        walletName: walletName,
        data: {'mnemonic': mnemonic, 'handle': result},
      );
      
    } catch (e) {
      _logError('Failed to create wallet: $e');
      return WalletResult(
        success: false,
        error: 'Failed to create wallet: $e',
      );
    }
  }

/// Recover wallet from mnemonic using same FFI functions as test battery.
  static Future<WalletResult> recoverWallet({
    required String walletName,
    required String password,
    required String mnemonic,
  }) async {
    try {
      _logInfo('Recovering wallet: $walletName');
      
      // Use same configuration pattern as test battery.
      final config = _getWalletConfig(walletName);
      
      // Use the same FFI function as test battery.
      await Libmwc.recoverWallet(
        config: config,
        password: password,
        mnemonic: mnemonic,
        name: walletName,
      );
      
      // After recovery, open the wallet to get handle.
      final openResult = await openWallet(
        walletName: walletName,
        password: password,
      );
      
      if (openResult.success) {
        _logInfo('Wallet recovered successfully: $walletName');
        return WalletResult(
          success: true,
          walletName: walletName,
          data: {'recovered': true},
        );
      }
      
      return openResult;
      
    } catch (e) {
      _logError('Failed to recover wallet: $e');
      return WalletResult(
        success: false,
        error: 'Failed to recover wallet: $e',
      );
    }
  }

/// Open an existing wallet using same FFI functions as test battery.
  static Future<WalletResult> openWallet({
    required String walletName,
    required String password,
  }) async {
    try {
      _logInfo('Opening wallet: $walletName');
      
      // Use same configuration pattern as test battery.
      final config = _getWalletConfig(walletName);
      
      // Use the same FFI function as test battery.
      final result = await Libmwc.openWallet(
        config: config,
        password: password,
      );
      
      if (result.toUpperCase().contains('ERROR')) {
        return WalletResult(
          success: false,
          error: 'Failed to open wallet: $result',
        );
      }
      
      // Store wallet handle for subsequent operations.
      _currentWalletHandle = result;
      _currentWalletName = walletName;
      
      _logInfo('Wallet opened successfully: $walletName');
      return WalletResult(
        success: true,
        walletName: walletName,
        data: {'handle': result},
      );
      
    } catch (e) {
      _logError('Failed to open wallet: $e');
      return WalletResult(
        success: false,
        error: 'Failed to open wallet: $e',
      );
    }
  }

/// Get wallet balance information using same FFI functions as test battery.
  static Future<WalletBalanceResult> getWalletBalance({
    int refreshFromNode = 1,
    int minimumConfirmations = 10,
  }) async {
    try {
      if (_currentWalletHandle == null) {
        return WalletBalanceResult(
          success: false,
          error: 'No wallet is currently open',
        );
      }

      _logInfo('Getting wallet balance');
      
      // Use the same FFI function as test battery.
      final balances = await Libmwc.getWalletBalances(
        wallet: _currentWalletHandle!,
        refreshFromNode: refreshFromNode,
        minimumConfirmations: minimumConfirmations,
      );
      
      _logInfo('Balance retrieved successfully');
      return WalletBalanceResult(
        success: true,
        spendable: balances.spendable,
        pending: balances.pending,
        total: balances.total,
        awaitingFinalization: balances.awaitingFinalization,
      );
      
    } catch (e) {
      _logError('Failed to get wallet balance: $e');
      return WalletBalanceResult(
        success: false,
        error: 'Failed to get wallet balance: $e',
      );
    }
  }

/// Get chain height using same FFI functions as test battery.
  static Future<int?> getChainHeight() async {
    try {
      if (_currentWalletName == null) {
        return null;
      }

      final config = _getWalletConfig(_currentWalletName!);
      return await Libmwc.getChainHeight(config: config);
      
    } catch (e) {
      _logError('Failed to get chain height: $e');
      return null;
    }
  }

/// Create a transaction using same FFI functions as test battery.
  static Future<TransactionResult> createTransaction({
    required int amount,
    required String address,
    required String note,
    int secretKeyIndex = 0,
    int minimumConfirmations = 10,
  }) async {
    try {
      if (_currentWalletHandle == null) {
        return TransactionResult(
          success: false,
          error: 'No wallet is currently open',
        );
      }

      _logInfo('Creating transaction');
      
      // Use same MWCMQS config pattern as test battery.
      final mwcmqsConfig = jsonEncode({
        'mwcmqs_domain': 'mqs.mwc.mw',
        'mwcmqs_port': 443,
        'mwcmqs_use_ssl': true,
      });
      
      // Use the same FFI function as test battery.
      final result = await Libmwc.createTransaction(
        wallet: _currentWalletHandle!,
        amount: amount,
        address: address,
        secretKeyIndex: secretKeyIndex,
        mwcmqsConfig: mwcmqsConfig,
        minimumConfirmations: minimumConfirmations,
        note: note,
      );
      
      _logInfo('Transaction created successfully');
      return TransactionResult(
        success: true,
        slateId: result.slateId,
        commitId: result.commitId,
      );
      
    } catch (e) {
      _logError('Failed to create transaction: $e');
      return TransactionResult(
        success: false,
        error: 'Failed to create transaction: $e',
      );
    }
  }

/// Encode slatepack using same FFI functions as test battery.
  static Future<SlatepackResult> encodeSlatepack({
    required String slateJson,
    String? recipientAddress,
    bool encrypt = false,
  }) async {
    try {
      _logInfo('Encoding slatepack');
      
      // Use the same FFI function as test battery.
      final result = await Libmwc.encodeSlatepack(
        slateJson: slateJson,
        recipientAddress: recipientAddress,
        encrypt: encrypt,
        wallet: _currentWalletHandle,
      );
      
      _logInfo('Slatepack encoded successfully');
      return SlatepackResult(
        success: true,
        slatepack: result.slatepack,
        wasEncrypted: result.wasEncrypted,
        recipientAddress: result.recipientAddress,
      );
      
    } catch (e) {
      _logError('Failed to encode slatepack: $e');
      return SlatepackResult(
        success: false,
        error: 'Failed to encode slatepack: $e',
      );
    }
  }

/// Decode slatepack using same FFI functions as test battery.
  static Future<SlatepackDecodeResult> decodeSlatepack({
    required String slatepack,
  }) async {
    try {
      _logInfo('Decoding slatepack');
      
      // Use the same FFI function as test battery.
      final result = await Libmwc.decodeSlatepack(
        slatepack: slatepack,
      );
      
      _logInfo('Slatepack decoded successfully');
      return SlatepackDecodeResult(
        success: true,
        slateJson: result.slateJson,
        wasEncrypted: result.wasEncrypted,
        senderAddress: result.senderAddress,
        recipientAddress: result.recipientAddress,
      );
      
    } catch (e) {
      _logError('Failed to decode slatepack: $e');
      return SlatepackDecodeResult(
        success: false,
        error: 'Failed to decode slatepack: $e',
      );
    }
  }

/// Start MWCMQS listener using same FFI functions as test battery.
  static void startMwcMqsListener() {
    try {
      if (_currentWalletHandle == null) {
        throw Exception('No wallet is currently open');
      }

      _logInfo('Starting MWCMQS listener');
      
      // Use same MWCMQS config pattern as test battery.
      final mwcmqsConfig = jsonEncode({
        'mwcmqs_domain': 'mqs.mwc.mw',
        'mwcmqs_port': 443,
        'mwcmqs_use_ssl': true,
      });
      
      // Use the same FFI function as test battery.
      Libmwc.startMwcMqsListener(
        wallet: _currentWalletHandle!,
        mwcmqsConfig: mwcmqsConfig,
      );
      
      _logInfo('MWCMQS listener started successfully');
      
    } catch (e) {
      _logError('Failed to start MWCMQS listener: $e');
      throw Exception('Failed to start MWCMQS listener: $e');
    }
  }

/// Stop MWCMQS listener using same FFI functions as test battery.
  static void stopMwcMqsListener() {
    try {
      _logInfo('Stopping MWCMQS listener');
      
      // Use the same FFI function as test battery.
      Libmwc.stopMwcMqsListener();
      
      _logInfo('MWCMQS listener stopped successfully');
      
    } catch (e) {
      _logError('Failed to stop MWCMQS listener: $e');
    }
  }

/// Generate a new mnemonic using same FFI functions as test battery.
  static String generateMnemonic() {
    try {
      // Use the same FFI function as test battery.
      return Libmwc.getMnemonic();
    } catch (e) {
      _logError('Failed to generate mnemonic: $e');
      throw Exception('Failed to generate mnemonic: $e');
    }
  }

/// Validate send address using same FFI functions as test battery.
  static bool validateSendAddress(String address) {
    try {
      // Use the same FFI function as test battery.
      return Libmwc.validateSendAddress(address: address);
    } catch (e) {
      _logError('Failed to validate address: $e');
      return false;
    }
  }

/// Get wallet configuration using same pattern as test battery.
  static String _getWalletConfig(String walletName) {
    final walletDir = _getWalletDirectory(walletName);
    
    // Use same configuration pattern as test battery.
    final config = {
      'wallet_dir': walletDir,
      'check_node_api_http_addr': 'https://mwc713.mwc.mw:443',
      'chain': 'mainnet',
      'account': 'default',
    };
    
    return jsonEncode(config);
  }

/// Get wallet directory path using same pattern as test battery.
  static String _getWalletDirectory(String walletName) {
    if (Platform.isAndroid) {
      return '/data/data/com.example.flutter_libmwc_example/files/wallets/$walletName/';
    } else if (Platform.isIOS) {
      return '/var/mobile/Containers/Data/Application/wallets/$walletName/';
    } else if (Platform.isLinux) {
      return '/tmp/flutter_libmwc_wallets/$walletName/';
    } else if (Platform.isWindows) {
      return r'C:\temp\flutter_libmwc_wallets\\' + walletName + r'\';
    } else if (Platform.isMacOS) {
      return '/tmp/flutter_libmwc_wallets/$walletName/';
    } else {
      return '/tmp/flutter_libmwc_wallets/$walletName/';
    }
  }

  // Getters for current wallet state.
  static String? get currentWalletName => _currentWalletName;
  static String? get currentWalletHandle => _currentWalletHandle;
  static bool get hasOpenWallet => _currentWalletHandle != null && _currentWalletName != null;

  /// Log info message.
  static void _logInfo(String message) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] [WALLET] [INFO] $message');
  }

  /// Log error message.
  static void _logError(String message) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] [WALLET] [ERROR] $message');
  }
}

/// Result classes for wallet operations.
class WalletResult {
  final bool success;
  final String? walletName;
  final String? error;
  final Map<String, dynamic>? data;

  WalletResult({
    required this.success,
    this.walletName,
    this.error,
    this.data,
  });
}

class WalletBalanceResult {
  final bool success;
  final String? error;
  final double? spendable;
  final double? pending;
  final double? total;
  final double? awaitingFinalization;

  WalletBalanceResult({
    required this.success,
    this.error,
    this.spendable,
    this.pending,
    this.total,
    this.awaitingFinalization,
  });
}

class TransactionResult {
  final bool success;
  final String? error;
  final String? slateId;
  final String? commitId;

  TransactionResult({
    required this.success,
    this.error,
    this.slateId,
    this.commitId,
  });
}

class SlatepackResult {
  final bool success;
  final String? error;
  final String? slatepack;
  final bool? wasEncrypted;
  final String? recipientAddress;

  SlatepackResult({
    required this.success,
    this.error,
    this.slatepack,
    this.wasEncrypted,
    this.recipientAddress,
  });
}

class SlatepackDecodeResult {
  final bool success;
  final String? error;
  final String? slateJson;
  final bool? wasEncrypted;
  final String? senderAddress;
  final String? recipientAddress;

  SlatepackDecodeResult({
    required this.success,
    this.error,
    this.slateJson,
    this.wasEncrypted,
    this.senderAddress,
    this.recipientAddress,
  });
}
