import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:art/screens/MenuPage.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as serial;
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class BillingScreen extends StatefulWidget {
  @override
  _BillingScreenState createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String branchCode = '3333';

  List<Map<String, dynamic>> tables = [];
  Map<String, dynamic>? selectedTable;
  String paymentMethod = '';
  String paymentStatus = '';
  String responsibleName = '';
  double discountPercentage = 0.0;
  final BlueThermalPrinter bluetoothPrinter = BlueThermalPrinter.instance;
  @override
  void initState() {
    super.initState();
    fetchTables();
  }

  Future<void> fetchTables() async {
    try {
      final querySnapshot = await _db
          .collection('tables')
          .doc(branchCode)
          .collection('tables')
          .get();

      setState(() {
        tables = querySnapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
            'orderStatus': 'Running Order',
          };
        }).toList();
      });
    } catch (e) {
      print("Error fetching tables: $e");
    }
  }
  // Connect to the Bluetooth printer
  // Connect to the Bluetooth printer
  Future<void> saveSelectedPrinter(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_printer_address', address);
  }
  Future<BluetoothDevice?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAddress = prefs.getString('saved_printer_address');
    if (savedAddress == null) return null;

    final devices = await bluetoothPrinter.getBondedDevices();
    final matches = devices.where((device) => device.address == savedAddress);
    return matches.isNotEmpty ? matches.first : null;

  }

  Future<void> connectToBluetoothPrinter() async {
    try {
      final devices = await bluetoothPrinter.getBondedDevices();
      if (devices.isEmpty) {
        Fluttertoast.showToast(msg: "No Bluetooth devices found!");
        return;
      }

      // Disconnect before connecting again to avoid stale socket
      await bluetoothPrinter.disconnect();
      await Future.delayed(Duration(milliseconds: 300));

      await bluetoothPrinter.connect(devices.first);
      await Future.delayed(Duration(seconds: 1));

      final connected = await bluetoothPrinter.isConnected ?? false;
      if (connected) {
        Fluttertoast.showToast(msg: "Connected to printer!");
      } else {
        Fluttertoast.showToast(msg: "Failed to connect to printer.");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error connecting to Bluetooth printer: $e");
    }
  }
  Future<BluetoothDevice?> showPrinterSelectionDialog(BuildContext context) async {
    final devices = await bluetoothPrinter.getBondedDevices();
    return showDialog<BluetoothDevice>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select a printer'),
        content: SizedBox(
          height: 300,
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: devices.length,
            itemBuilder: (_, index) {
              final device = devices[index];
              return ListTile(
                title: Text(device.name ?? 'Unknown'),
                subtitle: Text(device.address ?? 'N/A'),
                onTap: () => Navigator.of(context).pop(device),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<bool> ensureConnected(BuildContext context) async {
    try {
      bool connected = await bluetoothPrinter.isConnected ?? false;
      if (connected) return true;

      BluetoothDevice? device = await getSavedPrinter();

      // If not saved, ask user to pick one
      if (device == null) {
        device = await showPrinterSelectionDialog(context);
        if (device == null) {
          Fluttertoast.showToast(msg: "Printer selection cancelled");
          return false;
        }
        await saveSelectedPrinter(device.address!);
      }

      await bluetoothPrinter.connect(device);
      await Future.delayed(const Duration(seconds: 1));
      connected = await bluetoothPrinter.isConnected ?? false;

      if (!connected) {
        Fluttertoast.showToast(msg: "Failed to connect to printer");
      }

      return connected;
    } catch (e) {
      Fluttertoast.showToast(msg: "Connection error: $e");
      return false;
    }
  }

  Future<BluetoothDevice?> _selectPrinter(BuildContext context) async {
    try {
      List<BluetoothDevice> devices = await bluetoothPrinter.getBondedDevices();

      if (devices.isEmpty) {
        Fluttertoast.showToast(msg: "No paired Bluetooth devices found.");
        return null;
      }

      return await showDialog<BluetoothDevice>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Select Printer"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return ListTile(
                    title: Text(device.name ?? "Unknown"),
                    subtitle: Text(device.address ?? ""),
                    onTap: () => Navigator.pop(context, device),
                  );
                },
              ),
            ),
          );
        },
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Error fetching paired devices: $e");
      return null;
    }
  }

  Future<void> printReceipt(BuildContext context, Map<String, dynamic> table) async {
    try {
      // Check if printer is already saved
      BluetoothDevice? device = await getSavedPrinter();

      // If not saved, show selection dialog
      if (device == null) {
        device = await showPrinterSelectionDialog(context);
        if (device == null) return; // User cancelled
        await saveSelectedPrinter(device.address!); // Save selection
      }

      // Try to connect
      await bluetoothPrinter.connect(device);
      await Future.delayed(Duration(seconds: 1));

      final isConnected = await bluetoothPrinter.isConnected ?? false;
      if (!isConnected) {
        Fluttertoast.showToast(msg: "Failed to connect to printer.");
        return;
      }
      final orders = List<Map<String, dynamic>>.from(table['orders'] ?? []);
      final totalPrice = calculateTotalPrice(orders);
      final paymentMethod = table['paymentMethod'] ?? 'Cash';
      final dateTime = DateTime.now();
      final tableNumber = table['tableNumber'] ?? 'N/A';
      final orderStatus = table['orderStatus'] ?? 'N/A';

      bluetoothPrinter.printNewLine();

      // Header
      bluetoothPrinter.printCustom("       My Fine Dine", 3, 1);
      bluetoothPrinter.printCustom("Branch: $branchCode", 1, 1);
      bluetoothPrinter.printCustom("Date: ${dateTime.toLocal().toString().split('.').first}", 1, 1);
      bluetoothPrinter.printNewLine();

      // Order Info
      bluetoothPrinter.printCustom("Table No: $tableNumber", 1, 0);
      bluetoothPrinter.printCustom("Status: $orderStatus", 1, 0);
      bluetoothPrinter.printCustom("Payment: $paymentMethod", 1, 0);
      bluetoothPrinter.printNewLine();

      // Item list header
      bluetoothPrinter.printCustom("--------------------------------", 1, 1);
      bluetoothPrinter.printCustom("Item        Qty  Price  Total", 1, 0);
      bluetoothPrinter.printCustom("--------------------------------", 1, 1);

      for (var order in orders) {
        final name = (order['name'] ?? 'Unknown').toString().padRight(12).substring(0, 12);
        final quantity = int.tryParse(order['quantity'].toString()) ?? 0;
        final price = double.tryParse(order['price'].toString()) ?? 0.0;
        final lineTotal = (quantity * price).toStringAsFixed(2).padLeft(6);
        final qtyStr = quantity.toString().padLeft(3);
        final priceStr = price.toStringAsFixed(2).padLeft(6);

        final line = "$name $qtyStr $priceStr $lineTotal";
        bluetoothPrinter.printCustom(line, 1, 0);
      }

      bluetoothPrinter.printCustom("--------------------------------", 1, 1);

      // Totals
      final tax = totalPrice * 0.05;
      final discount = 0.0;
      final grandTotal = totalPrice + tax - discount;

      bluetoothPrinter.printCustom("Subtotal           ${totalPrice.toStringAsFixed(2)}", 1, 2);
      bluetoothPrinter.printCustom("Tax (5%)           ${tax.toStringAsFixed(2)}", 1, 2);
      if (discount > 0) {
        bluetoothPrinter.printCustom("Discount          -${discount.toStringAsFixed(2)}", 1, 2);
      }
      bluetoothPrinter.printCustom("Total              ${grandTotal.toStringAsFixed(2)}", 2, 2);
      bluetoothPrinter.printNewLine();

      // Footer
      bluetoothPrinter.printCustom("--------------------------------", 1, 1);
      bluetoothPrinter.printCustom("Thank you for dining with us!", 1, 1);
      bluetoothPrinter.printCustom("Feedback? 1800-123-456", 1, 1);
      bluetoothPrinter.printCustom("Visit again!", 1, 1);
      bluetoothPrinter.printCustom("--------------------------------", 1, 1);
      bluetoothPrinter.printNewLine();

      await bluetoothPrinter.disconnect();
    } catch (e) {
      Fluttertoast.showToast(msg: "Error printing receipt: $e");
    }
  }







  double calculateTotalPrice(List<dynamic> orders) {
    return orders.fold(0.0, (total, order) {
      return total + (order['price'] * order['quantity']);
    });
  }

  double calculateDiscountedPrice(double totalPrice, double discountPercentage) {
    double discountAmount = (totalPrice * discountPercentage) / 100;
    return totalPrice - discountAmount;
  }

  void openPaymentModal(Map<String, dynamic> table) {
    selectedTable = table;
    paymentMethod = '';
    paymentStatus = '';
    responsibleName = '';
    discountPercentage = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => _buildPaymentModal(),
    );
  }
  Future<void> updateIngredientQuantities(List<dynamic> orders) async {
    try {
      final Map<String, double> inventoryUpdates = {};

      for (var order in orders) {
        if (order['ingredients'] != null) {
          for (var ingredient in order['ingredients']) {
            final String ingredientName = ingredient['ingredientName'];
            final double quantityUsed =
                (double.tryParse(ingredient['quantityUsed'].toString()) ?? 0.0) *
                    (double.tryParse(order['quantity'].toString()) ?? 0.0);

            if (inventoryUpdates.containsKey(ingredientName)) {
              inventoryUpdates[ingredientName] =
                  inventoryUpdates[ingredientName]! + quantityUsed;
            } else {
              inventoryUpdates[ingredientName] = quantityUsed;
            }
          }
        }
      }

      for (final entry in inventoryUpdates.entries) {
        final ingredientName = entry.key;
        final quantityUsed = entry.value;

        final querySnapshot = await FirebaseFirestore.instance
            .collection('tables')
            .doc(branchCode)
            .collection('Inventory')
            .where('ingredientName', isEqualTo: ingredientName)
            .get();

        for (var doc in querySnapshot.docs) {
          final currentQuantity =
              (doc.data()['quantity'] as num?)?.toDouble() ?? 0.0;
          final updatedQuantity = currentQuantity - quantityUsed;

          await doc.reference.update({'quantity': updatedQuantity});
        }
      }
    } catch (e) {
      print('Error updating ingredient quantities: $e');
    }
  }
  Future<void> handleSavePayment() async {
    if (selectedTable != null && paymentMethod.isNotEmpty && paymentStatus.isNotEmpty) {
      try {
        final tableRef = _db
            .collection('tables')
            .doc(branchCode)
            .collection('tables')
            .doc(selectedTable!['id']);

        List<dynamic> updatedOrders = selectedTable!['orders'];
        double totalPrice = calculateTotalPrice(updatedOrders);
        double discountedPrice = calculateDiscountedPrice(totalPrice, discountPercentage);

        String updatedOrderStatus = '';
        if (paymentStatus == 'Settled') {
          updatedOrderStatus = 'Payment Successfully Settled';
          updatedOrders = [];
        } else if (paymentStatus == 'Due' && responsibleName.isNotEmpty) {
          updatedOrderStatus = 'Payment Due Successfully by $responsibleName';
          updatedOrders = [];
        } else {
          Fluttertoast.showToast(msg: "Please enter responsible person's name for due payments.");
          return;
        }

        await tableRef.update({
          'orders': [],
          'orderStatus': updatedOrderStatus,
        });

        await tableRef.collection('orders').add({
          'orders': selectedTable!['orders'],
          'payment': {
            'total': totalPrice,
            'discountedTotal': discountedPrice,
            'discountPercentage': discountPercentage,
            'status': paymentStatus,
            'method': paymentMethod,
            'responsible': paymentStatus == 'Due' ? responsibleName : null,
            'timestamp': DateTime.now(),
          },
          'orderStatus': updatedOrderStatus,
          'timestamp': DateTime.now(),
        });
        // ✅ Subtract ingredients from inventory
        await updateIngredientQuantities(selectedTable!['orders']);

        Fluttertoast.showToast(msg: "Payment details saved successfully.");
        Navigator.pop(context); // Close modal
        fetchTables();
      } catch (e) {
        print("Error saving payment: $e");
        Fluttertoast.showToast(msg: "Error saving payment.");
      }
    } else {
      Fluttertoast.showToast(msg: 'Select payment method and status');
    }
  }

  Widget _buildPaymentModal() {
    final orders = selectedTable?['orders'] ?? [];
    final totalPrice = calculateTotalPrice(orders);
    final discountedPrice = calculateDiscountedPrice(totalPrice, discountPercentage);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (context, modalSetState) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment for Table ${selectedTable!['tableNumber']}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
              ),
              SizedBox(height: 16),

              if (orders.isNotEmpty)
                Container(
                  height: 250,
                  child: ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      var order = orders[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: ListTile(
                          title: Text(order['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Qty: ${order['quantity']} x ₹${order['price']}'),
                          trailing: Text('₹${(order['quantity'] * order['price']).toStringAsFixed(2)}'),
                        ),
                      );
                    },
                  ),
                ),
              if (orders.isEmpty)
                Center(child: Text("No orders found", style: TextStyle(color: Colors.grey))),

              Divider(),
              Text('Total: ₹${totalPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 18)),
              Text('Discounted: ₹${discountedPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 18)),
              SizedBox(height: 12),

              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Discount %',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.discount),
                ),
                onChanged: (val) {
                  modalSetState(() {
                    discountPercentage = double.tryParse(val) ?? 0.0;
                  });
                },
              ),
              SizedBox(height: 16),

              Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 10,
                children: ['Cash', 'Card', 'UPI', 'Due'].map((method) {
                  return ChoiceChip(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Text(method),
                    ),
                    selected: paymentMethod == method,
                    selectedColor: Colors.teal.shade700,
                    labelStyle: TextStyle(
                      color: paymentMethod == method ? Colors.white : Colors.black,
                    ),
                    onSelected: (_) {
                      modalSetState(() => paymentMethod = method);
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 16),

              Text('Payment Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 10,
                children: ['Settled', 'Due'].map((status) {
                  return ChoiceChip(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Text(status),
                    ),
                    selected: paymentStatus == status,
                    selectedColor: Colors.teal.shade700,
                    labelStyle: TextStyle(
                      color: paymentStatus == status ? Colors.white : Colors.black,
                    ),
                    onSelected: (_) {
                      modalSetState(() => paymentStatus = status);
                    },
                  );
                }).toList(),
              ),

              if (paymentStatus == 'Due') ...[
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Responsible Person',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => modalSetState(() => responsibleName = val),
                ),
              ],

              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: handleSavePayment,
                      icon: Icon(Icons.save),
                      label: Text('Save Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),





              ElevatedButton.icon(
                onPressed: selectedTable != null
                    ? () => printReceipt(context, selectedTable!)
                    : null, // disable if no table selected
                icon: Icon(Icons.print),
                label: Text('Print Receipt'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.fromHeight(48),
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Billing'),
        backgroundColor: Colors.teal.shade700,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  /* your “Add New Table” logic */
                },
                child: Text('Add New Table'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),

            // <-- Real-time table list -->
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection('tables')
                      .doc(branchCode)
                      .collection('tables')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    // Map Firestore docs into your local table list
                    final docs = snapshot.data!.docs;
                    final tables = docs.map((d) {
                      final data = d.data()! as Map<String, dynamic>;
                      return {
                        'id': d.id,
                        ...data,
                        'orderStatus': data['orderStatus'] ?? 'Running Order',
                      };
                    }).toList();

                    return ListView.builder(
                      itemCount: tables.length,
                      itemBuilder: (context, index) {
                        final table = tables[index];
                        final totalPrice = calculateTotalPrice(table['orders']);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 350),
                              child: Card(
                                elevation: 6,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    // Await the push so you could do something afterwards if needed
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            MenuPage(tableId: table['id']),
                                      ),
                                    );
                                    // no need to fetchTables(); StreamBuilder will auto-update
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Icon(Icons.restaurant_menu,
                                            color: Colors.teal.shade700),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment
                                                .start,
                                            children: [
                                              Text(
                                                'Table ${table['tableNumber']}',
                                                style: TextStyle(fontSize: 18,
                                                    fontWeight: FontWeight
                                                        .bold),
                                              ),
                                              Text(
                                                '₹${totalPrice.toStringAsFixed(
                                                    2)}',
                                                style: TextStyle(fontSize: 16,
                                                    color: Colors.teal
                                                        .shade700),
                                              ),
                                              Text(
                                                'Status: ${table['orderStatus']}',
                                                style: TextStyle(
                                                    color: Colors.grey
                                                        .shade600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.arrow_drop_up,
                                              color: Colors.teal.shade700),
                                          onPressed: () =>
                                              openPaymentModal(table),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          /* your add-table */
        },
        backgroundColor: Colors.teal.shade700,
        child: Icon(Icons.add),
      ),
    );
  }}
