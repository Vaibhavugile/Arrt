import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class AddVendorPage extends StatefulWidget {
  @override
  State<AddVendorPage> createState() => _AddVendorPageState();
}

class _AddVendorPageState extends State<AddVendorPage> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String contactNo = '';
  String address = '';

  List<String> allCategories = [];
  Map<String, List<Map<String, dynamic>>> itemsByCategory = {};
  List<String> selectedCategories = [];
  Map<String, List<String>> selectedItems = {};

  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchInventoryData();
  }

  Future<void> fetchInventoryData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchCode = userProvider.userData?['branchCode'];
    if (branchCode == null) return;

    final inventoryRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Inventory');

    final snapshot = await inventoryRef.get();
    final categoriesSet = <String>{};
    final itemsMap = <String, List<Map<String, dynamic>>>{};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final category = data['category'] ?? '';
      categoriesSet.add(category);
      itemsMap.putIfAbsent(category, () => []);
      itemsMap[category]!.add({...data, 'id': doc.id});
    }

    setState(() {
      allCategories = categoriesSet.toList();
      itemsByCategory = itemsMap;
      loading = false;
    });
  }

  Future<void> submitVendor() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchCode = userProvider.userData?['branchCode'];
    if (branchCode == null) return;

    final suppliedItems = selectedItems.entries
        .expand((entry) => entry.value.map((id) =>
    itemsByCategory[entry.key]!.firstWhere((item) => item['id'] == id)['ingredientName']))
        .toList();

    final vendorData = {
      'branchCode': branchCode,
      'name': name,
      'contactNo': contactNo,
      'address': address,
      'categories': selectedCategories,
      'suppliedItems': suppliedItems,
    };

    await FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Vendors')
        .add(vendorData);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vendor added successfully')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF4CB050),
        title: Text(
          'Add vendor',
          style: TextStyle(color: Colors.white), // 👈 Makes text white
        ),
        iconTheme: IconThemeData(color: Colors.white), // optional: makes back icon white too
      ),      body: loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Vendor Name'),
                onChanged: (val) => name = val,
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
                onChanged: (val) => contactNo = val,
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Address'),
                onChanged: (val) => address = val,
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 20),
              Text('Select Categories'),
              Wrap(
                spacing: 8,
                children: allCategories.map((cat) {
                  final selected = selectedCategories.contains(cat);
                  return FilterChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          selectedCategories.add(cat);
                        } else {
                          selectedCategories.remove(cat);
                          selectedItems.remove(cat);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              for (final category in selectedCategories)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select items from $category'),
                    Wrap(
                      spacing: 8,
                      children: itemsByCategory[category]!
                          .map((item) {
                        final itemId = item['id'];
                        final selected = selectedItems[category]?.contains(itemId) ?? false;
                        return FilterChip(
                          label: Text('${item['ingredientName']} (${item['quantity']} ${item['unit']})'),
                          selected: selected,
                          onSelected: (val) {
                            setState(() {
                              selectedItems.putIfAbsent(category, () => []);
                              if (val) {
                                selectedItems[category]!.add(itemId);
                              } else {
                                selectedItems[category]!.remove(itemId);
                              }
                            });
                          },
                        );
                      })
                          .toList(),
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    submitVendor();
                  }
                },
                child: Text('Add Vendor'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
