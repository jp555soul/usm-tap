import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../../core/constants/app_constants.dart';

class PasswordLoginUseCase {
  Future<Either<Failure, bool>> call(String password) async {
    if (password.isEmpty) {
      return Left(AuthFailure('Password cannot be empty'));
    }

    if (password == AppConstants.accessPassword) {
      return const Right(true);
    }

    return Left(AuthFailure('Incorrect password'));
  }
}
