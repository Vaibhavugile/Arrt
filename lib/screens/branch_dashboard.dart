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
  int _selectedIndex = 0;

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

    final Color appBarGradientStart = Color(0xFFE0FFFF);
    final Color appBarGradientMid = Color(0xFFBFEBFA);
    final Color appBarGradientEnd = Color(0xFF87CEEB);

    final Color lightModeCardSolidColor = Color(0xFFCBEEEE);
    final Color darkModeCardColor = Colors.grey[800]!;
    final Color lightModeCardIconColor = Colors.black87;
    final Color lightModeCardTextColor = Colors.black87;
    final Color darkModeIconColor = Color(0xFF9AC0C6);
    final Color darkModeTextColor = Colors.white70;

    final Color webContentBackgroundLight = Colors.white;
    final Color webContentBackgroundDark = Colors.grey[900]!;

    final Color webSelectedNavItemColorLight = appBarGradientEnd;
    final Color webSelectedNavItemBackgroundLight = appBarGradientStart.withOpacity(0.4);
    final Color webSelectedNavItemColorDark = appBarGradientMid;
    final Color webSelectedNavItemBackgroundDark = Colors.black.withOpacity(0.3);

    final Color webUnselectedNavItemColorLight = Colors.grey[600]!;
    final Color webUnselectedNavItemColorDark = Colors.grey[400]!;

    final Color webSidebarTitleColorLight = Colors.black87;
    final Color webSidebarTitleColorDark = Colors.white;

    return Scaffold(
      backgroundColor: isDarkMode ? webContentBackgroundDark : webContentBackgroundLight,
      appBar: AppBar(
        title: Text(S.branchDashboard, style: const TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, color: Colors.white),
            onSelected: (value) {
              if (value == 'en') MyApp.setLocale(context, Locale('en'));
              else if (value == 'hi') MyApp.setLocale(context, Locale('hi'));
              else if (value == 'mr') MyApp.setLocale(context, Locale('mr'));
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(value: 'hi', child: Text('हिंदी')),
              PopupMenuItem(value: 'mr', child: Text('मराठी')),
            ],
          ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
            onPressed: () => setState(() => isDarkMode = !isDarkMode),
            tooltip: S.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {},
          ),
        ],
        flexibleSpace: isDarkMode
            ? Container(color: Colors.grey[850])
            : Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [appBarGradientStart, appBarGradientMid, appBarGradientEnd],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isLargeScreen = constraints.maxWidth > 700;

          return Stack(
            children: [
              if (isLargeScreen)
                Row(
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: 260,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 28, 16, 8),
                            child: Row(
                              children: [
                                Icon(Icons.dashboard_customize, color: isDarkMode ? Colors.white70 : Colors.black87, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  S.branchDashboard,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(color: isDarkMode ? Colors.white10 : Colors.grey[300], thickness: 1),
                          Expanded(
                            child: ListView.builder(
                              itemCount: dashboardItems.length,
                              itemBuilder: (context, index) {
                                final item = dashboardItems[index];
                                final isSelected = _selectedIndex == index;
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected
                                          ? (isDarkMode ? webSelectedNavItemColorDark : webSelectedNavItemColorLight)
                                          : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: isSelected
                                        ? (isDarkMode ? webSelectedNavItemBackgroundDark : webSelectedNavItemBackgroundLight)
                                        : (isDarkMode ? Colors.grey[850] : Colors.grey[100]),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => setState(() => _selectedIndex = index),
                                      splashColor: Colors.blue.withOpacity(0.1),
                                      hoverColor: Colors.grey.withOpacity(0.05),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        child: Row(
                                          children: [
                                            Icon(
                                              item.icon,
                                              size: 22,
                                              color: isSelected
                                                  ? (isDarkMode ? webSelectedNavItemColorDark : webSelectedNavItemColorLight)
                                                  : (isDarkMode ? webUnselectedNavItemColorDark : webUnselectedNavItemColorLight),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                  color: isSelected
                                                      ? (isDarkMode ? webSelectedNavItemColorDark : webSelectedNavItemColorLight)
                                                      : (isDarkMode ? webUnselectedNavItemColorDark : webUnselectedNavItemColorLight),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: isDarkMode ? webContentBackgroundDark : webContentBackgroundLight,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: dashboardItems[_selectedIndex].screen,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Padding(
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
                          decoration: isDarkMode
                              ? BoxDecoration(
                            color: darkModeCardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          )
                              : BoxDecoration(
                            color: lightModeCardSolidColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(item.icon, size: 40, color: isDarkMode ? darkModeIconColor : lightModeCardIconColor),
                              const SizedBox(height: 12),
                              Text(
                                item.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? darkModeTextColor : lightModeCardTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (!isLargeScreen)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    backgroundColor: isDarkMode ? appBarGradientEnd : appBarGradientMid,
                    onPressed: () => setState(() => isDarkMode = !isDarkMode),
                    child: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
                    tooltip: S.toggleTheme,
                  ),
                ),
            ],
          );
        },
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
