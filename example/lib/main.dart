import 'package:flutter/material.dart';
import 'services/ffi_test_service.dart';
import 'views/test_runner_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check for test mode environment variable.
  const bool testMode = bool.fromEnvironment('test', defaultValue: false);
  
  // Initialize the FFI test framework.
  await FFITestService.initialize();
  
  runApp(FFITestApp(testMode: testMode));
}

class FFITestApp extends StatelessWidget {
  final bool testMode;
  
  const FFITestApp({super.key, this.testMode = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_libmwc example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: const CardTheme(
          elevation: 4,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      home: testMode ? const TestRunnerView() : const WelcomeView(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_libmwc example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TestRunnerView(),
                  ),
                );
              },
              icon: const Icon(Icons.science),
              label: const Text('Run FFI Integration Tests'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tip: Use --dart-define=test=true to launch directly into test mode',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Example: flutter run -d linux --dart-define=test=true',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
