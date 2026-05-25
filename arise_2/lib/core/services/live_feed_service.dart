import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_client.dart';

class FeedEntry {
  final String message;
  final String type;
  final String time;

  const FeedEntry({
    required this.message,
    required this.type,
    required this.time,
  });
}

class LiveFeedService {
  final String _baseUrl = '${AppConfig.springBaseUrl}/api/events';
  final List<FeedEntry> _entries = [];
  final _controller = StreamController<List<FeedEntry>>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  // Dedicated Voice Engine Streams mapped to Python PubSub telemetry
  final _amplitudeController = StreamController<double>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();
  final _voiceStateController = StreamController<String>.broadcast();

  String currentStatus = 'Ready ✓';

  // Reconnection state
  http.Client? _client;
  int _retryCount = 0;
  static const int _maxRetries = 30;

  Stream<List<FeedEntry>> get entries => _controller.stream;
  Stream<String> get modelStatus => _statusController.stream;
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get voiceStateStream => _voiceStateController.stream;

  LiveFeedService() {
    _connectToEventStream();
  }

  void _connectToEventStream() async {
    // Close previous client to prevent resource leak
    _client?.close();
    _client = http.Client();

    try {
      final request = http.Request('GET', Uri.parse('$_baseUrl/stream'))
        ..headers['Accept'] = 'text/event-stream'
        ..headers['X-API-KEY'] = AppConfig.apiKey;

      final response = await _client!.send(request);

      // Reset retry count on successful connection
      _retryCount = 0;

      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.startsWith('data:')) {
                try {
                  final data = jsonDecode(line.substring(5).trim());
                  final msgType = data['type'] as String?;
                  final msgContent = data['message'];

                  if (msgType == 'voice_events') {
                    // Extract structured sub-JSON emitted natively from Python FastApi
                    try {
                      final voiceData = jsonDecode(msgContent.toString());
                      final vType = voiceData['type'] as String;
                      final vData = voiceData['data'] ?? {};

                      if (vType == 'MIC_AMPLITUDE' ||
                          vType == 'TTS_AMPLITUDE') {
                        final val = vData['value'];
                        if (val != null) {
                          _amplitudeController.add((val as num).toDouble());
                        }
                      } else if (vType == 'TRANSCRIPT_READY' ||
                          vType == 'USER_MESSAGE') {
                        final t = vData['text'] as String?;
                        if (t != null && t.isNotEmpty) {
                          _transcriptController.add(t);
                        }
                      } else {
                        // Triggers state machine transitions: VOICE_MODE_ON, LISTENING, AI_THINKING, TTS_START
                        _voiceStateController.add(vType);
                      }
                    } catch (e) {
                      debugPrint('[LiveFeedService] voice event parse error: $e');
                    }
                  } else {
                    // Core Telemetry Logging
                    _entries.insert(
                      0,
                      FeedEntry(
                        message: msgContent.toString(),
                        type: msgType ?? 'info',
                        time: data['time']?.toString() ?? '',
                      ),
                    );

                    if (_entries.length > 100) _entries.removeLast();

                    final msgStr = msgContent.toString();
                    if (msgStr.startsWith('Loading ')) {
                      currentStatus = 'Loading...';
                      _statusController.add(currentStatus);
                    } else if (msgStr == 'Model ready for operations') {
                      currentStatus = 'Ready ✓';
                      _statusController.add(currentStatus);
                    }

                    _controller.add(List.from(_entries));
                  }
                } catch (e) {
                  debugPrint('[LiveFeedService] SSE parse error: $e');
                }
              }
            },
            onDone: () => _reconnectWithBackoff(),
            onError: (e) {
              debugPrint('[LiveFeedService] SSE stream error: $e');
              _reconnectWithBackoff();
            },
          );
    } catch (e) {
      debugPrint('[LiveFeedService] SSE connection error: $e');
      _reconnectWithBackoff();
    }
  }

  void _reconnectWithBackoff() {
    if (_retryCount >= _maxRetries) {
      debugPrint('[LiveFeedService] Max retries reached ($_maxRetries). Stopping reconnection.');
      return;
    }
    final delaySeconds = min(3 * pow(2, _retryCount).toInt(), 60);
    _retryCount++;
    debugPrint('[LiveFeedService] Reconnecting in ${delaySeconds}s (attempt $_retryCount)');
    Future.delayed(Duration(seconds: delaySeconds), _connectToEventStream);
  }

  void dispose() {
    _client?.close();
    _client = null;
    _controller.close();
    _statusController.close();
    _amplitudeController.close();
    _transcriptController.close();
    _voiceStateController.close();
  }
}

final liveFeedService = LiveFeedService();
