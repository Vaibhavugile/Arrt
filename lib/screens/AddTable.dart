import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // For UserProvider
import '../../providers/user_provider.dart';
import'package:art/screens/billing_screen.dart';

class AddTable extends StatefulWidget {
  @override
  _AddTableState createState() => _AddTableState();
}

class _AddTableState extends State<AddTable> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _tableNumberController = TextEditingController();
  bool sidebarOpen = false;

  @override
  void initState() {
    super.initState();
  }

  // Get the branchCode from UserProvider
  String? _getBranchCode() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    return userProvider.branchCode;
  }

  Future<void> _handleSubmit() async {
    final branchCode = _getBranchCode();
    if (_formKey.currentState!.validate() && branchCode != null) {
      try {
        // Reference to subcollection: tables/{branchCode}/tables
        CollectionReference tablesRef = FirebaseFirestore.instance
            .collection('tables')
            .doc(branchCode)
            .collection('tables');

        await tablesRef.add({
          'tableNumber': _tableNumberController.text,
          'branchCode': branchCode,
          'orders': [], // Initialize with an empty orders array
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Table added successfully")),
        );

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BillingScreen()),
        ); // Navigate to another screen
      } catch (error) {
        print("Error adding table: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding table")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF4CB050),
        title: Text(
          'Add Table',
          style: TextStyle(color: Colors.white), // 👈 Makes text white
        ),
        iconTheme: IconThemeData(color: Colors.white), // optional: makes back icon white too
      ),       body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Add New Table', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _tableNumberController,
                    decoration: InputDecoration(labelText: 'Table Number / Counter Number'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a table number';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _handleSubmit,
                    child: Text('Add Table'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
