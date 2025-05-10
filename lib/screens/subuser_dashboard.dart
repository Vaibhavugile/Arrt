import 'package:flutter/material.dart';

class SubuserDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subuser Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 100, color: Colors.orange),
            SizedBox(height: 20),
            Text(
              'Welcome, Subuser!',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Add your sign out logic here
              },
              child: Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}
