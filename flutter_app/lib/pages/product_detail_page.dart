import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/types.dart';
import '../providers/store_provider.dart';
import '../widgets/grade_badge.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({super.key, required this.productId});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int activeImage = 0;

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<StoreProvider>(context);
    final product = store.getProduct(widget.productId);

    if (product == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '상품 정보를 불러올 수 없습니다.',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1917),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  '홈으로',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final analysis = product.analysis;

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1280),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mobile Back Button
              if (MediaQuery.of(context).size.width < 1024)
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
                  child: GestureDetector(
                    onTap: () => context.go('/'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.chevron_left, size: 24),
                    ),
                  ),
                ),
              // Content Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 1024) {
                    return _buildDesktopLayout(product, analysis);
                  } else {
                    return _buildMobileLayout(product, analysis);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      // Mobile Bottom Action
      bottomNavigationBar: MediaQuery.of(context).size.width < 1024
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // 구매 채팅 보내기
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1917),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '구매 채팅 보내기',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            )
          : null,
      // Desktop Floating Action
      floatingActionButton: MediaQuery.of(context).size.width >= 1024
          ? FloatingActionButton.extended(
              onPressed: () {
                // 구매 채팅 보내기
              },
              backgroundColor: const Color(0xFF1C1917),
              foregroundColor: Colors.white,
              label: const Row(
                children: [
                  Text(
                    '구매 채팅 보내기',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildDesktopLayout(Product product, AIAnalysisResult? analysis) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Images
        Expanded(
          flex: 7,
          child: Column(
            children: [
              // Main Image
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: _buildImage(product.images[activeImage]),
                      ),
                      Positioned(
                        top: 24,
                        left: 24,
                        child: GradeBadge(
                          grade: analysis?.grade,
                          size: BadgeSize.lg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Thumbnails
              Row(
                children: product.images.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final img = entry.value;
                  final isActive = activeImage == idx;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: idx < product.images.length - 1 ? 16 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => activeImage = idx),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFF1C1917)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Opacity(
                                opacity: isActive ? 1.0 : 0.7,
                                child: _buildImage(img),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
        // Right: Info
        Expanded(
          flex: 5,
          child: _buildProductInfo(product, analysis),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(Product product, AIAnalysisResult? analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Image
        AspectRatio(
          aspectRatio: 0.75,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
            ),
            child: Stack(
              children: [
                _buildImage(product.images[activeImage]),
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: GradeBadge(
                    grade: analysis?.grade,
                    size: BadgeSize.lg,
                  ),
                ),
                // Dots Indicator
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: product.images.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final isActive = activeImage == idx;
                      return GestureDetector(
                        onTap: () => setState(() => activeImage = idx),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white
                                : Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Info
        _buildProductInfo(product, analysis),
      ],
    );
  }

  Widget _buildProductInfo(Product product, AIAnalysisResult? analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seller & Date
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                product.sellerName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '•',
              style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDate(product.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Title
        Text(
          product.modelName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1917),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        // Price
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${product.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEA580C),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '원',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Stats Grid
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.battery_charging_full,
                label: 'BATTERY',
                value: '${product.batteryHealth}%',
                color: product.batteryHealth >= 85
                    ? const Color(0xFF1C1917)
                    : const Color(0xFFEA580C),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.warning_amber_rounded,
                label: 'ISSUES',
                value: '${analysis?.damageReport.length ?? 0}',
                suffix: '건',
                color: const Color(0xFF1C1917),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Seller Comment
        _buildSection(
          icon: Icons.message,
          title: '판매자 코멘트',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              product.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // AI Analysis Report
        _buildSection(
          icon: Icons.check_circle,
          title: 'AI 검수 리포트',
          iconColor: const Color(0xFFF97316),
          child: analysis != null && analysis.damageReport.isNotEmpty
              ? Column(
                  children: analysis.damageReport.map((damage) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: damage.severity == DamageSeverity.high
                                  ? Colors.red
                                  : damage.severity == DamageSeverity.medium
                                      ? Colors.orange
                                      : Colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${damage.location} ${damage.type}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C1917),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  damage.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              : Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD1FAE5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Color(0xFF059669), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '특별한 외관 손상이 발견되지 않았습니다.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    String? suffix,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Text(
                  suffix,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: iconColor ?? Colors.grey.shade400,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1917),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      // Base64 이미지
      final base64String = imageUrl.split(',')[1];
      return Image.memory(
        base64Decode(base64String),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    } else {
      // URL 이미지
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade100,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade100,
          child: const Icon(Icons.error),
        ),
      );
    }
  }
}

