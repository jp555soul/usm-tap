// lib/presentation/widgets/auth/login_button.dart

import 'package:flutter/material.dart';

class LoginButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const LoginButton({
    Key? key,
    this.onPressed,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDB2777), // pink-600
          disabledBackgroundColor: const Color(0xFFF472B6), // pink-400
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          elevation: 0,
        ).copyWith(
          overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.hovered)) {
                return const Color(0xFFBE185D); // pink-700
              }
              return null;
            },
          ),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Logging in...',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              )
            : const Text(
                'Log In',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}

// ============================================================================
// WITH AUTH BLOC INTEGRATION
// ============================================================================

/*
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';

class LoginButton extends StatelessWidget {
  const LoginButton({Key? key}) : super(key: key);

  void _handleLogin(BuildContext context) async {
    try {
      final redirectUri = Uri.base.origin + '/auth/callback';
      
      context.read<AuthBloc>().add(
        LoginRequested(
          redirectUri: redirectUri,
          scope: 'openid profile email',
          responseType: 'code',
        ),
      );
    } catch (error) {
      debugPrint('Login error: $error');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : () => _handleLogin(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDB2777),
              disabledBackgroundColor: const Color(0xFFF472B6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              elevation: 0,
            ).copyWith(
              overlayColor: MaterialStateProperty.resolveWith<Color?>(
                (Set<MaterialState> states) {
                  if (states.contains(MaterialState.hovered)) {
                    return const Color(0xFFBE185D);
                  }
                  return null;
                },
              ),
            ),
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Logging in...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Log In',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
*/

// ============================================================================
// WITH AUTH SERVICE
// ============================================================================

/*
import '../../services/auth_service.dart';

class LoginButton extends StatefulWidget {
  const LoginButton({Key? key}) : super(key: key);

  @override
  State<LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<LoginButton> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      final redirectUri = Uri.base.origin + '/auth/callback';
      
      await _authService.loginWithRedirect(
        redirectUri: redirectUri,
        scope: 'openid profile email',
        responseType: 'code',
      );
    } catch (error) {
      debugPrint('Login error: $error');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDB2777),
          disabledBackgroundColor: const Color(0xFFF472B6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          elevation: 0,
        ).copyWith(
          overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.hovered)) {
                return const Color(0xFFBE185D);
              }
              return null;
            },
          ),
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Logging in...',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              )
            : const Text(
                'Log In',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}
*/