import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/predict_response.dart';
import '../providers/heart_rate_provider.dart';
import '../providers/records_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_result_card.dart';
import '../widgets/waveform_chart.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final heartRate = context.watch<HeartRateProvider>();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _Header(),
            const SizedBox(height: 16),
            const _CalibrationBanner(),
            _StatusCard(heartRate: heartRate),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 6, child: _BpmCard(heartRate: heartRate)),
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: _HeartRateZoneCard(heartRate: heartRate)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Spo2Card(heartRate: heartRate),
            const SizedBox(height: 16),
            WaveformChart(
              waveform: heartRate.waveData,
              isLive: heartRate.isRunning,
              color: const Color(0xFF1E90FF),
              emptyMessage: 'Place finger on sensor',
            ),
            const SizedBox(height: 16),
            _MlPredictionCard(heartRate: heartRate),
            const SizedBox(height: 16),
            heartRate.isFingerDetected
                ? AiResultSection(results: heartRate.aiResults)
                : const _NoFingerCard(),
            const SizedBox(height: 20),
            _ControlButtons(heartRate: heartRate),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                heartRate.correctionFactor == 1.0
                    ? 'Not calibrated'
                    : 'Calibration: ${heartRate.correctionFactor.toStringAsFixed(2)}x',
                style: TextStyle(fontSize: 11, color: context.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces the shared `BpmCard` widget for Home specifically, since this
/// screen needs to show "--" plus a "place finger" caption whenever
/// [HeartRateProvider.isFingerDetected] is false.
class _BpmCard extends StatelessWidget {
  const _BpmCard({required this.heartRate});

  final HeartRateProvider heartRate;

  @override
  Widget build(BuildContext context) {
    final bool detected = heartRate.isFingerDetected;
    final int? bpm = heartRate.displayBpm;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HEART RATE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(Icons.favorite, color: Colors.white70, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                detected && bpm != null ? '$bpm' : '--',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'BPM',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (!detected) ...[
            const SizedBox(height: 4),
            const Text(
              'Place finger on sensor',
              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}

/// Replaces the shared `HeartRateZoneCard` widget for Home specifically,
/// since this screen needs a color-coded zone label plus a "No Signal"
/// state.
class _HeartRateZoneCard extends StatelessWidget {
  const _HeartRateZoneCard({required this.heartRate});

  final HeartRateProvider heartRate;

  Color _zoneColor(BuildContext context, String zone) {
    switch (zone) {
      case 'Low':
        return const Color(0xFF3B82F6);
      case 'Normal':
        return AppColors.normal;
      case 'High':
        return AppColors.murmur;
      case 'Very High':
        return AppColors.arrhythmia;
      default: // 'No Signal'
        return context.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String zone = heartRate.heartRateZone;
    final Color zoneColor = _zoneColor(context, zone);

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
          Text(
            'HEART RATE ZONE',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: zoneColor, width: 3),
                  ),
                  child: Icon(Icons.favorite, color: zoneColor),
                ),
                const SizedBox(height: 8),
                Text(
                  zone,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: zoneColor),
                ),
                Text(
                  '60 - 100 BPM',
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// SpO2 card shown below the BPM/zone row — color-coded by saturation
/// level, showing "--" whenever there's no finger or no reading yet.
class _Spo2Card extends StatelessWidget {
  const _Spo2Card({required this.heartRate});

  final HeartRateProvider heartRate;

  @override
  Widget build(BuildContext context) {
    final double spo2 = heartRate.currentSpo2;
    final bool show = heartRate.isFingerDetected && spo2 > 0;
    final Color color = !show
        ? context.textSecondary
        : spo2 >= 95
            ? AppColors.normal
            : spo2 >= 90
                ? AppColors.murmur
                : AppColors.arrhythmia;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
        boxShadow: context.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.water_drop, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPO2',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  show ? '${spo2.round()}%' : '--',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the AI Analysis cards while no finger is detected.
class _NoFingerCard extends StatelessWidget {
  const _NoFingerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, color: context.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Place finger to start analysis',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Smart Stethoscope',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Heart Sounds. Smart Diagnosis.',
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.notifications_none, color: context.textPrimary),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.heartRate});

  final HeartRateProvider heartRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
        boxShadow: context.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bluetooth, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.normal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'CONNECTED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.normal,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  heartRate.deviceName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Battery: ${heartRate.batteryPercent}%',
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.signal_cellular_alt, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _ControlButtons extends StatelessWidget {
  const _ControlButtons({required this.heartRate});

  final HeartRateProvider heartRate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: heartRate.isRunning ? null : heartRate.start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('START'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: heartRate.isRunning ? heartRate.stop : null,
            icon: const Icon(Icons.stop),
            label: const Text('STOP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.arrhythmia,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              final record = heartRate.captureRecord();
              context.read<RecordsProvider>().addRecord(record);
              heartRate.toggleRecording();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recording saved')),
              );
            },
            icon: Icon(heartRate.isRecording ? Icons.fiber_manual_record : Icons.circle_outlined),
            label: const Text('RECORD'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.recordButton,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      ],
    );
  }
}

class _MlPredictionCard extends StatelessWidget {
  const _MlPredictionCard({required this.heartRate});

  final HeartRateProvider heartRate;

  Color _riskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return AppColors.normal;
      case RiskLevel.medium:
        return AppColors.murmur;
      case RiskLevel.high:
        return AppColors.arrhythmia;
    }
  }

  @override
  Widget build(BuildContext context) {
    final PredictResponse? result = heartRate.predictResult;

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
          Text(
            'ML PREDICTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          if (result == null)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Collecting data...',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _riskColor(result.riskLevel).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    riskLevelLabel(result.riskLevel),
                    style: TextStyle(
                      color: _riskColor(result.riskLevel),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${result.confidence.round()}%',
                  style: TextStyle(
                    color: _riskColor(result.riskLevel),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              result.message,
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Last predicted at ${DateFormat('hh:mm:ss a').format(result.timestamp)}',
              style: TextStyle(fontSize: 11, color: context.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalibrationBanner extends StatefulWidget {
  const _CalibrationBanner();

  @override
  State<_CalibrationBanner> createState() => _CalibrationBannerState();
}

class _CalibrationBannerState extends State<_CalibrationBanner> {
  static const String _dismissedKey = 'calibration_banner_dismissed';

  bool _loaded = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dismissed = prefs.getBool(_dismissedKey) ?? false;
      _loaded = true;
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final double correctionFactor = context.watch<HeartRateProvider>().correctionFactor;
    if (!_loaded || _dismissed || correctionFactor != 1.0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SettingsScreen(scrollToCalibration: true),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tip: Calibrate your device in Settings for more accurate readings',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _dismiss,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, color: AppColors.primary, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
