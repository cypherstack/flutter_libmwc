import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';

class SlatepackDemoView extends StatefulWidget {
  const SlatepackDemoView({super.key});

  @override
  State<SlatepackDemoView> createState() => _SlatepackDemoViewState();
}

class _SlatepackDemoViewState extends State<SlatepackDemoView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Encoding tab.
  final _slateJsonController = TextEditingController();
  final _recipientAddressController = TextEditingController();
  bool _encryptSlatepack = false;
  String? _encodedSlatepack;
  bool _isEncoding = false;
  
  // Decoding tab.
  final _slatepackController = TextEditingController();
  SlatepackDecodeResult? _decodedResult;
  bool _isDecoding = false;
  // Receive/finalize actions
  bool _isReceiving = false;
  bool _isFinalizing = false;
  ReceiveSlatepackResult? _receiveResult;
  FinalizeSlatepackResult? _finalizeResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setExampleSlateJson();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _slateJsonController.dispose();
    _recipientAddressController.dispose();
    _slatepackController.dispose();
    super.dispose();
  }

  void _setExampleSlateJson() {
    _slateJsonController.text = '''{
  "version_info": {
    "orig_version": 3,
    "version": 3,
    "block_header_version": 2
  },
  "id": "0436430c-2b02-624c-2032-570501212b00",
  "sta": "S1",
  "num_participants": 2,
  "amount": "1000000000",
  "fee": "1000000",
  "height": "0",
  "lock_height": "0",
  "ttl_cutoff_height": null,
  "payment_proof": null,
  "participant_data": [],
  "tx": {
    "offset": "0000000000000000000000000000000000000000000000000000000000000000",
    "body": {
      "inputs": [],
      "outputs": [],
      "kernels": []
    }
  }
}''';
  }

  Future<void> _encodeSlatepack() async {
    if (_slateJsonController.text.trim().isEmpty) {
      _showErrorDialog('Please enter slate JSON');
      return;
    }

    setState(() {
      _isEncoding = true;
      _encodedSlatepack = null;
    });

    try {
      final result = await WalletService.encodeSlatepack(
        slateJson: _slateJsonController.text.trim(),
        recipientAddress: _encryptSlatepack && _recipientAddressController.text.trim().isNotEmpty
            ? _recipientAddressController.text.trim()
            : null,
        encrypt: _encryptSlatepack,
      );

      if (result.success) {
        setState(() {
          _encodedSlatepack = result.slatepack;
        });
        _showSuccessSnackBar('Slatepack encoded successfully!');
      } else {
        _showErrorDialog(result.error ?? 'Unknown error occurred');
      }
    } catch (e) {
      _showErrorDialog('Failed to encode slatepack: $e');
    } finally {
      setState(() {
        _isEncoding = false;
      });
    }
  }

  Future<void> _decodeSlatepack() async {
    if (_slatepackController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a slatepack');
      return;
    }

    setState(() {
      _isDecoding = true;
      _decodedResult = null;
    });

    try {
      final result = await WalletService.decodeSlatepack(
        slatepack: _slatepackController.text.trim(),
      );

      setState(() {
        _decodedResult = result;
        _receiveResult = null;
        _finalizeResult = null;
      });

      if (result.success) {
        _showSuccessSnackBar('Slatepack decoded successfully!');
      } else {
        _showErrorDialog(result.error ?? 'Unknown error occurred');
      }
    } catch (e) {
      _showErrorDialog('Failed to decode slatepack: $e');
    } finally {
      setState(() {
        _isDecoding = false;
      });
    }
  }

  Future<void> _receiveCurrentSlatepack() async {
    if (_slatepackController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a slatepack');
      return;
    }

    setState(() {
      _isReceiving = true;
      _receiveResult = null;
    });

    try {
      final res = await WalletService.receiveSlatepack(
        slatepack: _slatepackController.text.trim(),
      );
      setState(() {
        _receiveResult = res;
      });
      if (res.success) {
        _showSuccessSnackBar('Received slatepack and built response');
      } else {
        _showErrorDialog(res.error ?? 'Failed to receive slatepack');
      }
    } catch (e) {
      _showErrorDialog('Failed to receive slatepack: $e');
    } finally {
      setState(() {
        _isReceiving = false;
      });
    }
  }

  Future<void> _finalizeCurrentSlatepack() async {
    if (_slatepackController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a slatepack');
      return;
    }

    setState(() {
      _isFinalizing = true;
      _finalizeResult = null;
    });

    try {
      final res = await WalletService.finalizeSlatepack(
        slatepack: _slatepackController.text.trim(),
      );
      setState(() {
        _finalizeResult = res;
      });
      if (res.success) {
        _showSuccessSnackBar('Finalized slatepack and posted transaction');
      } else {
        _showErrorDialog(res.error ?? 'Failed to finalize slatepack');
      }
    } catch (e) {
      _showErrorDialog('Failed to finalize slatepack: $e');
    } finally {
      setState(() {
        _isFinalizing = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
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

  Widget _buildEncodingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Slate JSON',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: _setExampleSlateJson,
                      child: const Text('Load Example'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _slateJsonController,
                  decoration: const InputDecoration(
                    labelText: 'Slate JSON',
                    hintText: 'Enter the slate JSON to encode',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 8,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encryption Options',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Encrypt Slatepack'),
                  subtitle: const Text('Encrypt for a specific recipient'),
                  value: _encryptSlatepack,
                  onChanged: (value) => setState(() {
                    _encryptSlatepack = value;
                  }),
                ),
                if (_encryptSlatepack) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _recipientAddressController,
                    decoration: const InputDecoration(
                      labelText: 'Recipient Address',
                      hintText: 'username@mqs.mwc.mw',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isEncoding ? null : _encodeSlatepack,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isEncoding
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
                    Text('Encoding...'),
                  ],
                )
              : const Text(
                  'Encode Slatepack',
                  style: TextStyle(fontSize: 16),
                ),
        ),
        if (_encodedSlatepack != null) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Encoded Slatepack',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.green.shade700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _copyToClipboard(_encodedSlatepack!, 'Slatepack'),
                        icon: const Icon(Icons.copy),
                        color: Colors.green.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.green.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _encodedSlatepack!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDecodingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Slatepack Input',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _slatepackController,
                  decoration: const InputDecoration(
                    labelText: 'Slatepack',
                    hintText: 'Paste a slatepack to decode',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 8,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isDecoding ? null : _decodeSlatepack,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isDecoding
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
                    Text('Decoding...'),
                  ],
                )
              : const Text(
                  'Decode Slatepack',
                  style: TextStyle(fontSize: 16),
                ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isReceiving ? null : _receiveCurrentSlatepack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isReceiving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Receive This Slatepack'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isFinalizing ? null : _finalizeCurrentSlatepack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isFinalizing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Finalize This Slatepack'),
              ),
            ),
          ],
        ),
        if (_decodedResult != null) ...[
          const SizedBox(height: 16),
          Card(
            color: _decodedResult!.success ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Decode Result',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _decodedResult!.success ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_decodedResult!.success) ...[
                    _buildResultRow('Status', 'Success', Colors.green),
                    _buildResultRow('Encrypted', _decodedResult!.wasEncrypted.toString(), Colors.blue),
                    if (_decodedResult!.senderAddress != null)
                      _buildResultRow('Sender', _decodedResult!.senderAddress!, Colors.orange),
                    if (_decodedResult!.recipientAddress != null)
                      _buildResultRow('Recipient', _decodedResult!.recipientAddress!, Colors.purple),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Slate JSON:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () => _copyToClipboard(_decodedResult!.slateJson!, 'Slate JSON'),
                          icon: const Icon(Icons.copy),
                          color: Colors.green.shade700,
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.green.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _decodedResult!.slateJson!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Error: ${_decodedResult!.error}',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (_receiveResult != null) ...[
          const SizedBox(height: 16),
          Card(
            color: _receiveResult!.success ? Colors.blue.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receive Result',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _receiveResult!.success ? Colors.blue.shade700 : Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_receiveResult!.success) ...[
                    _buildResultRow('Slate ID', _receiveResult!.slateId ?? '', Colors.blueGrey),
                    _buildResultRow('Commit ID', _receiveResult!.commitId ?? '', Colors.blueGrey),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Response Slatepack:', style: TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: () => _copyToClipboard(_receiveResult!.responseSlatepack ?? '', 'Response Slatepack'),
                          icon: const Icon(Icons.copy),
                          color: Colors.blue.shade700,
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.blue.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _receiveResult!.responseSlatepack ?? '',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ] else ...[
                    Text('Error: ${_receiveResult!.error}', style: TextStyle(color: Colors.red.shade700)),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (_finalizeResult != null) ...[
          const SizedBox(height: 16),
          Card(
            color: _finalizeResult!.success ? Colors.teal.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finalize Result',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _finalizeResult!.success ? Colors.teal.shade700 : Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_finalizeResult!.success) ...[
                    _buildResultRow('Slate ID', _finalizeResult!.slateId ?? '', Colors.blueGrey),
                    _buildResultRow('Commit ID', _finalizeResult!.commitId ?? '', Colors.blueGrey),
                  ] else ...[
                    Text('Error: ${_finalizeResult!.error}', style: TextStyle(color: Colors.red.shade700)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontFamily: value.length > 20 ? 'monospace' : null,
                fontSize: value.length > 20 ? 12 : 14,
              ),
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
        title: const Text('Slatepack Demo'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Encode'),
            Tab(text: 'Decode'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEncodingTab(),
          _buildDecodingTab(),
        ],
      ),
    );
  }
}
