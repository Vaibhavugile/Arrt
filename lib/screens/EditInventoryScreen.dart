import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:art/providers/user_provider.dart';

class EditInventoryScreen extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> data;

  const EditInventoryScreen({
    Key? key,
    required this.documentId,
    required this.data,
  }) : super(key: key);

  @override
  _EditInventoryScreenState createState() => _EditInventoryScreenState();
}

class _EditInventoryScreenState extends State<EditInventoryScreen> {
  late TextEditingController _ingredientNameController;
  late TextEditingController _quantityController;
  late TextEditingController _categoryController;

  String? _category;
  String _unit = 'grams';
  List<String> _suggestedCategories = [];

  @override
  void initState() {
    super.initState();
    _ingredientNameController =
        TextEditingController(text: widget.data['ingredientName'] ?? '');
    _quantityController = TextEditingController(
        text: (widget.data['quantity'] ?? 0).toString());
    _category = widget.data['category'] ?? '';
    _categoryController = TextEditingController(text: _category);
    _unit = widget.data['unit'] ?? 'grams';
  }

  @override
  void dispose() {
    _ingredientNameController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories(String input) async {
    if (input.isEmpty) {
      setState(() => _suggestedCategories = []);
      return;
    }
    final branchCode =
        Provider.of<UserProvider>(context, listen: false).branchCode;
    if (branchCode == null) return;

    final inventoryRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Inventory');

    final snapshot = await inventoryRef
        .where('category', isGreaterThanOrEqualTo: input)
        .where('category', isLessThanOrEqualTo: '$input\uf8ff')
        .get();

    final categories = snapshot.docs
        .map((doc) => doc['category'] as String)
        .toSet()
        .toList();

    setState(() => _suggestedCategories = categories);
  }

  Future<void> _handleUpdateIngredient() async {
    final loc = AppLocalizations.of(context)!;
    final ingredientName = _ingredientNameController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim());
    final category = _category?.trim() ?? '';
    final unit = _unit;

    final branchCode =
        Provider.of<UserProvider>(context, listen: false).branchCode;
    if (ingredientName.isEmpty ||
        quantity == null ||
        category.isEmpty ||
        branchCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.fillAllFields)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(loc.confirmUpdateTitle),
        content: Text(loc.confirmUpdateMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final inventoryRef = FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('Inventory')
          .doc(widget.documentId);

      // Update main document
      await inventoryRef.update({
        'ingredientName': ingredientName, // saved as-is
        'category': category,
        'quantity': quantity,
        'unit': unit,
      });

      // Add to history subcollection
      await inventoryRef.collection('History').add({
        'action': 'Update',
        'updatedAt': DateTime.now(),
        'updatedQuantity': quantity,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.updateSuccess)),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error updating ingredient: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.updateFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CB050),
        title: Text(loc.editInventoryTitle,
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.editIngredientHeading,
                    style: Theme.of(context).textTheme.headline6),
                const SizedBox(height: 16),

                // Ingredient Name
                TextField(
                  controller: _ingredientNameController,
                  decoration: InputDecoration(
                    labelText: loc.ingredientNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Category with suggestions
                TextField(
                  controller: _categoryController,
                  onChanged: (val) {
                    _category = val;
                    _fetchCategories(val);
                  },
                  decoration: InputDecoration(
                    labelText: loc.categoryLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _suggestedCategories.isEmpty
                      ? const SizedBox.shrink()
                      : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedCategories.map((cat) {
                      return ActionChip(
                        label: Text(cat),
                        backgroundColor: Colors.grey.shade200,
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
                ),
                const SizedBox(height: 16),

                // Quantity
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: loc.quantityLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Unit dropdown
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: loc.unitLabel,
                    border: const OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _unit,
                      isExpanded: true,
                      onChanged: (value) => setState(() {
                        if (value != null) _unit = value;
                      }),
                      items: [
                        'grams',
                        'kilograms',
                        'liters',
                        'milliliters',
                        'pieces',
                        'boxes'
                      ]
                          .map((unit) => DropdownMenuItem(
                        value: unit,
                        child: Text(unit),
                      ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _handleUpdateIngredient,
                    icon: const Icon(Icons.save),
                    label: Text(loc.updateButton),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
