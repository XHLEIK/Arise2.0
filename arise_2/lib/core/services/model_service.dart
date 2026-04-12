import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
  final String _baseUrl = 'http://localhost:8081/api/models';

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
    fetchModels(silent: true);
    fetchInstallingModels();

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      fetchInstallingModels();
      // Only do a heavy fetchModels if we aren't loading and things look stale,
      // but to keep it simple, fetch config periodically to check deleted via terminal
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
          .get(Uri.parse('$_baseUrl/installing'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        installingModels = data
            .map((json) => InstallingModel.fromJson(json))
            .toList();
        onModelsUpdated?.call();
      }
    } catch (_) {}
  }

  /// Fetches Ollama status and populates models if active.
  Future<void> fetchModels({bool silent = false}) async {
    if (!silent) {
      loading = true;
      onModelsUpdated?.call();
    }
    try {
      final statusRes = await http
          .get(Uri.parse('$_baseUrl/ollama/status'))
          .timeout(const Duration(seconds: 3));
      if (statusRes.statusCode == 200) {
        final statusData = jsonDecode(statusRes.body);
        ollamaConnected =
            statusData['installed'] == true && statusData['running'] == true;
      }

      if (ollamaConnected) {
        final responses = await Future.wait([
          http
              .get(Uri.parse('$_baseUrl/list'))
              .timeout(const Duration(seconds: 5)),
          http
              .get(Uri.parse('$_baseUrl/config'))
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
            } catch (_) {}
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
    } catch (_) {
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
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'model': modelName, 'role': role}),
      );
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
    } catch (_) {}
    return false;
  }

  /// Stores a Cloud Model Provider API Key securely on the backend.
  Future<bool> addCloudModel(String provider, String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/cloud/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'provider': provider, 'apiKey': apiKey}),
      );
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  Future<void> selectModel(OllamaModel model) async {
    // Treat visual "Top Bar" selection as assigning the universal "Conversation" role
    await setModelRole(model.name, 'Conversation');
  }

  Future<bool> deleteModel(String modelName) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/$modelName'));
      if (response.statusCode == 200) {
        models.removeWhere((m) => m.name == modelName);
        if (activeModel?.name == modelName) {
          activeModel = models.isNotEmpty ? models.first : null;
        }
        onModelsUpdated?.call();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Initiates a pull request on the backend. Updates will arrive via `fetchInstallingModels()`.
  Future<void> pullModel(String modelName) async {
    if (modelName.isEmpty) return;

    try {
      await http.post(
        Uri.parse('$_baseUrl/pull'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': modelName}),
      );
    } catch (_) {}
  }
}

// Global Singleton
final modelService = ModelService();
