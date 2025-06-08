import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class KotScreen extends StatefulWidget {
  final String branchCode;
  final String tableId;

  const KotScreen({Key? key, required this.branchCode, required this.tableId}) : super(key: key);

  @override
  _KotScreenState createState() => _KotScreenState();
}

class _KotScreenState extends State<KotScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('KOTs for Table ${widget.tableId}'), // Display table ID
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('tables')
            .doc(widget.branchCode)
            .collection('tables')
            .doc(widget.tableId)
            .collection('kots')
            .orderBy('timestamp', descending: true) // Order by latest KOT
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No KOTs for this table yet.'));
          }

          final kots = snapshot.data!.docs;

          return ListView.builder(
            itemCount: kots.length,
            itemBuilder: (context, index) {
              final kotDoc = kots[index];
              final kotData = kotDoc.data() as Map<String, dynamic>;
              final items = List<Map<String, dynamic>>.from(kotData['items'] ?? []);
              final status = kotData['status'] ?? 'N/A';
              final timestamp = (kotData['timestamp'] as Timestamp?)?.toDate();
              final tableNumber = kotData['tableNumber'] ?? 'N/A'; // Get table number from KOT data

              return Card(
                margin: const EdgeInsets.all(8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'KOT for Table: ${tableNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Chip(
                            label: Text(status.toUpperCase(), style: TextStyle(color: Colors.white)),
                            backgroundColor: _getStatusColor(status),
                          ),
                        ],
                      ),
                      Text('KOT ID: ${kotDoc.id}', style: TextStyle(color: Colors.grey[700])),
                      if (timestamp != null)
                        Text(
                          'Time: ${timestamp.toLocal().toString().split('.')[0]}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      const Divider(height: 20, thickness: 1),
                      const Text('Order Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      // Display KOT items based on their type
                      ...items.map((item) {
                        final String itemName = item['name'] ?? 'Unknown Item';
                        final int itemQuantity = item['quantity'] ?? 0;
                        final String itemType = item['type'] ?? 'add'; // Default to 'add'

                        IconData icon;
                        Color textColor;
                        String actionText;

                        switch (itemType) {
                          case 'add':
                            icon = Icons.add_circle;
                            textColor = Colors.green[700]!;
                            actionText = 'ADD';
                            break;
                          case 'void_partial':
                            icon = Icons.remove_circle;
                            textColor = Colors.red[700]!;
                            actionText = 'VOID (Partial)';
                            break;
                          case 'void_full':
                            icon = Icons.cancel;
                            textColor = Colors.deepOrange[700]!;
                            actionText = 'VOID (Full)';
                            break;
                          default:
                            icon = Icons.info_outline;
                            textColor = Colors.grey[700]!;
                            actionText = 'ACTION';
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(icon, color: textColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$itemName (x$itemQuantity)',
                                  style: TextStyle(fontSize: 16, color: textColor, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                actionText,
                                style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 10),
                      // Action buttons for KOT status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (status == 'pending')
                            ElevatedButton.icon(
                              onPressed: () => _updateKotStatus(kotDoc.id, 'preparing'),
                              icon: const Icon(Icons.receipt_long, size: 18),
                              label: const Text('Mark Preparing'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (status == 'preparing')
                            ElevatedButton.icon(
                              onPressed: () => _updateKotStatus(kotDoc.id, 'ready'),
                              icon: const Icon(Icons.check_circle, size: 18),
                              label: const Text('Mark Ready'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (status == 'ready')
                            ElevatedButton.icon(
                              onPressed: () => _updateKotStatus(kotDoc.id, 'served'),
                              icon: const Icon(Icons.room_service, size: 18),
                              label: const Text('Mark Served'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          // Optional: Button to mark KOT as voided/cancelled from kitchen side
                          // if (status != 'voided' && status != 'served') // Only if not already finished
                          //   TextButton(
                          //     onPressed: () => _updateKotStatus(kotDoc.id, 'voided'),
                          //     child: Text('Void KOT', style: TextStyle(color: Colors.red)),
                          //   ),
                        ].where((widget) => widget != null).toList(), // Filter out nulls
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'served':
        return Colors.grey;
      case 'voided': // For full voids triggered from MenuPage
        return Colors.deepOrange;
      default:
        return Colors.black;
    }
  }

  Future<void> _updateKotStatus(String kotId, String newStatus) async {
    try {
      await _db
          .collection('tables')
          .doc(widget.branchCode)
          .collection('tables')
          .doc(widget.tableId)
          .collection('kots')
          .doc(kotId)
          .update({'status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('KOT $kotId status updated to $newStatus')),
      );
    } catch (e) {
      print("Error updating KOT status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update KOT status.')),
      );
    }
  }
}