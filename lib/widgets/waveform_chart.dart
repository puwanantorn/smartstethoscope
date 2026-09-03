import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Reusable live/static waveform chart. Used for both the Home screen's
/// real-time IR waveform and a saved record's historical waveform, so the
/// y-axis range is auto-computed from whatever data is passed in rather
/// than assuming a fixed scale.
class WaveformChart extends StatefulWidget {
  const WaveformChart({
    super.key,
    required this.waveform,
    this.isLive = false,
    this.height = 100,
    this.color = AppColors.primary,
    this.emptyMessage = 'No data',
    this.maxPoints = 100,
  });

  final List<double> waveform;
  final bool isLive;
  final double height;
  final Color color;
  final String emptyMessage;

  /// Only the most recent [maxPoints] points are plotted.
  final int maxPoints;

  @override
  State<WaveformChart> createState() => _WaveformChartState();
}

class _WaveformChartState extends State<WaveformChart> {
  Timer? _blinkTimer;
  bool _blinkOn = true;

  @override
  void initState() {
    super.initState();
    _syncBlinkTimer();
  }

  @override
  void didUpdateWidget(covariant WaveformChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLive != widget.isLive) _syncBlinkTimer();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _syncBlinkTimer() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    if (!widget.isLive) return;
    _blinkOn = true;
    _blinkTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _blinkOn = !_blinkOn);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<double> clipped = widget.waveform.length > widget.maxPoints
        ? widget.waveform.sublist(widget.waveform.length - widget.maxPoints)
        : widget.waveform;
    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < clipped.length; i++) FlSpot(i.toDouble(), clipped[i]),
    ];

    double minY = -1.5;
    double maxY = 1.5;
    if (clipped.isNotEmpty) {
      final double dataMin = clipped.reduce(math.min);
      final double dataMax = clipped.reduce(math.max);
      final double pad = math.max((dataMax - dataMin) * 0.1, 0.5);
      minY = dataMin - pad;
      maxY = dataMax + pad;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HEART SOUND (PHONOCARDIOGRAM)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              if (widget.isLive)
                Opacity(
                  opacity: _blinkOn ? 1 : 0.2,
                  child: const Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.redAccent),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: widget.height,
            child: spots.isEmpty
                ? Center(
                    child: Text(
                      widget.emptyMessage,
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                  )
                : LineChart(
                    duration: Duration.zero,
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minY: minY,
                      maxY: maxY,
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: widget.color,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: widget.color.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
