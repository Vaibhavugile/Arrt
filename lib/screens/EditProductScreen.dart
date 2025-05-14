import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Product updated successfully!')));
      } catch (e) {
        print('Error updating product: $e');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error updating product')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF4CB050),
        title: Text(
          'Edit Product',
          style: TextStyle(color: Colors.white), // 👈 Makes text white
        ),
        iconTheme: IconThemeData(color: Colors.white), // optional: makes back icon white too
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
                    _buildTextField(productNameController, 'Product Name', TextInputType.text),
                    // Price
                    _buildTextField(priceController, 'Price', TextInputType.number),
                    // Subcategory
                    _buildSubcategoryField(),
                    SizedBox(height: 20),
                    // Ingredients section
                    Text('Ingredients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        label: Text("Add Ingredient"),
                      ),
                    ),
                    SizedBox(height: 24),
                    // Update Product Button
                    ElevatedButton.icon(
                      onPressed: updateProduct,
                      icon: Icon(Icons.save,color: Colors.white ,),
                      label: Text('Update Product',style: TextStyle(color: Colors.white)),
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
        validator: (value) => value!.isEmpty ? 'Please enter a value' : null,
        onChanged: (value) {
          if (label == 'Product Name') {
            productName = value;
          } else if (label == 'Price') {
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
          labelText: 'Subcategory',
          border: OutlineInputBorder(),
        ),
        onChanged: handleSubcategoryChange,
      ),
    );
  }

  Widget _buildIngredientRow(int index) {
    final ingredient = ingredients[index];
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: ingredient['category'].isEmpty ? null : ingredient['category'],
              onChanged: (value) => handleInputChange(index, 'category', value!),
              items: allIngredients.map((e) {
                return DropdownMenuItem<String>(
                  value: e['category'],
                  child: Text(e['category']),
                );
              }).toList(),
              decoration: InputDecoration(labelText: 'Category'),
            ),
            DropdownButtonFormField<String>(
              value: ingredient['ingredientName'].isEmpty ? null : ingredient['ingredientName'],
              onChanged: (value) => handleInputChange(index, 'ingredientName', value!),
              items: allIngredients
                  .where((e) => e['category'] == ingredient['category'])
                  .map((e) {
                return DropdownMenuItem<String>(
                  value: e['ingredientName'],
                  child: Text(e['ingredientName']),
                );
              }).toList(),
              decoration: InputDecoration(labelText: 'Ingredient'),
            ),
            TextFormField(
              initialValue: ingredient['quantityUsed']?.toString(),
              onChanged: (value) => handleInputChange(index, 'quantityUsed', value),
              decoration: InputDecoration(labelText: 'Quantity Used'),
              keyboardType: TextInputType.number,
            ),
            // Remove Ingredient Button
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeIngredientField(index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
