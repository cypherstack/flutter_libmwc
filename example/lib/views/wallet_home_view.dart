import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import 'create_wallet_view.dart';
import 'open_wallet_view.dart';
import 'restore_wallet_view.dart';
import 'wallet_info_view.dart';
import 'slatepack_demo_view.dart';
import 'transaction_view.dart';

/// Main wallet demo interface that provides interactive wallet functionality.
class WalletHomeView extends StatefulWidget {
  const WalletHomeView({super.key});

  @override
  State<WalletHomeView> createState() => _WalletHomeViewState();
}

class _WalletHomeViewState extends State<WalletHomeView> {
  bool _isWalletOpen = false;
  String? _currentWalletName;

  @override
  void initState() {
    super.initState();
    _checkWalletStatus();
  }

  @override
  void didUpdateWidget(WalletHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkWalletStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWalletStatus();
    });
  }

  void _checkWalletStatus() {
    setState(() {
      _isWalletOpen = WalletService.hasOpenWallet;
      _currentWalletName = WalletService.currentWalletName;
    });
  }

  Widget _buildMenuButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    bool enabled = true,
  }) {
    final isEnabled = enabled && onPressed != null;
    final effectiveBackgroundColor =
        backgroundColor ?? Theme.of(context).primaryColor;

    return Card(
      child: ListTile(
        enabled: isEnabled,
        leading: CircleAvatar(
          backgroundColor:
              isEnabled ? effectiveBackgroundColor : Colors.grey.shade400,
          child: Icon(
            icon,
            color: isEnabled ? Colors.white : Colors.grey.shade600,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isEnabled ? null : Colors.grey.shade600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isEnabled ? null : Colors.grey.shade600,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isEnabled ? null : Colors.grey.shade400,
        ),
        onTap: isEnabled ? onPressed : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_isWalletOpen)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Wallet Open: ${_currentWalletName ?? "Unknown"}',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Wallet Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildMenuButton(
                  title: 'Create New Wallet',
                  subtitle: 'Generate a new MWC wallet with recovery phrase',
                  icon: Icons.add_circle,
                  backgroundColor: Colors.green,
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<dynamic>(
                        builder: (context) => const CreateWalletView(),
                      ),
                    );
                    _checkWalletStatus();
                  },
                ),
                _buildMenuButton(
                  title: 'Restore from Seed',
                  subtitle: 'Recover wallet from recovery phrase',
                  icon: Icons.restore,
                  backgroundColor: Colors.orange,
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<dynamic>(
                        builder: (context) => const RestoreWalletView(),
                      ),
                    );
                    _checkWalletStatus();
                  },
                ),
                _buildMenuButton(
                  title: 'Open Existing Wallet',
                  subtitle: 'Access your existing MWC wallet',
                  icon: Icons.folder_open,
                  backgroundColor: Colors.blue,
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<dynamic>(
                        builder: (context) => const OpenWalletView(),
                      ),
                    );
                    _checkWalletStatus();
                  },
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Wallet Operations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildMenuButton(
                  title: 'Wallet Information',
                  subtitle: _isWalletOpen
                      ? 'View balance, transactions, and wallet details'
                      : 'Open a wallet first to view information',
                  icon: Icons.info,
                  backgroundColor: Colors.teal,
                  enabled: _isWalletOpen,
                  onPressed: _isWalletOpen
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute<dynamic>(
                              builder: (context) => const WalletInfoView(),
                            ),
                          );
                        }
                      : null,
                ),
                _buildMenuButton(
                  title: 'Send Transaction',
                  subtitle: _isWalletOpen
                      ? 'Send MWC to another address'
                      : 'Open a wallet first to send transactions',
                  icon: Icons.send,
                  backgroundColor: Colors.indigo,
                  enabled: _isWalletOpen,
                  onPressed: _isWalletOpen
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute<dynamic>(
                              builder: (context) => const TransactionView(),
                            ),
                          );
                        }
                      : null,
                ),
                _buildMenuButton(
                  title: 'Slatepack Demo',
                  subtitle: _isWalletOpen
                      ? 'Demonstrate Slatepack encoding and sharing'
                      : 'Open a wallet first to use Slatepack features',
                  icon: Icons.qr_code,
                  backgroundColor: Colors.purple,
                  enabled: _isWalletOpen,
                  onPressed: _isWalletOpen
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute<dynamic>(
                              builder: (context) => const SlatepackDemoView(),
                            ),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'This wallet demo uses the same FFI functions as the test battery.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
