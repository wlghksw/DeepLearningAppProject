import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/inspection.dart';
import 'package:flutter_app/core/models/product.dart';

class InspectionProvider extends ChangeNotifier {
  InspectionProvider() {
    _seedInitialData();
  }

  final List<InspectionRequest> _requests = [];
  final Random _random = Random();

  UnmodifiableListView<InspectionRequest> get requests =>
      UnmodifiableListView(_requests);

  List<InspectionRequest> get activeRequests => _requests
      .where((element) => element.status == InspectionStatus.analyzing)
      .toList();

  List<InspectionRequest> get completedRequests => _requests
      .where((element) => element.status == InspectionStatus.completed)
      .toList();

  int get totalRequestCount => _requests.length;

  double get averageBatteryHealth {
    final completed = completedRequests;
    if (completed.isEmpty) return 0;
    final total = completed
        .map((e) => e.submission.batteryHealth)
        .reduce((value, element) => value + element);
    return total / completed.length;
  }

  Future<void> submitInspection(ProductSubmission submission) async {
    final request = InspectionRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      submission: submission,
      status: InspectionStatus.analyzing,
      submittedAt: DateTime.now(),
    );

    _requests.insert(0, request);
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));
    final result = _analyze(submission);
    request
      ..status = InspectionStatus.completed
      ..result = result
      ..completedAt = DateTime.now();
    notifyListeners();
  }

  InspectionResult _analyze(ProductSubmission submission) {
    final damages = _generateDamageReports();
    final grade = _calculateGrade(submission.batteryHealth, damages);
    final confidence = 0.88 + _random.nextDouble() * 0.1;
    final summary = _buildSummary(grade, submission.batteryHealth, damages);

    return InspectionResult(
      grade: grade,
      aiConfidence: double.parse(confidence.toStringAsFixed(2)),
      damages: damages,
      summary: summary,
    );
  }

  List<DamageReport> _generateDamageReports() {
    final damageAreas = [
      '디스플레이',
      '후면 글라스',
      '사이드 프레임',
      '카메라 렌즈',
      '하단 모서리',
    ];
    final damageTypes = [
      '스크래치',
      '찍힘',
      '미세 파손',
      '얼룩',
    ];

    final count = _random.nextInt(3); // 0~2개의 하자
    return List.generate(count, (index) {
      final area = damageAreas[_random.nextInt(damageAreas.length)];
      final type = damageTypes[_random.nextInt(damageTypes.length)];
      final severity =
          DamageSeverity.values[_random.nextInt(DamageSeverity.values.length)];
      return DamageReport(area: area, type: type, severity: severity);
    });
  }

  QualityGrade _calculateGrade(
    double batteryHealth,
    List<DamageReport> damages,
  ) {
    final severityScore = damages.fold<int>(
        0, (previousValue, element) => previousValue + element.severity.score);

    if (severityScore == 0 && batteryHealth >= 92) {
      return QualityGrade.s;
    } else if (severityScore <= 3 && batteryHealth >= 88) {
      return QualityGrade.a;
    } else if (severityScore <= 6 && batteryHealth >= 80) {
      return QualityGrade.b;
    } else if (severityScore <= 8 && batteryHealth >= 70) {
      return QualityGrade.c;
    }
    return QualityGrade.d;
  }

  String _buildSummary(
    QualityGrade grade,
    double batteryHealth,
    List<DamageReport> damages,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('배터리 건강도: ${batteryHealth.toStringAsFixed(1)}%');
    if (damages.isEmpty) {
      buffer.writeln('외관 하자 없음');
    } else {
      buffer.writeln('감지된 하자:');
      for (final damage in damages) {
        buffer.writeln(
            '- ${damage.area} ${damage.type} (${damage.severity.label})');
      }
    }
    buffer.writeln('AI 추정 등급: ${grade.label}');
    return buffer.toString();
  }

  void _seedInitialData() {
    final samples = <ProductSubmission>[
      const ProductSubmission(
        deviceName: 'iPhone 15 Pro',
        storage: '256GB',
        batteryHealth: 94,
        imageAngles: ['전면', '후면', '좌측', '우측', '배터리 캡처'],
        sellerNote: '케이스 사용, 외관 깨끗',
      ),
      const ProductSubmission(
        deviceName: 'Galaxy S23',
        storage: '512GB',
        batteryHealth: 87,
        imageAngles: ['전면', '후면', '상단', '하단', '배터리 캡처'],
        sellerNote: '모서리 미세 찍힘',
      ),
      const ProductSubmission(
        deviceName: 'iPhone 13 mini',
        storage: '128GB',
        batteryHealth: 79,
        imageAngles: ['전면', '후면', '좌측', '우측', '배터리 캡처'],
      ),
    ];

    for (final submission in samples) {
      final result = _analyze(submission);
      _requests.add(
        InspectionRequest(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          submission: submission,
          status: InspectionStatus.completed,
          submittedAt: DateTime.now().subtract(const Duration(days: 1)),
          completedAt: DateTime.now().subtract(const Duration(hours: 2)),
          result: result,
        ),
      );
    }
  }
}
