import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
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
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchCode = userProvider.branchCode;
    if (input.isEmpty || branchCode == null) {
      setState(() => _suggestedCategories = []);
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Inventory')
        .where('category', isGreaterThanOrEqualTo: input)
        .where('category', isLessThanOrEqualTo: input + '\uf8ff')
        .get();

    final categories = snapshot.docs
        .map((doc) => doc['category'] as String)
        .toSet()
        .toList();

    setState(() {
      _suggestedCategories = categories;
    });
  }

  double _convertQuantity(double quantity) {
    switch (_unit) {
      case 'kilograms':
      case 'liters':
        return quantity * 1000;
      default:
        return quantity;
    }
  }

  Future<void> _handleAddIngredient() async {
    final ingredientName = _ingredientNameController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim());
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchCode = userProvider.branchCode;

    if (ingredientName.isEmpty || quantity == null || branchCode == null || _category!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill in all fields')));
      return;
    }

    final confirmed = await showModal(
      context: context,
      configuration: FadeScaleTransitionConfiguration(),
      builder: (context) => AlertDialog(
        title: Text("Confirm Add"),
        content: Text("Are you sure you want to add this ingredient to inventory?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text("Confirm")),
        ],
      ),
    );

    if (confirmed != true) return;

    final standardizedQuantity = _convertQuantity(quantity);

    try {
      final inventoryRef = FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('Inventory');

      final docRef = await inventoryRef.add({
        'ingredientName': ingredientName,
        'category': _category,
        'quantity': standardizedQuantity,
        'unit': _unit,
      });

      await docRef.collection('History').add({
        'quantityAdded': standardizedQuantity,
        'updatedQuantity': standardizedQuantity,
        'action': 'Add Inventory',
        'updatedAt': DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ingredient added successfully!')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding ingredient')));
    }
  }

  Widget _buildTextField(
      {required String label,
        required TextEditingController controller,
        TextInputType inputType = TextInputType.text,
        Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: _suggestedCategories.isNotEmpty
          ? Wrap(
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
      )
          : SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Inventory')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Ingredient Info", style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 16),
                _buildTextField(label: "Ingredient Name", controller: _ingredientNameController),
                SizedBox(height: 16),
                _buildTextField(
                  label: "Category",
                  controller: _categoryController,
                  onChanged: (val) {
                    _category = val;
                    _fetchCategories(val);
                  },
                ),
                SizedBox(height: 8),
                _buildCategoryChips(),
                SizedBox(height: 16),
                _buildTextField(
                  label: "Quantity",
                  controller: _quantityController,
                  inputType: TextInputType.number,
                ),
                SizedBox(height: 16),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: "Unit",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _unit,
                      isExpanded: true,
                      onChanged: (val) => setState(() => _unit = val!),
                      items: ['grams', 'kilograms', 'liters', 'milliliters', 'pieces', 'boxes']
                          .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                          .toList(),
                    ),
                  ),
                ),
                SizedBox(height: 28),
                Center(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text("Add Ingredient"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
