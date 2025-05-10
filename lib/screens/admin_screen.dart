import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'billing_screen.dart';
import 'product_screen.dart';
import 'inventory_screen.dart';
import 'vendor_screen.dart';
import 'order_report_screen.dart';
import 'payment_report_screen.dart';
import 'due_payment_report_screen.dart';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;

  // List of screens for BottomNavigationBar items
  final List<Widget> _screens = [
    BillingScreen(),
    ProductScreen(),
    InventoryScreen(),
    VendorScreen(),
    OrderReportScreen(),
    PaymentReportScreen(),
    DuePaymentReportScreen(),
  ];

  // Update the selected screen when tapping on an icon
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              // Handle logout functionality
            },
          ),
        ],
      ),
      body: Animate(
        effects: [FadeEffect(duration: 600.ms), MoveEffect(begin: Offset(0, 30))],
        child: _screens[_selectedIndex], // Display screen based on selected index
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Billing',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Vendors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Order Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: 'Payment Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Due Payments',
          ),
        ],
      ),
    );
  }
}
