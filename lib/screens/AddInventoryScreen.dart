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

    final confirmed = await showModal<bool>(
      context: context,
      configuration: FadeScaleTransitionConfiguration(),
      builder: (c) => AlertDialog(
        title: Text(loc.confirmAddTitle),
        content: Text(loc.confirmAddMessage),
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
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType inputType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _suggestedCategories.isEmpty
          ? const SizedBox.shrink()
          : Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _suggestedCategories.map((cat) {
          return ActionChip(
            label: Text(cat),
            backgroundColor: Colors.blueGrey.shade100,
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CB050),
        title: Text(loc.addInventoryTitle,
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.ingredientInfoHeading,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),

                _buildTextField(
                  label: loc.ingredientNameLabel,
                  controller: _ingredientNameController,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: loc.categoryLabel,
                  controller: _categoryController,
                  onChanged: (v) {
                    _category = v;
                    _fetchCategories(v);
                  },
                ),
                const SizedBox(height: 8),
                _buildCategoryChips(),
                const SizedBox(height: 16),

                _buildTextField(
                  label: loc.quantityLabel,
                  controller: _quantityController,
                  inputType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),

                InputDecorator(
                  decoration: InputDecoration(
                    labelText: loc.unitLabel,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _unit,
                      isExpanded: true,
                      onChanged: (v) => setState(() {
                        if (v != null) _unit = v;
                      }),
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
                    icon: const Icon(Icons.add),
                    label: Text(loc.addButton),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                    ),
                    onPressed: _handleAddIngredient,
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
