import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'billing_screen.dart';
import 'product_screen.dart';
import 'inventory_screen.dart';
import 'vendor_screen.dart';
import 'order_report_screen.dart';
import 'payment_report_screen.dart';
import 'due_payment_report_screen.dart';
import '../app.dart'; // Adjust path as needed if app.dart is in /lib

class BranchDashboard extends StatefulWidget {
  @override
  _BranchDashboardState createState() => _BranchDashboardState();
}

class _BranchDashboardState extends State<BranchDashboard> {
  bool isDarkMode = false;

  List<_DashboardItem> getDashboardItems(BuildContext context) {
    final S = AppLocalizations.of(context)!;
    return [
      _DashboardItem(S.billing, Icons.attach_money, BillingScreen()),
      _DashboardItem(S.products, Icons.shopping_cart, ProductScreen()),
      _DashboardItem(S.inventory, Icons.inventory, InventoryScreen()),
      _DashboardItem(S.vendors, Icons.business, VendorScreen()),
      _DashboardItem(S.orderReport, Icons.receipt_long, OrderReportScreen()),
      _DashboardItem(S.paymentReport, Icons.payment, PaymentReportScreen()),
      _DashboardItem(S.duePayments, Icons.money_off, DuePaymentReportScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final S = AppLocalizations.of(context)!;
    final dashboardItems = getDashboardItems(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(S.branchDashboard, style: const TextStyle(color: Colors.white)),
        backgroundColor: isDarkMode ? Colors.grey[900] : const Color(0xFF4CB050),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, color: Colors.white),
            onSelected: (value) {
              if (value == 'en') {
                MyApp.setLocale(context, const Locale('en'));
              } else if (value == 'hi') {
                MyApp.setLocale(context, const Locale('hi'));
              } else if (value == 'mr') {
                MyApp.setLocale(context, const Locale('mr'));
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(value: 'hi', child: Text('हिंदी')),
              PopupMenuItem(value: 'mr', child: Text('मराठी')), // ✅ New
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                ScaleEffect(begin: const Offset(0.95, 0.95), end: const Offset(1.0, 1.0), duration: 400.ms),
                MoveEffect(begin: const Offset(0, 30), duration: 400.ms),
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
                            offset: const Offset(2, 4),
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
                            padding: const EdgeInsets.all(16),
                            child: Icon(
                              item.icon,
                              size: 40,
                              color: isDarkMode ? Colors.white70 : Colors.green[800],
                            ),
                          ),
                          const SizedBox(height: 12),
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
          color: Colors.white,
        ),
        tooltip: S.toggleTheme,
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
