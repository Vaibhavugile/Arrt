import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MenuPage extends StatefulWidget {
  final String tableId;
  const MenuPage({ Key? key, required this.tableId }) : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  static const branchCode = '3333';
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // PRODUCTS (loaded once) & grouping
  List<Map<String, dynamic>> products = [];
  Map<String, List<Map<String, dynamic>>> grouped = {};
  String? selectedSubcategory;

  // TABLE state (orders, tableNumber, status) from real-time listener
  List<Map<String, dynamic>> orders = [];
  String? tableNumber;
  String? orderStatus;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _listenToTable();
  }

  /// 1) One-time load of all products, group them by `subcategory`
  Future<void> _loadProducts() async {
    final snap = await _db
        .collection('tables')
        .doc(branchCode)
        .collection('products')
        .get();

    final list = snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList();

    final map = <String, List<Map<String, dynamic>>>{};
    for (var p in list) {
      final sub = (p['subcategory'] as String?) ?? 'Uncategorized';
      map.putIfAbsent(sub, () => []).add(p);
    }

    setState(() {
      products = list;
      grouped = map;
      selectedSubcategory = map.keys.first;
    });
  }

  /// 2) Real-time listener on the table document for orders/status/etc.
  void _listenToTable() {
    _db
        .collection('tables')
        .doc(branchCode)
        .collection('tables')
        .doc(widget.tableId)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data != null && mounted) {
        setState(() {
          tableNumber = data['tableNumber']?.toString();
          orderStatus = data['orderStatus']?.toString();
          orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
        });
      }
    });
  }

  /// Push the updated orders back to Firestore
  Future<void> _updateOrders() async {
    final docRef = _db
        .collection('tables')
        .doc(branchCode)
        .collection('tables')
        .doc(widget.tableId);
    await docRef.update({'orders': orders});
  }

  /// Add one unit of the given product to the order
  void _addProduct(String productId) {
    final prod = products.firstWhere((p) => p['id'] == productId);
    final idx  = orders.indexWhere((o) => o['name'] == prod['name']);
    setState(() {
      if (idx >= 0) {
        orders[idx]['quantity'] += 1;
      } else {
        orders.add({
          'name': prod['name'],
          'price': prod['price'],
          'quantity': 1,
          'ingredients': prod['ingredients'] ?? [],
        });
      }
    });
    _updateOrders();
  }

  /// Change quantity by delta, remove if <= 0
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
        title: Text('Table ${tableNumber ?? "..."}'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ],
      ),

      // --- Drawer with subcategories ---
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text('Categories',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
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

      // --- Body ---
      body: grouped.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Product grid
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: GridView.builder(
                gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3 / 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount:
                grouped[selectedSubcategory]!.length,
                itemBuilder: (ctx, i) {
                  final p = grouped[selectedSubcategory]![i];
                  return GestureDetector(
                    onTap: () => _addProduct(p['id']),
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(8)),
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(p['name'],
                                style: TextStyle(
                                    fontWeight:
                                    FontWeight.bold)),
                            Spacer(),
                            Text('₹${p['price']}',
                                style: TextStyle(
                                    color: Colors.teal)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Live order summary
          Container(
            color: Colors.grey[100],
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                Text('Current Order',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                if (orders.isEmpty)
                  Text('No items yet',
                      style:
                      TextStyle(color: Colors.grey))
                else
                  ...orders
                      .asMap()
                      .entries
                      .map((e) {
                    final idx = e.key;
                    final o = e.value;
                    return Padding(
                      padding:
                      EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(
                                  '${o['quantity']} x ${o['name']}')),
                          Text(
                              '₹${(o['price'] * o['quantity']).toStringAsFixed(2)}'),
                          SizedBox(width: 16),
                          IconButton(
                            icon: Icon(Icons
                                .remove_circle_outline),
                            onPressed: () =>
                                _changeQuantity(idx, -1),
                          ),
                          IconButton(
                            icon: Icon(Icons
                                .add_circle_outline),
                            onPressed: () =>
                                _changeQuantity(idx, 1),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
