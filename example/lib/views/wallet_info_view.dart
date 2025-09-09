import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/wallet_service.dart';

class WalletInfoView extends StatefulWidget {
  const WalletInfoView({super.key});

  @override
  State<WalletInfoView> createState() => _WalletInfoViewState();
}

class _WalletInfoViewState extends State<WalletInfoView> {
  WalletBalanceResult? _balance;
  int? _chainHeight;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  Future<void> _loadWalletInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final balanceResult = await WalletService.getWalletBalance();
      final chainHeight = await WalletService.getChainHeight();

      setState(() {
        _balance = balanceResult;
        _chainHeight = chainHeight;
        if (!balanceResult.success) {
          _error = balanceResult.error;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load wallet info: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  String _formatMwc(double? amount) {
    if (amount == null) return 'N/A';
    return '${amount!.toStringAsFixed(9)} MWC';
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceRow(String label, double? amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          Text(
            _formatMwc(amount),
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Information'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadWalletInfo,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadWalletInfo,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildInfoCard(
                      'Wallet Details',
                      [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Name:',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            Row(
                              children: [
                                Text(
                                  WalletService.currentWalletName ?? 'Unknown',
                                  style:
                                      const TextStyle(fontFamily: 'monospace'),
                                ),
                                IconButton(
                                  onPressed: () => _copyToClipboard(
                                    WalletService.currentWalletName ?? '',
                                    'Wallet name',
                                  ),
                                  icon: const Icon(Icons.copy, size: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Status:',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Open',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildInfoCard(
                      'Balance Information',
                      _balance == null
                          ? [const Text('Loading...')]
                          : [
                              _buildBalanceRow('Spendable', _balance!.spendable,
                                  color: Colors.green),
                              _buildBalanceRow('Pending', _balance!.pending,
                                  color: Colors.orange),
                              _buildBalanceRow('Awaiting Finalization',
                                  _balance!.awaitingFinalization,
                                  color: Colors.blue),
                              const Divider(),
                              _buildBalanceRow('Total', _balance!.total,
                                  color: Colors.black),
                            ],
                    ),
                    _buildInfoCard(
                      'Network Information',
                      [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Chain Height:',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              _chainHeight?.toString() ?? 'N/A',
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Node:',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            const Text(
                              'mwc713.mwc.mw:443',
                              style: TextStyle(
                                  fontFamily: 'monospace', fontSize: 12),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Chain:',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            const Text(
                              'Mainnet',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
