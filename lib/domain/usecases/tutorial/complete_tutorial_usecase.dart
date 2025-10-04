import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/tutorial_repository.dart';

class CompleteTutorialUseCase {
  final TutorialRepository repository;

  CompleteTutorialUseCase(this.repository);

  Future<Either<Failure, void>> call() async {
    return await repository.completeTutorial();
  }
}