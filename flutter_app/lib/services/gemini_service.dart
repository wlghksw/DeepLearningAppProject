import 'dart:convert';
import '../models/types.dart';
import '../models/inspection_report.dart';
import 'yolo_service.dart';

class GeminiService {
  /// YOLO 서비스를 사용하여 스마트폰 이미지 분석
  static Future<AIAnalysisResult> analyzePhoneImages(
    List<String> imagesBase64,
    String userModelName,
    int batteryHealth,
  ) async {
    try {
      // Base64 문자열을 bytes로 변환
      final frontBytes = base64Decode(imagesBase64[0]);
      final backBytes = base64Decode(imagesBase64[1]);

      // YOLO 서비스를 사용하여 분석
      final inspectionReport = await YOLOService.inspectPhoneFromBytes(
        frontBytes: frontBytes,
        backBytes: backBytes,
      );

      // InspectionReport를 AIAnalysisResult로 변환
      return _convertToAIAnalysisResult(inspectionReport, batteryHealth);
    } catch (e) {
      // YOLO 서비스 실패 시 배터리 상태 기반 기본 등급 반환
      return _getDefaultAnalysis(batteryHealth);
    }
  }

  /// InspectionReport를 AIAnalysisResult로 변환
  static AIAnalysisResult _convertToAIAnalysisResult(
    InspectionReport report,
    int batteryHealth,
  ) {
    // 등급 변환 (S, A, B, C, D)
    QualityGrade grade = _convertGrade(report.grade);

    // 손상 리포트 변환
    List<DamageItem> damageReport = report.damages.map((damage) {
      return DamageItem(
        type: damage.type,
        location: damage.location,
        severity: _convertSeverity(damage.severity),
        description: '${damage.location}에 ${damage.type} 발견',
      );
    }).toList();

    return AIAnalysisResult(
      grade: grade,
      damageReport: damageReport,
      visualizedImages: report.visualizedImages,
    );
  }

  /// 등급 문자열을 QualityGrade로 변환
  static QualityGrade _convertGrade(String gradeStr) {
    final upperGrade = gradeStr.toUpperCase();
    switch (upperGrade) {
      case 'S':
        return QualityGrade.s;
      case 'A':
        return QualityGrade.a;
      case 'B':
        return QualityGrade.b;
      case 'C':
        return QualityGrade.c;
      case 'D':
        return QualityGrade.d;
      default:
        return QualityGrade.c;
    }
  }

  /// 심각도 문자열을 DamageSeverity로 변환
  static DamageSeverity _convertSeverity(String severityStr) {
    final lowerSeverity = severityStr.toLowerCase();
    switch (lowerSeverity) {
      case 'high':
      case 'high':
        return DamageSeverity.high;
      case 'medium':
      case '중간':
        return DamageSeverity.medium;
      case 'low':
      case '낮음':
      default:
        return DamageSeverity.low;
    }
  }


  /// 기본 분석 결과 반환 (YOLO 서비스 실패 시)
  static AIAnalysisResult _getDefaultAnalysis(int batteryHealth) {
    QualityGrade grade;
    List<DamageItem> damageReport = [];

    if (batteryHealth >= 90) {
      grade = QualityGrade.s;
    } else if (batteryHealth >= 85) {
      grade = QualityGrade.a;
    } else if (batteryHealth >= 80) {
      grade = QualityGrade.b;
      damageReport = [
        DamageItem(
          type: 'Wear',
          location: 'Overall',
          severity: DamageSeverity.low,
          description: '전반적인 사용감 있는 상태',
        ),
      ];
    } else {
      grade = QualityGrade.c;
      damageReport = [
        DamageItem(
          type: 'Wear',
          location: 'Overall',
          severity: DamageSeverity.medium,
          description: '전반적인 사용감 있는 상태',
        ),
      ];
    }

    return AIAnalysisResult(
      grade: grade,
      damageReport: damageReport,
    );
  }
}
