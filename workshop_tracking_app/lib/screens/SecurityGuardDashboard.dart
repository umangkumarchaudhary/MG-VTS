import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SecurityGuardDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const SecurityGuardDashboard({
    Key? key, 
    required this.token,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<SecurityGuardDashboard> createState() => _SecurityGuardDashboardState();
}

class _SecurityGuardDashboardState extends State<SecurityGuardDashboard> {
  String? scannedVehicleNumber;
  bool isScanning = false;
  String eventType = 'Start';
  final TextEditingController kmController = TextEditingController();
  final TextEditingController vehicleNumberController = TextEditingController();
  
  // New fields for bringBy/takeOutBy functionality
  String? bringBy;
  String? takeOutBy;
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerNameOutController = TextEditingController();

  List<Map<String, dynamic>> inVehicles = [];
  List<Map<String, dynamic>> outVehicles = [];
  final TextEditingController searchVehicleController = TextEditingController();
  DateTime? fromDate;
  DateTime? toDate;
  bool isLoadingHistory = false;
  String? historyError;

  final String backendUrl = 'http://192.168.1.62:5000/api/vehicle-check';
  final String historyUrl = 'http://192.168.1.62:5000/api/security-gate-history';

  @override
  void initState() {
    super.initState();
    fetchVehicleHistory();
  }

  @override
  void dispose() {
    kmController.dispose();
    vehicleNumberController.dispose();
    customerNameController.dispose();
    customerNameOutController.dispose();
    searchVehicleController.dispose();
    super.dispose();
  }

  Future<void> scanQRCode() async {
    setState(() => isScanning = true);

    try {
      final barcode = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => const QRScannerScreen(),
        ),
      );
      if (barcode != null && mounted) {
        setState(() {
          scannedVehicleNumber = barcode;
          vehicleNumberController.text = barcode;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanning failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isScanning = false);
    }
  }

  Future<void> submitData() async {
    final vehicleNumber = scannedVehicleNumber ?? vehicleNumberController.text.trim();
    if (vehicleNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan or enter a vehicle number')),
      );
      return;
    }

    final km = int.tryParse(kmController.text.trim());
    if (km == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid KM number')),
      );
      return;
    }

    // Validate bringBy/takeOutBy fields based on event type
    if (eventType == 'Start' && bringBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select who is bringing the vehicle')),
      );
      return;
    }

    if (eventType == 'Start' && bringBy == 'Customer' && customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer name')),
      );
      return;
    }

    if (eventType == 'End' && takeOutBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select who is taking out the vehicle')),
      );
      return;
    }

    if (eventType == 'End' && takeOutBy == 'Customer' && customerNameOutController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer name')),
      );
      return;
    }

    try {
      Map<String, dynamic> body = {
        'vehicleNumber': vehicleNumber,
        'stage': 'securityGate',
        'eventType': eventType,
        'role': 'Security Guard',
      };

      if (eventType == 'Start') {
        body['inKM'] = km;
        body['bringBy'] = bringBy;
        if (bringBy == 'Customer') {
          body['customerName'] = customerNameController.text;
        }
      } else {
        body['outKM'] = km;
        body['takeOutBy'] = takeOutBy;
        if (takeOutBy == 'Customer') {
          body['customerNameOut'] = customerNameOutController.text;
        }
      }

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle event submitted successfully')),
        );
        resetForm();
        fetchVehicleHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting data: $e')),
      );
    }
  }

  void resetForm() {
    setState(() {
      scannedVehicleNumber = null;
      vehicleNumberController.clear();
      kmController.clear();
      customerNameController.clear();
      customerNameOutController.clear();
      bringBy = null;
      takeOutBy = null;
      // Keep the same event type after submission
    });
  }

  Future<void> pickDate(BuildContext context, bool isFrom) async {
    final initialDate = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (fromDate ?? initialDate) : (toDate ?? initialDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
    }
  }

  Future<void> fetchVehicleHistory() async {
    setState(() {
      isLoadingHistory = true;
      historyError = null;
    });

    try {
      final queryParameters = <String, String>{};
      if (searchVehicleController.text.trim().isNotEmpty) {
        queryParameters['vehicleNumber'] = searchVehicleController.text.trim();
      }
      if (fromDate != null) {
        queryParameters['fromDate'] = fromDate!.toIso8601String();
      }
      if (toDate != null) {
        queryParameters['toDate'] = toDate!.toIso8601String();
      }

      final uri = Uri.parse(historyUrl).replace(queryParameters: queryParameters);

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer ${widget.token}',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          inVehicles = List<Map<String, dynamic>>.from(data['inVehicles'] ?? []);
          outVehicles = List<Map<String, dynamic>>.from(data['outVehicles'] ?? []);
        });
      } else {
        setState(() {
          historyError = 'Error: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        historyError = 'Failed to fetch history: $e';
      });
    } finally {
      setState(() {
        isLoadingHistory = false;
      });
    }
  }

  EdgeInsets getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) {
      return const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    } else if (width < 600) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    } else {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
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
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: getResponsivePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Submission Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: isScanning ? null : scanQRCode,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan QR Code'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              textStyle: const TextStyle(fontSize: 18),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: vehicleNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Vehicle Number',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Event Type:', style: TextStyle(fontSize: 16)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Radio<String>(
                                value: 'Start',
                                groupValue: eventType,
                                onChanged: (value) {
                                  setState(() {
                                    eventType = value!;
                                    // Clear related fields when switching event type
                                    if (eventType == 'Start') {
                                      takeOutBy = null;
                                      customerNameOutController.clear();
                                    } else {
                                      bringBy = null;
                                      customerNameController.clear();
                                    }
                                  });
                                },
                              ),
                              const Text('IN', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 20),
                              Radio<String>(
                                value: 'End',
                                groupValue: eventType,
                                onChanged: (value) {
                                  setState(() {
                                    eventType = value!;
                                    // Clear related fields when switching event type
                                    if (eventType == 'Start') {
                                      takeOutBy = null;
                                      customerNameOutController.clear();
                                    } else {
                                      bringBy = null;
                                      customerNameController.clear();
                                    }
                                  });
                                },
                              ),
                              const Text('OUT', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: kmController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: eventType == 'Start' ? 'In KM' : 'Out KM',
                              border: const OutlineInputBorder(),
                            ),
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          
                          // Bring By/Take Out By Section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eventType == 'Start' ? 'Brought By:' : 'Taken Out By:',
                                style: const TextStyle(fontSize: 16),
                              ),
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'Driver',
                                    groupValue: eventType == 'Start' ? bringBy : takeOutBy,
                                    onChanged: (value) {
                                      setState(() {
                                        if (eventType == 'Start') {
                                          bringBy = value;
                                          if (value == 'Driver') {
                                            customerNameController.clear();
                                          }
                                        } else {
                                          takeOutBy = value;
                                          if (value == 'Driver') {
                                            customerNameOutController.clear();
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  const Text('Driver'),
                                  const SizedBox(width: 20),
                                  Radio<String>(
                                    value: 'Customer',
                                    groupValue: eventType == 'Start' ? bringBy : takeOutBy,
                                    onChanged: (value) {
                                      setState(() {
                                        if (eventType == 'Start') {
                                          bringBy = value;
                                        } else {
                                          takeOutBy = value;
                                        }
                                      });
                                    },
                                  ),
                                  const Text('Customer'),
                                ],
                              ),
                              if ((eventType == 'Start' && bringBy == 'Customer') || 
                                  (eventType == 'End' && takeOutBy == 'Customer'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextField(
                                    controller: eventType == 'Start' 
                                        ? customerNameController 
                                        : customerNameOutController,
                                    decoration: InputDecoration(
                                      labelText: eventType == 'Start' 
                                          ? 'Customer Name (Bringing)' 
                                          : 'Customer Name (Taking Out)',
                                      border: const OutlineInputBorder(),
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: submitData,
                            child: const Text('Submit'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              textStyle: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // History Search Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Search Vehicle History',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: searchVehicleController,
                            decoration: const InputDecoration(
                              labelText: 'Vehicle Number (optional)',
                              border: OutlineInputBorder(),
                            ),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => pickDate(context, true),
                                  child: AbsorbPointer(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: fromDate == null
                                            ? 'From Date'
                                            : fromDate!.toLocal().toString().split(' ')[0],
                                        border: const OutlineInputBorder(),
                                        suffixIcon: const Icon(Icons.calendar_today),
                                      ),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => pickDate(context, false),
                                  child: AbsorbPointer(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: toDate == null
                                            ? 'To Date'
                                            : toDate!.toLocal().toString().split(' ')[0],
                                        border: const OutlineInputBorder(),
                                        suffixIcon: const Icon(Icons.calendar_today),
                                      ),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: fetchVehicleHistory,
                                  icon: const Icon(Icons.search),
                                  label: const Text('Search'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 44),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () {
                                  searchVehicleController.clear();
                                  setState(() {
                                    fromDate = null;
                                    toDate = null;
                                  });
                                  fetchVehicleHistory();
                                },
                                tooltip: 'Clear & Refresh',
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // History Display Section
                  if (isLoadingHistory)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    )),
                  if (historyError != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          historyError!,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      ),
                    ),
                  if (!isLoadingHistory && historyError == null) ...[
                    const Text(
                      'IN Vehicles',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    inVehicles.isEmpty
                        ? const Text('No IN vehicles found.', style: TextStyle(fontSize: 16))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: inVehicles.length,
                            itemBuilder: (context, index) {
                              final vehicle = inVehicles[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: const Icon(Icons.directions_car, color: Colors.green),
                                  title: Text(
                                    vehicle['vehicleNumber'] ?? '',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('In KM: ${vehicle['inKM'] ?? '-'}'),
                                      Text('Brought By: ${vehicle['bringBy'] ?? '-'}'),
                                      if (vehicle['bringBy'] == 'Customer')
                                        Text('Customer: ${vehicle['customerName'] ?? '-'}'),
                                      Text('In Time: ${vehicle['inTime'] != null 
                                          ? vehicle['inTime'].toString().split('T').first 
                                          : 'N/A'}'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 24),
                    const Text(
                      'OUT Vehicles',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    outVehicles.isEmpty
                        ? const Text('No OUT vehicles found.', style: TextStyle(fontSize: 16))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: outVehicles.length,
                            itemBuilder: (context, index) {
                              final vehicle = outVehicles[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                                  title: Text(
                                    vehicle['vehicleNumber'] ?? '',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('In KM: ${vehicle['inKM'] ?? '-'}'),
                                      Text('Out KM: ${vehicle['outKM'] ?? '-'}'),
                                      Text('Taken Out By: ${vehicle['takeOutBy'] ?? '-'}'),
                                      if (vehicle['takeOutBy'] == 'Customer')
                                        Text('Customer: ${vehicle['customerNameOut'] ?? '-'}'),
                                      Text('In Time: ${vehicle['inTime'] != null 
                                          ? vehicle['inTime'].toString().split('T').first 
                                          : 'N/A'}'),
                                      Text('Out Time: ${vehicle['outTime'] != null 
                                          ? vehicle['outTime'].toString().split('T').first 
                                          : 'N/A'}'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
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
  late MobileScannerController cameraController;

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  cameraController.stop();
                  Navigator.pop(context, code);
                }
              }
            },
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Close Scanner'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.green.withOpacity(0.5),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}