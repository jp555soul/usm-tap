// ============================================================================
// FILE: lib/presentation/widgets/tutorial/tutorial.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tutorial_modal.dart';
import 'tutorial_steps.dart';
import 'dart:ui';

class TutorialWidget extends StatefulWidget {
  final bool isOpen;
  final VoidCallback? onClose;
  final VoidCallback? onComplete;
  final int tutorialStep;
  final ValueChanged<int>? onStepChange;

  const TutorialWidget({
    Key? key,
    this.isOpen = false,
    this.onClose,
    this.onComplete,
    this.tutorialStep = 0,
    this.onStepChange,
  }) : super(key: key);

  @override
  State<TutorialWidget> createState() => _TutorialWidgetState();
}

class _TutorialWidgetState extends State<TutorialWidget> {
  late int _currentStep;
  bool _isAnimating = false;
  Set<int> _completedSteps = {};
  final _tutorialSteps = tutorialSteps;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.tutorialStep;
  }

  @override
  void didUpdateWidget(TutorialWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tutorialStep != oldWidget.tutorialStep) {
      setState(() => _currentStep = widget.tutorialStep);
    }
  }

  void _goToStep(int stepIndex) {
    if (stepIndex >= 0 && stepIndex < _tutorialSteps.length) {
      setState(() {
        _isAnimating = true;
        _completedSteps.add(_currentStep);
      });

      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _currentStep = stepIndex;
            _isAnimating = false;
          });
          widget.onStepChange?.call(stepIndex);
        }
      });
    }
  }

  void _nextStep() => _goToStep(_currentStep + 1);
  void _prevStep() => _goToStep(_currentStep - 1);

  void _completeTutorial() {
    setState(() => _completedSteps.add(_currentStep));
    widget.onComplete?.call();
  }

  void _restartTutorial() {
    setState(() {
      _currentStep = 0;
      _completedSteps.clear();
    });
    widget.onStepChange?.call(0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final currentStepData = _tutorialSteps[_currentStep];

    return KeyboardListener(
      autofocus: true,
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;

        if ((event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.enter) &&
            currentStepData.actions.contains('next')) {
          _nextStep();
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            currentStepData.actions.contains('prev')) {
          _prevStep();
        }
      },
      child: TutorialModal(
        isOpen: widget.isOpen,
        onClose: widget.onClose,
        title: currentStepData.title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSubtitle(currentStepData),
            _buildProgressBar(),
            _buildContent(currentStepData),
            _buildNavigation(currentStepData),
            _buildStepIndicators(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle(TutorialStep step) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF334155),
            width: 0.5,
          ),
        ),
      ),
      child: Text(
        'Step ${_currentStep + 1} of ${_tutorialSteps.length}: ${step.subtitle}',
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentStep + 1) / _tutorialSteps.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                  ),
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progress',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(fontSize: 12, color: Colors.blue[300]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(TutorialStep step) {
    return Flexible(
      child: AnimatedOpacity(
        opacity: _isAnimating ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            step.content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFE2E8F0),
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigation(TutorialStep step) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF334155), width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (step.actions.contains('prev'))
                ElevatedButton.icon(
                  onPressed: _currentStep == 0 ? null : _prevStep,
                  icon: const Icon(Icons.chevron_left_rounded, size: 16),
                  label: const Text('Previous'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF475569),
                    disabledBackgroundColor: const Color(0xFF334155),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              if (step.actions.contains('restart')) ...[
                if (step.actions.contains('prev')) const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _restartTutorial,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Restart'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF475569),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
          Row(
            children: [
              if (step.actions.contains('next'))
                ElevatedButton.icon(
                  onPressed: _nextStep,
                  icon: const Icon(Icons.chevron_right_rounded, size: 16),
                  label: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              if (step.actions.contains('complete'))
                ElevatedButton.icon(
                  onPressed: _completeTutorial,
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Complete Tutorial'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicators() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_tutorialSteps.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = _completedSteps.contains(index);

          return GestureDetector(
            onTap: () => _goToStep(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.blue[400]
                    : isCompleted
                        ? Colors.green[500]
                        : const Color(0xFF475569),
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          );
        }),
      ),
    );
  }
}
