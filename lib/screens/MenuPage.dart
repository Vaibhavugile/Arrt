import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';


class MenuPage extends StatelessWidget {
  final Map<String, dynamic> table;
  const MenuPage({required this.table});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Menu - Table ${table['tableNumber']}"),
        backgroundColor: Colors.teal.shade700,
      ),
      body: Center(child: Text("Display menu here")),
    );
  }
}
