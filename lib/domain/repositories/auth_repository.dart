import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';
import '../../core/errors/failures.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login();
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, UserEntity>> getUserProfile();
  Future<Either<Failure, bool>> validateAuthConfig();
  Future<Either<Failure, String>> getAccessToken();
}