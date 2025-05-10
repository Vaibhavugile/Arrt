import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VendorScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [FadeEffect(duration: 600.ms), MoveEffect(begin: Offset(0, 30))],
      child: Scaffold(
        appBar: AppBar(title: Text('Vendors')),
        body: Center(
          child: Text(
            'Vendor content goes here.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
