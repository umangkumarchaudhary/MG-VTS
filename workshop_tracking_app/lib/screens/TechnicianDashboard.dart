import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';

// Define a dark theme for the entire app
final ThemeData darkTheme = ThemeData.dark().copyWith(
  primaryColor: Colors.grey[900],
  scaffoldBackgroundColor: Colors.black,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.black,
    elevation: 0,
    iconTheme: const IconThemeData(color: Colors.white),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.grey[800],
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.grey),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Colors.white70,
    ),
  ),
  cardTheme: CardTheme(
    color: Colors.grey[900],
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  tabBarTheme: const TabBarTheme(
    labelColor: Colors.white,
    unselectedLabelColor: Colors.grey,
    indicator: UnderlineTabIndicator(
      borderSide: BorderSide(color: Colors.white, width: 2),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey[900],
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white38),
    ),
    labelStyle: const TextStyle(color: Colors.grey),
  ),
);

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
      SnackBar(
        content: const Text('Status submitted'),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
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
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
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
    return Theme(
      data: darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Technician Dashboard'),
          centerTitle: true,
          // Making the hamburger menu more visible
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(
                Icons.menu,
                color: Colors.white, // Explicitly set color for visibility
                size: 28, // Larger size for better visibility
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu', // Accessibility feature
            ),
          ),
          actions: [
            // Adding refresh button in app bar for visibility
            IconButton(
              icon: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {
                // refresh logic - could show a temporary message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refreshed'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: Colors.grey[900],
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Vehicle History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'View progress by stage',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.white70),
                title: const Text('Interactive Bay History'),
                onTap: () {
                  Navigator.pop(context);
                  _viewProgress('interactiveBay');
                },
              ),
              ListTile(
                leading: const Icon(Icons.build, color: Colors.white70),
                title: const Text('Bay Work History'),
                onTap: () {
                  Navigator.pop(context);
                  _viewProgress('bayWork');
                },
              ),
              ListTile(
                leading: const Icon(Icons.engineering, color: Colors.white70),
                title: const Text('Expert Stage History'),
                onTap: () {
                  Navigator.pop(context);
                  _viewProgress('expertStage');
                },
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white70),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement logout functionality
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
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VEHICLE INFORMATION',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: vehicleController,
                              decoration: const InputDecoration(
                                labelText: 'Vehicle Number',
                                prefixIcon: Icon(Icons.directions_car),
                              ),
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: scanQRCode,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('SCAN'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Stage Selection
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SELECT STAGE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStageButton('Interactive Bay', 'interactiveBay', Icons.touch_app),
                      const SizedBox(height: 8),
                      _buildStageButton('Bay Work', 'bayWork', Icons.build),
                      const SizedBox(height: 8),
                      _buildStageButton('Expert', 'expertStage', Icons.engineering),
                    ],
                  ),
                ),
              ),

              // Event Type
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EVENT TYPE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => eventType = 'Start'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: eventType == 'Start' ? Colors.green.withOpacity(0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: eventType == 'Start' ? Colors.green : Colors.grey,
                                    width: 1,
                                  ),
                                ),
                                child: const Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_arrow, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('START'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => eventType = 'End'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: eventType == 'End' ? Colors.red.withOpacity(0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: eventType == 'End' ? Colors.red : Colors.grey,
                                    width: 1,
                                  ),
                                ),
                                child: const Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.stop, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('END'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Stage-Specific Fields
              if (selectedStage == 'interactiveBay' || selectedStage == 'bayWork')
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DETAILS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: workTypeController,
                          decoration: const InputDecoration(
                            labelText: 'Work Type',
                            prefixIcon: Icon(Icons.work),
                          ),
                        ),
                        if (selectedStage == 'bayWork') ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: bayNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Bay Number',
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              
              // Submit Button
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : submitData,
                  icon: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(isLoading ? 'SUBMITTING...' : 'SUBMIT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    disabledBackgroundColor: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageButton(String label, String stageKey, IconData icon) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => setState(() => selectedStage = stageKey),
        icon: Icon(
          icon,
          color: selectedStage == stageKey ? Colors.blue : Colors.white70,
        ),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: selectedStage == stageKey 
              ? Colors.blue.withOpacity(0.1) 
              : Colors.transparent,
          side: BorderSide(
            color: selectedStage == stageKey ? Colors.blue : Colors.grey,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.centerLeft,
        ),
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
    return Theme(
      data: darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.stage.replaceAll(RegExp(r'([A-Z])'), r' $1').split(' ').map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '').join(' ')} Progress',
          ),
          centerTitle: true,
          actions: [
            // Making refresh button clearly visible in the app bar
            IconButton(
              icon: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 24,
              ),
              onPressed: _fetchProgressData,
              tooltip: 'Refresh Data',
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Loading data...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchProgressData,
              icon: const Icon(Icons.refresh),
              label: const Text('TRY AGAIN'),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.grey[900],
            child: const TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.pending_actions),
                  text: 'In Progress',
                ),
                Tab(
                  icon: Icon(Icons.check_circle_outline),
                  text: 'Completed',
                ),
              ],
              indicatorColor: Colors.white,
              labelColor: Colors.white,
            ),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No vehicles available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final item = items[index];
        final isCompleted = item['status'] == 'Completed';
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_circle : Icons.pending,
                        color: isCompleted ? Colors.green : Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
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
                          Text(
                            'Total Time: ${item['totalTime']}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Stage', item['stageName']),
                          if (item['workType'] != null && item['workType'].isNotEmpty)
                            _buildInfoRow('Work Type', item['workType']),
                          if (item['bayNumber'] != null && item['bayNumber'].isNotEmpty)
                            _buildInfoRow('Bay', '#${item['bayNumber']}'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Started', item['startedAtFormatted']),
                          _buildInfoRow('By', item['startedBy']),
                          if (isCompleted) ...[
                            _buildInfoRow('Completed', item['endedAtFormatted']),
                            _buildInfoRow('By', item['endedBy']),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
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
    return Theme(
      data: darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan Vehicle QR'),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: cameraController,
              onDetect: _handleDetection,
            ),
            // Scan overlay
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: Icon(
                      Icons.qr_code,
                      color: Colors.white70,
                      size: 50,
                    ),
                  ),
                ),
              ),
            ),
            // Scanning indicator
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text('Scanning...'),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await cameraController.stop();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('CANCEL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[800],
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}