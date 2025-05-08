import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';

class TechnicianDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const TechnicianDashboard({
    Key? key, 
    required this.token,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  String? scannedVehicleNumber;
  String selectedStage = 'bayWork';
  String eventType = 'Start';
  bool isLoading = false;
  bool showWorkInProgress = false;
  List<dynamic> workInProgress = [];
  final TextEditingController additionalWorkController = TextEditingController();

  final vehicleController = TextEditingController();
  final workTypeController = TextEditingController();
  final bayNumberController = TextEditingController();

  final String backendUrl = 'https://mg-vts-backend.onrender.com/api/vehicle-check';
  final String workInProgressUrl = 'https://mg-vts-backend.onrender.com/api/work-in-progress';

  @override
  void initState() {
    super.initState();
    fetchWorkInProgress();
  }

  @override
  void dispose() {
    vehicleController.dispose();
    workTypeController.dispose();
    bayNumberController.dispose();
    additionalWorkController.dispose();
    super.dispose();
  }

  Future<void> fetchWorkInProgress() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(workInProgressUrl),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          workInProgress = json.decode(response.body);
        });
      } else {
        showError('Failed to fetch work in progress');
      }
    } catch (e) {
      showError('Error: ${e.toString()}');
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
        scannedVehicleNumber = barcode;
        vehicleController.text = barcode;
      });
    }
  }

  Future<void> submitData() async {
    if (isLoading) return;
    
    setState(() => isLoading = true);
    
    try {
      final vehicleNumber = scannedVehicleNumber ?? vehicleController.text.trim();
      if (vehicleNumber.isEmpty) {
        showError('Please scan or enter a vehicle number');
        return;
      }

      final body = _buildRequestBody(vehicleNumber);
      if (body == null) return;

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        _handleSuccess();
        fetchWorkInProgress();
      } else {
        showError('Error: ${response.body}');
      }
    } catch (e) {
      showError('Submission failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Map<String, dynamic>? _buildRequestBody(String vehicleNumber) {
    final body = {
      'vehicleNumber': vehicleNumber,
      'stage': selectedStage,
      'eventType': eventType,
      'role': 'Technician',
    };

    // Handling 'bayWork' stage
    if (selectedStage == 'bayWork') {
      // Validation for 'Start' event
      if (eventType == 'Start' &&
          (workTypeController.text.trim().isEmpty || bayNumberController.text.trim().isEmpty)) {
        showError('Please enter both work type and bay number');
        return null;
      }

      // Handling 'AdditionalWorkNeeded' event
      if (eventType == 'AdditionalWorkNeeded') {
        if (additionalWorkController.text.trim().isEmpty) {
          showError('Please describe the additional work needed');
          return null;
        }
        // Convert the additional work description to a JSON string
        body['additionalData'] = json.encode({
          'commentText': additionalWorkController.text.trim()
        });
      } else {
        // If it's another event, like 'Start', assign workType and bayNumber
        body['workType'] = workTypeController.text.trim();
        body['bayNumber'] = bayNumberController.text.trim();
      }
    }

    return body;
  }

  void _handleSuccess() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Status submitted successfully'),
        backgroundColor: Colors.green,
      ),
    );
    vehicleController.clear();
    workTypeController.clear();
    bayNumberController.clear();
    additionalWorkController.clear();
    setState(() {
      scannedVehicleNumber = null;
      eventType = 'Start';
    });
  }

  void showError(String msg) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showAdditionalWorkDialog(String vehicleNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Additional Work'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Describe the additional work needed:'),
            const SizedBox(height: 10),
            TextField(
              controller: additionalWorkController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                vehicleController.text = vehicleNumber;
                selectedStage = 'bayWork';
                eventType = 'AdditionalWorkNeeded';
              });
              submitData();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (mounted) {
                widget.onLogout();
              }
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
        title: const Text('Technician Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchWorkInProgress,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => setState(() => showWorkInProgress = !showWorkInProgress),
            tooltip: 'Work in Progress',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutConfirmation,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showWorkInProgress) ...[
              _buildWorkInProgressTable(),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
            ],
            
            // Vehicle Input Section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: vehicleController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Number',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: scanQRCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('SCAN QR'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stage Selection
            const Text('SELECT STAGE:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Column(
              children: [
                _buildStageButton('Bay Work', 'bayWork'),
                const SizedBox(height: 8),
                _buildStageButton('Expert', 'expertStage'),
              ],
            ),
            const SizedBox(height: 20),

            // Event Type
            const Text('EVENT TYPE:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              children: [
                ChoiceChip(
                  label: const Text('Start'),
                  selected: eventType == 'Start',
                  onSelected: (selected) => setState(() => eventType = 'Start'),
                ),
                ChoiceChip(
                  label: const Text('Pause'),
                  selected: eventType == 'Pause',
                  onSelected: (selected) => setState(() => eventType = 'Pause'),
                ),
                ChoiceChip(
                  label: const Text('Resume'),
                  selected: eventType == 'Resume',
                  onSelected: (selected) => setState(() => eventType = 'Resume'),
                ),
                ChoiceChip(
                  label: const Text('End'),
                  selected: eventType == 'End',
                  onSelected: (selected) => setState(() => eventType = 'End'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stage-Specific Fields
            if (selectedStage == 'bayWork') ...[
              if (eventType == 'Start') ...[
                TextField(
                  controller: workTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Work Type',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bayNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Bay Number',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
            
            if (selectedStage == 'expertStage')
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No additional input required'),
              ),

            const SizedBox(height: 20),
            
            // Submit Button
            ElevatedButton(
              onPressed: isLoading ? null : submitData,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
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
                  : const Text('SUBMIT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageButton(String label, String stageKey) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => setState(() => selectedStage = stageKey),
        style: OutlinedButton.styleFrom(
          backgroundColor: selectedStage == stageKey 
              ? Colors.blue.withOpacity(0.1) 
              : Colors.transparent,
          side: BorderSide(
            color: selectedStage == stageKey ? Colors.blue : Colors.grey,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildWorkInProgressTable() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (workInProgress.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No vehicles currently in progress'),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Vehicle')),
              DataColumn(label: Text('Bay')),
              DataColumn(label: Text('Work Type')),
              DataColumn(label: Text('Started At')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: workInProgress.map((vehicle) {
              return DataRow(cells: [
                DataCell(Text(vehicle['vehicleNumber'] ?? '')),
                DataCell(Text(vehicle['bayNumber'] ?? '')),
                DataCell(Text(vehicle['workType'] ?? '')),
                DataCell(Text(vehicle['startTimeIST'] ?? '')),
                DataCell(
                  Chip(
                    label: Text(vehicle['status'] ?? ''),
                    backgroundColor: vehicle['status'] == 'Additional work needed' 
                        ? Colors.orange.withOpacity(0.2) 
                        : Colors.green.withOpacity(0.2),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.add_task),
                    onPressed: () => _showAdditionalWorkDialog(vehicle['vehicleNumber']),
                    tooltip: 'Report Additional Work',
                  ),
                ),
              ]);
            }).toList(),
          ),
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
      appBar: AppBar(title: const Text('Scan Vehicle QR')),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _handleDetection,
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: () async {
                  await cameraController.stop();
                  Navigator.pop(context);
                },
                child: const Text('CANCEL'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}