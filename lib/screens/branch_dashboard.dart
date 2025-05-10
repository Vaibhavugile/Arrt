import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'billing_screen.dart';
import 'product_screen.dart';
import 'inventory_screen.dart';
import 'vendor_screen.dart';
import 'order_report_screen.dart';
import 'payment_report_screen.dart';
import 'due_payment_report_screen.dart';

class BranchDashboard extends StatefulWidget {
  @override
  _BranchDashboardState createState() => _BranchDashboardState();
}

class _BranchDashboardState extends State<BranchDashboard> {
  bool isDarkMode = false;

  final List<_DashboardItem> dashboardItems = [
    _DashboardItem('Billing', Icons.attach_money, BillingScreen()),
    _DashboardItem('Products', Icons.shopping_cart, ProductScreen()),
    _DashboardItem('Inventory', Icons.inventory, InventoryScreen()),
    _DashboardItem('Vendors', Icons.business, VendorScreen()),
    _DashboardItem('Order Report', Icons.receipt_long, OrderReportScreen()),
    _DashboardItem('Payment Report', Icons.payment, PaymentReportScreen()),
    _DashboardItem('Due Payments', Icons.money_off, DuePaymentReportScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDarkMode
          ? ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black)
          : ThemeData.light().copyWith(scaffoldBackgroundColor: Colors.white),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Branch Dashboard'),
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.green,
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () {
                // TODO: Add logout logic
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.builder(
            itemCount: dashboardItems.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final item = dashboardItems[index];
              return Animate(
                effects: [
                  FadeEffect(duration: 500.ms),
                  ScaleEffect(begin: Offset(0.95, 0.95), end: Offset(1.0, 1.0), duration: 400.ms),
                  MoveEffect(begin: Offset(0, 30), duration: 400.ms),
                ],
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => item.screen),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white.withOpacity(0.4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(2, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.greenAccent.withOpacity(0.3),
                              ),
                              padding: EdgeInsets.all(16),
                              child: Icon(
                                item.icon,
                                size: 40,
                                color: isDarkMode ? Colors.white70 : Colors.green[800],
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.green,
          onPressed: () {
            setState(() {
              isDarkMode = !isDarkMode;
            });
          },
          child: Icon(
            isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: isDarkMode ? Colors.white : Colors.white,
          ),
          tooltip: "Toggle Theme",
        ),
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final IconData icon;
  final Widget screen;

  _DashboardItem(this.title, this.icon, this.screen);
}
