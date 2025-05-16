import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import the generated file
import 'package:art/providers/user_provider.dart'; // 👈 adjust the path


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
  late AppLocalizations? _localization; // Add this line

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      setState(() {
        branchCode = userProvider.branchCode!;
        _localization = AppLocalizations.of(context); // Initialize here
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
      if (mounted) { // Check if the widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')), // Show error to user
        );
      }
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

  Future<void> exportOrderPDF(BuildContext context, List<dynamic> filteredHistory) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_localization?.paymentReportTitle ?? 'Order Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: [
                  _localization?.table ?? 'Item',
                  _localization?.price ?? 'Price',
                  _localization?.status ?? 'Qty',
                  'Total',
                  _localization?.responsible ?? 'Responsible',
                  _localization?.time ?? 'Time'
                ],
                data: filteredHistory.map((entry) {
                  DateTime entryDate = entry['timestamp'] is Timestamp
                      ? entry['timestamp'].toDate()
                      : DateTime.tryParse(entry['timestamp'].toString()) ?? DateTime.now();

                  final price = double.tryParse(entry['price'].toString()) ?? 0;
                  final quantity = int.tryParse(entry['quantity'].toString()) ?? 0;
                  final total = price * quantity;

                  return [
                    entry['name'].toString(),
                    '₹${price.toStringAsFixed(2)}',
                    quantity.toString(),
                    '₹${total.toStringAsFixed(2)}',
                    entry['responsible'].toString(),
                    DateFormat('yyyy-MM-dd HH:mm').format(entryDate),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
              )
            ],
          );
        },
      ),
    );

    try {
      final outputDir = await getTemporaryDirectory();
      final file = File('${outputDir.path}/order_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_localization?.failedToOpenPdf ?? 'Failed to open PDF'}: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
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
    // Initialize _localization here as well, to ensure it's always available.
    _localization = AppLocalizations.of(context);
    if (_localization == null) {
      // Handle the case where _localization is null, although it should not happen.
      return const Center(child: Text("Localization not loaded!")); // Or a loading indicator.
    }

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
          title: Text(
            _localization?.orderReport ?? 'Order Report',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF4CB050),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => exportOrderPDF(context, filteredHistory)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: clearFilters,
          icon: const Icon(Icons.clear),
          label: Text(_localization?.clearFilters ?? "Clear Filters"),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(fromDate == null
                        ? _localization?.fromDate ?? 'From Date'
                        : DateFormat('yyyy-MM-dd').format(fromDate!)),
                    onPressed: () => pickDate(context, true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(toDate == null
                        ? _localization?.toDate ?? 'To Date'
                        : DateFormat('yyyy-MM-dd').format(toDate!)),
                    onPressed: () => pickDate(context, false),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: _localization?.search ?? 'Search by item/responsible',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (val) {
                  searchTerm = val;
                  filterData();
                },
              ),
              const SizedBox(height: 20),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMM d, y').format(DateTime.parse(dateKey)),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Subtotal: ₹${dayTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 5),
                          ],
                        ),

                        const SizedBox(height: 5),
                        ...entries.map((entry) {
                          final ts = entry['timestamp'];
                          DateTime time = ts is Timestamp
                              ? ts.toDate()
                              : DateTime.tryParse(ts.toString()) ?? DateTime.now();

                          return Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry['name'],
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Positional args, not named:
                                      Text(
                                        AppLocalizations.of(context)!.quantity(
                                          entry['quantity'].toString(),
                                          entry['price'].toStringAsFixed(2),
                                        ),
                                      ),
                                      Text(
                                        '${AppLocalizations.of(context)!.total}: ₹${(entry['price'] * entry['quantity']).toStringAsFixed(2)}',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${AppLocalizations.of(context)!.by}: ${entry['responsible']}',
                                        style: TextStyle(color: Colors.grey.shade700),
                                      ),
                                      Text(
                                        DateFormat('hh:mm a').format(time),
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),

                        const Divider(),
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

