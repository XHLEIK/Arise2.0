import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_client.dart';

class AudioDevice {
  final String id;
  final String name;
  final bool isInput;
  final bool isOutput;

  AudioDevice({
    required this.id,
    required this.name,
    required this.isInput,
    required this.isOutput,
  });

  factory AudioDevice.fromJson(Map<String, dynamic> json) {
    return AudioDevice(
      id: json['id'].toString(),
      name: json['name'].toString(),
      isInput: json['is_input'] == true || (json['maxInputChannels'] ?? 0) > 0,
      isOutput:
          json['is_output'] == true || (json['maxOutputChannels'] ?? 0) > 0,
    );
  }
}

class DeviceService {
  final String _baseUrl = '${AppConfig.springBaseUrl}/api/ai/voice';

  List<AudioDevice> _devices = [];
  AudioDevice? _selectedInput;
  AudioDevice? _selectedOutput;

  final _devicesController = StreamController<List<AudioDevice>>.broadcast();
  final _inputController = StreamController<AudioDevice?>.broadcast();
  final _outputController = StreamController<AudioDevice?>.broadcast();

  Stream<List<AudioDevice>> get devicesStream => _devicesController.stream;
  Stream<AudioDevice?> get inputStream => _inputController.stream;
  Stream<AudioDevice?> get outputStream => _outputController.stream;

  AudioDevice? get selectedInput => _selectedInput;
  AudioDevice? get selectedOutput => _selectedOutput;
  List<AudioDevice> get devices => _devices;

  Future<void> scanDevices() async {
    try {
      // Mocking device list if backend doesn't support it yet
      // A real implementation would call the backend
      final response = await http
          .get(Uri.parse('$_baseUrl/devices'), headers: ApiClient.baseHeaders)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        _devices = data.map((e) => AudioDevice.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load devices: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[DeviceService] scanDevices error: $e');
      _devices = [];
    }

    _devicesController.add(_devices);

    if (_selectedInput == null && _devices.any((d) => d.isInput)) {
      selectInputDevice(_devices.firstWhere((d) => d.isInput));
    }
    if (_selectedOutput == null && _devices.any((d) => d.isOutput)) {
      selectOutputDevice(_devices.firstWhere((d) => d.isOutput));
    }
  }

  void selectInputDevice(AudioDevice device) {
    if (!device.isInput) return;
    _selectedInput = device;
    _inputController.add(device);
    _notifyBackend('input', device.id);
  }

  void selectOutputDevice(AudioDevice device) {
    if (!device.isOutput) return;
    _selectedOutput = device;
    _outputController.add(device);
    _notifyBackend('output', device.id);
  }

  Future<void> _notifyBackend(String type, String deviceId) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/device'),
        headers: ApiClient.jsonHeaders,
        body: jsonEncode({'type': type, 'deviceId': deviceId}),
      ).timeout(ApiClient.defaultTimeout);
    } catch (e) {
      debugPrint('[DeviceService] _notifyBackend error: $e');
    }
  }

  void dispose() {
    _devicesController.close();
    _inputController.close();
    _outputController.close();
  }
}

final deviceService = DeviceService();
