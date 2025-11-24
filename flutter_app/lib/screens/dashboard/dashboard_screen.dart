import 'package:flutter/material.dart';
import 'package:flutter_app/core/models/inspection.dart';
import 'package:flutter_app/providers/inspection_provider.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:flutter_app/widgets/feature_card.dart';
import 'package:flutter_app/widgets/grade_chip.dart';
import 'package:flutter_app/widgets/inspection_status_tile.dart';
import 'package:flutter_app/widgets/stat_card.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InspectionProvider>();
    final active = provider.activeRequests;
    final completed = provider.completedRequests;

    const featureCards = [
      FeatureCardData(
        title: '촬영 가이드',
        description: '전면·후면·측면·모서리를 밝고 선명하게 촬영하세요.',
        icon: Icons.photo_camera,
      ),
      FeatureCardData(
        title: '배터리 캡처',
        description: '설정 화면에서 배터리 성능 캡처를 추가하면 정확도가 높아집니다.',
        icon: Icons.battery_charging_full,
      ),
      FeatureCardData(
        title: '부정 등록 방지',
        description: '흐릿하거나 합성된 이미지는 자동으로 제외됩니다.',
        icon: Icons.shield_outlined,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: ListView(
        children: [
          _HeroBanner(
              activeCount: active.length, completedCount: completed.length),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                StatCard(
                  icon: Icons.fact_check_outlined,
                  label: '총 검수 요청',
                  value: provider.totalRequestCount.toString(),
                ),
                const SizedBox(width: 12),
                StatCard(
                  icon: Icons.check_circle_outline,
                  label: '완료된 검수',
                  value: completed.length.toString(),
                ),
                const SizedBox(width: 12),
                StatCard(
                  icon: Icons.favorite_outline,
                  label: '평균 배터리',
                  value: '${provider.averageBatteryHealth.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '촬영 팁',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: featureCards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  FeatureCard(data: featureCards[index]),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '진행 중인 검수',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (active.isEmpty)
            const _EmptyState(message: '진행 중인 검수가 없습니다. 새 기기를 등록해 보세요.')
          else
            ...active.map((request) => InspectionStatusTile(request: request)),
          const SizedBox(height: 24),
          Text(
            '최근 완료',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (completed.isEmpty)
            const _EmptyState(message: '아직 완료된 검수가 없습니다.')
          else
            ...completed.take(3).map(
                  (request) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CompletedCard(request: request),
                  ),
                ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.activeCount, required this.completedCount});

  final int activeCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 품질 검수',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  '실시간 검수 현황과 요약을 확인하세요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.local_mall_outlined,
                size: 36, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.request});

  final InspectionRequest request;

  @override
  Widget build(BuildContext context) {
    final result = request.result;
    if (result == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.submission.deviceName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${request.submission.storage} · 배터리 ${request.submission.batteryHealth.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              GradeChip(grade: result.grade),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.summary,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.neutral.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
