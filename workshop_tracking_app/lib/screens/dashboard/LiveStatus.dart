import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LiveStatusScreen extends StatefulWidget {
  @override
  _LiveStatusScreenState createState() => _LiveStatusScreenState();
}

class _LiveStatusScreenState extends State<LiveStatusScreen> {
  List<dynamic> vehicles = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchVehicleStatus();
  }

  Future<void> fetchVehicleStatus() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final response = await http.get(
        Uri.parse('https://mg-vts-backend.onrender.com/api/dashboard/status'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          vehicles = data['vehicles'];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching data: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Color getStatusColor(String status) {
    if (status.contains('Delivered')) return Colors.green[400]!;
    if (status.contains('Work in progress')) return Colors.blue[400]!;
    if (status.contains('Waiting')) return Colors.orange[400]!;
    if (status.contains('Inspection')) return Colors.purple[400]!;
    return Colors.grey[600]!;
  }

  IconData getStatusIcon(String status) {
    if (status.contains('Delivered')) return Icons.check_circle;
    if (status.contains('Work in progress')) return Icons.build;
    if (status.contains('Waiting')) return Icons.hourglass_empty;
    if (status.contains('Inspection')) return Icons.verified_user;
    return Icons.directions_car;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Vehicle Status Dashboard',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchVehicleStatus,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : RefreshIndicator(
                  onRefresh: fetchVehicleStatus,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      return Card(
                        elevation: 4,
                        margin: EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: getStatusColor(vehicle['status']),
                                width: 6,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      vehicle['vehicleNumber'],
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Chip(
                                      backgroundColor: getStatusColor(vehicle['status']).withOpacity(0.2),
                                      label: Text(
                                        vehicle['currentStage'],
                                        style: TextStyle(
                                          color: getStatusColor(vehicle['status']),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      getStatusIcon(vehicle['status']),
                                      color: getStatusColor(vehicle['status']),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        vehicle['status'],
                                        style: TextStyle(
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Divider(),
                                SizedBox(height: 8),
                                Text(
                                  'Last updated: ${DateTime.parse(vehicle['lastUpdated']).toLocal().toString().substring(0, 16)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black87,
        child: Icon(Icons.refresh),
        onPressed: fetchVehicleStatus,
      ),
    );
  }
}