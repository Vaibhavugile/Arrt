import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

class BillingScreen extends StatefulWidget {
  @override
  _BillingScreenState createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String branchCode = '3333';
  List<Map<String, dynamic>> tables = [];
  bool showPaymentModal = false;
  Map<String, dynamic>? selectedTable;
  String paymentMethod = '';
  String paymentStatus = '';
  String responsibleName = '';
  double discountPercentage = 0.0;

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

  double calculateTotalPrice(List<dynamic> orders) {
    return orders.fold(0.0, (total, order) {
      return total + (order['price'] * order['quantity']);
    });
  }

  double calculateDiscountedPrice(double totalPrice, double discountPercentage) {
    double discountAmount = (totalPrice * discountPercentage) / 100;
    return totalPrice - discountAmount;
  }

  void handleOpenPaymentModal(Map<String, dynamic> table) {
    setState(() {
      selectedTable = table;
      showPaymentModal = true;
    });
  }

  void handleClosePaymentModal() {
    setState(() {
      showPaymentModal = false;
      selectedTable = null;
      paymentMethod = '';
      paymentStatus = '';
      responsibleName = '';
      discountPercentage = 0.0;
    });
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
          Fluttertoast.showToast(msg: "Please enter the responsible person's name for due payments.");
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

        Fluttertoast.showToast(msg: "Payment details saved successfully.");
        handleClosePaymentModal();
        fetchTables(); // Refresh tables
      } catch (e) {
        print("Error saving payment details: $e");
      }
    } else {
      Fluttertoast.showToast(msg: 'Please select a payment method and status');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Billing'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.add),
              label: Text('Add Table'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: GridView.builder(
                key: ValueKey<int>(tables.length),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                padding: EdgeInsets.all(12),
                itemCount: tables.length,
                itemBuilder: (context, index) {
                  var table = tables[index];
                  double totalPrice = calculateTotalPrice(table['orders']);
                  return GestureDetector(
                    onTap: () => handleOpenPaymentModal(table),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(2, 4),
                          )
                        ],
                        gradient: totalPrice > 0
                            ? LinearGradient(colors: [Colors.orange.shade200, Colors.orangeAccent])
                            : LinearGradient(colors: [Colors.white, Colors.grey.shade100]),
                      ),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.table_restaurant, size: 28, color: totalPrice > 0 ? Colors.white : Colors.blueAccent),
                              SizedBox(width: 8),
                              Text(
                                'Table: ${table['tableNumber']}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: totalPrice > 0 ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Total: ₹${totalPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: totalPrice > 0 ? Colors.white : Colors.black87,
                                ),
                              ),
                              SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () => handleOpenPaymentModal(table),
                                icon: Icon(Icons.payment),
                                label: Text('Pay'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (showPaymentModal && selectedTable != null) _buildPaymentModal(),
        ],
      ),
    );
  }

  Widget _buildPaymentModal() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Payment for Table ${selectedTable!['tableNumber']}',
                style: Theme.of(context).textTheme.headline6,
              ),
              SizedBox(height: 16),
              if (selectedTable!['orders'].isNotEmpty) ...[
                Text('Total Price: ₹${calculateTotalPrice(selectedTable!['orders']).toStringAsFixed(2)}'),
                SizedBox(height: 8),
                Text('Discounted Price: ₹${calculateDiscountedPrice(calculateTotalPrice(selectedTable!['orders']), discountPercentage).toStringAsFixed(2)}'),
                SizedBox(height: 16),
                Text('Order Summary:'),
                ...selectedTable!['orders'].map<Widget>((order) {
                  return Text('${order['quantity']} x ${order['name']} - ₹${(order['price'] * order['quantity']).toStringAsFixed(2)}');
                }).toList(),
                SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Discount Percentage',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                  onChanged: (value) => setState(() {
                    discountPercentage = double.tryParse(value) ?? 0.0;
                  }),
                ),
                SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment Method: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 10,
                      children: [
                        _buildPaymentMethodRadio('Cash'),
                        _buildPaymentMethodRadio('Card'),
                        _buildPaymentMethodRadio('UPI'),
                        _buildPaymentMethodRadio('Due'),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text('Payment Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 10,
                      children: [
                        _buildPaymentStatusRadio('Settled'),
                        _buildPaymentStatusRadio('Due'),
                      ],
                    ),
                  ],
                ),
                if (paymentStatus == 'Due')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Responsible Person',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.grey[200],
                      ),
                      onChanged: (value) => setState(() {
                        responsibleName = value;
                      }),
                    ),
                  ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: handleSavePayment,
                      child: Text('Save Payment'),
                      style: ElevatedButton.styleFrom(
                        primary: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: handleClosePaymentModal,
                      child: Text('Cancel'),
                      style: ElevatedButton.styleFrom(
                        primary: Colors.red,
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodRadio(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: paymentMethod,
          onChanged: (val) {
            setState(() {
              paymentMethod = val!;
            });
          },
        ),
        Text(value),
      ],
    );
  }

  Widget _buildPaymentStatusRadio(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: paymentStatus,
          onChanged: (val) {
            setState(() {
              paymentStatus = val!;
            });
          },
        ),
        Text(value),
      ],
    );
  }
}
