import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/predict_response.dart';

/// Handles communication with the FastAPI backend that streams
/// heart-rate / phonocardiogram data from the Smart Stethoscope device
/// and serves the ML risk prediction.
///
/// Every data-fetching method is resilient: requests time out after 5
/// seconds and are retried once, and if the backend still can't be
/// reached the method falls back to locally generated mock data instead
/// of throwing, so callers never have to special-case connectivity loss.
class ApiService {
  static const String _calibrationKey = 'calibration_data';

  /// The Smart Stethoscope backend's address. Fixed and non-configurable —
  /// there is no local/dev override, so every request always goes to the
  /// hosted Railway backend.
  static const String baseUrl = 'https://smart-stethoscope-backend.up.railway.app';

  static const Duration _timeout = Duration(seconds: 5);
  static const int _maxAttempts = 2; // initial attempt + 1 retry

  final Random _random = Random();

  /// GET /data — the latest [limit] readings from the device.
  /// Falls back to generated mock readings if the backend is unreachable.
  Future<List<Map<String, dynamic>>> fetchRecentData({int limit = 100}) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/data',
      ).replace(queryParameters: {'limit': '$limit'});
      final response = await _requestWithRetry(() => http.get(uri));
      if (response != null && response.statusCode == 200) {
        final list = _asListOfMaps(jsonDecode(response.body));
        if (list != null) return list;
      }
    } catch (_) {
      // Fall through to mock data below.
    }
    return _mockRecentData(limit);
  }

  /// GET /data/stats — aggregated stats used as the /predict input.
  /// Falls back to locally computed mock stats if the backend is
  /// unreachable.
  Future<Map<String, dynamic>> fetchStats() async {
    try {
      final uri = Uri.parse('$baseUrl/data/stats');
      final response = await _requestWithRetry(() => http.get(uri));
      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {
      // Fall through to mock data below.
    }
    return _mockStats();
  }

  /// POST /predict — sends aggregated stats, returns the ML risk
  /// prediction. Falls back to a locally derived mock prediction if the
  /// backend is unreachable.
  Future<PredictResponse> predict(Map<String, dynamic> stats) async {
    try {
      final uri = Uri.parse('$baseUrl/predict');
      final response = await _requestWithRetry(
        () => http.post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(stats),
        ),
      );
      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return PredictResponse.fromJson(decoded);
        }
      }
    } catch (_) {
      // Fall through to mock prediction below.
    }
    return _mockPredictResponse(stats);
  }

  /// POST /calibration — submits the manual/measured pulse pair and
  /// profile fields, returns the backend-computed correction factor.
  /// Returns null (rather than a misleading mock) if unreachable — the
  /// caller is expected to compute and persist a local fallback instead.
  Future<Map<String, dynamic>?> saveCalibration(
    Map<String, dynamic> data,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/calibration');
      final response = await _requestWithRetry(
        () => http.post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        ),
      );
      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {
      // Fall through; caller falls back to a locally computed calibration.
    }
    return null;
  }

  /// GET /calibration — the most recently saved calibration. Returns null
  /// if unreachable — the caller should fall back to [loadCalibrationLocally].
  Future<Map<String, dynamic>?> getCalibration() async {
    try {
      final uri = Uri.parse('$baseUrl/calibration');
      final response = await _requestWithRetry(() => http.get(uri));
      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {
      // Fall through; caller falls back to a locally computed calibration.
    }
    return null;
  }

  /// GET /wave — the latest IR waveform samples (normalized 0-100) plus
  /// the instantaneous bpm/spo2 the device derived them from. Falls back
  /// to a generated mock waveform if the backend is unreachable, matching
  /// the other telemetry endpoints.
  Future<Map<String, dynamic>> getWave() async {
    try {
      final uri = Uri.parse('$baseUrl/wave');
      final response = await _requestWithRetry(() => http.get(uri));
      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {
      // Fall through to mock data below.
    }
    return _mockWave();
  }

  /// Caches the last-known calibration locally so it survives offline use.
  Future<void> saveCalibrationLocally(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_calibrationKey, jsonEncode(data));
  }

  /// Reads the locally cached calibration, if any.
  Future<Map<String, dynamic>?> loadCalibrationLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_calibrationKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<http.Response?> _requestWithRetry(
    Future<http.Response> Function() request,
  ) async {
    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        return await request().timeout(_timeout);
      } catch (_) {
        if (attempt == _maxAttempts) return null;
      }
    }
    return null;
  }

  List<Map<String, dynamic>>? _asListOfMaps(dynamic decoded) {
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    if (decoded is Map<String, dynamic>) {
      final inner = decoded['data'] ?? decoded['records'];
      if (inner is List) return inner.whereType<Map<String, dynamic>>().toList();
    }
    return null;
  }

  /// Newest-first (descending), matching the real /data contract — index 0
  /// is "now", later indices go further back in time. `id` mirrors the
  /// real backend's monotonically increasing row id (derived from the
  /// wall clock, so it keeps increasing call to call) so callers can use
  /// the same "id greater than baseline" freshness check against mock
  /// data as against the real API.
  List<Map<String, dynamic>> _mockRecentData(int limit) {
    final now = DateTime.now();
    final int nowId = now.millisecondsSinceEpoch;
    return List.generate(limit, (i) {
      final base = sin(i / 3) * 0.3;
      final spike = (i % 12 == 0) ? 1.2 : 0.0;
      final noise = (_random.nextDouble() - 0.5) * 0.2;
      return {
        'id': nowId - i,
        'bpm': 60 + _random.nextInt(41),
        'spo2': 95 + _random.nextInt(6),
        'value': base + spike + noise,
        'timestamp': now.subtract(Duration(seconds: i)).toIso8601String(),
      };
    });
  }

  /// A plausible PPG/IR pulse shape (normalized 0-100) rather than plain
  /// noise, so the live waveform still looks like a real signal when the
  /// backend or /wave endpoint is unavailable.
  Map<String, dynamic> _mockWave({int count = 200}) {
    const int samplesPerBeat = 40;
    final List<double> wave = List.generate(count, (i) {
      final double phase = (i % samplesPerBeat) / samplesPerBeat;
      final double pulse = phase < 0.15
          ? phase / 0.15
          : (1 - (phase - 0.15) / 0.85).clamp(0.0, 1.0);
      final double shaped = pulse * pulse;
      final double noise = (_random.nextDouble() - 0.5) * 4;
      return (shaped * 90 + noise).clamp(0.0, 100.0);
    });
    return {
      'wave': wave,
      'bpm': (60 + _random.nextInt(41)).toDouble(),
      'spo2': (95 + _random.nextInt(6)).toDouble(),
    };
  }

  Map<String, dynamic> _mockStats() {
    final avgBpm = 60 + _random.nextInt(41);
    return {
      'avg_bpm': avgBpm,
      'min_bpm': avgBpm - _random.nextInt(10),
      'max_bpm': avgBpm + _random.nextInt(10),
      'avg_spo2': 95 + _random.nextInt(6),
    };
  }

  PredictResponse _mockPredictResponse(Map<String, dynamic> stats) {
    final avgBpm =
        (stats['avg_bpm'] as num?)?.toDouble() ??
        (60 + _random.nextInt(41)).toDouble();

    final RiskLevel level;
    final String message;
    if (avgBpm < 60 || avgBpm > 100) {
      level = RiskLevel.high;
      message =
          'Heart rate is outside the normal resting range. Consider consulting a doctor.';
    } else if (avgBpm < 65 || avgBpm > 95) {
      level = RiskLevel.medium;
      message = 'Heart rate is near the edge of the normal range. Keep monitoring.';
    } else {
      level = RiskLevel.low;
      message = 'Heart rate and rhythm look within the normal range.';
    }

    return PredictResponse(
      riskLevel: level,
      confidence: 70 + _random.nextInt(26).toDouble(),
      message: message,
      timestamp: DateTime.now(),
    );
  }
}
