import 'package:flutter/material.dart';

import '../models/heart_rate_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

Color colorForCondition(AiCondition condition) {
  switch (condition) {
    case AiCondition.normal:
      return AppColors.normal;
    case AiCondition.murmur:
      return AppColors.murmur;
    case AiCondition.arrhythmia:
      return AppColors.arrhythmia;
  }
}

String labelForCondition(AiCondition condition) {
  switch (condition) {
    case AiCondition.normal:
      return 'Normal';
    case AiCondition.murmur:
      return 'Heart Murmur';
    case AiCondition.arrhythmia:
      return 'Arrhythmia';
  }
}

IconData iconForCondition(AiCondition condition) {
  switch (condition) {
    case AiCondition.normal:
      return Icons.check_circle;
    case AiCondition.murmur:
      return Icons.warning_rounded;
    case AiCondition.arrhythmia:
      return Icons.error;
  }
}

class AiResultSection extends StatelessWidget {
  const AiResultSection({super.key, required this.results});

  final List<AiResult> results;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI ANALYSIS RESULT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Updated just now',
              style: TextStyle(fontSize: 11, color: context.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (int i = 0; i < results.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: AiResultCard(result: results[i])),
            ],
          ],
        ),
      ],
    );
  }
}

class AiResultCard extends StatelessWidget {
  const AiResultCard({super.key, required this.result, this.expanded = false});

  final AiResult result;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final color = colorForCondition(result.condition);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconForCondition(result.condition), color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            labelForCondition(result.condition),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (result.confidence / 100).clamp(0, 1),
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${result.confidence.round()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 4),
            Text(
              result.description,
              style: TextStyle(fontSize: 11, color: context.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
