import 'package:flutter/material.dart';
import '../services/wallet_service.dart';

class OpenWalletView extends StatefulWidget {
  const OpenWalletView({super.key});

  @override
  State<OpenWalletView> createState() => _OpenWalletViewState();
}

class _OpenWalletViewState extends State<OpenWalletView> {
  final _formKey = GlobalKey<FormState>();
  final _walletNameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isOpening = false;

  @override
  void dispose() {
    _walletNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _openWallet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isOpening = true;
    });

    try {
      final result = await WalletService.openWallet(
        walletName: _walletNameController.text.trim(),
        password: _passwordController.text,
      );

      if (result.success) {
        _showSuccessDialog();
      } else {
        _showErrorDialog(result.error ?? 'Unknown error occurred');
      }
    } catch (e) {
      _showErrorDialog('Failed to open wallet: $e');
    } finally {
      setState(() {
        _isOpening = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Wallet Opened'),
        content: Text('Wallet "${_walletNameController.text}" has been opened successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Wallet'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wallet Credentials',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _walletNameController,
                        decoration: const InputDecoration(
                          labelText: 'Wallet Name',
                          hintText: 'Enter your wallet name',
                          prefixIcon: Icon(Icons.account_balance_wallet),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your wallet name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your wallet password',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isOpening ? null : _openWallet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isOpening
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Opening Wallet...'),
                          ],
                        )
                      : const Text(
                          'Open Wallet',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}