// lib/presentation/blocs/animation/animation_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/usecases/animation/control_animation_usecase.dart';

// Events
abstract class AnimationEvent extends Equatable {
  const AnimationEvent();

  @override
  List<Object?> get props => [];
}

class PlayAnimationEvent extends AnimationEvent {
  const PlayAnimationEvent();
}

class PauseAnimationEvent extends AnimationEvent {
  const PauseAnimationEvent();
}

class StopAnimationEvent extends AnimationEvent {
  const StopAnimationEvent();
}

class ResetAnimationEvent extends AnimationEvent {
  const ResetAnimationEvent();
}

class SetAnimationSpeedEvent extends AnimationEvent {
  final double speed;

  const SetAnimationSpeedEvent(this.speed);

  @override
  List<Object?> get props => [speed];
}

class SpeedUpAnimationEvent extends AnimationEvent {
  const SpeedUpAnimationEvent();
}

class SpeedDownAnimationEvent extends AnimationEvent {
  const SpeedDownAnimationEvent();
}

class SetAnimationFrameEvent extends AnimationEvent {
  final int frame;

  const SetAnimationFrameEvent(this.frame);

  @override
  List<Object?> get props => [frame];
}

class UpdateAnimationProgressEvent extends AnimationEvent {
  final int currentFrame;
  final int totalFrames;

  const UpdateAnimationProgressEvent({
    required this.currentFrame,
    required this.totalFrames,
  });

  @override
  List<Object?> get props => [currentFrame, totalFrames];
}

class SyncAnimationDataEvent extends AnimationEvent {
  final int totalFrames;

  const SyncAnimationDataEvent(this.totalFrames);

  @override
  List<Object?> get props => [totalFrames];
}

class TickAnimationEvent extends AnimationEvent {
  const TickAnimationEvent();
}

// States
abstract class AnimationBlocState extends Equatable {
  const AnimationBlocState();

  @override
  List<Object?> get props => [];
}

class AnimationInitial extends AnimationBlocState {
  const AnimationInitial();
}

class AnimationPlaying extends AnimationBlocState {
  final double speed;
  final int currentFrame;
  final int totalFrames;
  final double progress;

  const AnimationPlaying({
    required this.speed,
    required this.currentFrame,
    required this.totalFrames,
    required this.progress,
  });

  @override
  List<Object?> get props => [speed, currentFrame, totalFrames, progress];
}

class AnimationPaused extends AnimationBlocState {
  final double speed;
  final int currentFrame;
  final int totalFrames;
  final double progress;

  const AnimationPaused({
    required this.speed,
    required this.currentFrame,
    required this.totalFrames,
    required this.progress,
  });

  @override
  List<Object?> get props => [speed, currentFrame, totalFrames, progress];
}

class AnimationStopped extends AnimationBlocState {
  final double speed;
  final int totalFrames;

  const AnimationStopped({
    required this.speed,
    required this.totalFrames,
  });

  @override
  List<Object?> get props => [speed, totalFrames];
}

class AnimationError extends AnimationBlocState {
  final String message;

  const AnimationError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class AnimationBloc extends Bloc<AnimationEvent, AnimationBlocState> {
  final ControlAnimationUseCase _controlAnimationUseCase;
  Timer? _animationTimer;

  AnimationBloc({ControlAnimationUseCase? controlAnimationUseCase})
      : _controlAnimationUseCase = controlAnimationUseCase ?? ControlAnimationUseCase(),
        super(const AnimationInitial()) {
    on<PlayAnimationEvent>(_onPlay);
    on<PauseAnimationEvent>(_onPause);
    on<StopAnimationEvent>(_onStop);
    on<ResetAnimationEvent>(_onReset);
    on<SetAnimationSpeedEvent>(_onSetSpeed);
    on<SpeedUpAnimationEvent>(_onSpeedUp);
    on<SpeedDownAnimationEvent>(_onSpeedDown);
    on<SetAnimationFrameEvent>(_onSetFrame);
    on<UpdateAnimationProgressEvent>(_onUpdateProgress);
    on<TickAnimationEvent>(_onTick);
    on<SyncAnimationDataEvent>(_onSyncData);
  }

  Future<void> _onPlay(
    PlayAnimationEvent event,
    Emitter<AnimationBlocState> emit,
  ) async {
    // Get current totalFrames from state to pass to UseCase
    int currentTotalFrames = 0;
    if (state is AnimationPaused) {
      currentTotalFrames = (state as AnimationPaused).totalFrames;
    } else if (state is AnimationPlaying) {
      currentTotalFrames = (state as AnimationPlaying).totalFrames;
    } else if (state is AnimationStopped) {
      currentTotalFrames = (state as AnimationStopped).totalFrames;
    }

    final result = await _controlAnimationUseCase(
      ControlAnimationParams(
        command: AnimationCommand.play,
        totalFrames: currentTotalFrames > 0 ? currentTotalFrames : null,
      ),
    );

    result.fold(
      (failure) => emit(AnimationError(failure.message)),
      (animationState) {
        // CRITICAL FIX: Preserve totalFrames from current state if useCase returns 0
        final totalFrames = animationState.totalFrames > 0
            ? animationState.totalFrames
            : (currentTotalFrames > 0 ? currentTotalFrames : 0);

        emit(AnimationPlaying(
          speed: animationState.speed,
          currentFrame: animationState.currentFrame,
          totalFrames: totalFrames,
          progress: _calculateProgress(
            animationState.currentFrame,
            totalFrames,
          ),
        ));

        _startAnimationTimer(animationState.speed);
      },
    );
  }

  Future<void> _onPause(
    PauseAnimationEvent event,
    Emitter<AnimationBlocState> emit,
  ) async {
    _stopAnimationTimer();

    // Get current totalFrames to ensure persistence
    int currentTotalFrames = 0;
    if (state is AnimationPlaying) {
      currentTotalFrames = (state as AnimationPlaying).totalFrames;
    }

    final result = await _controlAnimationUseCase(
      ControlAnimationParams(
        command: AnimationCommand.pause,
        totalFrames: currentTotalFrames > 0 ? currentTotalFrames : null,
        frame: state is AnimationPlaying ? (state as AnimationPlaying).currentFrame : null,
      ),
    );

    result.fold(
      (failure) => emit(AnimationError(failure.message)),
      (animationState) {
        // Ensure we don't lose the frame count
        final totalFrames = animationState.totalFrames > 0 
            ? animationState.totalFrames 
            : currentTotalFrames;

        emit(AnimationPaused(
          speed: animationState.speed,
          currentFrame: animationState.currentFrame,
          totalFrames: totalFrames,
          progress: _calculateProgress(
            animationState.currentFrame,
            totalFrames,
          ),
        ));
      },
    );
  }

  Future<void> _onStop(
    StopAnimationEvent event,
    Emitter<AnimationBlocState> emit,
  ) async {
    _stopAnimationTimer();

    final result = await _controlAnimationUseCase(
      const ControlAnimationParams(command: AnimationCommand.stop),
    );

    result.fold(
      (failure) => emit(AnimationError(failure.message)),
      (animationState) {
        emit(AnimationStopped(
          speed: animationState.speed,
          totalFrames: animationState.totalFrames,
        ));
      },
    );
  }

  Future<void> _onReset(
    ResetAnimationEvent event,
    Emitter<AnimationBlocState> emit,
  ) async {
    _stopAnimationTimer();

    // Extract current state info to preserve speed and totalFrames
    double speed = 1.0;
    int totalFrames = 0;

    if (state is AnimationPlaying) {
      speed = (state as AnimationPlaying).speed;
      totalFrames = (state as AnimationPlaying).totalFrames;
    } else if (state is AnimationPaused) {
      speed = (state as AnimationPaused).speed;
      totalFrames = (state as AnimationPaused).totalFrames;
    } else if (state is AnimationStopped) {
      speed = (state as AnimationStopped).speed;
      totalFrames = (state as AnimationStopped).totalFrames;
    }

    // "Replay" logic: Reset to frame 0 and PLAY
    if (totalFrames > 0) {
      // Call UseCase to sync state to playing at frame 0
      final result = await _controlAnimationUseCase(
        ControlAnimationParams(
          command: AnimationCommand.play,
          frame: 0,
          totalFrames: totalFrames,
        ),
      );

      result.fold(
        (failure) => emit(AnimationError(failure.message)),
        (animationState) {
          emit(AnimationPlaying(
            speed: animationState.speed,
            currentFrame: 0,
            totalFrames: totalFrames,
            progress: 0.0,
          ));
          _startAnimationTimer(animationState.speed);
        },
      );
    } else {
      // Fallback if no frames available - just reset state
      final result = await _controlAnimationUseCase(
        const ControlAnimationParams(command: AnimationCommand.reset),
      );

      result.fold(
        (failure) => emit(AnimationError(failure.message)),
        (animationState) => emit(const AnimationInitial()),
      );
    }
  }

  Future<void> _onSetSpeed(
    SetAnimationSpeedEvent event,
    Emitter<AnimationBlocState> emit,
  ) async {
    final result = await _controlAnimationUseCase(
      ControlAnimationParams(
        command: AnimationCommand.play,
        speed: event.speed,
      ),
    );

    result.fold(
      (failure) => emit(AnimationError(failure.message)),
      (animationState) {
        if (state is AnimationPlaying) {
          _stopAnimationTimer();
          _startAnimationTimer(event.speed);

          emit(AnimationPlaying(
            speed: animationState.speed,
            currentFrame: animationState.currentFrame,
            totalFrames: animationState.totalFrames,
            progress: _calculateProgress(
              animationState.currentFrame,
              animationState.totalFrames,
            ),
          ));
        }
      },
    );
  }

  Future<void> _onSpeedUp(
    SpeedUpAnimationEvent event,
    Emitter<AnimationBlocState> emit,
  ) async {
    final result = await _controlAnimationUseCase(
      const ControlAnimationParams(command: AnimationCommand.speedUp),
    );

    result.fold(
      (failure) => emit(AnimationError(failure.message)),
      (animationState) {
        if (state is AnimationPlaying) {
          _stopAnimationTimer();
          _startAnimationTimer(animationState.speed);
        }

        _emitCurrentState(animationState, emit);
      },
    );
  }

  Future<void> _onSpeedDown(
    SpeedDownAnimationEvent event,
    Emitter<AnimationBlocState> emit,
  ) async {
    final result = await _controlAnimationUseCase(
      const ControlAnimationParams(command: AnimationCommand.speedDown),
    );

    result.fold(
      (failure) => emit(AnimationError(failure.message)),
      (animationState) {
        if (state is AnimationPlaying) {
          _stopAnimationTimer();
          _startAnimationTimer(animationState.speed);
        }

        _emitCurrentState(animationState, emit);
      },
    );
  }

  Future<void> _onSetFrame(
    SetAnimationFrameEvent event,
    Emitter<AnimationBlocState> emit,
  ) async {
    final result = await _controlAnimationUseCase(
      ControlAnimationParams(
        command: AnimationCommand.pause,
        frame: event.frame,
      ),
    );

    result.fold(
      (failure) => emit(AnimationError(failure.message)),
      (animationState) => _emitCurrentState(animationState, emit),
    );
  }

  void _onUpdateProgress(
    UpdateAnimationProgressEvent event,
    Emitter<AnimationBlocState> emit,
  ) {
    final progress = _calculateProgress(
      event.currentFrame,
      event.totalFrames,
    );

    if (state is AnimationPlaying) {
      emit(AnimationPlaying(
        speed: (state as AnimationPlaying).speed,
        currentFrame: event.currentFrame,
        totalFrames: event.totalFrames,
        progress: progress,
      ));
    }
  }

  Future<void> _onTick(
    TickAnimationEvent event,
    Emitter<AnimationBlocState> emit,
  ) async {
    if (state is! AnimationPlaying) return;

    final currentState = state as AnimationPlaying;

    // Calculate frame step based on current speed and timing
    const baseInterval = 500;
    const minInterval = 32;
    final idealInterval = (baseInterval / currentState.speed).round();
    final safeInterval = idealInterval.clamp(minInterval, baseInterval * 2);
    final frameStep = _calculateFrameStep(currentState.speed, idealInterval, safeInterval);

    final nextFrame = currentState.currentFrame + frameStep;

    // Guard against empty or invalid frame counts
    if (currentState.totalFrames <= 0) {
      add(const StopAnimationEvent());
      return;
    }

    // Respect totalFrames limit - loop back to 0 or stop
    if (nextFrame >= currentState.totalFrames) {
      // Loop back to frame 0
      emit(AnimationPlaying(
        speed: currentState.speed,
        currentFrame: 0,
        totalFrames: currentState.totalFrames,
        progress: 0.0,
      ));
    } else {
      // Ensure nextFrame is within valid bounds
      final safeFrame = nextFrame < 0 ? 0 : (nextFrame >= currentState.totalFrames ? currentState.totalFrames - 1 : nextFrame);
      emit(AnimationPlaying(
        speed: currentState.speed,
        currentFrame: safeFrame,
        totalFrames: currentState.totalFrames,
        progress: _calculateProgress(safeFrame, currentState.totalFrames),
      ));
    }
  }

  Future<void> _onSyncData(
    SyncAnimationDataEvent event,
    Emitter<AnimationBlocState> emit,
  ) async {
    // Sync with UseCase
    final result = await _controlAnimationUseCase(
      ControlAnimationParams(
        command: AnimationCommand.sync,
        totalFrames: event.totalFrames,
      ),
    );

    result.fold(
      (failure) => emit(AnimationError(failure.message)),
      (animationState) {
        // Update totalFrames and reset to frame 0
        if (state is AnimationPlaying) {
          emit(AnimationPlaying(
            speed: (state as AnimationPlaying).speed,
            currentFrame: 0,
            totalFrames: event.totalFrames,
            progress: 0.0,
          ));
        } else if (state is AnimationPaused) {
          emit(AnimationPaused(
            speed: (state as AnimationPaused).speed,
            currentFrame: 0,
            totalFrames: event.totalFrames,
            progress: 0.0,
          ));
        } else {
          emit(AnimationPaused(
            speed: 1.0,
            currentFrame: 0,
            totalFrames: event.totalFrames,
            progress: 0.0,
          ));
        }
      },
    );
  }

  void _emitCurrentState(
    AnimationState animationState,
    Emitter<AnimationBlocState> emit,
  ) {
    if (animationState.isPlaying) {
      emit(AnimationPlaying(
        speed: animationState.speed,
        currentFrame: animationState.currentFrame,
        totalFrames: animationState.totalFrames,
        progress: _calculateProgress(
          animationState.currentFrame,
          animationState.totalFrames,
        ),
      ));
    } else {
      emit(AnimationPaused(
        speed: animationState.speed,
        currentFrame: animationState.currentFrame,
        totalFrames: animationState.totalFrames,
        progress: _calculateProgress(
          animationState.currentFrame,
          animationState.totalFrames,
        ),
      ));
    }
  }

  double _calculateProgress(int current, int total) {
    if (total == 0) return 0.0;
    return (current / total).clamp(0.0, 1.0);
  }

  void _startAnimationTimer(double speed) {
    // SCIENTIFIC PACING: Base speed (1.0x) = 500ms per frame (2 FPS)
    // This allows readable observation of each time step
    const baseInterval = 500; // milliseconds per frame at 1.0x speed
    const minInterval = 32;   // milliseconds (approx 30 fps max)

    // Calculate ideal interval: baseInterval / speed
    // Speed 1.0x = 500ms, 2.0x = 250ms, 4.0x = 125ms, etc.
    final idealInterval = (baseInterval / speed).round();

    // Clamp to minimum safe interval
    final safeInterval = idealInterval.clamp(minInterval, baseInterval * 2);

    // Calculate frame step to maintain visual speed without freezing UI
    final frameStep = _calculateFrameStep(speed, idealInterval, safeInterval);

    _animationTimer = Timer.periodic(Duration(milliseconds: safeInterval), (_) {
      add(const TickAnimationEvent());
    });
  }

  /// Calculate frame step based on speed to simulate faster playback
  /// without overwhelming the UI thread with rapid timer events
  ///
  /// When ideal interval is below minInterval (32ms), we skip frames
  /// to maintain the visual speed without overloading the UI thread
  int _calculateFrameStep(double speed, int idealInterval, int safeInterval) {
    // If we're at the safe interval, no frame skipping needed
    if (idealInterval >= safeInterval) {
      return 1;
    }

    // Calculate how many frames to skip to maintain visual speed
    // Example: If idealInterval=16ms but safeInterval=32ms,
    // we need to skip 2 frames per tick (32/16 = 2)
    final skipRatio = (safeInterval / idealInterval).ceil();
    return skipRatio.clamp(1, 10); // Clamp to reasonable range
  }

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