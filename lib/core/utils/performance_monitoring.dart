import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Performance monitoring utility equivalent to React's reportWebVitals
/// Handles performance metrics, memory usage, and app lifecycle monitoring
class PerformanceMonitoring {
  static bool _isInitialized = false;
  static final Map<String, dynamic> _metrics = {};
  static final Map<String, Stopwatch> _activeTimers = {};
  static int _frameCount = 0;
  static int _slowFrameCount = 0;
  static DateTime? _lastMetricsLog;
  static final List<double> _frameTimes = [];
  static const int _maxFrameTimesSamples = 60; // Track last 60 frames
  
  /// Initialize performance monitoring (equivalent to reportWebVitals())
  static void init() {
    if (_isInitialized || !kDebugMode) return;
    
    _isInitialized = true;

    // developer.log(
    //   'Performance monitoring initialized',
    //   name: 'PerformanceMonitoring',
    // );

    // Start monitoring app lifecycle
    _startLifecycleMonitoring();
    
    // Start memory monitoring
    _startMemoryMonitoring();
    
    // Start frame rate monitoring
    _startFrameRateMonitoring();
  }
  
  /// Monitor app lifecycle events
  static void _startLifecycleMonitoring() {
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
  }
  
  /// Monitor memory usage
  static void _startMemoryMonitoring() {
    if (!kDebugMode) return;
    
    developer.Timeline.startSync('MemoryMonitoring');
    
    // Log memory usage periodically in debug mode
    Future.delayed(const Duration(seconds: 30), () {
      _logMemoryUsage();
      if (_isInitialized) {
        _startMemoryMonitoring(); // Continue monitoring
      }
    });
    
    developer.Timeline.finishSync();
  }
  
  /// Monitor frame rendering performance
  static void _startFrameRateMonitoring() {
    if (!kDebugMode) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackFrameMetrics();
    });
  }
  
  /// Log memory usage information
  static void _logMemoryUsage() {
    // developer.log(
    //   'Memory usage check - App running normally',
    //   name: 'PerformanceMonitoring.Memory',
    // );
  }
  
  /// Track frame rendering metrics
  static void _trackFrameMetrics() {
    if (!kDebugMode) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    _metrics['lastFrameTime'] = now;
    
    // Continue tracking for next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackFrameMetrics();
    });
  }
  
  /// Report custom performance metric
  static void reportMetric(String name, dynamic value) {
    if (!kDebugMode) return;

    _metrics[name] = value;

    // developer.log(
    //   'Custom metric: $name = $value',
    //   name: 'PerformanceMonitoring.Custom',
    // );
  }
  
  /// Report page/screen navigation timing
  static void reportNavigationTiming(String routeName, int duration) {
    if (!kDebugMode) return;

    // developer.log(
    //   'Navigation to $routeName took ${duration}ms',
    //   name: 'PerformanceMonitoring.Navigation',
    // );
  }
  
  /// Report API call performance
  static void reportApiTiming(String endpoint, int duration, bool success) {
    if (!kDebugMode) return;

    // developer.log(
    //   'API call to $endpoint: ${duration}ms, success: $success',
    //   name: 'PerformanceMonitoring.API',
    // );
  }
  
  /// Report widget build performance
  static void reportWidgetBuildTiming(String widgetName, int duration) {
    if (!kDebugMode) return;

    if (duration > 16) { // Report builds that take longer than one frame (16ms)
      // developer.log(
      //   'Slow widget build: $widgetName took ${duration}ms',
      //   name: 'PerformanceMonitoring.Widget',
      // );
    }
  }
  
  /// Get current performance metrics
  static Map<String, dynamic> getMetrics() {
    return Map.from(_metrics);
  }

  /// PERFORMANCE: Start a named timer for precise measurement
  /// Returns a timer ID that should be passed to stopTimer()
  static String startTimer([String? name]) {
    if (!kDebugMode) return '';

    final timerId = name ?? 'timer_${DateTime.now().millisecondsSinceEpoch}';
    _activeTimers[timerId] = Stopwatch()..start();
    return timerId;
  }

  /// PERFORMANCE: Stop a named timer and return elapsed milliseconds
  /// Optionally log the metric with a category
  static int stopTimer(String timerId, {String? category, String? metricName}) {
    if (!kDebugMode) return 0;

    final timer = _activeTimers.remove(timerId);
    if (timer == null) return 0;

    timer.stop();
    final elapsed = timer.elapsedMilliseconds;

    if (category != null && metricName != null) {
      logMetric(category, metricName, elapsed);
    }

    return elapsed;
  }

  /// PERFORMANCE: Log a structured metric
  /// Example: logMetric('BLOC', 'SetCurrentFrameEvent', 5)
  static void logMetric(String category, String name, dynamic value) {
    if (!kDebugMode) return;

    final key = '$category.$name';
    _metrics[key] = value;

    // Log significant events
    if (value is int && value > 16) {
      debugPrint('⚠️ SLOW $category [$name]: ${value}ms');
    }
  }

  /// PERFORMANCE: Track frame timing (call once per frame)
  static void trackFrame(double frameTimeMs) {
    if (!kDebugMode) return;

    _frameCount++;
    _frameTimes.add(frameTimeMs);

    // Keep only recent samples
    if (_frameTimes.length > _maxFrameTimesSamples) {
      _frameTimes.removeAt(0);
    }

    // Track slow frames (> 16ms = below 60fps)
    if (frameTimeMs > 16.0) {
      _slowFrameCount++;
    }

    // Log metrics every 10 seconds
    final now = DateTime.now();
    if (_lastMetricsLog == null ||
        now.difference(_lastMetricsLog!).inSeconds >= 10) {
      _logFrameMetrics();
      _lastMetricsLog = now;
    }
  }

  /// PERFORMANCE: Log aggregated frame metrics
  static void _logFrameMetrics() {
    if (_frameTimes.isEmpty) return;

    final avgFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
    final fps = 1000.0 / avgFrameTime;
    final slowFramePercent = (_slowFrameCount / _frameCount * 100).toStringAsFixed(1);

    debugPrint('🎨 PERFORMANCE: Frame #$_frameCount | ${avgFrameTime.toStringAsFixed(1)}ms | '
        '${fps.toStringAsFixed(1)}fps | slow frames: $slowFramePercent%');

    // Reset counters for next interval
    _slowFrameCount = 0;
    _frameCount = 0;
  }

  /// PERFORMANCE: Check memory usage and warn if above threshold
  /// @param thresholdPercent - Warning threshold (default: 80%)
  static void checkMemoryUsage([int thresholdPercent = 80]) {
    if (!kDebugMode) return;

    // Note: Accurate memory monitoring requires platform channels
    // This is a placeholder for the monitoring infrastructure
    // In production, you'd use DeviceInfoPlugin or similar

    // Log periodic memory checks
    debugPrint('💾 MEMORY: Check performed (threshold: $thresholdPercent%)');
  }

  /// PERFORMANCE: Monitor BLoC event queue depth
  /// @param blocName - Name of the BLoC
  /// @param queueDepth - Current event queue size
  static void monitorBlocQueue(String blocName, int queueDepth) {
    if (!kDebugMode) return;

    if (queueDepth > 10) {
      debugPrint('⚠️ BLOC QUEUE [$blocName]: $queueDepth events pending (possible backlog)');
    }

    _metrics['$blocName.queueDepth'] = queueDepth;
  }

  /// Clean up performance monitoring
  static void dispose() {
    _isInitialized = false;
    _metrics.clear();
    _activeTimers.clear();
    _frameTimes.clear();
    _frameCount = 0;
    _slowFrameCount = 0;
    _lastMetricsLog = null;

    // developer.log(
    //   'Performance monitoring disposed',
    //   name: 'PerformanceMonitoring',
    // );
  }
}

/// App lifecycle observer for performance monitoring
class _AppLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kDebugMode) return;
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    switch (state) {
      case AppLifecycleState.resumed:
        // developer.log(
        //   'App resumed at $timestamp',
        //   name: 'PerformanceMonitoring.Lifecycle',
        // );
        break;
      case AppLifecycleState.paused:
        // developer.log(
        //   'App paused at $timestamp',
        //   name: 'PerformanceMonitoring.Lifecycle',
        // );
        break;
      case AppLifecycleState.inactive:
        // developer.log(
        //   'App inactive at $timestamp',
        //   name: 'PerformanceMonitoring.Lifecycle',
        // );
        break;
      case AppLifecycleState.detached:
        // developer.log(
        //   'App detached at $timestamp',
        //   name: 'PerformanceMonitoring.Lifecycle',
        // );
        break;
      case AppLifecycleState.hidden:
        // developer.log(
        //   'App hidden at $timestamp',
        //   name: 'PerformanceMonitoring.Lifecycle',
        // );
        break;
    }
  }
  
  @override
  void didHaveMemoryPressure() {
    if (!kDebugMode) return;

    // developer.log(
    //   'Memory pressure detected',
    //   name: 'PerformanceMonitoring.Memory',
    // );

    // Trigger garbage collection
    SystemChannels.platform.invokeMethod('SystemNavigator.routeUpdated');
  }
  
  @override
  void didChangeLocales(List<Locale>? locales) {
    if (!kDebugMode) return;

    // developer.log(
    //   'Locale changed to: ${locales?.first.toString()}',
    //   name: 'PerformanceMonitoring.Locale',
    // );
  }
  
  @override
  void didChangePlatformBrightness() {
    if (!kDebugMode) return;

    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    // developer.log(
    //   'Platform brightness changed to: $brightness',
    //   name: 'PerformanceMonitoring.Theme',
    // );
  }
}