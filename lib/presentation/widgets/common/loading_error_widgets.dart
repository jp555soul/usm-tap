// lib/presentation/widgets/common/loading_error_widgets.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/ocean_data/ocean_data_bloc.dart';
import 'error_screen.dart';

/// Loading screen widget equivalent to React LoadingScreen component
/// Shows a loading spinner while the INITIAL data is being fetched
class LoadingScreen extends StatelessWidget {
  final String? message;
  
  const LoadingScreen({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // bg-slate-900
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 24),
            Text(
              message ?? 'Loading...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple error screen widget for basic error display
/// For more comprehensive error handling, use the full ErrorScreen widget
class SimpleErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  
  const SimpleErrorScreen({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // bg-slate-900
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              const Text(
                'Error Loading Data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (onRetry != null)
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper widget that handles global loading and error states
/// Equivalent to the conditional rendering in OceanDataProvider
/// Uses the comprehensive ErrorScreen for better error handling
class OceanDataStateWrapper extends StatelessWidget {
  final Widget child;
  
  const OceanDataStateWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OceanDataBloc, OceanDataState>(
      builder: (context, state) {
        // Show a loading spinner only while the INITIAL data is being fetched
        if (state is OceanDataLoadingState && state.isInitialLoad) {
          return const LoadingScreen();
        }
        
        if (state is OceanDataErrorState) {
          // Show comprehensive error screen with type detection
          return ErrorScreen(
            type: _detectErrorType(state.message),
            message: state.message,
            details: state.details,
            onRetry: () {
              context.read<OceanDataBloc>().add(const LoadInitialDataEvent());
            },
            onGoHome: () {
              Navigator.of(context).pushReplacementNamed('/');
            },
          );
        }
        
        // Render children for loaded state
        return child;
      },
    );
  }

  /// Detect error type based on error message
  String _detectErrorType(String message) {
    final lowerMessage = message.toLowerCase();
    
    if (lowerMessage.contains('network') || 
        lowerMessage.contains('connection') ||
        lowerMessage.contains('timeout')) {
      return 'network';
    } else if (lowerMessage.contains('validation') || 
               lowerMessage.contains('invalid') ||
               lowerMessage.contains('corrupted')) {
      return 'validation';
    } else if (lowerMessage.contains('api') || 
               lowerMessage.contains('endpoint')) {
      return 'api';
    } else if (lowerMessage.contains('map') || 
               lowerMessage.contains('mapbox')) {
      return 'map';
    } else if (lowerMessage.contains('no data') || 
               lowerMessage.contains('empty') ||
               lowerMessage.contains('not found')) {
      return 'no-data';
    }
    
    return 'general';
  }
}