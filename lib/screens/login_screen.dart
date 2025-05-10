import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'admin_screen.dart';
import 'branch_dashboard.dart';
import 'subuser_dashboard.dart';
import '../providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _loading = false;
  String? _error;

  String formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      final month = parts[1].padLeft(2, '0');
      final day = parts[2].padLeft(2, '0');
      return '${parts[0]}-$month-$day';
    }
    return dateStr;
  }

  Future<void> _handleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final result = await auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = result.user;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          if (_rememberMe) {
            await prefs.setString('authToken', token);
            await prefs.setString('email', _emailController.text.trim());
            await prefs.setString('password', _passwordController.text.trim());
          }

          final email = _emailController.text.trim();
          final firestore = FirebaseFirestore.instance;

          final superAdmins = await firestore
              .collection('superadmins')
              .where('email', isEqualTo: email)
              .get();
          if (superAdmins.docs.isNotEmpty) {
            Provider.of<UserProvider>(context, listen: false)
                .setUserData(superAdmins.docs.first.data());
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => AdminScreen()));
            return;
          }

          final branches = await firestore
              .collection('branches')
              .where('emailId', isEqualTo: email)
              .get();
          if (branches.docs.isNotEmpty) {
            final data = branches.docs.first.data();
            final now = DateTime.now();
            if (now.isBefore(DateTime.parse(formatDate(data['activeDate'])))) {
              setState(() => _error = 'Branch plan not active yet.');
              return;
            }
            if (now.isAfter(DateTime.parse(formatDate(data['deactiveDate'])))) {
              setState(() => _error = 'Branch plan has expired.');
              return;
            }
            if (data['firstLogin'] == true) {
              // TODO: Navigate to password change screen
            } else {
              Provider.of<UserProvider>(context, listen: false)
                  .setUserData(data);
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => BranchDashboard()));
              return;
            }
          }

          final subusers = await firestore
              .collection('subusers')
              .where('email', isEqualTo: email)
              .get();
          if (subusers.docs.isNotEmpty) {
            final data = subusers.docs.first.data();
            if (data['isActive'] != true) {
              setState(() => _error = 'Subuser account is inactive.');
              return;
            }

            final now = DateTime.now();
            if (now.isBefore(DateTime.parse(formatDate(data['activeDate'])))) {
              setState(() => _error = 'Subuser plan not active.');
              return;
            }
            if (now.isAfter(DateTime.parse(formatDate(data['deactiveDate'])))) {
              setState(() => _error = 'Subuser plan expired.');
              return;
            }

            final branch = await firestore
                .collection('branches')
                .where('branchCode', isEqualTo: data['branchCode'])
                .get();
            if (branch.docs.isEmpty) {
              setState(() => _error = 'Associated branch not found.');
              return;
            }

            final branchData = branch.docs.first.data();
            if (now.isBefore(DateTime.parse(formatDate(branchData['activeDate']))) ||
                now.isAfter(DateTime.parse(formatDate(branchData['deactiveDate'])))) {
              setState(() => _error = 'Branch plan is not valid.');
              return;
            }

            Provider.of<UserProvider>(context, listen: false)
                .setUserData(data);
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => SubuserDashboard()));
            return;
          }

          setState(() => _error = 'No user found with the provided credentials.');
        } else {
          setState(() => _error = 'Failed to retrieve token.');
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _emailController.text = prefs.getString('email') ?? '';
    _passwordController.text = prefs.getString('password') ?? '';
    setState(() {
      _rememberMe = prefs.containsKey('authToken');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          child: Animate(
            effects: [FadeEffect(duration: 600.ms), MoveEffect(begin: Offset(0, 30))],
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Welcome to Arthaa",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: "Email",
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (val) =>
                                setState(() => _rememberMe = val ?? false),
                          ),
                          Text("Remember Me"),
                        ],
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: _loading
                              ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ))
                              : Icon(Icons.login),
                          label: Text("Login"),
                          onPressed: _loading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
