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
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.black54,
        ),
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
  int _newsCategoryIndex = 0;
  final _newsScreenKey = GlobalKey<NewsScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      NewsScreen(key: _newsScreenKey),
      const GamesScreen(),
      const OutreachScreen(),
    ];
  }

  void _onNewsCategoryTapped(String category, int index) {
    _newsScreenKey.currentState?.selectCategory(category);
    setState(() {
      _newsCategoryIndex = index;
    });
  }

  static const List<BottomNavigationBarItem> _defaultNavItems = [
    BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'News'),
    BottomNavigationBarItem(icon: Icon(Icons.grid_on), label: 'Games'),
    BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Outreach'),
  ];

  static const List<BottomNavigationBarItem> _newsNavItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'All News'),
    BottomNavigationBarItem(icon: Icon(Icons.article), label: 'News-Features'),
    BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Opinions'),
    BottomNavigationBarItem(icon: Icon(Icons.palette), label: 'Arts'),
    BottomNavigationBarItem(icon: Icon(Icons.sports_basketball), label: 'Sports'),
    BottomNavigationBarItem(icon: Icon(Icons.grid_on), label: 'Games'),
    BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Outreach'),
  ];
  
  static const List<String> _newsCategories = ['All', 'News-Features', 'Opinions', 'Arts-Entertainment', 'Sports'];


  @override
  Widget build(BuildContext context) {
    final bool isNewsSelected = _selectedIndex == 0;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: isNewsSelected ? _newsNavItems : _defaultNavItems,
        currentIndex: isNewsSelected ? _newsCategoryIndex : _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            if (isNewsSelected) {
              if (index < 5) { // A news category was tapped
                _onNewsCategoryTapped(_newsCategories[index], index);
              } else { // Games or Outreach was tapped
                _selectedIndex = index - 4; // Map index 5,6 to 1,2
              }
            } else {
              _selectedIndex = index;
              if (index == 0) {
                 // Reset to 'All' when entering news mode
                _onNewsCategoryTapped('All', 0);
              }
            }
          });
        },
      ),
    );
  }
}
