import 'package:flutter/material.dart';
import 'services/ffi_test_service.dart';
import 'views/test_runner_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the FFI test framework.
  await FFITestService.initialize();
  
  runApp(const FFITestApp());
}

class FFITestApp extends StatelessWidget {
  const FFITestApp({super.key});

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
      home: const TestRunnerView(),
      debugShowCheckedModeBanner: false,
    );
  }
}
