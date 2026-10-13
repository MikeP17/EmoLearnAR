import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/emotion_result.dart';

enum DetectionStatus {
  analyzing,
  noFace,
  lowConfidence,
  backendDisconnected,
  faceDetected,
}

class ApiService {
  ApiService({
    this.baseUrl = 'http://172.20.10.5:5000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<EmotionResult> detectEmotion(Uint8List imageBytes) async {
    final uri = Uri.parse('$baseUrl/detect');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'frame.jpg',
        ),
      );

    try {
      final streamed = await _client.send(request).timeout(
            const Duration(seconds: 8),
          );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw ApiException('Backend disconnected');
      }

      return EmotionResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Backend disconnected');
    } on http.ClientException {
      throw ApiException('Backend disconnected');
    } catch (e) {
      throw ApiException('Backend disconnected');
    }
  }

  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
