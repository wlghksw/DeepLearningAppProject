import 'package:flutter/material.dart';
import 'package:flutter_app/core/models/product.dart';

enum InspectionStatus { analyzing, completed }

enum DamageSeverity { low, medium, high }

enum QualityGrade { s, a, b, c, d }

extension QualityGradeX on QualityGrade {
  String get label => switch (this) {
        QualityGrade.s => 'S',
        QualityGrade.a => 'A',
        QualityGrade.b => 'B',
        QualityGrade.c => 'C',
        QualityGrade.d => 'D',
      };

  Color resolveColor(ColorScheme scheme) => switch (this) {
        QualityGrade.s => scheme.primary,
        QualityGrade.a => Colors.green,
        QualityGrade.b => Colors.blue,
        QualityGrade.c => Colors.orange,
        QualityGrade.d => Colors.red,
      };

  String get description => switch (this) {
        QualityGrade.s => '신품 수준 (흠집 없음)',
        QualityGrade.a => '매우 양호 (미세 사용감)',
        QualityGrade.b => '양호 (가벼운 사용감)',
        QualityGrade.c => '보통 (눈에 띄는 손상)',
        QualityGrade.d => '하 (수리 필요)',
      };
}

extension DamageSeverityX on DamageSeverity {
  String get label => switch (this) {
        DamageSeverity.low => '경미',
        DamageSeverity.medium => '보통',
        DamageSeverity.high => '심각',
      };

  int get score => switch (this) {
        DamageSeverity.low => 1,
        DamageSeverity.medium => 3,
        DamageSeverity.high => 5,
      };
}

class DamageReport {
  const DamageReport({
    required this.area,
    required this.type,
    required this.severity,
  });

  final String area;
  final String type;
  final DamageSeverity severity;
}

class InspectionResult {
  const InspectionResult({
    required this.grade,
    required this.aiConfidence,
    required this.damages,
    required this.summary,
  });

  final QualityGrade grade;
  final double aiConfidence;
  final List<DamageReport> damages;
  final String summary;
}

class InspectionRequest {
  InspectionRequest({
    required this.id,
    required this.submission,
    required this.status,
    required this.submittedAt,
    this.completedAt,
    this.result,
  });

  final String id;
  final ProductSubmission submission;
  InspectionStatus status;
  final DateTime submittedAt;
  DateTime? completedAt;
  InspectionResult? result;
}



