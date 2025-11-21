// lib/presentation/widgets/auth/profile.dart

import 'package:flutter/material.dart';

class Profile extends StatelessWidget {
  final String? pictureUrl;
  final String? name;
  final bool isLoading;
  final bool isAuthenticated;

  const Profile({
    Key? key,
    this.pictureUrl,
    this.name,
    this.isLoading = false,
    this.isAuthenticated = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Text(
        'Loading ...',
        style: TextStyle(color: Colors.white),
      );
    }

    if (!isAuthenticated) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: pictureUrl != null ? NetworkImage(pictureUrl!) : null,
          backgroundColor: const Color(0xFF475569), // slate-600
          child: pictureUrl == null
              ? const Icon(Icons.person, size: 16, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          name ?? 'User',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// WITH AUTH BLOC INTEGRATION
// ============================================================================

/*
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';

class Profile extends StatelessWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthLoading) {
          return const Text(
            'Loading ...',
            style: TextStyle(color: Colors.white),
          );
        }

        if (state is! AuthAuthenticated) {
          return const SizedBox.shrink();
        }

        final user = state.user;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: user.picture != null 
                ? NetworkImage(user.picture!) 
                : null,
              backgroundColor: const Color(0xFF475569),
              child: user.picture == null
                  ? const Icon(Icons.person, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              user.name ?? 'User',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
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
import '../../models/user_model.dart';

class Profile extends StatefulWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final isAuthenticated = await _authService.isAuthenticated();
      
      if (isAuthenticated) {
        final user = await _authService.getUser();
        setState(() {
          _user = user;
          _isAuthenticated = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    } catch (error) {

      setState(() {
        _isLoading = false;
        _isAuthenticated = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Text(
        'Loading ...',
        style: TextStyle(color: Colors.white),
      );
    }

    if (!_isAuthenticated || _user == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: _user!.picture != null 
            ? NetworkImage(_user!.picture!) 
            : null,
          backgroundColor: const Color(0xFF475569),
          child: _user!.picture == null
              ? const Icon(Icons.person, size: 16, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          _user!.name ?? 'User',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
*/

// ============================================================================
// USER MODEL (for reference)
// ============================================================================

/*
class UserModel {
  final String? name;
  final String? email;
  final String? picture;

  UserModel({
    this.name,
    this.email,
    this.picture,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] as String?,
      email: json['email'] as String?,
      picture: json['picture'] as String?,
    );
  }
}
*/