import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import'package:art/providers/user_provider.dart';
import 'package:provider/provider.dart';

class OrderReportScreen extends StatefulWidget {
  @override
  _OrderReportScreenState createState() => _OrderReportScreenState();
}

class _OrderReportScreenState extends State<OrderReportScreen> {
  List<Map<String, dynamic>> orderHistory = [];
  List<Map<String, dynamic>> filteredHistory = [];
  DateTime? fromDate;
  DateTime? toDate;
  String searchTerm = '';
  bool isLoading = true;
  late String branchCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      setState(() {
        branchCode = userProvider.branchCode!;
      });
    fetchOrderHistory();
    });
  }

  Future<void> fetchOrderHistory() async {
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
          for (var item in orderData['orders'] ?? []) {
            historyData.add({
              'name': item['name'] ?? '',
              'price': item['price'] ?? 0.0,
              'quantity': item['quantity'] ?? 0,
              'timestamp': orderData['timestamp'],
              'responsible': orderData['payment']['responsible'] ?? 'N/A',
            });
          }
        }
      }

      setState(() {
        orderHistory = historyData;
        filteredHistory = List.from(orderHistory);
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching order history: $e");
    }
  }

  void filterData() {
    setState(() {
      filteredHistory = orderHistory.where((entry) {
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
            !(entry['name'].toString().toLowerCase().contains(searchTerm.toLowerCase()) ||
                entry['responsible'].toString().toLowerCase().contains(searchTerm.toLowerCase()))) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  void clearFilters() {
    setState(() {
      fromDate = null;
      toDate = null;
      searchTerm = '';
    });
    filterData();
  }

  Future<void> exportCSV() async {
    List<List<String>> csvData = [
      ['Item', 'Price', 'Quantity', 'Total', 'Responsible', 'Time']
    ];

    for (var entry in filteredHistory) {
      DateTime entryDate = entry['timestamp'] is Timestamp
          ? entry['timestamp'].toDate()
          : DateTime.tryParse(entry['timestamp'].toString()) ?? DateTime.now();

      csvData.add([
        entry['name'],
        '₹${entry['price'].toStringAsFixed(2)}',
        '${entry['quantity']}',
        '₹${(entry['price'] * entry['quantity']).toStringAsFixed(2)}',
        entry['responsible'],
        DateFormat('yyyy-MM-dd HH:mm').format(entryDate),
      ]);
    }

    String csv = const ListToCsvConverter().convert(csvData);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/order_report_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV exported to ${file.path}')),
    );
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

  Map<String, List<Map<String, dynamic>>> groupByDate(List<Map<String, dynamic>> entries) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var entry in entries) {
      DateTime entryDate = entry['timestamp'] is Timestamp
          ? entry['timestamp'].toDate()
          : DateTime.tryParse(entry['timestamp'].toString()) ?? DateTime.now();
      String dateStr = DateFormat('yyyy-MM-dd').format(entryDate);
      grouped.putIfAbsent(dateStr, () => []).add(entry);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = Map.fromEntries(
      groupByDate(filteredHistory).entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key)) // Recent dates first
        ..forEach((entry) {
          entry.value.sort((a, b) {
            DateTime aDate;
            DateTime bDate;

            final aTs = a['timestamp'];
            final bTs = b['timestamp'];

            if (aTs is Timestamp) {
              aDate = aTs.toDate();
            } else if (aTs is String) {
              aDate = DateTime.tryParse(aTs) ?? DateTime(2000);
            } else {
              aDate = DateTime(2000);
            }

            if (bTs is Timestamp) {
              bDate = bTs.toDate();
            } else if (bTs is String) {
              bDate = DateTime.tryParse(bTs) ?? DateTime(2000);
            } else {
              bDate = DateTime(2000);
            }

            return bDate.compareTo(aDate); // Recent orders first
          });
        }),
    );


    return Animate(
      effects: [FadeEffect(duration: 600.ms), MoveEffect(begin: Offset(0, 30))],
      child: Scaffold(
        appBar: AppBar(
          title: Text('Order Report'),
          actions: [
            IconButton(icon: Icon(Icons.download), onPressed: exportCSV),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: clearFilters,
          icon: Icon(Icons.clear),
          label: Text("Clear Filters"),
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.date_range),
                    label: Text(fromDate == null
                        ? 'From Date'
                        : DateFormat('yyyy-MM-dd').format(fromDate!)),
                    onPressed: () => pickDate(context, true),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.date_range),
                    label: Text(toDate == null
                        ? 'To Date'
                        : DateFormat('yyyy-MM-dd').format(toDate!)),
                    onPressed: () => pickDate(context, false),
                  ),
                ),
              ]),
              SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search by item/responsible',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  searchTerm = val;
                  filterData();
                },
              ),
              SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: groupedData.length,
                  itemBuilder: (context, index) {
                    final dateKey = groupedData.keys.elementAt(index);
                    final entries = groupedData[dateKey]!;
                    final dayTotal = entries.fold<double>(
                      0.0,
                          (sum, entry) => sum + (entry['price'] * entry['quantity']),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, MMM d, yyyy').format(DateTime.parse(dateKey)),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 5),
                        ...entries.map((entry) {
                          final ts = entry['timestamp'];
                          DateTime time = ts is Timestamp
                              ? ts.toDate()
                              : DateTime.tryParse(ts.toString()) ?? DateTime.now();

                          return Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry['name'],
                                      style: TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w600)),
                                  SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Qty: ${entry['quantity']}'),
                                      Text('Price: ₹${entry['price'].toStringAsFixed(2)}'),
                                      Text('Total: ₹${(entry['price'] * entry['quantity']).toStringAsFixed(2)}'),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('By: ${entry['responsible']}',
                                          style: TextStyle(color: Colors.grey.shade700)),
                                      Text(DateFormat('hh:mm a').format(time),
                                          style: TextStyle(color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text('Subtotal: ₹${dayTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                        Divider(),
                      ],
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
