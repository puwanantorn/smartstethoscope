import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/calibration_data.dart';
import '../providers/heart_rate_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.scrollToCalibration = false});

  /// When true (e.g. reached via the Home screen's calibration tip),
  /// auto-scrolls down to the Calibration section after the first frame.
  final bool scrollToCalibration;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _sound = true;
  bool _vibration = true;
  bool _cloudBackup = true;
  String _units = 'BPM';
  String _language = 'English';
  final GlobalKey _calibrationKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.scrollToCalibration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final BuildContext? target = _calibrationKey.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.05,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final heartRate = context.watch<HeartRateProvider>();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back, color: context.textPrimary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                ],
                const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _SectionLabel('Profile'),
            _SettingsGroup(children: [
              _SettingsTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: 'Tester',
                subtitle: 'Mock Account',
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 20),
            _SectionLabel('Device'),
            _SettingsGroup(children: [
              _SettingsTile(
                leading: const Icon(Icons.bluetooth, color: AppColors.primary),
                title: heartRate.deviceName,
                trailingText: heartRate.isConnected ? 'Connected' : 'Disconnected',
                trailingColor: heartRate.isConnected ? AppColors.normal : AppColors.arrhythmia,
                onTap: () {},
              ),
              _SettingsTile(
                leading: const Icon(Icons.battery_full, color: AppColors.primary),
                title: 'Battery',
                trailingText: '${heartRate.batteryPercent}%',
                onTap: () {},
              ),
              _SettingsTile(
                leading: const Icon(Icons.memory, color: AppColors.primary),
                title: 'Firmware Version',
                trailingText: 'v1.2.3',
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 12),
            Column(
              key: _calibrationKey,
              children: const [
                _CalibrationGuideSection(),
                SizedBox(height: 12),
                _CalibrationSection(),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel('App Settings'),
            _SettingsGroup(children: [
              _SettingsTile(
                leading: const Icon(Icons.straighten, color: AppColors.primary),
                title: 'Units',
                trailingText: _units,
                onTap: () => _showOptionPicker(
                  title: 'Units',
                  options: const ['BPM'],
                  current: _units,
                  onSelected: (v) => setState(() => _units = v),
                ),
              ),
              _SettingsSwitchTile(
                leading: const Icon(Icons.volume_up_outlined, color: AppColors.primary),
                title: 'Sound',
                value: _sound,
                onChanged: (v) => setState(() => _sound = v),
              ),
              _SettingsSwitchTile(
                leading: const Icon(Icons.vibration, color: AppColors.primary),
                title: 'Vibration',
                value: _vibration,
                onChanged: (v) => setState(() => _vibration = v),
              ),
              _SettingsSwitchTile(
                leading: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
                title: 'Dark Mode',
                value: context.watch<ThemeProvider>().isDarkMode,
                onChanged: (v) => context.read<ThemeProvider>().setDarkMode(v),
              ),
              _SettingsTile(
                leading: const Icon(Icons.language, color: AppColors.primary),
                title: 'Language',
                trailingText: _language,
                onTap: () => _showOptionPicker(
                  title: 'Language',
                  options: const ['English', 'ไทย'],
                  current: _language,
                  onSelected: (v) => setState(() => _language = v),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _SectionLabel('Data & Storage'),
            _SettingsGroup(children: [
              _SettingsSwitchTile(
                leading: const Icon(Icons.cloud_outlined, color: AppColors.primary),
                title: 'Cloud Backup',
                value: _cloudBackup,
                onChanged: (v) => setState(() => _cloudBackup = v),
              ),
              _SettingsTile(
                leading: const Icon(Icons.storage_outlined, color: AppColors.primary),
                title: 'Manage Storage',
                trailingText: '2.4 GB Used',
                onTap: () {},
              ),
              _SettingsTile(
                leading: const Icon(Icons.ios_share, color: AppColors.primary),
                title: 'Export Data',
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 20),
            _SectionLabel('Support'),
            _SettingsGroup(children: [
              _SettingsTile(leading: const Icon(Icons.menu_book_outlined, color: AppColors.primary), title: 'User Guide', onTap: () {}),
              _SettingsTile(leading: const Icon(Icons.help_outline, color: AppColors.primary), title: 'FAQ', onTap: () {}),
              _SettingsTile(leading: const Icon(Icons.mail_outline, color: AppColors.primary), title: 'Contact Us', onTap: () {}),
            ]),
            const SizedBox(height: 20),
            _SectionLabel('About'),
            _SettingsGroup(children: [
              _SettingsTile(
                leading: const Icon(Icons.info_outline, color: AppColors.primary),
                title: 'Smart Stethoscope App',
                trailingText: 'Version 1.0.0',
                onTap: () {},
              ),
              _SettingsTile(leading: const Icon(Icons.description_outlined, color: AppColors.primary), title: 'Terms of Use', onTap: () {}),
              _SettingsTile(leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary), title: 'Privacy Policy', onTap: () {}),
            ]),
          ],
        ),
      ),
    );
  }

  void _showOptionPicker({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            for (final option in options)
              ListTile(
                title: Text(option),
                trailing: option == current ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  onSelected(option);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, indent: 52, color: context.cardBorder),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailingColor,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Color? trailingColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: leading,
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              Text(
                trailingText!,
                style: TextStyle(fontSize: 13, color: trailingColor ?? context.textSecondary),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: context.textSecondary, size: 18),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.leading,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final Widget leading;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: leading,
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ),
    );
  }
}

class _CalibrationSection extends StatefulWidget {
  const _CalibrationSection();

  @override
  State<_CalibrationSection> createState() => _CalibrationSectionState();
}

class _CalibrationSectionState extends State<_CalibrationSection> {
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _actualBpmController = TextEditingController();
  final TextEditingController _measuredBpmController = TextEditingController();
  Gender _gender = Gender.male;
  Finger _finger = Finger.indexFinger;
  bool _saving = false;

  @override
  void dispose() {
    _ageController.dispose();
    _actualBpmController.dispose();
    _measuredBpmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final int? age = int.tryParse(_ageController.text.trim());
    final double? actualBpm = double.tryParse(_actualBpmController.text.trim());
    final double? measuredBpm = double.tryParse(_measuredBpmController.text.trim());

    if (age == null || actualBpm == null || measuredBpm == null || measuredBpm == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in Age, Actual BPM, and Measured BPM with valid numbers.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final bool success = await context.read<HeartRateProvider>().saveCalibration(
          age: age,
          gender: _gender,
          finger: _finger,
          actualBpm: actualBpm,
          measuredBpm: measuredBpm,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Calibration saved!' : 'Failed to save')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CalibrationData? calibration = context.watch<HeartRateProvider>().calibration;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CALIBRATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Age',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Gender>(
            initialValue: _gender,
            decoration: InputDecoration(
              labelText: 'Gender',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: <DropdownMenuItem<Gender>>[
              for (final Gender g in Gender.values)
                DropdownMenuItem(value: g, child: Text(genderLabel(g))),
            ],
            onChanged: (Gender? value) {
              if (value != null) setState(() => _gender = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Finger>(
            initialValue: _finger,
            decoration: InputDecoration(
              labelText: 'Finger used',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: <DropdownMenuItem<Finger>>[
              for (final Finger f in Finger.values)
                DropdownMenuItem(value: f, child: Text(fingerLabel(f))),
            ],
            onChanged: (Finger? value) {
              if (value != null) setState(() => _finger = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _actualBpmController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Actual BPM',
              helperText: 'Count your pulse manually for 30 sec × 2',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _measuredBpmController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Measured BPM',
              helperText: 'Current BPM shown by the sensor',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Calibration'),
            ),
          ),
          if (calibration != null) ...[
            const SizedBox(height: 12),
            Text(
              'Correction factor: ${calibration.correctionFactor.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (calibration.updatedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last updated: ${DateFormat('MMM d, yyyy hh:mm a').format(calibration.updatedAt!)}',
                style: TextStyle(fontSize: 11, color: context.textSecondary),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep({required this.icon, required this.title, required this.details});

  final IconData icon;
  final String title;
  final List<String> details;
}

const List<_GuideStep> _calibrationGuideSteps = [
  _GuideStep(
    icon: Icons.pan_tool_outlined,
    title: 'Step 1: Prepare',
    details: [
      'Place your index finger firmly on the sensor',
      'Stay still for 15 seconds until BPM stabilizes',
    ],
  ),
  _GuideStep(
    icon: Icons.visibility_outlined,
    title: 'Step 2: Note the sensor reading',
    details: [
      'Write down the BPM shown on the Home screen',
      'Enter it in "Measured BPM" field below',
    ],
  ),
  _GuideStep(
    icon: Icons.favorite_border,
    title: 'Step 3: Count your real pulse',
    details: [
      'Use your other hand to feel pulse at your wrist',
      'Count beats for 30 seconds then multiply by 2',
      'Enter this number in "Actual BPM" field below',
    ],
  ),
  _GuideStep(
    icon: Icons.save_outlined,
    title: 'Step 4: Save & Reset',
    details: [
      'Tap "Save Calibration"',
      'Restart your ESP32 device to apply changes',
      'BPM readings will now be more accurate',
    ],
  ),
];

class _CalibrationGuideSection extends StatefulWidget {
  const _CalibrationGuideSection();

  @override
  State<_CalibrationGuideSection> createState() => _CalibrationGuideSectionState();
}

class _CalibrationGuideSectionState extends State<_CalibrationGuideSection> {
  // null = follow the calibration status automatically; once the user taps
  // the header this locks to their explicit choice instead.
  bool? _manualExpanded;

  @override
  Widget build(BuildContext context) {
    // Reactive rather than decided once in initState: calibration loads
    // asynchronously from the backend, so a one-time snapshot would almost
    // always see "not calibrated yet" and stay expanded even for users who
    // already have a saved calibration.
    final bool hasCalibration = context.watch<HeartRateProvider>().calibration != null;
    final bool expanded = _manualExpanded ?? !hasCalibration;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _manualExpanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.help_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'How to Calibrate?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, color: context.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < _calibrationGuideSteps.length; i++) ...[
                    if (i > 0) Divider(height: 20, color: context.cardBorder),
                    _GuideStepTile(step: _calibrationGuideSteps[i]),
                  ],
                ],
              ),
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

class _GuideStepTile extends StatelessWidget {
  const _GuideStepTile({required this.step});

  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(step.icon, color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              for (final String detail in step.details)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '•  $detail',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
