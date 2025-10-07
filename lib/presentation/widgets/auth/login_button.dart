import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// import '../../blocs/auth/auth_bloc.dart';

class LoginButton extends StatelessWidget {
  const LoginButton({Key? key}) : super(key: key);

  Future<void> _handleLogin(BuildContext context) async {
    try {
      // TODO: Implement Auth0 login
      // context.read<AuthBloc>().add(LoginEvent(
      //   redirectUri: '${Uri.base.origin}/auth/callback',
      //   scope: 'openid profile email',
      //   responseType: 'code',
      // ));
    } catch (error) {
      debugPrint('Login error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with BlocBuilder<AuthBloc, AuthState>
    final isLoading = false; // Get from AuthBloc state

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _handleLogin(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDB2777), // pink-600
          disabledBackgroundColor: const Color(0xFFF472B6), // pink-400
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ).copyWith(
          overlayColor: MaterialStateProperty.all(
            const Color(0xFFBE185D).withOpacity(0.1), // pink-700 hover
          ),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Logging in...',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              )
            : const Text(
                'Log In',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}