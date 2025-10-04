import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';

class TutorialStep {
  final String id;
  final String title;
  final String description;
  final int order;
  final String? targetElement;
  final Map<String, dynamic>? metadata;

  const TutorialStep({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    this.targetElement,
    this.metadata,
  });
}

abstract class TutorialRepository {
  Future<Either<Failure, void>> startTutorial();

  Future<Either<Failure, void>> completeTutorial();

  Future<Either<Failure, bool>> getTutorialStatus();

  Future<Either<Failure, void>> setTutorialStep(int step);

  Future<Either<Failure, int>> getCurrentStep();

  Future<Either<Failure, List<TutorialStep>>> getTutorialSteps();

  Future<Either<Failure, void>> resetTutorial();

  Future<Either<Failure, void>> skipTutorial();
}