import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/my_rides_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/error_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_drawer.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/voice_call_screen.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'services/notification_service.dart';
import 'services/safety_service.dart';
import 'services/safety_trigger_service.dart';
import 'services/voice_call_service.dart';
import 'widgets/glass_widgets.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return ErrorScreen(
      message: "Something went wrong with the display. We're looking into it!",
      onRetry: () => main(),
    );
  };

  bool isFirebaseInitialized = false;
  String? initializationError;

  try {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    
    // Initialize Core Safety Services
    await NotificationService().init();
    await SafetyService().fetchHighRiskZones(); // Load zones once at startup

    isFirebaseInitialized = true;
  } catch (e) {
    debugPrint("Firebase/Notification initialization failed: $e");
    initializationError = e.toString();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeService()),
        ChangeNotifierProvider(create: (context) => VoiceCallService()),
      ],
      child: MyApp(
        isServiceAvailable: isFirebaseInitialized,
        initializationError: initializationError,
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool isServiceAvailable;
  final String? initializationError;

  const MyApp({
    super.key,
    required this.isServiceAvailable,
    this.initializationError,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updatePresence(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePresence(true);
    } else {
      _updatePresence(false);
    }
  }

  void _updatePresence(bool isOnline) {
    _authService.updateUserPresence(isOnline);
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => _authService),
        Provider<SafetyTriggerService>(
          create: (_) => SafetyTriggerService()..init(),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        title: 'ZedPool',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        themeMode: themeService.themeMode,
        navigatorObservers: [routeObserver],
        theme: _buildTheme(Brightness.light, themeService),
        darkTheme: _buildTheme(Brightness.dark, themeService),
        initialRoute: '/',
        routes: {
          '/': (context) => AuthWrapper(
                isServiceAvailable: widget.isServiceAvailable,
                error: widget.initializationError,
              ),
          '/admin': (context) => const AdminDashboardScreen(),
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness, ThemeService themeService) {
    final bool isDark = brightness == Brightness.dark;
    final activeGold = themeService.goldAccent;
    final bgColor = themeService.primaryColor;
    final isTealTheme = themeService.appTheme == AppTheme.tealGold;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: themeService.fontFamily,
      scaffoldBackgroundColor: bgColor,
      primaryColor: activeGold,
      colorScheme: ColorScheme.fromSeed(
        seedColor: activeGold,
        primary: activeGold,
        secondary: themeService.secondaryColor,
        surface: isDark ? (isTealTheme ? const Color(0xFF144D4D) : const Color(0xFF1A1A1A)) : Colors.white,
        brightness: brightness,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? activeGold : const Color(0xFF484848),
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: activeGold,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? bgColor.withOpacity(0.9) : bgColor,
        selectedItemColor: activeGold,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
      textTheme: const TextTheme().apply(
        fontSizeFactor: themeService.fontSizeFactor,
        bodyColor: isDark ? Colors.white : Colors.black87,
        displayColor: isDark ? Colors.white : Colors.black87,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final bool isServiceAvailable;
  final String? error;

  const AuthWrapper({
    super.key,
    required this.isServiceAvailable,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (!isServiceAvailable) {
      return ErrorScreen(
        message: "Connection lost. Please check your data.\n\nError: ${error ?? 'Unknown'}",
        onRetry: () => main(),
      );
    }

    final themeService = Provider.of<ThemeService>(context);

    if (!themeService.isInitialized) {
      return const LoadingScreen(message: "Initializing ZedPool...");
    }

    if (themeService.showOnboarding) {
      return OnboardingScreen(onFinished: () => themeService.completeOnboarding());
    }

    return StreamBuilder<User?>(
      stream: Provider.of<AuthService>(context).user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active || snapshot.connectionState == ConnectionState.waiting) {
          if (snapshot.data == null) {
            return const LoginScreen();
          } else {
            return const MainNavigation();
          }
        }
        if (snapshot.hasError) return const ErrorScreen(message: "Auth service error.");
        return const LoadingScreen(message: "Verifying Session...");
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final String emergencyPhoneNumber = "+260964256282";
  
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _sosKey = GlobalKey();
  final GlobalKey _themeToggleKey = GlobalKey();
  final GlobalKey _recentRoutesKey = GlobalKey();
  final GlobalKey _bookRideKey = GlobalKey();
  final GlobalKey _postRideKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  late TutorialCoachMark tutorialCoachMark;
  List<TargetFocus> targets = [];

  @override
  void initState() {
    super.initState();
    _initTutorial();
  }

  void _initTutorial() {
    targets.add(
      TargetFocus(
        identify: "menu",
        keyTarget: _menuKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialText("Menu", "Access your profile, ride history, and system settings here."),
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "sos",
        keyTarget: _sosKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialText("Emergency SOS", "Tap this in case of danger to immediately alert our Admin and call for help."),
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "theme",
        keyTarget: _themeToggleKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialText("Comfort Mode", "Easily switch between Light and Dark themes to suit your eyes."),
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "book",
        keyTarget: _bookRideKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildTutorialText("Book a Ride", "Find available premium rides heading to your destination."),
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "post",
        keyTarget: _postRideKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildTutorialText("Post a Ride", "Share your trip and start saving on fuel costs."),
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "recent",
        keyTarget: _recentRoutesKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildTutorialText("Live Feed", "View the most recent active routes within the ZedPool community."),
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "fab",
        keyTarget: _fabKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildTutorialText("Quick Start", "The fastest way to post your new ride from anywhere."),
          ),
        ],
      ),
    );
  }

  void _showTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    bool tutorialShown = prefs.getBool('feature_discovery_shown') ?? false;

    if (!tutorialShown && mounted) {
      tutorialCoachMark = TutorialCoachMark(
        targets: targets,
        colorShadow: Colors.black,
        opacityShadow: 0.85,
        paddingFocus: 10,
        textSkip: "SKIP",
        onFinish: () => prefs.setBool('feature_discovery_shown', true),
        onSkip: () {
          prefs.setBool('feature_discovery_shown', true);
          return true;
        },
      )..show(context: context);
    }
  }

  Widget _buildTutorialText(String title, String body) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 24)),
        const SizedBox(height: 10),
        Text(body, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final activeGold = themeService.goldAccent;

    if (themeService.currentTabIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
    }

    final List<Widget> pages = [
      HomeScreen(
        recentRoutesKey: _recentRoutesKey,
        bookRideKey: _bookRideKey,
        postRideKey: _postRideKey,
        fabKey: _fabKey,
      ),
      const SearchScreen(),
      const InboxScreen(),
      const MyRidesScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const MainDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: (isDark ? themeService.primaryColor : Colors.white).withOpacity(0.7),
              elevation: 0,
              centerTitle: true,
              leading: Builder(
                builder: (context) => IconButton(
                  key: _menuKey,
                  icon: Icon(Icons.menu, color: activeGold),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              title: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'ZedPool ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 20,
                      ),
                    ),
                    TextSpan(
                      text: 'Premium',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: themeService.secondaryColor,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: PremiumSOSButton(
                      key: _sosKey,
                      onTap: () => _showSOSDialog(context),
                    ),
                  ),
                ),
                _buildActionButton(
                  isDark ? Icons.wb_sunny : Icons.nightlight_round,
                  activeGold,
                  () => themeService.toggleTheme(),
                  activeGold,
                  key: _themeToggleKey,
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(color: activeGold.withOpacity(0.3), height: 1.0),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: themeService.backgroundGradient,
        ),
        child: IndexedStack(
          index: themeService.currentTabIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.mail), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'My Rides'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: themeService.currentTabIndex,
        onTap: (index) => themeService.setTabIndex(index),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap, Color borderGold, {Key? key}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Container(
        key: key,
        height: 38, width: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderGold.withOpacity(0.4), width: 1.5),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: color, size: 20),
          onPressed: onTap,
        ),
      ),
    );
  }

  void _showSOSDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          isDark: true,
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                const Text('EMERGENCY SOS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 15),
                const Text(
                  'This will immediately alert the Admin with your live location. Are you in danger?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text('YES, HELP!', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm == true) {
      // 1. Trigger the background alerts (Admin SMS & Dashboard Dashboard)
      final safetyTrigger = Provider.of<SafetyTriggerService>(context, listen: false);
      safetyTrigger.triggerSOS('User manually triggered Global SOS from Dashboard');

      // 2. Immediately initiate a regular phone call to emergency services
      final Uri tel = Uri(scheme: 'tel', path: emergencyPhoneNumber);
      if (await canLaunchUrl(tel)) {
        await launchUrl(tel);
      }
    }
  }
}
