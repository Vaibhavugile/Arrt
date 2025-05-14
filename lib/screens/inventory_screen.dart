import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../providers/user_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:art/screens/AddInventoryScreen.dart';
import 'package:art/screens/EditInventoryScreen.dart';
import 'package:art/screens/AddStockScreen.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

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
        return {'id': doc.id, ...doc.data()};
      }).toList();

      setState(() {
        inventoryItems = items;
      });

      for (final item in items) {
        final historyRef = inventoryRef.doc(item['id']).collection('History');
        final historySnap = await historyRef.get();
        final historyList = historySnap.docs
            .map((h) => h.data())
            .toList()
          ..sort((a, b) => (b['updatedAt'] as Timestamp).compareTo(a['updatedAt'] as Timestamp));

        setState(() {
          inventoryHistory[item['id']] = List<Map<String, dynamic>>.from(historyList);
        });
      }
    } catch (e) {
      print('Error fetching inventory: $e');
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  void deleteItem(String id) async {
    final userData = Provider.of<UserProvider>(context, listen: false).userData;
    final branchCode = userData?['branchCode'];
    try {
      await FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('Inventory')
          .doc(id)
          .delete();

      setState(() {
        inventoryItems.removeWhere((item) => item['id'] == id);
      });
    } catch (e) {
      print('Delete failed: $e');
    }
  }

  String formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('dd/MM/yyyy hh:mm a').format(timestamp.toDate());
    }
    return '';
  }

  Future<void> exportToPDF(List<Map<String, dynamic>> inventoryItems, BuildContext context) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Inventory Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ['Ingredient Name', 'Category', 'Quantity', 'Unit', 'Last Updated'],
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
          );
        },
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final file = File('${outputDir.path}/inventory_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open PDF: ${result.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [FadeEffect(duration: 500.ms), MoveEffect(begin: Offset(0, 40))],
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF4CB050),
          title: Text('Inventory', style: TextStyle(color: Colors.white)),
          iconTheme: IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () async {
                final result = await showSearch(
                  context: context,
                  delegate: InventorySearchDelegate(),
                );
                if (result != null) {
                  final item = inventoryItems.firstWhere((item) => item['id'] == result, orElse: () => {});
                  if (item.isNotEmpty) {
                    setState(() {
                      selectedItemId = item['id'];
                    });
                  }
                }
              },
            ),
          ],
        ),
        floatingActionButton: SpeedDial(
          animatedIcon: AnimatedIcons.menu_close,
          backgroundColor: Color(0xFF4CB050),
          foregroundColor: Colors.white,
          overlayColor: Colors.black,
          overlayOpacity: 0.5,
          spacing: 14,
          spaceBetweenChildren: 8,
          heroTag: 'mainSpeedDial',
          children: [
            SpeedDialChild(
              child: Icon(Icons.add),
              label: 'Add Inventory',
              backgroundColor: Colors.deepPurple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddInventoryScreen()),
                );
              },
            ),
            SpeedDialChild(
              child: Icon(Icons.inventory),
              label: 'Add Stock',
              backgroundColor: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddStockScreen()),
                );
              },
            ),
            SpeedDialChild(
              child: Icon(Icons.download),
              label: 'Export to PDF',
              backgroundColor: Colors.indigo,
              onTap: () => exportToPDF(inventoryItems, context),
            ),
          ],
        ),
        body: loading
            ? Center(child: CircularProgressIndicator())
            : inventoryItems.isEmpty
            ? Center(child: Text('No inventory items found.'))
            : ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: inventoryItems.length,
          itemBuilder: (context, index) {
            final item = inventoryItems[index];
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
                      title: Text(item['ingredientName'] ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Category: ${item['category'] ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditInventoryScreen(
                                  documentId: item['id'],
                                  data: item,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () => deleteItem(item['id']),
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          selectedItemId = isSelected ? null : item['id'];
                        });
                      },
                    ),
                    Text('Last Updated: ${formatDate(item['lastUpdated'])}'),
                    Text('Quantity: ${item['quantity']} ${item['unit']}'),
                    if (isSelected && inventoryHistory[item['id']] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(),
                            Text('History:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ...inventoryHistory[item['id']]!.map((history) {
                              final updatedAt = (history['updatedAt'] as Timestamp).toDate();
                              return Card(
                                elevation: 2,
                                margin: EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.history, color: Colors.blue, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            '${updatedAt.day}/${updatedAt.month}/${updatedAt.year} ${updatedAt.hour}:${updatedAt.minute}',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Action: ${history['action']}',
                                        style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Quantity Added: ${history['quantityAdded']} @ ₹${history['price']} - Current Qty: ${history['updatedQuantity']}',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList()
                          ],
                        ),
                      ),
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
  @override
  String get searchFieldLabel => 'Search inventory...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [IconButton(icon: Icon(Icons.clear), onPressed: () => query = '')];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) {
    final userData = Provider.of<UserProvider>(context, listen: false).userData;
    final branchCode = userData?['branchCode'];
    if (branchCode == null) return Center(child: Text('Branch code missing'));

    final inventoryRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Inventory');

    return FutureBuilder<QuerySnapshot>(
      future: inventoryRef
          .where('ingredientName', isGreaterThanOrEqualTo: query)
          .where('ingredientName', isLessThan: query + 'z')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return Center(child: Text('No results found.'));

        final results = snapshot.data!.docs;

        return ListView(
          children: results.map((doc) {
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
    final userData = Provider.of<UserProvider>(context, listen: false).userData;
    final branchCode = userData?['branchCode'];
    if (branchCode == null) return Center(child: Text('Branch code missing'));

    if (query.isEmpty) {
      return Center(child: Text('Start typing to search inventory...'));
    }

    final inventoryRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Inventory');

    return FutureBuilder<QuerySnapshot>(
      future: inventoryRef
          .where('ingredientName', isGreaterThanOrEqualTo: query)
          .where('ingredientName', isLessThan: query + 'z')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No matching inventory found.'));
        }

        final results = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final doc = results[index];
            final item = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
            final lastUpdated = (item['lastUpdated'] as Timestamp?)?.toDate();
            final lastUpdatedStr = lastUpdated != null
                ? '${lastUpdated.day}/${lastUpdated.month}/${lastUpdated.year} ${lastUpdated.hour}:${lastUpdated.minute}'
                : 'N/A';

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
                      title: Text(item['ingredientName'] ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Category: ${item['category'] ?? ''}'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 18),
                      onTap: () {
                        close(context, item['ingredientName']);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditInventoryScreen(
                              documentId: item['id'],
                              data: item,
                            ),
                          ),
                        );
                      },
                    ),
                    Text('Last Updated: $lastUpdatedStr'),
                    Text('Quantity: ${item['quantity']} ${item['unit']}'),
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
