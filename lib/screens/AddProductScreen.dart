import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // <-- Add this line
import 'package:art/providers/user_provider.dart';

class AddProductScreen extends StatefulWidget {
  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _subcategoryController = TextEditingController();

  bool _isLoading = false;
  bool _isOffline = false;
  String _branchCode = '';
  List<Map<String, String>> _ingredients = [{'category': '', 'ingredientName': '', 'quantityUsed': ''}];

  List<String> _allSubcategories = [];
  List<String> _filteredSubcategories = [];

  List<String> _allCategories = [];
  List<String> _filteredCategories = [];

  List<Map<String, dynamic>> _allIngredients = [];

  @override
  void initState() {
    super.initState();
    _initializeOfflineSupport();
    Future.delayed(Duration.zero, _fetchBranchCode);
  }

  void _initializeOfflineSupport() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
  }

  void _fetchBranchCode() {
    final userData = Provider.of<UserProvider>(context, listen: false).userData;
    if (userData != null && userData['branchCode'] != null) {
      _branchCode = userData['branchCode'];
      _fetchIngredients();
      _fetchSubcategories();
      _fetchCategories();
    }
  }

  void _fetchIngredients() async {
    if (_branchCode.isEmpty) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('tables')
        .doc(_branchCode)
        .collection('Inventory')
        .get();

    setState(() {
      _allIngredients = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'category': data['category'] ?? '',
          'ingredientName': data['ingredientName'] ?? '',
          'quantity': data['quantity'] ?? '',
          'unit': data['unit'] ?? ''
        };
      }).toList();
    });
  }

  void _fetchSubcategories() async {
    if (_branchCode.isEmpty) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('tables')
        .doc(_branchCode)
        .collection('products')
        .get();

    setState(() {
      _allSubcategories = snapshot.docs
          .map((doc) => doc['subcategory']?.toString() ?? '')
          .where((sub) => sub.isNotEmpty)
          .toSet()
          .toList();
    });
  }

  void _fetchCategories() async {
    if (_branchCode.isEmpty) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('tables')
        .doc(_branchCode)
        .collection('products')
        .get();

    setState(() {
      _allCategories = snapshot.docs
          .map((doc) => doc['category']?.toString() ?? '')
          .where((cat) => cat.isNotEmpty)
          .toSet()
          .toList();
    });
  }

  void _addIngredientField() {
    setState(() {
      _ingredients.add({'category': '', 'ingredientName': '', 'quantityUsed': ''});
    });
  }

  void _removeIngredientField(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.remove_ingredient),
        content: Text(AppLocalizations.of(context)!.remove_ingredient_confirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context)!.remove)),
        ],
      ),
    );
    if (confirm ?? false) {
      setState(() {
        _ingredients.removeAt(index);
      });
    }
  }

  void _handleInputChange(int index, String field, String value) {
    setState(() {
      _ingredients[index][field] = value;
    });
  }

  void _handleSubcategoryChange(String value) {
    setState(() {
      _subcategoryController.text = value;
      _filteredSubcategories = _allSubcategories
          .where((sub) => sub.toLowerCase().contains(value.toLowerCase()))
          .toList();
    });
  }

  void _handleSubcategorySelect(String subcategory) {
    setState(() {
      _subcategoryController.text = subcategory;
      _filteredSubcategories = [];
    });
  }

  void _handleCategoryChange(String value) {
    setState(() {
      _categoryController.text = value;
      _filteredCategories = _allCategories
          .where((cat) => cat.toLowerCase().contains(value.toLowerCase()))
          .toList();
    });
  }

  void _handleCategorySelect(String category) {
    setState(() {
      _categoryController.text = category;
      _filteredCategories = [];
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final productsRef = FirebaseFirestore.instance
          .collection('tables')
          .doc(_branchCode)
          .collection('products');

      final productData = {
        'name': _nameController.text.trim(),
        'branchCode': _branchCode,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'category': _categoryController.text.trim(),
        'subcategory': _subcategoryController.text.trim(),
        'ingredients': _ingredients
            .where((ing) => ing['ingredientName']!.isNotEmpty && ing['quantityUsed']!.isNotEmpty)
            .toList(),
      };

      await productsRef.add(productData);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isOffline
            ? AppLocalizations.of(context)!.product_saved_offline
            : AppLocalizations.of(context)!.product_added_success),
      ));

      setState(() {
        _isLoading = false;
        _nameController.clear();
        _priceController.clear();
        _categoryController.clear();
        _subcategoryController.clear();
        _ingredients = [{'category': '', 'ingredientName': '', 'quantityUsed': ''}];
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.error_adding_product)));
    }
  }

  Widget _buildTextField(TextEditingController controller, String labelKey, TextInputType type) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: loc.getTranslatedField(labelKey),
          border: OutlineInputBorder(),
        ),
        onChanged: labelKey == 'category'
            ? _handleCategoryChange
            : labelKey == 'subcategory'
            ? _handleSubcategoryChange
            : null,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return loc.enter_field(loc.getTranslatedField(labelKey));
          }
          if (labelKey == 'price' && double.tryParse(value) == null) {
            return loc.enter_valid_number;
          }
          return null;
        },
      ),
    );
  }

  Widget _buildCategoryField() {
    final loc = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(_categoryController, 'category', TextInputType.text),
        if (_filteredCategories.isNotEmpty)
          ..._filteredCategories.map((cat) => ListTile(
            title: Text(cat),
            onTap: () => _handleCategorySelect(cat),
          )),
      ],
    );
  }

  Widget _buildSubcategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(_subcategoryController, 'subcategory', TextInputType.text),
        if (_filteredSubcategories.isNotEmpty)
          ..._filteredSubcategories.map((sub) => ListTile(
            title: Text(sub),
            onTap: () => _handleSubcategorySelect(sub),
          )),
      ],
    );
  }

  Widget _buildIngredientRow(int i, List<String> categoryList) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade100,
        ),
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${loc.ingredient} ${i + 1}", style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeIngredientField(i),
                ),
              ],
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _ingredients[i]['category']!.isEmpty ? null : _ingredients[i]['category'],
              hint: Text(loc.category),
              decoration: InputDecoration(border: OutlineInputBorder()),
              items: categoryList.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat,
                  child: Text(cat),
                );
              }).toList(),
              onChanged: (value) => _handleInputChange(i, 'category', value ?? ''),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _ingredients[i]['ingredientName']!.isEmpty
                  ? null
                  : _ingredients[i]['ingredientName'],
              hint: Text(loc.ingredient),
              decoration: InputDecoration(border: OutlineInputBorder()),
              items: _allIngredients
                  .where((ing) => ing['category'] == _ingredients[i]['category'])
                  .map((ing) {
                return DropdownMenuItem<String>(
                  value: ing['ingredientName'],
                  child: Text('${ing['ingredientName']} (${ing['quantity']} ${ing['unit']})'),
                );
              }).toList(),
              onChanged: (value) => _handleInputChange(i, 'ingredientName', value ?? ''),
            ),
            SizedBox(height: 10),
            TextFormField(
              decoration: InputDecoration(
                labelText: loc.quantity_used,
                hintText: loc.quantity_example,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => _handleInputChange(i, 'quantityUsed', value),
              initialValue: _ingredients[i]['quantityUsed'],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final categoryList = _allIngredients.map((ing) => ing['category']?.toString() ?? '').toSet().toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF4CB050),
        title: Text(loc.add_product, style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: Duration(milliseconds: 400),
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : Padding(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildTextField(_nameController, 'product_name', TextInputType.text),
                    _buildTextField(_priceController, 'price', TextInputType.number),
                    _buildCategoryField(),
                    _buildSubcategoryField(),
                    SizedBox(height: 20),
                    Text(loc.ingredients, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    AnimatedSize(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Column(
                        children: List.generate(_ingredients.length, (i) {
                          return _buildIngredientRow(i, categoryList);
                        }),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addIngredientField,
                        icon: Icon(Icons.add_circle_outline),
                        label: Text(loc.add_ingredient),
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _submitForm,
                      icon: Icon(Icons.save, color: Colors.white),
                      label: Text(loc.add_product, style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
