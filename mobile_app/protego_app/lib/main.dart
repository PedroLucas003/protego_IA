import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/monitor_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ProtegoApp());
}

class ProtegoApp extends StatelessWidget {
  const ProtegoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MonitorProvider(),
      child: MaterialApp(
        title: 'Protego IA',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A237E),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          cardTheme: CardThemeData(
            color: const Color(0xFF263238),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
