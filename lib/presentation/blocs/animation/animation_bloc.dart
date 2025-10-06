// lib/presentation/blocs/animation/animation_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
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
  }

  Future<void> _onPlay(
    PlayAnimationEvent event,
    Emitter<AnimationBlocState> emit,
  ) async {
    final result = await _controlAnimationUseCase(
      const ControlAnimationParams(command: AnimationCommand.play),
    );

    result.fold(
      (failure) => emit(AnimationError(failure.message)),
      (animationState) {
        emit(AnimationPlaying(
          speed: animationState.speed,
          currentFrame: animationState.currentFrame,
          totalFrames: animationState.totalFrames,
          progress: _calculateProgress(
            animationState.currentFrame,
            animationState.totalFrames,
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

    final result = await _controlAnimationUseCase(
      const ControlAnimationParams(command: AnimationCommand.pause),
    );

    result.fold(
      (failure) => emit(AnimationError(failure.message)),
      (animationState) {
        emit(AnimationPaused(
          speed: animationState.speed,
          currentFrame: animationState.currentFrame,
          totalFrames: animationState.totalFrames,
          progress: _calculateProgress(
            animationState.currentFrame,
            animationState.totalFrames,
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

    final result = await _controlAnimationUseCase(
      const ControlAnimationParams(command: AnimationCommand.reset),
    );

    result.fold(
      (failure) => emit(AnimationError(failure.message)),
      (animationState) => emit(const AnimationInitial()),
    );
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
    final nextFrame = currentState.currentFrame + 1;

    if (nextFrame >= currentState.totalFrames) {
      // Animation complete - loop or stop
      add(const StopAnimationEvent());
    } else {
      emit(AnimationPlaying(
        speed: currentState.speed,
        currentFrame: nextFrame,
        totalFrames: currentState.totalFrames,
        progress: _calculateProgress(nextFrame, currentState.totalFrames),
      ));
    }
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
    final interval = Duration(milliseconds: (1000 / (speed * 10)).round());
    _animationTimer = Timer.periodic(interval, (_) {
      add(const TickAnimationEvent());
    });
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