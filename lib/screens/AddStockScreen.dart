import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import'package:art/providers/user_provider.dart';
import 'package:provider/provider.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  late String branchCode;
  List<DocumentSnapshot> vendors = [];
  List<String> categories = [];
  List<DocumentSnapshot> items = [];
  List<Map<String, dynamic>> stockEntries = [];

  String? selectedVendorId;
  String? selectedCategory;
  String? selectedItemId;
  int currentQuantity = 0;
  int quantityToAdd = 0;
  double price = 0.0;
  DateTime invoiceDate = DateTime.now();

  @override
  void initState() {

    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      setState(() {
        branchCode = userProvider.branchCode!;
      });

    fetchVendors();
    });
  }

  Future<void> fetchVendors() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Vendors')
        .get();
    setState(() {
      vendors = snapshot.docs;
    });
  }

  void loadCategories() {
    final vendor = vendors.firstWhereOrNull((v) => v.id == selectedVendorId);
    if (vendor != null) {
      final data = vendor.data() as Map<String, dynamic>;
      if (data.containsKey('categories')) {
        setState(() {
          categories = List<String>.from(data['categories']);
        });
      }
    }
  }

  Future<void> fetchItems() async {
    if (selectedCategory == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Inventory')
        .where('category', isEqualTo: selectedCategory)
        .get();
    setState(() {
      items = snapshot.docs;
    });
  }

  void updateCurrentQuantity() {
    final selectedItem = items.firstWhereOrNull((i) => i.id == selectedItemId);
    if (selectedItem != null) {
      final quantity = selectedItem['quantity'];
      setState(() {
        currentQuantity = quantity is int ? quantity : 0;
      });
      print('Selected Item Data: ${selectedItem.data()}');
    } else {
      setState(() {
        currentQuantity = 0;
      });
      print('Selected item not found.');
    }
  }

  void handleAddStockEntry() {
    final updatedQuantity = currentQuantity + quantityToAdd;
    stockEntries.add({
      'vendorId': selectedVendorId,
      'category': selectedCategory,
      'itemId': selectedItemId,
      'quantityToAdd': quantityToAdd,
      'price': price,
      'invoiceDate': invoiceDate,
      'updatedQuantity': updatedQuantity,
    });

    setState(() {
      selectedCategory = null;
      selectedItemId = null;
      quantityToAdd = 0;
      price = 0;
      currentQuantity = updatedQuantity;
    });
  }

  Future<void> handleSubmit() async {
    for (var entry in stockEntries) {
      final itemRef = FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('Inventory')
          .doc(entry['itemId']);

      final vendorRef = FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('Vendors')
          .doc(entry['vendorId']);

      final itemSnapshot = await itemRef.get();
      final ingredientName = itemSnapshot['ingredientName'];

      // Add to vendor stock
      await vendorRef.collection('Stock').add({
        'invoiceDate': entry['invoiceDate'],
        'category': entry['category'],
        'ingredientName': ingredientName,
        'quantityAdded': entry['quantityToAdd'],
        'price': entry['price'],
        'branchCode': branchCode,
        'updatedQuantity': entry['updatedQuantity'],
      });

      // Update inventory
      await itemRef.update({
        'quantity': entry['updatedQuantity'],
        'lastUpdated': entry['invoiceDate'],
      });

      // Add to history
      await itemRef.collection('History').add({
        'invoiceDate': entry['invoiceDate'],
        'quantityAdded': entry['quantityToAdd'],
        'price': entry['price'],
        'updatedQuantity': entry['updatedQuantity'],
        'action': 'Add Stock',
        'updatedAt': Timestamp.now(),
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stocks updated successfully!')),
    );

    setState(() {
      stockEntries.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF4CB050),
        title: Text(
          'Add Stock',
          style: TextStyle(color: Colors.white), // 👈 Makes text white
        ),
        iconTheme: IconThemeData(color: Colors.white), // optional: makes back icon white too
      ),       body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: selectedVendorId,
              decoration: const InputDecoration(labelText: 'Select Vendor'),
              items: vendors
                  .map((vendor) => DropdownMenuItem(
                value: vendor.id,
                child: Text(vendor['name']),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedVendorId = value;
                  selectedCategory = null;
                  categories = [];
                  items = [];
                });
                loadCategories();
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(labelText: 'Select Category'),
              items: categories
                  .map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                  selectedItemId = null;
                  items = [];
                });
                fetchItems();
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedItemId,
              decoration: const InputDecoration(labelText: 'Select Item'),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item.id,
                  child: Text(item['ingredientName']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedItemId = value;
                });
                print("Selected Item ID: $selectedItemId");
                updateCurrentQuantity();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: currentQuantity.toString(),
              decoration: const InputDecoration(labelText: 'Current Quantity'),
              readOnly: true,
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Quantity to Add'),
              keyboardType: TextInputType.number,
              onChanged: (val) => quantityToAdd = int.tryParse(val) ?? 0,
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              onChanged: (val) => price = double.tryParse(val) ?? 0.0,
            ),
            const SizedBox(height: 10),
            ListTile(
              title: Text(
                  "Invoice Date: ${DateFormat.yMMMd().format(invoiceDate)}"),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: invoiceDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => invoiceDate = picked);
                }
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: handleAddStockEntry,
              child: const Text('Add to List'),
            ),
            const SizedBox(height: 20),
            if (stockEntries.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stock Entries:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...stockEntries.map((entry) {
                    final item = items.firstWhereOrNull(
                            (item) => item.id == entry['itemId']);
                    return Card(
                      child: ListTile(
                        title: Text(item != null
                            ? item['ingredientName']
                            : 'Unknown'),
                        subtitle: Text(
                            'Qty: ${entry['quantityToAdd']} | Price: ${entry['price']} | Date: ${DateFormat.yMd().format(entry['invoiceDate'])}'),
                      ),
                    );
                  }).toList(),
                ],
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: stockEntries.isNotEmpty ? handleSubmit : null,
              child: const Text('Submit All Entries'),
            ),
          ],
        ),
      ),
    );
  }
}
