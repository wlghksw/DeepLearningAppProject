import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/types.dart';
import '../providers/store_provider.dart';
import '../services/gemini_service.dart';
import '../widgets/grade_badge.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _modelNameController = TextEditingController();
  final _sellerNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  XFile? _frontImage;
  XFile? _backImage;
  Uint8List? _frontImageBytes;
  Uint8List? _backImageBytes;
  int _batteryHealth = 100;
  bool _isAnalyzing = false;
  AIAnalysisResult? _analysisResult;
  String? _error;

  @override
  void dispose() {
    _modelNameController.dispose();
    _sellerNameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, bool isFront) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        if (isFront) {
          _frontImage = image;
          _frontImageBytes = bytes;
        } else {
          _backImage = image;
          _backImageBytes = bytes;
        }
        _analysisResult = null;
        _error = null;
      });
    }
  }

  Future<void> _runAIAnalysis() async {
    if (_frontImage == null || _backImage == null) {
      setState(() {
        _error = "정확한 판정을 위해 전면과 후면 사진이 모두 필요합니다.";
      });
      return;
    }
    if (_modelNameController.text.isEmpty) {
      setState(() {
        _error = "모델명을 입력해주세요.";
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final frontBytes = _frontImageBytes ?? await _frontImage!.readAsBytes();
      final backBytes = _backImageBytes ?? await _backImage!.readAsBytes();
      final frontBase64 = base64Encode(frontBytes);
      final backBase64 = base64Encode(backBytes);

      final result = await GeminiService.analyzePhoneImages(
        [frontBase64, backBase64],
        _modelNameController.text,
        _batteryHealth,
      );

      setState(() {
        _analysisResult = result;
      });
    } catch (e) {
      setState(() {
        _error = "분석 중 문제가 발생했습니다: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_analysisResult == null ||
        _sellerNameController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      setState(() {
        _error = "모든 필드를 입력하고 AI 분석을 완료해주세요.";
      });
      return;
    }
    if (_frontImage == null || _backImage == null) return;

    final store = Provider.of<StoreProvider>(context, listen: false);
    final frontBytes = _frontImageBytes ?? await _frontImage!.readAsBytes();
    final backBytes = _backImageBytes ?? await _backImage!.readAsBytes();
    
    final product = Product(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sellerName: _sellerNameController.text,
      modelName: _modelNameController.text,
      batteryHealth: _batteryHealth,
      price: int.parse(_priceController.text),
      description: _descriptionController.text,
      images: [
        'data:image/jpeg;base64,${base64Encode(frontBytes)}',
        'data:image/jpeg;base64,${base64Encode(backBytes)}',
      ],
      analysis: _analysisResult,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      status: ProductStatus.listed,
    );

    store.addProduct(product);
    if (context.mounted) {
      context.go('/product/${product.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 768),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 폰 판매하기',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI가 사진을 분석하여 투명한 등급을 매겨드립니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: Photos
                  _buildStepSection(
                    step: 1,
                    title: '사진 등록',
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildImageUploadBox(
                            label: '전면 (Screen)',
                            image: _frontImage,
                            imageBytes: _frontImageBytes,
                            onTap: () => _pickImage(ImageSource.gallery, true),
                            onRemove: () => setState(() {
                              _frontImage = null;
                              _frontImageBytes = null;
                              _analysisResult = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildImageUploadBox(
                            label: '후면 (Back)',
                            image: _backImage,
                            imageBytes: _backImageBytes,
                            onTap: () => _pickImage(ImageSource.gallery, false),
                            onRemove: () => setState(() {
                              _backImage = null;
                              _backImageBytes = null;
                              _analysisResult = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Step 2: Details
                  _buildStepSection(
                    step: 2,
                    title: '상세 정보',
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Model Name
                          _buildTextField(
                            label: '기종',
                            controller: _modelNameController,
                            hintText: '예: iPhone 15 Pro',
                          ),
                          const SizedBox(height: 20),
                          // Seller Name & Price
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  label: '판매자명',
                                  controller: _sellerNameController,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  label: '희망 가격',
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  hintText: '원',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Battery Health
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '배터리 효율',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  Text(
                                    '$_batteryHealth%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _batteryHealth >= 85
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _batteryHealth.toDouble(),
                                min: 50,
                                max: 100,
                                divisions: 50,
                                onChanged: (value) {
                                  setState(() {
                                    _batteryHealth = value.toInt();
                                  });
                                },
                                activeColor: const Color(0xFF1C1917),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Description
                          _buildTextField(
                            label: '판매자 코멘트',
                            controller: _descriptionController,
                            maxLines: 5,
                            hintText: '제품 상태에 대한 솔직한 설명을 적어주세요.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Analyze Button
                  if (_analysisResult == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isAnalyzing ? null : _runAIAnalysis,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isAnalyzing
                              ? Colors.grey.shade100
                              : const Color(0xFFF97316),
                          foregroundColor: _isAnalyzing
                              ? Colors.grey.shade400
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: _isAnalyzing ? 0 : 8,
                        ),
                        child: _isAnalyzing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.grey),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'AI 분석 중...',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.smartphone, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'AI 검수 및 등록',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  // Error Message
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red.shade600, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Result Section
            if (_analysisResult != null) ...[
              const SizedBox(height: 40),
              _buildResultSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepSection({
    required int step,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF1C1917),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$step',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1917),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }

  Widget _buildImageUploadBox({
    required String label,
    required XFile? image,
    Uint8List? imageBytes,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 0.75,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: image != null ? Colors.white : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: image != null
                      ? const Color(0xFF1C1917)
                      : Colors.grey.shade200,
                  width: 2,
                ),
              ),
              child: image != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: kIsWeb
                              ? Image.memory(
                                  imageBytes!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(image.path),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: onRemove,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 24,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '사진 업로드',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade300),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1C1917), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1917),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
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
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _analysisResult!.grade.value,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '등급',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF97316),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Visualized Images (YOLO Detection Box)
              if (_analysisResult!.visualizedImages != null &&
                  _analysisResult!.visualizedImages!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 검수 결과',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_analysisResult!.visualizedImages!.containsKey('front'))
                          Expanded(
                            child: _buildVisualizedImage(
                              '전면',
                              _analysisResult!.visualizedImages!['front']!,
                            ),
                          ),
                        if (_analysisResult!.visualizedImages!.containsKey('front') &&
                            _analysisResult!.visualizedImages!.containsKey('back'))
                          const SizedBox(width: 16),
                        if (_analysisResult!.visualizedImages!.containsKey('back'))
                          Expanded(
                            child: _buildVisualizedImage(
                              '후면',
                              _analysisResult!.visualizedImages!['back']!,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              // Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '등록 가격',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  Text(
                    '${_priceController.text.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1C1917),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '판매 등록 확정',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizedImage(String label, String base64Image) {
    final base64String = base64Image.split(',').length > 1
        ? base64Image.split(',')[1]
        : base64Image;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 0.75,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                base64Decode(base64String),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

