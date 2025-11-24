import 'package:flutter/material.dart';
import 'package:flutter_app/core/models/inspection.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:flutter_app/widgets/grade_chip.dart';

class InspectionStatusTile extends StatelessWidget {
  const InspectionStatusTile({
    super.key,
    required this.request,
    this.trailing,
  });

  final InspectionRequest request;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isCompleted = request.status == InspectionStatus.completed;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.task_alt : Icons.timelapse,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
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
                const SizedBox(height: 6),
                Text(
                  isCompleted
                      ? '검수 완료: ${request.result?.summary.split('\n').first ?? ''}'
                      : 'AI 분석 중 · 평균 5초 내 결과 제공',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isCompleted && request.result != null)
            GradeChip(grade: request.result!.grade)
          else
            trailing ??
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
        ],
      ),
    );
  }
}
