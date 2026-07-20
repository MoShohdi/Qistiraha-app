import 'package:flutter/material.dart';
import 'core/services/hive_service.dart';
import 'core/services/deep_link_service.dart';
import 'features/consumer/screens/home_screen.dart';
import 'features/consumer/screens/insights_screen.dart';
import 'features/consumer/screens/history_screen.dart';
import 'features/consumer/screens/profile_screen.dart';

import 'features/auth/services/auth_service.dart';
import 'features/auth/models/user_role.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/merchant/screens/merchant_dashboard_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  bool loggedIn = await AuthService.isLoggedIn();
  UserRole role = await AuthService.getRole();
  runApp(QistirahaApp(isLoggedIn: loggedIn, role: role));
}

class QistirahaApp extends StatefulWidget {
  final bool isLoggedIn;
  final UserRole role;
  const QistirahaApp({super.key, required this.isLoggedIn, required this.role});

  @override
  State<QistirahaApp> createState() => _QistirahaAppState();
}

class _QistirahaAppState extends State<QistirahaApp> {
  @override
  void initState() {
    super.initState();
    DeepLinkService.init(navigatorKey);
  }

  @override
  void dispose() {
    DeepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
      home: !widget.isLoggedIn
          ? const WelcomeScreen()
          : (widget.role == UserRole.merchant
                ? const MerchantDashboardScreen()
                : const MainNavigation()),
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
