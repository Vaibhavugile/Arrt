import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import for localization
import '../app.dart'; // Import for setting locale
import 'package:art/providers/user_provider.dart'; // 👈 adjust the path


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

  bool isDarkMode = false; // Added for theme toggle

  // Theme Colors (consistent with inventory_screen for web styling)
  final Color appBarGradientStart = Color(0xFFE0FFFF); // Muted light blue
  final Color appBarGradientMid = Color(0xFFBFEBFA); // Steel Blue
  final Color appBarGradientEnd = Color(0xFF87CEEB); // Dark Indigo

  // Refined card and text colors for better "simple standard" look
  final Color lightModeCardBackground = Colors.white; // Changed from lightModeCardSolidColor
  final Color darkModeCardBackground = Colors.grey[800]!; // Dark mode card background
  final Color lightModeTextColor = Colors.black87; // Primary text color for light mode
  final Color darkModeTextColor = Colors.white70; // Primary text color for dark mode
  final Color lightModeIconColor = Colors.black87; // Icon color for light mode
  final Color darkModeIconColor = Color(0xFF9AC0C6); // Icon color for dark mode

  final Color webContentBackgroundLight = Colors.white;
  final Color webContentBackgroundDark = Colors.grey[900]!;


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

      final dateKey =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

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
    final S = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          color: isDarkMode ? webContentBackgroundDark : webContentBackgroundLight,
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                title: Text('${order['quantity']} x ${order['name']}', style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
                trailing: Text('₹${(order['price'] * order['quantity']).toStringAsFixed(2)}', style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> markAsSettled(Map<String, dynamic> entry) async {
    String selectedMethod = ''; // Default value
    List<String> paymentMethods = ['Cash', 'Card', 'UPI'];
    final S = AppLocalizations.of(context)!;

    // Show a dialog to let the user choose the payment method
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? darkModeCardBackground : lightModeCardBackground,
          title: Text(S.choosePaymentMethod, style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: paymentMethods.map((method) {
              return RadioListTile<String>(
                title: Text(method, style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
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
            'payment.status': 'Settled', // Optionally set the status to Paid
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
  String localizeMethod(String method, AppLocalizations S) {
    switch (method.toLowerCase()) {
      case 'cash':
        return S.cash;
      case 'card':
        return S.card;
      case 'upi':
        return S.upi;
      case 'online':
        return S.online;
      case 'due':
        return S.due;
      default:
        return method;
    }
  }

  String localizeStatus(String status, AppLocalizations S) {
    switch (status.toLowerCase()) {

      case 'settled':
        return S.settled;
      case 'due':
        return S.due;
      default:
        return status;
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
        final S = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.storagePermissionRequired),
            action: SnackBarAction(
              label: S.openSettings,
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
    final S = AppLocalizations.of(context)!;

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(S.paymentReportTitle, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: [
                  S.table,
                  S.total,
                  S.discounted,
                  S.method,
                  S.status,
                  S.responsible,
                  S.time
                ],
                data: filteredHistory.map((entry) {
                  DateTime entryDate = entry['timestamp'] is Timestamp
                      ? entry['timestamp'].toDate()
                      : DateTime.tryParse(entry['timestamp'].toString()) ??
                      DateTime.now();

                  return [
                    entry['tableNumber'].toString(),
                    '₹${entry['total'].toStringAsFixed(2)}',
                    '₹${entry['discountedTotal'].toStringAsFixed(2)}',
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
    final file =
    File('${outputDir.path}/payment_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    // Open the PDF directly
    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${S.failedToOpenPdf}: ${result.message}')),
      );
    }
  }

  Future<void> pickDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
      isFrom ? (fromDate ?? DateTime.now()) : (toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: isDarkMode ? ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: appBarGradientEnd, // Your primary color for dark mode pickers
              onPrimary: Colors.white,
              surface: darkModeCardBackground, // Use refined card background
              onSurface: darkModeTextColor,
            ),
            dialogBackgroundColor: darkModeCardBackground, // Use refined card background
          ) : ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: appBarGradientEnd, // Your primary color for light mode pickers
              onPrimary: Colors.white,
              surface: lightModeCardBackground, // Use refined card background
              onSurface: lightModeTextColor,
            ),
            dialogBackgroundColor: lightModeCardBackground, // Use refined card background
          ),
          child: child!,
        );
      },
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
      final amount =
      (entry['discountedTotal'] ?? entry['total'] ?? 0.0).toDouble();
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
      color: isDarkMode ? darkModeCardBackground : lightModeCardBackground, // Use refined card background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: isDarkMode ? darkModeIconColor : Theme.of(context).primaryColor),
            SizedBox(height: 8),
            Text(label,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
            Text('₹${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = calculateTotals(filteredHistory);
    final S = AppLocalizations.of(context)!;

    List<String> methods =
    paymentHistory.map((e) => e['method'].toString()).toSet().toList();
    List<String> statuses =
    paymentHistory.map((e) => e['status'].toString()).toSet().toList();
    List<String> responsibles =
    paymentHistory.map((e) => e['responsible'].toString()).toSet().toList();

    return Animate(
      effects: [FadeEffect(duration: 600.ms), MoveEffect(begin: Offset(0, 30))],
      child: Scaffold(
        backgroundColor: isDarkMode ? webContentBackgroundDark : webContentBackgroundLight,
        appBar: AppBar(
          title: Text(
            S.paymentReportTitle,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black87),
          actions: [
            IconButton(
              icon: Icon(
                isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              onPressed: () {
                setState(() {
                  isDarkMode = !isDarkMode;
                });
              },
              tooltip: S.toggleTheme,
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded),
              color: isDarkMode ? Colors.white : Colors.black87,
              onPressed: () {
                exportPDF(context, filteredHistory);
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.language, color: isDarkMode ? Colors.white : Colors.black87),
              onSelected: (value) {
                switch (value) { // Use switch for better readability
                  case 'en':
                    MyApp.setLocale(context, const Locale('en'));
                    break;
                  case 'hi':
                    MyApp.setLocale(context, const Locale('hi'));
                    break;
                  case 'mr':
                    MyApp.setLocale(context, const Locale('mr'));
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(value: 'en', child: Text('English')),
                const PopupMenuItem(value: 'hi', child: Text('हिंदी')),
                const PopupMenuItem(value: 'mr', child: Text('मराठी')), // ✅ New
              ],
            ),
          ],
          flexibleSpace: isDarkMode
              ? Container(
            color: Colors.grey[850],
          )
              : Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  appBarGradientStart,
                  appBarGradientMid,
                  appBarGradientEnd,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(appBarGradientEnd)))
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filters Section
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  color: isDarkMode ? darkModeCardBackground : lightModeCardBackground, // Use refined card background
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.filterPayments,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.date_range, color: isDarkMode ? darkModeIconColor : lightModeIconColor),
                              onPressed: () => pickDate(context, true),
                            ),
                            Text(fromDate == null
                                ? S.fromDate
                                : DateFormat.yMd().format(fromDate!), style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: Icon(Icons.date_range, color: isDarkMode ? darkModeIconColor : lightModeIconColor),
                              onPressed: () => pickDate(context, false),
                            ),
                            Text(toDate == null
                                ? S.toDate
                                : DateFormat.yMd().format(toDate!), style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search, color: isDarkMode ? darkModeIconColor : lightModeIconColor),
                            labelText: S.search,
                            labelStyle: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: isDarkMode ? darkModeIconColor : Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: isDarkMode ? appBarGradientEnd : appBarGradientMid),
                            ),
                          ),
                          style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor),
                          onChanged: (value) {
                            setState(() {
                              searchTerm = value;
                              filterData();
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButton<String>(
                                value: methods.contains(selectedMethod) ? selectedMethod : null,
                                hint: Text(S.method, style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
                                isExpanded: true,
                                dropdownColor: isDarkMode ? darkModeCardBackground : lightModeCardBackground, // Use refined card background
                                style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor),
                                items: methods.map((method) {
                                  String localizedMethod;
                                  switch (method.toLowerCase()) {
                                    case 'cash':
                                      localizedMethod = S.cash;
                                      break;
                                    case 'card':
                                      localizedMethod = S.card;
                                      break;
                                    case 'upi':
                                      localizedMethod = S.upi;
                                      break;
                                    case 'due':
                                      localizedMethod = S.due;
                                      break;
                                    default:
                                      localizedMethod = method;
                                  }
                                  return DropdownMenuItem<String>(
                                    value: method,
                                    child: Text(localizedMethod),
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
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButton<String>(
                                value: statuses.contains(selectedStatus) ? selectedStatus : null,
                                hint: Text(S.status, style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
                                isExpanded: true,
                                dropdownColor: isDarkMode ? darkModeCardBackground : lightModeCardBackground, // Use refined card background
                                style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor),
                                items: statuses.map((status) {
                                  String localizedStatus;
                                  switch (status.toLowerCase()) {
                                    case 'settled':
                                      localizedStatus = S.settled;
                                      break;
                                    case 'due':
                                      localizedStatus = S.due;
                                      break;
                                    default:
                                      localizedStatus = status;
                                  }
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(localizedStatus),
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
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButton<String>(
                                value: responsibles.contains(
                                    selectedResponsible)
                                    ? selectedResponsible
                                    : null,
                                hint: Text(S.responsible, style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
                                isExpanded: true,
                                dropdownColor: isDarkMode ? darkModeCardBackground : lightModeCardBackground, // Use refined card background
                                style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor),
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
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: clearFilters,
                          icon: Icon(Icons.clear_all, color: isDarkMode ? Colors.white : Colors.black87),
                          label: Text(S.clearFilters, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode ? appBarGradientEnd : appBarGradientMid,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Total Cards
                Column(

                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTotalCard(
                            Icons.money,
                            S.cash, // Translated label
                            totals['Cash']!,     // Fixed key
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTotalCard(
                            Icons.credit_card,
                            S.card,
                            totals['Card']!,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTotalCard(
                            Icons.account_balance_wallet,
                            S.upi,
                            totals['UPI']!,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTotalCard(
                            Icons.access_time,
                            S.due,
                            totals['Due']!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                // Payment History List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredHistory.length,
                  itemBuilder: (context, index) {
                    final entry = filteredHistory[index];

                    // Timestamp parsing
                    final timestampValue = entry['timestamp'];
                    String timestamp = S.notAvailable;

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

                    // Get localized values
                    final method = localizeMethod(entry['method'] ?? '', S);
                    final status = localizeStatus(entry['status'] ?? '', S);
                    final responsible = entry['responsible'] ?? S.notAvailable;

                    return Animate(
                      effects: [
                        FadeEffect(duration: 600.ms),
                        MoveEffect(begin: const Offset(0, 20))
                      ],
                      child: GestureDetector(
                        onTap: () => showOrders(entry['orders']),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: isDarkMode ? darkModeCardBackground : lightModeCardBackground, // Use refined card background
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
                                        '${S.table} ${entry['tableNumber'] ?? '-'}',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? darkModeTextColor : lightModeTextColor),
                                      ),
                                      Text(
                                        '$method | $status | $responsible',
                                        style: TextStyle(color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${S.time}: $timestamp',
                                        style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey.shade500 : Colors.blueGrey),
                                      ),
                                    ],
                                  ),
                                ),

                                // Right side: amount + action button
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('₹${entry['total'] ?? '0.0'}', style: TextStyle(color: isDarkMode ? darkModeTextColor : lightModeTextColor)),
                                    if ((entry['method'] ?? '').toString().toLowerCase() == 'due')
                                      TextButton(
                                        onPressed: () => markAsSettled(entry),
                                        style: TextButton.styleFrom(foregroundColor: isDarkMode ? Colors.lightGreenAccent : Colors.green),
                                        child: Text(S.markAsSettled),
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