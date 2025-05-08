import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';

class ServiceAdvisorDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const ServiceAdvisorDashboard({
    super.key, 
    required this.token,
    required this.onLogout,
  });

  @override
  State<ServiceAdvisorDashboard> createState() => _ServiceAdvisorDashboardState();
}

class _ServiceAdvisorDashboardState extends State<ServiceAdvisorDashboard> {
  final TextEditingController vehicleController = TextEditingController();
  final TextEditingController manualSearchController = TextEditingController();
  final TextEditingController concernController = TextEditingController();
  bool isLoading = false;
  bool isDrawerOpen = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? currentStage; // Tracks which stage is currently being processed

  final String backendUrl = 'https://mg-vts-backend.onrender.com/api/vehicle-check';

  @override
  void dispose() {
    vehicleController.dispose();
    manualSearchController.dispose();
    concernController.dispose();
    super.dispose();
  }

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

  void _showConcernDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Concern/Comment'),
        content: TextField(
          controller: concernController,
          decoration: const InputDecoration(
            labelText: 'Enter concern or comment',
            hintText: 'Describe the issue noticed',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              startJobCardCreation();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> startJobCardCreation() async {
    final vehicleNumber = vehicleController.text.trim();
    if (vehicleNumber.isEmpty) {
      showSnackBar('Please scan vehicle QR first');
      return;
    }

    if (currentStage == 'jobCardCreation' && concernController.text.isEmpty) {
      showSnackBar('Please enter a concern before submitting');
      return;
    }

    setState(() {
      currentStage = 'jobCardCreation';
      isLoading = true;
    });

    try {
      final payload = {
        'vehicleNumber': vehicleNumber,
        'stage': 'jobCardCreation',
        'eventType': 'Start',
        'role': 'Service Advisor',
        'commentText': concernController.text,
      };

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        showSnackBar('Job Card Creation started successfully', success: true);
        resetForm();
      } else {
        final error = json.decode(response.body)['message'] ?? 'Failed to start Job Card Creation';
        showSnackBar(error);
      }
    } catch (e) {
      showSnackBar('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startAdditionalWorkApproval() async {
    await _processStage('additionalWork', 'Additional Work Approval');
  }

  Future<void> startReadyForWashing() async {
    await _processStage('readyForWashing', 'Ready for Washing');
  }

  Future<void> _processStage(String stage, String stageName) async {
    final vehicleNumber = vehicleController.text.trim();
    if (vehicleNumber.isEmpty) {
      showSnackBar('Please scan vehicle QR first');
      return;
    }

    setState(() {
      currentStage = stage;
      isLoading = true;
    });

    try {
      final payload = {
        'vehicleNumber': vehicleNumber,
        'stage': stage,
        'eventType': 'Start',
        'role': 'Service Advisor',
      };

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        showSnackBar('$stageName started successfully', success: true);
        resetForm();
      } else {
        final error = json.decode(response.body)['message'] ?? 'Failed to start $stageName';
        showSnackBar(error);
      }
    } catch (e) {
      showSnackBar('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void resetForm() {
    vehicleController.clear();
    concernController.clear();
    currentStage = null;
  }

  Future<void> fetchJobCardHistory() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://mg-vts-backend.onrender.com/api/job-card-history'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _showHistoryDialog(data, 'Job Card History');
      } else {
        showSnackBar('Failed to fetch job card history');
      }
    } catch (e) {
      showSnackBar('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchVehicleHistory() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://mg-vts-backend.onrender.com/api/vehicle-history'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _showHistoryDialog(data, 'Vehicle History');
      } else {
        showSnackBar('Failed to fetch vehicle history');
      }
    } catch (e) {
      showSnackBar('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showHistoryDialog(List<dynamic> historyData, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: historyData.length,
            itemBuilder: (context, index) {
              final item = historyData[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(item['vehicleNumber'] ?? 'Unknown Vehicle'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item['concern'] != null) 
                        Text('Concern: ${item['concern']}'),
                      if (item['startTime'] != null)
                        Text('Date: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(item['startTime']).toLocal())}'),
                      if (item['performedBy'] != null)
                        Text('By: ${item['performedBy']['name'] ?? 'Unknown'}'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> fetchAndShowJourney([String? vehicleNumber]) async {
    final vNumber = vehicleNumber ?? vehicleController.text.trim();
    if (vNumber.isEmpty) {
      showSnackBar('Please enter or scan vehicle number');
      return;
    }

    final url = 'https://mg-vts-backend.onrender.com/api/vehicles/$vNumber/full-journey';

    try {
      setState(() => isLoading = true);
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final journey = data['journey'] as Map<String, dynamic>;

        if (journey.isEmpty) {
          showSnackBar('No activity recorded yet for this vehicle.');
          return;
        }

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Vehicle Journey'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: journey.entries.map((entry) {
                  final stage = entry.key;
                  final stageData = entry.value;
                  String time = '';

                  if (stageData is Map && stageData['startTime'] != null) {
                    final parsed = DateTime.parse(stageData['startTime']).toLocal();
                    time = DateFormat('dd-MM-yyyy hh:mm a').format(parsed);
                  } else if (stageData is List && stageData.isNotEmpty) {
                    final last = stageData.last;
                    if (last['startTime'] != null) {
                      final parsed = DateTime.parse(last['startTime']).toLocal();
                      time = DateFormat('dd-MM-yyyy hh:mm a').format(parsed);
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '$stage\n🕒 $time',
                      style: const TextStyle(fontSize: 15),
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        showSnackBar('Vehicle not found or journey error');
      }
    } catch (e) {
      showSnackBar('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showManualSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Vehicle Journey'),
        content: TextField(
          controller: manualSearchController,
          decoration: const InputDecoration(
            labelText: 'Enter Vehicle Number',
            hintText: 'e.g. ABC123',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              fetchAndShowJourney(manualSearchController.text.trim());
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? Colors.green : Colors.orange,
    ));
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
        title: const Text('Service Advisor Dashboard'),
        actions: [
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Vehicle Scan Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: vehicleController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Number',
                        prefixIcon: Icon(Icons.directions_car),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: scanQRCode,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan Vehicle QR'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Process Buttons Section
            Expanded(
              child: ListView(
                children: [
                  _buildProcessButton(
                    title: 'Start Job Card Creation',
                    icon: Icons.create,
                    onPressed: () {
                      if (vehicleController.text.isEmpty) {
                        showSnackBar('Please scan vehicle QR first');
                      } else {
                        _showConcernDialog();
                      }
                    },
                  ),
                  
                  _buildProcessButton(
                    title: 'Additional Work Approval',
                    icon: Icons.build,
                    onPressed: startAdditionalWorkApproval,
                  ),
                  
                  _buildProcessButton(
                    title: 'Ready for Washing',
                    icon: Icons.local_car_wash,
                    onPressed: startReadyForWashing,
                  ),
                  
                  _buildProcessButton(
                    title: 'Check Vehicle History',
                    icon: Icons.history,
                    onPressed: fetchVehicleHistory,
                  ),
                  
                  _buildProcessButton(
                    title: 'Check Job Card History',
                    icon: Icons.assignment,
                    onPressed: fetchJobCardHistory,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontSize: 18)),
        onTap: isLoading ? null : onPressed,
        trailing: isLoading && currentStage == title.toLowerCase()
            ? const CircularProgressIndicator()
            : const Icon(Icons.arrow_forward),
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

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
      final String code = barcodes.first.rawValue!;
      setState(() => isScanning = false);
      await cameraController.stop();
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: MobileScanner(
        controller: cameraController,
        onDetect: _handleDetection,
      ),
    );
  }
}