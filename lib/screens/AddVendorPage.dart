import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // generated localization
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
  bool isDarkMode = false; // Added isDarkMode state

  @override
  void initState() {
    super.initState();
    fetchInventoryData();
  }

  Future<void> fetchInventoryData() async {
    setState(() => loading = true); // Set loading to true at the start
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final branchCode = userProvider.userData?['branchCode'];
      if (branchCode == null) {
        setState(() => loading = false);
        return;
      }

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
        loading = false; // Set loading to false on success
      });
    } catch (e) {
      setState(() => loading = false); // Set loading to false on error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.error_loading_inventory)), // Assuming this key exists
      );
    }
  }

  Future<void> submitVendor() async {
    final loc = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchCode = userProvider.userData?['branchCode'];
    if (branchCode == null) return;

    setState(() => loading = true); // Set loading for submission
    try {
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
        'createdAt': FieldValue.serverTimestamp(), // Add timestamp
      };

      await FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('Vendors')
          .add(vendorData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.vendorAddedSuccessfully)),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.error_adding_vendor)), // Assuming this key exists
      );
    } finally {
      setState(() => loading = false); // Always set loading to false
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // Define theme colors consistent with other screens
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
    InputDecoration _themedInputDecoration(String label) {
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
      );
    }

    Widget formContent = Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true, // Important for ListView inside Column/ConstrainedBox
        children: [
          TextFormField(
            decoration: _themedInputDecoration(loc.vendorName),
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            onChanged: (val) => name = val,
            validator: (val) => val!.isEmpty ? loc.requiredField : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            decoration: _themedInputDecoration(loc.contactNumber),
            keyboardType: TextInputType.phone,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            onChanged: (val) => contactNo = val,
            validator: (val) => val!.isEmpty ? loc.requiredField : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            decoration: _themedInputDecoration(loc.address),
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            onChanged: (val) => address = val,
            validator: (val) => val!.isEmpty ? loc.requiredField : null,
          ),
          const SizedBox(height: 20),
          Text(loc.selectCategories, style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allCategories.map((cat) {
              final selected = selectedCategories.contains(cat);
              return FilterChip(
                label: Text(cat, style: TextStyle(color: selected ? Colors.black87 : (isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                selected: selected,
                backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                selectedColor: isDarkMode ? appBarGradientEnd : appBarGradientMid,
                checkmarkColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!),
                ),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      selectedCategories.add(cat);
                    } else {
                      selectedCategories.remove(cat);
                      selectedItems.remove(cat); // Clear selected items for this category
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          for (final category in selectedCategories)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${loc.selectItemsFrom} $category', style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: itemsByCategory[category]!
                      .map((item) {
                    final itemId = item['id'];
                    final selected = selectedItems[category]?.contains(itemId) ?? false;
                    return FilterChip(
                      label: Text(
                          '${item['ingredientName']} (${item['quantity']} ${item['unit']})',
                          style: TextStyle(color: selected ? Colors.black87 : (isDarkMode ? darkModeTextColor : lightModeCardTextColor))),
                      selected: selected,
                      backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      selectedColor: isDarkMode ? appBarGradientEnd : appBarGradientMid,
                      checkmarkColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!),
                      ),
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
                const SizedBox(height: 10),
              ],
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                submitVendor();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? appBarGradientEnd : appBarGradientMid,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: Size(double.infinity, 48), // Full width button
            ),
            child: Text(loc.addVendor, style: TextStyle(color: Colors.black87)),
          )
        ],
      ),
    );

    return Scaffold(
      backgroundColor: isDarkMode ? webContentBackgroundDark : webContentBackgroundLight,
      appBar: AppBar(
        title: Text(loc.addVendor, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
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
            tooltip: loc.toggleTheme, // Assuming 'toggleTheme' exists in AppLocalizations
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
                child: loading
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