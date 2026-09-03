import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/calibration_data.dart';
import '../models/heart_rate_data.dart';
import '../models/predict_response.dart';
import '../models/record.dart';
import '../services/api_service.dart';

class HeartRateProvider extends ChangeNotifier {
  HeartRateProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  static const Duration _pollInterval = Duration(seconds: 1);
  static const Duration _predictInterval = Duration(seconds: 30);
  // Points kept for the live waveform — matches the chart's visible window,
  // so each poll only requests as much as is actually rendered.
  static const int _sampleLimit = 60;

  final ApiService _apiService;
  final Random _random = Random();
  Timer? _pollTimer;
  Timer? _predictTimer;
  Timer? _waveTimer;
  DateTime? _monitoringStartedAt;
  // The highest reading id that already existed when this session started.
  // Only readings with a higher id than this are "new" — comparing ids
  // (not timestamps) sidesteps clock skew between the phone and backend.
  int? _baselineReadingId;

  // Device status
  bool isConnected = true;
  String deviceName = 'Smart Stethoscope SS-100';
  int batteryPercent = 85;

  // Live measurement state
  bool isRunning = false;
  bool isRecording = false;
  // null until the first reading arrives (no fake placeholder value).
  int? currentBpm;
  double currentSpo2 = 0;
  // True only while the sensor is actively reporting a positive bpm with a
  // timestamp from the last 10 seconds — i.e. a finger is really on it
  // right now, not just "the last reading we ever saw looked fine".
  bool isFingerDetected = false;
  List<double> waveformData = List.generate(_sampleLimit, (int i) => 0);
  // IR waveform points from GET /wave (normalized 0-100), polled
  // independently of GET /data.
  List<double> waveData = <double>[];
  List<AiResult> aiResults = const <AiResult>[
    AiResult(
      condition: AiCondition.normal,
      confidence: 92,
      description: 'No abnormal heart sound detected.',
    ),
    AiResult(
      condition: AiCondition.murmur,
      confidence: 45,
      description: 'Murmur-like sound detected. Recommend further evaluation.',
    ),
    AiResult(
      condition: AiCondition.arrhythmia,
      confidence: 18,
      description: 'Irregular rhythm detected. Recommend medical consultation.',
    ),
  ];

  // ML risk prediction (POST /predict), refreshed every 30s while running.
  PredictResponse? predictResult;

  // Sensor calibration — a locally- or backend-computed multiplier applied
  // to the raw reading before it's shown. Defaults to 1.0 (no adjustment)
  // until a calibration has been saved.
  double correctionFactor = 1.0;
  CalibrationData? calibration;

  /// [currentBpm] already has [correctionFactor] applied at the point it's
  /// read from the sensor — this getter just exposes it under the name
  /// the rest of the app (zone classification, saved records, UI) uses.
  int? get displayBpm => currentBpm;

  String get heartRateZone {
    if (!isFingerDetected) return 'No Signal';
    final int? bpm = displayBpm;
    if (bpm == null) return 'No Signal';
    if (bpm <= 60) return 'Low';
    if (bpm <= 100) return 'Normal';
    if (bpm <= 140) return 'High';
    return 'Very High';
  }

  /// True once monitoring has started but the backend hasn't produced a
  /// prediction yet — the first /predict call only fires after ~30s of
  /// collected data.
  bool get isCollectingPrediction {
    if (predictResult != null) return false;
    if (!isRunning || _monitoringStartedAt == null) return false;
    return DateTime.now().difference(_monitoringStartedAt!) < _predictInterval;
  }

  Future<void> init() async {
    await loadCalibration();
  }

  /// Loads the saved calibration from the backend, falling back to the
  /// locally cached copy (SharedPreferences) if the backend is unreachable
  /// — so a previously saved calibration still applies while offline.
  Future<void> loadCalibration() async {
    final Map<String, dynamic>? remote = await _apiService.getCalibration();
    final Map<String, dynamic>? data =
        remote ?? await _apiService.loadCalibrationLocally();
    if (data == null) return;

    calibration = CalibrationData.fromJson(data);
    correctionFactor = calibration!.correctionFactor;
    if (remote != null) {
      await _apiService.saveCalibrationLocally(remote);
    }
    notifyListeners();
  }

  /// Saves a new calibration by submitting it to the backend for the
  /// authoritative correction factor. Returns true and applies the result
  /// (also caching it locally for offline use) on success; returns false
  /// without touching existing state if the POST fails, so the caller can
  /// show an honest failure message instead of a fabricated success.
  Future<bool> saveCalibration({
    required int age,
    required Gender gender,
    required Finger finger,
    required double actualBpm,
    required double measuredBpm,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'age': age,
      'gender': genderLabel(gender).toLowerCase(),
      'finger': fingerLabel(finger).toLowerCase(),
      'actual_bpm': actualBpm,
      'measured_bpm': measuredBpm,
    };

    final Map<String, dynamic>? response =
        await _apiService.saveCalibration(payload);
    if (response == null) return false;

    final CalibrationData result = CalibrationData.fromJson(response);
    calibration = result;
    correctionFactor = result.correctionFactor;
    await _apiService.saveCalibrationLocally(response);
    notifyListeners();
    return true;
  }

  void start() {
    if (isRunning) return;
    isRunning = true;
    _monitoringStartedAt = DateTime.now();
    _baselineReadingId = null; // established by the first poll below
    predictResult = null;
    _resetLiveState();
    unawaited(_pollData());
    unawaited(_pollWave());
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollData());
    _waveTimer = Timer.periodic(_pollInterval, (_) => _pollWave());
    _predictTimer = Timer.periodic(_predictInterval, (_) => _runPrediction());
    notifyListeners();
  }

  void stop() {
    isRunning = false;
    isRecording = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _waveTimer?.cancel();
    _waveTimer = null;
    _predictTimer?.cancel();
    _predictTimer = null;
    _monitoringStartedAt = null;
    _baselineReadingId = null;
    _resetLiveState();
    notifyListeners();
  }

  void toggleRecording() {
    if (!isRunning) start();
    isRecording = !isRecording;
    _resetLiveState();
    notifyListeners();
  }

  /// Clears the live reading back to "no data yet" (shown as "-" / a flat
  /// waveform) — used whenever a session starts, stops, or a recording is
  /// captured, so nothing lingers from a previous reading.
  void _resetLiveState() {
    currentBpm = null;
    currentSpo2 = 0;
    isFingerDetected = false;
    waveformData = List.generate(_sampleLimit, (int i) => 0);
    waveData = <double>[];
  }

  /// Polls GET /wave independently of GET /data — the IR waveform samples
  /// the Home screen's live chart plots.
  Future<void> _pollWave() async {
    if (!isRunning) return;
    final Map<String, dynamic> wave = await _apiService.getWave();
    // The request can take a few seconds; if STOP was pressed while it was
    // in flight, isRunning is now false — discard this response instead of
    // re-populating the waveform right after it was reset.
    if (!isRunning) return;
    final dynamic points = wave['wave'];
    if (points is! List) return;
    updateWave(points.map((dynamic e) => (e as num?)?.toDouble() ?? 0.0).toList());
  }

  /// Applies newly polled IR waveform points.
  void updateWave(List<double> points) {
    waveData = points;
    notifyListeners();
  }

  Future<void> _pollData() async {
    // GET /data returns readings newest-first (descending), so index 0 is
    // the latest reading — not the last element.
    final List<Map<String, dynamic>> readings =
        await _apiService.fetchRecentData(limit: _sampleLimit);
    // The request can take a few seconds; if STOP was pressed while it was
    // in flight, isRunning is now false — discard this response instead of
    // re-populating state right after it was reset.
    if (!isRunning) return;
    if (readings.isEmpty) {
      _setFingerDetected(false);
      return;
    }

    // Finger-on-sensor is about the device's live activity right now, not
    // "is this newer than when I pressed START" — so it's always computed
    // from the absolute latest reading, independent of the baseline filter
    // below.
    final Map<String, dynamic> latest0 = readings[0];
    final bool detected = _computeFingerDetected(latest0);
    // ignore: avoid_print
    print(
      'BPM: ${latest0['bpm']} finger: $detected '
      '(timestamp=${latest0['timestamp']}, ageSec=${_readingAgeSeconds(latest0)})',
    );
    _setFingerDetected(detected);

    final int? latestId = _readingId(latest0);
    if (latestId == null) {
      // No id to key off of — fall back to trusting the newest reading
      // directly (can't distinguish "recorded before START" from "new").
      _applyFreshReadings(readings);
      return;
    }

    if (_baselineReadingId == null) {
      // First poll of this session: remember what was already the newest
      // reading so only data recorded AFTER this moment counts as "new" —
      // pressing START never shows old history left over from before.
      _baselineReadingId = latestId;
      if (detected) {
        // The very latest reading is itself live right now (not stale
        // history) — show it immediately rather than making the user wait
        // a whole extra poll cycle for "something newer than the newest".
        _applyFreshReadings(readings);
      }
      return;
    }

    final List<Map<String, dynamic>> fresh = readings
        .where((Map<String, dynamic> r) => (_readingId(r) ?? -1) > _baselineReadingId!)
        .toList();
    if (fresh.isEmpty) return; // nothing new yet; keep showing "-"
    _applyFreshReadings(fresh);
  }

  /// Updates [isFingerDetected] and notifies listeners whenever it
  /// actually changes value (separate from the other per-tick updates,
  /// which already notify on their own).
  void _setFingerDetected(bool detected) {
    if (isFingerDetected == detected) return;
    isFingerDetected = detected;
    notifyListeners();
  }

  /// True only if [reading] reports a bpm above the noise floor (>20 —
  /// a real pulse is never lower) timestamped within the last 15 seconds —
  /// i.e. the sensor is actively picking up a pulse right now, not just
  /// "the last thing we ever saw looked fine". spo2 is not checked at all.
  bool _computeFingerDetected(Map<String, dynamic> reading) {
    final num? bpm = reading['bpm'] is num ? reading['bpm'] as num : null;
    if (bpm == null || bpm <= 20) return false;

    final int? ageSeconds = _readingAgeSeconds(reading);
    if (ageSeconds == null) return true; // no timestamp to check; trust the bpm
    return ageSeconds <= 15;
  }

  /// How many seconds old [reading]'s timestamp is, or null if it has none
  /// / it can't be parsed. Exposed separately from
  /// [_computeFingerDetected] so the debug log can show it directly.
  int? _readingAgeSeconds(Map<String, dynamic> reading) {
    final String? raw = reading['timestamp'] as String?;
    if (raw == null) return null;
    final DateTime? timestamp = _parseBackendTimestamp(raw);
    if (timestamp == null) return null;
    return DateTime.now().toUtc().difference(timestamp).inSeconds.abs();
  }

  /// The backend sends naive timestamp strings with no `Z`/offset suffix
  /// (e.g. "2026-08-21T03:21:46"), which are already UTC. `DateTime.parse`
  /// treats a string with no timezone marker as *local* time, which
  /// silently shifts it by the device's own UTC offset — e.g. on a phone
  /// set to Thailand (UTC+7), every reading looked 7 hours old and
  /// [_computeFingerDetected] would never see anything as "fresh". Force
  /// UTC interpretation by appending `Z` before parsing instead.
  DateTime? _parseBackendTimestamp(String raw) {
    final String withZone = raw.endsWith('Z') ? raw : '${raw}Z';
    return DateTime.tryParse(withZone);
  }

  void _applyFreshReadings(List<Map<String, dynamic>> fresh) {
    final Map<String, dynamic> latest = fresh[0];
    final num? rawBpm = latest['bpm'] is num ? latest['bpm'] as num : null;
    if (rawBpm != null) {
      currentBpm = (rawBpm * correctionFactor).round();
    }
    final num? rawSpo2 = latest['spo2'] is num ? latest['spo2'] as num : null;
    if (rawSpo2 != null) {
      currentSpo2 = rawSpo2.toDouble();
    }

    // The chart plots left-to-right as oldest-to-newest, so reverse the
    // newest-first list before mapping it to waveform points. This is a
    // live BPM trend built from real readings — the backend doesn't expose
    // raw audio samples, so there's no literal phonocardiogram waveform to
    // plot.
    waveformData = fresh.reversed
        .map((Map<String, dynamic> r) =>
            ((r['value'] as num?) ?? (r['bpm'] as num?) ?? 0).toDouble())
        .toList();

    aiResults = _simulateAiResults();
    notifyListeners();
  }

  int? _readingId(Map<String, dynamic> reading) {
    final dynamic id = reading['id'];
    return id is num ? id.toInt() : null;
  }

  Future<void> _runPrediction() async {
    if (!isRunning) return;
    final Map<String, dynamic> stats = await _apiService.fetchStats();
    if (!isRunning) return;
    final PredictResponse result = await _apiService.predict(stats);
    if (!isRunning) return;
    predictResult = result;
    notifyListeners();
  }

  List<AiResult> _simulateAiResults() {
    final double normal = 70 + _random.nextInt(26).toDouble();
    final double murmur = _random.nextInt(50).toDouble();
    final double arrhythmia = _random.nextInt(30).toDouble();
    return <AiResult>[
      AiResult(
        condition: AiCondition.normal,
        confidence: normal,
        description: 'No abnormal heart sound detected.',
      ),
      AiResult(
        condition: AiCondition.murmur,
        confidence: murmur,
        description: 'Murmur-like sound detected. Recommend further evaluation.',
      ),
      AiResult(
        condition: AiCondition.arrhythmia,
        confidence: arrhythmia,
        description: 'Irregular rhythm detected. Recommend medical consultation.',
      ),
    ];
  }

  HeartRecord captureRecord() {
    final AiResult top =
        aiResults.reduce((AiResult a, AiResult b) => a.confidence >= b.confidence ? a : b);
    return HeartRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      bpm: displayBpm ?? 0,
      status: top.condition,
      confidence: top.confidence,
      waveform: List<double>.of(waveformData),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _waveTimer?.cancel();
    _predictTimer?.cancel();
    super.dispose();
  }
}
