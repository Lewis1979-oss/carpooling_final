import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/keys.dart';

enum AppTheme { 
  tealGold,
  oceanBlue,
  emeraldGreen,
  purpleIndigo,
  coralOrange,
  rosePink,
  classic, 
  gold, 
  midnight, 
  platinum,
}

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark; 
  AppTheme _appTheme = AppTheme.tealGold;
  String _fontFamily = 'Montserrat';
  double _fontSizeFactor = 1.0;
  bool _isInitialized = false;
  int _currentTabIndex = 0;
  bool _showOnboarding = true;
  
  // Map settings
  bool _isSatelliteMode = false;
  bool _isTrafficEnabled = true; 

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  AppTheme get appTheme => _appTheme;
  String get fontFamily => _fontFamily;
  double get fontSizeFactor => _fontSizeFactor;
  bool get isInitialized => _isInitialized;
  int get currentTabIndex => _currentTabIndex;
  bool get isSatelliteMode => _isSatelliteMode;
  bool get isTrafficEnabled => _isTrafficEnabled;
  bool get showOnboarding => _showOnboarding;

  ThemeService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final isDark = prefs.getBool('isDarkMode') ?? true;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    
    final themeIndex = prefs.getInt('appTheme') ?? 0; 
    _appTheme = AppTheme.values[themeIndex < AppTheme.values.length ? themeIndex : 0];
    
    _fontFamily = prefs.getString('fontFamily') ?? 'Montserrat';
    _fontSizeFactor = prefs.getDouble('fontSizeFactor') ?? 1.0;
    _currentTabIndex = prefs.getInt('currentTabIndex') ?? 0;
    _isSatelliteMode = prefs.getBool('isSatelliteMode') ?? false;
    _isTrafficEnabled = prefs.getBool('isTrafficEnabled') ?? true;
    _showOnboarding = prefs.getBool('showOnboarding') ?? true;
    
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _showOnboarding = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showOnboarding', false);
  }

  String get mapUrl {
    if (_isSatelliteMode) {
      return 'https://api.maptiler.com/maps/hybrid-v4/{z}/{x}/{y}.jpg?key=${AppKeys.mapTilerKey}';
    }
    return isDarkMode
        ? 'https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png?key=${AppKeys.mapTilerKey}'
        : 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=${AppKeys.mapTilerKey}';
  }

  String get trafficUrl => 'https://api.maptiler.com/tiles/traffic-v2/{z}/{x}/{y}.png?key=${AppKeys.mapTilerKey}';

  Future<void> toggleMapMode() async {
    _isSatelliteMode = !_isSatelliteMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSatelliteMode', _isSatelliteMode);
  }

  Future<void> toggleTraffic() async {
    _isTrafficEnabled = !_isTrafficEnabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTrafficEnabled', _isTrafficEnabled);
  }

  // Color constants based on the Glassmorphism Screenshot
  static const Color deepTeal = Color(0xFF0D3B3B);
  static const Color teal = Color(0xFF0FA69A);
  static const Color lightTeal = Color(0xFFA7F3E6);
  static const Color gold = Color(0xFFD4AF37);
  static const Color warmGold = Color(0xFFF5C24B);
  static const Color white = Color(0xFFFFFFFF);

  // New Theme Colors
  static const Color oceanBlue = Color(0xFF0EA5E9);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color purpleIndigo = Color(0xFF8B5CF6);
  static const Color coralOrange = Color(0xFFFF7A59);
  static const Color rosePink = Color(0xFFEC4899);

  static const Color premiumBlack = Color(0xFF0A0A0A);
  static const Color signatureGold = Color(0xFFD4AF37);

  static Color getThemeColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.tealGold: return teal;
      case AppTheme.oceanBlue: return oceanBlue;
      case AppTheme.emeraldGreen: return emeraldGreen;
      case AppTheme.purpleIndigo: return purpleIndigo;
      case AppTheme.coralOrange: return coralOrange;
      case AppTheme.rosePink: return rosePink;
      case AppTheme.gold: return signatureGold;
      case AppTheme.midnight: return const Color(0xFF2C3E50);
      case AppTheme.platinum: return const Color(0xFFE5E4E2);
      case AppTheme.classic:
      default: return Colors.blueGrey;
    }
  }

  Color get primaryColor {
    if (isDarkMode) {
      switch (_appTheme) {
        case AppTheme.tealGold: return const Color(0xFF0D3B3B);
        case AppTheme.oceanBlue: return const Color(0xFF0D1B2A);
        case AppTheme.emeraldGreen: return const Color(0xFF062119);
        case AppTheme.purpleIndigo: return const Color(0xFF1A1625);
        case AppTheme.coralOrange: return const Color(0xFF251A16);
        case AppTheme.rosePink: return const Color(0xFF25161A);
        default: return premiumBlack;
      }
    }
    return Colors.white;
  }

  Color get goldAccent {
    return warmGold;
  }

  Color get secondaryColor {
    return getThemeColor(_appTheme);
  }

  LinearGradient get backgroundGradient {
    final accent = secondaryColor;
    final base = primaryColor;
    
    if (!isDarkMode) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.grey[100]!],
      );
    }

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        base,
        Color.alphaBlend(accent.withOpacity(0.15), base),
        base,
      ],
    );
  }

  String get themeName => _appTheme.name.toUpperCase();

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  Future<void> setAppTheme(AppTheme theme) async {
    _appTheme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appTheme', theme.index);
  }

  Future<void> setFontFamily(String font) async {
    _fontFamily = font;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontFamily', font);
  }

  Future<void> setFontSizeFactor(double factor) async {
    _fontSizeFactor = factor;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSizeFactor', factor);
  }

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) => prefs.setInt('currentTabIndex', index));
  }
}
