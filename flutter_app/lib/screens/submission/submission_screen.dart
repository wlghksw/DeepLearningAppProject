import 'package:flutter/material.dart';
import 'package:flutter_app/core/models/product.dart';
import 'package:flutter_app/providers/inspection_provider.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

class SubmissionScreen extends StatefulWidget {
  const SubmissionScreen({super.key});

  @override
  State<SubmissionScreen> createState() => _SubmissionScreenState();
}

class _SubmissionScreenState extends State<SubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _modelController = TextEditingController();
  final _storageController = TextEditingController();
  final _batteryController = TextEditingController();
  final _imeiController = TextEditingController();
  final _noteController = TextEditingController();

  final List<_CaptureGuide> _captureGuides = const [
    _CaptureGuide(label: '전면 사진'),
    _CaptureGuide(label: '후면 사진'),
    _CaptureGuide(label: '좌측 측면'),
    _CaptureGuide(label: '우측 측면'),
    _CaptureGuide(label: '배터리 캡처'),
  ];

  late List<bool> _capturedFlags;

  @override
  void initState() {
    super.initState();
    _capturedFlags = List<bool>.filled(_captureGuides.length, false);
  }

  @override
  void dispose() {
    _modelController.dispose();
    _storageController.dispose();
    _batteryController.dispose();
    _imeiController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _toggleCapture(int index) {
    setState(() {
      _capturedFlags[index] = !_capturedFlags[index];
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final capturedAngles = <String>[];
    for (var i = 0; i < _captureGuides.length; i++) {
      if (_capturedFlags[i]) capturedAngles.add(_captureGuides[i].label);
    }

    if (capturedAngles.length != _captureGuides.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 이미지 5장을 모두 선택해주세요.')),
      );
      return;
    }

    final battery = double.tryParse(_batteryController.text);
    if (battery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배터리 건강도를 숫자로 입력해주세요.')),
      );
      return;
    }

    final submission = ProductSubmission(
      deviceName: _modelController.text.trim(),
      storage: _storageController.text.trim(),
      batteryHealth: battery,
      imageAngles: capturedAngles,
      imei: _imeiController.text.trim().isNotEmpty
          ? _imeiController.text.trim()
          : null,
      sellerNote: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
    );

    if (!mounted) return;

    context.read<InspectionProvider>().submitInspection(submission);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI가 이미지를 분석 중입니다. 곧 결과를 알려드릴게요.')),
    );

    _formKey.currentState!.reset();
    _modelController.clear();
    _storageController.clear();
    _batteryController.clear();
    _imeiController.clear();
    _noteController.clear();
    setState(() {
      _capturedFlags = List<bool>.filled(_captureGuides.length, false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final capturedCount = _capturedFlags.where((flag) => flag).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: ListView(
        children: [
          const _SectionTitle(
            title: '검수 요청 등록',
            description: '중고 스마트폰을 올리고 AI 검수를 받아보세요.',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    controller: _modelController,
                    label: '모델명',
                    hint: '예) iPhone 14 Pro',
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _storageController,
                    label: '저장 용량',
                    hint: '예) 256GB',
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _batteryController,
                    label: '배터리 건강도 (%)',
                    hint: '예) 92',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '배터리 건강도를 입력해주세요.';
                      }
                      final parsed = double.tryParse(value);
                      if (parsed == null || parsed <= 0 || parsed > 100) {
                        return '0~100 사이의 숫자를 입력해주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildOptionalField(_imeiController, 'IMEI (선택)'),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      label: '판매자 메모 (선택)',
                      hint: '기타 부속품, 사용 이력 등을 기록해 주세요.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '필수 촬영 이미지 ($capturedCount/${_captureGuides.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '선명한 사진일수록 정확도가 높아요',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < _captureGuides.length; i++)
                _CaptureCard(
                  guide: _captureGuides[i],
                  captured: _capturedFlags[i],
                  onTap: () => _toggleCapture(i),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.send_rounded),
            label: const Text('검수 요청 보내기'),
          ),
          const SizedBox(height: 16),
          const _GuideBox(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label을 입력해주세요.';
            }
            return null;
          },
      decoration: _inputDecoration(label: label, hint: hint),
    );
  }

  Widget _buildOptionalField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label: label, hint: null),
    );
  }

  InputDecoration _inputDecoration({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
    );
  }
}

class _CaptureGuide {
  const _CaptureGuide({required this.label});

  final String label;
}

class _CaptureCard extends StatelessWidget {
  const _CaptureCard({
    required this.guide,
    required this.captured,
    required this.onTap,
  });

  final _CaptureGuide guide;
  final bool captured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: captured
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.08),
            width: captured ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              captured ? Icons.check_circle : Icons.camera_alt_outlined,
              color: captured ? AppTheme.primary : AppTheme.neutral,
            ),
            const SizedBox(height: 10),
            Text(
              guide.label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              captured ? '등록 완료' : '사진 추가',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.neutral.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideBox extends StatelessWidget {
  const _GuideBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '밝은 자연광에서 촬영하고, 배터리 캡처는 설정 > 배터리 항목을 촬영해 주세요. 흐릿하면 재촬영 안내가 나옵니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
