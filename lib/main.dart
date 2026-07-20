import 'package:flutter/material.dart';
import 'core/services/hive_service.dart';
import 'features/consumer/screens/home_screen.dart';
import 'features/consumer/screens/insights_screen.dart';
import 'features/consumer/screens/history_screen.dart';
import 'features/consumer/screens/profile_screen.dart';

import 'features/auth/services/auth_service.dart';
import 'features/auth/screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  bool loggedIn = await AuthService.isLoggedIn();
  runApp(QistirahaApp(isLoggedIn: loggedIn));
}

class QistirahaApp extends StatelessWidget {
  final bool isLoggedIn;
  const QistirahaApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qistiraha',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF99AFD7),
          primary: const Color(0xFF99AFD7),
        ),
        useMaterial3: true,
        tabBarTheme: const TabBarThemeData(
          indicatorColor: Color(0xFF99AFD7),
          labelColor: Color(0xFF99AFD7),
          unselectedLabelColor: Colors.grey,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF99AFD7),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFF99AFD7),
        ),
      ),
      home: isLoggedIn ? const MainNavigation() : const WelcomeScreen(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const InsightsScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
