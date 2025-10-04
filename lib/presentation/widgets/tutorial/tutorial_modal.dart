// ============================================================================
// FILE: lib/presentation/widgets/tutorial/tutorial_modal.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TutorialModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback? onClose;
  final String title;
  final Widget child;
  final String size;
  final String position;
  final bool showCloseButton;
  final bool closeOnBackdrop;
  final bool closeOnEscape;

  const TutorialModal({
    Key? key,
    this.isOpen = false,
    this.onClose,
    this.title = 'Tutorial',
    required this.child,
    this.size = 'default',
    this.position = 'center',
    this.showCloseButton = true,
    this.closeOnBackdrop = true,
    this.closeOnEscape = true,
  }) : super(key: key);

  @override
  State<TutorialModal> createState() => _TutorialModalState();
}

class _TutorialModalState extends State<TutorialModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  FocusNode? _firstFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.isOpen) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(TutorialModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _controller.forward();
    } else if (!widget.isOpen && oldWidget.isOpen) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _firstFocusNode?.dispose();
    super.dispose();
  }

  double _getMaxWidth() {
    switch (widget.size) {
      case 'sm':
        return 384;
      case 'lg':
        return 672;
      case 'xl':
        return 896;
      case 'full':
        return double.infinity;
      default:
        return 512;
    }
  }

  MainAxisAlignment _getAlignment() {
    switch (widget.position) {
      case 'top':
        return MainAxisAlignment.start;
      case 'bottom':
        return MainAxisAlignment.end;
      default:
        return MainAxisAlignment.center;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    return KeyboardListener(
      autofocus: true,
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (widget.closeOnEscape &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose?.call();
        }
      },
      child: GestureDetector(
        onTap: widget.closeOnBackdrop ? widget.onClose : null,
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Column(
              mainAxisAlignment: _getAlignment(),
              children: [
                if (widget.position == 'top') const SizedBox(height: 64),
                Flexible(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _opacityAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: _getMaxWidth(),
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.9,
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.95),
                          border: Border.all(
                            color: Colors.blue[400]!.withOpacity(0.5),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeader(),
                            Flexible(child: widget.child),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.position == 'bottom') const SizedBox(height: 64),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF334155),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue[500]!.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.help_outline_rounded,
              color: Colors.blue[400],
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.blue[300],
              ),
            ),
          ),
          if (widget.showCloseButton)
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded),
              color: const Color(0xFF94A3B8),
              tooltip: 'Close modal',
            ),
        ],
      ),
    );
  }
}