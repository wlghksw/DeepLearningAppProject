import 'dart:io';
import 'package:flutter_app/models/inspection_report.dart';
import 'package:flutter_app/services/gemini_service.dart';
import 'package:flutter_app/services/yolo_service.dart';

enum InspectionMode {
  gemini, // Gemini AI 사용
  yolo, // YOLO 모델 사용
  hybrid, // 둘 다 사용하고 결과 통합
}

class InspectionService {
  static InspectionMode _mode = InspectionMode.yolo;

  /// 검사 모드 설정
  static void setMode(InspectionMode mode) {
    _mode = mode;
  }

  /// 현재 검사 모드 반환
  static InspectionMode getMode() => _mode;

  /// 스마트폰 검사 실행
  static Future<InspectionReport> inspectPhone({
    required File frontImage,
    required File backImage,
  }) async {
    switch (_mode) {
      case InspectionMode.gemini:
        return await GeminiService.inspectPhone(
          frontImage: frontImage,
          backImage: backImage,
        );

      case InspectionMode.yolo:
        return await YOLOService.inspectPhone(
          frontImage: frontImage,
          backImage: backImage,
        );

      case InspectionMode.hybrid:
        // 두 모델 모두 실행하고 결과 통합
        try {
          final geminiResult = await GeminiService.inspectPhone(
            frontImage: frontImage,
            backImage: backImage,
          );

          final yoloResult = await YOLOService.inspectPhone(
            frontImage: frontImage,
            backImage: backImage,
          );

          // 결과 통합 (YOLO의 damages를 우선, Gemini의 설명 사용)
          return InspectionReport(
            grade: _mergeGrade(geminiResult.grade, yoloResult.grade),
            summary: '${geminiResult.summary}\n\n[YOLO 검출: ${yoloResult.damages.length}개 결함 발견]',
            batteryHealth: 0,  // 배터리 정보 없음
            screenCondition: '${geminiResult.screenCondition}\n[YOLO: ${yoloResult.screenCondition}]',
            backCondition: '${geminiResult.backCondition}\n[YOLO: ${yoloResult.backCondition}]',
            frameCondition: '${geminiResult.frameCondition}\n[YOLO: ${yoloResult.frameCondition}]',
            overallAssessment: geminiResult.overallAssessment,
            damages: yoloResult.damages.isNotEmpty
                ? yoloResult.damages
                : geminiResult.damages,
          );
        } catch (e) {
          // 하나라도 실패하면 성공한 것만 반환
          try {
            return await GeminiService.inspectPhone(
              frontImage: frontImage,
              backImage: backImage,
            );
          } catch (_) {
            return await YOLOService.inspectPhone(
              frontImage: frontImage,
              backImage: backImage,
            );
          }
        }
    }
  }

  /// 두 등급을 통합 (더 낮은 등급 선택)
  static String _mergeGrade(String grade1, String grade2) {
    const grades = ['S', 'A', 'B', 'C', 'D'];
    final index1 = grades.indexOf(grade1);
    final index2 = grades.indexOf(grade2);
    if (index1 == -1) return grade2;
    if (index2 == -1) return grade1;
    return grades[index1 > index2 ? index1 : index2]; // 더 낮은 등급
  }
}


