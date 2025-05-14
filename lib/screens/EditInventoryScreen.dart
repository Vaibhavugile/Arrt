import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class EditInventoryScreen extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> data;

  EditInventoryScreen({required this.documentId, required this.data});

  @override
  _EditInventoryScreenState createState() => _EditInventoryScreenState();
}

class _EditInventoryScreenState extends State<EditInventoryScreen> {
  final TextEditingController _ingredientNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  String? _category;
  String _unit = 'grams';
  List<String> _suggestedCategories = [];

  @override
  void initState() {
    super.initState();
    _ingredientNameController.text = widget.data['ingredientName'] ?? '';
    _quantityController.text = ((widget.data['quantity'] ?? 0).toDouble()).toString();
    _category = widget.data['category'] ?? '';
    _categoryController.text = _category!;
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
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchCode = userProvider.branchCode;

    if (input.isEmpty || branchCode == null) {
      setState(() => _suggestedCategories = []);
      return;
    }

    final inventoryRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Inventory');

    final querySnapshot = await inventoryRef
        .where('category', isGreaterThanOrEqualTo: input)
        .where('category', isLessThanOrEqualTo: input + '\uf8ff')
        .get();

    final categories = querySnapshot.docs
        .map((doc) => doc['category'] as String)
        .toSet()
        .toList();

    setState(() => _suggestedCategories = categories);
  }

  Future<void> _handleUpdateIngredient() async {
    final ingredientName = _ingredientNameController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim());
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchCode = userProvider.branchCode;

    if (ingredientName.isEmpty || quantity == null || branchCode == null || _category!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill in all fields')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Update"),
        content: Text("Are you sure you want to update this ingredient?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text("Confirm")),
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

      await inventoryRef.update({
        'ingredientName': ingredientName,
        'category': _category,
        'quantity': quantity,
        'unit': _unit,
      });

      final historyRef = inventoryRef.collection('History');
      await historyRef.add({
        'action': 'Edit Inventory',
        'updatedAt': DateTime.now(),
        'updatedQuantity': quantity,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ingredient updated successfully')));
      Navigator.pop(context);
    } catch (e) {
      print('Error updating ingredient: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update ingredient')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF4CB050),
        title: Text(
          'Edit Inventory',
          style: TextStyle(color: Colors.white), // 👈 Makes text white
        ),
        iconTheme: IconThemeData(color: Colors.white), // optional: makes back icon white too
      ),       body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Edit Ingredient", style: Theme.of(context).textTheme.headline6),
                SizedBox(height: 16),
                TextField(
                  controller: _ingredientNameController,
                  decoration: InputDecoration(labelText: 'Ingredient Name', border: OutlineInputBorder()),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _categoryController,
                  onChanged: (val) {
                    _category = val;
                    _fetchCategories(val);
                  },
                  decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                ),
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _suggestedCategories.isNotEmpty
                      ? Wrap(
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
                  )
                      : SizedBox.shrink(),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                ),
                SizedBox(height: 16),
                InputDecorator(
                  decoration: InputDecoration(border: OutlineInputBorder(), labelText: "Unit"),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _unit,
                      isExpanded: true,
                      onChanged: (value) => setState(() => _unit = value!),
                      items: ['grams', 'kilograms', 'liters', 'milliliters', 'pieces', 'boxes']
                          .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                          .toList(),
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text('Update Ingredient'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _handleUpdateIngredient,
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
