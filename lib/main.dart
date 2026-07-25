import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/hive_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/utils/responsive_layout.dart';
import 'features/consumer/screens/home_screen.dart';
import 'features/consumer/screens/insights_screen.dart';
import 'features/consumer/screens/history_screen.dart';
import 'features/consumer/screens/profile_screen.dart';
import 'features/consumer/screens/consumer_dashboard_desktop.dart';
import 'features/consumer/screens/claim_installment_screen.dart';

import 'features/auth/services/auth_service.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/auth/screens/login_screen_desktop.dart';
import 'features/auth/screens/role_picker_screen.dart';
import 'features/auth/screens/role_picker_desktop.dart';
import 'features/merchant/screens/merchant_dashboard_screen.dart';
import 'features/merchant/screens/merchant_dashboard_desktop.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const supabaseUrl = 'https://blenajafusdwqrlpajnd.supabase.co';
const supabasePublishableKey = 'sb_publishable_Sxh427NXnNPdKw7sLCBXJg_SGkg1ks5';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  await HiveService.init();
  // Role now comes from Supabase (public.profiles), so boot needs the
  // network. A transient failure must not crash before the first frame —
  // fall back to the logged-out screen; the persisted session is untouched,
  // so the next sign-in attempt (or a reload) resolves cleanly.
  AuthDestination destination;
  try {
    destination = await AuthService.resolveDestination();
  } catch (_) {
    destination = AuthDestination.loggedOut;
  }
  // Web: a merchant's link is opened as an ordinary browser URL
  // (`?claim_id=…` or `#/claim?id=…`), which app_links can't surface — so
  // pick it up from the boot URL and route to the claim screen after mount.
  final initialClaimId = DeepLinkService.claimIdFromCurrentUrl();
  runApp(
    QistirahaApp(
      initialDestination: destination,
      initialClaimId: initialClaimId,
    ),
  );
}

/// The single place that turns an [AuthDestination] into the screen pair
/// shown for it — reused at boot, by the root auth-state listener, and by
/// the Role Picker screens once a role is chosen.
Widget destinationScreen(AuthDestination destination) {
  switch (destination) {
    case AuthDestination.loggedOut:
      return const ResponsiveLayout(
        mobileWidget: WelcomeScreen(),
        desktopWidget: LoginScreenDesktop(),
      );
    case AuthDestination.rolePicker:
      return const ResponsiveLayout(
        mobileWidget: RolePickerScreen(),
        desktopWidget: RolePickerDesktopScreen(),
      );
    case AuthDestination.merchantHome:
      return const ResponsiveLayout(
        mobileWidget: MerchantDashboardScreen(),
        desktopWidget: MerchantDashboardDesktop(),
      );
    case AuthDestination.consumerHome:
      return const ResponsiveLayout(
        mobileWidget: MainNavigation(),
        desktopWidget: ConsumerDashboardDesktop(),
      );
  }
}

class QistirahaApp extends StatefulWidget {
  final AuthDestination initialDestination;
  final String? initialClaimId;
  const QistirahaApp({
    super.key,
    required this.initialDestination,
    this.initialClaimId,
  });

  @override
  State<QistirahaApp> createState() => _QistirahaAppState();
}

class _QistirahaAppState extends State<QistirahaApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    DeepLinkService.init(navigatorKey);
    _authSub = AuthService.authStateChanges.listen(_onAuthStateChange);

    // If the app was opened via a web claim URL, drop the user onto the claim
    // screen once the navigator is mounted (post-first-frame).
    final claimId = widget.initialClaimId;
    if (claimId != null && claimId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ClaimInstallmentScreen(installmentId: claimId),
          ),
        );
      });
    }
  }

  /// `onAuthStateChange` immediately replays the current session as its
  /// first event (`initialSession`) — `main()` already decided the first
  /// screen from that same session, so this only needs to react to events
  /// that happen *after* boot: a live Google/email sign-in completing, or
  /// a sign-out, while the app is already running.
  Future<void> _onAuthStateChange(AuthState state) async {
    switch (state.event) {
      case AuthChangeEvent.signedIn:
        AuthDestination destination;
        try {
          destination = await AuthService.resolveDestination();
        } catch (_) {
          // Couldn't reach profiles right after sign-in — send the user to
          // the role picker, which retries the write and routes onward,
          // rather than stranding them on the login screen.
          destination = AuthDestination.rolePicker;
        }
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => destinationScreen(destination)),
          (route) => false,
        );
        break;
      case AuthChangeEvent.signedOut:
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => destinationScreen(AuthDestination.loggedOut),
          ),
          (route) => false,
        );
        break;
      default:
        break; // initialSession, tokenRefreshed, userUpdated, etc. — no-op
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
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
      home: destinationScreen(widget.initialDestination),
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
