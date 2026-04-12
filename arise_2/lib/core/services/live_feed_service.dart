import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
  final String _baseUrl = 'http://localhost:8081/api/events';
  final List<FeedEntry> _entries = [];
  final _controller = StreamController<List<FeedEntry>>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  // Dedicated Voice Engine Streams mapped to Python PubSub telemetry
  final _amplitudeController = StreamController<double>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();
  final _voiceStateController = StreamController<String>.broadcast();

  String currentStatus = 'Ready ✓';

  Stream<List<FeedEntry>> get entries => _controller.stream;
  Stream<String> get modelStatus => _statusController.stream;
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get voiceStateStream => _voiceStateController.stream;

  LiveFeedService() {
    _connectToEventStream();
  }

  void _connectToEventStream() async {
    try {
      final request = http.Request('GET', Uri.parse('$_baseUrl/stream'))
        ..headers['Accept'] = 'text/event-stream';

      final response = await http.Client().send(request);

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
                    } catch (_) {}
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
                } catch (_) {}
              }
            },
            onDone: () => Future.delayed(
              const Duration(seconds: 3),
              _connectToEventStream,
            ),
            onError: (_) => Future.delayed(
              const Duration(seconds: 3),
              _connectToEventStream,
            ),
          );
    } catch (_) {
      Future.delayed(const Duration(seconds: 3), _connectToEventStream);
    }
  }

  void dispose() {
    _controller.close();
    _statusController.close();
    _amplitudeController.close();
    _transcriptController.close();
    _voiceStateController.close();
  }
}

final liveFeedService = LiveFeedService();
