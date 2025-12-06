import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_app/models/inspection_report.dart';
import 'package:flutter_app/services/inspection_service.dart';
import 'package:flutter_app/services/yolo_service.dart';
import 'package:flutter_app/theme/app_theme.dart';

class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key});

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _frontImage;
  XFile? _backImage;

  bool _isAnalyzing = false;
  InspectionReport? _report;
  String? _error;
  InspectionMode _selectedMode = InspectionMode.yolo;
  bool _isCheckingYOLO = false;

  Future<void> _pickImage(String position) async {
    try {
      // 웹에서는 ImageSource.gallery가 파일 선택 다이얼로그를 엽니다
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // 이미지 품질 설정
      );
      
      if (image != null) {
        print('✅ 이미지 선택됨: ${image.name}, 경로: ${image.path}');
        
        // 이미지가 제대로 로드되는지 확인
        try {
          final bytes = await image.readAsBytes();
          print('✅ 이미지 바이트 읽기 성공: ${bytes.length} bytes');
        } catch (e) {
          print('⚠️ 이미지 바이트 읽기 실패: $e');
        }
        
        setState(() {
          switch (position) {
            case 'front':
              _frontImage = image;
              break;
            case 'back':
              _backImage = image;
              break;
          }
          _error = null;
        });
      } else {
        // 사용자가 취소한 경우
        print('ℹ️ 사용자가 이미지 선택 취소');
        setState(() {
          _error = null; // 에러 메시지 제거
        });
      }
    } catch (e) {
      print('❌ 이미지 선택 오류: $e');
      setState(() {
        _error = '이미지 선택 중 오류가 발생했습니다: ${e.toString()}';
      });
    }
  }

  Future<void> _startInspection() async {
    if (_frontImage == null || _backImage == null) {
      setState(() {
        _error = '전면과 후면 이미지를 모두 업로드해주세요.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _error = null;
      _report = null;
    });

    // 모드 설정
    InspectionService.setMode(_selectedMode);

    try {
      // XFile을 File로 변환 (웹이 아닌 경우) 또는 bytes 사용
      File? frontFile, backFile;
      if (!kIsWeb) {
        frontFile = File(_frontImage!.path);
        backFile = File(_backImage!.path);
      } else {
        // 웹에서는 임시 파일 경로를 사용하지 않고 직접 bytes 처리
        final frontBytes = await _frontImage!.readAsBytes();
        final backBytes = await _backImage!.readAsBytes();
        
        // 웹에서는 YOLOService를 직접 호출 (bytes 사용)
        if (_selectedMode == InspectionMode.yolo) {
          final report = await YOLOService.inspectPhoneFromBytes(
            frontBytes: frontBytes,
            backBytes: backBytes,
          );
          setState(() {
            _report = report;
            _isAnalyzing = false;
          });
          return;
        } else {
          throw Exception('웹에서는 Gemini AI 모드가 제한적입니다. YOLO 모드를 사용해주세요.');
        }
      }
      
      final report = await InspectionService.inspectPhone(
        frontImage: frontFile!,
        backImage: backFile!,
      );

      setState(() {
        _report = report;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _error = '검사에 실패했습니다. ${e.toString()}';
        _isAnalyzing = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _frontImage = null;
      _backImage = null;
      _report = null;
      _error = null;
    });
  }

  Future<void> _checkYOLOConnection() async {
    setState(() {
      _isCheckingYOLO = true;
    });
    await YOLOService.testConnection();
    setState(() {
      _isCheckingYOLO = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return _buildAnalyzingView();
    }

    if (_report != null) {
      return _buildResultView(_report!);
    }

    return _buildInputView();
  }

  Widget _buildInputView() {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'AI 스마트폰 상태 검사',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutral,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '휴대폰 이미지를 업로드하여 AI 기반 품질 분석을 받아보세요.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.neutral.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // 검사 모드 선택
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '검사 모드 선택',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.neutral,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            label: 'Gemini AI',
                            icon: Icons.auto_awesome,
                            isSelected: _selectedMode == InspectionMode.gemini,
                            onTap: () {
                              setState(() {
                                _selectedMode = InspectionMode.gemini;
                                InspectionService.setMode(InspectionMode.gemini);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ModeButton(
                            label: 'YOLO ver3',
                            icon: Icons.camera_alt,
                            isSelected: _selectedMode == InspectionMode.yolo,
                            onTap: () {
                              setState(() {
                                _selectedMode = InspectionMode.yolo;
                                InspectionService.setMode(InspectionMode.yolo);
                              });
                              _checkYOLOConnection();
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_selectedMode == InspectionMode.yolo) ...[
                      const SizedBox(height: 8),
                      if (_isCheckingYOLO)
                        const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '연결 확인 중...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.neutral,
                              ),
                            ),
                          ],
                        )
                      else
                        FutureBuilder<bool>(
                          future: YOLOService.testConnection(),
                          builder: (context, snapshot) {
                            final isConnected = snapshot.data ?? false;
                            return Row(
                              children: [
                                Icon(
                                  isConnected
                                      ? Icons.check_circle
                                      : Icons.error_outline,
                                  size: 16,
                                  color: isConnected
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    isConnected
                                        ? 'YOLO 서버 연결됨'
                                        : 'YOLO 서버 연결 필요 (${YOLOService.getBaseUrl()})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.neutral.withValues(alpha: 0.6),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Flexible(
                          flex: 1,
                          child: _ImageUploader(
                            label: '전면',
                            image: _frontImage,
                            onTap: () => _pickImage('front'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          flex: 1,
                          child: _ImageUploader(
                            label: '후면',
                            image: _backImage,
                            onTap: () => _pickImage('back'),
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _startInspection,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'AI 검사 시작',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzingView() {
    final messages = [
      'AI 분석 시스템 초기화 중...',
      '화면의 미세 흠집을 분석하고 있습니다...',
      '후면 패널의 외관 손상을 스캔 중입니다...',
      '프레임의 찍힘 및 긁힘을 확인하고 있습니다...',
      '전반적인 사용감을 평가하는 중...',
      '최종 품질 등급을 계산하고 있습니다...',
      '상세 리포트를 생성하는 중입니다...',
    ];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'AI가 분석하고 있습니다...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutral,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '잠시만 기다려주세요. AI가 꼼꼼하게 휴대폰 상태를 검사하고 있습니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.neutral.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                messages[DateTime.now().millisecondsSinceEpoch ~/
                    2000 %
                    messages.length],
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultView(InspectionReport report) {
    final gradeConfig = {
      'S': {'color': Colors.green, 'label': '최상'},
      'A': {'color': Colors.blue, 'label': '우수'},
      'B': {'color': Colors.orange, 'label': '양호'},
      'C': {'color': Colors.deepOrange, 'label': '보통'},
      'D': {'color': Colors.red, 'label': '미흡'},
    };

    final config =
        gradeConfig[report.grade] ?? {'color': Colors.grey, 'label': '알 수 없음'};

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color:
                            (config['color'] as Color).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          report.grade,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: config['color'] as Color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${config['label']} 상태',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: config['color'] as Color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.summary,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.neutral.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _DetailRow(
                      icon: Icons.phone_android,
                      label: '화면 상태',
                      value: report.screenCondition,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.phone_iphone,
                      label: '후면 상태',
                      value: report.backCondition,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.square,
                      label: '프레임 상태',
                      value: report.frameCondition,
                    ),
                    // 시각화된 이미지 표시
                    if (report.visualizedImages != null && report.visualizedImages!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '검출된 손상 위치',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.neutral,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...report.visualizedImages!.entries.map((entry) {
                        final viewName = entry.key;
                        final base64Image = entry.value;
                        final bytes = base64Decode(base64Image);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  viewName == 'front' ? '전면 검출 결과' : '후면 검출 결과',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.neutral,
                                  ),
                                ),
                              ),
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Image.memory(
                                    bytes,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    if (report.damages.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '발견된 문제점',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.neutral,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...report.damages.map(
                        (damage) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${damage.type} on ${damage.location}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.neutral,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '심각도: ${damage.severity}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.neutral
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '종합 평가',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.neutral,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.overallAssessment,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.neutral.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _reset,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          '다른 휴대폰 검사하기',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageUploader extends StatelessWidget {
  const _ImageUploader({
    required this.label,
    required this.image,
    required this.onTap,
  });

  final String label;
  final XFile? image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AspectRatio(
            aspectRatio: 1.0, // 정사각형 비율
            child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: image != null
                  ? AppTheme.primary
                  : AppTheme.primary.withValues(alpha: 0.2),
              width: image != null ? 2 : 1,
            ),
          ),
          child: image != null
            ? FutureBuilder<Uint8List>(
                future: image!.readAsBytes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    print('이미지 로드 오류: ${snapshot.error}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(height: 8),
                          Text(
                            '이미지 로드 실패',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.neutral.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: Icon(Icons.error));
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox.expand(
                          child: Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Image.memory 오류: $error');
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(Icons.broken_image, size: 48),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt,
                    size: 32,
                    color: AppTheme.neutral.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.neutral.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '클릭하여 업로드',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.neutral.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primary : AppTheme.neutral.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primary : AppTheme.neutral.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.neutral.withValues(alpha: 0.5)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.neutral.withValues(alpha: 0.7),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.neutral,
            ),
          ),
        ),
      ],
    );
  }
}


