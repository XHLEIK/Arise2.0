import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_client.dart';

class ChatSessionSummary {
  final String sessionId;
  final String title;
  final String updatedAt;
  final int messageCount;
  final bool pinned;

  ChatSessionSummary({
    required this.sessionId,
    required this.title,
    required this.updatedAt,
    required this.messageCount,
    required this.pinned,
  });

  factory ChatSessionSummary.fromJson(Map<String, dynamic> json) {
    return ChatSessionSummary(
      sessionId: json['sessionId'] as String? ?? '',
      title: json['title'] as String? ?? 'New Chat',
      updatedAt: json['updatedAt'] as String? ?? '',
      messageCount: json['messageCount'] as int? ?? 0,
      pinned: json['pinned'] as bool? ?? false,
    );
  }
}

class SessionService {
  final String _baseUrl = '${AppConfig.springBaseUrl}/api/sessions';

  String? activeSessionId;
  final List<ChatSessionSummary> _sessions = [];
  final _sessionsController =
      StreamController<List<ChatSessionSummary>>.broadcast();

  Stream<List<ChatSessionSummary>> get sessions => _sessionsController.stream;

  /// Latest session list for widgets that resubscribe (e.g. after panel expand).
  List<ChatSessionSummary> get currentSessions => List.unmodifiable(_sessions);

  Future<void> refreshSessions() async {
    try {
      final response = await http
          .get(Uri.parse(_baseUrl), headers: ApiClient.baseHeaders)
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode != 200) {
        debugPrint('[SessionService] refresh failed: ${response.statusCode}');
        return;
      }

      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      _sessions
        ..clear()
        ..addAll(
          data.map(
            (e) => ChatSessionSummary.fromJson(e as Map<String, dynamic>),
          ),
        );
      _sessionsController.add(List.from(_sessions));
    } catch (e) {
      debugPrint('[SessionService] refresh error: $e');
    }
  }

  Future<ChatSessionSummary?> createSession({String? title, String? model}) async {
    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: ApiClient.jsonHeaders,
            body: jsonEncode({
              if (title != null) 'title': title,
              if (model != null) 'model': model,
            }),
          )
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode != 200) return null;
      final session =
          ChatSessionSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      activeSessionId = session.sessionId;
      await refreshSessions();
      return session;
    } catch (e) {
      debugPrint('[SessionService] create error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> loadSessionMessages(String sessionId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/$sessionId/messages'),
            headers: ApiClient.baseHeaders,
          )
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[SessionService] load messages error: $e');
      return null;
    }
  }

  Future<bool> activateSession(String sessionId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/$sessionId/activate'),
            headers: ApiClient.baseHeaders,
          )
          .timeout(ApiClient.defaultTimeout);
      if (response.statusCode == 200) {
        activeSessionId = sessionId;
        return true;
      }
    } catch (e) {
      debugPrint('[SessionService] activate error: $e');
    }
    return false;
  }

  Future<bool> renameSession(String sessionId, String title) async {
    return _patchSession(sessionId, {'title': title});
  }

  Future<bool> setPinned(String sessionId, bool pinned) async {
    return _patchSession(sessionId, {'pinned': pinned});
  }

  Future<bool> deleteSession(String sessionId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/$sessionId'),
            headers: ApiClient.baseHeaders,
          )
          .timeout(ApiClient.defaultTimeout);
      if (response.statusCode == 200) {
        if (activeSessionId == sessionId) {
          activeSessionId = null;
        }
        await refreshSessions();
        return true;
      }
    } catch (e) {
      debugPrint('[SessionService] delete error: $e');
    }
    return false;
  }

  Future<bool> _patchSession(String sessionId, Map<String, dynamic> body) async {
    try {
      final request = http.Request('PATCH', Uri.parse('$_baseUrl/$sessionId'));
      request.headers.addAll(ApiClient.jsonHeaders);
      request.body = jsonEncode(body);
      final streamed = await request.send().timeout(ApiClient.defaultTimeout);
      if (streamed.statusCode == 200) {
        await refreshSessions();
        return true;
      }
    } catch (e) {
      debugPrint('[SessionService] patch error: $e');
    }
    return false;
  }

  Future<void> ensureDefaultSession({String? model}) async {
    await refreshSessions();
    if (_sessions.isNotEmpty) {
      activeSessionId ??= _sessions.first.sessionId;
      return;
    }
    await createSession(title: 'New Chat', model: model);
  }

  void dispose() {
    _sessionsController.close();
  }
}

final sessionService = SessionService();
