import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/chat_repository.dart';

class GetChatHistoryParams {
  final int? limit;
  final DateTime? before;

  const GetChatHistoryParams({
    this.limit,
    this.before,
  });
}

class GetChatHistoryUseCase {
  final ChatRepository repository;

  GetChatHistoryUseCase(this.repository);

  Future<Either<Failure, List<ChatMessage>>> call(
    GetChatHistoryParams params,
  ) async {
    return await repository.getChatHistory(
      limit: params.limit,
      before: params.before,
    );
  }
}