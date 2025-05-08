import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DriverPerformancePage extends StatefulWidget {
  final String token;

  const DriverPerformancePage({Key? key, required this.token}) : super(key: key);

  @override
  _DriverPerformancePageState createState() => _DriverPerformancePageState();
}

class _DriverPerformancePageState extends State<DriverPerformancePage> {
  DateTime selectedDate = DateTime.now();
  List<dynamic> performanceData = [];
  bool isLoading = false;

  Future<void> fetchPerformanceData() async {
    setState(() {
      isLoading = true;
    });

    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    final url = Uri.parse(
        'https://mg-vts-backend.onrender.com/api/driver-performance?date=$formattedDate');

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer ${widget.token}',
      });

      if (response.statusCode == 200) {
        setState(() {
          performanceData = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        print('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching data: $e');
    }
  }

  String formatDateTime(String isoString) {
    final date = DateTime.parse(isoString).toLocal();
    final formatter = DateFormat('dd MMM yyyy, hh:mm a', 'en_IN');
    return formatter.format(date);
  }

  String formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  @override
  void initState() {
    super.initState();
    fetchPerformanceData();
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      fetchPerformanceData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Performance'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _selectDate(context),
                  child: const Text('Pick Date'),
                ),
              ],
            ),
          ),
          isLoading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: performanceData.isEmpty
                      ? const Center(child: Text('No data found for this date.'))
                      : ListView.builder(
                          itemCount: performanceData.length,
                          itemBuilder: (context, index) {
                            final item = performanceData[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 2,
                              child: ListTile(
                                title: Text('Vehicle: ${item['vehicleNumber']}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item['driverName'] != null)
                                      Text('Driver: ${item['driverName']}'),
                                    Text('Pickup KM: ${item['pickupKM'] ?? 'N/A'}'),
                                    Text('Drop KM: ${item['dropKM'] ?? 'N/A'}'),
                                    Text(
                                        'Duration: ${formatDuration(item['durationInSeconds'])}'),
                                    Text('From: ${formatDateTime(item['startTime'])}'),
                                    Text('To: ${formatDateTime(item['endTime'])}'),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ],
      ),
    );
  }
}
