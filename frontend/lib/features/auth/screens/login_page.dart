import 'package:flutter/material.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/services/service_locator.dart';
import 'package:frontend/features/dining_manager/screens/scanner_page.dart';
import 'package:frontend/features/meal_manager/screens/manager_dashboard.dart';
import 'package:frontend/features/student/screens/student_home.dart';
import 'package:frontend/core/services/service_locator.dart';
import 'package:frontend/core/widgets/app_primary_button.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/core/widgets/loading_overlay.dart';
import 'package:frontend/features/auth/screens/forgot_password_page.dart';
import 'package:frontend/features/auth/screens/signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _baseUrlController;

  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  bool _showBaseUrlField = false;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _baseUrlController = TextEditingController(text: ApiConstants.baseUrl);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    // Simple email validation
    if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    _clearErrors();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ServiceLocator.authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      // Navigate based on role
      await _navigateByRole(response.role, response.userId);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateByRole(String role, int userId) async {
    // Navigate to the appropriate home screen based on role
    // Token is already saved to storage by the auth service
    final token = await ServiceLocator.tokenStorage.getToken() ?? '';

    Widget screen;

    switch (role.toUpperCase()) {
      case 'STUDENT':
        screen = StudentHome(token: token, userId: userId);
        break;
      case 'MEAL_MANAGER':
        screen = const ManagerDashboard();
        break;
      case 'DINING_MANAGER':
        screen = const ScannerPage();
        break;
      default:
        screen = StudentHome(token: token, userId: userId);
    }

    // Push the screen and remove all previous routes (so user can't go back)
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => screen),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Signing in...',
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWideScreen ? 24 : 16,
                vertical: 16,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header
                  SizedBox(
                    width: isWideScreen ? 500 : double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Welcome Back',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onSurface,
                                  ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.settings,
                                color: _showBaseUrlField
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant.withOpacity(0.4),
                                size: 20,
                              ),
                              tooltip: 'Set Base URL',
                              onPressed: () {
                                setState(
                                  () =>
                                      _showBaseUrlField = !_showBaseUrlField,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to your account to continue',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Base URL field (dev only)
                  if (_showBaseUrlField)
                    SizedBox(
                      width: isWideScreen ? 500 : double.infinity,
                      child: Card(
                        elevation: 0,
                        color: scheme.errorContainer.withOpacity(0.3),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: scheme.error,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'DEV ONLY — Set Base URL',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.error,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _baseUrlController,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'http://192.168.x.x:8080/api/v1',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant
                                        .withOpacity(0.5),
                                  ),
                                  filled: true,
                                  fillColor: scheme.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 32,
                                child: FilledButton.tonal(
                                  onPressed: () {
                                    final url =
                                        _baseUrlController.text.trim();
                                    if (url.isNotEmpty) {
                                      ServiceLocator.apiClient
                                          .updateBaseUrl(url);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Base URL set to: $url',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                    }
                                  },
                                  child: const Text(
                                    'Apply',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Login Card
                  SizedBox(
                    width: isWideScreen ? 500 : double.infinity,
                    child: Card(
                      elevation: 0,
                      color: scheme.surfaceContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Email field
                              AppTextField(
                                label: 'Email Address',
                                hint: 'your@email.com',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                                errorText: _emailError,
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password field
                              AppTextField(
                                label: 'Password',
                                hint: '••••••••',
                                controller: _passwordController,
                                obscureText: true,
                                validator: _validatePassword,
                                errorText: _passwordError,
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Forgot password link
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordPage(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Forgot password?',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Login button
                              AppPrimaryButton(
                                text: 'Sign In',
                                onPressed: _handleLogin,
                                isLoading: _isLoading,
                                isEnabled: !_isLoading,
                              ),
                              const SizedBox(height: 16),

                              // Sign up link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const SignupPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Sign Up',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
