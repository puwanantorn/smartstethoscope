import 'heart_rate_data.dart';

class HeartRecord {
  final String id;
  final DateTime dateTime;
  final int bpm;
  final AiCondition status;
  final double confidence;
  final int durationSeconds;
  final String location;
  final String mode;
  final List<double> waveform;
  String note;

  HeartRecord({
    required this.id,
    required this.dateTime,
    required this.bpm,
    required this.status,
    required this.confidence,
    this.durationSeconds = 30,
    this.location = 'Apex (5th ICS)',
    this.mode = 'Standard',
    required this.waveform,
    this.note = '',
  });

  String get statusLabel {
    switch (status) {
      case AiCondition.normal:
        return 'Normal';
      case AiCondition.murmur:
        return 'Heart Murmur';
      case AiCondition.arrhythmia:
        return 'Arrhythmia';
    }
  }

  String get description {
    switch (status) {
      case AiCondition.normal:
        return 'No abnormal heart sound detected.';
      case AiCondition.murmur:
        return 'Murmur-like sound detected. Recommend further evaluation.';
      case AiCondition.arrhythmia:
        return 'Irregular rhythm detected. Recommend medical consultation.';
    }
  }
}
