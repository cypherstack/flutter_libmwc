import 'package:flutter/material.dart';

import '../services/ffi_test_service.dart';
import '../models/test_result.dart';

/// Main test runner view for FFI integration tests.
class TestRunnerView extends StatefulWidget {
  const TestRunnerView({super.key});

  @override
  State<TestRunnerView> createState() => _TestRunnerViewState();
}

class _TestRunnerViewState extends State<TestRunnerView> {
  bool _isRunningTests = false;
  List<TestResult> _testResults = [];
  String _overallStatus = 'Ready';
  
  @override
  void initState() {
    super.initState();
    // Run tests automatically after the first frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAllTests();
    });
  }
  
  Future<void> _runAllTests() async {
    setState(() {
      _isRunningTests = true;
      _overallStatus = 'Running tests...';
    });
    
    try {
      final success = await FFITestService.runAllTests();
      
      setState(() {
        _testResults = FFITestService.testResults;
        _overallStatus = success ? 'All tests passed' : 'Some tests failed';
      });
      
    } catch (e) {
      setState(() {
        _overallStatus = 'Test execution failed: $e';
      });
    } finally {
      setState(() {
        _isRunningTests = false;
      });
    }
  }
  
  void _clearResults() {
    setState(() {
      _testResults.clear();
      _overallStatus = 'Results cleared';
    });
    FFITestService.clearResults();
  }
  
  void _showTestDetails(TestResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.name),
        content: SingleChildScrollView(
          child: Text(
            result.passed 
                ? 'Result: ${result.result}'
                : 'Error: ${result.error}',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MWC FFI Integration Tests'),
      ),
      body: Column(
        children: [
          _buildStatusCard(),
          _buildControlPanel(),
          Expanded(child: _buildResultsList()),
        ],
      ),
    );
  }
  
  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Environment Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('Status: $_overallStatus'),
            Text('Tests Completed: ${_testResults.length}'),
            Text(
              'Pass Rate: ${_testResults.isEmpty ? 'N/A' : '${_testResults.where((r) => r.passed).length}/${_testResults.length}'}',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isRunningTests ? null : _runAllTests,
                icon: _isRunningTests
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isRunningTests ? 'Running Tests...' : 'Run All Tests'),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _testResults.isEmpty ? null : _clearResults,
              icon: const Icon(Icons.clear),
              label: const Text('Clear Results'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultsList() {
    if (_testResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No test results available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Run the test suite to see integration test results',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _testResults.length,
      itemBuilder: (context, index) {
        final result = _testResults[index];
        return Card(
          child: ListTile(
            leading: Icon(
              result.passed ? Icons.check_circle : Icons.error,
              color: result.passed ? Colors.green : Colors.red,
              size: 32,
            ),
            title: Text(
              result.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.description),
                const SizedBox(height: 4),
                Text(
                  'Duration: ${result.duration.inMilliseconds}ms',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.visibility, color: Colors.blue),
            onTap: () => _showTestDetails(result),
          ),
        );
      },
    );
  }
}
