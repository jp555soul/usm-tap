import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/ocean_data/ocean_data_bloc.dart';
import 'presentation/blocs/tutorial/tutorial_bloc.dart';
import 'data/datasources/local/session_key_service.dart';
import 'injection_container.dart' as di;

// Widget imports
import 'presentation/widgets/auth/auth_configuration_error_widget.dart';
import 'presentation/widgets/layout/header_widget.dart';
import 'presentation/widgets/panels/control_panel_widget.dart';
import 'presentation/widgets/map/map_container_widget.dart';
import 'presentation/widgets/panels/data_panels_widget.dart';
import 'presentation/widgets/panels/output_module_widget.dart';
import 'presentation/widgets/chatbot/chatbot_widget.dart';
import 'presentation/widgets/tutorial/tutorial_widget.dart';
import 'presentation/widgets/tutorial/tutorial_overlay_widget.dart';
import 'data/models/chat_message.dart' as DataModels;
import 'domain/entities/env_data_entity.dart';
import 'domain/entities/station_data_entity.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oceanographic Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: '/',
      home: const AppRouterWidget(),
    );
  }
}

class AppRouterWidget extends StatelessWidget {
  const AppRouterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/auth/callback':
            return MaterialPageRoute(
              builder: (_) => const AuthCallbackPage(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const MainAppWidget(),
            );
        }
      },
    );
  }
}

class MainAppWidget extends StatefulWidget {
  const MainAppWidget({super.key});

  @override
  State<MainAppWidget> createState() => _MainAppWidgetState();
}

class _MainAppWidgetState extends State<MainAppWidget> {
  late SessionKeyService _sessionKeyService;

  @override
  void initState() {
    super.initState();
    _sessionKeyService = di.sl<SessionKeyService>();
    _setupSessionKey();
  }

  void _setupSessionKey() {
    context.read<AuthBloc>().stream.listen((authState) {
      if (authState is AuthenticatedState) {
        final secret = AppConstants.auth0ClientSecret;
        final salt = authState.user.id;
        if (secret.isNotEmpty) {
          final key = _generateSessionKey(secret, salt);
          _sessionKeyService.setSessionKey(key);
        } else {
          debugPrint('AUTH0_CLIENT_SECRET is not set. Local storage will not be encrypted.');
        }
      }
    });
  }

  String _generateSessionKey(String secret, String salt) {
    final bytes = utf8.encode(secret + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        // Handle configuration errors
        if (authState is AuthConfigurationErrorState) {
          return AuthConfigurationErrorWidget(
            missingVariables: authState.missingVariables,
          );
        }

        // Handle auth errors
        if (authState is AuthErrorState) {
          return Container(
            color: const Color(0xFF0F172A),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Authentication Error',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      authState.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(const AuthRetryEvent());
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Handle loading state
        if (authState is AuthLoadingState) {
          return Container(
            color: const Color(0xFF0F172A),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading Ocean Platform...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        // Handle unauthenticated state
        if (authState is UnauthenticatedState) {
          return Container(
            color: const Color(0xFF0F172A),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome to the Oceanographic Platform',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please log in to continue.',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(const AuthLoginEvent());
                    },
                    child: const Text('Log In'),
                  ),
                ],
              ),
            ),
          );
        }

        // Handle authenticated state
        if (authState is AuthenticatedState) {
          return const OceanPlatformWidget();
        }

        // Fallback for initial state or unknown states
        return Container(
          color: const Color(0xFF0F172A),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
            ),
          ),
        );
      },
    );
  }
}

class OceanPlatformWidget extends StatefulWidget {
  const OceanPlatformWidget({super.key});

  @override
  State<OceanPlatformWidget> createState() => _OceanPlatformWidgetState();
}

class _OceanPlatformWidgetState extends State<OceanPlatformWidget> {
  bool isOutputCollapsed = true;
  bool showApiConfig = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkApiStatus();
    _setupApiConfigListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkApiStatus() {
    final oceanDataBloc = context.read<OceanDataBloc>();
    oceanDataBloc.add(const CheckApiStatusEvent());
  }

  void _setupApiConfigListener() {
    context.read<OceanDataBloc>().stream.listen((oceanState) {
      if (oceanState is OceanDataLoadedState) {
        if (oceanState.connectionStatus != null && 
            !oceanState.connectionStatus!.connected && 
            !showApiConfig) {
          if (!oceanState.connectionStatus!.hasApiKey && 
              oceanState.connectionStatus!.endpoint.isNotEmpty) {
            setState(() {
              showApiConfig = true;
            });
          }
        }
      }
    });
  }

  String? _getTutorialTarget(int step) {
    const targets = {
      1: 'control-panel',
      2: 'map-container',
      3: 'data-panels',
      4: 'output-module',
      5: 'chatbot',
      6: 'holoocean-panel',
    };
    return targets[step];
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OceanDataBloc, OceanDataState>(
      builder: (context, oceanState) {
        // Show loading indicator while ocean data is being fetched
        if (oceanState is! OceanDataLoadedState) {
          return Container(
            color: const Color(0xFF0F172A),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading ocean data...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return BlocBuilder<TutorialBloc, TutorialState>(
          builder: (context, tutorialState) {
            return BlocBuilder<AuthBloc, AuthState>(builder: (context, authState) {
              return Scaffold(
                backgroundColor: const Color(0xFF0F172A),
                body: Stack(
                  children: [
                    Column(
                      children: [
                        // Header (Fixed at top)
                        HeaderWidget(
                          key: const Key('header'),
                          dataSource: oceanState.dataSource,
                          timeZone: oceanState.timeZone,
                          onTimeZoneChange: (timeZone) {
                            context.read<OceanDataBloc>().add(
                                  SetTimeZoneEvent(timeZone),
                                );
                          },
                          connectionStatus:
                              oceanState.connectionStatus?.state.name ?? 'disconnected',
                          dataQuality: oceanState.dataQuality != null
                              ? DataQuality(
                                  stations: (oceanState.dataQuality!['stations'] as int?) ?? 0,
                                  measurements: (oceanState.dataQuality!['measurements'] as int?) ?? 0,
                                  lastUpdate:
                                      oceanState.dataQuality!['lastUpdate'] != null
                                          ? DateTime.parse(
                                              oceanState.dataQuality!['lastUpdate'] as String)
                                          : null,
                                )
                              : null,
                          showDataStatus: true,
                          showTutorial: tutorialState is TutorialInProgress,
                          onTutorialToggle: (value) {
                            if (tutorialState is TutorialInProgress) {
                              context.read<TutorialBloc>().add(const CloseTutorialEvent());
                            } else {
                              context.read<TutorialBloc>().add(const StartTutorialEvent());
                            }
                          },
                          tutorialStep: tutorialState is TutorialInProgress
                              ? tutorialState.currentStep
                              : 0,
                          isFirstTimeUser: tutorialState is TutorialNotStarted,
                          isAuthenticated: authState is AuthenticatedState,
                        ),

                        // Main Content (Scrollable with permanent scrollbar)
                        Expanded(
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            thickness: 8,
                            radius: const Radius.circular(4),
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              child: Column(
                                children: [
                                  // Control Panel
                                  Container(
                                    key: const Key('control-panel'),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0x4DEC4899),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: ControlPanelWidget(
                                      isLoading: oceanState.isLoading,
                                      availableModels: oceanState.availableModels,
                                      availableDepths: oceanState.availableDepths,
                                      dataLoaded: oceanState.dataLoaded,
                                      selectedArea: oceanState.selectedArea,
                                      selectedModel: oceanState.selectedModel,
                                      selectedDepth: oceanState.selectedDepth,
                                      startDate: oceanState.startDate,
                                      endDate: oceanState.endDate,
                                      timeZone: oceanState.timeZone,
                                      currentFrame: oceanState.currentFrame,
                                      isPlaying: oceanState.isPlaying,
                                      playbackSpeed: oceanState.playbackSpeed,
                                      loopMode: oceanState.loopMode ? 'loop' : 'once',
                                      holoOceanPOV: oceanState.holoOceanPOV,
                                      totalFrames: oceanState.totalFrames,
                                      data: oceanState.data,
                                      mapLayerVisibility:
                                          oceanState.mapLayerVisibility,
                                      isSstHeatmapVisible:
                                          oceanState.isSstHeatmapVisible,
                                      currentsVectorScale:
                                          oceanState.currentsVectorScale,
                                      currentsColorBy: oceanState.currentsColorBy,
                                      heatmapScale: (oceanState.heatmapScale['value'] as num?)?.toDouble() ?? 1.0,
                                      onAreaChange: (area) {
                                        context.read<OceanDataBloc>().add(
                                              SetSelectedAreaEvent(area),
                                            );
                                      },
                                      onModelChange: (model) {
                                        context.read<OceanDataBloc>().add(
                                              SetSelectedModelEvent(model),
                                            );
                                      },
                                      onDepthChange: (depth) {
                                        context.read<OceanDataBloc>().add(
                                              SetSelectedDepthEvent(depth),
                                            );
                                      },
                                      onDateRangeChange: (startDate, endDate) {
                                        context.read<OceanDataBloc>().add(
                                              SetDateRangeEvent(startDate, endDate),
                                            );
                                      },
                                      onTimeZoneChange: (timeZone) {
                                        context.read<OceanDataBloc>().add(
                                              SetTimeZoneEvent(timeZone),
                                            );
                                      },
                                      onSpeedChange: (speed) {
                                        context.read<OceanDataBloc>().add(
                                              SetPlaybackSpeedEvent(speed),
                                            );
                                      },
                                      onLoopModeChange: (loopMode) {
                                        context.read<OceanDataBloc>().add(
                                              SetLoopModeEvent(loopMode == 'loop'),
                                            );
                                      },
                                      onFrameChange: (frame) {
                                        context.read<OceanDataBloc>().add(
                                              SetCurrentFrameEvent(frame),
                                            );
                                      },
                                      onReset: () {
                                        context.read<OceanDataBloc>().add(
                                              const ResetDataEvent(),
                                            );
                                      },
                                      onLayerToggle: (layer) {
                                        context.read<OceanDataBloc>().add(
                                              ToggleMapLayerEvent(layer),
                                            );
                                      },
                                      onSstHeatmapToggle: () {
                                        context.read<OceanDataBloc>().add(
                                              const ToggleSstHeatmapEvent(),
                                            );
                                      },
                                      onCurrentsScaleChange: (scale) {
                                        context.read<OceanDataBloc>().add(
                                              SetCurrentsVectorScaleEvent(scale),
                                            );
                                      },
                                      onCurrentsColorChange: (colorBy) {
                                        context.read<OceanDataBloc>().add(
                                              SetCurrentsColorByEvent(colorBy),
                                            );
                                      },
                                      onHeatmapScaleChange: (scale) {
                                        context.read<OceanDataBloc>().add(
                                              SetHeatmapScaleEvent({'value': scale}),
                                            );
                                      },
                                    ),
                                  ),

                                  // Map and Output Section
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.4,
                                    child: Row(
                                      children: [
                                        // Map Container
                                        Expanded(
                                          flex: isOutputCollapsed ? 5 : 1,
                                          child: Container(
                                            key: const Key('map-container'),
                                            child: MapContainerWidget(
                                              mapboxToken: AppConstants.mapboxAccessToken,
                                              stationData: oceanState.stationData.map((s) => {
                                                'id': s.id,
                                                'name': s.name,
                                                'latitude': s.latitude,
                                                'longitude': s.longitude,
                                                'type': s.type,
                                                'description': s.description,
                                              }).toList(),
                                              timeSeriesData:
                                                  oceanState.timeSeriesData,
                                              rawData: [oceanState.rawData],
                                              currentsGeoJSON:
                                                  oceanState.currentsGeoJSON,
                                              currentFrame:
                                                  oceanState.currentFrame,
                                              selectedDepth:
                                                  oceanState.selectedDepth,
                                              selectedArea:
                                                  oceanState.selectedArea,
                                              holoOceanPOV:
                                                  oceanState.holoOceanPOV,
                                              currentDate: oceanState.currentDate.toIso8601String(),
                                              currentTime: oceanState.currentTime,
                                              mapLayerVisibility:
                                                  oceanState.mapLayerVisibility,
                                              currentsVectorScale:
                                                  oceanState.currentsVectorScale,
                                              currentsColorBy:
                                                  oceanState.currentsColorBy,
                                              heatmapScale:
                                                  (oceanState.heatmapScale['value'] as num?)?.toDouble() ?? 1.0,
                                              isOutputCollapsed:
                                                  isOutputCollapsed,
                                              availableDepths:
                                                  oceanState.availableDepths,
                                              onPOVChange: (pov) {
                                                context.read<OceanDataBloc>().add(
                                                      SetHoloOceanPOVEvent(pov),
                                                    );
                                              },
                                              onDepthChange: (depth) {
                                                context.read<OceanDataBloc>().add(
                                                      SetSelectedDepthEvent(depth),
                                                    );
                                              },
                                              onStationSelect: (station) {
                                                if (station == null) {
                                                  context.read<OceanDataBloc>().add(
                                                        const SetSelectedStationEvent(null),
                                                      );
                                                  return;
                                                }
                                                final stationEntity = StationDataEntity(
                                                  id: station['id'] as String? ?? 'default_id',
                                                  name: station['name'] as String? ?? 'Unknown Station',
                                                  latitude: (station['latitude'] as num?)?.toDouble() ?? 0.0,
                                                  longitude: (station['longitude'] as num?)?.toDouble() ?? 0.0,
                                                  type: station['type'] as String?,
                                                  description: station['description'] as String?,
                                                );
                                                context.read<OceanDataBloc>().add(
                                                      SetSelectedStationEvent(
                                                          stationEntity),
                                                    );
                                              },
                                              onEnvironmentUpdate: (envData) {
                                                if (envData == null) return;

                                                final timestampStr = envData['timestamp'] as String?;
                                                final timestamp = timestampStr != null
                                                    ? DateTime.tryParse(timestampStr) ?? DateTime.now()
                                                    : DateTime.now();

                                                final envEntity = EnvDataEntity(
                                                  timestamp: timestamp,
                                                  windSpeed: (envData['windSpeed'] as num?)?.toDouble(),
                                                  windDirection: (envData['windDirection'] as num?)?.toDouble(),
                                                  airTemperature: (envData['airTemperature'] as num?)?.toDouble(),
                                                  airPressure: (envData['airPressure'] as num?)?.toDouble(),
                                                  humidity: (envData['humidity'] as num?)?.toDouble(),
                                                  waveHeight: (envData['waveHeight'] as num?)?.toDouble(),
                                                  wavePeriod: (envData['wavePeriod'] as num?)?.toDouble(),
                                                  visibility: (envData['visibility'] as num?)?.toDouble(),
                                                  cloudCover: (envData['cloudCover'] as num?)?.toDouble(),
                                                  weatherCondition: envData['weatherCondition'] as String?,
                                                );

                                                context.read<OceanDataBloc>().add(
                                                      SetEnvDataEvent(envEntity),
                                                    );
                                              },
                                            ),
                                          ),
                                        ),

                                        // Output Module
                                        Expanded(
                                          flex: isOutputCollapsed ? 1 : 1,
                                          child: Container(
                                            key: const Key('output-module'),
                                            child: OutputModuleWidget(
                                              chatMessages:
                                                  oceanState.chatMessages,
                                              timeSeriesData:
                                                  oceanState.timeSeriesData,
                                              currentsGeoJSON:
                                                  oceanState.currentsGeoJSON,
                                              currentFrame:
                                                  oceanState.currentFrame,
                                              selectedDepth:
                                                  oceanState.selectedDepth,
                                              isTyping: oceanState.isTyping,
                                              isCollapsed: isOutputCollapsed,
                                              onToggleCollapse: () {
                                                setState(() {
                                                  isOutputCollapsed =
                                                      !isOutputCollapsed;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Data Panels
                                  SizedBox(
                                    //height: MediaQuery.of(context).size.height * 0.6,
                                    child: Container(
                                      key: const Key('data-panels'),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Color(0x4D10B981),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: DataPanelsWidget(
                                        envData: oceanState.envData,
                                        holoOceanPOV: oceanState.holoOceanPOV,
                                        selectedDepth: oceanState.selectedDepth,
                                        timeSeriesData: oceanState.timeSeriesData,
                                        currentFrame: oceanState.currentFrame,
                                        availableDepths: oceanState.availableDepths,
                                        onDepthChange: (depth) {
                                          context.read<OceanDataBloc>().add(
                                                SetSelectedDepthEvent(depth),
                                              );
                                        },
                                        onPOVChange: (pov) {
                                          context.read<OceanDataBloc>().add(
                                                SetHoloOceanPOVEvent(pov),
                                              );
                                        },
                                        onRefreshData: () {
                                          context.read<OceanDataBloc>().add(
                                                const RefreshDataEvent(),
                                              );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Chatbot (Floating/Overlay)
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: SizedBox(
                        width: 400,
                        height: 600,
                        child: ChatbotWidget(
                          key: const Key('chatbot'),
                          timeSeriesData: oceanState.timeSeriesData,
                          data: oceanState.data,
                          dataSource: oceanState.dataSource,
                          selectedDepth: oceanState.selectedDepth,
                          availableDepths: oceanState.availableDepths,
                          selectedArea: oceanState.selectedArea,
                          selectedModel: oceanState.selectedModel,
                          playbackSpeed: oceanState.playbackSpeed,
                          currentFrame: oceanState.currentFrame,
                          holoOceanPOV: oceanState.holoOceanPOV,
                          envData: oceanState.envData?.toJson() ?? {},
                          timeZone: oceanState.timeZone,
                          startDate: oceanState.startDate,
                          endDate: oceanState.endDate,
                          onAddMessage: (message) {
                            final chatMessage = DataModels.ChatMessage(
                              id: message.id,
                              content: message.content,
                              isUser: message.isUser,
                              timestamp: message.timestamp,
                              source: message.source,
                              retryAttempt: message.retryAttempt,
                            );
                            context.read<OceanDataBloc>().add(
                                  AddChatMessageEvent(chatMessage),
                                );
                          },
                        ),
                      ),
                    ),

                    // Tutorial
                    if (tutorialState is TutorialInProgress)
                      TutorialWidget(
                        isOpen: true,
                        tutorialStep: tutorialState.currentStep,
                        onClose: () {
                          context
                              .read<TutorialBloc>()
                              .add(const CloseTutorialEvent());
                        },
                        onComplete: () {
                          context
                              .read<TutorialBloc>()
                              .add(const CompleteTutorialEvent());
                        },
                        onStepChange: (step) {
                          context
                              .read<TutorialBloc>()
                              .add(SetTutorialStepEvent(step));
                        },
                      ),

                    // Tutorial Overlay
                    if (tutorialState is TutorialInProgress)
                      TutorialOverlayWidget(
                        isActive: true,
                        targetSelector:
                            _getTutorialTarget(tutorialState.currentStep),
                        highlightType: 'spotlight',
                        showPointer: tutorialState.currentStep > 0,
                      ),
                  ],
                ),
              );
            });
          },
        );
      },
    );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
        ),
      ),
    );
  }
}

class AuthCallbackPage extends StatelessWidget {
  const AuthCallbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
            ),
            SizedBox(height: 16),
            Text(
              'Completing login...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}