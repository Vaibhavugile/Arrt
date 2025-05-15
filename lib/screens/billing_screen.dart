import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:art/screens/MenuPage.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as serial;
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import 'package:art/screens/AddTable.dart';
import'package:art/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app.dart'; // Adjust path as needed if app.dart is in /lib


class BillingScreen extends StatefulWidget {
  @override
  _BillingScreenState createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late String branchCode;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      setState(() {
        branchCode = userProvider.branchCode!;
      });
    fetchTables();
    });
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
      builder: (dialogContext) => AlertDialog(
        title: Text('Select a printer'),
        content: SizedBox(
          height: 300,
          width: double.maxFinite,
          child: devices.isEmpty
              ? Center(child: Text("No paired printers found"))
              : ListView.builder(
            itemCount: devices.length,
            itemBuilder: (_, index) {
              final device = devices[index];
              return ListTile(
                title: Text(device.name ?? 'Unknown'),
                subtitle: Text(device.address ?? 'N/A'),
                onTap: () => Navigator.of(dialogContext).pop(device), // ✅ Use dialogContext here
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(), // ✅ Use dialogContext here too
            child: Text('Cancel'),
          ),
        ],
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
    final loc = AppLocalizations.of(context)!;

    if (selectedTable != null && paymentMethod.isNotEmpty && paymentStatus.isNotEmpty) {
      try {
        // 🔁 Convert localized strings to English before saving
        final englishPaymentMethod = {
          loc.cash: 'Cash',
          loc.card: 'Card',
          loc.upi: 'UPI',
          loc.due: 'Due',
        }[paymentMethod] ?? 'Cash';

        final englishPaymentStatus = {
          loc.settled: 'Settled',
          loc.due: 'Due',
        }[paymentStatus] ?? 'Settled';

        final tableRef = _db
            .collection('tables')
            .doc(branchCode)
            .collection('tables')
            .doc(selectedTable!['id']);

        List<dynamic> updatedOrders = selectedTable!['orders'];
        double totalPrice = calculateTotalPrice(updatedOrders);
        double discountedPrice = calculateDiscountedPrice(totalPrice, discountPercentage);

        String updatedOrderStatus = '';

        if (englishPaymentStatus == 'Settled') {
          updatedOrderStatus = 'Payment Successfully Settled';
          updatedOrders = [];
        } else if (englishPaymentStatus == 'Due' && responsibleName.isNotEmpty) {
          updatedOrderStatus = 'Payment Due Successfully by - $responsibleName';
          updatedOrders = [];
        } else {
          Fluttertoast.showToast(msg: loc.enterResponsibleName);
          return;
        }


        // 🔄 Clear table and set order status
        await tableRef.update({
          'orders': [],
          'orderStatus': updatedOrderStatus,
        });

        // ✅ Save payment with English values
        await tableRef.collection('orders').add({
          'orders': selectedTable!['orders'],
          'payment': {
            'total': totalPrice,
            'discountedTotal': discountedPrice,
            'discountPercentage': discountPercentage,
            'status': englishPaymentStatus, // English
            'method': englishPaymentMethod, // English
            'responsible': englishPaymentStatus == 'Due' ? responsibleName : null,
            'timestamp': DateTime.now(),
          },
          'orderStatus': updatedOrderStatus,
          'timestamp': DateTime.now(),
        });

        await updateIngredientQuantities(selectedTable!['orders']);

        Fluttertoast.showToast(msg: loc.paymentSaved);
        Navigator.pop(context); // Close modal
        fetchTables();
      } catch (e) {
        print("Error saving payment: $e");
        Fluttertoast.showToast(msg: loc.errorSavingPayment);
      }
    } else {
      Fluttertoast.showToast(msg: loc.selectPaymentMethodAndStatus);
    }
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
      backgroundColor: Colors.transparent,
      builder: (_) => _buildPaymentModal(),
    );
  }

  Widget _buildPaymentModal() {
    final loc = AppLocalizations.of(context)!;
    final orders = selectedTable?['orders'] ?? [];
    final totalPrice = calculateTotalPrice(orders);
    final discountedPrice = calculateDiscountedPrice(totalPrice, discountPercentage);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: Colors.white.withOpacity(0.92),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: StatefulBuilder(
                builder: (context, modalSetState) => ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      '${loc.payment} - ${loc.table} ${selectedTable?['tableNumber']}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF263238)),
                    ),
                    SizedBox(height: 16),

                    if (orders.isNotEmpty)
                      ...orders.map((order) => Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          title: Text(order['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${loc.qty}: ${order['quantity']} x ₹${order['price']}'),
                          trailing: Text(
                            '₹${(order['quantity'] * order['price']).toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      )),
                    if (orders.isEmpty)
                      Center(child: Text(loc.noOrdersFound, style: TextStyle(color: Colors.grey))),

                    Divider(height: 32, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${loc.total}:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text('₹${totalPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${loc.discounted}:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text('₹${discountedPrice.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 16, color: Colors.green.shade700)),
                      ],
                    ),
                    SizedBox(height: 20),

                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '${loc.discount} %',
                        prefixIcon: Icon(Icons.percent),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        modalSetState(() {
                          discountPercentage = double.tryParse(val) ?? 0.0;
                        });
                      },
                    ),
                    SizedBox(height: 24),

                    Text('${loc.paymentMethod}:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [loc.cash, loc.card, loc.upi, loc.due].map((method) {
                        return ChoiceChip(
                          label: Text(method),
                          selected: paymentMethod == method,
                          selectedColor: Color(0xFF1565C0),
                          backgroundColor: Color(0xFFE3F2FD),
                          labelStyle: TextStyle(
                            color: paymentMethod == method ? Colors.white : Colors.black87,
                          ),
                          onSelected: (_) {
                            modalSetState(() => paymentMethod = method);
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 20),

                    Text('${loc.paymentStatus}:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [loc.settled, loc.due].map((status) {
                        return ChoiceChip(
                          label: Text(status),
                          selected: paymentStatus == status,
                          selectedColor: status == loc.settled ? Color(0xFF2E7D32) : Color(0xFFF9A825),
                          backgroundColor: Colors.grey.shade200,
                          labelStyle: TextStyle(
                            color: paymentStatus == status ? Colors.white : Colors.black87,
                          ),
                          onSelected: (_) {
                            modalSetState(() => paymentStatus = status);
                          },
                        );
                      }).toList(),
                    ),

                    if (paymentStatus == loc.due) ...[
                      SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          labelText: loc.responsiblePerson,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) => modalSetState(() => responsibleName = val),
                      ),
                    ],

                    SizedBox(height: 28),
                    ElevatedButton.icon(
                    onPressed: handleSavePayment,

                      icon: Icon(Icons.save),
                      label: Text(loc.savePayment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: Size.fromHeight(50),
                        elevation: 4,
                      ),
                    ),
                    SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: selectedTable != null ? () => printReceipt(context, selectedTable!) : null,
                      icon: Icon(Icons.print),
                      label: Text(loc.printReceipt),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: Size.fromHeight(48),
                        elevation: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF4CB050),
        title: Text(
          'La Casa',
          style: TextStyle(color: Colors.white), // 👈 Makes text white
        ),
        iconTheme: IconThemeData(color: Colors.white), // optional: makes back icon white too
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 12),
              child: SizedBox(
                width: double.infinity,

              ),
            ),

            // Real-time table list
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

                    final docs = snapshot.data!.docs;
                    final tables = docs.map((d) {
                      final data = d.data()! as Map<String, dynamic>;
                      return {
                        'id': d.id,
                        ...data,
                        'orderStatus': data['orderStatus'] ?? 'Running Order',
                      };
                    }).toList();

                    if (tables.isEmpty) {
                      return Center(
                        child: Text(
                          "No tables available.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: tables.length,
                      itemBuilder: (context, index) {
                        final table = tables[index];
                        final totalPrice = calculateTotalPrice(table['orders']);
                        final hasOrders = (table['orders'] as List?)?.isNotEmpty ?? false;

                        return Container(
                          decoration: BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: hasOrders ? Colors.red.shade400 : Colors.green.shade400,
                              width: 1,
                            ),

                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MenuPage(tableId: table['id']),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.table_restaurant, size: 20, color: Color(0xFF455A64)),
                                    SizedBox(height: 8),
                                    Text(
                                      ' ${table['tableNumber']}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF333333),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    Spacer(),
                                    SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => openPaymentModal(table),
                                        style: ElevatedButton.styleFrom(
                                          elevation: 3,
                                          backgroundColor: Color(0xFF4CB050),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.payment, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Pay ₹${totalPrice.toStringAsFixed(2)}',
                                              style: TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTable()),
          );
        },
        backgroundColor: Color(0xFF4CB050),
        child: Icon(Icons.add),
      ),
    );
  }
}
