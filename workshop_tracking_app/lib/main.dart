import 'package:flutter/material.dart';
import 'authScreen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Import your dashboards here
import 'package:workshop_tracking_app/screens/SecurityGuardDashboard.dart';
import 'package:workshop_tracking_app/screens/TechnicianDashboard.dart';
import 'package:workshop_tracking_app/screens/WashingDashboard.dart';
import 'package:workshop_tracking_app/screens/DriverDashboard.dart';
import 'package:workshop_tracking_app/screens/FinalInspectionDashboard.dart';
import 'package:workshop_tracking_app/screens/ServiceAdvisorDashboard.dart';
import 'package:workshop_tracking_app/screens/JobControllerDashboard.dart';
import 'package:workshop_tracking_app/screens/PartsTeamDashboard.dart';
import 'package:workshop_tracking_app/screens/AdminDashboard.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const String baseUrl = 'https://mg-vts-backend.onrender.com/api';
final storage = FlutterSecureStorage();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget _home = const AuthScreen();

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final token = await storage.read(key: 'token');
    if (token != null) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/me'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final userData = json.decode(response.body);
          String userRole = userData['role'];
          setState(() {
            _home = _dashboardForRole(userRole, token);
          });
          return;
        } else {
          await storage.delete(key: 'token');
        }
      } catch (e) {
        // Ignore and show AuthScreen
      }
    }
    setState(() {
      _home = const AuthScreen();
    });
  }

  Widget _dashboardForRole(String role, String token) {
    void handleLogout() async {
      await storage.delete(key: 'token');
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    }

    switch (role) {
      case 'Admin':
        return AdminDashboard(token: token, onLogout: handleLogout);
      case 'Technician':
        return TechnicianDashboard(token: token, onLogout: handleLogout);
      case 'Service Advisor':
        return ServiceAdvisorDashboard(token: token, onLogout: handleLogout);
      case 'Quality Inspector':
        return FinalInspectionDashboard(token: token, onLogout: handleLogout);
      case 'Job Controller':
        return JobControllerDashboard(token: token, onLogout: handleLogout);
      case 'Washing':
        return WashingDashboard(token: token, onLogout: handleLogout);
      case 'Security Guard':
        return SecurityGuardDashboard(token: token, onLogout: handleLogout);
      case 'Driver':
        return DriverDashboard(token: token, onLogout: handleLogout);
      case 'Parts Team':
        return PartsTeamDashboard(token: token, onLogout: handleLogout);
      default:
        return const Scaffold(
          body: Center(child: Text('Unknown Role')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workshop Login/Register',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primaryColor: const Color(0xFFD5001C), // MG Red
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFD5001C),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD5001C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFD5001C), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          labelStyle: const TextStyle(color: Colors.black87),
        ),
      ),
      home: _home,
    );
  }
}
