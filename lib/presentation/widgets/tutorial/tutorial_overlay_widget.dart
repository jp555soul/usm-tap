// ============================================================================
// FILE: lib/presentation/widgets/tutorial/tutorial_overlay.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'dart:async';

class TutorialOverlayWidget extends StatefulWidget {
  final bool isActive;
  final String? targetSelector;
  final String highlightType;
  final double overlayOpacity;
  final double spotlightPadding;
  final bool showPointer;
  final String? pointerText;
  final VoidCallback? onTargetClick;

  const TutorialOverlayWidget({
    Key? key,
    this.isActive = false,
    this.targetSelector,
    this.highlightType = 'spotlight',
    this.overlayOpacity = 0.7,
    this.spotlightPadding = 8,
    this.showPointer = false,
    this.pointerText,
    this.onTargetClick,
  }) : super(key: key);

  @override
  State<TutorialOverlayWidget> createState() => _TutorialOverlayWidgetState();
}

class _TutorialOverlayWidgetState extends State<TutorialOverlayWidget>
    with SingleTickerProviderStateMixin {
  Rect? _targetBounds;
  bool _isVisible = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    if (widget.isActive && widget.targetSelector != null) {
      _findTarget();
    }
  }

  @override
  void didUpdateWidget(TutorialOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive ||
        widget.targetSelector != oldWidget.targetSelector) {
      if (widget.isActive && widget.targetSelector != null) {
        _findTarget();
      } else {
        setState(() {
          _targetBounds = null;
          _isVisible = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _findTarget() {
    // In Flutter, you'd use GlobalKey to find widgets
    // This is a placeholder - implement based on your widget tree
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        // Simulate finding a target - replace with actual implementation
        setState(() {
          _targetBounds = const Rect.fromLTWH(100, 200, 300, 100);
          _isVisible = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive || !_isVisible || _targetBounds == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        _buildHighlight(),
        if (widget.showPointer) _buildPointer(),
        _buildCornerIndicator(),
      ],
    );
  }

  Widget _buildHighlight() {
    switch (widget.highlightType) {
      case 'outline':
        return _buildOutlineHighlight();
      case 'glow':
        return _buildGlowHighlight();
      case 'pulse':
        return _buildPulseHighlight();
      default:
        return _buildSpotlightHighlight();
    }
  }

  Widget _buildSpotlightHighlight() {
    return CustomPaint(
      size: Size.infinite,
      painter: _SpotlightPainter(
        targetBounds: _targetBounds!,
        padding: widget.spotlightPadding,
        overlayOpacity: widget.overlayOpacity,
      ),
    );
  }

  Widget _buildOutlineHighlight() {
    return Stack(
      children: [
        Container(color: Colors.black.withOpacity(widget.overlayOpacity)),
        Positioned(
          left: _targetBounds!.left - widget.spotlightPadding,
          top: _targetBounds!.top - widget.spotlightPadding,
          width: _targetBounds!.width + widget.spotlightPadding * 2,
          height: _targetBounds!.height + widget.spotlightPadding * 2,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue[400]!, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue[400]!.withOpacity(0.6),
                      blurRadius: 20,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGlowHighlight() {
    return Positioned(
      left: _targetBounds!.left - widget.spotlightPadding,
      top: _targetBounds!.top - widget.spotlightPadding,
      width: _targetBounds!.width + widget.spotlightPadding * 2,
      height: _targetBounds!.height + widget.spotlightPadding * 2,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue[400]!.withOpacity(0.4),
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.blue[400]!.withOpacity(0.2),
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: Colors.blue[400]!.withOpacity(0.6),
                  blurRadius: 20,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPulseHighlight() {
    return Positioned(
      left: _targetBounds!.left - widget.spotlightPadding,
      top: _targetBounds!.top - widget.spotlightPadding,
      width: _targetBounds!.width + widget.spotlightPadding * 2,
      height: _targetBounds!.height + widget.spotlightPadding * 2,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue[400]!, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue[300]!, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[400]!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPointer() {
    return Positioned(
      left: _targetBounds!.center.dx - 50,
      top: _targetBounds!.bottom + 20,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _pulseController.value * 10),
                child: Icon(
                  Icons.arrow_downward_rounded,
                  color: Colors.blue[400],
                  size: 24,
                ),
              );
            },
          ),
          if (widget.pointerText != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.9),
                border: Border.all(color: Colors.blue[400]!.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.pointerText!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[300],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCornerIndicator() {
    return Positioned(
      left: _targetBounds!.left - widget.spotlightPadding - 12,
      top: _targetBounds!.top - widget.spotlightPadding - 12,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _pulseController.value * 6.28,
            child: Icon(
              Icons.gps_fixed_rounded,
              color: Colors.blue[400],
              size: 24,
            ),
          );
        },
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect targetBounds;
  final double padding;
  final double overlayOpacity;

  _SpotlightPainter({
    required this.targetBounds,
    required this.padding,
    required this.overlayOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(overlayOpacity)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        targetBounds.inflate(padding),
        const Radius.circular(8),
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.blue[400]!.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        targetBounds.inflate(padding),
        const Radius.circular(8),
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) => true;
}