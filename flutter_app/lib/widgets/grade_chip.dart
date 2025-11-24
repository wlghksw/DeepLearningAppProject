import 'package:flutter/material.dart';
import 'package:flutter_app/core/models/inspection.dart';
import 'package:flutter_app/theme/app_theme.dart';

class GradeChip extends StatelessWidget {
  const GradeChip({super.key, required this.grade});

  final QualityGrade grade;

  @override
  Widget build(BuildContext context) {
    final color = grade.resolveColor(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: Text(
              grade.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            grade.description,
            style: const TextStyle(
              color: AppTheme.neutral,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
