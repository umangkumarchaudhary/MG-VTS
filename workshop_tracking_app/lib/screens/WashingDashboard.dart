import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';

// MG Automobile Theme Constants
const mgPrimaryColor = Color(0xFFE4002B); // MG's signature red
const mgSecondaryColor = Color(0xFF000000); // Black
const mgAccentColor = Color(0xFFF0F0F0); // Light gray
const mgTextColor = Color(0xFF333333); // Dark gray
const mgSuccessColor = Color(0xFF4CAF50); // Green
const mgWarningColor = Color(0xFFFFC107); // Amber
const mgErrorColor = Color(0xFFF44336); // Red

final mgTheme = ThemeData(
  primaryColor: mgPrimaryColor,
  colorScheme: const ColorScheme.light(
    primary: mgPrimaryColor,
    secondary: mgSecondaryColor,
    surface: Colors.white,
    background: mgAccentColor,
    error: mgErrorColor,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: mgPrimaryColor,
    foregroundColor: Colors.white,
    elevation: 4,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: mgPrimaryColor,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      textStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  cardTheme: const CardTheme(
    elevation: 2,
    margin: EdgeInsets.all(8),
  ),
);

class WashingDashboard extends StatefulWidget {
  final String token;
  const WashingDashboard({Key? key, required this.token}) : super(key: key);

  @override
  State<WashingDashboard> createState() => _WashingDashboardState();
}

class _WashingDashboardState extends State<WashingDashboard> {
  String? scannedVehicleNumber;
  String eventType = 'Start';
  bool isLoading = false;

  final vehicleController = TextEditingController();
  final backendUrl = 'http://192.168.9.77:5000/api/vehicle-check';

  @override
  void dispose() {
    vehicleController.dispose();
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
        vehicleController.text = barcode;
      });
    }
  }

  Future<void> submitWashingStatus() async {
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      final vehicleNumber = scannedVehicleNumber ?? vehicleController.text.trim();
      if (vehicleNumber.isEmpty) {
        showError('Please scan or enter a vehicle number');
        setState(() => isLoading = false);
        return;
      }

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'vehicleNumber': vehicleNumber,
          'stage': 'washing',
          'eventType': eventType,
          'role': 'Washer',
        }),
      );

      if (response.statusCode == 200) {
        _handleSuccess();
      } else {
        showError('Error: ${response.body}');
      }
    } catch (e) {
      showError('Submission failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _handleSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Washing status updated'),
        backgroundColor: mgSuccessColor,
      ),
    );
    vehicleController.clear();
    setState(() {
      scannedVehicleNumber = null;
      eventType = 'Start';
    });
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: mgErrorColor,
      ),
    );
  }

  void _viewWashingHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WashingHistoryScreen(token: widget.token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: mgTheme,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('MG Washing Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _viewWashingHistory,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // MG Brand Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Text(
                  'Vehicle Washing Station',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: mgPrimaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(color: mgPrimaryColor),

              // Vehicle Input Section
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: vehicleController,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Number',
                        labelStyle: TextStyle(color: mgTextColor),
                        prefixIcon: Icon(Icons.directions_car, color: mgPrimaryColor),
                      ),
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: scanQRCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mgSecondaryColor,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner),
                        SizedBox(width: 4),
                        Text('SCAN'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Action Selection
              const Text(
                'SELECT ACTION:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: mgTextColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: 'Start',
                    groupValue: eventType,
                    onChanged: (value) => setState(() => eventType = value!),
                    activeColor: mgPrimaryColor,
                  ),
                  const Text('Start Washing'),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: 'End',
                    groupValue: eventType,
                    onChanged: (value) => setState(() => eventType = value!),
                    activeColor: mgPrimaryColor,
                  ),
                  const Text('End Washing'),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: isLoading ? null : submitWashingStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: eventType == 'Start' ? mgPrimaryColor : mgSuccessColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        eventType == 'Start' ? 'START WASHING' : 'END WASHING',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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

class WashingHistoryScreen extends StatefulWidget {
  final String token;
  const WashingHistoryScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<WashingHistoryScreen> createState() => _WashingHistoryScreenState();
}

class _WashingHistoryScreenState extends State<WashingHistoryScreen> {
  List<dynamic> inProgress = [];
  List<dynamic> completed = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchWashingHistory();
  }

  Future<void> _fetchWashingHistory() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://192.168.9.77:5000/api/washing-history'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          inProgress = data['inProgress'] ?? [];
          completed = data['completed'] ?? [];
        });
      } else {
        setState(() {
          error = 'Failed to load data: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error fetching data: ${e.toString()}';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MG Washing History'),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchWashingHistory,
        backgroundColor: mgPrimaryColor,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: mgPrimaryColor));
    }

    if (error != null) {
      return Center(
        child: Text(
          error!,
          style: const TextStyle(color: mgErrorColor),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: mgPrimaryColor,
            child: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'In Progress'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildWashingList(inProgress, false),
                _buildWashingList(completed, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWashingList(List<dynamic> items, bool showDuration) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No washing records found',
          style: const TextStyle(color: mgTextColor),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_car, color: mgPrimaryColor),
                    const SizedBox(width: 8),
                    Text(
                      item['vehicleNumber'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: mgPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: mgTextColor),
                    const SizedBox(width: 4),
                    Text(
                      'Started: ${item['startTime']}',
                      style: const TextStyle(color: mgTextColor),
                    ),
                  ],
                ),
                if (showDuration && item['endTime'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer_off, size: 16, color: mgTextColor),
                      const SizedBox(width: 4),
                      Text(
                        'Ended: ${item['endTime']}',
                        style: const TextStyle(color: mgTextColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 16, color: mgTextColor),
                      const SizedBox(width: 4),
                      Text(
                        'Duration: ${item['durationMinutes']} minutes',
                        style: const TextStyle(
                          color: mgTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
      setState(() => isScanning = false);
      await cameraController.stop();
      Navigator.pop(context, barcodes.first.rawValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MG Vehicle QR Scanner'),
        backgroundColor: mgPrimaryColor,
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: _handleDetection,
      ),
    );
  }
}
