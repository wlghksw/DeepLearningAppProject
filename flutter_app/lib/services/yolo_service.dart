import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_app/models/inspection_report.dart';

class YOLOService {
  // YOLO 서버 API 엔드포인트
  // 로컬 테스트: 'http://localhost:8000'
  // 실제 서버: 'https://your-server.com'
  static const String _baseUrl = String.fromEnvironment(
    'YOLO_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// YOLO 모델을 사용하여 스마트폰 이미지 분석 (File 사용)
  static Future<InspectionReport> inspectPhone({
    required File frontImage,
    required File backImage,
  }) async {
    final frontBytes = await frontImage.readAsBytes();
    final backBytes = await backImage.readAsBytes();
    
    return inspectPhoneFromBytes(
      frontBytes: frontBytes,
      backBytes: backBytes,
    );
  }

  /// YOLO 모델을 사용하여 스마트폰 이미지 분석 (bytes 사용 - 웹 호환)
  static Future<InspectionReport> inspectPhoneFromBytes({
    required List<int> frontBytes,
    required List<int> backBytes,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/inspect');
      
      final requestBody = {
        'images': {
          'front': base64Encode(frontBytes),
          'back': base64Encode(backBytes),
        },
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 60), // YOLO 분석은 시간이 걸릴 수 있음
      );

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return InspectionReport.fromJson(json);
        } catch (e) {
          throw Exception(
            '응답 파싱 오류: ${e.toString()}\n응답 내용: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
          );
        }
      } else {
        throw Exception(
          '서버 오류 (${response.statusCode}): ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception(
        '서버에 연결할 수 없습니다. 서버가 실행 중인지 확인해주세요.\nURL: $_baseUrl/api/inspect\n오류: $e',
      );
    } on SocketException catch (e) {
      throw Exception(
        '네트워크 오류가 발생했습니다.\nURL: $_baseUrl/api/inspect\n오류: $e',
      );
    } catch (e) {
      throw Exception('YOLO 분석 실패: ${e.toString()}');
    }
  }

  /// 서버 연결 테스트
  static Future<bool> testConnection() async {
    try {
      final uri = Uri.parse('$_baseUrl/health');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 서버 URL 반환 (디버깅용)
  static String getBaseUrl() => _baseUrl;
}

