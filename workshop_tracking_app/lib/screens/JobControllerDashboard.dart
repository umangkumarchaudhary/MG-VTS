import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class JobControllerDashboard extends StatefulWidget {
  final String token;
  const JobControllerDashboard({Key? key, required this.token}) : super(key: key);

  @override
  _JobControllerDashboardState createState() => _JobControllerDashboardState();
}

class _JobControllerDashboardState extends State<JobControllerDashboard> {
  String? vehicleNumber;
  String? selectedExpert;
  List<String> selectedTechnicians = [];
  String? vehicleModel;
  String? serviceType;
  String? jobDescription;
  String? itemDescription;
  double? frtHours;
  bool isLoading = false;
  int _currentIndex = 0;
  bool hasScanned = false;

  final GlobalKey<FormState> _bayAllocationFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _assignExpertFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _finishJobFormKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> technicians = [];
  List<Map<String, dynamic>> experts = [];
  List<String> serviceTypes = [
    'General Repair',
    'Periodic Maintenance',
    'Body Repair',
    'Electrical Work',
    'AC Service'
  ];

  @override
  void initState() {
    super.initState();
    fetchTechnicians();
    fetchExperts();
  }

  Future<void> fetchTechnicians() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.9.70:5000/api/technicians'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          technicians = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching technicians: $e')),
      );
    }
  }

  Future<void> fetchExperts() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.9.70:5000/api/technicians'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          experts = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching experts: $e')),
      );
    }
  }

  Future<void> scanQRCode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
    if (barcode != null && mounted) {
      setState(() {
        vehicleNumber = barcode;
        hasScanned = true;
      });
      fetchVehicleDetails(barcode);
    }
  }

  Future<void> fetchVehicleDetails(String vehicleNumber) async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://192.168.9.70:5000/api/vehicles/$vehicleNumber'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Update UI with vehicle details if needed
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vehicle details not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching vehicle: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> handleBayAllocation() async {
    if (!_bayAllocationFormKey.currentState!.validate()) return;
    if (vehicleNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan vehicle QR first')),
      );
      return;
    }
    
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('http://192.168.9.70:5000/api/vehicle-check'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'vehicleNumber': vehicleNumber,
          'stage': 'bayAllocation',
          'eventType': 'Start',
          'role': 'JobController',
          'vehicleModel': vehicleModel,
          'serviceType': serviceType,
          'jobDescription': jobDescription,
          'itemDescription': itemDescription,
          'frtHours': frtHours,
          'technicians': selectedTechnicians,
        }),
      );

      final result = json.decode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Bay allocated successfully')),
        );
        _bayAllocationFormKey.currentState?.reset();
        setState(() {
          selectedTechnicians = [];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to allocate bay')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> handleAssignExpert() async {
    if (!_assignExpertFormKey.currentState!.validate()) return;
    if (vehicleNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan vehicle QR first')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('http://192.168.9.70:5000/api/vehicle-check'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'vehicleNumber': vehicleNumber,
          'stage': 'assignExpert',
          'eventType': 'Start',
          'role': 'JobController',
          'expertName': selectedExpert,
        }),
      );

      final result = json.decode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Expert assigned successfully')),
        );
        _assignExpertFormKey.currentState?.reset();
        setState(() {
          selectedExpert = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to assign expert')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> handleJobFinished() async {
    if (vehicleNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan vehicle QR first')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('http://192.168.9.70:5000/api/vehicle-check'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'vehicleNumber': vehicleNumber,
          'stage': 'jobCardReceived',
          'eventType': 'End',
          'role': 'JobController',
        }),
      );

      final result = json.decode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Job marked as finished')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to mark job as finished')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Controller Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: scanQRCode,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: Text(
                  vehicleNumber ?? 'No vehicle scanned',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: hasScanned ? Colors.green : Colors.grey,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: scanQRCode,
                ),
                subtitle: hasScanned ? null : const Text('Scan vehicle QR to begin'),
              ),
            ),
            const SizedBox(height: 20),
            
            if (!hasScanned)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code, size: 100, color: Colors.grey),
                      const SizedBox(height: 20),
                      const Text(
                        'Scan Vehicle QR Code',
                        style: TextStyle(fontSize: 20, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan QR'),
                        onPressed: scanQRCode,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    // Bay Allocation Section
                    Form(
                      key: _bayAllocationFormKey,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Vehicle Model',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                              onChanged: (value) => vehicleModel = value,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Service Type',
                                border: OutlineInputBorder(),
                              ),
                              items: serviceTypes.map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              )).toList(),
                              onChanged: (value) => serviceType = value,
                              validator: (value) => value == null ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Job Description',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                              onChanged: (value) => jobDescription = value,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Item Description',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                              onChanged: (value) => itemDescription = value,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'FRT Hours',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Required';
                                if (double.tryParse(value!) == null) return 'Enter valid number';
                                return null;
                              },
                              onChanged: (value) => frtHours = double.tryParse(value ?? '0'),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            if (technicians.isNotEmpty)
                              MultiSelectChipField(
                                items: technicians.map((tech) => MultiSelectItem(
                                  tech['_id'].toString(),
                                  "${tech['name']} (${tech['team']})"
                                )).toList(),
                                title: const Text("Select Technicians"),
                                selectedItems: selectedTechnicians,
                                onSelectionChanged: (values) {
                                  setState(() {
                                    selectedTechnicians = values.cast<String>();
                                  });
                                },
                                validator: (values) => values?.isEmpty ?? true ? 'Select at least one' : null,
                              )
                            else
                              const CircularProgressIndicator(),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: isLoading ? null : handleBayAllocation,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: isLoading 
                                  ? const CircularProgressIndicator()
                                  : const Text('Allocate Bay'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Assign Expert Section
                    Form(
                      key: _assignExpertFormKey,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            if (experts.isNotEmpty)
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Select Expert',
                                  border: OutlineInputBorder(),
                                ),
                                items: experts.map((expert) => DropdownMenuItem<String>(
                                  value: expert['_id'].toString(),
                                  child: Text("${expert['name']} (${expert['team']})"),
                                )).toList(),
                                onChanged: (value) => selectedExpert = value,
                                validator: (value) => value == null ? 'Required' : null,
                              )
                            else
                              const CircularProgressIndicator(),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: isLoading ? null : handleAssignExpert,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: isLoading 
                                  ? const CircularProgressIndicator()
                                  : const Text('Assign Expert'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Job Finished Section (Simplified)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.done_all, size: 60, color: Colors.green),
                          const SizedBox(height: 20),
                          const Text(
                            'Mark Job as Finished',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            'Vehicle: ${vehicleNumber ?? 'Not scanned'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: isLoading ? null : handleJobFinished,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(200, 50),
                              backgroundColor: Colors.green,
                            ),
                            child: isLoading 
                                ? const CircularProgressIndicator()
                                : const Text('Confirm Finish'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_parking),
            label: 'Bay Allocation',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Assign Expert',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.done_all),
            label: 'Finish Job',
          ),
        ],
      ),
    );
  }
}

// QR Scanner Screen remains the same
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isScanning = true;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Vehicle QR')),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          if (!isScanning) return;
          final barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            isScanning = false;
            cameraController.stop();
            Navigator.pop(context, barcodes.first.rawValue!);
          }
        },
      ),
    );
  }
}

// MultiSelectChipField widget remains the same
class MultiSelectChipField extends StatelessWidget {
  final List<MultiSelectItem> items;
  final List selectedItems;
  final Function(List) onSelectionChanged;
  final Widget? title;
  final FormFieldValidator<List>? validator;

  const MultiSelectChipField({
    Key? key,
    required this.items,
    required this.selectedItems,
    required this.onSelectionChanged,
    this.title,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FormField<List>(
      validator: validator,
      builder: (FormFieldState<List> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) title!,
            Wrap(
              spacing: 8.0,
              children: items.map((item) {
                return ChoiceChip(
                  label: Text(item.label),
                  selected: selectedItems.contains(item.value),
                  onSelected: (selected) {
                    List newSelected = List.from(selectedItems);
                    if (selected) {
                      newSelected.add(item.value);
                    } else {
                      newSelected.remove(item.value);
                    }
                    onSelectionChanged(newSelected);
                    state.didChange(newSelected);
                  },
                );
              }).toList(),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class MultiSelectItem {
  final dynamic value;
  final String label;

  MultiSelectItem(this.value, this.label);
}