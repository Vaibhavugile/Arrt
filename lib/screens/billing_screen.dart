import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BillingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [FadeEffect(duration: 600.ms), MoveEffect(begin: Offset(0, 30))],
      child: Scaffold(
        appBar: AppBar(title: Text('Billing')),
        body: Center(
          child: Text('Billing content goes here'),
        ),
      ),
    );
  }
}
