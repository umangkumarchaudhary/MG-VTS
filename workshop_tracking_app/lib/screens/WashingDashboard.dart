import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      textStyle: const TextStyle(
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


class VehicleWashingData {
  final String vehicleNumber;
  final String serviceAdvisorName;
  final String serviceType;
  final DateTime dateTime;
  final String status;
  final String? startTime;
  final String? endTime;
  final bool isCompleted;

  VehicleWashingData({
    required this.vehicleNumber,
    required this.serviceAdvisorName, 
    required this.serviceType,
    required this.dateTime,
    required this.status,
    this.startTime,
    this.endTime,
    this.isCompleted = false,
  });

  factory VehicleWashingData.fromJson(Map<String, dynamic> json) {
    return VehicleWashingData(
      vehicleNumber: json['vehicleNumber']?.toString() ?? '',
      serviceAdvisorName: json['serviceAdvisor']?.toString() ?? '',
      serviceType: json['washingType']?.toString() ?? 'Paid',
      dateTime: DateTime.tryParse(json['dateTime']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString() ?? 'Not Started',
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

class WashingDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const WashingDashboard({
    Key? key, 
    required this.token,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<WashingDashboard> createState() => _WashingDashboardState();
}

class _WashingDashboardState extends State<WashingDashboard> with SingleTickerProviderStateMixin {
  bool isLoading = true;
  String? error;
  List<VehicleWashingData> vehicles = [];
  Set<String> inProgressVehicles = {};
  Set<String> completedVehicles = {};
  String? scannedVehicleNumber;
  late TabController _tabController;
  final backendUrl = 'https://mg-vts-backend.onrender.com/api';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVehicleStates();
    fetchWashingSummary();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleStates() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      inProgressVehicles = Set.from(prefs.getStringList('inProgressVehicles') ?? []);
      completedVehicles = Set.from(prefs.getStringList('completedVehicles') ?? []);
    });
  }

  Future<void> _saveVehicleStates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('inProgressVehicles', inProgressVehicles.toList());
    await prefs.setStringList('completedVehicles', completedVehicles.toList());
  }

  Future<void> fetchWashingSummary() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$backendUrl/washing-summary'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        List<dynamic> vehiclesList = responseData is List ? responseData : [];

        setState(() {
          vehicles = vehiclesList.map((v) => VehicleWashingData.fromJson(v)).toList();
          
          // Update vehicle states based on local storage
          vehicles = vehicles.map((vehicle) {
            if (inProgressVehicles.contains(vehicle.vehicleNumber)) {
              return VehicleWashingData(
                vehicleNumber: vehicle.vehicleNumber,
                serviceAdvisorName: vehicle.serviceAdvisorName,
                serviceType: vehicle.serviceType,
                dateTime: vehicle.dateTime,
                status: 'In Progress',
                startTime: vehicle.startTime,
                endTime: null,
                isCompleted: false,
              );
            } else if (completedVehicles.contains(vehicle.vehicleNumber)) {
              return VehicleWashingData(
                vehicleNumber: vehicle.vehicleNumber,
                serviceAdvisorName: vehicle.serviceAdvisorName,
                serviceType: vehicle.serviceType,
                dateTime: vehicle.dateTime,
                status: 'Completed',
                startTime: vehicle.startTime,
                endTime: vehicle.endTime,
                isCompleted: true,
              );
            }
            return vehicle;
          }).toList();
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

  Future<void> scanQRCode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
    
    if (barcode != null && mounted) {
      setState(() {
        scannedVehicleNumber = barcode;
      });
      
      final vehicleIndex = vehicles.indexWhere((v) => v.vehicleNumber == barcode);
      if (vehicleIndex != -1) {
        _handleVehicleAction(vehicles[vehicleIndex]);
      } else {
        showError('Vehicle not found in washing queue');
      }
    }
  }

  void _handleVehicleAction(VehicleWashingData vehicle) {
    if (vehicle.isCompleted) {
      _showRestartConfirmationDialog(vehicle);
    } else {
      final bool isInProgress = inProgressVehicles.contains(vehicle.vehicleNumber);
      if (isInProgress) {
        _showConfirmationDialog(
          'End Washing',
          'Do you want to end washing for ${vehicle.vehicleNumber}?',
          () => _updateWashingStatus(vehicle.vehicleNumber, 'End'),
        );
      } else {
        _showConfirmationDialog(
          'Start Washing',
          'Do you want to start washing ${vehicle.vehicleNumber}?',
          () => _updateWashingStatus(vehicle.vehicleNumber, 'Start'),
        );
      }
    }
  }

  void _showRestartConfirmationDialog(VehicleWashingData vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Washing'),
        content: Text('Are you sure you want to wash ${vehicle.vehicleNumber} again?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateWashingStatus(vehicle.vehicleNumber, 'Start');
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateWashingStatus(String vehicleNumber, String eventType) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/vehicle-check'),
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
        setState(() {
          if (eventType == 'Start') {
            inProgressVehicles.add(vehicleNumber);
            completedVehicles.remove(vehicleNumber);
          } else {
            inProgressVehicles.remove(vehicleNumber);
            completedVehicles.add(vehicleNumber);
          }
        });
        await _saveVehicleStates();
        fetchWashingSummary();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(eventType == 'Start' 
              ? 'Washing started successfully' 
              : 'Washing completed successfully'),
            backgroundColor: mgSuccessColor,
          ),
        );
      } else {
        showError('Error: ${response.body}');
      }
    } catch (e) {
      showError('Operation failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: mgErrorColor,
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

  Widget _buildActiveVehiclesList() {
    final activeVehicles = vehicles.where((v) => 
        !v.isCompleted && 
        (v.status == 'Not Started' || 
         v.status == 'In Progress' || 
         inProgressVehicles.contains(v.vehicleNumber))
    ).toList();
    
    if (activeVehicles.isEmpty) {
      return const Center(
        child: Text('No vehicles in washing queue', style: TextStyle(fontSize: 16)),
      );
    }
    
    return ListView.builder(
      itemCount: activeVehicles.length,
      itemBuilder: (context, index) {
        final vehicle = activeVehicles[index];
        final isInProgress = inProgressVehicles.contains(vehicle.vehicleNumber);
        
        return _buildVehicleCard(
          vehicle,
          isInProgress ? 'In Progress' : 'Pending',
          isInProgress ? mgWarningColor : mgAccentColor,
          isInProgress ? 'END WASH' : 'START WASH',
          isInProgress ? mgSuccessColor : mgPrimaryColor,
          () => _handleVehicleAction(vehicle),
        );
      },
    );
  }

  Widget _buildCompletedVehiclesList() {
    final completedVehiclesList = vehicles.where((v) => v.isCompleted).toList();
    
    if (completedVehiclesList.isEmpty) {
      return const Center(
        child: Text('No completed washing records', style: TextStyle(fontSize: 16)),
      );
    }
    
    return ListView.builder(
      itemCount: completedVehiclesList.length,
      itemBuilder: (context, index) {
        final vehicle = completedVehiclesList[index];
        return _buildVehicleCard(
          vehicle,
          'Completed',
          mgSuccessColor,
          'WASH AGAIN',
          mgPrimaryColor,
          () => _handleVehicleAction(vehicle),
          showActionButton: true,
        );
      },
    );
  }

  Widget _buildVehicleCard(
    VehicleWashingData vehicle,
    String statusText,
    Color statusColor,
    String buttonText,
    Color buttonColor,
    VoidCallback onAction, {
    bool showActionButton = true,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onAction,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_car, color: mgPrimaryColor),
                      const SizedBox(width: 8),
                      Text(
                        vehicle.vehicleNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: mgSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: mgTextColor),
                  const SizedBox(width: 4),
                  Text('Advisor: ${vehicle.serviceAdvisorName}', 
                      style: const TextStyle(color: mgTextColor)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: mgTextColor),
                  const SizedBox(width: 4),
                  Text('Date: ${DateFormat('dd MMM yyyy').format(vehicle.dateTime)}', 
                      style: const TextStyle(color: mgTextColor)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments, size: 16, color: mgTextColor),
                      const SizedBox(width: 4),
                      Text('Service: ${vehicle.serviceType}', 
                          style: const TextStyle(color: mgTextColor)),
                    ],
                  ),
                  if (showActionButton)
                    ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(buttonText),
                    ),
                ],
              ),
              if (vehicle.startTime != null && vehicle.endTime != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 8),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timer, size: 16, color: mgTextColor),
                    const SizedBox(width: 4),
                    Text('Start: ${vehicle.startTime}', 
                        style: const TextStyle(color: mgTextColor)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.timer_off, size: 16, color: mgTextColor),
                    const SizedBox(width: 4),
                    Text('End: ${vehicle.endTime}', 
                        style: const TextStyle(color: mgTextColor)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MG Washing Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: scanQRCode,
            tooltip: 'Scan QR',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchWashingSummary,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending & In Progress'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: mgPrimaryColor))
          : error != null
              ? Center(child: Text(error!, style: const TextStyle(color: mgErrorColor)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveVehiclesList(),
                    _buildCompletedVehiclesList(),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: scanQRCode,
        backgroundColor: mgPrimaryColor,
        child: const Icon(Icons.qr_code_scanner),
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
      appBar: AppBar(
        title: const Text('Scan Vehicle QR Code'),
        backgroundColor: mgPrimaryColor,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _handleDetection,
          ),
          Positioned.fill(
            child: Container(
              alignment: Alignment.center,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: mgPrimaryColor, width: 3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Position QR code here',
                    style: TextStyle(
                      color: Colors.white,
                      backgroundColor: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}