import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';

class FinalInspectionDashboard extends StatefulWidget {
  final String token;
  const FinalInspectionDashboard({Key? key, required this.token}) : super(key: key);

  @override
  State<FinalInspectionDashboard> createState() => _FinalInspectionDashboardState();
}

class _FinalInspectionDashboardState extends State<FinalInspectionDashboard> {
  final TextEditingController vehicleController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();
  bool isLoading = false;
  bool repairRequired = false;

  final String backendUrl = 'http://192.168.9.77:5000/api/vehicle-check';
  final String inspectionHistoryUrl = 'http://192.168.9.77:5000/api/final-inspection-history';

  List<dynamic> inProgressInspections = [];
  List<dynamic> completedInspections = [];
  DateTimeRange? dateRange;

  @override
  void initState() {
    super.initState();
    fetchInspectionHistory();
  }

  void showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> fetchInspectionHistory({String? vehicleNumber}) async {
    setState(() => isLoading = true);
    try {
      String url = inspectionHistoryUrl;
      List<String> params = [];
      if (vehicleNumber != null && vehicleNumber.isNotEmpty) {
        params.add('vehicleNumber=$vehicleNumber');
      }
      if (dateRange != null) {
        params.add('fromDate=${dateRange!.start.toIso8601String()}');
        params.add('toDate=${dateRange!.end.toIso8601String()}');
      }
      if (params.isNotEmpty) {
        url += '?' + params.join('&');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          inProgressInspections = data['inProgress'] ?? [];
          completedInspections = data['completed'] ?? [];
        });
      } else {
        showSnackBar('Failed to fetch inspection history');
      }
    } catch (e) {
      showSnackBar('Error fetching inspection history: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startInspection() async {
    final vehicleNumber = vehicleController.text.trim();
    if (vehicleNumber.isEmpty) {
      showSnackBar('Please enter or scan a vehicle number');
      return;
    }
    await _sendData({
      'vehicleNumber': vehicleNumber,
      'stage': 'finalInspection',
      'eventType': 'Start',
    });
    fetchInspectionHistory(vehicleNumber: vehicleNumber);
  }

  Future<void> endInspection() async {
    final vehicleNumber = vehicleController.text.trim();
    if (vehicleNumber.isEmpty) {
      showSnackBar('Please enter or scan a vehicle number');
      return;
    }
    await _sendData({
      'vehicleNumber': vehicleNumber,
      'stage': 'finalInspection',
      'eventType': 'End',
      'repairRequired': repairRequired,
      'remarks': remarksController.text,
    });
    fetchInspectionHistory(vehicleNumber: vehicleNumber);
    setState(() {
      repairRequired = false;
      remarksController.clear();
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
      } else {
        showSnackBar(result['error'] ?? 'Operation failed');
      }
    } catch (e) {
      showSnackBar('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
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
      fetchInspectionHistory(vehicleNumber: barcode);
    }
  }

  Widget buildInspectionForm() {
    final vehicleNumber = vehicleController.text.trim();
    final inProgress = inProgressInspections.any((insp) =>
        insp['vehicleNumber'].toString().toLowerCase() == vehicleNumber.toLowerCase());

    if (!inProgress) {
      // Show Start button
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Final Inspection'),
            onPressed: isLoading ? null : startInspection,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
        ],
      );
    } else {
      // Show End button, repairRequired switch, and remarks
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            title: const Text('Repair Required?'),
            value: repairRequired,
            onChanged: isLoading ? null : (val) => setState(() => repairRequired = val),
          ),
          TextField(
            controller: remarksController,
            decoration: const InputDecoration(
              labelText: 'Remarks (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('End Final Inspection'),
            onPressed: isLoading ? null : endInspection,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      );
    }
  }

  Widget buildInspectionHistory() {
    return Expanded(
      child: RefreshIndicator(
        onRefresh: () => fetchInspectionHistory(vehicleNumber: vehicleController.text.trim()),
        child: ListView(
          children: [
            if (inProgressInspections.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('In Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ...inProgressInspections.map((insp) => Card(
                  color: Colors.orange[50],
                  child: ListTile(
                    leading: const Icon(Icons.timelapse, color: Colors.orange),
                    title: Text('Vehicle: ${insp['vehicleNumber']}'),
                    subtitle: Text(
                      'Started: ${insp['startTime']}\n'
                      'Inspector: ${insp['performedBy'] ?? 'N/A'}',
                    ),
                  ),
                )),
            if (completedInspections.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ...completedInspections.map((insp) => Card(
                  color: Colors.green[50],
                  child: ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Vehicle: ${insp['vehicleNumber']}'),
                    subtitle: Text(
                      'Start: ${insp['startTime']}\n'
                      'End: ${insp['endTime']}\n'
                      'Inspector: ${insp['performedBy'] ?? 'N/A'}\n'
                      'Repair Required: ${insp['repairRequired']}\n'
                      'Remarks: ${insp['remarks'] ?? 'N/A'}\n'
                      'Duration: ${insp['durationMinutes']} min',
                    ),
                  ),
                )),
            if (inProgressInspections.isEmpty && completedInspections.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('No inspections found for the selected vehicle/date range.')),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: dateRange,
    );
    if (picked != null) {
      setState(() => dateRange = picked);
      fetchInspectionHistory(vehicleNumber: vehicleController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Inspection Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => fetchInspectionHistory(vehicleNumber: vehicleController.text.trim()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Vehicle number input and scan
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: vehicleController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Number',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => fetchInspectionHistory(vehicleNumber: vehicleController.text.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan QR',
                  onPressed: isLoading ? null : scanQRCode,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Date filter
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: const Text('Filter by Date'),
                  onPressed: isLoading ? null : pickDateRange,
                ),
                if (dateRange != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      '${DateFormat('dd MMM').format(dateRange!.start)} - ${DateFormat('dd MMM yyyy').format(dateRange!.end)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                if (dateRange != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() => dateRange = null);
                      fetchInspectionHistory(vehicleNumber: vehicleController.text.trim());
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Start/End inspection UI
            buildInspectionForm(),
            const SizedBox(height: 16),
            // Inspection history
            buildInspectionHistory(),
            if (isLoading) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// QR Scanner Screen using mobile_scanner package v6.x
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool scanned = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void onDetect(BarcodeCapture capture) {
    if (!scanned && capture.barcodes.isNotEmpty) {
      final String? code = capture.barcodes.first.rawValue;
      if (code != null && code.isNotEmpty) {
        scanned = true;
        Navigator.of(context).pop(code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Vehicle QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: onDetect,
      ),
    );
  }
}
