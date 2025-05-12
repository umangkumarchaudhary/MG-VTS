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

  final Map<String, String> stageDisplayNames = {
    'pickupDrop': 'Pickup/Drop',
    'interactiveBay': 'Interactive Bay',
    'jobCardCreation': 'Job Card Creation',
    'bayAllocation': 'Bay Allocation',
    'roadTest': 'Road Test',
    'bayWork': 'Bay Work',
    'assignExpert': 'Expert Assigned',
    'expertStage': 'Expert Diagnosis',
    'partsEstimation': 'Parts Estimation',
    'additionalWork': 'Additional Work Approval',
    'partsOrder': 'Parts Order',
    'finalInspection': 'Final Inspection',
    'jobCardReceived': 'Job Card Received',
    'readyForWashing': 'Ready for Washing',
    'washing': 'Washing',
    'vasActivities': 'Value-Added Services',
  };

  final Map<String, Map<String, dynamic>> eventDisplay = {
    'Start': {
      'verb': 'Started',
      'color': Colors.green,
      'icon': Icons.play_arrow,
    },
    'End': {
      'verb': 'Completed',
      'color': Colors.blue,
      'icon': Icons.check_circle,
    },
    'Pause': {
      'verb': 'Paused',
      'color': Colors.orange,
      'icon': Icons.pause,
    },
    'Resume': {
      'verb': 'Resumed',
      'color': Colors.green,
      'icon': Icons.play_arrow,
    },
    'default': {
      'verb': 'Updated',
      'color': Colors.grey,
      'icon': Icons.update,
    },
  };

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
      print('[DEBUG] scanQRCode: Scanned value = $barcode');
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
    print('[DEBUG] startJobCardCreation: vehicleNumber = $vehicleNumber');
    if (vehicleNumber.isEmpty) {
      showSnackBar('Please scan vehicle QR first');
      print('[DEBUG] startJobCardCreation: Vehicle number is empty');
      return;
    }

    if (currentStage == 'jobCardCreation' && concernController.text.isEmpty) {
      showSnackBar('Please enter a concern before submitting');
      print('[DEBUG] startJobCardCreation: Concern is empty');
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
      print('[DEBUG] startJobCardCreation: Sending payload = $payload');

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode(payload),
      );
      
      print('[DEBUG] startJobCardCreation: Response status = ${response.statusCode}');
      print('[DEBUG] startJobCardCreation: Response body = ${response.body}');

      if (response.statusCode == 200) {
        showSnackBar('Job Card Creation started successfully', success: true);
        resetForm();
      } else {
        final error = json.decode(response.body)['message'] ?? 'Failed to start Job Card Creation';
        showSnackBar(error);
        print('[DEBUG] startJobCardCreation: Error = $error');
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
    final vehicleNumber = vehicleController.text.trim();
    if (vehicleNumber.isEmpty) {
      showSnackBar('Please scan vehicle QR first');
      return;
    }

    // Show washing type selection dialog
    final washingType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Washing Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Free Washing'),
              leading: const Icon(Icons.clean_hands, color: Colors.green),
              onTap: () => Navigator.pop(context, 'Free'),
            ),
            ListTile(
              title: const Text('Paid Washing'),
              leading: const Icon(Icons.attach_money, color: Colors.blue),
              onTap: () => Navigator.pop(context, 'Paid'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (washingType == null) return; // User cancelled

    await _processStageWithWashingType(vehicleNumber, washingType);
  }

  Future<void> _processStageWithWashingType(String vehicleNumber, String washingType) async {
    setState(() {
      currentStage = 'readyForWashing';
      isLoading = true;
    });

    try {
      final payload = {
        'vehicleNumber': vehicleNumber,
        'stage': 'readyForWashing',
        'eventType': 'Start',
        'role': 'Service Advisor',
        'washingType': washingType,
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
        showSnackBar('Ready for Washing ($washingType) started successfully', success: true);
        resetForm();
      } else {
        final error = json.decode(response.body)['message'] ?? 'Failed to start Ready for Washing';
        showSnackBar(error);
      }
    } catch (e) {
      showSnackBar('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
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
    final vehicleNumber = vehicleController.text.trim();
    if (vehicleNumber.isEmpty) {
      showSnackBar('Please scan vehicle QR first');
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://mg-vts-backend.onrender.com/api/vehicle-history/$vehicleNumber'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _showHistoryDialog(data['history'], 'Vehicle History');
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
    // Sort by time (newest first)
    historyData.sort((a, b) => DateTime.parse(b['time'] ?? '1970-01-01')
      .compareTo(DateTime.parse(a['time'] ?? '1970-01-01')));

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
              final stage = item['stage']?.toString() ?? 'Unknown Stage';
              final displayName = stageDisplayNames[stage] ?? stage;
              final eventType = item['eventType']?.toString() ?? '';
              final eventConfig = eventDisplay[eventType] ?? eventDisplay['default']!;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header if it's a new day
                  if (index == 0 || 
                      !isSameDay(
                        DateTime.parse(historyData[index-1]['time']), 
                        DateTime.parse(item['time'])
                      ))
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        DateFormat('EEEE, MMMM d').format(DateTime.parse(item['time'])),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  
                  // Timeline item
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time and status
                        Row(
                          children: [
                            Icon(
                              eventConfig['icon'],
                              color: eventConfig['color'],
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('hh:mm a').format(DateTime.parse(item['time'])),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: eventConfig['color'].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: eventConfig['color'].withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                eventConfig['verb'],
                                style: TextStyle(
                                  color: eventConfig['color'],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Main action
                        RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              TextSpan(
                                text: '${eventConfig['verb']} ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: eventConfig['color'],
                                ),
                              ),
                              TextSpan(
                                text: displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Performed by
                        if (item['performedBy'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'by ',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  TextSpan(
                                    text: item['performedBy'] is String 
                                        ? item['performedBy'] 
                                        : item['performedBy']['name'] ?? 'System',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        // Washing Type (if applicable)
                        if (item['stage'] == 'readyForWashing' && item['washingType'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  item['washingType'] == 'Paid' 
                                      ? Icons.attach_money 
                                      : Icons.clean_hands,
                                  color: item['washingType'] == 'Paid' 
                                      ? Colors.blue 
                                      : Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Washing Type: ${item['washingType']}',
                                  style: TextStyle(
                                    color: item['washingType'] == 'Paid' 
                                        ? Colors.blue 
                                        : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Comments
                        if (item['comment'] != null && item['comment'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item['comment'],
                                style: TextStyle(
                                  color: Colors.blue[800],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
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

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
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