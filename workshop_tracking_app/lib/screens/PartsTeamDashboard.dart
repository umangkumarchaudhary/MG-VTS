import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PartsTeamDashboard extends StatefulWidget {
  final String token;
  const PartsTeamDashboard({Key? key, required this.token}) : super(key: key);

  @override
  State<PartsTeamDashboard> createState() => _PartsTeamDashboardState();
}

class _PartsTeamDashboardState extends State<PartsTeamDashboard> {
  String? scannedVehicleNumber;
  DateTime? selectedDate;
  final TextEditingController poNumberController = TextEditingController();
  bool isLoading = false;

  final backendUrl = 'http://192.168.9.77:5000/api/vehicle-check';

  @override
  void dispose() {
    poNumberController.dispose();
    super.dispose();
  }

  Future<void> scanQRCode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
    if (barcode != null && mounted) {
      setState(() {
        scannedVehicleNumber = barcode;
      });
    }
  }

  Future<void> _sendPartsEstimation(String eventType) async {
    if (scannedVehicleNumber == null) {
      _showError('Please scan the vehicle QR code first.');
      return;
    }
    setState(() => isLoading = true);
    try {
      final body = {
        "vehicleNumber": scannedVehicleNumber,
        "stage": "partsEstimation",
        "eventType": eventType,
      };
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        _showSuccess('Parts Estimation $eventType successful!');
      } else {
        _showError('Failed: ${response.body}');
      }
    } catch (e) {
      _showError('Error: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> _sendPartsOrder() async {
    if (scannedVehicleNumber == null) {
      _showError('Please scan the vehicle QR code first.');
      return;
    }
    if (selectedDate == null) {
      _showError('Please select parts arrival date.');
      return;
    }
    if (poNumberController.text.trim().isEmpty) {
      _showError('Please enter PO Number.');
      return;
    }
    setState(() => isLoading = true);
    try {
      final body = {
        "vehicleNumber": scannedVehicleNumber,
        "stage": "partsOrder",
        "eventType": "Start",
        "deliveryTime": selectedDate!.toIso8601String(),
        "poNumber": poNumberController.text.trim(),
      };
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        _showSuccess('Parts Order submitted!');
      } else {
        _showError('Failed: ${response.body}');
      }
    } catch (e) {
      _showError('Error: $e');
    }
    setState(() => isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parts Team Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Number (scan only)',
                      hintText: 'Scan QR to fill',
                    ),
                    controller: TextEditingController(text: scannedVehicleNumber ?? ''),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: isLoading ? null : scanQRCode,
                ),
              ],
            ),
            const SizedBox(height: 24),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parts Estimation', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: isLoading ? null : () => _sendPartsEstimation('Start'),
                          child: const Text('Start Parts Estimation'),
                        ),
                        ElevatedButton(
                          onPressed: isLoading ? null : () => _sendPartsEstimation('End'),
                          child: const Text('End Parts Estimation'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parts Order Status', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(selectedDate == null
                          ? 'Select Parts Arrival Date'
                          : 'Arrival Date: ${selectedDate!.toLocal().toString().split(' ')[0]}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: isLoading
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null && mounted) setState(() => selectedDate = picked);
                            },
                    ),
                    TextFormField(
                      controller: poNumberController,
                      decoration: const InputDecoration(labelText: 'PO Number'),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: isLoading ? null : _sendPartsOrder,
                      child: const Text('Submit Parts Order Status'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool isScanned = false;
  final MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Vehicle QR')),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final barcode = capture.barcodes.first;
          if (!isScanned && barcode.rawValue != null) {
            isScanned = true;
            Navigator.pop(context, barcode.rawValue!);
          }
        },
      ),
    );
  }
}