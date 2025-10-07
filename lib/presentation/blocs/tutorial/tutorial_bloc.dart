// lib/presentation/blocs/tutorial/tutorial_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/datasources/local/encrypted_storage_local_datasource.dart';

// Events
abstract class TutorialEvent extends Equatable {
  const TutorialEvent();

  @override
  List<Object?> get props => [];
}

class StartTutorialEvent extends TutorialEvent {
  const StartTutorialEvent();
}

class CloseTutorialEvent extends TutorialEvent {
  const CloseTutorialEvent();
}

class CompleteTutorialEvent extends TutorialEvent {
  const CompleteTutorialEvent();
}

class SetTutorialStepEvent extends TutorialEvent {
  final int step;

  const SetTutorialStepEvent(this.step);

  @override
  List<Object?> get props => [step];
}

class NextTutorialStepEvent extends TutorialEvent {
  const NextTutorialStepEvent();
}

class PreviousTutorialStepEvent extends TutorialEvent {
  const PreviousTutorialStepEvent();
}

class SkipTutorialEvent extends TutorialEvent {
  const SkipTutorialEvent();
}

class CheckTutorialStatusEvent extends TutorialEvent {
  const CheckTutorialStatusEvent();
}

// States
abstract class TutorialState extends Equatable {
  const TutorialState();

  @override
  List<Object?> get props => [];
}

class TutorialInitial extends TutorialState {
  const TutorialInitial();
}

class TutorialNotStarted extends TutorialState {
  const TutorialNotStarted();
}

class TutorialInProgress extends TutorialState {
  final int currentStep;
  final int totalSteps;
  final String stepTitle;
  final String stepDescription;
  final String? targetElement;

  const TutorialInProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitle,
    required this.stepDescription,
    this.targetElement,
  });

  @override
  List<Object?> get props => [
        currentStep,
        totalSteps,
        stepTitle,
        stepDescription,
        targetElement,
      ];

  bool get isFirstStep => currentStep == 0;
  bool get isLastStep => currentStep >= totalSteps - 1;
  double get progress => totalSteps > 0 ? (currentStep + 1) / totalSteps : 0.0;
}

class TutorialCompleted extends TutorialState {
  const TutorialCompleted();
}

class TutorialClosed extends TutorialState {
  const TutorialClosed();
}

class TutorialError extends TutorialState {
  final String message;

  const TutorialError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class TutorialBloc extends Bloc<TutorialEvent, TutorialState> {
  final EncryptedStorageLocalDataSource _storage;

  static const String _tutorialCompleteKey = 'tutorial_complete';
  static const String _tutorialStepKey = 'tutorial_current_step';

  // Define tutorial steps
  final List<Map<String, String>> _tutorialSteps = [
    {
      'title': 'Welcome to Ocean Platform',
      'description': 'This tutorial will guide you through the main features of the application.',
      'target': '',
    },
    {
      'title': 'Interactive Map',
      'description': 'View ocean stations and select them to see detailed data.',
      'target': 'map-container',
    },
    {
      'title': 'Control Panel',
      'description': 'Adjust time range, depth, and model settings for data visualization.',
      'target': 'control-panel',
    },
    {
      'title': 'Data Visualization',
      'description': 'View ocean data in charts and graphs.',
      'target': 'data-panels',
    },
    {
      'title': 'AI Assistant',
      'description': 'Ask questions about ocean data and get intelligent responses.',
      'target': 'chatbot',
    },
    {
      'title': 'HoloOcean Simulation',
      'description': 'Connect to HoloOcean for immersive ocean simulations.',
      'target': 'holoocean-panel',
    },
  ];

  TutorialBloc({required EncryptedStorageLocalDataSource storage})
      : _storage = storage,
        super(const TutorialInitial()) {
    on<StartTutorialEvent>(_onStart);
    on<CloseTutorialEvent>(_onClose);
    on<CompleteTutorialEvent>(_onComplete);
    on<SetTutorialStepEvent>(_onSetStep);
    on<NextTutorialStepEvent>(_onNextStep);
    on<PreviousTutorialStepEvent>(_onPreviousStep);
    on<SkipTutorialEvent>(_onSkip);
    on<CheckTutorialStatusEvent>(_onCheckStatus);
  }

  Future<void> _onStart(
    StartTutorialEvent event,
    Emitter<TutorialState> emit,
  ) async {
    try {
      await _storage.saveData(_tutorialCompleteKey, false);
      await _storage.saveData(_tutorialStepKey, 0);

      final firstStep = _tutorialSteps[0];
      emit(TutorialInProgress(
        currentStep: 0,
        totalSteps: _tutorialSteps.length,
        stepTitle: firstStep['title']!,
        stepDescription: firstStep['description']!,
        targetElement: firstStep['target'],
      ));
    } catch (e) {
      emit(TutorialError('Failed to start tutorial: ${e.toString()}'));
    }
  }

  Future<void> _onClose(
    CloseTutorialEvent event,
    Emitter<TutorialState> emit,
  ) async {
    try {
      // Save current progress
      if (state is TutorialInProgress) {
        final currentState = state as TutorialInProgress;
        await _storage.saveData(_tutorialStepKey, currentState.currentStep);
      }
      emit(const TutorialClosed());
    } catch (e) {
      emit(TutorialError('Failed to close tutorial: ${e.toString()}'));
    }
  }

  Future<void> _onComplete(
    CompleteTutorialEvent event,
    Emitter<TutorialState> emit,
  ) async {
    try {
      await _storage.saveData(_tutorialCompleteKey, true);
      await _storage.deleteData(_tutorialStepKey);
      emit(const TutorialCompleted());
    } catch (e) {
      emit(TutorialError('Failed to complete tutorial: ${e.toString()}'));
    }
  }

  Future<void> _onSetStep(
    SetTutorialStepEvent event,
    Emitter<TutorialState> emit,
  ) async {
    try {
      if (event.step < 0 || event.step >= _tutorialSteps.length) {
        emit(TutorialError('Invalid step: ${event.step}'));
        return;
      }

      await _storage.saveData(_tutorialStepKey, event.step);

      final step = _tutorialSteps[event.step];
      emit(TutorialInProgress(
        currentStep: event.step,
        totalSteps: _tutorialSteps.length,
        stepTitle: step['title']!,
        stepDescription: step['description']!,
        targetElement: step['target'],
      ));
    } catch (e) {
      emit(TutorialError('Failed to set tutorial step: ${e.toString()}'));
    }
  }

  Future<void> _onNextStep(
    NextTutorialStepEvent event,
    Emitter<TutorialState> emit,
  ) async {
    if (state is! TutorialInProgress) return;

    final currentState = state as TutorialInProgress;
    final nextStep = currentState.currentStep + 1;

    if (nextStep >= _tutorialSteps.length) {
      add(const CompleteTutorialEvent());
    } else {
      add(SetTutorialStepEvent(nextStep));
    }
  }

  Future<void> _onPreviousStep(
    PreviousTutorialStepEvent event,
    Emitter<TutorialState> emit,
  ) async {
    if (state is! TutorialInProgress) return;

    final currentState = state as TutorialInProgress;
    final previousStep = currentState.currentStep - 1;

    if (previousStep >= 0) {
      add(SetTutorialStepEvent(previousStep));
    }
  }

  Future<void> _onSkip(
    SkipTutorialEvent event,
    Emitter<TutorialState> emit,
  ) async {
    try {
      await _storage.saveData(_tutorialCompleteKey, true);
      await _storage.deleteData(_tutorialStepKey);
      emit(const TutorialCompleted());
    } catch (e) {
      emit(TutorialError('Failed to skip tutorial: ${e.toString()}'));
    }
  }

  Future<void> _onCheckStatus(
    CheckTutorialStatusEvent event,
    Emitter<TutorialState> emit,
  ) async {
    try {
      final completed = await _storage.getData(_tutorialCompleteKey) as bool?;

      if (completed == true) {
        emit(const TutorialCompleted());
      } else {
        final currentStep = await _storage.getData(_tutorialStepKey) as int?;

        if (currentStep != null && currentStep >= 0) {
          add(SetTutorialStepEvent(currentStep));
        } else {
          emit(const TutorialNotStarted());
        }
      }
    } catch (e) {
      emit(const TutorialNotStarted());
    }
  }
}