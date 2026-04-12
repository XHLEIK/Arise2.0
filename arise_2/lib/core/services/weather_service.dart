import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature;
  final String condition;
  final String city;
  final String localTime;

  WeatherData({
    required this.temperature,
    required this.condition,
    required this.city,
    required this.localTime,
  });

  factory WeatherData.zero() {
    return WeatherData(
      temperature: 0.0,
      condition: "Unknown",
      city: "Connecting...",
      localTime: "00:00 AM",
    );
  }
}

class WeatherService {
  final String _baseUrl = 'http://localhost:8081/api/system';

  final _weatherController = StreamController<WeatherData>.broadcast();
  Stream<WeatherData> get weatherStream => _weatherController.stream;

  Timer? _weatherTimer;
  Timer? _clockTimer;

  WeatherData _lastKnownWeather = WeatherData.zero();

  void startPolling() {
    _fetchWeather();
    // Refresh weather every 15 minutes as per user spec
    _weatherTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _fetchWeather(),
    );

    // Refresh time every 1 second instantly on frontend
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateLiveClock(),
    );
  }

  void stopPolling() {
    _weatherTimer?.cancel();
    _clockTimer?.cancel();
  }

  Future<void> _fetchWeather() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/weather'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _lastKnownWeather = WeatherData(
          temperature: (data['temperature'] ?? 0.0).toDouble(),
          condition: data['condition'] ?? 'Unknown',
          city: data['city'] ?? 'Unknown Location',
          localTime: _formatCurrentTime(),
        );
        _weatherController.add(_lastKnownWeather);
      }
    } catch (e) {
      // Retain last known weather if possible, but keep ticking the clock
    }
  }

  void _updateLiveClock() {
    if (_lastKnownWeather.city != "Connecting...") {
      _lastKnownWeather = WeatherData(
        temperature: _lastKnownWeather.temperature,
        condition: _lastKnownWeather.condition,
        city: _lastKnownWeather.city,
        localTime: _formatCurrentTime(),
      );
      _weatherController.add(_lastKnownWeather);
    }
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    int hour = now.hour;
    final String meridian = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    hour = hour == 0 ? 12 : hour;
    final String min = now.minute.toString().padLeft(2, '0');
    return '$hour:$min $meridian';
  }

  void dispose() {
    stopPolling();
    _weatherController.close();
  }
}
