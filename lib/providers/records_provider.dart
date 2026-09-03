import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/heart_rate_data.dart';
import '../models/record.dart';

class RecordsProvider extends ChangeNotifier {
  RecordsProvider() {
    _seedMockData();
  }

  final List<HeartRecord> _records = [];

  List<HeartRecord> get records =>
      List.unmodifiable(_records..sort((a, b) => b.dateTime.compareTo(a.dateTime)));

  List<HeartRecord> byStatus(AiCondition? status) {
    if (status == null) return records;
    return records.where((r) => r.status == status).toList();
  }

  List<HeartRecord> search(String query, {AiCondition? status}) {
    final base = byStatus(status);
    if (query.trim().isEmpty) return base;
    final q = query.toLowerCase();
    return base.where((r) {
      final dateStr = '${r.dateTime.month}/${r.dateTime.day}/${r.dateTime.year}';
      return r.statusLabel.toLowerCase().contains(q) ||
          r.bpm.toString().contains(q) ||
          dateStr.contains(q);
    }).toList();
  }

  void addRecord(HeartRecord record) {
    _records.add(record);
    notifyListeners();
  }

  void deleteRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void addNote(String id, String note) {
    final record = _records.firstWhere((r) => r.id == id);
    record.note = note;
    notifyListeners();
  }

  // ---- Analytics helpers ----

  double get averageBpm {
    if (_records.isEmpty) return 0;
    return _records.map((r) => r.bpm).reduce((a, b) => a + b) / _records.length;
  }

  int get totalRecordings => _records.length;

  double get normalRatePercent {
    if (_records.isEmpty) return 0;
    final normalCount = _records.where((r) => r.status == AiCondition.normal).length;
    return normalCount / _records.length * 100;
  }

  int get minBpm =>
      _records.isEmpty ? 0 : _records.map((r) => r.bpm).reduce(min);

  int get maxBpm =>
      _records.isEmpty ? 0 : _records.map((r) => r.bpm).reduce(max);

  Map<AiCondition, int> get distribution {
    final map = {
      AiCondition.normal: 0,
      AiCondition.murmur: 0,
      AiCondition.arrhythmia: 0,
    };
    for (final r in _records) {
      map[r.status] = (map[r.status] ?? 0) + 1;
    }
    return map;
  }

  void _seedMockData() {
    List<double> wave(int seed) {
      final rnd = Random(seed);
      return List.generate(60, (i) {
        final base = sin(i / 3) * 0.3;
        final spike = (i % 12 == 0) ? 1.2 : 0.0;
        final noise = (rnd.nextDouble() - 0.5) * 0.2;
        return base + spike + noise;
      });
    }

    _records.addAll([
      HeartRecord(
        id: '1',
        dateTime: DateTime(2025, 5, 20, 9, 21),
        bpm: 78,
        status: AiCondition.normal,
        confidence: 92,
        waveform: wave(1),
      ),
      HeartRecord(
        id: '2',
        dateTime: DateTime(2025, 5, 19, 16, 15),
        bpm: 82,
        status: AiCondition.normal,
        confidence: 88,
        waveform: wave(2),
      ),
      HeartRecord(
        id: '3',
        dateTime: DateTime(2025, 5, 18, 10, 2),
        bpm: 92,
        status: AiCondition.murmur,
        confidence: 63,
        waveform: wave(3),
      ),
      HeartRecord(
        id: '4',
        dateTime: DateTime(2025, 5, 17, 8, 45),
        bpm: 102,
        status: AiCondition.arrhythmia,
        confidence: 71,
        waveform: wave(4),
      ),
      HeartRecord(
        id: '5',
        dateTime: DateTime(2025, 5, 16, 15, 30),
        bpm: 76,
        status: AiCondition.normal,
        confidence: 90,
        waveform: wave(5),
      ),
      HeartRecord(
        id: '6',
        dateTime: DateTime(2025, 5, 15, 11, 12),
        bpm: 88,
        status: AiCondition.normal,
        confidence: 85,
        waveform: wave(6),
      ),
      HeartRecord(
        id: '7',
        dateTime: DateTime(2025, 5, 14, 14, 22),
        bpm: 95,
        status: AiCondition.murmur,
        confidence: 58,
        waveform: wave(7),
      ),
    ]);
  }
}
