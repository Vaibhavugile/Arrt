import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:art/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class MenuPage extends StatefulWidget {
  final String tableId;
  const MenuPage({Key? key, required this.tableId}) : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with TickerProviderStateMixin {
  late String branchCode;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> products = [];
  Map<String, List<Map<String, dynamic>>> grouped = {};
  String? selectedSubcategory;

  final ValueNotifier<List<Map<String, dynamic>>> _ordersNotifier = ValueNotifier([]);
  String? tableNumber;
  String? orderStatus;

  TabController? _tabController;
  String searchQuery = '';
  final GlobalKey cartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      branchCode = userProvider.branchCode!;
      _loadProducts();
      _listenToTable();
    });
  }

  Future<void> _loadProducts() async {
    final snap = await _db
        .collection('tables')
        .doc(branchCode)
        .collection('products')
        .get();

    final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

    final map = <String, List<Map<String, dynamic>>>{};
    for (var p in list) {
      final sub = (p['subcategory'] as String?) ?? 'Uncategorized';
      map.putIfAbsent(sub, () => []).add(p);
    }

    setState(() {
      products = list;
      grouped = map;
      selectedSubcategory = map.keys.first;
      _tabController = TabController(length: map.keys.length, vsync: this);
      _tabController!.addListener(() {
        selectedSubcategory = grouped.keys.elementAt(_tabController!.index);
        setState(() {});
      });
    });
  }

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
        _ordersNotifier.value = List<Map<String, dynamic>>.from(data['orders'] ?? []);
        tableNumber = data['tableNumber']?.toString();
        orderStatus = data['orderStatus']?.toString();
        setState(() {});
      }
    });
  }

  Future<void> _updateOrders() async {
    await _db
        .collection('tables')
        .doc(branchCode)
        .collection('tables')
        .doc(widget.tableId)
        .update({'orders': _ordersNotifier.value});
  }

  void _addProduct(String productId, BuildContext ctx, GlobalKey key) {
    final prod = products.firstWhere((p) => p['id'] == productId);
    final orders = [..._ordersNotifier.value];
    final idx = orders.indexWhere((o) => o['name'] == prod['name']);

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

    _ordersNotifier.value = orders;
    _updateOrders();
    _runAddToCartAnimation(ctx, key);
  }

  void _changeQuantity(int idx, int delta) {
    final orders = [..._ordersNotifier.value];
    final newQty = (orders[idx]['quantity'] ?? 0) + delta;
    if (newQty <= 0) {
      orders.removeAt(idx);
    } else {
      orders[idx]['quantity'] = newQty;
    }
    _ordersNotifier.value = orders;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateOrders();
    });
  }

  void _runAddToCartAnimation(BuildContext context, GlobalKey targetKey) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final start = renderBox.localToGlobal(Offset.zero);
    final cartRender = targetKey.currentContext?.findRenderObject() as RenderBox?;
    final end = cartRender?.localToGlobal(Offset.zero) ?? Offset(20, 40);

    final overlayEntry = OverlayEntry(
      builder: (context) {
        return AnimatedAddToCart(start: start, end: end);
      },
    );

    overlay.insert(overlayEntry);
    Future.delayed(Duration(milliseconds: 800), () {
      overlayEntry.remove();
    });
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: _ordersNotifier,
        builder: (context, orders, _) => DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, controller) => Padding(
            padding: EdgeInsets.all(12),
            child: ListView(
              controller: controller,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text('Current Order',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                if (orders.isEmpty)
                  Center(child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No items yet', style: TextStyle(color: Colors.grey)),
                  ))
                else
                  ...orders.asMap().entries.map((e) {
                    final idx = e.key;
                    final o = e.value;
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${o['quantity']} x ${o['name']}',
                              style: const TextStyle(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '₹${(o['price'] * o['quantity']).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _changeQuantity(idx, -1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => _changeQuantity(idx, 1),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _visibleProducts {
    if (searchQuery.isEmpty) {
      return grouped[selectedSubcategory] ?? [];
    } else {
      return products
          .where((p) =>
          (p['name'] as String).toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final subcategories = grouped.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Table ${tableNumber ?? "..."}'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            key: cartKey,
            icon: Icon(Icons.shopping_cart_outlined),
            onPressed: _showCartSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),
              if (searchQuery.isEmpty && _tabController != null)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    children: subcategories.map((sub) {
                      final isSelected = sub == selectedSubcategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(sub),
                          selected: isSelected,
                          onSelected: (_) {
                            selectedSubcategory = sub;
                            _tabController?.animateTo(subcategories.indexOf(sub));
                            setState(() {});
                          },
                          selectedColor: Color(0xFF4CB050),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                          backgroundColor: Colors.grey[200],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: grouped.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(8),
        child: GridView.builder(
          itemCount: _visibleProducts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3 / 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (ctx, i) {
            final p = _visibleProducts[i];
            return GestureDetector(
              onTap: () => _addProduct(p['id'], ctx, cartKey),
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name'],
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Spacer(),
                      Text('₹${p['price']}',
                          style: TextStyle(
                              color: Color(0xFF4CB050), fontSize: 14)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: _ordersNotifier,
        builder: (context, orders, _) => orders.isNotEmpty
            ? FloatingActionButton.extended(
          onPressed: _showCartSheet,
          label: Text('View Cart (${orders.length})'),
          icon: Icon(Icons.shopping_cart),
          backgroundColor: Color(0xFF4CB050),
        )
            : SizedBox.shrink(),
      ),
    );
  }
}

class AnimatedAddToCart extends StatefulWidget {
  final Offset start;
  final Offset end;

  const AnimatedAddToCart({required this.start, required this.end});

  @override
  _AnimatedAddToCartState createState() => _AnimatedAddToCartState();
}

class _AnimatedAddToCartState extends State<AnimatedAddToCart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> position;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: Duration(milliseconds: 800), vsync: this);
    position = Tween<Offset>(
      begin: widget.start,
      end: widget.end,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: position,
      builder: (context, child) {
        return Positioned(
          top: position.value.dy,
          left: position.value.dx,
          child: Icon(Icons.fastfood, size: 24, color: Colors.teal),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}