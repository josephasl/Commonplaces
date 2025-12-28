import 'package:flutter/material.dart';
import 'storage_service.dart';
import 'screens/home_screen.dart'; // Adjust path if needed

// Create a global instance
final StorageService storageService = StorageService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive boxes
  await storageService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}
