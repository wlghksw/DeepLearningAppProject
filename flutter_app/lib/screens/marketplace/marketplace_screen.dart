import 'package:flutter/material.dart';
import 'package:flutter_app/core/models/inspection.dart';
import 'package:flutter_app/providers/inspection_provider.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:flutter_app/widgets/grade_chip.dart';
import 'package:provider/provider.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  QualityGrade? _selectedGrade;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InspectionProvider>();
    final completed = provider.completedRequests
        .where((element) => element.result != null)
        .toList();

    final filtered = _selectedGrade == null
        ? completed
        : completed
            .where((request) =>
                request.result!.grade.index <= _selectedGrade!.index)
            .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '등급 보증 마켓',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.neutral),
          ),
          const SizedBox(height: 6),
          Text(
            'AI 검수를 마친 기기를 등급별로 확인하세요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _GradeFilter(
            selectedGrade: _selectedGrade,
            onSelected: (grade) => setState(() => _selectedGrade = grade),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: filtered.isEmpty
                ? const _EmptyMarketplace()
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final request = filtered[index];
                      final result = request.result!;
                      return _MarketplaceCard(request: request, result: result);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _GradeFilter extends StatelessWidget {
  const _GradeFilter({required this.selectedGrade, required this.onSelected});

  final QualityGrade? selectedGrade;
  final ValueChanged<QualityGrade?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <QualityGrade?>[
      null,
      QualityGrade.s,
      QualityGrade.a,
      QualityGrade.b,
      QualityGrade.c
    ];
    return Wrap(
      spacing: 10,
      children: options.map((grade) {
        final isSelected = grade == selectedGrade;
        final label = grade == null ? '전체 등급' : '${grade.label} 등급 이상';
        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => onSelected(grade),
          selectedColor: AppTheme.primary,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppTheme.neutral,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.white,
          shape: StadiumBorder(
              side:
                  BorderSide(color: AppTheme.primary.withValues(alpha: 0.12))),
        );
      }).toList(),
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({required this.request, required this.result});

  final InspectionRequest request;
  final InspectionResult result;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 12),
          Text(
            result.summary,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _EmptyMarketplace extends StatelessWidget {
  const _EmptyMarketplace();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 40, color: AppTheme.primary),
            const SizedBox(height: 10),
            Text(
              '조건에 맞는 기기가 아직 없어요.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              '필터를 조정하거나 검수 완료 후 다시 확인해 주세요.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
