import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'package:intl/intl.dart';
import 'package:art/screens/AddVendorPage.dart';
class VendorScreen extends StatefulWidget {
  @override
  _VendorScreenState createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> {
  bool loading = true;
  List<Map<String, dynamic>> vendors = [];
  String? editingVendorId;
  String? expandedVendorId;
  String searchQuery = '';
  Map<String, String> commentData = {'amountPaid': '', 'paidBy': '', 'date': ''};

  final dateFormat = DateFormat('dd-MM-yyyy');

  @override
  void initState() {
    super.initState();
    fetchVendors();
  }

  Future<void> fetchVendors() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchCode = userProvider.userData?['branchCode'];

    if (branchCode == null) return;

    final vendorRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Vendors');

    final vendorSnapshot = await vendorRef.get();

    final vendorData = await Future.wait(vendorSnapshot.docs.map((doc) async {
      final stockSnapshot = await doc.reference.collection('Stock').get();
      final stockDetails = stockSnapshot.docs.map((s) => s.data()).toList();

      return {
        'id': doc.id,
        ...doc.data(),
        'stockDetails': stockDetails,
      };
    }));

    setState(() {
      vendors = vendorData;
      loading = false;
    });
  }
  // Date Picker function
  Future<void> _selectDate(BuildContext context) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (selectedDate != null && selectedDate != DateTime.now()) {
      setState(() {
        commentData['date'] = dateFormat.format(selectedDate);
      });
    }
  }

  Future<void> saveComment(String vendorId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchCode = userProvider.userData?['branchCode'];

    final vendorRef = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('Vendors')
        .doc(vendorId);

    await vendorRef.update({
      'comments': FieldValue.arrayUnion([commentData])
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vendor details updated!')),
    );

    setState(() {
      editingVendorId = null;
      commentData = {'amountPaid': '', 'paidBy': '', 'date': ''};
    });

    fetchVendors();
  }

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [FadeEffect(duration: 600.ms), MoveEffect(begin: Offset(0, 30))],
      child: Scaffold(
        appBar: AppBar(
          title: Text('Vendor Dashboard'),

        ),
        body: loading
            ? Center(child: CircularProgressIndicator())
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: vendors.length,
          itemBuilder: (context, index) {
            final vendor = vendors[index];
            final List<Map<String, dynamic>> stockDetails =
            List<Map<String, dynamic>>.from(vendor['stockDetails'] ?? []);
            final isExpanded = expandedVendorId == vendor['id'];
            final List<Map<String, dynamic>> comments =
            List<Map<String, dynamic>>.from(vendor['comments'] ?? []);

            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    title: Text(vendor['name'] ?? 'No Name'),
                    subtitle: Text(() {
                      final total = stockDetails.fold<double>(
                        0.0,
                            (sum, item) => sum + (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0),
                      );
                      final totalPaid = comments.fold<double>(
                        0.0,
                            (sum, c) => sum + (double.tryParse(c['amountPaid']?.toString() ?? '0') ?? 0.0),
                      );
                      final pending = total - totalPaid;
                      return 'Total: ₹${total.toStringAsFixed(2)} | Paid: ₹${totalPaid.toStringAsFixed(2)} | Pending: ₹${pending.toStringAsFixed(2)}';
                    }()),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () {
                            setState(() {
                              editingVendorId = vendor['id'];
                              expandedVendorId = vendor['id'];
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                          onPressed: () {
                            setState(() {
                              expandedVendorId = isExpanded ? null : vendor['id'];
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  if (isExpanded) ...[
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Search by date (dd-mm-yyyy)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              setState(() {
                                searchQuery = val;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          ..._buildGroupedStockTables(stockDetails),
                          const SizedBox(height: 10),
                          if (editingVendorId == vendor['id']) ...[
                            Text('Add Comment', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextField(
                              decoration: InputDecoration(labelText: 'Amount Paid'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setState(() => commentData['amountPaid'] = val),
                            ),
                            TextField(
                              decoration: InputDecoration(labelText: 'Paid By'),
                              onChanged: (val) => setState(() => commentData['paidBy'] = val),
                            ),
                            TextField(
                              decoration: InputDecoration(
                                labelText: 'Date',
                                hintText: 'Select a date',
                              ),
                              controller: TextEditingController(text: commentData['date']),
                              readOnly: true,
                              onTap: () => _selectDate(context),
                            ),
                            ElevatedButton.icon(
                              icon: Icon(Icons.save),
                              label: Text('Save'),
                              onPressed: () => saveComment(vendor['id']),
                            )
                          ],
                          const SizedBox(height: 10),
                          Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)),
                          if (comments.isNotEmpty)
                            ...comments.map<Widget>((c) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                  '₹${c['amountPaid']} paid by ${c['paidBy']} on ${c['date']}'),
                            ))
                          else
                            Text('No comments yet'),
                        ],
                      ),
                    )
                  ]
                ],
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddVendorPage()),
            );
          },
          child: Icon(Icons.add),
          tooltip: 'Add Vendor',
        ),

      ),
    );
  }

  List<Widget> _buildGroupedStockTables(List<Map<String, dynamic>> stockDetails) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var stock in stockDetails) {
      if (stock['invoiceDate'] is Timestamp) {
        final formattedDate = dateFormat.format(stock['invoiceDate'].toDate());
        grouped.putIfAbsent(formattedDate, () => []);
        grouped[formattedDate]!.add(stock);
      }
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => dateFormat.parse(b.key).compareTo(dateFormat.parse(a.key)));

    return sortedEntries.map((entry) {
      return ExpansionTile(
        title: Text('Date: ${entry.key}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, // horizontal scroll enabled
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Stock Name')),
                  DataColumn(label: Text('Quantity')),
                  DataColumn(label: Text('Price')),
                ],
                rows: entry.value.map<DataRow>((stock) {
                  return DataRow(cells: [
                    DataCell(Text(stock['ingredientName'] ?? '')),
                    DataCell(Text(stock['quantityAdded']?.toString() ?? '')),
                    DataCell(Text(stock['price']?.toString() ?? '')),
                  ]);
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: ₹${entry.value.fold<double>(0.0, (sum, stock) => sum + (double.tryParse(stock['price']?.toString() ?? '0') ?? 0)).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }).toList();
  }
}
