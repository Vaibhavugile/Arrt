import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:art/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'kot_screen.dart';

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
  final List<Map<String, dynamic>> _pendingVoids = [];

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

// Inside _MenuPageState

  // Inside _MenuPageState

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
        final List<Map<String, dynamic>> fetchedOrders =
        List<Map<String, dynamic>>.from(data['orders'] ?? []);

        final List<Map<String, dynamic>> processedOrders = fetchedOrders.map((order) {
          return {
            ...order,
            'sentToKot': order['sentToKot'] ?? false,
            'lastSentQuantity': order['lastSentQuantity'] ?? 0,
            'voidPending': order['voidPending'] ?? 0, // Initialize voidPending
          };
        }).toList();

        _ordersNotifier.value = processedOrders;
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
// Inside _MenuPageState

// Modify _addProduct:
  void _addProduct(String productId, BuildContext ctx, GlobalKey key) {
    final prod = products.firstWhere((p) => p['id'] == productId);
    final orders = [..._ordersNotifier.value];
    final idx = orders.indexWhere((o) => o['name'] == prod['name']);

    if (idx >= 0) {
      orders[idx]['quantity'] += 1;
      // Mark as unsent because quantity changed
      orders[idx]['sentToKot'] = false;
      // No need to reset lastSentQuantity here, it's used when sending new items.
    } else {
      orders.add({
        'name': prod['name'],
        'price': prod['price'],
        'quantity': 1,
        'ingredients': prod['ingredients'] ?? [],
        'sentToKot': false,
        'lastSentQuantity': 0, // Initialize to 0 for new items
      });
    }

    _ordersNotifier.value = orders;
    _updateOrders();
    _runAddToCartAnimation(ctx, key);
  }

// Modify _changeQuantity:
// Inside _MenuPageState

// Modify _changeQuantity:
  // Inside _MenuPageState

// Inside _MenuPageState

  void _changeQuantity(int idx, int delta) {
    final orders = [..._ordersNotifier.value];
    final item = orders[idx];

    final currentQuantityInCart = item['quantity'] as int;
    final lastSentQuantity = item['lastSentQuantity'] as int;
    final currentVoidPending = item['voidPending'] as int? ?? 0;

    final newQuantityInCart = currentQuantityInCart + delta;

    if (newQuantityInCart <= 0) {
      // Case: Item is being completely removed or quantity reduced to zero.
      final effectiveSentQuantity = lastSentQuantity - currentVoidPending;

      if (effectiveSentQuantity > 0) {
        // If there's anything *previously sent* that needs to be voided
        // Add this as a 'void_full' to the _pendingVoids list
        _pendingVoids.add({
          'name': item['name'],
          'quantity': effectiveSentQuantity, // Void the effectively sent amount
          'type': 'void_full',
        });
      }
      orders.removeAt(idx); // Remove the item from the local list
    } else {
      // Case: Quantity is reduced but not to zero, or increased (delta > 0).

      if (delta < 0) {
        // Quantity is reduced
        final reductionAmount = -delta;
        final effectivelySentAmount = lastSentQuantity - currentVoidPending;

        if (reductionAmount > 0 && effectivelySentAmount > 0) {
          // Void only what is effectively sent and being reduced
          final actualVoidForThisReduction = (reductionAmount > effectivelySentAmount)
              ? effectivelySentAmount
              : reductionAmount;
          item['voidPending'] = currentVoidPending + actualVoidForThisReduction;
        }
      }
      item['quantity'] = newQuantityInCart;
      item['sentToKot'] = false; // Mark as unsent, indicating a pending change
    }

    _ordersNotifier.value = orders;
    // This will trigger _updateOrders which will persist to Firestore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateOrders();
    });
  }  // Inside _MenuPageState

// Inside _MenuPageState

  // Inside _MenuPageState

  // Inside _MenuPageState

  Future<void> _sendKOT() async {
    List<Map<String, dynamic>> kotItemsToSend = [];
    List<Map<String, dynamic>> updatedOrdersForLocalState = []; // For _ordersNotifier.value

    // --- Process items currently in the cart (_ordersNotifier.value) ---
    for (var item in _ordersNotifier.value) {
      final currentQuantity = item['quantity'] as int;
      final lastSentQuantity = item['lastSentQuantity'] as int;
      final voidPending = item['voidPending'] as int? ?? 0;

      // Process Additions
      if (currentQuantity > lastSentQuantity) {
        final additionalQuantity = currentQuantity - lastSentQuantity;
        kotItemsToSend.add({
          'name': item['name'],
          'price': item['price'],
          'quantity': additionalQuantity,
          'type': 'add',
          'ingredients': item['ingredients'] ?? [],
        });
        // Mark for local update: new lastSentQuantity
        item['lastSentQuantity'] = currentQuantity;
        item['sentToKot'] = true; // Mark as processed for this KOT batch
      }

      // Process Partial Voids (only if item still exists in cart)
      if (voidPending > 0) {
        kotItemsToSend.add({
          'name': item['name'],
          'quantity': voidPending,
          'type': 'void_partial',
        });
        // Mark for local update: reset voidPending
        item['voidPending'] = 0;
      }

      // Add the item to the list that will update _ordersNotifier.value
      updatedOrdersForLocalState.add(item);
    }

    // --- Process items in _pendingVoids (for full removals) ---
    if (_pendingVoids.isNotEmpty) {
      kotItemsToSend.addAll(_pendingVoids); // Add all pending full voids
    }


    if (kotItemsToSend.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending KOT updates (additions or voids).')),
      );
      return;
    }

    try {
      // Send a single KOT document containing all additions and voids
      await _db
          .collection('tables')
          .doc(branchCode)
          .collection('tables')
          .doc(widget.tableId)
          .collection('kots')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'items': kotItemsToSend,
        'status': 'pending', // Initial status for this batch of updates
        'tableNumber': tableNumber,
        // 'userId': Provider.of<UserProvider>(context, listen: false).user?.uid,
      });

      // Update the local state (_ordersNotifier.value) based on processed items
      _ordersNotifier.value = updatedOrdersForLocalState;
      _pendingVoids.clear(); // Clear the full voids list after sending

      await _updateOrders(); // Persist the updated state to Firestore

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KOT update sent successfully!')),
      );
    } catch (e) {
      print("Error sending KOT: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send KOT update. Please try again.')),
      );
    }
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

  // Inside _MenuPageState
  // Inside _MenuPageState
  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
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
            padding: const EdgeInsets.all(12),
            child: Column(
              // Use Column instead of ListView directly for fixed button at bottom
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
                const SizedBox(height: 16),
                const Text('Current Order',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (orders.isEmpty)
                  const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No items yet', style: TextStyle(color: Colors.grey)),
                      ))
                else
                  Expanded(
                    // Wrap ListView with Expanded
                    child: ListView(
                      controller: controller,
                      children: orders.asMap().entries.map((e) {
                        final idx = e.key;
                        final o = e.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${o['quantity']} x ${o['name']}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    // Add a style to show if it's already sent or has pending voids
                                    color: (o['sentToKot'] == true && (o['voidPending'] as int? ?? 0) == 0) ? Colors.grey : Colors.black,
                                    fontStyle: (o['sentToKot'] == true && (o['voidPending'] as int? ?? 0) == 0) ? FontStyle.italic : FontStyle.normal,
                                  ),
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
                      }).toList(),
                    ),
                  ),
                // The "Send Order to KOT" button should be active if there are any changes to send
                if (
                orders.any((item) =>
                ((item['quantity'] as int) > (item['lastSentQuantity'] as int)) || // Pending additions
                    ((item['voidPending'] as int? ?? 0) > 0) // Pending partial voids
                ) || _pendingVoids.isNotEmpty // Check for pending full voids
                )
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Close the bottom sheet
                          _sendKOT();
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Send KOT Update'), // General label
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CB050),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),

                // No need for the else if (orders.isEmpty) block here
                // as the outer if (orders.isNotEmpty) for FAB already handles it.
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
          ElevatedButton(
            child: Text("Open KOT"),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => KotScreen(
                    branchCode: branchCode,
                    tableId: widget.tableId,
                  ),
                ),
              );
            },
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