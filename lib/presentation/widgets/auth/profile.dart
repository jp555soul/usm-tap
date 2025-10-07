import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
// import '../../blocs/auth/auth_bloc.dart';
// import '../../../domain/entities/user_entity.dart';

class Profile extends StatelessWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with BlocBuilder<AuthBloc, AuthState>
    final isLoading = false;
    final isAuthenticated = false;
    final user = null; // UserEntity?

    if (isLoading) {
      return const Text(
        'Loading ...',
        style: TextStyle(color: Colors.white),
      );
    }

    if (!isAuthenticated || user == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: user.picture ?? '',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 32,
              height: 32,
              color: Colors.grey.shade700,
              child: const Icon(Icons.person, size: 20, color: Colors.white54),
            ),
            errorWidget: (context, url, error) => Container(
              width: 32,
              height: 32,
              color: Colors.grey.shade700,
              child: const Icon(Icons.person, size: 20, color: Colors.white54),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          user.name ?? 'User',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}