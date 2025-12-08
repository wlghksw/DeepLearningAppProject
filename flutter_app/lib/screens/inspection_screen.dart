import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
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
      XFile? image;
      
      // macOS/데스크톱에서는 file_picker를 우선 사용
      if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
        try {
          print('📁 file_picker로 파일 선택 시도...');
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: false,
            dialogTitle: '이미지 선택',
          );
          
          if (result != null && result.files.isNotEmpty) {
            final file = result.files.first;
            if (file.path != null) {
              image = XFile(file.path!);
              print('✅ file_picker로 파일 선택됨: ${file.path}');
            } else if (file.bytes != null) {
              // 웹이나 일부 플랫폼에서는 bytes로 제공될 수 있음
              // 임시 파일로 저장
              final tempDir = Directory.systemTemp;
              final tempFile = File('${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
              await tempFile.writeAsBytes(file.bytes!);
              image = XFile(tempFile.path);
              print('✅ file_picker로 파일 선택됨 (bytes): ${tempFile.path}');
            }
          } else {
            print('ℹ️ 사용자가 파일 선택 취소');
            return;
          }
        } catch (e) {
          print('⚠️ file_picker 실패: $e');
          // file_picker 실패 시 image_picker로 폴백
          print('📷 image_picker로 폴백 시도...');
          try {
            image = await _picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
            );
            if (image != null) {
              print('✅ image_picker로 이미지 선택됨: ${image.path}');
            }
          } catch (e2) {
            print('❌ image_picker도 실패: $e2');
            setState(() {
              _error = '이미지 선택에 실패했습니다. 파일 선택 다이얼로그를 확인해주세요.\n오류: ${e.toString()}';
            });
            return;
          }
        }
      } else {
        // 모바일/웹에서는 image_picker 사용
        ImageSource? source = await showDialog<ImageSource>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('이미지 선택'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('갤러리에서 선택'),
                    onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  ),
                  if (!kIsWeb)
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: const Text('카메라로 촬영'),
                      onTap: () => Navigator.of(context).pop(ImageSource.camera),
                    ),
                ],
              ),
            );
          },
        );
        
        if (source != null) {
          image = await _picker.pickImage(
            source: source,
            imageQuality: 85,
          );
        }
      }
      
      if (image != null) {
        print('✅ 이미지 선택됨: ${image.name}, 경로: ${image.path}');
        
        // 이미지가 제대로 로드되는지 확인
        try {
          final bytes = await image.readAsBytes();
          print('✅ 이미지 바이트 읽기 성공: ${bytes.length} bytes');
          
          if (bytes.isEmpty) {
            throw Exception('이미지 파일이 비어있습니다.');
          }
        } catch (e) {
          print('⚠️ 이미지 바이트 읽기 실패: $e');
          setState(() {
            _error = '이미지를 읽을 수 없습니다: ${e.toString()}';
          });
          return;
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
          _error = null;
        });
      }
    } catch (e, stackTrace) {
      print('❌ 이미지 선택 오류: $e');
      print('스택 트레이스: $stackTrace');
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
        child: Stack(
          children: [
            // Ambient Background Effects
            Positioned.fill(
              child: CustomPaint(
                painter: _AmbientBackgroundPainter(),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // 헤더
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '내 폰 판매하기',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.stone900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI가 사진을 분석하여 투명한 등급을 매겨드립니다.',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.neutralLight,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  // Step 1: 사진 등록
                  _StepSection(
                    stepNumber: 1,
                    title: '사진 등록',
                    child: Row(
                      children: [
                        Expanded(
                          child: _ImageUploader(
                            label: '전면 (Screen)',
                            image: _frontImage,
                            onTap: () => _pickImage('front'),
                            onRemove: _frontImage != null
                                ? () {
                                    setState(() {
                                      _frontImage = null;
                                    });
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ImageUploader(
                            label: '후면 (Back)',
                            image: _backImage,
                            onTap: () => _pickImage('back'),
                            onRemove: _backImage != null
                                ? () {
                                    setState(() {
                                      _backImage = null;
                                    });
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Step 2: 검사 모드 선택 (간소화)
                  if (_selectedMode == InspectionMode.yolo) ...[
                    _StepSection(
                      stepNumber: 2,
                      title: 'AI 검수',
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.smartphone,
                                    color: AppTheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'YOLO AI 검수',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.stone900,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '딥러닝 모델 기반 자동 검출',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.neutralLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                FutureBuilder<bool>(
                                  future: YOLOService.testConnection(),
                                  builder: (context, snapshot) {
                                    final isConnected = snapshot.data ?? false;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isConnected 
                                            ? Colors.green.withValues(alpha: 0.1)
                                            : Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isConnected ? Icons.check_circle : Icons.error_outline,
                                            size: 14,
                                            color: isConnected ? Colors.green : Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isConnected ? '연결됨' : '연결 필요',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isConnected ? Colors.green : Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                  
                  // 에러 메시지
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // AI 검수 버튼
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _frontImage != null && _backImage != null ? _startInspection : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ).copyWith(
                        elevation: WidgetStateProperty.all(0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.smartphone, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'AI 검수 및 등록',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
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
      'S': {'color': const Color(0xFF9333EA), 'label': '최상'}, // purple
      'A': {'color': const Color(0xFF2563EB), 'label': '우수'}, // blue
      'B': {'color': const Color(0xFF10B981), 'label': '양호'}, // emerald
      'C': {'color': const Color(0xFFFB923C), 'label': '보통'}, // orange
      'D': {'color': const Color(0xFFEF4444), 'label': '미흡'}, // red
    };

    final config =
        gradeConfig[report.grade] ?? {'color': AppTheme.neutralLighter, 'label': '알 수 없음'};

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // 다크 모드 결과 카드 (참고 프로젝트 스타일)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.stone900,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 헤더
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '검수 완료',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'AI가 판정한 최종 등급입니다.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                report.grade,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '등급',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Damage Report
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAMAGE REPORT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.5),
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (report.damages.isEmpty)
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '발견된 손상이 없습니다.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            )
                          else
                            ...report.damages.map((damage) {
                              final isHigh = damage.severity == 'severe';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isHigh 
                                            ? const Color(0xFFEF4444)
                                            : AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            damage.location,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${damage.type} - ${damage.severity}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    // 시각화된 이미지 표시
                    if (report.visualizedImages != null && report.visualizedImages!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      ...report.visualizedImages!.entries.map((entry) {
                        final viewName = entry.key;
                        final base64Image = entry.value;
                        final bytes = base64Decode(base64Image);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    viewName == 'front' ? '전면 검출 결과' : '후면 검출 결과',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Image.memory(
                                  bytes,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _reset,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.stone900,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '다른 휴대폰 검사하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 20),
                          ],
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
    this.onRemove,
  });

  final String label;
  final XFile? image;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.neutralLight,
                letterSpacing: 0.5,
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: 3 / 4, // 세로형 비율
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: image != null
                      ? AppTheme.stone900
                      : AppTheme.stone200,
                  width: image != null ? 2 : 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: image != null
                    ? FutureBuilder<Uint8List>(
                        future: image!.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError || !snapshot.hasData) {
                            return Container(
                              color: AppTheme.stone100,
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 48, color: AppTheme.neutralLighter),
                              ),
                            );
                          }
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                              ),
                              if (onRemove != null)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      onRemove!();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.stone900.withValues(alpha: 0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      )
                    : Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppTheme.stone200,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.stone100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 24,
                                color: AppTheme.neutralLighter,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '사진 업로드',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.neutralLighter,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
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

// Step Section 위젯
class _StepSection extends StatelessWidget {
  const _StepSection({
    required this.stepNumber,
    required this.title,
    required this.child,
  });

  final int stepNumber;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppTheme.stone900,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$stepNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.stone900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

// Ambient Background Painter
class _AmbientBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
    
    final paint2 = Paint()
      ..color = const Color(0xFFFFE4E6).withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    
    final paint3 = Paint()
      ..color = AppTheme.stone100.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
    
    // Top left circle
    canvas.drawCircle(
      Offset(-size.width * 0.1, -size.height * 0.1),
      size.width * 0.5,
      paint1,
    );
    
    // Top right circle
    canvas.drawCircle(
      Offset(size.width * 1.1, size.height * 0.2),
      size.width * 0.4,
      paint2,
    );
    
    // Bottom left circle
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 1.1),
      size.width * 0.6,
      paint3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


