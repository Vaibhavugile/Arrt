import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app.dart';

import 'billing_screen.dart';
import 'product_screen.dart';
import 'inventory_screen.dart';
import 'vendor_screen.dart';
import 'order_report_screen.dart';
import 'payment_report_screen.dart';

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
];
}

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
final S = AppLocalizations.of(context)!;
final dashboardItems = getDashboardItems(context);
final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.grey[100];

return Scaffold(
appBar: AppBar(
title: Text(S.branchDashboard, style: const TextStyle(color: Colors.white)),
backgroundColor: isDarkMode ? Colors.grey[850] : const Color(0xFF4CB050),
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
PopupMenuItem(value: 'mr', child: Text('मराठी')),
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
backgroundColor: backgroundColor,
body: Padding(
padding: const EdgeInsets.all(16.0),
child: GridView.count(
crossAxisCount: 2,
crossAxisSpacing: 16,
mainAxisSpacing: 16,
children: dashboardItems.map((item) {
return GestureDetector(
onTap: () => Navigator.push(
context,
MaterialPageRoute(builder: (_) => item.screen),
),
child: Container(
decoration: BoxDecoration(
color: isDarkMode ? Colors.grey[800] : Colors.white,
borderRadius: BorderRadius.circular(12),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(0.05),
blurRadius: 8,
offset: const Offset(0, 4),
),
],
),
padding: const EdgeInsets.all(16),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
crossAxisAlignment: CrossAxisAlignment.center,
children: [
Icon(
item.icon,
size: 40,
color: isDarkMode ? Colors.greenAccent : Colors.green[700],
),
const SizedBox(height: 12),
Text(
item.title,
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.w600,
color: isDarkMode ? Colors.white70 : Colors.black87,
),
),
],
),
),
);
}).toList(),
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
