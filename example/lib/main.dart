import 'package:flutter/material.dart';

import 'services/ffi_test_service.dart';
import 'services/wallet_service.dart';
import 'views/test_runner_view.dart';
import 'views/wallet_home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check for test mode environment variable.
  const bool testMode = bool.fromEnvironment('test', defaultValue: false);

  // Initialize the FFI test framework.
  await FFITestService.initialize();
  await WalletService.initialize();

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
        cardTheme: const CardThemeData(
          elevation: 4,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      home: testMode ? const TestRunnerView() : const MainNavigationView(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigationView extends StatefulWidget {
  const MainNavigationView({super.key});

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_libmwc example'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.account_balance_wallet),
              text: 'Wallet Demo',
            ),
            Tab(
              icon: Icon(Icons.science),
              text: 'FFI Tests',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          WalletHomeView(),
          TestRunnerView(),
        ],
      ),
    );
  }
}
