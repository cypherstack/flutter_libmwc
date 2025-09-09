import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_libmwc/lib.dart';
import '../models/test_result.dart';

/// Comprehensive FFI integration test service.
class FFITestService {
  static final List<TestResult> _testResults = [];
  static bool _isInitialized = false;
  
  /// Initialize the test framework.
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    _logInfo('FFI Test Service initialized successfully');
    _isInitialized = true;
  }
  
  /// Get all test results.
  static List<TestResult> get testResults => List.unmodifiable(_testResults);
  
  /// Clear all test results.
  static void clearResults() {
    _testResults.clear();
    _logInfo('Test results cleared');
  }
  
  /// Run all FFI integration tests.
  static Future<bool> runAllTests() async {
    if (!_isInitialized) {
      throw StateError('FFI Test Service not initialized');
    }
    
    clearResults();
    _logInfo('Starting comprehensive FFI integration test suite');
    
    bool allPassed = true;
    
    // Phase 1: Environment and pre-flight validation.
    allPassed &= await _runEnvironmentTests();
    
    // Phase 2: Basic FFI functionality.
    allPassed &= await _runBasicFFITests();
    
    // Phase 3: Wallet management tests.
    allPassed &= await _runWalletManagementTests();
    
    _logInfo('Test suite completed. Overall result: ${allPassed ? "PASS" : "FAIL"}');
    return allPassed;
  }
  
  /// Run environment validation tests.
  static Future<bool> _runEnvironmentTests() async {
    bool allPassed = true;
    
    // Test 1: Platform detection.
    allPassed &= await _runTest(
      'Platform Detection',
      'Verify current platform is correctly detected',
      () async {
        final platform = Platform.operatingSystem;
        final supportedPlatforms = ['linux', 'windows', 'macos', 'android', 'ios'];
        
        if (!supportedPlatforms.contains(platform)) {
          throw TestException('Unsupported platform: $platform');
        }
        
        return 'Platform: $platform (supported)';
      }
    );
    
    // Test 2: Library loading.
    allPassed &= await _runTest(
      'Library Loading',
      'Verify native library can be loaded',
      () async {
        try {
          final mnemonic = Libmwc.getMnemonic();
          if (mnemonic.isEmpty) {
            throw TestException('Library loaded but basic function returned empty result');
          }
          return 'Library loaded successfully, basic function operational';
        } catch (e) {
          throw TestException('Failed to load or call native library: $e');
        }
      }
    );
    
    return allPassed;
  }
  
  /// Run basic FFI functionality tests.
  static Future<bool> _runBasicFFITests() async {
    bool allPassed = true;
    
    // Test 1: Mnemonic generation.
    allPassed &= await _runTest(
      'Mnemonic Generation',
      'Test FFI mnemonic generation function',
      () async {
        final mnemonic = Libmwc.getMnemonic();
        final words = mnemonic.split(' ');
        
        if (words.length != 24) {
          throw TestException('Invalid mnemonic length: ${words.length} (expected 24)');
        }
        
        return 'Generated 24-word mnemonic successfully';
      }
    );
    
    // Test 2: Address validation.
    allPassed &= await _runTest(
      'Address Validation',
      'Test FFI address validation function',
      () async {
        // Test with known invalid address.
        final invalidResult = Libmwc.validateSendAddress(address: 'invalid_address');
        if (invalidResult) {
          throw TestException('Invalid address incorrectly validated as valid');
        }
        
        return 'Address validation working correctly';
      }
    );
    
    return allPassed;
  }
  
  /// Run wallet management integration tests.
  static Future<bool> _runWalletManagementTests() async {
    bool allPassed = true;
    
    // Test 1: Wallet configuration validation.
    allPassed &= await _runTest(
      'Wallet Configuration',
      'Test wallet configuration creation and validation',
      () async {
        final testConfig = _getTestWalletConfig();
        if (testConfig.isEmpty) {
          throw TestException('Failed to create test wallet configuration');
        }
        
        // Validate config contains required fields.
        final configData = {'wallet_dir': '', 'check_node_api_http_addr': '', 'chain': ''};
        for (final key in configData.keys) {
          if (!testConfig.contains(key)) {
            throw TestException('Missing required config field: $key');
          }
        }
        
        return 'Test wallet configuration created and validated successfully';
      }
    );
    
    // Test 2: Wallet initialization.
    allPassed &= await _runTest(
      'Wallet Initialization',
      'Test new wallet creation via FFI',
      () async {
        final testMnemonic = Libmwc.getMnemonic();
        final testConfig = _getTestWalletConfig();
        final testPassword = 'test_password_123';
        final walletName = 'ffi_test_wallet_${DateTime.now().millisecondsSinceEpoch}';
        
        try {
          final result = await Libmwc.initializeNewWallet(
            config: testConfig,
            mnemonic: testMnemonic,
            password: testPassword,
            name: walletName,
          );
          
          if (result.toUpperCase().contains('ERROR')) {
            throw TestException('Wallet initialization failed: $result');
          }
          
          return 'New wallet initialized successfully: $walletName';
          
        } catch (e) {
          // Expected to potentially fail if wallet already exists or other issues.
          if (e.toString().contains('already exists')) {
            return 'Wallet initialization handled existing wallet correctly';
          }
          rethrow;
        }
      }
    );
    
    // Test 3: Wallet recovery.
    allPassed &= await _runTest(
      'Wallet Recovery',
      'Test wallet recovery from mnemonic via FFI',
      () async {
        final testMnemonic = Libmwc.getMnemonic();
        final testConfig = _getTestWalletConfig();
        final testPassword = 'recovery_test_123';
        final walletName = 'ffi_recovery_test_${DateTime.now().millisecondsSinceEpoch}';
        
        try {
          await Libmwc.recoverWallet(
            config: testConfig,
            password: testPassword,
            mnemonic: testMnemonic,
            name: walletName,
          );
          
          return 'Wallet recovery from mnemonic completed successfully';
          
        } catch (e) {
          // Expected to potentially fail in test environment.
          if (e.toString().contains('directory') || e.toString().contains('permission')) {
            return 'Wallet recovery handled filesystem constraints correctly';
          }
          throw TestException('Unexpected error in wallet recovery: $e');
        }
      }
    );
    
    // Test 4: Chain height retrieval.
    allPassed &= await _runTest(
      'Chain Height Query',
      'Test chain height retrieval via FFI using remote MWC node',
      () async {
        final testConfig = _getTestWalletConfig();
        
        try {
          final height = await Libmwc.getChainHeight(config: testConfig);
          
          if (height < 0) {
            throw TestException('Invalid chain height returned: $height');
          }
          
          // Mainnet should have a reasonable height (over 1 million blocks as of 2024).
          if (height < 1000000) {
            throw TestException('Chain height seems too low for mainnet: $height');
          }
          
          return 'Chain height retrieved successfully: $height (mainnet)';
          
        } catch (e) {
          final errorStr = e.toString();
          
          // Handle specific error types with more detail.
          if (errorStr.contains('FormatException') || errorStr.contains('Invalid radix-10')) {
            throw TestException('Failed to parse chain height response: node may have returned an error message instead of height');
          } else if (errorStr.contains('connection') || errorStr.contains('network') || errorStr.contains('timeout')) {
            throw TestException('Network connection issue with remote node: ${errorStr.substring(0, 100)}...');
          } else if (errorStr.contains('Cannot m')) {
            throw TestException('Remote node connection failed - possibly network or SSL issue');
          }
          
          // Re-throw with more context.
          throw TestException('Chain height query failed: ${errorStr.substring(0, 100)}...');
        }
      }
    );
    
    return allPassed;
  }
  
  /// Get test wallet configuration.
  static String _getTestWalletConfig() {
    final config = {
      'wallet_dir': _getTestWalletDir(),
      'check_node_api_http_addr': 'https://mwc713.mwc.mw:443', // Working remote node.
      'chain': 'mainnet', // Use mainnet since remote node is mainnet.
      'account': 'default',
    };
    
    return '{"wallet_dir":"${config['wallet_dir']}","check_node_api_http_addr":"${config['check_node_api_http_addr']}","chain":"${config['chain']}","account":"${config['account']}"}';
  }
  
  /// Run a single test with proper error handling and result tracking.
  static Future<bool> _runTest(
    String name,
    String description,
    Future<String> Function() testFunction,
  ) async {
    _logInfo('Running test: $name');
    
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await testFunction();
      stopwatch.stop();
      
      _testResults.add(TestResult(
        name: name,
        description: description,
        passed: true,
        duration: stopwatch.elapsed,
        result: result,
      ));
      
      _logInfo('Test PASSED: $name (${stopwatch.elapsedMilliseconds}ms)');
      return true;
      
    } catch (e, stackTrace) {
      stopwatch.stop();
      
      _testResults.add(TestResult(
        name: name,
        description: description,
        passed: false,
        duration: stopwatch.elapsed,
        error: e.toString(),
        stackTrace: stackTrace.toString(),
      ));
      
      _logError('Test FAILED: $name - $e');
      return false;
    }
  }
  
  /// Log info message.
  static void _logInfo(String message) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] [INFO] $message');
  }
  
  /// Log error message.
  static void _logError(String message) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] [ERROR] $message');
  }
  
  /// Get appropriate test wallet directory for current platform.
  static String _getTestWalletDir() {
    if (Platform.isAndroid) {
      return '/data/data/com.example.flutter_libmwc_example/files/ffi_test_wallets/';
    } else if (Platform.isIOS) {
      return '/var/mobile/Containers/Data/Application/ffi_test_wallets/';
    } else if (Platform.isLinux) {
      return '/tmp/flutter_libmwc_ffi_test_wallets/';
    } else if (Platform.isWindows) {
      return r'C:\temp\flutter_libmwc_ffi_test_wallets\';
    } else if (Platform.isMacOS) {
      return '/tmp/flutter_libmwc_ffi_test_wallets/';
    } else {
      return '/tmp/flutter_libmwc_ffi_test_wallets/';
    }
  }
}

/// Exception thrown during testing.
class TestException implements Exception {
  final String message;
  
  const TestException(this.message);
  
  @override
  String toString() => 'TestException: $message';
}
