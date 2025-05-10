import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore import
import 'package:flutter/services.dart'; // For CSV export
import '../../providers/user_provider.dart'; // Assuming your user provider
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:io';  // This is needed for File operations
import 'package:intl/intl.dart'; // For DateFormat
import 'package:art/screens/AddInventoryScreen.dart';
import 'package:art/screens/EditInventoryScreen.dart';
import 'package:art/screens/AddStockScreen.dart';
class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool loading = true;
  List<Map<String, dynamic>> inventoryItems = [];
  Map<String, List<Map<String, dynamic>>> inventoryHistory = {};
  String? selectedItemId;
  String searchQuery = '';
  int currentPage = 1;
  int itemsPerPage = 10;

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

      // Fetch history for each item
      for (final item in items) {
        final historyRef = inventoryRef.doc(item['id']).collection('History');
        final historySnap = await historyRef.get();
        final historyList = historySnap.docs
            .map((h) => h.data())
            .toList()
          ..sort((a, b) =>
              (b['updatedAt'] as Timestamp).compareTo(a['updatedAt'] as Timestamp));

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
    final branchCode = userData?['branchCode']; // Safely access branchCode

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
      return timestamp.toDate().toLocal().toString();
    }
    return '';
  }

  Future<void> exportToCSV(List<Map<String, dynamic>> inventoryItems, BuildContext context) async {
    List<List<String>> rows = [];
    rows.add(["Ingredient Name", "Category", "Quantity", "Unit", "Last Updated"]);

    for (var item in inventoryItems) {
      rows.add([
        item['ingredientName'] ?? '',
        item['category'] ?? '',
        item['quantity'].toString(),
        item['unit'] ?? '',
        formatDate(item['lastUpdated']),
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/inventory_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV exported to ${file.path}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [FadeEffect(duration: 500.ms), MoveEffect(begin: Offset(0, 40))],
      child: Scaffold(
        appBar: AppBar(
          title: Text('Inventory'),
          actions: [
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () async {
                showSearch(context: context, delegate: InventorySearchDelegate());
              },
            ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
            onPressed: () {
      Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddInventoryScreen()),
      );
      },
              label: Text('Add Inventory'),
              icon: Icon(Icons.add),
              heroTag: 'addInventory',
            ),
            SizedBox(height: 12),
            FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddStockScreen()),
                );
              },
              label: Text('Add Stock'),
              icon: Icon(Icons.inventory),
              heroTag: 'addStock',
            ),
            SizedBox(height: 12),
            FloatingActionButton.extended(
              onPressed: () => exportToCSV(inventoryItems, context),
              label: Text('Export to CSV'),
              icon: Icon(Icons.download),
              heroTag: 'exportCSV',
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

class InventorySearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(future: _fetchSearchResults(query, context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final searchResults = snapshot.data ?? [];
        if (searchResults.isEmpty) {
          return Center(child: Text('No results found.'));
        }
        return ListView.builder(
          itemCount: searchResults.length,
          itemBuilder: (context, index) {
            final item = searchResults[index];
            return ListTile(
              title: Text(item['ingredientName'] ?? ''),
              subtitle: Text(item['category'] ?? ''),
              onTap: () {
                close(context, item['ingredientName']);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container();
  }

  Future<List<Map<String, dynamic>>> _fetchSearchResults(String query, BuildContext context) async {
    final userData = Provider.of<UserProvider>(context, listen: false).userData;
    if (userData == null || userData['branchCode'] == null) return [];
    final branchCode = userData['branchCode'];
    final inventoryRef = FirebaseFirestore.instance.collection('tables').doc(branchCode).collection('Inventory');
    final snapshot = await inventoryRef
        .where('ingredientName', isGreaterThanOrEqualTo: query)
        .where('ingredientName', isLessThan: query + 'z')
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }
}
