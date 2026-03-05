import 'package:flutter/material.dart';
import 'package:frontend/core/services/service_locator.dart';
import 'package:frontend/features/auth/screens/login_page.dart';
import 'package:frontend/features/meal_manager/screens/manager_dashboard.dart';
import 'package:frontend/features/student/screens/student_home.dart';
import 'core/theme/app_theme.dart';
// import 'features/home/screens/dining_manager_home_page.dart';
import 'features/dining_manager/screens/scanner_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ServiceLocator on all platforms
  // TokenStorage gracefully handles web (SharedPreferences not supported)
  await ServiceLocator.init();

  runApp(const DiningApp());
}

class DiningApp extends StatefulWidget {
  const DiningApp({super.key});

  @override
  State<DiningApp> createState() => _DiningAppState();
}

class _DiningAppState extends State<DiningApp> {
  bool _isLoggedIn = false;
  bool _isInitialized = false;
  String _token = '';
  String _userRole = '';
  int? _userId;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Check stored login status
    final isLoggedIn = await ServiceLocator.tokenStorage.isLoggedIn();
    final token = await ServiceLocator.tokenStorage.getToken();
    final role = await ServiceLocator.tokenStorage.getRole();
    final userId = await ServiceLocator.tokenStorage.getUserId();

    setState(() {
      _isLoggedIn = isLoggedIn;
      _token = token ?? '';
      _userRole = role ?? '';
      _userId = userId;
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade200),
            ),
          ),
        ),
      );
    }

    // Determine home screen based on login status and role
    Widget homeScreen;
    if (!_isLoggedIn) {
      homeScreen = const LoginPage();
    } else {
      homeScreen = _buildHomeScreen();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Digital Dining System',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: homeScreen,
      routes: {'/login': (_) => const LoginPage()},
    );
  }

  Widget _buildHomeScreen() {
    if (_userRole.toUpperCase() == 'MEAL_MANAGER') {
      return const ManagerDashboard();
    } else if (_userRole.toUpperCase() == 'DINING_MANAGER') {
      return const ScannerPage();
    } else {
      // Default to student home for 'STUDENT' or other roles
      return StudentHome(token: _token, userId: _userId);
    }
  }
}
