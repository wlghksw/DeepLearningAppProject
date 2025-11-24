import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_app/models/inspection_report.dart';

class GeminiService {
  // 환경 변수에서 API 키를 가져오거나, 여기에 직접 입력할 수 있습니다
  // 보안을 위해 실제 배포 시에는 환경 변수나 secure storage를 사용하세요
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '', // 여기에 직접 API 키를 입력하거나 환경 변수 사용
  );

  static Future<InspectionReport> inspectPhone({
    required File frontImage,
    required File backImage,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY 환경 변수를 설정해주세요.');
    }

    final model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: _apiKey,
    );

    final frontBytes = await frontImage.readAsBytes();
    final backBytes = await backImage.readAsBytes();

    final prompt = '''
You are a world-class AI system for inspecting used smartphones. Your task is to analyze the provided images to generate a detailed quality report.

**Instructions:**
1. **Analyze Images:** Carefully examine the two images provided (front screen, back panel) for any cosmetic damage such as scratches, cracks, dings, scuffs, or discoloration.
2. **Assess Condition:** Based on your analysis, describe the condition of the screen and back.
3. **Grade the Phone:** Use the following criteria to assign a final grade:
   - **S Grade:** Pristine, like-new condition. No visible scratches or dings.
   - **A Grade:** Excellent condition. Maybe one or two hairline scratches, barely visible.
   - **B Grade:** Good condition. Some minor, visible scratches or small dings. No cracks.
   - **C Grade:** Fair condition. Multiple noticeable scratches and/or dings. The phone is fully functional but shows clear signs of use.
   - **D Grade:** Poor condition. Deep scratches, cracks on the screen or back, or significant damage.
4. **List Damages:** List all detected damages with their type, location, and severity. If no damages are found, return an empty array for the 'damages' field.
5. **Provide Summaries:** Write a concise summary and an overall assessment.

Return your complete analysis in valid JSON format with the following structure:
{
  "grade": "S|A|B|C|D",
  "summary": "Brief one-sentence summary",
  "batteryHealth": 0,
  "screenCondition": "Detailed description",
  "backCondition": "Detailed description",
  "frameCondition": "Detailed description",
  "overallAssessment": "Final concluding remark",
  "damages": [
    {
      "type": "scratch|ding|crack|scuff",
      "location": "Location description",
      "severity": "minor|moderate|severe"
    }
  ]
}
''';

    try {
      final content = [
        Content.text(prompt),
        Content.multi([
          DataPart('image/jpeg', frontBytes),
          DataPart('image/jpeg', backBytes),
        ]),
      ];

      final response = await model.generateContent(content);
      final text = response.text ?? '';

      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) {
        throw Exception('AI 응답에서 JSON을 찾을 수 없습니다.');
      }

      final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      return InspectionReport.fromJson(json);
    } catch (e) {
      throw Exception('검사 실패: ${e.toString()}');
    }
  }
}
