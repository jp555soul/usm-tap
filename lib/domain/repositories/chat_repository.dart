import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.metadata,
  });
}

abstract class ChatRepository {
  Future<Either<Failure, ChatMessage>> sendMessage({
    required String message,
    List<ChatMessage>? history,
    Map<String, dynamic>? context,
  });

  Future<Either<Failure, Stream<String>>> sendMessageStream({
    required String message,
    List<ChatMessage>? history,
    Map<String, dynamic>? context,
  });

  Future<Either<Failure, List<ChatMessage>>> getChatHistory({
    int? limit,
    DateTime? before,
  });

  Future<Either<Failure, void>> clearChatHistory();
}