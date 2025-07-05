import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:art/providers/user_provider.dart';
import '../../screens/AddInventoryScreen.dart';
import '../../screens/EditInventoryScreen.dart';
import '../../screens/AddStockScreen.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool loading = true;
  List<Map<String, dynamic>> inventoryItems = [];
  Map<String, List<Map<String, dynamic>>> inventoryHistory = {};
  String? selectedItemId;
  bool isDarkMode = false; // Added for theme toggle
  int _selectedSidebarIndex = 0; // To track selected sidebar item

  // Define actions for sidebar/speed dial
  List<_InventoryActionItem> getInventoryActions(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return [
      _InventoryActionItem(loc.addInventory, Icons.add, () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => AddInventoryScreen()));
      }),
      _InventoryActionItem(loc.addStock, Icons.inventory, () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => AddStockScreen()));
      }),
      _InventoryActionItem(loc.exportToPdf, Icons.download, exportToPDF),
    ];
  }

  @override
  void initState() {
    super.initState();
    fetchInventory();
  }

  Future<void> fetchInventory() async {
    final userData = Provider.of<UserProvider>(context, listen: false).userData;
    if (userData == null || userData['branchCode'] == null) return;
    final branchCode = userData['branchCode'];
    final inventoryRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Inventory');

    try {
      final snapshot = await inventoryRef.get();
      final items = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
      setState(() => inventoryItems = items);

      for (final item in items) {
        final historySnap = await inventoryRef
            .doc(item['id'])
            .collection('History')
            .orderBy('updatedAt', descending: true)
            .get();
        setState(() => inventoryHistory[item['id']] =
            historySnap.docs.map((d) => d.data()).toList());
      }
    } catch (e) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.errorFetchingInventory)),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  void deleteItem(String id) async {
    final loc = AppLocalizations.of(context)!;
    final branchCode =
    Provider.of<UserProvider>(context, listen: false).userData?['branchCode'];
    try {
      await FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('Inventory')
          .doc(id)
          .delete();
      setState(() => inventoryItems.removeWhere((i) => i['id'] == id));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.itemDeleted)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.deleteFailed)));
    }
  }

  String formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('dd/MM/yyyy hh:mm a').format(timestamp.toDate());
    }
    return '';
  }

  Future<void> exportToPDF() async {
    final loc = AppLocalizations.of(context)!;
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(loc.inventoryReportTitle,
                style:
                pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: [
                loc.ingredientName,
                loc.category,
                loc.quantity1,
                loc.unit,
                loc.lastUpdated
              ],
              data: inventoryItems.map((item) {
                return [
                  item['ingredientName'] ?? '',
                  item['category'] ?? '',
                  item['quantity'].toString(),
                  item['unit'] ?? '',
                  formatDate(item['lastUpdated']),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
            )
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/inventory_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.failedToOpenPdf)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final inventoryActions = getInventoryActions(context);

    // Theme Colors (consistent with branch_dashboard for web styling)
    final Color appBarGradientStart = Color(0xFFE0FFFF); // Muted light blue
    final Color appBarGradientMid = Color(0xFFBFEBFA); // Steel Blue
    final Color appBarGradientEnd = Color(0xFF87CEEB); // Dark Indigo

    final Color lightModeCardSolidColor =
    Colors.grey[100]!; // Peach Puff (for small screen cards)
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
          title: Text(loc.inventoryTitle,
              style: const TextStyle(color: Colors.black87)),
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
                  delegate: InventorySearchDelegate(loc),
                );
                if (result != null) {
                  setState(() => selectedItemId = result);
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
                    label: loc.addInventory,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => AddInventoryScreen())),
                  ),
                  SpeedDialChild(
                    child: Icon(Icons.inventory),
                    label: loc.addStock,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => AddStockScreen())),
                  ),
                  SpeedDialChild(
                    child: Icon(Icons.download),
                    label: loc.exportToPdf,
                    onTap: exportToPDF,
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
                      color: isDarkMode ? darkModeCardColor : lightModeCardSolidColor,
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
                              Icon(Icons.category,
                                  color: isDarkMode
                                      ? webSidebarTitleColorDark
                                      : webSidebarTitleColorLight,
                                  size: 24),
                              SizedBox(width: 12),
                              Text(
                                loc.inventoryTitle,
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
                            itemCount: inventoryActions.length,
                            itemBuilder: (context, index) {
                              final item = inventoryActions[index];
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
                        : inventoryItems.isEmpty
                        ? Center(child: Text(loc.noInventoryFound))
                        : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: isLargeScreen
                          ? _buildInventoryList(loc, isDarkMode,
                          lightModeCardSolidColor, darkModeCardColor, darkModeIconColor, lightModeCardIconColor, darkModeTextColor, lightModeCardTextColor)
                          : GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: inventoryItems.map((item) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InventoryDetailScreen(
                                    item: item,
                                    inventoryHistory: inventoryHistory[item['id']] ?? [],
                                    isDarkMode: isDarkMode,
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
                                    Icons.category, // Using a generic icon for demonstration
                                    size: 40,
                                    color: isDarkMode
                                        ? darkModeIconColor
                                        : lightModeCardIconColor,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    item['ingredientName'] ?? '',
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
                                    '${item['quantity']} ${item['unit']}',
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

  Widget _buildInventoryList(
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
      itemCount: inventoryItems.length,
      itemBuilder: (context, i) {
        final item = inventoryItems[i];
        final isSelected = selectedItemId == item['id'];
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
                  title: Text(item['ingredientName'] ?? '',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? darkModeTextColor
                              : lightModeCardTextColor)),
                  subtitle: Text(
                      '${loc.category}: ${item['category'] ?? ''}',
                      style: TextStyle(
                          color: isDarkMode
                              ? darkModeTextColor
                              : lightModeCardTextColor)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit,
                            color: isDarkMode
                                ? darkModeIconColor
                                : lightModeCardIconColor),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditInventoryScreen(documentId: item['id'], data: item),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete,
                            color: isDarkMode
                                ? darkModeIconColor
                                : lightModeCardIconColor),
                        onPressed: () => deleteItem(item['id']),
                      ),
                    ],
                  ),
                  onTap: () => setState(
                          () => selectedItemId = isSelected ? null : item['id']),
                ),
                Text('${loc.lastUpdated}: ${formatDate(item['lastUpdated'])}',
                    style: TextStyle(
                        color: isDarkMode
                            ? darkModeTextColor
                            : lightModeCardTextColor)),
                Text('${loc.quantity1}: ${item['quantity']} ${item['unit']}',
                    style: TextStyle(
                        color: isDarkMode
                            ? darkModeTextColor
                            : lightModeCardTextColor)),
                if (isSelected && inventoryHistory[item['id']] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: isDarkMode ? Colors.white30 : Colors.grey[400]),
                        Text(loc.historyTitle,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? darkModeTextColor
                                    : lightModeCardTextColor)),
                        ...inventoryHistory[item['id']]!.map((h) {
                          final updatedAt = (h['updatedAt'] as Timestamp).toDate();
                          return Card(
                            elevation: 2,
                            margin: EdgeInsets.only(bottom: 8),
                            color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.history,
                                          color: isDarkMode ? darkModeIconColor : Colors.blue,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        DateFormat('dd/MM/yyyy hh:mm a')
                                            .format(updatedAt),
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode
                                                ? darkModeTextColor
                                                : lightModeCardTextColor),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${loc.actionLabel}: ${h['action']}',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                        color: isDarkMode
                                            ? darkModeTextColor
                                            : lightModeCardTextColor),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${loc.quantityAddedLabel}: ${h['quantityAdded']} @ ₹${h['price']} — ${loc.currentQuantityLabel}: ${h['updatedQuantity']}',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: isDarkMode
                                            ? darkModeTextColor
                                            : lightModeCardTextColor),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  )
              ],
            ),
          ),
        );
      },
    );
  }
}

class InventorySearchDelegate extends SearchDelegate<String?> {
  final AppLocalizations loc;
  InventorySearchDelegate(this.loc);

  @override
  String get searchFieldLabel => loc.searchInventory;

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

    final inventoryRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Inventory');

    return FutureBuilder<QuerySnapshot>(
      future: inventoryRef
          .where('ingredientName', isGreaterThanOrEqualTo: query)
          .where('ingredientName', isLessThan: '$query\uf8ff')
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
              title: Text(data['ingredientName'] ?? ''),
              subtitle: Text(data['category'] ?? ''),
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

    final inventoryRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Inventory');

    return FutureBuilder<QuerySnapshot>(
      future: inventoryRef
          .where('ingredientName', isGreaterThanOrEqualTo: query)
          .where('ingredientName', isLessThan: '$query\uf8ff')
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (snap.data?.docs.isEmpty ?? true)
          return Center(child: Text(loc.noMatchingInventory));

        return ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: snap.data!.docs.length,
          itemBuilder: (c, i) {
            final doc = snap.data!.docs[i];
            final item = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
            final updatedAt = (item['lastUpdated'] as Timestamp?)?.toDate();
            final lastUpdatedStr = updatedAt != null
                ? DateFormat('dd/MM/yyyy hh:mm a').format(updatedAt)
                : loc.notAvailable;
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
                      title: Text(item['ingredientName'] ?? '',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${loc.category}: ${item['category'] ?? ''}'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 18),
                      onTap: () => close(context, item['id']),
                    ),
                    Text('${loc.lastUpdated}: $lastUpdatedStr'),
                    Text('${loc.quantity1}: ${item['quantity']} ${item['unit']}'),
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

class _InventoryActionItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  _InventoryActionItem(this.title, this.icon, this.onTap);
}

// New screen for displaying full inventory item details
class InventoryDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> inventoryHistory;
  final bool isDarkMode;

  InventoryDetailScreen({
    required this.item,
    required this.inventoryHistory,
    required this.isDarkMode,
  });

  String formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('dd/MM/yyyy hh:mm a').format(timestamp.toDate());
    }
    return '';
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

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        title: Text(item['ingredientName'] ?? loc.itemDetails,
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: isDarkMode ? Colors.grey[850] : Color(0xFF87CEEB), // Consistent with InventoryScreen AppBar
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              color: isDarkMode ? darkModeCardColor : lightModeCardSolidColor,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.inventory_2,
                          size: 40,
                          color: isDarkMode ? darkModeIconColor : lightModeCardIconColor),
                      title: Text(
                        item['ingredientName'] ?? '',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? darkModeTextColor : lightModeCardTextColor,
                        ),
                      ),
                      subtitle: Text(
                        '${loc.category}: ${item['category'] ?? ''}',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? darkModeTextColor : lightModeCardTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${loc.quantity1}: ${item['quantity']} ${item['unit']}',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? darkModeTextColor : lightModeCardTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${loc.lastUpdated}: ${formatDate(item['lastUpdated'])}',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: isDarkMode ? darkModeTextColor : lightModeCardTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              loc.historyTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            if (inventoryHistory.isEmpty)
              Center(
                child: Text(loc.noHistoryFound,
                    style: TextStyle(
                        color: isDarkMode ? darkModeTextColor : lightModeCardTextColor)),
              )
            else
              ...inventoryHistory.map((h) {
                final updatedAt = (h['updatedAt'] as Timestamp).toDate();
                return Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 10),
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 18,
                                color: isDarkMode ? darkModeIconColor : Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              DateFormat('dd/MM/yyyy hh:mm a').format(updatedAt),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? darkModeTextColor
                                      : lightModeCardTextColor),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          '${loc.actionLabel}: ${h['action']}',
                          style: TextStyle(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              color: isDarkMode
                                  ? darkModeTextColor
                                  : lightModeCardTextColor),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${loc.quantityAddedLabel}: ${h['quantityAdded']} @ ₹${h['price']} — ${loc.currentQuantityLabel}: ${h['updatedQuantity']}',
                          style: TextStyle(
                              fontSize: 15,
                              color: isDarkMode
                                  ? darkModeTextColor
                                  : lightModeCardTextColor),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}