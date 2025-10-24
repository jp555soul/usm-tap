// lib/presentation/widgets/auth/logout_button.dart

import 'package:flutter/material.dart';

class LogoutButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const LogoutButton({
    Key? key,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4B5563), // gray-600
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
                return const Color(0xFF374151); // gray-700
              }
              return null;
            },
          ),
        ),
        child: const Text(
          'Log Out',
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

class LogoutButton extends StatelessWidget {
  const LogoutButton({Key? key}) : super(key: key);

  void _handleLogout(BuildContext context) {
    final returnTo = Uri.base.origin;
    
    context.read<AuthBloc>().add(
      LogoutRequested(returnTo: returnTo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _handleLogout(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4B5563),
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
                return const Color(0xFF374151);
              }
              return null;
            },
          ),
        ),
        child: const Text(
          'Log Out',
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

// ============================================================================
// WITH AUTH SERVICE
// ============================================================================

/*
import '../../services/auth_service.dart';

class LogoutButton extends StatelessWidget {
  final AuthService _authService = AuthService();

  LogoutButton({Key? key}) : super(key: key);

  Future<void> _handleLogout() async {
    try {
      final returnTo = Uri.base.origin;
      await _authService.logout(returnTo: returnTo);
    } catch (error) {
      // debugPrint('Logout error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4B5563),
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
                return const Color(0xFF374151);
              }
              return null;
            },
          ),
        ),
        child: const Text(
          'Log Out',
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