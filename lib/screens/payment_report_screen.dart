import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import'package:art/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:typed_data';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';

class PaymentReportScreen extends StatefulWidget {
  @override
  _PaymentReportScreenState createState() => _PaymentReportScreenState();
}

class _PaymentReportScreenState extends State<PaymentReportScreen> {
  List<Map<String, dynamic>> paymentHistory = [];
  List<Map<String, dynamic>> filteredHistory = [];
  late String branchCode;
  DateTime? fromDate;
  DateTime? toDate;
  String searchTerm = '';
  bool isLoading = true;

  String? selectedMethod;
  String? selectedStatus;
  String? selectedResponsible;
  int currentPage = 0;
  int itemsPerPage = 10;

  List<Map<String, dynamic>> paginatedData = [];

  Map<String, List<Map<String, dynamic>>> groupedData = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      setState(() {
        branchCode = userProvider.branchCode!;
      });
      fetchPaymentHistory();
    });
  }

  Future<void> fetchPaymentHistory() async {
    try {
      final tablesRef = FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('tables');

      final tablesSnapshot = await tablesRef.get();
      List<Map<String, dynamic>> historyData = [];

      for (var tableDoc in tablesSnapshot.docs) {
        final tableData = tableDoc.data();
        final tableId = tableDoc.id;

        final ordersRef = tablesRef.doc(tableId).collection('orders');
        final ordersSnapshot = await ordersRef.get();

        for (var orderDoc in ordersSnapshot.docs) {
          final orderData = orderDoc.data();
          final payment = orderData['payment'] ?? {};

          historyData.add({
            'tableNumber': tableData['tableNumber'] ?? 'N/A',
            'method': payment['method'] ?? 'N/A',
            'status': payment['status'] ?? 'N/A',
            'responsible': payment['responsible'] ?? 'N/A',
            'discountedTotal': payment['discountedTotal'] ?? 0.0,
            'total': payment['total'] ?? 0.0,
            'timestamp': orderData['timestamp'],
            'orders': orderData['orders'] ?? [],
          });
        }
      }
      historyData.sort((a, b) {
        final aTimeRaw = a['timestamp'];
        final bTimeRaw = b['timestamp'];

        DateTime aTime;
        DateTime bTime;

        if (aTimeRaw is Timestamp) {
          aTime = aTimeRaw.toDate();
        } else if (aTimeRaw is String) {
          aTime = DateTime.tryParse(aTimeRaw) ?? DateTime(2000);
        } else {
          aTime = DateTime(2000);
        }

        if (bTimeRaw is Timestamp) {
          bTime = bTimeRaw.toDate();
        } else if (bTimeRaw is String) {
          bTime = DateTime.tryParse(bTimeRaw) ?? DateTime(2000);
        } else {
          bTime = DateTime(2000);
        }

        return bTime.compareTo(aTime);
      });


      setState(() {
        paymentHistory = historyData;
        filteredHistory = List.from(paymentHistory);
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching payment history: $e");
    }
  }

  void filterData() {
    setState(() {
      filteredHistory = paymentHistory.where((entry) {
        DateTime entryDate;
        final ts = entry['timestamp'];
        if (ts is Timestamp) {
          entryDate = ts.toDate();
        } else if (ts is String) {
          entryDate = DateTime.tryParse(ts) ?? DateTime(2000);
        } else {
          return false;
        }

        if (fromDate != null && entryDate.isBefore(fromDate!)) return false;
        if (toDate != null && entryDate.isAfter(toDate!)) return false;

        if (searchTerm.isNotEmpty &&
            !(entry['tableNumber'].toString().contains(searchTerm) ||
                entry['method'].toString().toLowerCase().contains(searchTerm.toLowerCase()) ||
                entry['status'].toString().toLowerCase().contains(searchTerm.toLowerCase()) ||
                entry['responsible'].toString().toLowerCase().contains(searchTerm.toLowerCase()))) {
          return false;
        }

        if (selectedMethod != null && entry['method'] != selectedMethod) return false;
        if (selectedStatus != null && entry['status'] != selectedStatus) return false;
        if (selectedResponsible != null && entry['responsible'] != selectedResponsible) return false;

        return true;
      }).toList();
      DateTime _parseDate(dynamic ts) {
        if (ts is Timestamp) return ts.toDate();
        if (ts is String) return DateTime.tryParse(ts) ?? DateTime(2000);
        return DateTime(2000);
      }
      filteredHistory.sort((a, b) {
        final aTime = _parseDate(a['timestamp']);
        final bTime = _parseDate(b['timestamp']);
        return bTime.compareTo(aTime); // Descending
      });

    });
    // Group filtered data by day
    groupedData = {};
    for (var entry in filteredHistory) {
      final timestamp = entry['timestamp'];
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.tryParse(timestamp) ?? DateTime(2000);
      } else {
        continue;
      }

      final dateKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      if (!groupedData.containsKey(dateKey)) {
        groupedData[dateKey] = [];
      }
      groupedData[dateKey]!.add(entry);
    }

// Flatten groupedData for pagination
    final flatList = groupedData.entries
        .expand((entry) => entry.value.map((e) => {'dateKey': entry.key, ...e}))
        .toList();

// Apply pagination
    int start = currentPage * itemsPerPage;
    int end = start + itemsPerPage;
    if (start >= flatList.length) start = 0; // Reset if out of range

    paginatedData = flatList.sublist(
      start,
      end > flatList.length ? flatList.length : end,
    );

  }


  void clearFilters() {
    setState(() {
      fromDate = null;
      toDate = null;
      searchTerm = '';
      selectedMethod = null;
      selectedStatus = null;
      selectedResponsible = null;
    });
    filterData();
  }

  void showOrders(List<dynamic> orders) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return ListTile(
              title: Text('${order['quantity']} x ${order['name']}'),
              trailing: Text('₹${(order['price'] * order['quantity']).toStringAsFixed(2)}'),
            );
          },
        );
      },
    );
  }
  Future<void> markAsSettled(Map<String, dynamic> entry) async {
    String selectedMethod = ''; // Default value
    List<String> paymentMethods = ['Cash', 'Card', 'UPI'];

    // Show a dialog to let the user choose the payment method
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Choose Payment Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: paymentMethods.map((method) {
              return RadioListTile<String>(
                title: Text(method),
                value: method,
                groupValue: selectedMethod,
                onChanged: (value) {
                  setState(() {
                    selectedMethod = value ?? '';
                  });
                  Navigator.pop(context, selectedMethod);
                },
              );
            }).toList(),
          ),
        );
      },
    ).then((value) {
      if (value != null) {
        selectedMethod = value;
        // Proceed with updating the payment method to selectedMethod
        _updatePaymentMethod(entry, selectedMethod);
      }
    });
  }
  Future<void> _updatePaymentMethod(Map<String, dynamic> entry, String selectedMethod) async {
    try {
      final tableNumber = entry['tableNumber'];
      final timestamp = entry['timestamp'];

      final tablesRef = FirebaseFirestore.instance
          .collection('tables')
          .doc(branchCode)
          .collection('tables');

      final tablesSnapshot = await tablesRef
          .where('tableNumber', isEqualTo: tableNumber)
          .get();

      if (tablesSnapshot.docs.isNotEmpty) {
        final tableDoc = tablesSnapshot.docs.first;

        final ordersRef = tableDoc.reference.collection('orders');
        final ordersSnapshot = await ordersRef
            .where('timestamp', isEqualTo: timestamp)
            .get();

        if (ordersSnapshot.docs.isNotEmpty) {
          final orderDoc = ordersSnapshot.docs.first;
          await orderDoc.reference.update({
            'payment.method': selectedMethod,
            'payment.status': 'Paid', // Optionally set the status to Paid
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Marked as Settled with $selectedMethod')),
          );

          fetchPaymentHistory(); // refresh the list
        }
      }
    } catch (e) {
      print('Error updating payment method: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update payment method')),
      );
    }
  }


  Future<bool> requestStoragePermission(BuildContext context) async {
    if (Platform.isAndroid) {
      // Android 10 and below
      if (await Permission.storage.request().isGranted) return true;

      // Android 11+ requires manual settings navigation
      if (await Permission.manageExternalStorage.isGranted) return true;

      var status = await Permission.manageExternalStorage.request();

      if (status.isGranted) {
        return true;
      } else {
        // Show snackbar with link to settings
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Storage permission is required to export the CSV file.'),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: () {
                openAppSettings(); // Opens app settings page
              },
            ),
          ),
        );
        return false;
      }
    } else {
      // iOS/macOS
      return true;
    }
  }

  Future<void> exportPDF(BuildContext context, List<dynamic> filteredHistory) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Payment Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ['Table', 'Total', 'Discounted', 'Method', 'Status', 'Responsible', 'Time'],
                data: filteredHistory.map((entry) {
                  DateTime entryDate = entry['timestamp'] is Timestamp
                      ? entry['timestamp'].toDate()
                      : DateTime.tryParse(entry['timestamp'].toString()) ?? DateTime.now();

                  return [
                    entry['tableNumber'].toString(),
                    '${entry['total'].toStringAsFixed(2)}',
                    '${entry['discountedTotal'].toStringAsFixed(2)}',
                    entry['method'].toString(),
                    entry['status'].toString(),
                    entry['responsible'].toString(),
                    DateFormat('yyyy-MM-dd HH:mm').format(entryDate),
                  ];
                }).toList(),
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              )
            ],
          );
        },
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final file = File('${outputDir.path}/payment_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    // Open the PDF directly
    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open PDF: ${result.message}')),
      );
    }
  }





  Future<void> pickDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (fromDate ?? DateTime.now()) : (toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) fromDate = picked;
        if (!isFrom) toDate = picked;
        filterData();
      });
    }
  }

  Map<String, double> calculateTotals(List<Map<String, dynamic>> data) {
    final totals = {'Cash': 0.0, 'Card': 0.0, 'UPI': 0.0, 'Due': 0.0};

    for (var entry in data) {
      final amount = (entry['discountedTotal'] ?? entry['total'] ?? 0.0).toDouble();
      final method = (entry['method'] ?? '').toString().toLowerCase();

      if (method == 'cash') {
        totals['Cash'] = totals['Cash']! + amount;
      } else if (method == 'card') {
        totals['Card'] = totals['Card']! + amount;
      } else if (method == 'upi' || method == 'online') {
        totals['UPI'] = totals['UPI']! + amount;
      } else if (method == 'due') {
        totals['Due'] = totals['Due']! + amount;
      }
    }

    return totals;
  }

  Widget _buildTotalCard(IconData icon, String label, double value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: Theme.of(context).primaryColor),
            SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('₹${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = calculateTotals(filteredHistory);

    List<String> methods = paymentHistory.map((e) => e['method'].toString()).toSet().toList();
    List<String> statuses = paymentHistory.map((e) => e['status'].toString()).toSet().toList();
    List<String> responsibles = paymentHistory.map((e) => e['responsible'].toString()).toSet().toList();

    return Animate(
      effects: [FadeEffect(duration: 600.ms), MoveEffect(begin: Offset(0, 30))],
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Payment Report',
            style: TextStyle(color: Colors.white), // 👈 Makes text white
          ),
          backgroundColor: Color(0xFF4CB050),
          iconTheme: IconThemeData(color: Colors.white),
          actions: [
            IconButton(icon: Icon(Icons.download_rounded), onPressed: () {
              exportPDF(context, filteredHistory);
            },),
          ],
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filters Section
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Filter Payments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.date_range),
                              onPressed: () => pickDate(context, true),
                            ),
                            Text(fromDate == null ? 'From Date' : DateFormat.yMd().format(fromDate!)),
                            SizedBox(width: 16),
                            IconButton(
                              icon: Icon(Icons.date_range),
                              onPressed: () => pickDate(context, false),
                            ),
                            Text(toDate == null ? 'To Date' : DateFormat.yMd().format(toDate!)),
                          ],
                        ),
                        SizedBox(height: 16),
                        TextField(
                          decoration: InputDecoration(labelText: 'Search', border: OutlineInputBorder()),
                          onChanged: (value) {
                            setState(() {
                              searchTerm = value;
                              filterData();
                            });
                          },
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButton<String>(
                                value: methods.contains(selectedMethod) ? selectedMethod : null,
                                hint: Text('Method'),
                                isExpanded: true,
                                items: methods.map((method) {
                                  return DropdownMenuItem<String>(
                                    value: method,
                                    child: Text(method),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedMethod = value;
                                    filterData();
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: DropdownButton<String>(
                                value: statuses.contains(selectedStatus) ? selectedStatus : null,
                                hint: Text('Status'),
                                isExpanded: true,
                                items: statuses.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedStatus = value;
                                    filterData();
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: DropdownButton<String>(
                                value: responsibles.contains(selectedResponsible) ? selectedResponsible : null,
                                hint: Text('Responsible'),
                                isExpanded: true,
                                items: responsibles.map((responsible) {
                                  return DropdownMenuItem<String>(
                                    value: responsible,
                                    child: Text(responsible),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedResponsible = value;
                                    filterData();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),


                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: clearFilters,
                          icon: Icon(Icons.clear_all),
                          label: Text('Clear Filters'),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // Total Cards
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildTotalCard(Icons.money, 'Cash', totals['Cash']!)),
                        SizedBox(width: 16),
                        Expanded(child: _buildTotalCard(Icons.credit_card, 'Card', totals['Card']!)),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTotalCard(Icons.account_balance_wallet, 'UPI', totals['UPI']!)),
                        SizedBox(width: 16),
                        Expanded(child: _buildTotalCard(Icons.access_time, 'Due', totals['Due']!)),
                      ],
                    ),
                  ],
                ),



                SizedBox(height: 16),
                // Payment History List
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: filteredHistory.length,
                  itemBuilder: (context, index) {
                    final entry = filteredHistory[index];

                    // Timestamp parsing
                    final timestampValue = entry['timestamp'];
                    String timestamp = 'Not Available';

                    if (timestampValue != null) {
                      DateTime dateTime;

                      if (timestampValue is Timestamp) {
                        dateTime = timestampValue.toDate();
                      } else if (timestampValue is String) {
                        dateTime = DateTime.tryParse(timestampValue) ?? DateTime(2000);
                      } else if (timestampValue is DateTime) {
                        dateTime = timestampValue;
                      } else {
                        dateTime = DateTime(2000);
                      }

                      timestamp = DateFormat('yyyy-MM-dd hh:mm a').format(dateTime);
                    }

                    return Animate(
                      effects: [
                        FadeEffect(duration: 600.ms),
                        MoveEffect(begin: Offset(0, 20))
                      ],
                      child: GestureDetector(
                        onTap: () => showOrders(entry['orders']),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          margin: EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left side: table info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Table ${entry['tableNumber']}',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '${entry['method']} | ${entry['status']} | ${entry['responsible']}',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Time: $timestamp',
                                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                                      ),
                                    ],
                                  ),
                                ),
                                // Right side: amount + action button
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('₹${entry['total']}'),
                                    if (entry['method'].toString().toLowerCase() == 'due')
                                      TextButton(
                                        onPressed: () => markAsSettled(entry),
                                        child: Text('Mark as Settled'),
                                        style: TextButton.styleFrom(foregroundColor: Colors.green),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                  },
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
