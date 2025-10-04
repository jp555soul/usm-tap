// lib/core/router/app_router.dart
import 'package:flutter/material.dart';

class AppRouter {
  static const String home = '/';
  static const String authCallback = '/auth-callback';
  static const String loading = '/loading';
  static const String settings = '/settings';
  static const String profile = '/profile';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const Placeholder(), // Will be replaced with actual home
          settings: settings,
        );
      
      case authCallback:
        return MaterialPageRoute(
          builder: (_) => const AuthCallbackPage(),
          settings: settings,
        );
      
      case loading:
        return MaterialPageRoute(
          builder: (_) => const LoadingPage(),
          settings: settings,
        );
      
      case settings:
        return MaterialPageRoute(
          builder: (_) => const Placeholder(), // Settings page
          settings: settings,
        );
      
      case profile:
        return MaterialPageRoute(
          builder: (_) => const Placeholder(), // Profile page
          settings: settings,
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('404')),
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}

// Auth Callback Page
class AuthCallbackPage extends StatefulWidget {
  const AuthCallbackPage({super.key});

  @override
  State<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends State<AuthCallbackPage> {
  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    // Wait a bit for auth to complete
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRouter.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'Completing authentication...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// Loading Page
class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo or Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.water,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Loading Ocean Platform...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}