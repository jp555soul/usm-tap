// lib/presentation/screens/auth/auth_callback_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';

class AuthCallbackScreen extends StatefulWidget {
  final Map<String, String>? queryParameters;

  const AuthCallbackScreen({
    Key? key,
    this.queryParameters,
  }) : super(key: key);

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  String? _callbackError;
  bool _hasProcessed = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _processCallback();
  }

  Future<void> _processCallback() async {
    // Prevent double processing
    if (_hasProcessed) return;

    try {
      // debugPrint('Processing Auth0 callback for SPA...');
      setState(() => _hasProcessed = true);

      // Check for error in URL first
      final urlError = widget.queryParameters?['error'];
      final urlErrorDescription = widget.queryParameters?['error_description'];

      if (urlError != null) {
        throw Exception('$urlError: ${urlErrorDescription ?? 'Unknown error'}');
      }

      // Check if we have an authorization code
      final code = widget.queryParameters?['code'];

      if (code != null) {
        // Process the authorization code
        // debugPrint('Auth0 SPA callback processing complete');
        
        // Wait a moment to show loading state
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to home page after successful authentication
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      } else {
        // debugPrint('No authorization code found in callback URL');
        
        // Redirect to home after a short delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      }
    } catch (error) {
      // debugPrint('Error handling redirect callback: $error');
      
      setState(() {
        _callbackError = error.toString();
        _isLoading = false;
      });

      // If there's an error, redirect to home after a delay
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_callbackError != null) {
      return _buildErrorScreen();
    }

    return _buildLoadingScreen();
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // slate-900
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448), // max-w-md
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Authentication Error',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[400],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'There was an issue completing your login. You will be redirected automatically.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFFD1D5DB), // gray-300
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B), // slate-800
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _callbackError ?? 'Unknown authentication error',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280), // gray-500
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // slate-900
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.pink[500]!),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Completing login...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Processing authorization code...',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF), // gray-400
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ALTERNATIVE: With Auth Provider Integration
// ============================================================================

/*
// If using an auth provider/bloc:

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';

class AuthCallbackScreen extends StatefulWidget {
  final Map<String, String>? queryParameters;

  const AuthCallbackScreen({
    Key? key,
    this.queryParameters,
  }) : super(key: key);

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  String? _callbackError;
  bool _hasProcessed = false;

  @override
  void initState() {
    super.initState();
    _processCallback();
  }

  Future<void> _processCallback() async {
    if (_hasProcessed) return;

    try {
      // debugPrint('Processing Auth0 callback...');
      setState(() => _hasProcessed = true);

      final urlError = widget.queryParameters?['error'];
      final urlErrorDescription = widget.queryParameters?['error_description'];

      if (urlError != null) {
        throw Exception('$urlError: ${urlErrorDescription ?? 'Unknown error'}');
      }

      final code = widget.queryParameters?['code'];

      if (code != null) {
        // Trigger auth callback processing via bloc
        context.read<AuthBloc>().add(ProcessAuthCallback(code: code));
      } else {
        // debugPrint('No authorization code found in callback URL');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      }
    } catch (error) {
      // debugPrint('Error handling redirect callback: $error');
      setState(() => _callbackError = error.toString());
      
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.of(context).pushReplacementNamed('/');
        } else if (state is AuthError) {
          setState(() => _callbackError = state.message);
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/');
            }
          });
        }
      },
      child: _callbackError != null ? _buildErrorScreen() : _buildLoadingScreen(),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Authentication Error',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[400],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'There was an issue completing your login. You will be redirected automatically.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFFD1D5DB),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _callbackError ?? 'Unknown authentication error',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.pink[500]!),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Completing login...',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Processing authorization code...',
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
*/

// ============================================================================
// ROUTE SETUP
// ============================================================================

/*
// In your route configuration:

MaterialPageRoute(
  builder: (context) {
    final uri = Uri.parse(settings.name ?? '');
    return AuthCallbackScreen(
      queryParameters: uri.queryParameters,
    );
  },
)

// Or with named routes:
routes: {
  '/auth/callback': (context) {
    final uri = ModalRoute.of(context)!.settings.arguments as Uri?;
    return AuthCallbackScreen(
      queryParameters: uri?.queryParameters,
    );
  },
}

// For deep linking, add to AndroidManifest.xml and Info.plist:
// Then handle in main.dart:

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Handle deep links
  getInitialUri().then((uri) {
    if (uri != null && uri.path.contains('/auth/callback')) {
      runApp(MyApp(initialRoute: '/auth/callback', queryParams: uri.queryParameters));
    } else {
      runApp(MyApp());
    }
  });
}
*/