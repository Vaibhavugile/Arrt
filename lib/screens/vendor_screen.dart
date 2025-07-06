import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'AddVendorPage.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class VendorScreen extends StatefulWidget {
  @override
  _VendorScreenState createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> {
  bool loading = true;
  List<Map<String, dynamic>> vendors = [];
  String? expandedVendorId; // Used for web view expansion
  String searchQuery = '';
  bool isDarkMode = false; // Added for theme toggle
  int _selectedSidebarIndex = 0; // To track selected sidebar item

  final dateFormat = DateFormat('dd-MM-yyyy');

  // Define actions for sidebar/speed dial
  List<_VendorActionItem> _getVendorActions(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return [
      _VendorActionItem(loc.addVendor, Icons.person_add, () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => AddVendorPage()));
      }),
      // Add more vendor-specific actions here if needed
    ];
  }

  @override
  void initState() {
    super.initState();
    fetchVendors();
  }

  Future<void> fetchVendors() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchCode = userProvider.userData?['branchCode'];

    if (branchCode == null) return;

    final vendorRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Vendors');

    final vendorSnapshot = await vendorRef.get();

    final vendorData = await Future.wait(vendorSnapshot.docs.map((doc) async {
      final stockSnapshot = await doc.reference.collection('Stock').get();
      final stockDetails = stockSnapshot.docs.map((s) => s.data()).toList();

      return {
        'id': doc.id,
        ...doc.data(),
        'stockDetails': stockDetails,
      };
    }));

    setState(() {
      vendors = vendorData;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final vendorActions = _getVendorActions(context);

    // Theme Colors (consistent with inventory_screen)
    final Color appBarGradientStart = Color(0xFFE0FFFF); // Muted light blue
    final Color appBarGradientMid = Color(0xFFBFEBFA); // Steel Blue
    final Color appBarGradientEnd = Color(0xFF87CEEB); // Dark Indigo

    final Color lightModeCardSolidColor =
    Color(0xFFCBEEEE); // Peach Puff (for small screen cards)
    final Color darkModeCardColor =
    Colors.grey[800]!; // Dark mode card background (for small screen cards)
    final Color lightModeCardIconColor =
        Colors.black87; // Dark icons for contrast (for small screen cards)
    final Color lightModeCardTextColor =
        Colors.black87; // Dark text for contrast (for small screen cards)
    final Color darkModeIconColor =
    Color(0xFF9AC0C6); // Lighter blue for dark mode icons (for small screen cards)
    final Color darkModeTextColor =
        Colors.white70; // Dark text for contrast (for small screen cards)

    final Color webContentBackgroundLight = Colors.white;
    final Color webContentBackgroundDark = Colors.grey[900]!;

    final Color webSelectedNavItemBackground = appBarGradientMid;
    final Color webSelectedNavItemContentColor = Colors.white;

    final Color webUnselectedNavItemColorLight = lightModeCardTextColor;
    final Color webUnselectedNavItemColorDark = darkModeTextColor;

    final Color webSidebarTitleColorLight = Colors.black87;
    final Color webSidebarTitleColorDark = Colors.white;

    return Animate(
      effects: [FadeEffect(duration: 500.ms), MoveEffect(begin: Offset(0, 40))],
      child: Scaffold(
        backgroundColor:
        isDarkMode ? webContentBackgroundDark : webContentBackgroundLight,
        appBar: AppBar(
          title: Text(loc.vendors,
              style: const TextStyle(color: Colors.black87)), // Changed to black87 for contrast
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
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
              tooltip: loc.toggleTheme,
            ),
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () async {
                final result = await showSearch<String?>(
                  context: context,
                  delegate: VendorSearchDelegate(loc),
                );
                if (result != null) {
                  // If a search result is selected, navigate to its detail screen
                  final selectedVendor = vendors.firstWhere((v) => v['id'] == result);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VendorDetailScreen(
                        vendor: selectedVendor,
                        stockDetails: List<Map<String, dynamic>>.from(selectedVendor['stockDetails'] ?? []),
                        comments: List<Map<String, dynamic>>.from(selectedVendor['comments'] ?? []),
                        isDarkMode: isDarkMode,
                        onVendorUpdate: fetchVendors, // Pass callback to refresh vendors
                      ),
                    ),
                  );
                }
              },
            )
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
        floatingActionButton: LayoutBuilder(
          builder: (context, constraints) {
            bool isLargeScreen = constraints.maxWidth > 700;
            if (isLargeScreen) {
              return Container(); // Hide FAB on large screens
            } else {
              return SpeedDial(
                animatedIcon: AnimatedIcons.menu_close,
                backgroundColor: isDarkMode ? appBarGradientEnd : appBarGradientMid,
                children: [
                  SpeedDialChild(
                    child: Icon(Icons.add),
                    label: loc.addVendor,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => AddVendorPage())),
                  ),
                ],
              );
            }
          },
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            bool isLargeScreen = constraints.maxWidth > 700;

            return Row(
              children: [
                if (isLargeScreen)
                  Container(
                    width: 260,
                    decoration: BoxDecoration(
                      color: isDarkMode ? darkModeCardColor : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.15),
                          blurRadius: isDarkMode ? 8 : 10,
                          offset: Offset(0, isDarkMode ? 4 : 6),
                        ),
                      ],
                    ),
                    margin: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24.0, 24.0, 16.0, 16.0),
                          child: Row(
                            children: [
                              Icon(Icons.people,
                                  color: isDarkMode
                                      ? webSidebarTitleColorDark
                                      : webSidebarTitleColorLight,
                                  size: 24),
                              SizedBox(width: 12),
                              Text(
                                loc.vendors,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? webSidebarTitleColorDark
                                      : webSidebarTitleColorLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                            color: isDarkMode ? Colors.white10 : Colors.grey[300],
                            thickness: 1,
                            height: 1),
                        Expanded(
                          child: ListView.builder(
                            itemCount: vendorActions.length,
                            itemBuilder: (context, index) {
                              final item = vendorActions[index];
                              final isSelected = _selectedSidebarIndex == index;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedSidebarIndex = index;
                                    });
                                    item.onTap();
                                  },
                                  hoverColor: isDarkMode
                                      ? webSelectedNavItemBackground.withOpacity(0.5)
                                      : webSelectedNavItemBackground.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? webSelectedNavItemBackground
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 16),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.icon,
                                          color: isSelected
                                              ? webSelectedNavItemContentColor
                                              : (isDarkMode
                                              ? webUnselectedNavItemColorDark
                                              : webUnselectedNavItemColorLight),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? webSelectedNavItemContentColor
                                                : (isDarkMode
                                                ? webUnselectedNavItemColorDark
                                                : webUnselectedNavItemColorLight),
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
                Expanded(
                  child: Container(
                    color: isDarkMode
                        ? webContentBackgroundDark
                        : webContentBackgroundLight,
                    child: loading
                        ? Center(child: CircularProgressIndicator())
                        : vendors.isEmpty
                        ? Center(child: Text(loc.noVendorsFound))
                        : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: isLargeScreen
                          ? _buildVendorList(loc, isDarkMode,
                          lightModeCardSolidColor, darkModeCardColor, darkModeIconColor, lightModeCardIconColor, darkModeTextColor, lightModeCardTextColor)
                          : GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: vendors.map((vendor) {
                          final List<Map<String, dynamic>> stockDetails =
                          List<Map<String, dynamic>>.from(vendor['stockDetails'] ?? []);
                          final List<Map<String, dynamic>> comments =
                          List<Map<String, dynamic>>.from(vendor['comments'] ?? []);

                          final total = stockDetails.fold<double>(
                            0.0,
                                (sum, item) =>
                            sum + (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0),
                          );
                          final totalPaid = comments.fold<double>(
                            0.0,
                                (sum, c) =>
                            sum + (double.tryParse(c['amountPaid']?.toString() ?? '0') ?? 0.0),
                          );
                          final pending = total - totalPaid;

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VendorDetailScreen(
                                    vendor: vendor,
                                    stockDetails: stockDetails,
                                    comments: comments,
                                    isDarkMode: isDarkMode,
                                    onVendorUpdate: fetchVendors, // Pass callback to refresh vendors
                                  ),
                                ),
                              );
                            },
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
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                crossAxisAlignment:
                                CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 40,
                                    color: isDarkMode
                                        ? darkModeIconColor
                                        : lightModeCardIconColor,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    vendor['name'] ?? loc.noName,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? darkModeTextColor
                                          : lightModeCardTextColor,
                                    ),
                                  ),
                                  Text(
                                    '${loc.total}: ₹${total.toStringAsFixed(2)}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? darkModeTextColor
                                          : lightModeCardTextColor,
                                    ),
                                  ),
                                  Text(
                                    '${loc.pending}: ₹${pending.toStringAsFixed(2)}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? darkModeTextColor
                                          : lightModeCardTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVendorList(
      AppLocalizations loc,
      bool isDarkMode,
      Color lightModeCardSolidColor,
      Color darkModeCardColor,
      Color darkModeIconColor,
      Color lightModeCardIconColor,
      Color darkModeTextColor,
      Color lightModeCardTextColor) {
    return ListView.builder(
      padding: EdgeInsets.all(12),
      itemCount: vendors.length,
      itemBuilder: (context, i) {
        final vendor = vendors[i];
        final List<Map<String, dynamic>> stockDetails =
        List<Map<String, dynamic>>.from(vendor['stockDetails'] ?? []);
        final isExpanded = expandedVendorId == vendor['id'];

        // Sort comments by date in descending order (latest first)
        final List<Map<String, dynamic>> comments =
        List<Map<String, dynamic>>.from(vendor['comments'] ?? []);
        comments.sort((a, b) {
          DateTime dateA;
          DateTime dateB;
          try {
            dateA = dateFormat.parse(a['date'] ?? '01-01-1900');
          } catch (e) {
            dateA = DateTime(1900, 1, 1); // Default to a very old date on parse error
          }
          try {
            dateB = dateFormat.parse(b['date'] ?? '01-01-1900');
          } catch (e) {
            dateB = DateTime(1900, 1, 1); // Default to a very old date on parse error
          }
          return dateB.compareTo(dateA); // Descending order
        });


        final total = stockDetails.fold<double>(
          0.0,
              (sum, item) =>
          sum + (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0),
        );
        final totalPaid = comments.fold<double>(
          0.0,
              (sum, c) =>
          sum + (double.tryParse(c['amountPaid']?.toString() ?? '0') ?? 0.0),
        );
        final pending = total - totalPaid;

        return Card(
          elevation: 3,
          margin: EdgeInsets.only(bottom: 16),
          color: isDarkMode ? darkModeCardColor : lightModeCardSolidColor,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(vendor['name'] ?? loc.noName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? darkModeTextColor
                              : lightModeCardTextColor)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${loc.total}: ₹${total.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: isDarkMode ? darkModeTextColor : Colors.blue[800], fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${loc.paid}: ₹${totalPaid.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: isDarkMode ? darkModeTextColor : Colors.green[700], fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${loc.pending}: ₹${pending.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: isDarkMode ? darkModeTextColor : Colors.red[700], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit button in web view
                      IconButton(
                        icon: Icon(Icons.edit,
                            color: isDarkMode
                                ? darkModeIconColor
                                : lightModeCardIconColor),
                        onPressed: () {
                          // For web, if 'edit' means opening a new page, navigate.
                          // If it means showing an inline form, that logic would be here.
                          // For this context, let's assume it leads to a detail/edit page.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VendorDetailScreen(
                                vendor: vendor,
                                stockDetails: stockDetails,
                                comments: comments,
                                isDarkMode: isDarkMode,
                                onVendorUpdate: fetchVendors, // Pass callback
                              ),
                            ),
                          );
                        },
                        tooltip: loc.edit,
                      ),
                      IconButton(
                        icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: isDarkMode
                                ? darkModeIconColor
                                : lightModeCardIconColor),
                        onPressed: () {
                          setState(() {
                            expandedVendorId = isExpanded ? null : vendor['id'];
                          });
                        },
                        tooltip: isExpanded ? loc.collapse : loc.expand,
                      ),
                    ],
                  ),
                  onTap: () => setState(
                          () => expandedVendorId = isExpanded ? null : vendor['id']),
                ),
                if (isExpanded) ...[
                  // Directly show stock details and comments in web view
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            labelText: loc.searchByDate,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            setState(() {
                              searchQuery = val;
                            });
                          },
                          style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor),
                        ),
                        const SizedBox(height: 10),
                        ..._buildGroupedStockTables(stockDetails, isDarkMode, darkModeTextColor, lightModeCardTextColor),
                        const SizedBox(height: 10),
                        // Add Comment Section for Web View (inline)
                        _AddCommentSection(
                          vendorId: vendor['id'],
                          isDarkMode: isDarkMode,
                          onCommentSaved: fetchVendors, // Callback to refresh
                        ),
                        const SizedBox(height: 10),
                        Text(loc.comments,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? darkModeTextColor : lightModeCardTextColor)),
                        if (comments.isNotEmpty)
                          ...comments.map<Widget>((c) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '₹${c['amountPaid']} ${loc.paidBy} ${c['paidBy']} ${loc.on} ${c['date']}',
                              style: TextStyle(
                                  color: isDarkMode ? darkModeTextColor : lightModeCardTextColor),
                            ),
                          ))
                        else
                          Text(loc.noCommentsYet,
                              style: TextStyle(
                                  color: isDarkMode ? darkModeTextColor : lightModeCardTextColor)),
                      ],
                    ),
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildGroupedStockTables(List<Map<String, dynamic>> stockDetails, bool isDarkMode, Color darkModeTextColor, Color lightModeCardTextColor) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var stock in stockDetails) {
      if (stock['invoiceDate'] is Timestamp) {
        final formattedDate = dateFormat.format(stock['invoiceDate'].toDate());
        grouped.putIfAbsent(formattedDate, () => []);
        grouped[formattedDate]!.add(stock);
      }
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => dateFormat.parse(b.key).compareTo(dateFormat.parse(a.key)));

    final loc = AppLocalizations.of(context)!;

    return sortedEntries.map((entry) {
      return ExpansionTile(
        title: Text('${loc.dateLabel}: ${entry.key}',
            style: TextStyle(
                color: isDarkMode ? darkModeTextColor : lightModeCardTextColor)),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(loc.stockName, style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                  DataColumn(label: Text(loc.quantity1, style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                  DataColumn(label: Text(loc.price, style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                ],
                rows: entry.value.map<DataRow>((stock) {
                  return DataRow(cells: [
                    DataCell(Text(stock['ingredientName'] ?? '', style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                    DataCell(Text(stock['quantityAdded']?.toString() ?? '', style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                    DataCell(Text(stock['price']?.toString() ?? '', style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                  ]);
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${loc.total}: ₹${entry.value.fold<double>(0.0, (sum, stock) => sum + (double.tryParse(stock['price']?.toString() ?? '0') ?? 0)).toStringAsFixed(2)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? darkModeTextColor : lightModeCardTextColor),
              ),
            ),
          ),
        ],
      );
    }).toList();
  }
}

class _VendorActionItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  _VendorActionItem(this.title, this.icon, this.onTap);
}

class VendorSearchDelegate extends SearchDelegate<String?> {
  final AppLocalizations loc;
  VendorSearchDelegate(this.loc);

  @override
  String get searchFieldLabel => loc.searchVendors;

  @override
  List<Widget>? buildActions(BuildContext context) =>
      [IconButton(icon: Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
      icon: Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) {
    final branchCode =
    Provider.of<UserProvider>(context, listen: false).userData?['branchCode'];
    if (branchCode == null) return Center(child: Text(loc.branchMissing));

    final vendorRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Vendors');

    return FutureBuilder<QuerySnapshot>(
      future: vendorRef
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '$query\uf8ff')
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (snap.data?.docs.isEmpty ?? true)
          return Center(child: Text(loc.noResults));

        return ListView(
          children: snap.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['name'] ?? ''),
              onTap: () => close(context, doc.id),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final branchCode =
    Provider.of<UserProvider>(context, listen: false).userData?['branchCode'];
    if (branchCode == null) return Center(child: Text(loc.branchMissing));
    if (query.isEmpty) return Center(child: Text(loc.startTyping));

    final vendorRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Vendors');

    return FutureBuilder<QuerySnapshot>(
      future: vendorRef
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '$query\uf8ff')
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (snap.data?.docs.isEmpty ?? true)
          return Center(child: Text(loc.noMatchingVendors));

        return ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: snap.data!.docs.length,
          itemBuilder: (c, i) {
            final doc = snap.data!.docs[i];
            final vendor = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
            return Card(
              elevation: 3,
              margin: EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(vendor['name'] ?? '',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Icon(Icons.arrow_forward_ios, size: 18),
                      onTap: () => close(context, vendor['id']),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// New widget for adding comments
class _AddCommentSection extends StatefulWidget {
  final String vendorId;
  final bool isDarkMode;
  final VoidCallback onCommentSaved; // Callback to refresh parent data

  const _AddCommentSection({
    Key? key,
    required this.vendorId,
    required this.isDarkMode,
    required this.onCommentSaved,
  }) : super(key: key);

  @override
  __AddCommentSectionState createState() => __AddCommentSectionState();
}

class __AddCommentSectionState extends State<_AddCommentSection> {
  final dateFormat = DateFormat('dd-MM-yyyy');

  late TextEditingController _amountPaidController;
  late TextEditingController _paidByController;
  late TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _amountPaidController = TextEditingController();
    _paidByController = TextEditingController();
    _dateController = TextEditingController();
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    _paidByController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      helpText: AppLocalizations.of(context)!.selectDate,
      cancelText: AppLocalizations.of(context)!.cancel,
      confirmText: AppLocalizations.of(context)!.confirm,
    );

    if (selectedDate != null) {
      setState(() {
        _dateController.text = dateFormat.format(selectedDate);
      });
    }
  }

  Future<void> saveComment() async {
    final loc = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchCode = userProvider.userData?['branchCode'];

    if (branchCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.branchMissing)),
      );
      return;
    }

    final commentData = {
      'amountPaid': _amountPaidController.text,
      'paidBy': _paidByController.text,
      'date': _dateController.text,
    };

    if (commentData['amountPaid']!.isEmpty ||
        commentData['paidBy']!.isEmpty ||
        commentData['date']!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.fillAllFields)), // You might need to add this key
      );
      return;
    }

    final vendorRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Vendors')
        .doc(widget.vendorId);

    await vendorRef.update({
      'comments': FieldValue.arrayUnion([commentData])
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.vendorDetailsUpdated)),
    );

    setState(() {
      _amountPaidController.clear();
      _paidByController.clear();
      _dateController.clear();
    });
    widget.onCommentSaved(); // Notify parent to refresh
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final Color darkModeTextColor = Colors.white70;
    final Color lightModeCardTextColor = Colors.black87;
    final Color darkModeIconColor = Color(0xFF9AC0C6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.addComment,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode ? darkModeTextColor : lightModeCardTextColor)),
        TextField(
          decoration: InputDecoration(
            labelText: loc.amountPaid,
            labelStyle: TextStyle(color: widget.isDarkMode ? darkModeTextColor : lightModeCardTextColor),
          ),
          keyboardType: TextInputType.number,
          controller: _amountPaidController,
          style: TextStyle(color: widget.isDarkMode ? darkModeTextColor : lightModeCardTextColor),
        ),
        TextField(
          decoration: InputDecoration(
            labelText: loc.paidBy,
            labelStyle: TextStyle(color: widget.isDarkMode ? darkModeTextColor : lightModeCardTextColor),
          ),
          controller: _paidByController,
          style: TextStyle(color: widget.isDarkMode ? darkModeTextColor : lightModeCardTextColor),
        ),
        TextField(
          decoration: InputDecoration(
            labelText: loc.date,
            hintText: loc.selectDate,
            labelStyle: TextStyle(color: widget.isDarkMode ? darkModeTextColor : lightModeCardTextColor),
          ),
          controller: _dateController,
          readOnly: true,
          onTap: () => _selectDate(context),
          style: TextStyle(color: widget.isDarkMode ? darkModeTextColor : lightModeCardTextColor),
        ),
        ElevatedButton.icon(
          icon: Icon(Icons.save),
          label: Text(loc.save),
          onPressed: saveComment,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isDarkMode ? darkModeIconColor : Theme.of(context).primaryColor,
            foregroundColor: widget.isDarkMode ? Colors.black : Colors.white,
          ),
        ),
      ],
    );
  }
}

// New screen for displaying full vendor details
class VendorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> vendor;
  final List<Map<String, dynamic>> stockDetails;
  final List<Map<String, dynamic>> comments;
  final bool isDarkMode;
  final VoidCallback onVendorUpdate; // Callback to refresh vendor list

  VendorDetailScreen({
    Key? key,
    required this.vendor,
    required this.stockDetails,
    required this.comments,
    required this.isDarkMode,
    required this.onVendorUpdate,
  }) : super(key: key);

  @override
  _VendorDetailScreenState createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen> {
  final dateFormat = DateFormat('dd-MM-yyyy');
  late List<Map<String, dynamic>> _currentComments; // Mutable list for comments

  @override
  void initState() {
    super.initState();
    _currentComments = List.from(widget.comments); // Initialize with passed comments
    _sortComments(); // Sort initially
  }

  void _sortComments() {
    _currentComments.sort((a, b) {
      DateTime dateA;
      DateTime dateB;
      try {
        dateA = dateFormat.parse(a['date'] ?? '01-01-1900');
      } catch (e) {
        dateA = DateTime(1900, 1, 1); // Default to a very old date on parse error
      }
      try {
        dateB = dateFormat.parse(b['date'] ?? '01-01-1900');
      } catch (e) {
        dateB = DateTime(1900, 1, 1); // Default to a very old date on parse error
      }
      return dateB.compareTo(dateA); // Descending order (latest first)
    });
  }

  void _refreshComments() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchCode = userProvider.userData?['branchCode'];

    if (branchCode == null) return;

    final vendorDoc = await FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Vendors')
        .doc(widget.vendor['id'])
        .get();

    setState(() {
      _currentComments = List<Map<String, dynamic>>.from(vendorDoc.data()?['comments'] ?? []);
      _sortComments(); // Re-sort after fetching
    });
    widget.onVendorUpdate(); // Also refresh the main vendor list
  }


  List<Widget> _buildGroupedStockTables(List<Map<String, dynamic>> stockDetails, AppLocalizations loc, bool isDarkMode, Color darkModeTextColor, Color lightModeCardTextColor) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var stock in stockDetails) {
      if (stock['invoiceDate'] is Timestamp) {
        final formattedDate = dateFormat.format(stock['invoiceDate'].toDate());
        grouped.putIfAbsent(formattedDate, () => []);
        grouped[formattedDate]!.add(stock);
      }
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => dateFormat.parse(b.key).compareTo(dateFormat.parse(a.key)));

    return sortedEntries.map((entry) {
      return ExpansionTile(
        title: Text('${loc.dateLabel}: ${entry.key}',
            style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor)),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(loc.stockName, style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                  DataColumn(label: Text(loc.quantity1, style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                  DataColumn(label: Text(loc.price, style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                ],
                rows: entry.value.map<DataRow>((stock) {
                  return DataRow(cells: [
                    DataCell(Text(stock['ingredientName'] ?? '', style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                    DataCell(Text(stock['quantityAdded']?.toString() ?? '', style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                    DataCell(Text(stock['price']?.toString() ?? '', style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                  ]);
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${loc.total}: ₹${entry.value.fold<double>(0.0, (sum, stock) => sum + (double.tryParse(stock['price']?.toString() ?? '0') ?? 0)).toStringAsFixed(2)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? darkModeTextColor : lightModeCardTextColor),
              ),
            ),
          ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // Re-use theme colors for consistency
    final Color darkModeTextColor = Colors.white70;
    final Color lightModeCardTextColor = Colors.black87;
    final Color darkModeIconColor = Color(0xFF9AC0C6);
    final Color lightModeCardIconColor = Colors.black87;
    final Color darkModeCardColor = Colors.grey[800]!;
    final Color lightModeCardSolidColor = const Color(0xFFCBEEEE);

    final total = widget.stockDetails.fold<double>(
      0.0,
          (sum, item) =>
      sum + (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0),
    );
    final totalPaid = _currentComments.fold<double>( // Use _currentComments here
      0.0,
          (sum, c) =>
      sum + (double.tryParse(c['amountPaid']?.toString() ?? '0') ?? 0.0),
    );
    final pending = total - totalPaid;

    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        title: Text(widget.vendor['name'] ?? loc.vendorDetails,
            style: const TextStyle(color: Colors.black87)), // Consistent with main app bar
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: widget.isDarkMode
            ? Container(
          color: Colors.grey[850],
        )
            : Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE0FFFF), // appBarGradientStart
                Color(0xFFBFEBFA), // appBarGradientMid
                Color(0xFF87CEEB), // appBarGradientEnd
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              color: widget.isDarkMode ? darkModeCardColor : lightModeCardSolidColor,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.person,
                          size: 40,
                          color: widget.isDarkMode ? darkModeIconColor : lightModeCardIconColor),
                      title: Text(
                        widget.vendor['name'] ?? '',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode ? darkModeTextColor : lightModeCardTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${loc.total}: ₹${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: widget.isDarkMode ? darkModeTextColor : lightModeCardTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${loc.paid}: ₹${totalPaid.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: widget.isDarkMode ? darkModeTextColor : lightModeCardTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${loc.pending}: ₹${pending.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: widget.isDarkMode ? darkModeTextColor : lightModeCardTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              loc.stockDetails,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.stockDetails.isEmpty)
              Center(
                child: Text(loc.noStockDetailsFound,
                    style: TextStyle(
                        color: widget.isDarkMode ? darkModeTextColor : lightModeCardTextColor)),
              )
            else
              ..._buildGroupedStockTables(widget.stockDetails, loc, widget.isDarkMode, darkModeTextColor, lightModeCardTextColor),
            const SizedBox(height: 24),
            Text(
              loc.addComment, // Add comment section title
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            // Add Comment Section
            _AddCommentSection(
              vendorId: widget.vendor['id'],
              isDarkMode: widget.isDarkMode,
              onCommentSaved: _refreshComments, // Refresh comments in this screen
            ),
            const SizedBox(height: 24),
            Text(
              loc.comments,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            if (_currentComments.isEmpty) // Use _currentComments here
              Center(
                child: Text(loc.noCommentsYet,
                    style: TextStyle(
                        color: widget.isDarkMode ? darkModeTextColor : lightModeCardTextColor)),
              )
            else
              ..._currentComments.map<Widget>((c) => Card( // Use _currentComments here
                elevation: 2,
                margin: EdgeInsets.only(bottom: 10),
                color: widget.isDarkMode ? Colors.grey[700] : Colors.grey[200],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notes,
                              size: 18,
                              color: widget.isDarkMode ? darkModeIconColor : Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            '${loc.amountPaid}: ₹${c['amountPaid']}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: widget.isDarkMode
                                    ? darkModeTextColor
                                    : lightModeCardTextColor),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        '${loc.paidBy}: ${c['paidBy']}',
                        style: TextStyle(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: widget.isDarkMode
                                ? darkModeTextColor
                                : lightModeCardTextColor),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${loc.date}: ${c['date']}',
                        style: TextStyle(
                            fontSize: 15,
                            color: widget.isDarkMode
                                ? darkModeTextColor
                                : lightModeCardTextColor),
                      ),
                    ],
                  ),
                ),
              )).toList(),
          ],
        ),
      ),
    );
  }
}