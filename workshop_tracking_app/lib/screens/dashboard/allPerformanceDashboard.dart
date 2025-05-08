import 'package:flutter/material.dart';
import 'individualDashboard/driverPerformance.dart'; // Import the driverPerformance file

class AllPerformanceDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Retrieve the token from the context or a global state
    final token = ModalRoute.of(context)!.settings.arguments as String?;

    // Handle case where the token is not available
    if (token == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('All Performance Dashboard'),
        ),
        body: Center(child: Text('Token not available! Please log in again.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Performance Dashboard'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Navigate to the DriverPerformancePage with the retrieved token
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DriverPerformancePage(token: token), // Pass the token
              ),
            );
          },
          child: const Text('View Driver Performance'),
        ),
      ),
    );
  }
}
