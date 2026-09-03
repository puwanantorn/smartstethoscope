enum Gender { male, female, other }

enum Finger { indexFinger, middle, ring }

Gender genderFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'female':
      return Gender.female;
    case 'other':
      return Gender.other;
    default:
      return Gender.male;
  }
}

String genderLabel(Gender gender) {
  switch (gender) {
    case Gender.male:
      return 'Male';
    case Gender.female:
      return 'Female';
    case Gender.other:
      return 'Other';
  }
}

Finger fingerFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'middle':
      return Finger.middle;
    case 'ring':
      return Finger.ring;
    default:
      return Finger.indexFinger;
  }
}

String fingerLabel(Finger finger) {
  switch (finger) {
    case Finger.indexFinger:
      return 'Index';
    case Finger.middle:
      return 'Middle';
    case Finger.ring:
      return 'Ring';
  }
}

/// A saved sensor calibration: a manually-counted pulse ("actual") paired
/// with what the sensor reported at the same time ("measured"), plus the
/// resulting correction factor applied to future readings.
class CalibrationData {
  const CalibrationData({
    required this.age,
    required this.gender,
    required this.finger,
    required this.actualBpm,
    required this.measuredBpm,
    required this.correctionFactor,
    this.updatedAt,
  });

  factory CalibrationData.fromJson(Map<String, dynamic> json) {
    return CalibrationData(
      age: (json['age'] as num?)?.toInt() ?? 0,
      gender: genderFromString(json['gender'] as String?),
      finger: fingerFromString(json['finger'] as String?),
      actualBpm: (json['actual_bpm'] as num?)?.toDouble() ?? 0,
      measuredBpm: (json['measured_bpm'] as num?)?.toDouble() ?? 0,
      correctionFactor: (json['correction_factor'] as num?)?.toDouble() ?? 1.0,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  final int age;
  final Gender gender;
  final Finger finger;
  final double actualBpm;
  final double measuredBpm;
  final double correctionFactor;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'age': age,
      'gender': genderLabel(gender).toLowerCase(),
      'finger': fingerLabel(finger).toLowerCase(),
      'actual_bpm': actualBpm,
      'measured_bpm': measuredBpm,
      'correction_factor': correctionFactor,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
