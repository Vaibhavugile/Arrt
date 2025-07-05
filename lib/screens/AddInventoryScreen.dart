import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../providers/user_provider.dart';

class AddInventoryScreen extends StatefulWidget {
  @override
  _AddInventoryScreenState createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends State<AddInventoryScreen> {
  final _ingredientNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _categoryController = TextEditingController();

  String? _category = '';
  String _unit = 'grams';
  List<String> _suggestedCategories = [];

  // Add isDarkMode state for this screen
  bool isDarkMode = false;
  // Declare _isLoading state
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _categoryController.text = '';
  }

  @override
  void dispose() {
    _ingredientNameController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories(String input) async {
    final branchCode =
        Provider.of<UserProvider>(context, listen: false).branchCode;
    if (input.isEmpty || branchCode == null) {
      setState(() => _suggestedCategories = []);
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Inventory')
        .where('category', isGreaterThanOrEqualTo: input)
        .where('category', isLessThanOrEqualTo: '$input\uf8ff')
        .get();

    final categories = snapshot.docs
        .map((doc) => doc['category'] as String)
        .toSet()
        .toList();

    setState(() => _suggestedCategories = categories);
  }

  double _convertQuantity(double q) {
    switch (_unit) {
      case 'kilograms':
      case 'liters':
        return q * 1000;
      default:
        return q;
    }
  }

  Future<void> _handleAddIngredient() async {
    final loc = AppLocalizations.of(context)!;
    final name = _ingredientNameController.text.trim();
    final qty = double.tryParse(_quantityController.text.trim());
    final cat = _category?.trim() ?? '';
    final branchCode =
        Provider.of<UserProvider>(context, listen: false).branchCode;

    if (name.isEmpty || qty == null || cat.isEmpty || branchCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.fillAllFields)),
      );
      return;
    }

    // Set loading to true before showing the dialog
    setState(() => _isLoading = true);

    final confirmed = await showModal<bool>(
      context: context,
      configuration: FadeScaleTransitionConfiguration(),
      builder: (c) => AlertDialog(
        title: Text(loc.confirmAddTitle, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
        content: Text(loc.confirmAddMessage, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87)),
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(loc.cancel, style: TextStyle(color: isDarkMode ? Colors.blueAccent : Colors.blue)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? Color(0xFF87CEEB) : Color(0xFFBFEBFA), // Themed button color
            ),
            child: Text(loc.confirm, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() => _isLoading = false); // Reset loading if not confirmed
      return;
    }

    final standardized = _convertQuantity(qty);

    try {
      final invRef = FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('Inventory');
      final docRef = await invRef.add({
        'ingredientName': name,
        'category': cat,
        'quantity': standardized,
        'unit': _unit,
      });
      await docRef.collection('History').add({
        'quantityAdded': standardized,
        'updatedQuantity': standardized,
        'action': 'Add Inventory',
        'updatedAt': DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.addSuccess)),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.addFailed)),
      );
    } finally {
      setState(() => _isLoading = false); // Ensure loading is false after operation
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType inputType = TextInputType.text,
    Function(String)? onChanged,
    bool isDarkMode = false, // Add isDarkMode parameter
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      onChanged: onChanged,
      decoration: InputDecoration(
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
      ),
      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
    );
  }

  Widget _buildCategoryChips({bool isDarkMode = false}) { // Add isDarkMode parameter
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _suggestedCategories.isEmpty
          ? const SizedBox.shrink()
          : Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _suggestedCategories.map((cat) {
          return ActionChip(
            label: Text(cat, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87)),
            backgroundColor: isDarkMode ? Colors.blueGrey.shade700 : Colors.blueGrey.shade100,
            onPressed: () {
              setState(() {
                _category = cat;
                _categoryController.text = cat;
                _suggestedCategories = [];
              });
            },
          );
        }).toList(),
      ),
    );
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

    final Color webContentBackgroundLight = Colors.white;
    final Color webContentBackgroundDark = Colors.grey[900]!;

    return Scaffold(
      backgroundColor: isDarkMode ? webContentBackgroundDark : webContentBackgroundLight,
      appBar: AppBar(
        title: Text(loc.addInventoryTitle, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
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
            tooltip: loc.toggleTheme, // Assuming you have this string in app_localizations.dart
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
                      constraints: BoxConstraints(maxWidth: 600), // Adjust max width as needed for a single form
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 6,
                        color: isDarkMode ? darkModeCardColor : lightModeCardSolidColor,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(loc.ingredientInfoHeading,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor)),
                              const SizedBox(height: 16),

                              _buildTextField(
                                label: loc.ingredientNameLabel,
                                controller: _ingredientNameController,
                                isDarkMode: isDarkMode,
                              ),
                              const SizedBox(height: 16),

                              _buildTextField(
                                label: loc.categoryLabel,
                                controller: _categoryController,
                                onChanged: (v) {
                                  _category = v;
                                  _fetchCategories(v);
                                },
                                isDarkMode: isDarkMode,
                              ),
                              const SizedBox(height: 8),
                              _buildCategoryChips(isDarkMode: isDarkMode),
                              const SizedBox(height: 16),

                              _buildTextField(
                                label: loc.quantityLabel,
                                controller: _quantityController,
                                inputType: TextInputType.numberWithOptions(decimal: true),
                                isDarkMode: isDarkMode,
                              ),
                              const SizedBox(height: 16),

                              InputDecorator(
                                decoration: InputDecoration(
                                  labelText: loc.unitLabel,
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
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _unit,
                                    isExpanded: true,
                                    onChanged: (v) => setState(() {
                                      if (v != null) _unit = v;
                                    }),
                                    dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white, // Dropdown background
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87), // Dropdown text color
                                    items: [
                                      'grams',
                                      'kilograms',
                                      'liters',
                                      'milliliters',
                                      'pieces',
                                      'boxes'
                                    ]
                                        .map((u) =>
                                        DropdownMenuItem(value: u, child: Text(u)))
                                        .toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              Center(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.add, color: Colors.black87),
                                  label: Text(loc.addButton, style: TextStyle(color: Colors.black87)),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16)),
                                    elevation: 3,
                                    backgroundColor: isDarkMode ? appBarGradientEnd : appBarGradientMid, // Themed button color
                                  ),
                                  onPressed: _handleAddIngredient,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                    : SingleChildScrollView( // Mobile Layout
                  padding: const EdgeInsets.all(16),
                  child: Card( // Wrap content in a Card for consistent styling
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 6,
                    color: isDarkMode ? darkModeCardColor : lightModeCardSolidColor,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.ingredientInfoHeading,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isDarkMode ? darkModeTextColor : lightModeCardTextColor)),
                          const SizedBox(height: 16),

                          _buildTextField(
                            label: loc.ingredientNameLabel,
                            controller: _ingredientNameController,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            label: loc.categoryLabel,
                            controller: _categoryController,
                            onChanged: (v) {
                              _category = v;
                              _fetchCategories(v);
                            },
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 8),
                          _buildCategoryChips(isDarkMode: isDarkMode),
                          const SizedBox(height: 16),

                          _buildTextField(
                            label: loc.quantityLabel,
                            controller: _quantityController,
                            inputType: TextInputType.numberWithOptions(decimal: true),
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 16),

                          InputDecorator(
                            decoration: InputDecoration(
                              labelText: loc.unitLabel,
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
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _unit,
                                isExpanded: true,
                                onChanged: (v) => setState(() {
                                  if (v != null) _unit = v;
                                }),
                                dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                                items: [
                                  'grams',
                                  'kilograms',
                                  'liters',
                                  'milliliters',
                                  'pieces',
                                  'boxes'
                                ]
                                    .map((u) =>
                                    DropdownMenuItem(value: u, child: Text(u)))
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add, color: Colors.black87),
                              label: Text(loc.addButton, style: TextStyle(color: Colors.black87)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 3,
                                backgroundColor: isDarkMode ? appBarGradientEnd : appBarGradientMid,
                              ),
                              onPressed: _handleAddIngredient,
                            ),
                          ),
                        ],
                      ),
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