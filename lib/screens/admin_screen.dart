import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart'; // Import this for defaultTargetPlatform

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

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController; // For web: to control AppBar tabs
  int _selectedIndex = 0; // For mobile: to control BottomNavigationBar

  // List of screens
  final List<Widget> _screens = [
    BillingScreen(),
    ProductScreen(),
    InventoryScreen(),
    VendorScreen(),
    OrderReportScreen(),
    PaymentReportScreen(),
    DuePaymentReportScreen(),
  ];

  // List of navigation destinations (icon + label)
  final List<Map<String, dynamic>> _destinations = [
    {'icon': Icons.attach_money, 'label': 'Billing'},
    {'icon': Icons.shopping_cart, 'label': 'Products'},
    {'icon': Icons.inventory, 'label': 'Inventory'},
    {'icon': Icons.business, 'label': 'Vendors'},
    {'icon': Icons.receipt_long, 'label': 'Order Report'},
    {'icon': Icons.payment, 'label': 'Payment Report'},
    {'icon': Icons.money_off, 'label': 'Due Payments'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _screens.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onItemTappedMobile(int index) {
    setState(() {
      _selectedIndex = index;
      if (kIsWeb) {
        _tabController.index = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isWebPlatform = kIsWeb;
    print('Is Web Platform: $isWebPlatform');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Handle logout functionality
            },
          ),
        ],
        bottom: isWebPlatform
            ? TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _destinations.map((destination) {
            return Tab(
              icon: Icon(destination['icon'] as IconData),
              text: destination['label'] as String,
            );
          }).toList(),
        )
            : null,
      ),
      body: Animate(
        effects: [FadeEffect(duration: 600.ms), MoveEffect(begin: const Offset(0, 30))],
        child: isWebPlatform
            ? Container( // Add Container for visual debugging on web
          color: const Color(0xFFD4AF37).withOpacity(0.3), // Distinct color for web
          child: TabBarView(
            controller: _tabController,
            children: _screens,
          ),
        )
            : Container( // Add Container for visual debugging on mobile
          color: const Color(0xFFD4AF37).withOpacity(0.3), // Distinct color for mobile
          child: _screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: isWebPlatform
          ? null
          : BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTappedMobile,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: _destinations.map((destination) {
          return BottomNavigationBarItem(
            icon: Icon(destination['icon'] as IconData),
            label: destination['label'] as String,
          );
        }).toList(),
      ),
    );
  }
}