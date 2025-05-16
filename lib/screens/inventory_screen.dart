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

  @override
  void initState() {
    super.initState();
    // Firestore fetch does not depend on localization
    fetchInventory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No localization here either; all loc calls happen in build() or delegates
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
    final file = File('${dir.path}/inventory_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
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

    return Animate(
      effects: [FadeEffect(duration: 500.ms), MoveEffect(begin: Offset(0, 40))],
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF4CB050),
          title: Text(loc.inventoryTitle, style: TextStyle(color: Colors.white)),
          iconTheme: IconThemeData(color: Colors.white),
          actions: [
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
        ),
        floatingActionButton: SpeedDial(
          animatedIcon: AnimatedIcons.menu_close,
          backgroundColor: Color(0xFF4CB050),
          children: [
            SpeedDialChild(
              child: Icon(Icons.add),
              label: loc.addInventory,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddInventoryScreen())),
            ),
            SpeedDialChild(
              child: Icon(Icons.inventory),
              label: loc.addStock,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddStockScreen())),
            ),
            SpeedDialChild(
              child: Icon(Icons.download),
              label: loc.exportToPdf,
              onTap: exportToPDF,
            ),
          ],
        ),
        body: loading
            ? Center(child: CircularProgressIndicator())
            : inventoryItems.isEmpty
            ? Center(child: Text(loc.noInventoryFound))
            : ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: inventoryItems.length,
          itemBuilder: (context, i) {
            final item = inventoryItems[i];
            final isSelected = selectedItemId == item['id'];
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
                      subtitle: Text(
                          '${loc.category}: ${item['category'] ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditInventoryScreen(
                                    documentId: item['id'], data: item),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () => deleteItem(item['id']),
                          ),
                        ],
                      ),
                      onTap: () =>
                          setState(() => selectedItemId = isSelected ? null : item['id']),
                    ),
                    Text('${loc.lastUpdated}: ${formatDate(item['lastUpdated'])}'),
                    Text('${loc.quantity1}: ${item['quantity']} ${item['unit']}'),
                    if (isSelected && inventoryHistory[item['id']] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Divider(),
                            Text(loc.historyTitle,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                            ...inventoryHistory[item['id']]!
                                .map((h) {
                              final updatedAt =
                              (h['updatedAt'] as Timestamp)
                                  .toDate();
                              return Card(
                                elevation: 2,
                                margin:
                                EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding:
                                  const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.history,
                                              color: Colors.blue,
                                              size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            DateFormat(
                                                'dd/MM/yyyy hh:mm a')
                                                .format(updatedAt),
                                            style: TextStyle(
                                                fontWeight:
                                                FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '${loc.actionLabel}: ${h['action']}',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontStyle: FontStyle
                                                .italic),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '${loc.quantityAddedLabel}: ${h['quantityAdded']} @ ₹${h['price']} — ${loc.currentQuantityLabel}: ${h['updatedQuantity']}',
                                        style:
                                        TextStyle(fontSize: 14),
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
        ),
      ),
    );
  }
}

class InventorySearchDelegate extends SearchDelegate<String?> {
  final AppLocalizations loc;
  InventorySearchDelegate(this.loc);

  @override
  String get searchFieldLabel => loc.searchInventory;

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: Icon(Icons.clear), onPressed: () => query = '')
  ];

  @override
  Widget? buildLeading(BuildContext context) =>
      IconButton(icon: Icon(Icons.arrow_back), onPressed: () => close(context, null));

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
        if (snap.data?.docs.isEmpty ?? true) return Center(child: Text(loc.noResults));

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
