import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/notification_entity.dart';
import '../../../data/services/browser_notification_service.dart';

// ============================================================================
// EVENTS
// ============================================================================

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

/// Show a new notification
class ShowNotificationEvent extends NotificationEvent {
  final NotificationEntity notification;
  const ShowNotificationEvent(this.notification);

  @override
  List<Object?> get props => [notification];
}

/// Dismiss a notification by ID
class DismissNotificationEvent extends NotificationEvent {
  final String notificationId;
  const DismissNotificationEvent(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

/// Clear all notifications
class ClearAllNotificationsEvent extends NotificationEvent {
  const ClearAllNotificationsEvent();
}

/// Internal event for auto-dismiss timer
class _AutoDismissEvent extends NotificationEvent {
  final String notificationId;
  const _AutoDismissEvent(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

// ============================================================================
// STATES
// ============================================================================

class NotificationState extends Equatable {
  final List<NotificationEntity> notifications;

  const NotificationState({
    this.notifications = const [],
  });

  NotificationState copyWith({
    List<NotificationEntity>? notifications,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
    );
  }

  @override
  List<Object?> get props => [notifications];
}

// ============================================================================
// BLOC
// ============================================================================

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final BrowserNotificationService? _browserNotificationService;
  static const int _maxNotifications = 5;

  NotificationBloc({
    BrowserNotificationService? browserNotificationService,
  })  : _browserNotificationService = browserNotificationService,
        super(const NotificationState()) {
    on<ShowNotificationEvent>(_onShowNotification);
    on<DismissNotificationEvent>(_onDismissNotification);
    on<ClearAllNotificationsEvent>(_onClearAll);
    on<_AutoDismissEvent>(_onAutoDismiss);
  }

  Future<void> _onShowNotification(
    ShowNotificationEvent event,
    Emitter<NotificationState> emit,
  ) async {
    final notification = event.notification;

    // Add notification to list, limiting to max
    final updatedList = [
      notification,
      ...state.notifications,
    ].take(_maxNotifications).toList();

    emit(state.copyWith(notifications: updatedList));

    // Trigger browser notification if requested
    if (notification.sendBrowserNotification &&
        _browserNotificationService != null &&
        _browserNotificationService!.isSupported) {
      try {
        await _browserNotificationService!.showNotification(
          title: notification.title,
          body: notification.message,
        );
      } catch (e) {
        // Silently fail for browser notifications
      }
    }

    // Schedule auto-dismiss
    Future.delayed(notification.duration, () {
      if (!isClosed) {
        add(_AutoDismissEvent(notification.id));
      }
    });
  }

  void _onDismissNotification(
    DismissNotificationEvent event,
    Emitter<NotificationState> emit,
  ) {
    final updatedList = state.notifications
        .where((n) => n.id != event.notificationId)
        .toList();
    emit(state.copyWith(notifications: updatedList));
  }

  void _onClearAll(
    ClearAllNotificationsEvent event,
    Emitter<NotificationState> emit,
  ) {
    emit(state.copyWith(notifications: []));
  }

  void _onAutoDismiss(
    _AutoDismissEvent event,
    Emitter<NotificationState> emit,
  ) {
    final updatedList = state.notifications
        .where((n) => n.id != event.notificationId)
        .toList();
    emit(state.copyWith(notifications: updatedList));
  }
}
