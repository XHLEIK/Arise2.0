import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_client.dart';

class OllamaModel {
  final String name;
  final String size;
  String role; // 'Conversation', 'Coding', or 'Idle'

  OllamaModel({required this.name, required this.size, this.role = 'Idle'});

  factory OllamaModel.fromJson(Map<String, dynamic> json, String assignedRole) {
    double sizeInGb = (json['size'] ?? 0) / (1024 * 1024 * 1024);
    return OllamaModel(
      name: json['name'] ?? 'Unknown',
      size: '${sizeInGb.toStringAsFixed(1)} GB',
      role: assignedRole,
    );
  }

  String get displayName => name.split(':').first.toUpperCase();
  String get quantization =>
      name.contains(':') ? name.split(':').last.toUpperCase() : 'LATEST';
}

class InstallingModel {
  final String name;
  String status;
  int progress;
  String speed;

  InstallingModel({
    required this.name,
    this.status = "Starting...",
    this.progress = 0,
    this.speed = "0 MB/s",
  });

  factory InstallingModel.fromJson(Map<String, dynamic> json) {
    return InstallingModel(
      name: json['name'] ?? 'Unknown',
      status: json['status'] ?? 'Downloading...',
      progress: json['progress'] ?? 0,
      speed: json['speed'] ?? '0 MB/s',
    );
  }
}

class ModelService extends Iterable {
  final String _baseUrl = '${AppConfig.springBaseUrl}/api/models';

  bool ollamaConnected = false;
  List<OllamaModel> models = [];
  List<InstallingModel> installingModels = [];
  OllamaModel? activeModel;
  bool loading = false;

  void Function()? onModelsUpdated;
  Timer? _pollTimer;

  @override
  Iterator get iterator => models.iterator;

  void startPolling() {
    if (_pollTimer != null) return; // Guard against duplicate polling
    fetchModels(silent: true);
    fetchInstallingModels();

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      fetchInstallingModels();
      fetchModels(silent: true);
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> fetchInstallingModels() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/installing'), headers: ApiClient.baseHeaders)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        installingModels = data
            .map((json) => InstallingModel.fromJson(json))
            .toList();
        onModelsUpdated?.call();
      }
    } catch (e) {
      debugPrint('[ModelService] fetchInstallingModels error: $e');
    }
  }

  /// Fetches Ollama status and populates models if active.
  Future<void> fetchModels({bool silent = false}) async {
    if (!silent) {
      loading = true;
      onModelsUpdated?.call();
    }
    try {
      final statusRes = await http
          .get(Uri.parse('$_baseUrl/ollama/status'), headers: ApiClient.baseHeaders)
          .timeout(const Duration(seconds: 3));
      if (statusRes.statusCode == 200) {
        final statusData = jsonDecode(statusRes.body);
        ollamaConnected =
            statusData['installed'] == true && statusData['running'] == true;
      }

      if (ollamaConnected) {
        final responses = await Future.wait([
          http
              .get(Uri.parse('$_baseUrl/list'), headers: ApiClient.baseHeaders)
              .timeout(const Duration(seconds: 5)),
          http
              .get(Uri.parse('$_baseUrl/config'), headers: ApiClient.baseHeaders)
              .timeout(const Duration(seconds: 2))
              .catchError((_) => http.Response('{}', 200)),
        ]);

        final listRes = responses[0];
        final configRes = responses[1];

        if (listRes.statusCode == 200) {
          final data = jsonDecode(listRes.body);
          final List<dynamic> modelsJson = data['models'] ?? [];

          // Parse roles map safely
          Map<String, dynamic> rolesMap = {};
          if (configRes.statusCode == 200) {
            try {
              rolesMap = jsonDecode(configRes.body);
            } catch (e) {
              debugPrint('[ModelService] config parse error: $e');
            }
          }

          List<OllamaModel> fetched = [];
          for (var m in modelsJson) {
            String name = m['name'];
            if (name.contains('embed') || name.contains('nomic')) continue;

            // Assign configured role, defaulting to 'Idle'
            String role = rolesMap[name] ?? 'Idle';
            fetched.add(OllamaModel.fromJson(m, role));
          }
          models = fetched;

          try {
            activeModel = models.firstWhere(
              (m) => m.role == 'Conversation' || m.role == 'Both',
            );
          } catch (_) {
            activeModel = models.isNotEmpty ? models.first : null;
          }
        }
      }
    } catch (e) {
      debugPrint('[ModelService] fetchModels error: $e');
      ollamaConnected = false;
    }
    if (!silent) {
      loading = false;
    }
    onModelsUpdated?.call();
  }

  /// Sets a model's role (`Conversation`, `Coding`, `Both`) on the backend.
  Future<bool> setModelRole(String modelName, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/config'),
        headers: ApiClient.jsonHeaders,
        body: jsonEncode({'model': modelName, 'role': role}),
      ).timeout(ApiClient.defaultTimeout);
      if (response.statusCode == 200) {
        for (var m in models) {
          if (m.name == modelName) {
            m.role = role;
          } else {
            if (role == 'Conversation' &&
                (m.role == 'Conversation' || m.role == 'Both')) {
              m.role = 'Idle';
            }
            if (role == 'Coding' && (m.role == 'Coding' || m.role == 'Both')) {
              m.role = 'Idle';
            }
            if (role == 'Both') {
              m.role = 'Idle';
            }
          }
        }

        try {
          activeModel = models.firstWhere(
            (m) => m.role == 'Conversation' || m.role == 'Both',
          );
        } catch (_) {
          activeModel = models.isNotEmpty ? models.first : null;
        }

        onModelsUpdated?.call();
        return true;
      }
    } catch (e) {
      debugPrint('[ModelService] setModelRole error: $e');
    }
    return false;
  }

  /// Stores a Cloud Model Provider API Key securely on the backend.
  Future<bool> addCloudModel(String provider, String apiKey) async {
    if (apiKey.trim().length < 10) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/cloud/add'),
        headers: ApiClient.jsonHeaders,
        body: jsonEncode({'provider': provider, 'apiKey': apiKey}),
      ).timeout(ApiClient.defaultTimeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ModelService] addCloudModel error: $e');
    }
    return false;
  }

  Future<void> selectModel(OllamaModel model) async {
    // Treat visual "Top Bar" selection as assigning the universal "Conversation" role
    await setModelRole(model.name, 'Conversation');
  }

  Future<bool> deleteModel(String modelName) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/$modelName'),
        headers: ApiClient.baseHeaders,
      ).timeout(ApiClient.defaultTimeout);
      if (response.statusCode == 200) {
        models.removeWhere((m) => m.name == modelName);
        if (activeModel?.name == modelName) {
          activeModel = models.isNotEmpty ? models.first : null;
        }
        onModelsUpdated?.call();
        return true;
      }
    } catch (e) {
      debugPrint('[ModelService] deleteModel error: $e');
    }
    return false;
  }

  /// Initiates a pull request on the backend. Updates will arrive via `fetchInstallingModels()`.
  Future<void> pullModel(String modelName) async {
    final name = modelName.trim();
    if (name.isEmpty || name.length > 128) return;
    if (!RegExp(r'^[a-zA-Z0-9._:/-]+$').hasMatch(name)) return;

    try {
      await http.post(
        Uri.parse('$_baseUrl/pull'),
        headers: ApiClient.jsonHeaders,
        body: jsonEncode({'name': name}),
      ).timeout(ApiClient.longTimeout);
    } catch (e) {
      debugPrint('[ModelService] pullModel error: $e');
    }
  }

  void dispose() {
    stopPolling();
  }
}

// Global Singleton
final modelService = ModelService();
