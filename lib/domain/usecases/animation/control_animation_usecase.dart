import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';

enum AnimationCommand {
  play,
  pause,
  stop,
  reset,
  speedUp,
  speedDown,
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

  const ControlAnimationParams({
    required this.command,
    this.speed,
    this.frame,
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
      switch (params.command) {
        case AnimationCommand.play:
          _state = AnimationState(
            isPlaying: true,
            speed: _state.speed,
            currentFrame: _state.currentFrame,
            totalFrames: _state.totalFrames,
          );
          break;
        case AnimationCommand.pause:
          _state = AnimationState(
            isPlaying: false,
            speed: _state.speed,
            currentFrame: _state.currentFrame,
            totalFrames: _state.totalFrames,
          );
          break;
        case AnimationCommand.stop:
          _state = AnimationState(
            isPlaying: false,
            speed: _state.speed,
            currentFrame: 0,
            totalFrames: _state.totalFrames,
          );
          break;
        case AnimationCommand.reset:
          _state = const AnimationState(
            isPlaying: false,
            speed: 1.0,
            currentFrame: 0,
            totalFrames: 0,
          );
          break;
        case AnimationCommand.speedUp:
          _state = AnimationState(
            isPlaying: _state.isPlaying,
            speed: (_state.speed * 1.5).clamp(0.1, 5.0),
            currentFrame: _state.currentFrame,
            totalFrames: _state.totalFrames,
          );
          break;
        case AnimationCommand.speedDown:
          _state = AnimationState(
            isPlaying: _state.isPlaying,
            speed: (_state.speed / 1.5).clamp(0.1, 5.0),
            currentFrame: _state.currentFrame,
            totalFrames: _state.totalFrames,
          );
          break;
      }

      if (params.speed != null) {
        _state = AnimationState(
          isPlaying: _state.isPlaying,
          speed: params.speed!.clamp(0.1, 5.0),
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