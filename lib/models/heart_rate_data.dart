enum AiCondition { normal, murmur, arrhythmia }

class AiResult {
  final AiCondition condition;
  final double confidence; // 0-100
  final String description;

  const AiResult({
    required this.condition,
    required this.confidence,
    required this.description,
  });
}

class HeartRateData {
  final int bpm;
  final List<double> waveform;
  final List<AiResult> aiResults;
  final DateTime timestamp;

  const HeartRateData({
    required this.bpm,
    required this.waveform,
    required this.aiResults,
    required this.timestamp,
  });

  String get heartRateZone {
    if (bpm < 60) return 'Low';
    if (bpm <= 100) return 'Normal';
    return 'High';
  }

  AiResult get topResult =>
      aiResults.reduce((a, b) => a.confidence >= b.confidence ? a : b);
}
