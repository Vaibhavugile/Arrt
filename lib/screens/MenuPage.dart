import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:art/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'kot_screen.dart';

// Define a breakpoint for web/mobile layout switching
const double _webBreakpoint = 800.0;

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
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  final GlobalKey cartKey = GlobalKey(); // Used for FAB and animation target

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      branchCode = userProvider.branchCode!;
      _loadProducts();
      _listenToTable();
    });

    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    _ordersNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
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
        if (map.keys.isNotEmpty) {
          selectedSubcategory = map.keys.first;
          _tabController = TabController(length: map.keys.length, vsync: this);
          _tabController!.addListener(() {
            if (!_tabController!.indexIsChanging) {
              selectedSubcategory = grouped.keys.elementAt(_tabController!.index);
              setState(() {});
            }
          });
        }
      });
    } catch (e) {
      print("Error loading products: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load products.')),
      );
    }
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
            'voidPending': order['voidPending'] ?? 0,
          };
        }).toList();

        _ordersNotifier.value = processedOrders;
        tableNumber = data['tableNumber']?.toString();
        orderStatus = data['orderStatus']?.toString();
        setState(() {}); // Trigger rebuild for tableNumber/orderStatus
      }
    });
  }

  Future<void> _updateOrders() async {
    try {
      await _db
          .collection('tables')
          .doc(branchCode)
          .collection('tables')
          .doc(widget.tableId)
          .update({'orders': _ordersNotifier.value});
    } catch (e) {
      print("Error updating orders: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save order changes.')),
      );
    }
  }

  void _addProduct(String productId, BuildContext ctx, GlobalKey? key) {
    final prod = products.firstWhere((p) => p['id'] == productId);
    final orders = [..._ordersNotifier.value];
    final idx = orders.indexWhere((o) => o['name'] == prod['name']);

    if (idx >= 0) {
      orders[idx]['quantity'] += 1;
      orders[idx]['sentToKot'] = false;
    } else {
      orders.add({
        'name': prod['name'],
        'price': prod['price'],
        'quantity': 1,
        'ingredients': prod['ingredients'] ?? [],
        'sentToKot': false,
        'lastSentQuantity': 0,
        'voidPending': 0,
      });
    }

    _ordersNotifier.value = orders;
    _updateOrders();
    if (key != null) {
      _runAddToCartAnimation(ctx, key);
    }
  }

  void _changeQuantity(int idx, int delta) {
    final orders = [..._ordersNotifier.value];
    final item = orders[idx];

    final currentQuantityInCart = item['quantity'] as int;
    final lastSentQuantity = item['lastSentQuantity'] as int;
    int currentVoidPending = item['voidPending'] as int? ?? 0;

    final newQuantityInCart = currentQuantityInCart + delta;

    if (newQuantityInCart <= 0) {
      if (lastSentQuantity > 0) {
        _pendingVoids.add({
          'name': item['name'],
          'quantity': lastSentQuantity,
          'type': 'void_full',
        });
      }
      orders.removeAt(idx);
    } else {
      if (delta < 0) { // Quantity decreased
        final reductionAmount = -delta;
        final itemsEffectivelySentAndStillInCart = lastSentQuantity - currentVoidPending;

        if (reductionAmount > 0 && itemsEffectivelySentAndStillInCart > 0) {
          final actualVoidForThisReduction = (reductionAmount > itemsEffectivelySentAndStillInCart)
              ? itemsEffectivelySentAndStillInCart
              : reductionAmount;
          currentVoidPending = (currentVoidPending + actualVoidForThisReduction);
        }
      } else { // Quantity increased
        if (currentVoidPending > 0) {
          final amountToReduceVoidPending = (delta > currentVoidPending) ? currentVoidPending : delta;
          currentVoidPending = (currentVoidPending - amountToReduceVoidPending);
        }
      }
      item['quantity'] = newQuantityInCart;
      item['voidPending'] = currentVoidPending;
      item['sentToKot'] = false;
    }

    _ordersNotifier.value = orders;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateOrders();
    });
  }

  Future<void> _sendKOT() async {
    List<Map<String, dynamic>> kotItemsToSend = [];
    List<Map<String, dynamic>> ordersAfterSend = [];

    for (var item in _ordersNotifier.value) {
      final Map<String, dynamic> itemToProcess = Map<String, dynamic>.from(item);

      final currentQuantity = itemToProcess['quantity'] as int;
      final lastSentQuantity = itemToProcess['lastSentQuantity'] as int;
      int voidPending = itemToProcess['voidPending'] as int? ?? 0;

      bool itemChanged = false;

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

      if (voidPending > 0) {
        kotItemsToSend.add({
          'name': itemToProcess['name'],
          'quantity': voidPending,
          'type': 'void_partial',
        });
        itemChanged = true;
      }

      if (itemChanged) {
        itemToProcess['lastSentQuantity'] = currentQuantity;
        itemToProcess['voidPending'] = 0;
        itemToProcess['sentToKot'] = true;
      }

      ordersAfterSend.add(itemToProcess);
    }

    if (_pendingVoids.isNotEmpty) {
      kotItemsToSend.addAll(_pendingVoids);
    }

    if (kotItemsToSend.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending KOT updates (additions or voids).')),
      );
      return;
    }

    try {
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

      _ordersNotifier.value = ordersAfterSend;
      _pendingVoids.clear();

      await _updateOrders();

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
    Future.delayed(const Duration(milliseconds: 800), () {
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
          bool shouldShowButton = _pendingVoids.isNotEmpty;
          if (!shouldShowButton) {
            for (var item in orders) {
              final itemQty = item['quantity'] as int;
              final itemLastSentQty = item['lastSentQuantity'] as int;
              final itemVoidPending = item['voidPending'] as int? ?? 0;
              if (itemQty > itemLastSentQty || itemVoidPending > 0) {
                shouldShowButton = true;
                break;
              }
            }
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, controller) => _buildCartContent(orders, controller, shouldShowButton),
          );
        },
      ),
    );
  }

  Widget _buildCartContent(List<Map<String, dynamic>> orders, ScrollController controller, bool shouldShowButton) {
    return Padding(
      padding: const EdgeInsets.all(16),
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
          Text(
            'Current Order for Table ${tableNumber ?? "..."}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            const Expanded(
                child: Center(
                  child: Text('No items in the cart yet. Add some delicious food!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ))
          else
            Expanded(
              child: ListView(
                controller: controller,
                children: orders.asMap().entries.map((e) {
                  final idx = e.key;
                  final o = e.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o['name'],
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: (o['sentToKot'] == true && (o['voidPending'] as int? ?? 0) == 0) ? Colors.grey : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (o['sentToKot'] == true && (o['voidPending'] as int? ?? 0) == 0)
                                  const Text(
                                    'Sent to KOT',
                                    style: TextStyle(fontSize: 12, color: Colors.green),
                                  ),
                                if ((o['voidPending'] as int? ?? 0) > 0)
                                  Text(
                                    'Void Pending: ${o['voidPending']}',
                                    style: const TextStyle(fontSize: 12, color: Colors.red),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _changeQuantity(idx, -1),
                                tooltip: 'Decrease quantity',
                              ),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  '${o['quantity']}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF4CAF50)),
                                onPressed: () => _changeQuantity(idx, 1),
                                tooltip: 'Increase quantity',
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '₹${(o['price'] * o['quantity']).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (shouldShowButton)
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.pop(context);
                    }
                    _sendKOT();
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Send KOT Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
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

  // --- Mobile Layout Specific Widget Tree ---
  Widget _buildMobileLayout() {
    final subcategories = grouped.keys.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Table ${tableNumber ?? "..."}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.receipt, color: Colors.white),
              label: const Text("Open KOT", style: TextStyle(color: Colors.white)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: Colors.grey, width: 1)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2)),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (searchQuery.isEmpty && subcategories.isNotEmpty)
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 35,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: subcategories.length,
                    itemBuilder: (context, index) {
                      final sub = subcategories[index];
                      final isSelected = sub == selectedSubcategory;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(sub),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                selectedSubcategory = sub;
                              });
                            }
                          },
                          selectedColor: const Color(0xFF4CAF50),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          backgroundColor: Colors.grey[200],
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: isSelected ? 3 : 1,
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: grouped.isEmpty
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50))))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: _visibleProducts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (ctx, i) {
            final p = _visibleProducts[i];
            return ProductCard(
              product: p,
              onAdd: () => _addProduct(p['id'], ctx, cartKey),
              isMobileScreen: true,
            );
          },
        ),
      ),
      floatingActionButton: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: _ordersNotifier,
        builder: (context, orders, _) {
          int totalQuantity = orders.fold(0, (sum, item) => sum + (item['quantity'] as int));
          return orders.isNotEmpty
              ? FloatingActionButton.extended(
            key: cartKey,
            onPressed: _showCartSheet,
            label: Text('View Cart ($totalQuantity)', style: const TextStyle(fontSize: 14)), // Show total quantity
            icon: const Icon(Icons.shopping_cart, size: 20),
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            elevation: 6,
          )
              : const SizedBox.shrink();
        },
      ),
    );
  }

  // --- Web Layout Specific Widget Tree ---
  Widget _buildWebLayout() {
    final subcategories = grouped.keys.toList();

    int crossAxisCount;
    if (MediaQuery.of(context).size.width > 1400) {
      crossAxisCount = 6;
    } else if (MediaQuery.of(context).size.width > 1000) {
      crossAxisCount = 5;
    } else {
      crossAxisCount = 4;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Table ${tableNumber ?? "..."}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.receipt, color: Colors.white, size: 24),
              label: const Text("Open KOTs", style: TextStyle(color: Colors.white, fontSize: 16)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Main Content Area (Products)
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 24),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2)),
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                // Subcategory Bar (Horizontal Chips - "Top Sidebar" feel)
                if (searchQuery.isEmpty && subcategories.isNotEmpty)
                  Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Wrap(
                      spacing: 12.0,
                      runSpacing: 8.0,
                      children: subcategories.map((sub) {
                        final isSelected = sub == selectedSubcategory;
                        return ChoiceChip(
                          label: Text(sub),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                selectedSubcategory = sub;
                              });
                            }
                          },
                          selectedColor: const Color(0xFF4CAF50),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 15,
                          ),
                          backgroundColor: Colors.grey[200],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: isSelected ? 3 : 1,
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 20),
                Expanded(
                  child: grouped.isEmpty
                      ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50))))
                      : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GridView.builder(
                      itemCount: _visibleProducts.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.9,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemBuilder: (ctx, i) {
                        final p = _visibleProducts[i];
                        return ProductCard(
                          product: p,
                          onAdd: () => _addProduct(p['id'], ctx, null),
                          isWeb: true,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Side Cart Area (Web Only)
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _ordersNotifier,
            builder: (context, orders, _) {
              bool shouldShowButton = _pendingVoids.isNotEmpty;
              if (!shouldShowButton) {
                for (var item in orders) {
                  final itemQty = item['quantity'] as int;
                  final itemLastSentQty = item['lastSentQuantity'] as int;
                  final itemVoidPending = item['voidPending'] as int? ?? 0;
                  if (itemQty > itemLastSentQty || itemVoidPending > 0) {
                    shouldShowButton = true;
                    break;
                  }
                }
              }
              return Container(
                width: MediaQuery.of(context).size.width * 0.25,
                constraints: const BoxConstraints(minWidth: 320, maxWidth: 450),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(-3, 0),
                    ),
                  ],
                ),
                child: _buildCartContent(orders, ScrollController(), shouldShowButton),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > _webBreakpoint) {
          return _buildWebLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }
}

// --- Reusable Product Card Widget ---
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onAdd;
  final bool isWeb;
  final bool isMobileScreen;

  const ProductCard({
    Key? key,
    required this.product,
    required this.onAdd,
    this.isWeb = false,
    this.isMobileScreen = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Adjust font sizes and padding based on screen type
    final double nameFontSize = isMobileScreen ? 14 : (isWeb ? 16 : 16);
    final double priceFontSize = isMobileScreen ? 14 : (isWeb ? 18 : 18);
    final double cardPadding = isMobileScreen ? 8 : (isWeb ? 12 : 12);
    final double iconSize = isMobileScreen ? 18 : 20;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: isMobileScreen ? 2 : 5,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: onAdd,
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      product['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: nameFontSize,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Price
                    Text(
                      '₹${(product['price'] as num).toStringAsFixed(1)}',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: priceFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMobileScreen)
            Positioned(
              bottom: 0,
              right: 0,
              child: InkWell(
                onTap: onAdd,
                child: Container(
                  width: iconSize + 8,
                  height: iconSize + 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Icon(Icons.add, color: Colors.white, size: iconSize),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class AnimatedAddToCart extends StatefulWidget {
  final Offset start;
  final Offset end;

  const AnimatedAddToCart({super.key, required this.start, required this.end});

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
        AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
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
          child: const Icon(Icons.fastfood, size: 28, color: Color(0xFF4CAF50)),
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