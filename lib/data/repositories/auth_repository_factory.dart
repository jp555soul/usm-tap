import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

import 'auth_repository_stub.dart'
    if (dart.library.html) 'auth_repository_web.dart'
    if (dart.library.io) 'auth_repository_mobile.dart';

class AuthRepositoryFactory {
  static AuthRepository create(dynamic appAuth) {
    return createPlatformAuthRepository(appAuth);
  }
}
