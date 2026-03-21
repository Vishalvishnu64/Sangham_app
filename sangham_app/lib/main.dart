import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const SanghamApp());
}

class SanghamApp extends StatelessWidget {
  const SanghamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'The Digital Ledger',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A5C3A),
            primary: const Color(0xFF1A5C3A),
            secondary: const Color(0xFFF5A623),
            surface: const Color(0xFFF5F5F0),
          ),
          textTheme: GoogleFonts.interTextTheme(),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A5C3A),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5C3A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
