import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/chat_repository.dart';

class SendMessageParams {
  final String message;
  final List<ChatMessage>? history;
  final Map<String, dynamic>? context;

  const SendMessageParams({
    required this.message,
    this.history,
    this.context,
  });
}

class SendMessageUseCase {
  final ChatRepository repository;

  SendMessageUseCase(this.repository);

  Future<Either<Failure, ChatMessage>> call(SendMessageParams params) async {
    return await repository.sendMessage(
      message: params.message,
      history: params.history,
      context: params.context,
    );
  }

  Future<Either<Failure, Stream<String>>> callStream(
    SendMessageParams params,
  ) async {
    return await repository.sendMessageStream(
      message: params.message,
      history: params.history,
      context: params.context,
    );
  }
}