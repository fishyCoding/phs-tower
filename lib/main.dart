import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/news_screen.dart';
import 'screens/games_screen.dart';
import 'screens/outreach_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://yusjougmsdnhcsksadaw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl1c2pvdWdtc2RuaGNza3NhZGF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE2NDU1NzI4NzQsImV4cCI6MTk2MTE0ODg3NH0.DHLgiswzK6Y_z5_mXAkRn1xy60zvhdb_iQH5gAyJorg',
  );
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 500 * 1024 * 1024;
  runApp(const PHSTowerApp());
}

class PHSTowerApp extends StatelessWidget {
  const PHSTowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PHS Tower',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    NewsScreen(),
    GamesScreen(),
    OutreachScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'News'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_on), label: 'Games'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Outreach'),
        ],
      ),
    );
  }
}