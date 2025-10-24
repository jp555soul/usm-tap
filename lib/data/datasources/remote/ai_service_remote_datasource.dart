// lib/data/datasources/remote/ai_service_remote_datasource.dart
import '../../services/ai_service.dart';

/// Abstract class for remote AI service data source
abstract class AiServiceRemoteDataSource {
  Future<Map<String, dynamic>> getAIResponse({
    required String message,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  });

  Future<bool> testAPIConnection();

  Future<dynamic> sendMessage({
    required String message,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  });
  
  Stream<dynamic> sendMessageStream({
    required String message,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  });
}

/// Implementation of [AiServiceRemoteDataSource]
class AiServiceRemoteDataSourceImpl implements AiServiceRemoteDataSource {
  final AiService _aiService;

  AiServiceRemoteDataSourceImpl({required AiService aiService})
      : _aiService = aiService;

  @override
  Future<Map<String, dynamic>> getAIResponse({
    required String message,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  }) async {
    final response = await _aiService.sendMessage(
      message: message,
      history: history,
      context: context,
    );
    return response;
  }

  @override
  Future<bool> testAPIConnection() async {
    return await _aiService.healthCheck();
  }

  @override
  Future<dynamic> sendMessage({
    required String message,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  }) async {
    final response = await _aiService.sendMessage(
      message: message,
      history: history,
      context: context,
    );
    return response;
  }

  @override
  Stream<dynamic> sendMessageStream({
    required String message,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  }) {
    return _aiService.sendMessageStream(
      message: message,
      history: history,
      context: context,
    );
  }
}