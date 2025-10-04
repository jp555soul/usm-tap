import 'package:flutter/material.dart';
import 'dart:math' as math;

// ============================================================================
// LOADING SCREEN WIDGET
// ============================================================================

class LoadingScreen extends StatelessWidget {
  final String title;
  final String message;
  final String type;
  final double? progress;
  final List<LoadingDetail>? details;

  const LoadingScreen({
    Key? key,
    this.title = 'Loading Oceanographic Data',
    this.message = 'Loading data...',
    this.type = 'data',
    this.progress,
    this.details,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = _getColorScheme();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // slate-900
      body: Stack(
        children: [
          // Pulsing background effects
          Positioned(
            top: -160,
            right: -160,
            child: _PulsingCircle(
              size: 320,
              color: Colors.blue.withOpacity(0.05),
            ),
          ),
          Positioned(
            bottom: -160,
            left: -160,
            child: _PulsingCircle(
              size: 320,
              color: Colors.cyan.withOpacity(0.05),
              delay: const Duration(milliseconds: 1000),
            ),
          ),
          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448), // max-w-md
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Loading Animation
                    _buildLoadingAnimation(colors),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colors.titleColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Main Message
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 16,
                        color: colors.messageColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Progress Bar (if provided)
                    if (progress != null) ...[
                      _buildProgressBar(colors),
                      const SizedBox(height: 16),
                    ],

                    // Loading Details/Steps (if provided)
                    if (details != null && details!.isNotEmpty) ...[
                      _buildLoadingDetails(),
                      const SizedBox(height: 32),
                    ],

                    // USM/CubeAI Branding
                    _buildBranding(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingAnimation(LoadingColorScheme colors) {
    switch (type) {
      case 'data':
        return _DataLoadingAnimation(color: colors.progressColor);
      case 'processing':
        return _ProcessingAnimation(color: colors.progressColor);
      case 'connecting':
        return _ConnectingAnimation(color: colors.progressColor);
      default:
        return _DefaultLoadingAnimation(color: colors.progressColor);
    }
  }

  Widget _buildProgressBar(LoadingColorScheme colors) {
    final clampedProgress = (progress ?? 0).clamp(0.0, 100.0);

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF334155), // slate-700
            borderRadius: BorderRadius.circular(9999),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: clampedProgress / 100,
            child: Container(
              decoration: BoxDecoration(
                color: colors.progressColor,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${clampedProgress.round()}% Complete',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B), // slate-500
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingDetails() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.5), // slate-800/50
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Loading Progress:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCBD5E1), // slate-300
            ),
          ),
          const SizedBox(height: 8),
          ...details!.map((detail) => _buildLoadingDetailItem(detail)),
        ],
      ),
    );
  }

  Widget _buildLoadingDetailItem(LoadingDetail detail) {
    Color statusColor;
    Color textColor;

    switch (detail.status) {
      case LoadingStatus.completed:
        statusColor = Colors.green[400]!;
        textColor = Colors.green[300]!;
        break;
      case LoadingStatus.loading:
        statusColor = Colors.yellow[400]!;
        textColor = Colors.yellow[300]!;
        break;
      case LoadingStatus.error:
        statusColor = Colors.red[400]!;
        textColor = Colors.red[300]!;
        break;
      case LoadingStatus.pending:
      default:
        statusColor = const Color(0xFF475569); // slate-600
        textColor = const Color(0xFF94A3B8); // slate-400
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
            child: detail.status == LoadingStatus.loading
                ? _PulsingDot(color: statusColor)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail.message,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Text(
          'University of Southern Mississippi',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B), // slate-500
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Roger F. Wicker Center for Ocean Enterprise',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B), // slate-500
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF64748B),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Powered by CubeAI Technology',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF64748B),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  LoadingColorScheme _getColorScheme() {
    switch (type) {
      case 'data':
        return LoadingColorScheme(
          titleColor: Colors.blue[300]!,
          messageColor: const Color(0xFF94A3B8), // slate-400
          progressColor: Colors.blue[400]!,
        );
      case 'processing':
        return LoadingColorScheme(
          titleColor: Colors.green[300]!,
          messageColor: const Color(0xFF94A3B8),
          progressColor: Colors.green[400]!,
        );
      case 'connecting':
        return LoadingColorScheme(
          titleColor: Colors.cyan[300]!,
          messageColor: const Color(0xFF94A3B8),
          progressColor: Colors.cyan[400]!,
        );
      default:
        return LoadingColorScheme(
          titleColor: Colors.blue[300]!,
          messageColor: const Color(0xFF94A3B8),
          progressColor: Colors.blue[400]!,
        );
    }
  }
}

// ============================================================================
// COLOR SCHEME
// ============================================================================

class LoadingColorScheme {
  final Color titleColor;
  final Color messageColor;
  final Color progressColor;

  LoadingColorScheme({
    required this.titleColor,
    required this.messageColor,
    required this.progressColor,
  });
}

// ============================================================================
// LOADING DETAIL
// ============================================================================

enum LoadingStatus { completed, loading, error, pending }

class LoadingDetail {
  final String message;
  final LoadingStatus status;

  LoadingDetail({
    required this.message,
    required this.status,
  });
}

// ============================================================================
// LOADING ANIMATIONS
// ============================================================================

class _DataLoadingAnimation extends StatelessWidget {
  final Color color;

  const _DataLoadingAnimation({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          _PingingCircle(size: 64, color: color.withOpacity(0.3)),
          _PulsingCircle(size: 56, color: color.withOpacity(0.5)),
          Center(
            child: _PulsingIcon(
              icon: Icons.storage_rounded,
              color: color,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingAnimation extends StatelessWidget {
  final Color color;

  const _ProcessingAnimation({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          _SpinningCircle(size: 64, color: color.withOpacity(0.3)),
          _SpinningCircle(
            size: 56,
            color: color.withOpacity(0.5),
            reverse: true,
          ),
          Center(
            child: _PulsingIcon(
              icon: Icons.bar_chart_rounded,
              color: color,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectingAnimation extends StatelessWidget {
  final Color color;

  const _ConnectingAnimation({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          _PingingCircle(size: 64, color: color.withOpacity(0.3)),
          _PulsingCircle(size: 56, color: color.withOpacity(0.5)),
          Center(
            child: _BouncingIcon(
              icon: Icons.waves_rounded,
              color: color,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultLoadingAnimation extends StatelessWidget {
  final Color color;

  const _DefaultLoadingAnimation({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          _PingingCircle(size: 64, color: color.withOpacity(0.3)),
          _PulsingCircle(size: 56, color: color.withOpacity(0.5)),
          Center(
            child: _SpinningIcon(
              icon: Icons.refresh_rounded,
              color: color,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ANIMATED COMPONENTS
// ============================================================================

class _PingingCircle extends StatefulWidget {
  final double size;
  final Color color;

  const _PingingCircle({required this.size, required this.color});

  @override
  State<_PingingCircle> createState() => _PingingCircleState();
}

class _PingingCircleState extends State<_PingingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
              color: widget.color.withOpacity(1 - _controller.value),
              width: 4,
            ),
          ),
        );
      },
    );
  }
}

class _PulsingCircle extends StatefulWidget {
  final double size;
  final Color color;
  final Duration delay;

  const _PulsingCircle({
    required this.size,
    required this.color,
    this.delay = Duration.zero,
  });

  @override
  State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
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
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.7),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class _SpinningCircle extends StatefulWidget {
  final double size;
  final Color color;
  final bool reverse;

  const _SpinningCircle({
    required this.size,
    required this.color,
    this.reverse = false,
  });

  @override
  State<_SpinningCircle> createState() => _SpinningCircleState();
}

class _SpinningCircleState extends State<_SpinningCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
        return Transform.rotate(
          angle: (widget.reverse ? -1 : 1) * _controller.value * 2 * math.pi,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: widget.color, width: 4),
            ),
          ),
        );
      },
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _PulsingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
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
        return Opacity(
          opacity: 0.4 + (_controller.value * 0.6),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}

class _SpinningIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _SpinningIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}

class _BouncingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _BouncingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  State<_BouncingIcon> createState() => _BouncingIconState();
}

class _BouncingIconState extends State<_BouncingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_animation.value),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
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
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.5 + (_controller.value * 0.5)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

// ============================================================================
// PRE-CONFIGURED LOADING SCREEN VARIANTS
// ============================================================================

class DataLoadingScreen extends StatelessWidget {
  final String? title;
  final String? message;
  final double? progress;
  final List<LoadingDetail>? details;

  const DataLoadingScreen({
    Key? key,
    this.title,
    this.message,
    this.progress,
    this.details,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LoadingScreen(
      type: 'data',
      title: title ?? 'Loading Oceanographic Data',
      message: message ?? 'Loading data...',
      progress: progress,
      details: details,
    );
  }
}

class ProcessingScreen extends StatelessWidget {
  final String? title;
  final String? message;
  final double? progress;
  final List<LoadingDetail>? details;

  const ProcessingScreen({
    Key? key,
    this.title,
    this.message,
    this.progress,
    this.details,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LoadingScreen(
      type: 'processing',
      title: title ?? 'Processing Data',
      message: message ?? 'Analyzing oceanographic measurements...',
      progress: progress,
      details: details,
    );
  }
}

class ConnectingScreen extends StatelessWidget {
  final String? title;
  final String? message;
  final double? progress;
  final List<LoadingDetail>? details;

  const ConnectingScreen({
    Key? key,
    this.title,
    this.message,
    this.progress,
    this.details,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LoadingScreen(
      type: 'connecting',
      title: title ?? 'Connecting to Ocean Systems',
      message: message ?? 'Establishing connection to monitoring stations...',
      progress: progress,
      details: details,
    );
  }
}
