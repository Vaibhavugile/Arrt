import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
// import 'package:path_provider/path_provider.dart'; // <<< REMOVE THIS IMPORT for web

import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive - NO path_provider needed for web
  // Hive automatically uses IndexedDB for web
  await Hive.initFlutter(); // <<< CHANGE THIS LINE: Remove the path argument

  // Open Hive box for offline login data
  await Hive.openBox('offline_cache');
  print('Main function is running!'); // ADD THIS LINE
  runApp(MyApp());

}