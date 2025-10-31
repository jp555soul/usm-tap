import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

class PlatformAuthRepository implements AuthRepository {
  PlatformAuthRepository() {
    throw UnsupportedError('Cannot create PlatformAuthRepository without platform-specific implementation');
  }

  @override
  Future<Either<Failure, UserEntity>> login() async => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> logout() async => throw UnimplementedError();

  @override
  Future<Either<Failure, UserEntity>> getUserProfile() async => throw UnimplementedError();

  @override
  Future<Either<Failure, bool>> validateAuthConfig() async => throw UnimplementedError();

  @override
  Future<Either<Failure, String>> getAccessToken() async => throw UnimplementedError();
}

AuthRepository createPlatformAuthRepository(dynamic appAuth) {
  return PlatformAuthRepository();
}
