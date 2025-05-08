import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';

class DriverDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const DriverDashboard({
    Key? key,
    required this.token,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final TextEditingController vehicleController = TextEditingController();
  final TextEditingController kmController = TextEditingController();
  bool isLoading = false;

  final String backendUrl = 'https://mg-vts-backend.onrender.com/api/vehicle-check';

  Future<void> scanQRCode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
    if (barcode != null && mounted) {
      setState(() {
        vehicleController.text = barcode;
      });
    }
  }

  Future<void> sendPickup() async {
    final vehicleNumber = vehicleController.text.trim();
    final pickupKM = kmController.text.trim();

    if (vehicleNumber.isEmpty || pickupKM.isEmpty) {
      showSnackBar('Please enter vehicle number and pickup KM');
      return;
    }

    await _sendData({
      'vehicleNumber': vehicleNumber,
      'stage': 'pickupDrop',
      'eventType': 'Start',
      'role': 'Driver',
      'pickupKM': pickupKM,
    });
  }

  Future<void> sendDropOff() async {
    final vehicleNumber = vehicleController.text.trim();

    if (vehicleNumber.isEmpty) {
      showSnackBar('Please enter or scan vehicle number');
      return;
    }

    await _sendData({
      'vehicleNumber': vehicleNumber,
      'stage': 'driverDrop',
      'eventType': 'End',
      'role': 'Driver',
    });
  }

  Future<void> _sendData(Map<String, dynamic> body) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode(body),
      );

      final result = json.decode(response.body);
      if (response.statusCode == 200) {
        showSnackBar(result['message'] ?? 'Success', success: true);
        vehicleController.clear();
        kmController.clear();
      } else {
        showSnackBar(result['error'] ?? 'Failed');
      }
    } catch (e) {
      showSnackBar('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? Colors.green : Colors.red,
    ));
  }

  void openHistoryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverPickupDropSummary(token: widget.token),
      ),
    );
  }

  void _handleLogout() {
  print('[DEBUG] Logout button pressed'); // Debug statement 1
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () {
            print('[DEBUG] Logout cancelled'); // Debug statement 2
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            print('[DEBUG] Logout confirmed'); // Debug statement 3
            
            // First close the dialog
            Navigator.pop(context);
            
            // Add a small delay to ensure dialog is fully dismissed
            await Future.delayed(const Duration(milliseconds: 100));
            
            // Check if widget is still mounted
            if (!mounted) {
              print('[DEBUG] Widget not mounted, aborting logout');
              return;
            }
            
            print('[DEBUG] Calling onLogout callback');
            widget.onLogout();
          },
          child: const Text('Logout'),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            onPressed: openHistoryPage,
            icon: const Icon(Icons.history),
            tooltip: 'Driver History',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: vehicleController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Number',
                prefixIcon: Icon(Icons.directions_car),
                border: OutlineInputBorder(),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: scanQRCode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Vehicle QR'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: kmController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pickup KM',
                prefixIcon: Icon(Icons.speed),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isLoading ? null : sendPickup,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Start Pickup'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : sendDropOff,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('End Drop'),
                ),
              ],
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
  late final MobileScannerController cameraController;
  bool isScanning = true;

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 250,
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) async {
    if (!isScanning) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String code = barcodes.first.rawValue!;
      setState(() => isScanning = false);
      await cameraController.stop();
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MG Vehicle QR Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
            tooltip: 'Toggle Flash',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => cameraController.switchCamera(),
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: _handleDetection,
      ),
    );
  }
}

class DriverPickupDropSummary extends StatefulWidget {
  final String token;
  const DriverPickupDropSummary({super.key, required this.token});

  @override
  State<DriverPickupDropSummary> createState() => _DriverPickupDropSummaryState();
}

class _DriverPickupDropSummaryState extends State<DriverPickupDropSummary> {
  List<dynamic> summary = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSummary();
  }

  Future<void> fetchSummary() async {
    try {
      final response = await http.get(
        Uri.parse('https://mg-vts-backend.onrender.com/api/vehicle/driver-history'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          summary = json.decode(response.body);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load summary');
      }
    } catch (e) {
      setState(() {
        summary = [];
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver History')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : summary.isEmpty
              ? const Center(child: Text('No records found.'))
              : ListView.builder(
                  itemCount: summary.length,
                  itemBuilder: (context, index) {
                    final item = summary[index];
                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['vehicleNumber'] ?? 'Unknown',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const Divider(),
                            Text('Pickup Time: ${item['pickupTime'] ?? 'N/A'}'),
                            Text('Pickup KM: ${item['pickupKM'] ?? 'N/A'}'),
                            const SizedBox(height: 10),
                            Text('Drop Time: ${item['dropTime'] ?? 'N/A'}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
