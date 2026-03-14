import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/product_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'inhouseExport',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
        cardColor: Colors.white,
        dividerColor: const Color(0xFFE5E7EB),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF111827)),
          bodyMedium: TextStyle(color: Color(0xFF374151)),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF101827),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
        cardColor: const Color(0xFF1F2937),
        dividerColor: const Color(0xFF374151),
      ),
      home: const HomeScreen(),
    );
  }
}
