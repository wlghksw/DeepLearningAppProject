import 'package:flutter/material.dart';
import '../models/types.dart';

class GradeBadge extends StatelessWidget {
  final QualityGrade? grade;
  final String? gradeString;
  final BadgeSize size;

  const GradeBadge({
    super.key,
    this.grade,
    this.gradeString,
    this.size = BadgeSize.md,
  });

  Color _getBackgroundColor(String g) {
    switch (g) {
      case 'S':
        return const Color(0xFFF3E8FF); // purple-50
      case 'A':
        return const Color(0xFFEFF6FF); // blue-50
      case 'B':
        return const Color(0xFFECFDF5); // emerald-50
      case 'C':
        return const Color(0xFFFFF7ED); // orange-50
      case 'D':
        return const Color(0xFFFEF2F2); // red-50
      default:
        return const Color(0xFFFAFAF9); // stone-50
    }
  }

  Color _getTextColor(String g) {
    switch (g) {
      case 'S':
        return const Color(0xFF9333EA); // purple-600
      case 'A':
        return const Color(0xFF2563EB); // blue-600
      case 'B':
        return const Color(0xFF059669); // emerald-600
      case 'C':
        return const Color(0xFFEA580C); // orange-600
      case 'D':
        return const Color(0xFFDC2626); // red-600
      default:
        return const Color(0xFF78716C); // stone-500
    }
  }

  Color _getBorderColor(String g) {
    switch (g) {
      case 'S':
        return const Color(0xFFE9D5FF); // purple-100
      case 'A':
        return const Color(0xFFDBEAFE); // blue-100
      case 'B':
        return const Color(0xFFD1FAE5); // emerald-100
      case 'C':
        return const Color(0xFFFED7AA); // orange-100
      case 'D':
        return const Color(0xFFFEE2E2); // red-100
      default:
        return const Color(0xFFE7E5E4); // stone-200
    }
  }

  double _getFontSize() {
    switch (size) {
      case BadgeSize.sm:
        return 10;
      case BadgeSize.lg:
        return 20;
      default:
        return 12;
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case BadgeSize.sm:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case BadgeSize.lg:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 6);
      default:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    }
  }

  FontWeight _getFontWeight() {
    return size == BadgeSize.lg ? FontWeight.bold : FontWeight.w600;
  }

  @override
  Widget build(BuildContext context) {
    final gradeValue = grade?.value ?? gradeString ?? 'C';
    final backgroundColor = _getBackgroundColor(gradeValue);
    final textColor = _getTextColor(gradeValue);
    final borderColor = _getBorderColor(gradeValue);

    return Container(
      padding: _getPadding(),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        '${gradeValue}등급',
        style: TextStyle(
          color: textColor,
          fontSize: _getFontSize(),
          fontWeight: _getFontWeight(),
        ),
      ),
    );
  }
}

enum BadgeSize { sm, md, lg }






