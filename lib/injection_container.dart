import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Services
import 'data/services/ai_service.dart';
import 'data/services/holoocean_service.dart';
import 'data/datasources/local/session_key_service.dart';

// Data Sources
import 'data/datasources/local/encrypted_storage_local_datasource.dart';
import 'data/datasources/local/session_key_local_datasource.dart';
import 'data/datasources/remote/ai_service_remote_datasource.dart';
import 'data/datasources/remote/ocean_data_remote_datasource.dart';
import 'data/datasources/remote/holoocean_service_remote_datasource.dart';

// Repositories
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/ocean_data_repository_impl.dart';
import 'data/repositories/chat_repository_impl.dart';
import 'data/repositories/holoocean_repository_impl.dart';
import 'data/repositories/map_repository_impl.dart';
import 'data/repositories/tutorial_repository_impl.dart';

// Domain Repositories
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/ocean_data_repository.dart';
import 'domain/repositories/chat_repository.dart';
import 'domain/repositories/holoocean_repository.dart';
import 'domain/repositories/map_repository.dart';
import 'domain/repositories/tutorial_repository.dart';

// Use Cases
import 'domain/usecases/auth/login_usecase.dart';
import 'domain/usecases/auth/logout_usecase.dart';
import 'domain/usecases/auth/get_user_profile_usecase.dart';
import 'domain/usecases/auth/validate_auth_config_usecase.dart';
import 'domain/usecases/ocean_data/get_ocean_data_usecase.dart';
import 'domain/usecases/ocean_data/update_time_range_usecase.dart';
import 'domain/usecases/ocean_data/load_all_data_usecase.dart';
import 'domain/usecases/chat/send_message_usecase.dart';
import 'domain/usecases/chat/get_chat_history_usecase.dart';
import 'domain/usecases/holoocean/connect_holoocean_usecase.dart';
import 'domain/usecases/holoocean/set_target_usecase.dart';
import 'domain/usecases/map/get_stations_usecase.dart';
import 'domain/usecases/map/select_station_usecase.dart';
import 'domain/usecases/tutorial/start_tutorial_usecase.dart';
import 'domain/usecases/tutorial/complete_tutorial_usecase.dart';
import 'domain/usecases/animation/control_animation_usecase.dart';

// BLoCs
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/ocean_data/ocean_data_bloc.dart';
import 'presentation/blocs/chat/chat_bloc.dart';
import 'presentation/blocs/holoocean/holoocean_bloc.dart';
import 'presentation/blocs/map/map_bloc.dart';
import 'presentation/blocs/tutorial/tutorial_bloc.dart';
import 'presentation/blocs/animation/animation_bloc.dart';
import 'presentation/blocs/api/api_bloc.dart';
import 'presentation/blocs/data_management/data_management_bloc.dart';
import 'presentation/blocs/environmental_data/environmental_data_bloc.dart';
import 'presentation/blocs/time_management/time_management_bloc.dart';
import 'presentation/blocs/ui_controls/ui_controls_bloc.dart';

// Core Services
import 'core/network/network_info.dart';
import 'core/utils/encryption_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  sl.registerLazySingleton(() => Dio());
  
  sl.registerLazySingleton(() => const FlutterAppAuth());
  
  sl.registerLazySingleton(() => Connectivity());
  
  sl.registerLazySingleton(() => const FlutterSecureStorage());

  //! Core
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(),
  );

  sl.registerLazySingleton<EncryptionService>(
    () => EncryptionServiceImpl(),
  );

  sl.registerLazySingleton(
    () => SessionKeyService(secureStorage: sl()),
  );

  //! Services (Wrappers for Dio-based services)
  sl.registerLazySingleton(
    () => AiService(
      dio: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => HoloOceanService(
      dio: sl(),
    ),
  );

  //! Data sources
  
  // Remote Data Sources (equivalent to services)
  sl.registerLazySingleton<OceanDataRemoteDataSource>(
    () => OceanDataRemoteDataSourceImpl(dio: sl()),
  );

  sl.registerLazySingleton<AiServiceRemoteDataSource>(
    () => AiServiceRemoteDataSourceImpl(aiService: sl()),
  );

  sl.registerLazySingleton<HoloOceanServiceRemoteDataSource>(
    () => HoloOceanServiceRemoteDataSourceImpl(
      holoOceanService: sl(),
    ),
  );

  // Local Data Sources (equivalent to encrypted storage and session management)
  sl.registerLazySingleton(
    () => EncryptedStorageService(
      prefs: sl(),
      sessionKeyService: sl(),
    ),
  );

  sl.registerLazySingleton<EncryptedStorageLocalDataSource>(
    () => EncryptedStorageLocalDataSourceImpl(
      encryptedStorageService: sl(),
    ),
  );

  sl.registerLazySingleton<SessionKeyLocalDataSource>(
    () => SessionKeyLocalDataSourceImpl(
      sessionKeyService: sl(),
    ),
  );

  //! Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      appAuth: sl(),
    ),
  );

  sl.registerLazySingleton<OceanDataRepository>(
    () => OceanDataRepositoryImpl(
      remoteDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      remoteDataSource: sl(),
      localStorage: sl(),
    ),
  );

  sl.registerLazySingleton<HoloOceanRepository>(
    () => HoloOceanRepositoryImpl(
      remoteDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<MapRepository>(
    () => MapRepositoryImpl(
      remoteDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<TutorialRepository>(
    () => TutorialRepositoryImpl(
      localStorage: sl(),
    ),
  );

  //! Use cases
  
  // Auth Use Cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetUserProfileUseCase(sl()));
  sl.registerLazySingleton(() => ValidateAuthConfigUseCase(sl()));

  // Ocean Data Use Cases
  sl.registerLazySingleton(() => GetOceanDataUseCase(sl()));
  sl.registerLazySingleton(() => UpdateTimeRangeUseCase(sl()));
  sl.registerLazySingleton(() => LoadAllDataUseCase(sl()));

  // Chat Use Cases
  sl.registerLazySingleton(() => SendMessageUseCase(sl()));
  sl.registerLazySingleton(() => GetChatHistoryUseCase(sl()));

  // HoloOcean Use Cases
  sl.registerLazySingleton(() => ConnectHoloOceanUseCase(sl()));
  sl.registerLazySingleton(() => SetTargetUseCase(sl()));

  // Map Use Cases
  sl.registerLazySingleton(() => GetStationsUseCase(sl()));
  sl.registerLazySingleton(() => SelectStationUseCase(sl()));

  // Tutorial Use Cases
  sl.registerLazySingleton(() => StartTutorialUseCase(sl()));
  sl.registerLazySingleton(() => CompleteTutorialUseCase(sl()));

  // Animation Use Case
  sl.registerLazySingleton(() => ControlAnimationUseCase());

  //! Features - BLoCs (equivalent to React hooks and contexts)
  
  // Auth BLoC (equivalent to Auth0ProviderWrapper)
  sl.registerFactory(
    () => AuthBloc(
      loginUseCase: sl(),
      logoutUseCase: sl(),
      getUserProfileUseCase: sl(),
      validateAuthConfigUseCase: sl(),
    ),
  );

  // Ocean Data BLoC (equivalent to OceanDataContext)
  sl.registerFactory(
    () => OceanDataBloc(
      getOceanDataUseCase: sl(),
      updateTimeRangeUseCase: sl(),
      controlAnimationUseCase: sl(),
      connectHoloOceanUseCase: sl(),
    ),
  );

  // Chat BLoC (equivalent to useChatManagement hook)
  sl.registerFactory(
    () => ChatBloc(
      sendMessageUseCase: sl(),
      getChatHistoryUseCase: sl(),
      chatRepository: sl(),
    ),
  );

  // HoloOcean BLoC (equivalent to useHoloOcean hook)
  sl.registerFactory(
    () => HoloOceanBloc(
      holoOceanService: sl<HoloOceanServiceRemoteDataSource>(),
      authBloc: sl(),
    ),
  );

  // Map BLoC (equivalent to map components state)
  sl.registerFactory(
    () => MapBloc(
      getStationsUseCase: sl(),
      selectStationUseCase: sl(),
      mapRepository: sl(),
    ),
  );

  // Tutorial BLoC (equivalent to useTutorial hook)
  sl.registerFactory(
    () => TutorialBloc(
      storage: sl(),
    ),
  );

  // Animation BLoC (equivalent to useAnimationControl hook)
  sl.registerFactory(() => AnimationBloc());

  // API BLoC (equivalent to useApiIntegration hook)
  sl.registerFactory(() => ApiBloc());

  // Data Management BLoC (equivalent to useDataManagement hook)
  sl.registerFactory(
    () => DataManagementBloc(
      dataSource: sl(),
      authBloc: sl(),
    ),
  );

  // Environmental Data BLoC (equivalent to useEnvironmentalData hook)
  sl.registerFactory(() => EnvironmentalDataBloc());

  // Time Management BLoC (equivalent to useTimeManagement hook)
  sl.registerFactory(() => TimeManagementBloc());

  // UI Controls BLoC (equivalent to useUIControls hook)
  sl.registerFactory(() => UIControlsBloc());
}