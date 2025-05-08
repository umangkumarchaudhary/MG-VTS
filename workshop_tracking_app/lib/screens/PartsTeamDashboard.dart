import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class PartsTeamDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const PartsTeamDashboard({
    Key? key, 
    required this.token,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<PartsTeamDashboard> createState() => _PartsTeamDashboardState();
}

class _PartsTeamDashboardState extends State<PartsTeamDashboard> {
  String? scannedVehicleNumber;
  DateTime? selectedDate;
  final TextEditingController poNumberController = TextEditingController();
  bool isLoading = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final backendUrl = 'https://mg-vts-backend.onrender.com/api/vehicle-check';

  @override
  void dispose() {
    poNumberController.dispose();
    super.dispose();
  }

  // Toggle drawer function
  void _toggleDrawer() {
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      Navigator.pop(context);
    } else {
      _scaffoldKey.currentState!.openDrawer();
    }
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
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
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Parts Team Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _toggleDrawer,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text('Parts Team Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Scan Vehicle QR'),
              onTap: () {
                Navigator.pop(context);
                scanQRCode();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Vehicle Number',
                          prefixIcon: const Icon(Icons.directions_car),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        controller: TextEditingController(text: scannedVehicleNumber ?? ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, size: 32),
                      onPressed: isLoading ? null : scanQRCode,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Parts Estimation Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parts Estimation',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: isLoading ? null : () => _sendPartsEstimation('Start'),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Estimation'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(150, 50),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: isLoading ? null : () => _sendPartsEstimation('End'),
                          icon: const Icon(Icons.stop),
                          label: const Text('End Estimation'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(150, 50),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Parts Order Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parts Order',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        selectedDate == null
                            ? 'Select Arrival Date'
                            : 'Arrival: ${DateFormat('dd MMM yyyy').format(selectedDate!)}',
                      ),
                      leading: const Icon(Icons.calendar_today),
                      trailing: const Icon(Icons.arrow_drop_down),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      onTap: isLoading
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null && mounted) {
                                setState(() => selectedDate = picked);
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: poNumberController,
                      decoration: InputDecoration(
                        labelText: 'PO Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.confirmation_number),
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _sendPartsOrder,
                        icon: const Icon(Icons.send),
                        label: const Text('Submit Parts Order'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
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
      appBar: AppBar(
        title: const Text('Scan Vehicle QR'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final barcode = capture.barcodes.first;
              if (!isScanned && barcode.rawValue != null) {
                isScanned = true;
                Navigator.pop(context, barcode.rawValue!);
              }
            },
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Align the QR code within the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}