import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:workshop_tracking_app/screens/SecurityGuardDashboard.dart';
import 'package:workshop_tracking_app/screens/TechnicianDashboard.dart';
import 'package:workshop_tracking_app/screens/WashingDashboard.dart';
import 'package:workshop_tracking_app/screens/DriverDashboard.dart';
import 'package:workshop_tracking_app/screens/FinalInspectionDashboard.dart';
import 'package:workshop_tracking_app/screens/ServiceAdvisorDashboard.dart';
import 'package:workshop_tracking_app/screens/JobControllerDashboard.dart';
import 'package:workshop_tracking_app/screens/PartsTeamDashboard.dart';
import 'package:workshop_tracking_app/screens/AdminDashboard.dart';

// Import the global navigatorKey from main.dart
import '../main.dart';

const String baseUrl = 'https://mg-vts-backend.onrender.com/api';
final storage = FlutterSecureStorage();

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String phone = '';
  String email = '';
  String password = '';
  String role = 'Technician';
  String team = 'A';

  final List<String> roles = [
    'Admin',
    'Technician',
    'Service Advisor',
    'Quality Inspector',
    'Job Controller',
    'Washing',
    'Security Guard',
    'Driver',
    'Parts Team'
  ];

  final List<String> teams = ['A', 'B', 'None'];

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
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
          navigateToDashboard(userRole, token);
        } else {
          // Token invalid or expired, remove it
          await storage.delete(key: 'token');
        }
      } catch (e) {
        // Ignore errors, stay on login screen
      }
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      final url = isLogin ? '$baseUrl/login' : '$baseUrl/register';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(
          isLogin
              ? {
                  'phone': phone,
                  'password': password,
                }
              : {
                  'name': name,
                  'phone': phone,
                  'email': email,
                  'password': password,
                  'role': role,
                  'team': team,
                },
        ),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (isLogin) {
          String userRole = data['user']['role'];
          String token = data['token'];
          // Store token securely for persistent login
          await storage.write(key: 'token', value: token);
          navigateToDashboard(userRole, token);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful. Please log in.')),
          );
          setState(() {
            isLogin = true;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Authentication Failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void navigateToDashboard(String role, String token) {
    Widget page;

    void handleLogout() async {
      await storage.delete(key: 'token');
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    }

    switch (role) {
      case 'Admin':
        page = AdminDashboard(token: token, onLogout: handleLogout);
        break;
      case 'Technician':
        page = TechnicianDashboard(token: token, onLogout: handleLogout);
        break;
      case 'Service Advisor':
        page = ServiceAdvisorDashboard(token: token, onLogout: handleLogout);
        break;
      case 'Quality Inspector':
        page = FinalInspectionDashboard(token: token, onLogout: handleLogout);
        break;
      case 'Job Controller':
        page = JobControllerDashboard(token: token, onLogout: handleLogout);
        break;
      case 'Washing':
        page = WashingDashboard(token: token, onLogout: handleLogout);
        break;
      case 'Security Guard':
        page = SecurityGuardDashboard(token: token, onLogout: handleLogout);
        break;
      case 'Driver':
        page = DriverDashboard(token: token, onLogout: handleLogout);
        break;
      case 'Parts Team':
        page = PartsTeamDashboard(token: token, onLogout: handleLogout);
        break;
      default:
        page = const Scaffold(
          body: Center(child: Text('Unknown Role')),
        );
    }

    navigatorKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => page),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Spacer(),
                      Text(
                        'Raam Group MG',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD5001C),
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    isLogin ? 'Welcome to MG Workshop' : 'Register for MG Workshop',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 1.1,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLogin
                        ? 'Login to continue'
                        : 'Create your account below',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (!isLogin)
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Please enter name' : null,
                            onSaved: (value) => name = value!,
                          ),
                        if (!isLogin) const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) =>
                              value!.isEmpty ? 'Please enter phone number' : null,
                          onSaved: (value) => phone = value!,
                        ),
                        if (!isLogin) const SizedBox(height: 16),
                        if (!isLogin)
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            onSaved: (value) => email = value ?? '',
                          ),
                        if (!isLogin) const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          obscureText: true,
                          validator: (value) =>
                              value!.isEmpty ? 'Please enter password' : null,
                          onSaved: (value) => password = value!,
                        ),
                        if (!isLogin) const SizedBox(height: 16),
                        if (!isLogin)
                          DropdownButtonFormField(
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              prefixIcon: Icon(Icons.work),
                            ),
                            value: role,
                            items: roles
                                .map((role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(role),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                role = value!;
                              });
                            },
                          ),
                        if (!isLogin) const SizedBox(height: 16),
                        if (!isLogin)
                          DropdownButtonFormField(
                            decoration: const InputDecoration(
                              labelText: 'Team',
                              prefixIcon: Icon(Icons.group),
                            ),
                            value: team,
                            items: teams
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                team = value!;
                              });
                            },
                          ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: submit,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14.0),
                              child: Text(
                                isLogin ? 'Login' : 'Register',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isLogin = !isLogin;
                            });
                          },
                          child: Text(
                            isLogin
                                ? "Don't have an account? Register"
                                : "Already have an account? Login",
                            style: const TextStyle(
                              color: Color(0xFFD5001C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
