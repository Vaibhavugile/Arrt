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

  bool _isLoading = false; // Added _isLoading state
  bool isDarkMode = false; // Added isDarkMode state

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
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('Vendors')
          .get();
      setState(() {
        vendors = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.error_loading_vendors)),
      );
    }
  }

  void loadCategories() {
    final v = vendors.firstWhereOrNull((v) => v.id == selectedVendorId);
    if (v != null) {
      final data = v.data() as Map<String, dynamic>;
      setState(() {
        categories = List<String>.from(data['categories'] ?? []);
        selectedCategory = categories.firstOrNull; // Select first category if available
        items = []; // Clear items when vendor or category changes
        selectedItemId = null;
      });
      if (selectedCategory != null) {
        fetchItems();
      }
    } else {
      setState(() {
        categories = [];
        items = [];
        selectedCategory = null;
        selectedItemId = null;
      });
    }
  }

  Future<void> fetchItems() async {
    if (selectedCategory == null) {
      setState(() {
        items = [];
        selectedItemId = null;
      });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('Inventory')
          .where('category', isEqualTo: selectedCategory)
          .get();
      setState(() {
        items = snap.docs;
        selectedItemId = items.firstOrNull?.id; // Select first item if available
        _isLoading = false;
      });

      if (selectedItemId != null) {
        updateCurrentQuantity();
      } else {
        setState(() => currentQuantity = 0); // Reset quantity if no item
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.error_loading_items)),
      );
    }
  }

  void updateCurrentQuantity() {
    setState(() => _isLoading = true);
    final doc = items.firstWhereOrNull((i) => i.id == selectedItemId);
    if (doc != null) {
      final qty = doc['quantity'];
      setState(() {
        currentQuantity = (qty is int ? qty : (qty is double ? qty.toInt() : 0));
        _isLoading = false;
      });
    } else {
      setState(() {
        currentQuantity = 0;
        _isLoading = false;
      });
    }
  }

  void handleAddStockEntry() {
    final loc = AppLocalizations.of(context)!;
    if (selectedItemId == null || quantityToAdd <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.fillAllFields)));
      return;
    }

    final selectedItem = items.firstWhereOrNull((doc) => doc.id == selectedItemId);
    if (selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.selected_item_not_found)));
      return;
    }

    final updated = currentQuantity + quantityToAdd;

    setState(() {
      stockEntries.add({
        'vendorId': selectedVendorId,
        'category': selectedCategory,
        'itemId': selectedItemId,
        'ingredientName': selectedItem['ingredientName'] ?? loc.unknown,
        'quantityToAdd': quantityToAdd,
        'price': price,
        'invoiceDate': invoiceDate,
        'updatedQuantity': updated,
      });

      // Clear fields for next entry
      selectedCategory = null; // Maybe keep vendor, but clear others
      selectedItemId = null;
      quantityToAdd = 0;
      price = 0.0;
      currentQuantity = 0; // Reset for next item selection
      items = []; // Clear items to force re-fetch based on new selection
    });
  }

  Future<void> handleSubmit() async {
    final loc = AppLocalizations.of(context)!;
    if (stockEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.no_entries_to_submit)));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var e in stockEntries) {
        final itemRef = FirebaseFirestore.instance
            .collection('tables')
            .doc(branchCode)
            .collection('Inventory')
            .doc(e['itemId']);
        final vendorStockRef = FirebaseFirestore.instance
            .collection('tables')
            .doc(branchCode)
            .collection('Vendors')
            .doc(e['vendorId'])
            .collection('Stock');

        // Update Inventory quantity
        batch.update(itemRef, {
          'quantity': e['updatedQuantity'],
          'lastUpdated': e['invoiceDate'],
        });

        // Add to Vendor's Stock history
        batch.set(vendorStockRef.doc(), { // Use .doc() to create a new document with auto-ID
          'invoiceDate': e['invoiceDate'],
          'category': e['category'],
          'ingredientName': e['ingredientName'], // Use already fetched name
          'quantityAdded': e['quantityToAdd'],
          'price': e['price'],
          'branchCode': branchCode,
          'updatedQuantity': e['updatedQuantity'],
          'createdAt': FieldValue.serverTimestamp(), // Add server timestamp
        });

        // Add to Inventory item's History
        batch.set(itemRef.collection('History').doc(), { // Use .doc() for auto-ID
          'invoiceDate': e['invoiceDate'],
          'quantityAdded': e['quantityToAdd'],
          'price': e['price'],
          'updatedQuantity': e['updatedQuantity'],
          'action':  'Add Stock',
          'updatedAt': Timestamp.now(),
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.submitSuccess)),
      );
      setState(() {
        stockEntries.clear();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.error_adding_stock)), // Add a specific error message
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // Define theme colors consistent with ProductScreen and AddProductScreen
    final Color appBarGradientStart = Color(0xFFE0FFFF); // Muted light blue
    final Color appBarGradientMid = Color(0xFFBFEBFA);   // Steel Blue
    final Color appBarGradientEnd = Color(0xFF87CEEB);   // Dark Indigo (This is a good accent color)

    final Color lightModeCardSolidColor = Colors.grey[100]!; // Changed to light grey
    final Color darkModeCardColor = Colors.grey[800]!; // Dark mode card background
    final Color lightModeCardTextColor = Colors.black87; // Dark text
    final Color darkModeTextColor = Colors.white70; // Dark text
    final Color darkModeIconColor = Colors.white; // Icons in dark mode

    final Color webContentBackgroundLight = Colors.white;
    final Color webContentBackgroundDark = Colors.grey[900]!;

    // Helper for themed InputDecoration
    InputDecoration _themedInputDecoration(String label, {bool isDropdown = false}) {
      return InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDarkMode ? Colors.blueAccent : Colors.blue),
        ),
        fillColor: isDarkMode ? Colors.grey[700] : Colors.grey[50],
        filled: true,
        labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
        contentPadding: isDropdown ? EdgeInsets.symmetric(horizontal: 12, vertical: 8) : null,
      );
    }

    Widget formContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.addStockEntry, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor)),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: _themedInputDecoration(loc.selectVendor, isDropdown: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedVendorId,
              hint: Text(loc.selectVendor, style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey[600])),
              dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              isExpanded: true,
              onChanged: (newValue) {
                setState(() {
                  selectedVendorId = newValue;
                });
                loadCategories();
              },
              items: vendors.map((vendor) {
                return DropdownMenuItem<String>(
                  value: vendor.id,
                  child: Text(vendor['name']),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        InputDecorator(
          decoration: _themedInputDecoration(loc.selectCategory, isDropdown: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedCategory,
              hint: Text(loc.selectCategory, style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey[600])),
              dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              isExpanded: true,
              onChanged: (newValue) {
                setState(() {
                  selectedCategory = newValue;
                });
                fetchItems();
              },
              items: categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        InputDecorator(
          decoration: _themedInputDecoration(loc.selectItem, isDropdown: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedItemId,
              hint: Text(loc.selectItem, style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey[600])),
              dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              isExpanded: true,
              onChanged: (newValue) {
                setState(() {
                  selectedItemId = newValue;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  updateCurrentQuantity();
                });
              },
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item.id,
                  child: Text('${item['ingredientName']} (Current: ${item['quantity'] ?? 0} ${item['unit'] ?? ''})'),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('${loc.currentQuantity}: $currentQuantity', style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor)),
        const SizedBox(height: 10),
        TextFormField(
          decoration: _themedInputDecoration(loc.quantityToAdd),
          keyboardType: TextInputType.number,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          onChanged: (v) =>
          quantityToAdd = int.tryParse(v) ?? 0,
        ),
        const SizedBox(height: 10),
        TextFormField(
          decoration: _themedInputDecoration(loc.priceLabel),
          keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          onChanged: (v) => price = double.tryParse(v) ?? 0.0,
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: invoiceDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (BuildContext context, Widget? child) {
                return Theme(
                  data: isDarkMode ? ThemeData.dark().copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: appBarGradientEnd, // header background color
                      onPrimary: Colors.white, // header text color
                      onSurface: Colors.white, // body text color
                    ),
                    dialogBackgroundColor: darkModeCardColor,
                  ) : ThemeData.light().copyWith(
                    colorScheme: ColorScheme.light(
                      primary: appBarGradientMid, // header background color
                      onPrimary: Colors.white, // header text color
                      onSurface: Colors.black, // body text color
                    ),
                    dialogBackgroundColor: lightModeCardSolidColor,
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => invoiceDate = picked);
            }
          },
          child: InputDecorator(
            decoration: _themedInputDecoration(loc.invoiceDateLabel),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat.yMd().format(invoiceDate), style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
                Icon(Icons.calendar_today, color: isDarkMode ? darkModeIconColor : lightModeCardTextColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: handleAddStockEntry,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDarkMode ? appBarGradientEnd : appBarGradientMid,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: Size(double.infinity, 48), // Full width button
          ),
          child: Text(loc.addToList, style: TextStyle(color: Colors.black87)),
        ),
        const SizedBox(height: 20),
        if (stockEntries.isNotEmpty) ...[
          Text(loc.stockEntriesHeader,
              style:
              TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? darkModeTextColor : lightModeCardTextColor)),
          ...stockEntries.map((e) {

            return Card(
              color: isDarkMode ? Colors.grey[700] : Colors.white,
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title:
                Text(e['ingredientName'] ?? loc.unknown, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),

                subtitle: Text(
                    '${loc.qtyLabel}: ${e['quantityToAdd']} | ${loc.priceLabel}: ${e['price']} | ${loc.dateLabel}: ${DateFormat.yMd().format(e['invoiceDate'])}',
                    style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[600])),
              ),
            );
          }),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed:
            stockEntries.isEmpty ? null : handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? appBarGradientEnd : appBarGradientMid,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: Size(double.infinity, 48), // Full width button
            ),
            child: Text(loc.submitAll, style: TextStyle(color: Colors.black87)),
          ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: isDarkMode ? webContentBackgroundDark : webContentBackgroundLight,
      appBar: AppBar(
        title: Text(loc.addStockTitle, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.white),
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
            tooltip: loc.toggleTheme, // Ensure this string is in app_localizations.dart
          ),
        ],
        flexibleSpace: isDarkMode
            ? Container(
          color: Colors.grey[850], // Dark mode AppBar background
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isLargeScreen = constraints.maxWidth > 700;

          return Stack(
            children: [
              AnimatedSwitcher(
                duration: Duration(milliseconds: 400),
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(isDarkMode ? appBarGradientMid : appBarGradientEnd)))
                    : isLargeScreen
                    ? Center( // Center the form on large screens
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: ConstrainedBox( // Constrain max width for better readability on very wide screens
                      constraints: BoxConstraints(maxWidth: 800), // Adjust max width as needed
                      child: Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        color: isDarkMode ? darkModeCardColor : lightModeCardSolidColor,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: formContent,
                        ),
                      ),
                    ),
                  ),
                )
                    : SingleChildScrollView( // Mobile Layout
                  padding: const EdgeInsets.all(16.0),
                  child: Card( // Wrap mobile content in a Card too for consistent look
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    color: isDarkMode ? darkModeCardColor : lightModeCardSolidColor,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: formContent,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}