import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SystemMetrics {
  final double cpuUsage;
  final double cpuTemp;
  final double gpuUsage;
  final double gpuTemp;
  final double ramUsage;
  final double storageUsage;

  SystemMetrics({
    required this.cpuUsage,
    required this.cpuTemp,
    required this.gpuUsage,
    required this.gpuTemp,
    required this.ramUsage,
    required this.storageUsage,
  });

  factory SystemMetrics.fromJson(Map<String, dynamic> json) {
    return SystemMetrics(
      cpuUsage: (json['cpuUsage'] ?? 0.0).toDouble(),
      cpuTemp: (json['cpuTemp'] ?? 0.0).toDouble(),
      gpuUsage: (json['gpuUsage'] ?? 0.0).toDouble(),
      gpuTemp: (json['gpuTemp'] ?? 0.0).toDouble(),
      ramUsage: (json['ramUsage'] ?? 0.0).toDouble(),
      storageUsage: (json['storageUsage'] ?? 0.0).toDouble(),
    );
  }

  // Factory for empty zeroed metrics
  factory SystemMetrics.zero() {
    return SystemMetrics(
      cpuUsage: 0.0,
      cpuTemp: 0.0,
      gpuUsage: 0.0,
      gpuTemp: 0.0,
      ramUsage: 0.0,
      storageUsage: 0.0,
    );
  }
}

class SystemMetricsService {
  final String _baseUrl = 'http://localhost:8081/api/system';

  // Keep 20 data points for the sparkline history
  final int _maxHistory = 20;

  final _cpuHistoryController = StreamController<List<double>>.broadcast();
  final _gpuHistoryController = StreamController<List<double>>.broadcast();
  final _ramHistoryController = StreamController<List<double>>.broadcast();
  final _metricsController = StreamController<SystemMetrics>.broadcast();

  final List<double> _cpuHistory = [];
  final List<double> _gpuHistory = [];
  final List<double> _ramHistory = [];

  Timer? _pollingTimer;

  Stream<List<double>> get cpuHistory => _cpuHistoryController.stream;
  Stream<List<double>> get gpuHistory => _gpuHistoryController.stream;
  Stream<List<double>> get ramHistory => _ramHistoryController.stream;
  Stream<SystemMetrics> get metrics => _metricsController.stream;

  List<double> get currentCpuHistory => _cpuHistory;
  List<double> get currentGpuHistory => _gpuHistory;
  List<double> get currentRamHistory => _ramHistory;
  List<double> get currentStorageHistory => [];

  void startPolling() {
    // Initial fetch
    _fetchMetrics();
    // Poll every 2 seconds matching the backend NVML loop
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchMetrics();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> _fetchMetrics() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/metrics'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final metrics = SystemMetrics.fromJson(data);

        _updateHistory(_cpuHistory, metrics.cpuUsage, _cpuHistoryController);
        _updateHistory(_gpuHistory, metrics.gpuUsage, _gpuHistoryController);
        _updateHistory(_ramHistory, metrics.ramUsage, _ramHistoryController);

        _metricsController.add(metrics);
      } else {
        _handleDisconnect();
      }
    } catch (e) {
      // Backend unreachable
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    final zeros = SystemMetrics.zero();
    _updateHistory(_cpuHistory, 0.0, _cpuHistoryController);
    _updateHistory(_gpuHistory, 0.0, _gpuHistoryController);
    _updateHistory(_ramHistory, 0.0, _ramHistoryController);
    _metricsController.add(zeros);
  }

  void _updateHistory(
    List<double> history,
    double newValue,
    StreamController<List<double>> controller,
  ) {
    history.add(newValue);
    if (history.length > _maxHistory) {
      history.removeAt(0);
    }
    controller.add(List.from(history)); // emit copy
  }

  void dispose() {
    stopPolling();
    _cpuHistoryController.close();
    _gpuHistoryController.close();
    _ramHistoryController.close();
    _metricsController.close();
  }
}
