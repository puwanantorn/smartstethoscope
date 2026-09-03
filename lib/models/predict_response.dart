enum RiskLevel { low, medium, high }

RiskLevel riskLevelFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'medium':
      return RiskLevel.medium;
    case 'high':
      return RiskLevel.high;
    default:
      return RiskLevel.low;
  }
}

String riskLevelLabel(RiskLevel level) {
  switch (level) {
    case RiskLevel.low:
      return 'Low';
    case RiskLevel.medium:
      return 'Medium';
    case RiskLevel.high:
      return 'High';
  }
}

/// Result of a POST /predict call to the ML backend.
class PredictResponse {
  const PredictResponse({
    required this.riskLevel,
    required this.confidence,
    required this.message,
    required this.timestamp,
  });

  factory PredictResponse.fromJson(Map<String, dynamic> json) {
    final double rawConfidence = (json['confidence'] as num?)?.toDouble() ?? 0;
    // The backend reports confidence as a 0-1 fraction (e.g. 0.88); scale
    // it up to a 0-100 percentage. A value already above 1 is assumed to
    // already be a percentage and is left as-is.
    final double confidence = rawConfidence <= 1 ? rawConfidence * 100 : rawConfidence;
    return PredictResponse(
      riskLevel: riskLevelFromString(json['risk_level'] as String?),
      confidence: confidence,
      message: (json['message'] as String?) ?? '',
      timestamp: DateTime.now(),
    );
  }

  final RiskLevel riskLevel;
  final double confidence; // 0-100
  final String message;
  final DateTime timestamp;
}
