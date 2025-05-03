import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';

class ServiceAdvisorDashboard extends StatefulWidget {
  final String token;
  const ServiceAdvisorDashboard({super.key, required this.token});

  @override
  State<ServiceAdvisorDashboard> createState() => _ServiceAdvisorDashboardState();
}

class _ServiceAdvisorDashboardState extends State<ServiceAdvisorDashboard> {
  final TextEditingController vehicleController = TextEditingController();
  bool isLoading = false;

  final String backendUrl = 'http://192.168.9.70:5000/api/vehicle-check';

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

  Future<void> startJobCardCreation() async {
    await _startStage('jobCardCreation');
  }

  Future<void> startAdditionalWorkApproval() async {
    await _startStage('additionalWork');
  }

  Future<void> startReadyForWashing() async {
    await _startStage('readyForWashing');
  }

  Future<void> _startStage(String stage) async {
    final vehicleNumber = vehicleController.text.trim();
    if (vehicleNumber.isEmpty) {
      showSnackBar('Please scan vehicle QR first');
      return;
    }

    final payload = {
      'vehicleNumber': vehicleNumber,
      'stage': stage,
      'eventType': 'Start',
      'role': 'Service Advisor',
    };

    await sendData(payload);
  }

  Future<void> sendData(Map<String, dynamic> payload) async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode(payload),
      );

      final result = json.decode(response.body);
      final String msg = result['message'] ?? 'Success';
      final bool alreadyStarted = result['alreadyStarted'] ?? false;

      if (response.statusCode == 200) {
        showSnackBar(msg, success: !alreadyStarted);
      } else {
        showSnackBar(result['error'] ?? 'Failed');
      }
    } catch (e) {
      showSnackBar('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchAndShowJourney() async {
    final vehicleNumber = vehicleController.text.trim();
    if (vehicleNumber.isEmpty) {
      showSnackBar('Please enter or scan vehicle number');
      return;
    }

    final url = 'http://192.168.9.70:5000/api/vehicles/$vehicleNumber/full-journey';

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

  void showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? Colors.green : Colors.orange,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Advisor Dashboard'),
      ),
      body: Padding(
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : startJobCardCreation,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Start Job Card Creation'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : startAdditionalWorkApproval,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Start Additional Work Approval'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : startReadyForWashing,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Start Ready for Washing'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isLoading ? null : fetchAndShowJourney,
              icon: const Icon(Icons.search),
              label: const Text('Search Vehicle Journey'),
            ),
          ],
        ),
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
