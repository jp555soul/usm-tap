import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';

enum AnimationCommand {
  play,
  pause,
  stop,
  reset,
  speedUp,
  speedDown,
  sync, // New command to sync data
}

class AnimationState {
  final bool isPlaying;
  final double speed;
  final int currentFrame;
  final int totalFrames;

  const AnimationState({
    required this.isPlaying,
    required this.speed,
    required this.currentFrame,
    required this.totalFrames,
  });
}

class ControlAnimationParams {
  final AnimationCommand command;
  final double? speed;
  final int? frame;
  final int? totalFrames; // Added totalFrames

  const ControlAnimationParams({
    required this.command,
    this.speed,
    this.frame,
    this.totalFrames,
  });
}

class ControlAnimationUseCase {
  AnimationState _state = const AnimationState(
    isPlaying: false,
    speed: 1.0,
    currentFrame: 0,
    totalFrames: 0,
  );

  Future<Either<Failure, AnimationState>> call(
    ControlAnimationParams params,
  ) async {
    try {
      // Update totalFrames if provided in params
      int newTotalFrames = params.totalFrames ?? _state.totalFrames;

      switch (params.command) {
        case AnimationCommand.play:
          _state = AnimationState(
            isPlaying: true,
            speed: _state.speed,
            currentFrame: _state.currentFrame,
            totalFrames: newTotalFrames,
          );
          break;
        case AnimationCommand.pause:
          _state = AnimationState(
            isPlaying: false,
            speed: _state.speed,
            currentFrame: _state.currentFrame,
            totalFrames: newTotalFrames,
          );
          break;
        case AnimationCommand.stop:
          _state = AnimationState(
            isPlaying: false,
            speed: _state.speed,
            currentFrame: 0,
            totalFrames: newTotalFrames,
          );
          break;
        case AnimationCommand.reset:
          _state = AnimationState(
            isPlaying: false,
            speed: 1.0,
            currentFrame: 0,
            totalFrames: newTotalFrames,
          );
          break;
        case AnimationCommand.speedUp:
          _state = AnimationState(
            isPlaying: _state.isPlaying,
            speed: (_state.speed * 1.5).clamp(0.1, 20.0),
            currentFrame: _state.currentFrame,
            totalFrames: newTotalFrames,
          );
          break;
        case AnimationCommand.speedDown:
          _state = AnimationState(
            isPlaying: _state.isPlaying,
            speed: (_state.speed / 1.5).clamp(0.1, 20.0),
            currentFrame: _state.currentFrame,
            totalFrames: newTotalFrames,
          );
          break;
        case AnimationCommand.sync:
          _state = AnimationState(
            isPlaying: _state.isPlaying,
            speed: _state.speed,
            currentFrame: _state.currentFrame, // Keep current frame or reset? Usually sync implies new data, so maybe 0?
            // Let's keep it safe and just update totalFrames. The Bloc usually handles the frame reset on sync.
            totalFrames: newTotalFrames,
          );
          break;
      }

      if (params.speed != null) {
        _state = AnimationState(
          isPlaying: _state.isPlaying,
          speed: params.speed!.clamp(0.1, 20.0),
          currentFrame: _state.currentFrame,
          totalFrames: _state.totalFrames,
        );
      }

      if (params.frame != null) {
        _state = AnimationState(
          isPlaying: _state.isPlaying,
          speed: _state.speed,
          currentFrame: params.frame!,
          totalFrames: _state.totalFrames,
        );
      }

      return Right(_state);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  AnimationState get currentState => _state;
}