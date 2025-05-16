import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:art/providers/user_provider.dart';
import 'package:provider/provider.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({Key? key}) : super(key: key);

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
      branchCode =
      Provider.of<UserProvider>(context, listen: false).branchCode!;
      fetchVendors();
    });
  }

  Future<void> fetchVendors() async {
    final snap = await FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Vendors')
        .get();
    setState(() => vendors = snap.docs);
  }

  void loadCategories() {
    final v = vendors.firstWhereOrNull((v) => v.id == selectedVendorId);
    if (v != null) {
      final data = v.data() as Map<String, dynamic>;
      setState(() {
        categories = List<String>.from(data['categories'] ?? []);
      });
    }
  }

  Future<void> fetchItems() async {
    if (selectedCategory == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Inventory')
        .where('category', isEqualTo: selectedCategory)
        .get();
    setState(() => items = snap.docs);
  }

  void updateCurrentQuantity() {
    final doc =
    items.firstWhereOrNull((i) => i.id == selectedItemId);
    if (doc != null) {
      final qty = doc['quantity'];
      setState(() => currentQuantity = (qty is int ? qty : 0));
    } else {
      setState(() => currentQuantity = 0);
    }
  }

  void handleAddStockEntry() {
    final updated = currentQuantity + quantityToAdd;
    setState(() {
      stockEntries.add({
        'vendorId': selectedVendorId,
        'category': selectedCategory,
        'itemId': selectedItemId,
        'quantityToAdd': quantityToAdd,
        'price': price,
        'invoiceDate': invoiceDate,
        'updatedQuantity': updated,
      });
      // reset row
      selectedCategory = null;
      selectedItemId = null;
      quantityToAdd = 0;
      price = 0.0;
      currentQuantity = updated;
      items = [];
    });
  }

  Future<void> handleSubmit() async {
    final loc = AppLocalizations.of(context)!;
    for (var e in stockEntries) {
      final itemRef = FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('Inventory')
          .doc(e['itemId']);
      final vendorRef = FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('Vendors')
          .doc(e['vendorId']);

      final itemSnap = await itemRef.get();
      final name = itemSnap['ingredientName'];

      await vendorRef.collection('Stock').add({
        'invoiceDate': e['invoiceDate'],
        'category': e['category'],
        'ingredientName': name,
        'quantityAdded': e['quantityToAdd'],
        'price': e['price'],
        'branchCode': branchCode,
        'updatedQuantity': e['updatedQuantity'],
      });

      await itemRef.update({
        'quantity': e['updatedQuantity'],
        'lastUpdated': e['invoiceDate'],
      });

      await itemRef.collection('History').add({
        'invoiceDate': e['invoiceDate'],
        'quantityAdded': e['quantityToAdd'],
        'price': e['price'],
        'updatedQuantity': e['updatedQuantity'],
        'action':  'Add Stock',
        'updatedAt': Timestamp.now(),
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.submitSuccess)),
    );
    setState(() => stockEntries.clear());
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CB050),
        title: Text(loc.addStockTitle,
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: selectedVendorId,
              decoration:
              InputDecoration(labelText: loc.selectVendor),
              items: vendors
                  .map((v) => DropdownMenuItem(
                value: v.id,
                child: Text(v['name']),
              ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  selectedVendorId = v;
                  selectedCategory = null;
                  items = [];
                });
                loadCategories();
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration:
              InputDecoration(labelText: loc.selectCategory),
              items: categories
                  .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c),
              ))
                  .toList(),
              onChanged: (c) {
                setState(() {
                  selectedCategory = c;
                  selectedItemId = null;
                  items = [];
                });
                fetchItems();
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedItemId,
              decoration:
              InputDecoration(labelText: loc.selectItem),
              items: items
                  .map((it) => DropdownMenuItem(
                value: it.id,
                child: Text(it['ingredientName']),
              ))
                  .toList(),
              onChanged: (i) {
                setState(() {
                  selectedItemId = i;
                });
                updateCurrentQuantity();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: currentQuantity.toString(),
              decoration:
              InputDecoration(labelText: loc.currentQuantity),
              readOnly: true,
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration:
              InputDecoration(labelText: loc.quantityToAdd),
              keyboardType: TextInputType.number,
              onChanged: (v) =>
              quantityToAdd = int.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration:
              InputDecoration(labelText: loc.priceLabel),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => price = double.tryParse(v) ?? 0.0,
            ),
            const SizedBox(height: 10),
            ListTile(
              title: Text(
                  '${loc.invoiceDateLabel}: ${DateFormat.yMMMd().format(invoiceDate)}'),
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
              child: Text(loc.addToList),
            ),
            const SizedBox(height: 20),
            if (stockEntries.isNotEmpty) ...[
              Text(loc.stockEntriesHeader,
                  style:
                  const TextStyle(fontWeight: FontWeight.bold)),
              ...stockEntries.map((e) {
                final it = items.firstWhereOrNull(
                        (it) => it.id == e['itemId']);
                return Card(
                  child: ListTile(
                    title:
                    Text(
                      ((it?.data() as Map<String, dynamic>?)?['ingredientName']) ?? loc.unknown,
                    ),
                    subtitle: Text(
                        '${loc.qtyLabel}: ${e['quantityToAdd']} | ${loc.priceLabel}: ${e['price']} | ${loc.dateLabel}: ${DateFormat.yMd().format(e['invoiceDate'])}'),
                  ),
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                stockEntries.isEmpty ? null : handleSubmit,
                child: Text(loc.submitAll),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
