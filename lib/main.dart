import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US'), Locale('en', 'GB')],
      home: const HomeScreen(),
    );
  }
}
