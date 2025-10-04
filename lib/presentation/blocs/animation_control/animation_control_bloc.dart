// lib/presentation/blocs/animation_control/animation_control_bloc.dart

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

// ============================================================================
// EVENTS
// ============================================================================

abstract class AnimationControlEvent extends Equatable {
  const AnimationControlEvent();

  @override
  List<Object?> get props => [];
}

class SetCurrentFrame extends AnimationControlEvent {
  final int frame;

  const SetCurrentFrame(this.frame);

  @override
  List<Object?> get props => [frame];
}

class SetPlaybackSpeed extends AnimationControlEvent {
  final double speed;

  const SetPlaybackSpeed(this.speed);

  @override
  List<Object?> get props => [speed];
}

class SetLoopMode extends AnimationControlEvent {
  final String mode;

  const SetLoopMode(this.mode);

  @override
  List<Object?> get props => [mode];
}

class TogglePlay extends AnimationControlEvent {
  const TogglePlay();
}

class PauseAnimation extends AnimationControlEvent {
  const PauseAnimation();
}

class ResetAnimation extends AnimationControlEvent {
  const ResetAnimation();
}

class JumpToFrame extends AnimationControlEvent {
  final int frame;

  const JumpToFrame(this.frame);

  @override
  List<Object?> get props => [frame];
}

class StepForward extends AnimationControlEvent {
  const StepForward();
}

class StepBackward extends AnimationControlEvent {
  const StepBackward();
}

class JumpToStart extends AnimationControlEvent {
  const JumpToStart();
}

class JumpToEnd extends AnimationControlEvent {
  const JumpToEnd();
}

class SetSpeedPreset extends AnimationControlEvent {
  final String preset;

  const SetSpeedPreset(this.preset);

  @override
  List<Object?> get props => [preset];
}

class UpdateAnimationConfig extends AnimationControlEvent {
  final Map<String, dynamic> config;

  const UpdateAnimationConfig(this.config);

  @override
  List<Object?> get props => [config];
}

class HandleKeyboardControl extends AnimationControlEvent {
  final LogicalKeyboardKey key;
  final bool ctrlPressed;
  final bool metaPressed;

  const HandleKeyboardControl({
    required this.key,
    this.ctrlPressed = false,
    this.metaPressed = false,
  });

  @override
  List<Object?> get props => [key, ctrlPressed, metaPressed];
}

class _AnimationTick extends AnimationControlEvent {
  const _AnimationTick();
}

// ============================================================================
// STATE
// ============================================================================

class AnimationControlState extends Equatable {
  final int currentFrame;
  final double playbackSpeed;
  final String loopMode;
  final int direction;
  final bool isPlaying;
  final AnimationConfig animationConfig;
  final int elapsedTime;
  final int? startTime;
  final double currentFPS;
  final int totalFrames;

  const AnimationControlState({
    required this.currentFrame,
    required this.playbackSpeed,
    required this.loopMode,
    required this.direction,
    required this.isPlaying,
    required this.animationConfig,
    required this.elapsedTime,
    this.startTime,
    required this.currentFPS,
    required this.totalFrames,
  });

  factory AnimationControlState.initial({int totalFrames = 24}) {
    return AnimationControlState(
      currentFrame: 0,
      playbackSpeed: 10.0,
      loopMode: 'Once',
      direction: 1,
      isPlaying: false,
      animationConfig: AnimationConfig.initial(),
      elapsedTime: 0,
      startTime: null,
      currentFPS: 0,
      totalFrames: totalFrames,
    );
  }

  // Animation progress calculation
  double get animationProgress {
    if (totalFrames <= 1) return 100.0;
    return (currentFrame / (totalFrames - 1)) * 100;
  }

  // Animation status
  String get animationStatus {
    if (totalFrames <= 1) return 'no-data';
    if (isPlaying) return 'playing';
    if (currentFrame == 0) return 'ready';
    if (currentFrame == totalFrames - 1) return 'complete';
    return 'paused';
  }

  // Animation info
  Map<String, dynamic> get animationInfo => {
        'currentFrame': currentFrame + 1, // 1-based for display
        'totalFrames': totalFrames,
        'progress': animationProgress,
        'status': animationStatus,
        'speed': playbackSpeed,
        'mode': loopMode,
        'fps': currentFPS,
        'elapsedTime': formatTime(elapsedTime),
        'direction': direction > 0 ? 'forward' : 'backward',
      };

  // Helper getters
  bool get isAtStart => currentFrame == 0;
  bool get isAtEnd => currentFrame == totalFrames - 1;
  bool get canPlay => totalFrames > 1;
  double get frameRate => playbackSpeed;

  // Time formatting
  String formatTime(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  AnimationControlState copyWith({
    int? currentFrame,
    double? playbackSpeed,
    String? loopMode,
    int? direction,
    bool? isPlaying,
    AnimationConfig? animationConfig,
    int? elapsedTime,
    int? startTime,
    double? currentFPS,
    int? totalFrames,
    bool clearStartTime = false,
  }) {
    return AnimationControlState(
      currentFrame: currentFrame ?? this.currentFrame,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      loopMode: loopMode ?? this.loopMode,
      direction: direction ?? this.direction,
      isPlaying: isPlaying ?? this.isPlaying,
      animationConfig: animationConfig ?? this.animationConfig,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      currentFPS: currentFPS ?? this.currentFPS,
      totalFrames: totalFrames ?? this.totalFrames,
    );
  }

  @override
  List<Object?> get props => [
        currentFrame,
        playbackSpeed,
        loopMode,
        direction,
        isPlaying,
        animationConfig,
        elapsedTime,
        startTime,
        currentFPS,
        totalFrames,
      ];
}

// ============================================================================
// ANIMATION CONFIG
// ============================================================================

class AnimationConfig extends Equatable {
  final bool smoothTransitions;
  final bool autoResetOnComplete;
  final bool syncWithRealTime;
  final bool frameSkipping;

  const AnimationConfig({
    required this.smoothTransitions,
    required this.autoResetOnComplete,
    required this.syncWithRealTime,
    required this.frameSkipping,
  });

  factory AnimationConfig.initial() {
    return const AnimationConfig(
      smoothTransitions: true,
      autoResetOnComplete: false,
      syncWithRealTime: false,
      frameSkipping: false,
    );
  }

  AnimationConfig copyWith({
    bool? smoothTransitions,
    bool? autoResetOnComplete,
    bool? syncWithRealTime,
    bool? frameSkipping,
  }) {
    return AnimationConfig(
      smoothTransitions: smoothTransitions ?? this.smoothTransitions,
      autoResetOnComplete: autoResetOnComplete ?? this.autoResetOnComplete,
      syncWithRealTime: syncWithRealTime ?? this.syncWithRealTime,
      frameSkipping: frameSkipping ?? this.frameSkipping,
    );
  }

  AnimationConfig copyWithMap(Map<String, dynamic> map) {
    return AnimationConfig(
      smoothTransitions: map['smoothTransitions'] ?? smoothTransitions,
      autoResetOnComplete: map['autoResetOnComplete'] ?? autoResetOnComplete,
      syncWithRealTime: map['syncWithRealTime'] ?? syncWithRealTime,
      frameSkipping: map['frameSkipping'] ?? frameSkipping,
    );
  }

  @override
  List<Object?> get props => [
        smoothTransitions,
        autoResetOnComplete,
        syncWithRealTime,
        frameSkipping,
      ];
}

// ============================================================================
// BLOC
// ============================================================================

class AnimationControlBloc extends Bloc<AnimationControlEvent, AnimationControlState> {
  static const double maxPlaybackSpeed = 20.0;
  static const double minPlaybackSpeed = 0.1;

  static const Map<String, double> speedPresets = {
    'Very Slow': 0.25,
    'Slow': 0.5,
    'Normal': 1.0,
    'Fast': 2.0,
    'Very Fast': 4.0,
    'Ultra Fast': 8.0,
  };

  Timer? _animationTimer;
  int _lastFrameTime = DateTime.now().millisecondsSinceEpoch;
  final List<int> _frameTimeHistory = [];

  AnimationControlBloc({int totalFrames = 24})
      : super(AnimationControlState.initial(totalFrames: totalFrames)) {
    on<SetCurrentFrame>(_onSetCurrentFrame);
    on<SetPlaybackSpeed>(_onSetPlaybackSpeed);
    on<SetLoopMode>(_onSetLoopMode);
    on<TogglePlay>(_onTogglePlay);
    on<PauseAnimation>(_onPauseAnimation);
    on<ResetAnimation>(_onResetAnimation);
    on<JumpToFrame>(_onJumpToFrame);
    on<StepForward>(_onStepForward);
    on<StepBackward>(_onStepBackward);
    on<JumpToStart>(_onJumpToStart);
    on<JumpToEnd>(_onJumpToEnd);
    on<SetSpeedPreset>(_onSetSpeedPreset);
    on<UpdateAnimationConfig>(_onUpdateAnimationConfig);
    on<HandleKeyboardControl>(_onHandleKeyboardControl);
    on<_AnimationTick>(_onAnimationTick);
  }

  // --- Set current frame with bounds checking ---
  void _onSetCurrentFrame(
    SetCurrentFrame event,
    Emitter<AnimationControlState> emit,
  ) {
    final validFrame = _clampFrame(event.frame);
    emit(state.copyWith(currentFrame: validFrame));
  }

  // --- Set playback speed with validation ---
  void _onSetPlaybackSpeed(
    SetPlaybackSpeed event,
    Emitter<AnimationControlState> emit,
  ) {
    final clampedSpeed = _clampSpeed(event.speed);
    emit(state.copyWith(playbackSpeed: clampedSpeed));
    
    // Restart timer with new speed if playing
    if (state.isPlaying) {
      _startAnimationTimer();
    }
  }

  // --- Set loop mode ---
  void _onSetLoopMode(
    SetLoopMode event,
    Emitter<AnimationControlState> emit,
  ) {
    const validModes = ['Repeat', 'Once', 'PingPong'];
    if (validModes.contains(event.mode)) {
      emit(state.copyWith(
        loopMode: event.mode,
        direction: 1, // Reset direction when changing modes
      ));
    }
  }

  // --- Toggle play/pause ---
  void _onTogglePlay(
    TogglePlay event,
    Emitter<AnimationControlState> emit,
  ) {
    if (state.isPlaying) {
      _stopAnimationTimer();
      emit(state.copyWith(isPlaying: false, clearStartTime: true));
    } else {
      emit(state.copyWith(isPlaying: true));
      _startAnimationTimer();
    }
  }

  // --- Pause animation ---
  void _onPauseAnimation(
    PauseAnimation event,
    Emitter<AnimationControlState> emit,
  ) {
    _stopAnimationTimer();
    emit(state.copyWith(isPlaying: false, clearStartTime: true));
  }

  // --- Reset animation ---
  void _onResetAnimation(
    ResetAnimation event,
    Emitter<AnimationControlState> emit,
  ) {
    _stopAnimationTimer();
    emit(state.copyWith(
      currentFrame: 0,
      isPlaying: false,
      elapsedTime: 0,
      direction: 1,
      clearStartTime: true,
    ));
  }

  // --- Jump to specific frame ---
  void _onJumpToFrame(
    JumpToFrame event,
    Emitter<AnimationControlState> emit,
  ) {
    final validFrame = _clampFrame(event.frame);
    emit(state.copyWith(currentFrame: validFrame));
    
    if (state.isPlaying) {
      _lastFrameTime = DateTime.now().millisecondsSinceEpoch;
    }
  }

  // --- Step forward ---
  void _onStepForward(
    StepForward event,
    Emitter<AnimationControlState> emit,
  ) {
    final nextFrame = _clampFrame(state.currentFrame + 1);
    emit(state.copyWith(currentFrame: nextFrame));
  }

  // --- Step backward ---
  void _onStepBackward(
    StepBackward event,
    Emitter<AnimationControlState> emit,
  ) {
    final prevFrame = _clampFrame(state.currentFrame - 1);
    emit(state.copyWith(currentFrame: prevFrame));
  }

  // --- Jump to start ---
  void _onJumpToStart(
    JumpToStart event,
    Emitter<AnimationControlState> emit,
  ) {
    emit(state.copyWith(currentFrame: 0));
  }

  // --- Jump to end ---
  void _onJumpToEnd(
    JumpToEnd event,
    Emitter<AnimationControlState> emit,
  ) {
    emit(state.copyWith(currentFrame: state.totalFrames - 1));
  }

  // --- Set speed preset ---
  void _onSetSpeedPreset(
    SetSpeedPreset event,
    Emitter<AnimationControlState> emit,
  ) {
    final speed = speedPresets[event.preset];
    if (speed != null) {
      add(SetPlaybackSpeed(speed));
    }
  }

  // --- Update animation configuration ---
  void _onUpdateAnimationConfig(
    UpdateAnimationConfig event,
    Emitter<AnimationControlState> emit,
  ) {
    final updatedConfig = state.animationConfig.copyWithMap(event.config);
    emit(state.copyWith(animationConfig: updatedConfig));
  }

  // --- Handle keyboard control ---
  void _onHandleKeyboardControl(
    HandleKeyboardControl event,
    Emitter<AnimationControlState> emit,
  ) {
    if (event.key == LogicalKeyboardKey.space) {
      add(const TogglePlay());
    } else if (event.key == LogicalKeyboardKey.arrowRight) {
      add(const StepForward());
    } else if (event.key == LogicalKeyboardKey.arrowLeft) {
      add(const StepBackward());
    } else if (event.key == LogicalKeyboardKey.home) {
      add(const JumpToStart());
    } else if (event.key == LogicalKeyboardKey.end) {
      add(const JumpToEnd());
    } else if (event.key == LogicalKeyboardKey.keyR && 
               (event.ctrlPressed || event.metaPressed)) {
      add(const ResetAnimation());
    }
  }

  // --- Animation tick (main loop) ---
  void _onAnimationTick(
    _AnimationTick event,
    Emitter<AnimationControlState> emit,
  ) {
    if (!state.isPlaying || state.totalFrames <= 1) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final deltaTime = now - _lastFrameTime;

    // Update FPS calculation
    _frameTimeHistory.add(deltaTime);
    if (_frameTimeHistory.length > 10) {
      _frameTimeHistory.removeAt(0);
    }
    final avgFrameTime = _frameTimeHistory.isNotEmpty
        ? _frameTimeHistory.reduce((a, b) => a + b) / _frameTimeHistory.length
        : 0;
    final fps = avgFrameTime > 0 ? (1000 / avgFrameTime).round().toDouble() : 0.0;

    // Calculate next frame
    final nextFrame = _calculateNextFrame(state.currentFrame, state.direction);
    
    emit(state.copyWith(
      currentFrame: nextFrame['frame'],
      direction: nextFrame['direction'],
      elapsedTime: state.elapsedTime + deltaTime,
      currentFPS: fps,
    ));

    _lastFrameTime = now;
  }

  // --- Calculate next frame based on loop mode ---
  Map<String, int> _calculateNextFrame(int current, int dir) {
    switch (state.loopMode) {
      case 'Once':
        if (current >= state.totalFrames - 1) {
          add(const PauseAnimation());
          return {'frame': current, 'direction': dir};
        }
        return {'frame': current + 1, 'direction': dir};

      case 'PingPong':
        int nextFrame = current + dir;
        int nextDirection = dir;

        if (nextFrame >= state.totalFrames - 1) {
          nextFrame = state.totalFrames - 1;
          nextDirection = -1;
        } else if (nextFrame <= 0) {
          nextFrame = 0;
          nextDirection = 1;
        }

        return {'frame': nextFrame, 'direction': nextDirection};

      case 'Repeat':
      default:
        final nextFrame = current >= state.totalFrames - 1 ? 0 : current + 1;
        return {'frame': nextFrame, 'direction': dir};
    }
  }

  // --- Helper: Clamp frame to valid range ---
  int _clampFrame(int frame) {
    return frame.clamp(0, state.totalFrames - 1);
  }

  // --- Helper: Clamp speed to valid range ---
  double _clampSpeed(double speed) {
    return speed.clamp(minPlaybackSpeed, maxPlaybackSpeed);
  }

  // --- Start animation timer ---
  void _startAnimationTimer() {
    _stopAnimationTimer();
    
    if (state.startTime == null) {
      _lastFrameTime = DateTime.now().millisecondsSinceEpoch;
    }
    
    final intervalMs = (1000 / state.playbackSpeed).round();
    _animationTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => add(const _AnimationTick()),
    );
  }

  // --- Stop animation timer ---
  void _stopAnimationTimer() {
    _animationTimer?.cancel();
    _animationTimer = null;
  }

  @override
  Future<void> close() {
    _stopAnimationTimer();
    return super.close();
  }
}