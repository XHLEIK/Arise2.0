import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_client.dart';
import 'model_service.dart';
import 'session_service.dart';

enum ChatRole { user, ai }

class ChatMessage {
  final ChatRole role;
  final String text;
  final String time;

  ChatMessage({required this.role, required this.text, required this.time});
}

class ChatService {
  final String _baseUrl = '${AppConfig.springBaseUrl}/api/ai';

  final List<ChatMessage> _messages = [];
  final _messagesController = StreamController<List<ChatMessage>>.broadcast();
  final _isGeneratingController = StreamController<bool>.broadcast();

  Stream<List<ChatMessage>> get messages => _messagesController.stream;
  Stream<bool> get isGenerating => _isGeneratingController.stream;

  bool _isSpeakerMuted = false;
  bool get isSpeakerMuted => _isSpeakerMuted;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await sessionService.ensureDefaultSession(model: modelService.activeModel?.name);
    if (sessionService.activeSessionId != null) {
      await loadSession(sessionService.activeSessionId!);
    }
  }

  void toggleSpeakerMute() async {
    _isSpeakerMuted = !_isSpeakerMuted;
    try {
      await http.post(
        Uri.parse('$_baseUrl/voice/mute'),
        headers: ApiClient.jsonHeaders,
        body: jsonEncode({'mute': _isSpeakerMuted}),
      ).timeout(ApiClient.defaultTimeout);
    } catch (e) {
      debugPrint('[ChatService] toggleSpeakerMute error: $e');
    }
  }

  void generateGreeting() async {
    await initialize();
    if (_messages.isNotEmpty) return;

    final now = DateTime.now();
    final nowStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    const greetingText =
        'Hello sir, I am A.R.I.S.E, your personal AI assistant. How can I assist you today?';
    final aiMessage = ChatMessage(
      role: ChatRole.ai,
      text: greetingText,
      time: nowStr,
    );
    _messages.insert(0, aiMessage);
    _messagesController.add(List.from(_messages));

    if (!_isSpeakerMuted) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/voice/tts'),
          headers: ApiClient.jsonHeaders,
          body: jsonEncode({'text': greetingText}),
        ).timeout(ApiClient.defaultTimeout);
      } catch (e) {
        debugPrint('[ChatService] generateGreeting TTS error: $e');
      }
    }
  }

  Future<void> loadSession(String sessionId) async {
    await sessionService.activateSession(sessionId);
    final data = await sessionService.loadSessionMessages(sessionId);
    _messages.clear();

    if (data != null && data['messages'] is List) {
      final rawMessages = data['messages'] as List<dynamic>;
      for (final item in rawMessages.reversed) {
        final map = item as Map<String, dynamic>;
        final roleStr = map['role'] as String? ?? 'assistant';
        final content = map['content'] as String? ?? '';
        final timestamp = map['timestamp'] as String? ?? '';
        final time = _formatTime(timestamp);
        _messages.add(
          ChatMessage(
            role: roleStr == 'user' ? ChatRole.user : ChatRole.ai,
            text: content,
            time: time,
          ),
        );
      }
    }

    _messagesController.add(List.from(_messages));
  }

  Future<void> startNewSession() async {
    await sessionService.createSession(model: modelService.activeModel?.name);
    _messages.clear();
    _messagesController.add(List.from(_messages));
  }

  String _formatTime(String timestamp) {
    if (timestamp.isEmpty) {
      final now = DateTime.now();
      return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      if (timestamp.length >= 16) {
        return timestamp.substring(11, 16);
      }
      return timestamp;
    }
  }

  void sendMessage(String text) async {
    await initialize();
    final activeModel = modelService.activeModel;
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 10000 || activeModel == null) return;
    final modelName = activeModel.name;
    final sessionId = sessionService.activeSessionId;

    final now = DateTime.now();
    final nowStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    _messages.insert(
      0,
      ChatMessage(role: ChatRole.user, text: text, time: nowStr),
    );
    _messagesController.add(List.from(_messages));

    final aiMessage = ChatMessage(role: ChatRole.ai, text: '', time: nowStr);
    _messages.insert(0, aiMessage);
    _messagesController.add(List.from(_messages));

    _isGeneratingController.add(true);

    final client = http.Client();

    try {
      final request = http.Request('POST', Uri.parse('$_baseUrl/chat'))
        ..headers.addAll(ApiClient.jsonHeaders)
        ..headers['Accept'] = 'text/event-stream'
        ..body = jsonEncode({
          'model': modelName,
          'message': text,
          'mute_tts': _isSpeakerMuted,
          if (sessionId != null) 'session_id': sessionId,
        });

      final response = await client.send(request);

      String currentText = '';

      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.startsWith('data:')) {
                try {
                  final data = jsonDecode(line.substring(5).trim());

                  if (data['session_id'] != null) {
                    sessionService.activeSessionId = data['session_id'] as String;
                  }

                  if (data['response'] != null) {
                    currentText += data['response'];
                    _messages[0] = ChatMessage(
                      role: ChatRole.ai,
                      text: currentText,
                      time: nowStr,
                    );
                    _messagesController.add(List.from(_messages));
                  } else if (data['error'] != null) {
                    currentText += '\n[Error: ${data['error']}]';
                    _messages[0] = ChatMessage(
                      role: ChatRole.ai,
                      text: currentText,
                      time: nowStr,
                    );
                    _messagesController.add(List.from(_messages));
                  }

                  if (data['done'] == true) {
                    sessionService.refreshSessions();
                  }
                } catch (e) {
                  if (line.substring(5).trim().isNotEmpty) {
                    currentText += line.substring(5);
                    _messages[0] = ChatMessage(
                      role: ChatRole.ai,
                      text: currentText,
                      time: nowStr,
                    );
                    _messagesController.add(List.from(_messages));
                  }
                }
              } else if (line.trim().startsWith('{')) {
                try {
                  final data = jsonDecode(line.trim());
                  if (data['response'] != null) {
                    currentText += data['response'];
                    _messages[0] = ChatMessage(
                      role: ChatRole.ai,
                      text: currentText,
                      time: nowStr,
                    );
                    _messagesController.add(List.from(_messages));
                  }
                  if (data['done'] == true) {
                    sessionService.refreshSessions();
                  }
                } catch (_) {}
              }
            },
            onDone: () {
              _isGeneratingController.add(false);
              client.close();
              sessionService.refreshSessions();
            },
            onError: (e) {
              _messages[0] = ChatMessage(
                role: ChatRole.ai,
                text: 'AI service temporarily unavailable.',
                time: nowStr,
              );
              _messagesController.add(List.from(_messages));
              _isGeneratingController.add(false);
              client.close();
            },
            cancelOnError: true,
          );
    } catch (e) {
      _messages[0] = ChatMessage(
        role: ChatRole.ai,
        text: 'AI service temporarily unavailable.',
        time: nowStr,
      );
      _messagesController.add(List.from(_messages));
      _isGeneratingController.add(false);
      client.close();
    }
  }

  void dispose() {
    _messagesController.close();
    _isGeneratingController.close();
  }

  Future<void> startVoiceMode() async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/voice/start'),
        headers: ApiClient.baseHeaders,
      ).timeout(ApiClient.defaultTimeout);
    } catch (e) {
      debugPrint('[ChatService] startVoiceMode error: $e');
    }
  }

  Future<void> stopVoiceMode() async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/voice/stop'),
        headers: ApiClient.baseHeaders,
      ).timeout(ApiClient.defaultTimeout);
    } catch (e) {
      debugPrint('[ChatService] stopVoiceMode error: $e');
    }
  }
}

final chatService = ChatService();
