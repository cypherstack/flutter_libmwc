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
}

/// Exception thrown during testing.
class TestException implements Exception {
  final String message;
  
  const TestException(this.message);
  
  @override
  String toString() => 'TestException: $message';
}
