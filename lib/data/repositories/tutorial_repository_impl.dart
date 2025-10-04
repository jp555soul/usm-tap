// lib/data/repositories/tutorial_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/repositories/tutorial_repository.dart';
import '../datasources/local/encrypted_storage_local_datasource.dart';

class TutorialRepositoryImpl implements TutorialRepository {
  final EncryptedStorageLocalDataSource localStorage;

  static const String _tutorialCompleteKey = 'tutorial_complete';
  static const String _tutorialStepKey = 'tutorial_current_step';

  TutorialRepositoryImpl({required this.localStorage});

  @override
  Future<Either<Failure, void>> startTutorial() async {
    try {
      await localStorage.saveData(_tutorialCompleteKey, false);
      await localStorage.saveData(_tutorialStepKey, 0);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Failed to start tutorial: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> completeTutorial() async {
    try {
      await localStorage.saveData(_tutorialCompleteKey, true);
      await localStorage.deleteData(_tutorialStepKey);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Failed to complete tutorial: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> getTutorialStatus() async {
    try {
      final completed = await localStorage.getData(_tutorialCompleteKey);
      return Right(completed ?? false);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Failed to get tutorial status: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> setTutorialStep(int step) async {
    try {
      await localStorage.saveData(_tutorialStepKey, step);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Failed to set tutorial step: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> getCurrentStep() async {
    try {
      final step = await localStorage.getData(_tutorialStepKey);
      return Right(step ?? 0);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Failed to get current step: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<TutorialStep>>> getTutorialSteps() async {
    try {
      // Define tutorial steps
      final steps = [
        const TutorialStep(
          id: 'welcome',
          title: 'Welcome to Ocean Platform',
          description: 'This tutorial will guide you through the main features of the application.',
          order: 0,
          targetElement: null,
        ),
        const TutorialStep(
          id: 'map',
          title: 'Interactive Map',
          description: 'View ocean stations and select them to see detailed data.',
          order: 1,
          targetElement: 'map-container',
        ),
        const TutorialStep(
          id: 'control-panel',
          title: 'Control Panel',
          description: 'Adjust time range, depth, and model settings for data visualization.',
          order: 2,
          targetElement: 'control-panel',
        ),
        const TutorialStep(
          id: 'data-panels',
          title: 'Data Visualization',
          description: 'View ocean data in charts and graphs.',
          order: 3,
          targetElement: 'data-panels',
        ),
        const TutorialStep(
          id: 'chatbot',
          title: 'AI Assistant',
          description: 'Ask questions about ocean data and get intelligent responses.',
          order: 4,
          targetElement: 'chatbot',
        ),
        const TutorialStep(
          id: 'holoocean',
          title: 'HoloOcean Simulation',
          description: 'Connect to HoloOcean for immersive ocean simulations.',
          order: 5,
          targetElement: 'holoocean-panel',
        ),
      ];

      return Right(steps);
    } catch (e) {
      return Left(CacheFailure('Failed to get tutorial steps: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> resetTutorial() async {
    try {
      await localStorage.deleteData(_tutorialCompleteKey);
      await localStorage.deleteData(_tutorialStepKey);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Failed to reset tutorial: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> skipTutorial() async {
    try {
      await localStorage.saveData(_tutorialCompleteKey, true);
      await localStorage.deleteData(_tutorialStepKey);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Failed to skip tutorial: ${e.toString()}'));
    }
  }
}