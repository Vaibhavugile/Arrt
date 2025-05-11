import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MenuPage extends StatefulWidget {
  final String tableId;
  const MenuPage({ super.key, required this.tableId });

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  static const branchCode = '3333'; // hard-coded branch code

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Map<String, dynamic>? table;
  List<Map<String, dynamic>> products = [];
  Map<String, List<Map<String, dynamic>>> grouped = {};
  String? selectedSubcategory;
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    _loadTable();
    _loadProducts();
  }

  Future<void> _loadTable() async {
    final docRef = _db
        .collection('tables')
        .doc(branchCode)
        .collection('tables')
        .doc(widget.tableId);
    final snapshot = await docRef.get();
    if (!mounted) return;
    setState(() {
      table = snapshot.data()?..['id'] = snapshot.id;
      orders = List<Map<String, dynamic>>.from(table?['orders'] ?? []);
    });
  }

  Future<void> _loadProducts() async {
    final colRef = _db.collection('tables').doc(branchCode).collection('products');
    final snap   = await colRef.get();
    final list   = snap.docs.map((d) => { 'id': d.id, ...d.data() }).toList();
    final map    = <String, List<Map<String, dynamic>>>{};
    for (var p in list) {
      final sub = p['subcategory'] as String? ?? 'Uncategorized';
      map.putIfAbsent(sub, () => []).add(p);
    }
    if (!mounted) return;
    setState(() {
      products = list;
      grouped  = map;
      selectedSubcategory = map.keys.first;
    });
  }

  Future<void> _updateOrders() async {
    final docRef = _db
        .collection('tables')
        .doc(branchCode)
        .collection('tables')
        .doc(widget.tableId);
    await docRef.update({ 'orders': orders });
  }

  void _addProduct(String productId) {
    final prod = products.firstWhere((p) => p['id']==productId);
    final idx  = orders.indexWhere((o)=>o['name']==prod['name']);
    setState(() {
      if (idx>=0) {
        orders[idx]['quantity'] = orders[idx]['quantity']+1;
      } else {
        orders.add({
          'name': prod['name'],
          'price': prod['price'],
          'quantity': 1,
          'ingredients': prod['ingredients']
        });
      }
    });
    _updateOrders();
  }

  void _changeQuantity(int idx, int delta) {
    setState(() {
      orders[idx]['quantity'] += delta;
      if (orders[idx]['quantity'] <= 0) orders.removeAt(idx);
    });
    _updateOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Table ${table?['tableNumber'] ?? ''}'),
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(child: Text('Categories', style: TextStyle(fontSize: 24))),
            for (var sub in grouped.keys)
              ListTile(
                title: Text(sub),
                selected: sub == selectedSubcategory,
                onTap: () {
                  setState(() => selectedSubcategory = sub);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      body: grouped.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Product grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3/2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: grouped[selectedSubcategory]!.length,
                itemBuilder: (ctx, i) {
                  final p = grouped[selectedSubcategory]![i];
                  return GestureDetector(
                    onTap: () => _addProduct(p['id']),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                            Spacer(),
                            Text('₹${p['price']}', style: TextStyle(color: Colors.teal)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Order summary
          Container(
            color: Colors.grey[100],
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Current Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                if (orders.isEmpty)
                  Text('No items yet', style: TextStyle(color: Colors.grey))
                else
                  ...orders.asMap().entries.map((e) {
                    final idx = e.key;
                    final o   = e.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text('${o['quantity']} x ${o['name']}')),
                          Text('₹${(o['price']*o['quantity']).toStringAsFixed(2)}'),
                          SizedBox(width: 16),
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline),
                            onPressed: () => _changeQuantity(idx, -1),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_circle_outline),
                            onPressed: () => _changeQuantity(idx, 1),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
