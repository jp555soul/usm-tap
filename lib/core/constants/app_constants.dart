/// Application-wide constants
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();
  
  // Auth0 Configuration
  static const String auth0Domain = String.fromEnvironment(
    'AUTH0_DOMAIN',
    defaultValue: 'https://dev-iehguv204612q2sk.us.auth0.com',
  );
  
  static const String auth0ClientId = String.fromEnvironment(
    'AUTH0_CLIENT_ID',
    defaultValue: 'RSiNbEo6RBx6Mxq0PT9YvbCXJKN7HG17',
  );
  
  static const String auth0ClientSecret = String.fromEnvironment(
    'AUTH0_CLIENT_SECRET',
    defaultValue: '84cbc5c3605411e6c07567dc4960b8d23fb159995cb73711c8058c45982bdab7',
  );
  
  static const String auth0Audience = String.fromEnvironment(
    'AUTH0_AUDIENCE',
    defaultValue: 'https://api.isdata.ai',
  );
  
  static const String auth0CallbackUrl = String.fromEnvironment(
    'AUTH0_CALLBACK_URL',
    defaultValue: '',
  );
  
  static const String auth0Secret = String.fromEnvironment(
    'AUTH0_SECRET',
    defaultValue: '84cbc5c3605411e6c07567dc4960b8d23fb159995cb73711c8058c45982bdab7',
  );
  
  // API Configuration
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://demo-chat.isdata.ai',
  );
  
  static const String bearerToken = String.fromEnvironment(
    'BEARER_TOKEN',
    defaultValue: '0S0290SN1929VM192SDSsld239092@%^&*341267812',
  );
  
  // Mapbox Configuration
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: 'pk.eyJ1Ijoiam1wYXVsbWFwYm94IiwiYSI6ImNtZHh0ZmR6MjFoaHIyam9vZmJ4Z2x1MDYifQ.gR60szhfKWhTv8MyqynpVA',
  );
  
  // App Information
  static const String appName = 'Oceanographic Platform';
  static const String appVersion = '1.0.0';
  
  // API Endpoints
  static const String chatEndpoint = '/chat/';
  static const String healthCheckEndpoint = '/healthz';
  
  // Timeout Configuration
  static const Duration apiTimeout = Duration(minutes: 10);
  static const Duration connectionTimeout = Duration(seconds: 30);
  
  // Retry Configuration
  static const int maxRetries = 2;
  
  // Data Defaults
  static const String defaultArea = 'USM';
  static const String defaultModel = 'NGOSF2';
  static const String defaultDepth = '0m';
  static const String defaultTimeZone = 'UTC';
  static const String defaultDataSource = 'simulated';
  
  // Animation Defaults
  static const double defaultPlaybackSpeed = 1.0;
  static const int defaultTotalFrames = 100;
  
  // Wind Velocity Particle Defaults
  static const int defaultWindVelocityParticleCount = 1000;
  static const double defaultWindVelocityParticleOpacity = 0.8;
  static const double defaultWindVelocityParticleSpeed = 1.0;
  
  // Map Visualization Defaults
  static const double defaultCurrentsVectorScale = 1.0;
  static const String defaultCurrentsColorBy = 'velocity';
  
  // Tutorial Configuration
  static const String tutorialStorageKey = 'tutorial_completed';
  static const String tutorialStepStorageKey = 'tutorial_current_step';
  
  // Session Storage Keys
  static const String sessionKeyStorageKey = 'session_key';
  static const String encryptedDataStorageKey = 'encrypted_data';
  
  // Chat Configuration
  static const int maxChatMessages = 100;
  static const Duration chatTypingDelay = Duration(milliseconds: 500);
  
  // HoloOcean Defaults
  static const Map<String, double> defaultHoloOceanPOV = {
    'x': 0.0,
    'y': 0.0,
    'z': 0.0,
  };
  
  // Available Depths (in meters)
  static const List<String> availableDepths = [
    '0m',
    '10m',
    '20m',
    '50m',
    '100m',
  ];
  
  // Available Models
  static const List<String> availableModels = [
    'NGOSF2',
    'HYCOM',
    'RTOFS',
  ];
  
  // Available Areas
  static const List<String> availableAreas = [
    'USM',
    'Gulf of Mexico',
    'Atlantic Ocean',
    'Pacific Ocean',
  ];
  
  // Color Schemes
  static const int primaryColor = 0xFF3B82F6; // blue-500
  static const int secondaryColor = 0xFF10B981; // green-500
  static const int accentColor = 0xFFEC4899; // pink-500
  static const int backgroundColor = 0xFF0F172A; // slate-900
  static const int errorColor = 0xFFEF4444; // red-500
  
  // Validation
  static bool get isAuth0Configured =>
      auth0Domain.isNotEmpty && auth0ClientId.isNotEmpty;
  
  static bool get isApiConfigured =>
      baseUrl.isNotEmpty && bearerToken.isNotEmpty;
  
  static bool get isMapboxConfigured => mapboxAccessToken.isNotEmpty;
  
  // Helper method to get missing auth variables
  static List<String> getMissingAuthVariables() {
    final missing = <String>[];
    
    if (auth0Domain.isEmpty) missing.add('AUTH0_DOMAIN');
    if (auth0ClientId.isEmpty) missing.add('AUTH0_CLIENT_ID');
    
    return missing;
  }
  
  // Helper method to get missing API variables
  static List<String> getMissingApiVariables() {
    final missing = <String>[];
    
    if (baseUrl.isEmpty) missing.add('BASE_URL');
    if (bearerToken.isEmpty) missing.add('BEARER_TOKEN');
    
    return missing;
  }
}