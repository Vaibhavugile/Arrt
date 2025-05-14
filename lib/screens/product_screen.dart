import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:async';
import 'package:art/screens/AddProductScreen.dart';
import 'package:art/screens/EditProductScreen.dart';
import'package:art/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'dart:io';  // This is needed for File operations
import 'package:path_provider/path_provider.dart';
class ProductScreen extends StatefulWidget {
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  List<Map<String, dynamic>> allProducts = [];
  List<Map<String, dynamic>> filteredProducts = [];
  late String branchCode;
  String searchQuery = '';
  String selectedSubcategory = 'All';
  List<String> subcategories = ['All'];
  int itemsPerPage = 10;
  int currentPage = 1;

  StreamSubscription? _productSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      setState(() {
        branchCode = userProvider.branchCode!;
      });

      listenToProducts();
    });
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

  void exportToPDF(BuildContext context, List<Map<String, dynamic>> filteredProducts) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Product Export', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ['Name', 'Price', 'Subcategory'],
                data: filteredProducts.map((p) => [
                  p['name']?.toString() ?? '',
                  p['price']?.toString() ?? '',
                  p['subcategory']?.toString() ?? ''
                ]).toList(),
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
    final file = File('${outputDir.path}/product_export_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open PDF: ${result.message}')),
      );
    }
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
        title: Text('Products', style: TextStyle(color: Colors.white),),
        backgroundColor: Color(0xFF4CB050),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: Icon(Icons.file_upload), onPressed: importCSV),
          IconButton(icon: Icon(Icons.file_download), onPressed: () => exportToPDF(context, filteredProducts),),
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
                                      branchCode: branchCode// Assuming `p['id']` is the ID of the product you want to edit
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
