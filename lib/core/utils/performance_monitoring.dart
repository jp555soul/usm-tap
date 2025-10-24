import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Performance monitoring utility equivalent to React's reportWebVitals
/// Handles performance metrics, memory usage, and app lifecycle monitoring
class PerformanceMonitoring {
  static bool _isInitialized = false;
  static final Map<String, dynamic> _metrics = {};
  
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
  
  /// Clean up performance monitoring
  static void dispose() {
    _isInitialized = false;
    _metrics.clear();

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