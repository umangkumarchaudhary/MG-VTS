import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';

class TechnicianDashboard extends StatefulWidget {
  final String token;
  const TechnicianDashboard({Key? key, required this.token}) : super(key: key);

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  String? scannedVehicleNumber;
  String selectedStage = 'interactiveBay';
  String eventType = 'Start';
  bool isLoading = false;

  final vehicleController = TextEditingController();
  final workTypeController = TextEditingController();
  final bayNumberController = TextEditingController();

  final String backendUrl = 'http://192.168.9.77:5000/api/vehicle-check';

  @override
  void dispose() {
    vehicleController.dispose();
    workTypeController.dispose();
    bayNumberController.dispose();
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

    if (selectedStage == 'interactiveBay' && workTypeController.text.trim().isEmpty) {
      showError('Please enter work type');
      return null;
    }
    if (selectedStage == 'bayWork' && 
        (workTypeController.text.trim().isEmpty || bayNumberController.text.trim().isEmpty)) {
      showError('Please enter both work type and bay number');
      return null;
    }

    if (selectedStage == 'interactiveBay') {
      body['workType'] = workTypeController.text.trim();
    } 
    else if (selectedStage == 'bayWork') {
      body['workType'] = workTypeController.text.trim();
      body['bayNumber'] = bayNumberController.text.trim();
    }

    return body;
  }

  void _handleSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Status submitted'),
        backgroundColor: Colors.green,
      ),
    );
    vehicleController.clear();
    workTypeController.clear();
    bayNumberController.clear();
    setState(() => scannedVehicleNumber = null);
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _viewProgress(String stage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleProgressScreen(
          token: widget.token,
          stage: stage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Technician Dashboard'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Vehicle History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              title: const Text('Interactive Bay History'),
              onTap: () {
                Navigator.pop(context);
                _viewProgress('interactiveBay');
              },
            ),
            ListTile(
              title: const Text('Bay Work History'),
              onTap: () {
                Navigator.pop(context);
                _viewProgress('bayWork');
              },
            ),
            ListTile(
              title: const Text('Expert Stage History'),
              onTap: () {
                Navigator.pop(context);
                _viewProgress('expertStage');
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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

            // Stage Selection with View Progress button
            const Text('SELECT STAGE:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Column(
              children: [
                _buildStageButton('Interactive Bay', 'interactiveBay'),
                const SizedBox(height: 8),
                _buildStageButton('Bay Work', 'bayWork'),
                const SizedBox(height: 8),
                _buildStageButton('Expert', 'expertStage'),
              ],
            ),
            const SizedBox(height: 20),

            // Event Type
            const Text('EVENT TYPE:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: 'Start',
                  groupValue: eventType,
                  onChanged: (value) => setState(() => eventType = value!),
                ),
                const Text('Start'),
                const SizedBox(width: 20),
                Radio<String>(
                  value: 'End',
                  groupValue: eventType,
                  onChanged: (value) => setState(() => eventType = value!),
                ),
                const Text('End'),
              ],
            ),
            const SizedBox(height: 20),

            // Stage-Specific Fields
            if (selectedStage == 'interactiveBay')
              TextField(
                controller: workTypeController,
                decoration: const InputDecoration(
                  labelText: 'Work Type',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            
            if (selectedStage == 'bayWork') ...[
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
}

class VehicleProgressScreen extends StatefulWidget {
  final String token;
  final String stage;
  const VehicleProgressScreen({Key? key, required this.token, required this.stage}) : super(key: key);

  @override
  State<VehicleProgressScreen> createState() => _VehicleProgressScreenState();
}

class _VehicleProgressScreenState extends State<VehicleProgressScreen> {
  List<dynamic> inProgress = [];
  List<dynamic> completed = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchProgressData();
  }

  Future<void> _fetchProgressData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://192.168.9.77:5000/api/vehicle-progress/${widget.stage}'),
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
        title: Text('${widget.stage.replaceAll(RegExp(r'([A-Z])'), r' $1')} Progress'),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchProgressData,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(child: Text(error!));
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'In Progress'),
              Tab(text: 'Completed'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildProgressList(inProgress),
                _buildProgressList(completed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressList(List<dynamic> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['vehicleNumber'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Stage: ${item['stageName']}'),
                if (item['workType'] != null && item['workType'].isNotEmpty)
                  Text('Work Type: ${item['workType']}'),
                if (item['bayNumber'] != null && item['bayNumber'].isNotEmpty)
                  Text('Bay Number: ${item['bayNumber']}'),
                const SizedBox(height: 8),
                Text('Started: ${item['startedAtFormatted']}'),
                Text('By: ${item['startedBy']}'),
                if (item['status'] == 'Completed') ...[
                  const SizedBox(height: 8),
                  Text('Completed: ${item['endedAtFormatted']}'),
                  Text('By: ${item['endedBy']}'),
                ],
                const SizedBox(height: 8),
                Text(
                  'Duration: ${item['totalTime']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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