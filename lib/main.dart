import 'package:flutter/material.dart';
import 'storage_service.dart';
import 'screens/home_screen.dart';

// Create a global instance (or use a Provider/GetIt for dependency injection)
final StorageService storageService = StorageService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive and open boxes
  await storageService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Pinterest Clone', home: const HomeScreen());
  }
}
