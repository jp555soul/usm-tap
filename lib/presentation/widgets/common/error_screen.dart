import 'package:flutter/material.dart';
import 'dart:convert';

// ============================================================================
// ERROR SCREEN WIDGET
// ============================================================================

class ErrorScreen extends StatelessWidget {
  final String type;
  final String? title;
  final String? message;
  final dynamic details;
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;
  final bool showContactInfo;
  final List<ErrorAction> customActions;

  const ErrorScreen({
    Key? key,
    this.type = 'general',
    this.title,
    this.message,
    this.details,
    this.onRetry,
    this.onGoHome,
    this.showContactInfo = true,
    this.customActions = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = _getErrorConfig();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // slate-900
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672), // max-w-2xl
            child: Stack(
              children: [
                // Subtle background effects
                Positioned(
                  top: -80,
                  right: -80,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: -80,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Main content
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: config.gradientColors,
                    ),
                    border: Border.all(color: config.borderColor, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Error Icon
                      _buildErrorIcon(config),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        config.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Main Message
                      Text(
                        config.message,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFFCBD5E1), // slate-300
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Error Details (if provided)
                      if (details != null) ...[
                        _buildErrorDetails(),
                        const SizedBox(height: 24),
                      ],

                      // Suggested Solutions
                      _buildSuggestions(config),
                      const SizedBox(height: 24),

                      // Action Buttons
                      _buildActionButtons(context),

                      // Contact Information
                      if (showContactInfo) ...[
                        const SizedBox(height: 32),
                        _buildContactInfo(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorIcon(ErrorConfig config) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          // Background circle
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B), // slate-800
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  config.icon,
                  size: 40,
                  color: config.iconColor,
                ),
              ),
            ),
          ),
          // Animated border
          Center(
            child: _PulsingBorder(
              size: 80,
              color: const Color(0xFF475569), // slate-600
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDetails() {
    final detailsText = details is String
        ? details as String
        : const JsonEncoder.withIndent('  ').convert(details);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.5), // slate-800/50
        border: Border.all(color: const Color(0xFF334155)), // slate-700
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Colors.yellow[400],
              ),
              const SizedBox(width: 8),
              const Text(
                'Error Details',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE2E8F0), // slate-200
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.5), // slate-900/50
              border: Border.all(color: const Color(0xFF334155)),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                detailsText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8), // slate-400
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(ErrorConfig config) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.3), // slate-800/30
        border: Border.all(color: const Color(0xFF334155)), // slate-700
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 16,
                color: Colors.blue[400],
              ),
              const SizedBox(width: 8),
              const Text(
                'Suggested Solutions',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE2E8F0), // slate-200
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...config.suggestions.map((suggestion) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '•',
                        style: TextStyle(
                          color: Colors.blue[400],
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFCBD5E1), // slate-300
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final buttons = <Widget>[];

    if (onRetry != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB), // blue-600
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    if (onGoHome != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: onGoHome,
          icon: const Icon(Icons.home_rounded, size: 16),
          label: const Text('Go Home'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF334155), // slate-700
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    // Add custom actions
    for (final action in customActions) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: action.onPressed,
          icon: action.icon != null
              ? Icon(action.icon, size: 16)
              : const SizedBox.shrink(),
          label: Text(action.label),
          style: ElevatedButton.styleFrom(
            backgroundColor: action.backgroundColor ?? const Color(0xFF334155),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: buttons,
    );
  }

  Widget _buildContactInfo() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF334155)), // slate-700
        ),
      ),
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          const Text(
            'Need Additional Help?',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCBD5E1), // slate-300
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'University of Southern Mississippi',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8), // slate-400
            ),
          ),
          const Text(
            'Roger F. Wicker Center for Ocean Enterprise',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8), // slate-400
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () {
                  // Navigate to documentation
                },
                icon: Icon(
                  Icons.open_in_new_rounded,
                  size: 12,
                  color: Colors.blue[400],
                ),
                label: Text(
                  'Documentation',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[400],
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () {
                  // Navigate to support
                },
                icon: Icon(
                  Icons.open_in_new_rounded,
                  size: 12,
                  color: Colors.blue[400],
                ),
                label: Text(
                  'Support',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[400],
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ErrorConfig _getErrorConfig() {
    switch (type) {
      case 'no-data':
        return ErrorConfig(
          icon: Icons.storage_rounded,
          iconColor: Colors.red[400]!,
          gradientColors: [
            Colors.red.shade900.withOpacity(0.2),
            Colors.red.shade800.withOpacity(0.1),
          ],
          borderColor: Colors.red.shade500.withOpacity(0.3),
          title: title ?? 'No Data Available',
          message: message ?? 'API endpoint is not available.',
          suggestions: const ['Contact Admin'],
        );

      case 'network':
        return ErrorConfig(
          icon: Icons.wifi_off_rounded,
          iconColor: Colors.orange[400]!,
          gradientColors: [
            Colors.orange.shade900.withOpacity(0.2),
            Colors.orange.shade800.withOpacity(0.1),
          ],
          borderColor: Colors.orange.shade500.withOpacity(0.3),
          title: title ?? 'Network Connection Error',
          message: message ??
              'Unable to connect to data sources or external services.',
          suggestions: const [
            'Check your internet connection',
            'Verify API endpoints are accessible',
            'Check firewall and proxy settings',
            'Try refreshing the page',
          ],
        );

      case 'validation':
        return ErrorConfig(
          icon: Icons.error_outline_rounded,
          iconColor: Colors.yellow[400]!,
          gradientColors: [
            Colors.yellow.shade900.withOpacity(0.2),
            Colors.yellow.shade800.withOpacity(0.1),
          ],
          borderColor: Colors.yellow.shade500.withOpacity(0.3),
          title: title ?? 'Data Validation Error',
          message: message ??
              'The loaded data contains invalid or corrupted information.',
          suggestions: const [
            'Check the data format and required fields',
            'Verify latitude/longitude coordinates are valid',
            'Ensure date/time fields are properly formatted',
            'Remove any special characters or empty rows',
          ],
        );

      case 'map':
        return ErrorConfig(
          icon: Icons.location_off_rounded,
          iconColor: Colors.purple[400]!,
          gradientColors: [
            Colors.purple.shade900.withOpacity(0.2),
            Colors.purple.shade800.withOpacity(0.1),
          ],
          borderColor: Colors.purple.shade500.withOpacity(0.3),
          title: title ?? 'Map Initialization Error',
          message:
              message ?? 'Unable to initialize the interactive map component.',
          suggestions: const [
            'Check Mapbox access token configuration',
            'Verify WebGL support in your browser',
            'Clear browser cache and reload',
            'Try using a different browser',
          ],
        );

      case 'api':
        return ErrorConfig(
          icon: Icons.settings_rounded,
          iconColor: Colors.indigo[400]!,
          gradientColors: [
            Colors.indigo.shade900.withOpacity(0.2),
            Colors.indigo.shade800.withOpacity(0.1),
          ],
          borderColor: Colors.indigo.shade500.withOpacity(0.3),
          title: title ?? 'API Connection Error',
          message: message ??
              'Unable to connect to the oceanographic data API.',
          suggestions: const [
            'Verify API endpoint URL is correct',
            'Check API authentication credentials',
            'Confirm API server is running and accessible',
            'Review API rate limits and quotas',
          ],
        );

      default:
        return ErrorConfig(
          icon: Icons.cancel_rounded,
          iconColor: Colors.red[400]!,
          gradientColors: [
            Colors.red.shade900.withOpacity(0.2),
            const Color(0xFF1E293B).withOpacity(0.1),
          ],
          borderColor: Colors.red.shade500.withOpacity(0.3),
          title: title ?? 'Application Error',
          message: message ??
              'An unexpected error occurred while running the oceanographic platform.',
          suggestions: const [
            'Try refreshing the browser page',
            'Clear browser cache and cookies',
            'Check browser console for error details',
            'Contact support if the issue persists',
          ],
        );
    }
  }
}

// ============================================================================
// ERROR CONFIG
// ============================================================================

class ErrorConfig {
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;
  final Color borderColor;
  final String title;
  final String message;
  final List<String> suggestions;

  ErrorConfig({
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
    required this.borderColor,
    required this.title,
    required this.message,
    required this.suggestions,
  });
}

// ============================================================================
// ERROR ACTION
// ============================================================================

class ErrorAction {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;

  ErrorAction({
    required this.label,
    this.icon,
    required this.onPressed,
    this.backgroundColor,
  });
}

// ============================================================================
// PULSING BORDER ANIMATION
// ============================================================================

class _PulsingBorder extends StatefulWidget {
  final double size;
  final Color color;

  const _PulsingBorder({
    required this.size,
    required this.color,
  });

  @override
  State<_PulsingBorder> createState() => _PulsingBorderState();
}

class _PulsingBorderState extends State<_PulsingBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withOpacity(_controller.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// PRE-CONFIGURED ERROR SCREEN VARIANTS
// ============================================================================

class NoDataError extends StatelessWidget {
  final String? title;
  final String? message;
  final dynamic details;
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;
  final bool showContactInfo;
  final List<ErrorAction> customActions;

  const NoDataError({
    Key? key,
    this.title,
    this.message,
    this.details,
    this.onRetry,
    this.onGoHome,
    this.showContactInfo = true,
    this.customActions = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ErrorScreen(
      type: 'no-data',
      title: title,
      message: message,
      details: details,
      onRetry: onRetry,
      onGoHome: onGoHome,
      showContactInfo: showContactInfo,
      customActions: customActions,
    );
  }
}

class NetworkError extends StatelessWidget {
  final String? title;
  final String? message;
  final dynamic details;
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;
  final bool showContactInfo;
  final List<ErrorAction> customActions;

  const NetworkError({
    Key? key,
    this.title,
    this.message,
    this.details,
    this.onRetry,
    this.onGoHome,
    this.showContactInfo = true,
    this.customActions = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ErrorScreen(
      type: 'network',
      title: title,
      message: message,
      details: details,
      onRetry: onRetry,
      onGoHome: onGoHome,
      showContactInfo: showContactInfo,
      customActions: customActions,
    );
  }
}

class DataValidationError extends StatelessWidget {
  final String? title;
  final String? message;
  final dynamic details;
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;
  final bool showContactInfo;
  final List<ErrorAction> customActions;

  const DataValidationError({
    Key? key,
    this.title,
    this.message,
    this.details,
    this.onRetry,
    this.onGoHome,
    this.showContactInfo = true,
    this.customActions = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ErrorScreen(
      type: 'validation',
      title: title,
      message: message,
      details: details,
      onRetry: onRetry,
      onGoHome: onGoHome,
      showContactInfo: showContactInfo,
      customActions: customActions,
    );
  }
}

class MapError extends StatelessWidget {
  final String? title;
  final String? message;
  final dynamic details;
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;
  final bool showContactInfo;
  final List<ErrorAction> customActions;

  const MapError({
    Key? key,
    this.title,
    this.message,
    this.details,
    this.onRetry,
    this.onGoHome,
    this.showContactInfo = true,
    this.customActions = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ErrorScreen(
      type: 'map',
      title: title,
      message: message,
      details: details,
      onRetry: onRetry,
      onGoHome: onGoHome,
      showContactInfo: showContactInfo,
      customActions: customActions,
    );
  }
}

class APIError extends StatelessWidget {
  final String? title;
  final String? message;
  final dynamic details;
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;
  final bool showContactInfo;
  final List<ErrorAction> customActions;

  const APIError({
    Key? key,
    this.title,
    this.message,
    this.details,
    onRetry,
    this.onGoHome,
    this.showContactInfo = true,
    this.customActions = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ErrorScreen(
      type: 'api',
      title: title,
      message: message,
      details: details,
      onRetry: onRetry,
      onGoHome: onGoHome,
      showContactInfo: showContactInfo,
      customActions: customActions,
    );
  }
}