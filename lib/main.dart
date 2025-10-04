import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'app.dart';
import 'core/utils/performance_monitoring.dart';
import 'injection_container.dart' as di;
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

final GetIt sl = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependency injection (equivalent to importing services)
  await di.init();
  
  // Initialize performance monitoring (equivalent to reportWebVitals)
  if (kDebugMode) {
    PerformanceMonitoring.init();
  }
  
  runApp(const OceanographicPlatformApp());
}

class OceanographicPlatformApp extends StatelessWidget {
  const OceanographicPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiBlocProvider equivalent to React.StrictMode + Auth0ProviderWrapper + BrowserRouter
    return MultiBlocProvider(
      providers: [
        // Auth BLoC (equivalent to Auth0ProviderWrapper context)
        BlocProvider<AuthBloc>(
          create: (context) => sl<AuthBloc>()..add(const AuthInitializeEvent()),
        ),
        
        // Ocean Data BLoC (equivalent to OceanDataContext)
        BlocProvider<OceanDataBloc>(
          create: (context) => sl<OceanDataBloc>(),
        ),
        
        // Chat Management BLoC (equivalent to useChatManagement hook)
        BlocProvider<ChatBloc>(
          create: (context) => sl<ChatBloc>(),
        ),
        
        // HoloOcean BLoC (equivalent to useHoloOcean hook)
        BlocProvider<HoloOceanBloc>(
          create: (context) => sl<HoloOceanBloc>(),
        ),
        
        // Map BLoC (equivalent to map-related state management)
        BlocProvider<MapBloc>(
          create: (context) => sl<MapBloc>(),
        ),
        
        // Tutorial BLoC (equivalent to useTutorial hook)
        BlocProvider<TutorialBloc>(
          create: (context) => sl<TutorialBloc>(),
        ),
        
        // Animation Control BLoC (equivalent to useAnimationControl hook)
        BlocProvider<AnimationBloc>(
          create: (context) => sl<AnimationBloc>(),
        ),
        
        // API Integration BLoC (equivalent to useApiIntegration hook)
        BlocProvider<ApiBloc>(
          create: (context) => sl<ApiBloc>(),
        ),
        
        // Data Management BLoC (equivalent to useDataManagement hook)
        BlocProvider<DataManagementBloc>(
          create: (context) => sl<DataManagementBloc>(),
        ),
        
        // Environmental Data BLoC (equivalent to useEnvironmentalData hook)
        BlocProvider<EnvironmentalDataBloc>(
          create: (context) => sl<EnvironmentalDataBloc>(),
        ),
        
        // Time Management BLoC (equivalent to useTimeManagement hook)
        BlocProvider<TimeManagementBloc>(
          create: (context) => sl<TimeManagementBloc>(),
        ),
        
        // UI Controls BLoC (equivalent to useUIControls hook)
        BlocProvider<UIControlsBloc>(
          create: (context) => sl<UIControlsBloc>(),
        ),
      ],
      child: const App(), // Equivalent to <App /> component
    );
  }
}