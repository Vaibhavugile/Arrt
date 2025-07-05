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
  int _selectedIndex = 0; // To track the selected navigation item

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

    // Your Existing Theme Colors
    final Color appBarGradientStart = Color(0xFFE0FFFF); // Muted light blue
    final Color appBarGradientMid = Color(0xFFBFEBFA);   // Steel Blue
    final Color appBarGradientEnd = Color(0xFF87CEEB);   // Dark Indigo (This is a good accent color)

    // Mobile/App-style Card Colors
    final Color lightModeCardSolidColor = const Color(0xFFCBEEEE); // Peach Puff (for small screen cards)
    final Color darkModeCardColor = Colors.grey[800]!; // Dark mode card background (for small screen cards)
    final Color lightModeCardIconColor = Colors.black87; // Dark icons for contrast (for small screen cards)
    final Color lightModeCardTextColor = Colors.black87; // Dark text for contrast (for small screen cards)
    final Color darkModeIconColor = Color(0xFF9AC0C6); // Lighter blue for dark mode icons (for small screen cards)
    final Color darkModeTextColor = Colors.white70; // Dark text for contrast (for small screen cards)

    // Main content area background (still separate from sidebar for now, as it's the "body" background)
    final Color webContentBackgroundLight = Colors.white;
    final Color webContentBackgroundDark = Colors.grey[900]!;

    // Adjusted Web Sidebar Navigation Item Colors to match app-like card theme
    // For selected item, use appBarGradientMid as background for a highlight on the card
    final Color webSelectedNavItemBackground = appBarGradientMid; // Steel Blue for selected background
    final Color webSelectedNavItemContentColor = Colors.white; // White text/icon for selected item for contrast

    // For unselected, use the existing card text/icon colors
    final Color webUnselectedNavItemColorLight = lightModeCardTextColor;
    final Color webUnselectedNavItemColorDark = darkModeTextColor;

    // Sidebar branding/title text color (adjust to work with card background)
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
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              // TODO: Add logout logic
            },
          ),
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                isDarkMode = !isDarkMode;
              });
            },
            tooltip: S.toggleTheme,
          ),
        ],
        flexibleSpace: isDarkMode
            ? Container(
          color: Colors.grey[850],
        )
            : Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                appBarGradientStart,
                appBarGradientMid,
                appBarGradientEnd,
              ],
              stops: const [0.0, 0.5, 1.0],
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
                    // --- Side Navigation for Large Screens (App-like Card Theme) ---
                    Container(
                      width: 260,
                      decoration: BoxDecoration(
                        color: isDarkMode ? darkModeCardColor : lightModeCardSolidColor, // Use card colors for sidebar background
                        borderRadius: BorderRadius.circular(12), // Apply card border radius
                        boxShadow: [ // Apply card shadows
                          BoxShadow(
                            color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.15),
                            blurRadius: isDarkMode ? 8 : 10,
                            offset: Offset(0, isDarkMode ? 4 : 6),
                          ),
                        ],
                      ),
                      margin: const EdgeInsets.all(16.0), // Add margin to float like a card
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24.0, 24.0, 16.0, 16.0),
                            child: Row(
                              children: [
                                Icon(Icons.dashboard_customize, color: isDarkMode ? webSidebarTitleColorDark : webSidebarTitleColorLight, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  S.branchDashboard,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? webSidebarTitleColorDark : webSidebarTitleColorLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Divider might not be needed or can be adjusted if it doesn't fit the card aesthetic
                          Divider(color: isDarkMode ? Colors.white10 : Colors.grey[300], thickness: 1, height: 1),
                          Expanded(
                            child: ListView.builder(
                              itemCount: dashboardItems.length,
                              itemBuilder: (context, index) {
                                final item = dashboardItems[index];
                                final isSelected = _selectedIndex == index;
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedIndex = index;
                                      });
                                    },
                                    hoverColor: isDarkMode
                                        ? webSelectedNavItemBackground.withOpacity(0.5) // Using the new background for hover
                                        : webSelectedNavItemBackground.withOpacity(0.2), // Lighter hover for light mode
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? webSelectedNavItemBackground // Solid background for selected
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Adjusted margin
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                      child: Row(
                                        children: [
                                          Icon(
                                            item.icon,
                                            color: isSelected
                                                ? webSelectedNavItemContentColor // White for selected content
                                                : (isDarkMode ? webUnselectedNavItemColorDark : webUnselectedNavItemColorLight),
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected
                                                  ? webSelectedNavItemContentColor // White for selected content
                                                  : (isDarkMode ? webUnselectedNavItemColorDark : webUnselectedNavItemColorLight),
                                            ),
                                          ),
                                        ],
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
                    // --- Main Content Area ---
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
              else // Small Screen layout (retaining the original card grid)
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
                                offset: const Offset(0, 4),
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
                                offset: const Offset(0, 6),
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
                                color: isDarkMode ? darkModeIconColor : lightModeCardIconColor,
                              ),
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
              // Floating Action Button - only shown on small screens
              if (!isLargeScreen)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    backgroundColor: isDarkMode ? appBarGradientEnd : appBarGradientMid,
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