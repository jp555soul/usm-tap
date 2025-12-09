import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/notification/notification_bloc.dart';
import 'notification_toast.dart';

/// Overlay widget that displays notifications at the top-right of the screen
class NotificationOverlay extends StatelessWidget {
  final Widget child;

  const NotificationOverlay({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main app content
        child,
        // Notification overlay
        BlocBuilder<NotificationBloc, NotificationState>(
          builder: (context, state) {
            if (state.notifications.isEmpty) {
              return const SizedBox.shrink();
            }

            return Positioned(
              top: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: state.notifications.map((notification) {
                  return TweenAnimationBuilder<double>(
                    key: ValueKey(notification.id),
                    duration: const Duration(milliseconds: 300),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset((1 - value) * 100, 0),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: NotificationToast(
                      notification: notification,
                      onDismiss: () {
                        context.read<NotificationBloc>().add(
                              DismissNotificationEvent(notification.id),
                            );
                      },
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}
