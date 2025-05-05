import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SecurityGuardDashboard extends StatefulWidget {
  final String token; // Token will come from parent widget

  const SecurityGuardDashboard({Key? key, required this.token}) : super(key: key);

  @override
  State<SecurityGuardDashboard> createState() => _SecurityGuardDashboardState();
}

class _SecurityGuardDashboardState extends State<SecurityGuardDashboard> {
  // Submission variables
  String? scannedVehicleNumber;
  bool isScanning = false;
  String eventType = 'Start';
  final TextEditingController kmController = TextEditingController();
  final TextEditingController vehicleNumberController = TextEditingController();

  // History variables
  List<Map<String, dynamic>> inVehicles = [];
  List<Map<String, dynamic>> outVehicles = [];
  final TextEditingController searchVehicleController = TextEditingController();
  DateTime? fromDate;
  DateTime? toDate;
  bool isLoadingHistory = false;
  String? historyError;

  final String backendUrl = 'http://192.168.0.103:5000/api/vehicle-check';
  final String historyUrl = 'http://192.168.0.103:5000/api/security-gate-history';

  @override
  void initState() {
    super.initState();
    fetchVehicleHistory();
  }

  @override
  void dispose() {
    kmController.dispose();
    vehicleNumberController.dispose();
    searchVehicleController.dispose();
    super.dispose();
  }

  // QR Scanner
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

  // Submit IN/OUT event
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

    try {
      Map<String, dynamic> body = {
        'vehicleNumber': vehicleNumber,
        'stage': 'securityGate',
        'eventType': eventType,
        'role': 'Security Guard',
      };
      if (eventType == 'Start') {
        body['inKM'] = km;
      } else {
        body['outKM'] = km;
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
        setState(() {
          scannedVehicleNumber = null;
          vehicleNumberController.clear();
          kmController.clear();
          eventType = 'Start';
        });
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

  // Date picker helper
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

  // Fetch vehicle history
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

  // Responsive padding
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
                                  setState(() => eventType = value!);
                                },
                              ),
                              const Text('IN', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 20),
                              Radio<String>(
                                value: 'End',
                                groupValue: eventType,
                                onChanged: (value) {
                                  setState(() => eventType = value!);
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
                                  subtitle: Text(
                                    'In KM: ${vehicle['inKM'] ?? '-'}\n'
                                    'In Time: ${vehicle['inTime'] != null ? vehicle['inTime'].toString().split('T').first : 'N/A'}',
                                    style: const TextStyle(fontSize: 15),
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
                                  subtitle: Text(
                                    'In KM: ${vehicle['inKM'] ?? '-'}\n'
                                    'Out KM: ${vehicle['outKM'] ?? '-'}\n'
                                    'In Time: ${vehicle['inTime'] != null ? vehicle['inTime'].toString().split('T').first : 'N/A'}\n'
                                    'Out Time: ${vehicle['outTime'] != null ? vehicle['outTime'].toString().split('T').first : 'N/A'}',
                                    style: const TextStyle(fontSize: 15),
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

// QR Scanner Screen (unchanged)
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
