import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import 'package:workshop_tracking_app/screens/SecurityGuardDashboard.dart';
import 'package:workshop_tracking_app/screens/TechnicianDashboard.dart';
import 'package:workshop_tracking_app/screens/WashingDashboard.dart';
import 'package:workshop_tracking_app/screens/DriverDashboard.dart';
import 'package:workshop_tracking_app/screens/FinalInspectionDashboard.dart';
import 'package:workshop_tracking_app/screens/ServiceAdvisorDashboard.dart';
import 'package:workshop_tracking_app/screens/JobControllerDashboard.dart';
import 'package:workshop_tracking_app/screens/PartsTeamDashboard.dart';
import 'package:workshop_tracking_app/screens/AdminDashboard.dart';



const String baseUrl = 'http://192.168.0.103:5000/api';

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
        navigateToDashboard(userRole, token);
      } else {
        // Registration success: show success and go back to login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful. Please log in.')),
        );
        setState(() {
          isLogin = true; // Switch to login form
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

    switch (role) {
      case 'Admin':
        page = AdminDashboard(token: token);
        break;
      case 'Technician':
        page = TechnicianDashboard(token: token);
        break;
      case 'Service Advisor':
        page = ServiceAdvisorDashboard(token : token);
        break;
      case 'Quality Inspector':
        page = FinalInspectionDashboard(token: token);
        break;
      case 'Job Controller':
        page = JobControllerDashboard(token: token);
        break;
      case 'Washing':
        page = WashingDashboard(token: token);
        break;
      case 'Security Guard':
        page = SecurityGuardDashboard(token: token);
        break;
      case 'Driver':
        page = DriverDashboard(token: token);
        break;
      case 'Parts Team':
        page = PartsTeamDashboard(token:token);
        break;
      default:
        page = Scaffold(body: Center(child: Text('Unknown Role')));
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Login' : 'Register'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (!isLogin)
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter name' : null,
                  onSaved: (value) => name = value!,
                ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value!.isEmpty ? 'Please enter phone number' : null,
                onSaved: (value) => phone = value!,
              ),
              if (!isLogin)
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  onSaved: (value) => email = value ?? '',
                ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) =>
                    value!.isEmpty ? 'Please enter password' : null,
                onSaved: (value) => password = value!,
              ),
              if (!isLogin)
                DropdownButtonFormField(
                  decoration: const InputDecoration(labelText: 'Role'),
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
              if (!isLogin)
                DropdownButtonFormField(
                  decoration: const InputDecoration(labelText: 'Team'),
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: submit,
                child: Text(isLogin ? 'Login' : 'Register'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                  });
                },
                child: Text(isLogin
                    ? "Don't have an account? Register"
                    : "Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


