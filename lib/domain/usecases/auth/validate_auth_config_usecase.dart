import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/auth_repository.dart';

class ValidateAuthConfigUseCase {
  final AuthRepository repository;

  ValidateAuthConfigUseCase(this.repository);

  Future<Either<Failure, bool>> call() async {
    return await repository.validateAuthConfig();
  }
}