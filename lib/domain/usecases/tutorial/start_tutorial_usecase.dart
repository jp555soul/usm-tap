import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/tutorial_repository.dart';

class StartTutorialUseCase {
  final TutorialRepository repository;

  StartTutorialUseCase(this.repository);

  Future<Either<Failure, void>> call() async {
    return await repository.startTutorial();
  }
}