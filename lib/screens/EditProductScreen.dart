import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EditProductScreen extends StatefulWidget {
  final String productId;
  final String branchCode;

  EditProductScreen({required this.productId, required this.branchCode});

  @override
  _EditProductScreenState createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String productName = '';
  String price = '';
  String subcategory = '';
  List<Map<String, dynamic>> ingredients = [];
  List<String> filteredSubcategories = [];
  List<String> allSubcategories = [];
  List<Map<String, dynamic>> allIngredients = [];

  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  TextEditingController productNameController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController subcategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchProductDetails();
    fetchIngredients();
    fetchSubcategories();
  }

  Future<void> fetchProductDetails() async {
    setState(() {
      _isLoading = true;
    });
    try {
      DocumentSnapshot productDoc = await _firestore
          .collection('tables')
          .doc(widget.branchCode)
          .collection('products')
          .doc(widget.productId)
          .get();

      if (productDoc.exists) {
        var data = productDoc.data() as Map<String, dynamic>;
        setState(() {
          productName = data['name'] ?? '';
          price = data['price'].toString();
          subcategory = data['subcategory'] ?? '';
          ingredients = List<Map<String, dynamic>>.from(data['ingredients'] ?? []);
        });

        productNameController.text = productName;
        priceController.text = price;
        subcategoryController.text = subcategory;
      }
    } catch (e) {
      print('Error fetching product details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> fetchIngredients() async {
    try {
      QuerySnapshot ingredientsSnapshot = await _firestore
          .collection('tables')
          .doc(widget.branchCode)
          .collection('Inventory')
          .get();

      setState(() {
        allIngredients = ingredientsSnapshot.docs
            .map((doc) => {
          'id': doc.id,
          'category': doc['category'],
          'ingredientName': doc['ingredientName'],
          'quantity': doc['quantity'],
          'unit': doc['unit']
        })
            .toList();
      });
    } catch (e) {
      print('Error fetching ingredients: $e');
    }
  }

  Future<void> fetchSubcategories() async {
    try {
      QuerySnapshot productSnapshot = await _firestore
          .collection('tables')
          .doc(widget.branchCode)
          .collection('products')
          .get();

      setState(() {
        allSubcategories = productSnapshot.docs
            .map((doc) => doc['subcategory'].toString())
            .toSet()
            .toList();
      });
    } catch (e) {
      print('Error fetching subcategories: $e');
    }
  }

  void handleInputChange(int index, String field, String value) {
    setState(() {
      ingredients[index][field] = value;
    });
  }

  void handleSubcategoryChange(String value) {
    setState(() {
      subcategory = value;
      filteredSubcategories = allSubcategories
          .where((sub) => sub.toLowerCase().contains(value.toLowerCase()))
          .toList();
    });
  }

  void _addIngredientField() {
    setState(() {
      ingredients.add({
        'category': '',
        'ingredientName': '',
        'quantityUsed': '',
      });
    });
  }

  void _removeIngredientField(int index) {
    setState(() {
      ingredients.removeAt(index);
    });
  }

  Future<void> updateProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _firestore
            .collection('tables')
            .doc(widget.branchCode)
            .collection('products')
            .doc(widget.productId)
            .update({
          'name': productName,
          'price': double.parse(price),
          'subcategory': subcategory,
          'ingredients': ingredients
              .where((ingredient) =>
          ingredient['ingredientName'] != null &&
              ingredient['quantityUsed'] != null)
              .toList(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.productUpdatedSuccess)),
        );
      } catch (e) {
        print('Error updating product: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingProduct)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF4CB050),
        title: Text(
          loc.editProduct,
          style: TextStyle(color: Colors.white),
        ),
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
                    // Product Name
                    _buildTextField(productNameController, loc.productName, TextInputType.text),
                    // Price
                    _buildTextField(priceController, loc.price, TextInputType.number),
                    // Subcategory
                    _buildSubcategoryField(),
                    SizedBox(height: 20),
                    // Ingredients section
                    Text(
                      loc.ingredients,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    AnimatedSize(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Column(
                        children: List.generate(ingredients.length, (i) {
                          return _buildIngredientRow(i);
                        }),
                      ),
                    ),
                    // Add Ingredient Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addIngredientField,
                        icon: Icon(Icons.add_circle_outline),
                        label: Text(loc.addIngredient),
                      ),
                    ),
                    SizedBox(height: 24),
                    // Update Product Button
                    ElevatedButton.icon(
                      onPressed: updateProduct,
                      icon: Icon(Icons.save, color: Colors.white),
                      label: Text(
                        loc.updateProduct,
                        style: TextStyle(color: Colors.white),
                      ),
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

  Widget _buildTextField(TextEditingController controller, String label, TextInputType keyboardType) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        validator: (value) => value!.isEmpty ? AppLocalizations.of(context)!.pleaseEnterValue : null,
        onChanged: (value) {
          if (label == AppLocalizations.of(context)!.productName) {
            productName = value;
          } else if (label == AppLocalizations.of(context)!.price) {
            price = value;
          }
        },
      ),
    );
  }

  Widget _buildSubcategoryField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: subcategoryController,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.subcategory,
          border: OutlineInputBorder(),
        ),
        onChanged: handleSubcategoryChange,
      ),
    );
  }

  Widget _buildIngredientRow(int index) {
    final ingredient = ingredients[index];

    // Get unique categories
    final categories = allIngredients.map((e) => e['category']).toSet().toList();

    // Get ingredients for selected category
    final ingredientsForCategory = allIngredients.where((e) => e['category'] == ingredient['category']).toSet().toList();

    final selectedCategory = categories.contains(ingredient['category']) ? ingredient['category'] : null;
    final selectedIngredient = ingredientsForCategory.any((e) => e['ingredientName'] == ingredient['ingredientName'])
        ? ingredient['ingredientName']
        : null;

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Category Dropdown
            DropdownButtonFormField<String>(
              value: selectedCategory,
              onChanged: (value) => handleInputChange(index, 'category', value ?? ''),
              items: categories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat,
                  child: Text(cat),
                );
              }).toList(),
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.category),
            ),

            // Ingredient Dropdown
            DropdownButtonFormField<String>(
              value: selectedIngredient,
              onChanged: (value) => handleInputChange(index, 'ingredientName', value ?? ''),
              items: ingredientsForCategory.map((e) {
                return DropdownMenuItem<String>(
                  value: e['ingredientName'],
                  child: Text(e['ingredientName']),
                );
              }).toList(),
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.ingredient),
            ),

            // Quantity Used Field
            TextFormField(
              initialValue: ingredient['quantityUsed']?.toString(),
              onChanged: (value) => handleInputChange(index, 'quantityUsed', value),
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.quantityUsed),
              keyboardType: TextInputType.number,
            ),

            // Remove Button
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeIngredientField(index),
                tooltip: AppLocalizations.of(context)!.removeIngredient,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
