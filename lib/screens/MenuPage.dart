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
        'voidPending': 0, // Initialize voidPending for new items
      });
    }

    _ordersNotifier.value = orders;
    _updateOrders();
    _runAddToCartAnimation(ctx, key);
  }

  void _changeQuantity(int idx, int delta) {
    final orders = [..._ordersNotifier.value];
    final item = orders[idx];

    final currentQuantityInCart = item['quantity'] as int;
    final lastSentQuantity = item['lastSentQuantity'] as int;
    int currentVoidPending = item['voidPending'] as int? ?? 0;

    final newQuantityInCart = currentQuantityInCart + delta;

    if (newQuantityInCart <= 0) {
      // When an item is fully removed, we void the entire lastSentQuantity
      // because any 'voidPending' would have been part of that lastSentQuantity
      // and is now superseded by a full void.
      // If lastSentQuantity is 0, it means the item was never sent, so no void needed.
      if (lastSentQuantity > 0) { // Only add to _pendingVoids if it was actually sent before
        _pendingVoids.add({
          'name': item['name'],
          'quantity': lastSentQuantity, // Void the entire quantity that was last sent
          'type': 'void_full',
        });
        print('DEBUG: Added ${item['name']} (qty: $lastSentQuantity) to _pendingVoids for full void.'); // DEBUG
      }
      orders.removeAt(idx); // Remove the item from the local list
    } else {
      if (delta < 0) {
        final reductionAmount = -delta;
        final itemsEffectivelySentAndStillInCart = lastSentQuantity - currentVoidPending;

        if (reductionAmount > 0 && itemsEffectivelySentAndStillInCart > 0) {
          final actualVoidForThisReduction = (reductionAmount > itemsEffectivelySentAndStillInCart)
              ? itemsEffectivelySentAndStillInCart
              : reductionAmount;
          currentVoidPending += actualVoidForThisReduction;
        }
      } else { // delta > 0 (quantity increased)
        // If increasing quantity, we might be re-adding an item that had a pending void.
        // We should try to 'undo' the voidPending if applicable.
        if (currentVoidPending > 0) {
          final amountToReduceVoidPending = (delta > currentVoidPending) ? currentVoidPending : delta;
          currentVoidPending -= amountToReduceVoidPending;
        }
      }
      item['quantity'] = newQuantityInCart;
      item['voidPending'] = currentVoidPending; // Update voidPending for partial voids
      item['sentToKot'] = false; // Mark as unsent, indicating a pending change
    }

    print('--- _changeQuantity Debug ---');
    print('Item: ${item['name']}');
    print('  New Quantity in Cart: ${item['quantity']}');
    print('  Last Sent Quantity: ${item['lastSentQuantity']}');
    print('  Void Pending: ${item['voidPending']}');
    print('  Sent to KOT: ${item['sentToKot']}');
    print('--- End _changeQuantity Debug ---');

    _ordersNotifier.value = orders;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateOrders();
    });
  }

  Future<void> _sendKOT() async {
    List<Map<String, dynamic>> kotItemsToSend = [];
    List<Map<String, dynamic>> ordersAfterSend = []; // This will be the new 'orders' array after successful send

    for (var item in _ordersNotifier.value) {
      // Create a mutable copy of the item for updates within this loop
      final Map<String, dynamic> itemToProcess = Map<String, dynamic>.from(item);

      final currentQuantity = itemToProcess['quantity'] as int;
      final lastSentQuantity = itemToProcess['lastSentQuantity'] as int;
      int voidPending = itemToProcess['voidPending'] as int? ?? 0;

      bool itemChanged = false; // Flag to indicate if this item needs to be sent in KOT

      // Process Additions
      if (currentQuantity > lastSentQuantity) {
        final additionalQuantity = currentQuantity - lastSentQuantity;
        kotItemsToSend.add({
          'name': itemToProcess['name'],
          'price': itemToProcess['price'],
          'quantity': additionalQuantity,
          'type': 'add',
          'ingredients': itemToProcess['ingredients'] ?? [],
        });
        itemChanged = true;
      }

      // Process Partial Voids
      if (voidPending > 0) {
        kotItemsToSend.add({
          'name': itemToProcess['name'],
          'quantity': voidPending,
          'type': 'void_partial',
        });
        itemChanged = true;
      }

      // If the item had any changes (additions or partial voids),
      // update its 'lastSentQuantity' to its 'currentQuantity' and reset 'voidPending'
      if (itemChanged) {
        itemToProcess['lastSentQuantity'] = currentQuantity;
        itemToProcess['voidPending'] = 0; // Reset voidPending after processing
        itemToProcess['sentToKot'] = true; // Mark as processed
      }

      ordersAfterSend.add(itemToProcess); // Add the (potentially updated) item to the list for notifier update
    }

    // Process items in _pendingVoids (for full removals)
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
        'status': 'pending',
        'tableNumber': tableNumber,
      });

      // --- ONLY UPDATE LOCAL STATE AND FIREBASE *AFTER* SUCCESSFUL KOT SEND ---
      _ordersNotifier.value = ordersAfterSend; // Update local state with the processed items
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
        builder: (context, orders, _) {
          // --- Debugging Prints for Button Visibility ---
          print('\n--- Cart Sheet Button Check Debug ---');
          bool shouldShowButton = false;
          orders.forEach((item) {
            final itemQty = item['quantity'] as int;
            final itemLastSentQty = item['lastSentQuantity'] as int;
            final itemVoidPending = item['voidPending'] as int? ?? 0;
            final pendingAddition = itemQty > itemLastSentQty;
            final pendingPartialVoid = itemVoidPending > 0;

            print('  Item: ${item['name']}');
            print('    Qty: $itemQty, Last Sent: $itemLastSentQty, Void Pending: $itemVoidPending');
            print('    Pending Addition: $pendingAddition');
            print('    Pending Partial Void: $pendingPartialVoid');

            if (pendingAddition || pendingPartialVoid) {
              shouldShowButton = true;
            }
          });
          print('  _pendingVoids.isNotEmpty: ${_pendingVoids.isNotEmpty}');
          if (_pendingVoids.isNotEmpty) {
            shouldShowButton = true;
          }
          print('  Overall shouldShowButton: $shouldShowButton');
          print('--- End Cart Sheet Button Check Debug ---\n');
          // ---------------------------------------------

          return DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, controller) => Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
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
                  if (shouldShowButton) // Use the calculated shouldShowButton variable
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _sendKOT();
                          },
                          icon: const Icon(Icons.send),
                          label: const Text('Send KOT Update'),
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
                ],
              ),
            ),
          );
        },
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