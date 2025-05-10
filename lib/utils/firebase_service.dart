// lib/utils/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static Future<List<Map<String, dynamic>>> fetchOrderHistory(String branchCode) async {
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

    return historyData;
  }
}
