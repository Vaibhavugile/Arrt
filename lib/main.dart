// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart'; // Your main app widget
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive - NO path_provider needed for web
  // Hive automatically uses IndexedDB for web
  await Hive.initFlutter();
  // Open Hive box for offline login data
  await Hive.openBox('offline_cache');
  print('Main function is running!');

  // Run your MyApp directly, as it now contains the MaterialApp and MultiProvider
  runApp(const MyApp());
}