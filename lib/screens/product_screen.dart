import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:async';
import 'package:art/screens/AddProductScreen.dart';
import 'package:art/screens/EditProductScreen.dart';

class ProductScreen extends StatefulWidget {
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final String branchCode = '3333';
  List<Map<String, dynamic>> allProducts = [];
  List<Map<String, dynamic>> filteredProducts = [];
  String searchQuery = '';
  String selectedSubcategory = 'All';
  List<String> subcategories = ['All'];
  int itemsPerPage = 10;
  int currentPage = 1;

  StreamSubscription? _productSubscription;

  @override
  void initState() {
    super.initState();
    listenToProducts();
  }

  @override
  void dispose() {
    _productSubscription?.cancel();
    super.dispose();
  }

  void listenToProducts() {
    _productSubscription = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('products')
        .snapshots()
        .listen((snapshot) {
      final fetched = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

      final uniqueSubcategories = {
        'All',
        ...fetched.map((p) => p['subcategory'].toString()).toSet()
      };

      setState(() {
        allProducts = fetched;
        subcategories = uniqueSubcategories.toList();
        applyFilters();
      });
    });
  }

  void applyFilters() {
    List<Map<String, dynamic>> result = allProducts;

    if (selectedSubcategory != 'All') {
      result = result
          .where((p) => p['subcategory'] == selectedSubcategory)
          .toList();
    }

    if (searchQuery.isNotEmpty) {
      result = result
          .where((p) => p['name']
          .toString()
          .toLowerCase()
          .contains(searchQuery.toLowerCase()))
          .toList();
    }

    setState(() {
      filteredProducts = result.take(currentPage * itemsPerPage).toList();
    });
  }

  void deleteProduct(String id) async {
    await FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('products')
        .doc(id)
        .delete();
    // No need to manually refresh — listener handles it
  }

  void importCSV() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv']);
    if (result == null) return;

    final file = result.files.first;
    final content = utf8.decode(file.bytes!);
    final csvData = CsvToListConverter().convert(content);
    final headers = csvData.first.cast<String>();
    final rows = csvData.skip(1);

    try {
      for (var row in rows) {
        final product = Map.fromIterables(headers, row);
        product['price'] = double.tryParse(product['price'].toString()) ?? 0;
        await FirebaseFirestore.instance
            .collection('tables')
            .doc(branchCode)
            .collection('products')
            .add(product);
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('CSV Imported Successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to import CSV')));
    }
  }

  void exportCSV() {
    final headers = ['name', 'price', 'subcategory'];
    final rows = [headers];
    for (var p in filteredProducts) {
      rows.add([p['name'], p['price'], p['subcategory']]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    debugPrint(csv);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('CSV Exported (check console)')));
  }

  void loadMore() {
    setState(() {
      currentPage++;
      applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Products'),
        actions: [
          IconButton(icon: Icon(Icons.file_upload), onPressed: importCSV),
          IconButton(icon: Icon(Icons.file_download), onPressed: exportCSV),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddProductScreen()),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Add Product',
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        applyFilters();
                      });
                    },
                  ),
                ),
                SizedBox(width: 12),
                DropdownButton<String>(
                  value: selectedSubcategory,
                  items: subcategories.map((subcategory) {
                    return DropdownMenuItem(
                      value: subcategory,
                      child: Text(subcategory),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSubcategory = value!;
                      applyFilters();
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 12),
            Expanded(
              child: filteredProducts.isEmpty
                  ? Center(child: Text('No products found'))
                  : ListView.builder(
                itemCount: filteredProducts.length + 1,
                itemBuilder: (context, index) {
                  if (index == filteredProducts.length) {
                    return filteredProducts.length < allProducts.length
                        ? Center(
                      child: TextButton(
                        onPressed: loadMore,
                        child: Text('Load More'),
                      ),
                    )
                        : SizedBox.shrink();
                  }

                  final p = filteredProducts[index];
                  return Animate(
                    effects: [
                      FadeEffect(duration: 400.ms),
                      MoveEffect(begin: Offset(0, 20))
                    ],
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        title: Text(
                          p['name'],
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle:
                        Text('₹${p['price']} • ${p['subcategory']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.indigo),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProductScreen(
                                    productId: p['id'],
                                      branchCode: '3333'// Assuming `p['id']` is the ID of the product you want to edit
                                  ),
                                ),
                              ),
                            ),

                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteProduct(p['id']),
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
    );
  }
}
