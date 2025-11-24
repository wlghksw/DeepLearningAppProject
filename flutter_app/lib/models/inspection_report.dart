class InspectionReport {
  final String grade;
  final String summary;
  final int batteryHealth;
  final String screenCondition;
  final String backCondition;
  final String frameCondition;
  final String overallAssessment;
  final List<Damage> damages;
  final Map<String, String>? visualizedImages; // base64 인코딩된 시각화 이미지

  InspectionReport({
    required this.grade,
    required this.summary,
    required this.batteryHealth,
    required this.screenCondition,
    required this.backCondition,
    required this.frameCondition,
    required this.overallAssessment,
    required this.damages,
    this.visualizedImages,
  });

  factory InspectionReport.fromJson(Map<String, dynamic> json) {
    return InspectionReport(
      grade: json['grade'] as String,
      summary: json['summary'] as String,
      batteryHealth: json['batteryHealth'] as int,
      screenCondition: json['screenCondition'] as String,
      backCondition: json['backCondition'] as String,
      frameCondition: json['frameCondition'] as String,
      overallAssessment: json['overallAssessment'] as String,
      damages: (json['damages'] as List<dynamic>?)
              ?.map((e) => Damage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      visualizedImages: json['visualizedImages'] != null
          ? Map<String, String>.from(json['visualizedImages'] as Map)
          : null,
    );
  }
}

class Damage {
  final String type;
  final String location;
  final String severity;

  Damage({
    required this.type,
    required this.location,
    required this.severity,
  });

  factory Damage.fromJson(Map<String, dynamic> json) {
    return Damage(
      type: json['type'] as String,
      location: json['location'] as String,
      severity: json['severity'] as String,
    );
  }
}



