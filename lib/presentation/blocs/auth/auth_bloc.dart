import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:usm_tap/presentation/widgets/auth/auth_configuration_error_widget.dart';

import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/auth/login_usecase.dart';
import '../../../domain/usecases/auth/logout_usecase.dart';
import '../../../domain/usecases/auth/get_user_profile_usecase.dart';
import '../../../domain/usecases/auth/validate_auth_config_usecase.dart';
import '../../../core/constants/app_constants.dart';

// EVENTS
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  
  @override
  List<Object?> get props => [];
}

class AuthInitializeEvent extends AuthEvent {
  const AuthInitializeEvent();
}

class AuthLoginEvent extends AuthEvent {
  const AuthLoginEvent();
}

class AuthLogoutEvent extends AuthEvent {
  const AuthLogoutEvent();
}

class AuthRetryEvent extends AuthEvent {
  const AuthRetryEvent();
}

class AuthValidateConfigEvent extends AuthEvent {
  const AuthValidateConfigEvent();
}

class AuthCheckStatusEvent extends AuthEvent {
  const AuthCheckStatusEvent();
}

// STATES
abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

class AuthInitialState extends AuthState {
  const AuthInitialState();
}

class AuthLoadingState extends AuthState {
  const AuthLoadingState();
}

class AuthConfigurationErrorState extends AuthState {
  final List<String> missingVariables;
  
  const AuthConfigurationErrorState(this.missingVariables);
  
  @override
  List<Object?> get props => [missingVariables];
}

class UnauthenticatedState extends AuthState {
  const UnauthenticatedState();
}

class AuthenticatedState extends AuthState {
  final UserEntity user;
  final String accessToken;
  final bool hasRefreshToken;
  
  const AuthenticatedState({
    required this.user,
    required this.accessToken,
    this.hasRefreshToken = false,
  });
  
  @override
  List<Object?> get props => [user, accessToken, hasRefreshToken];
}

class AuthErrorState extends AuthState {
  final String message;
  
  const AuthErrorState(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLOC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetUserProfileUseCase _getUserProfileUseCase;
  final ValidateAuthConfigUseCase _validateAuthConfigUseCase;
  
  AuthBloc({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required GetUserProfileUseCase getUserProfileUseCase,
    required ValidateAuthConfigUseCase validateAuthConfigUseCase,
  }) : _loginUseCase = loginUseCase,
       _logoutUseCase = logoutUseCase,
       _getUserProfileUseCase = getUserProfileUseCase,
       _validateAuthConfigUseCase = validateAuthConfigUseCase,
       super(const AuthInitialState()) {
    
    // Register event handlers
    on<AuthInitializeEvent>(_onInitialize);
    on<AuthLoginEvent>(_onLogin);
    on<AuthLogoutEvent>(_onLogout);
    on<AuthRetryEvent>(_onRetry);
    on<AuthValidateConfigEvent>(_onValidateConfig);
    on<AuthCheckStatusEvent>(_onCheckStatus);
  }
  
  Future<void> _onInitialize(
    AuthInitializeEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    
    // First validate Auth0 configuration (equivalent to environment variable validation)
    final configResult = await _validateAuthConfigUseCase();
    
    if (configResult.isLeft()) {
      final failure = configResult.fold((l) => l, (r) => null);
      if (failure != null && failure.message.contains('missing')) {
        // Parse missing variables from error message
        final missingVars = _parseMissingVariables(failure.message);
        emit(AuthConfigurationErrorState(missingVars));
        return;
      }
    }
    
    // Log Auth0 configuration (equivalent to console.log in React)
    if (kDebugMode) {
      _logAuth0Configuration();
    }
    
    // Check existing authentication status
    try {
      final userResult = await _getUserProfileUseCase();
      
      if (userResult.isRight()) {
        final user = userResult.getOrElse(() => throw Exception('No user'));
        emit(AuthenticatedState(
          user: user,
          accessToken: 'token', // Replace with actual token
          hasRefreshToken: true,
        ));
      } else {
        emit(const UnauthenticatedState());
      }
    } catch (e) {
      emit(const UnauthenticatedState());
    }
  }
  
  Future<void> _onLogin(
    AuthLoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    
    try {
      final loginResult = await _loginUseCase();
      
      if (loginResult.isRight()) {
        final authData = loginResult.getOrElse(() => throw Exception('Login failed'));
        
        // Get user profile after successful login
        final userResult = await _getUserProfileUseCase();
        
        if (userResult.isRight()) {
          final user = userResult.getOrElse(() => throw Exception('No user profile'));
          
          emit(AuthenticatedState(
            user: user,
            accessToken: authData.accessToken ?? '',
            hasRefreshToken: authData.refreshToken != null,
          ));
        } else {
          emit(AuthErrorState(userResult.fold((l) => l.message, (r) => 'Failed to get user profile')));
        }
      } else {
        emit(AuthErrorState(loginResult.fold((l) => l.message, (r) => 'Login failed')));
      }
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }
  
  Future<void> _onLogout(
    AuthLogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    
    try {
      final result = await _logoutUseCase();
      
      if (result.isRight()) {
        emit(const UnauthenticatedState());
      } else {
        emit(AuthErrorState(result.fold((l) => l.message, (r) => 'Logout failed')));
      }
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }
  
  void _onRetry(
    AuthRetryEvent event,
    Emitter<AuthState> emit,
  ) {
    add(const AuthInitializeEvent());
  }
  
  Future<void> _onValidateConfig(
    AuthValidateConfigEvent event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _validateAuthConfigUseCase();
    
    if (result.isLeft()) {
      final failure = result.fold((l) => l, (r) => null);
      if (failure != null && failure.message.contains('missing')) {
        final missingVars = _parseMissingVariables(failure.message);
        emit(AuthConfigurationErrorState(missingVars));
      } else {
        emit(AuthErrorState(failure?.message ?? 'Configuration validation failed'));
      }
    }
  }
  
  Future<void> _onCheckStatus(
    AuthCheckStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final userResult = await _getUserProfileUseCase();
      
      if (userResult.isRight()) {
        final user = userResult.getOrElse(() => throw Exception('No user'));
        if (state is AuthenticatedState) {
          final currentState = state as AuthenticatedState;
          emit(AuthenticatedState(
            user: user,
            accessToken: currentState.accessToken,
            hasRefreshToken: currentState.hasRefreshToken,
          ));
        }
      }
    } catch (e) {
      // Don't emit error for status check failures
      if (kDebugMode) {
        print('Auth status check failed: $e');
      }
    }
  }
  
  List<String> _parseMissingVariables(String errorMessage) {
    // Parse missing variables from error message
    // This would depend on your specific error message format
    const requiredVars = [
      'AUTH0_DOMAIN',
      'AUTH0_CLIENT_ID',
      'AUTH0_CLIENT_SECRET',
      'AUTH0_AUDIENCE',
      'AUTH0_CALLBACK_URL',
    ];
    
    return requiredVars.where((varName) => errorMessage.contains(varName)).toList();
  }
  
  void _logAuth0Configuration() {
    // Equivalent to console.log in React
    print('Auth0 Configuration (SPA):');
    print('Domain: ${AppConstants.auth0Domain}');
    print('Client ID: ${AppConstants.auth0ClientId}');
    print('Has Client Secret: ${AppConstants.auth0ClientSecret.isNotEmpty}');
    print('Audience: ${AppConstants.auth0Audience.isNotEmpty ? AppConstants.auth0Audience : 'none (using default scopes)'}');
    print('Callback URL: ${AppConstants.auth0CallbackUrl}');
  }
}


// Auth wrapper widget that handles configuration errors
class AuthWrapper extends StatelessWidget {
  final Widget child;
  
  const AuthWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthConfigurationErrorState) {
          return AuthConfigurationErrorWidget(
            missingVariables: state.missingVariables,
          );
        }
        
        return child;
      },
    );
  }
}