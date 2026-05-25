import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_client.dart';
import 'model_service.dart';

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
    final now = DateTime.now();
    final nowStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final greetingText =
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

  void sendMessage(String text) async {
    final activeModel = modelService.activeModel;
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 10000 || activeModel == null) return;
    String modelName = activeModel.name;

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
              }
            },
            onDone: () {
              _isGeneratingController.add(false);
              client.close();
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
