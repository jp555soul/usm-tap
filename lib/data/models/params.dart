import 'package:equatable/equatable.dart';
import 'chat_message.dart';

class SendMessageParams extends Equatable {
  final String message;
  final List<ChatMessage> history;
  final Map<String, dynamic>? context;

  const SendMessageParams({
    required this.message,
    required this.history,
    this.context,
  });

  @override
  List<Object?> get props => [message, history, context];
}

class GetChatHistoryParams extends Equatable {
  final int? limit;

  const GetChatHistoryParams({this.limit});

  @override
  List<Object?> get props => [limit];
}

enum AnimationCommand {
  play,
  pause,
  stop,
  fastForward,
  rewind,
}

class ControlAnimationParams extends Equatable {
  final AnimationCommand command;
  final double? speed;

  const ControlAnimationParams({
    required this.command,
    this.speed,
  });

  @override
  List<Object?> get props => [command, speed];
}