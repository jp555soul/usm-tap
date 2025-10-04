// lib/domain/usecases/auth/get_user_profile_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/user_entity.dart';
import '../../repositories/auth_repository.dart';

class GetUserProfileUseCase {
  final AuthRepository repository;

  GetUserProfileUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call() async {
    return await repository.getUserProfile();
  }
}