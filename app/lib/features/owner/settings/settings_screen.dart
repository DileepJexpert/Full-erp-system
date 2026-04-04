import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/error_view.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _editing = false;
  bool _saving = false;

  late TextEditingController _businessNameCtrl;
  late TextEditingController _gstCtrl;
  late TextEditingController _upiIdCtrl;
  late TextEditingController _upiPayeeCtrl;

  @override
  void initState() {
    super.initState();
    _businessNameCtrl = TextEditingController();
    _gstCtrl = TextEditingController();
    _upiIdCtrl = TextEditingController();
    _upiPayeeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _gstCtrl.dispose();
    _upiIdCtrl.dispose();
    _upiPayeeCtrl.dispose();
    super.dispose();
  }

  void _populateControllers(BusinessSettings s) {
    _businessNameCtrl.text = s.businessName;
    _gstCtrl.text = s.gstNumber;
    _upiIdCtrl.text = s.upiId;
    _upiPayeeCtrl.text = s.upiPayeeName;
  }

  void _startEditing(BusinessSettings settings) {
    _populateControllers(settings);
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    setState(() => _editing = false);
  }

  Future<void> _save() async {
    final current = ref.read(settingsProvider).valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(
      businessName: _businessNameCtrl.text.trim(),
      gstNumber: _gstCtrl.text.trim(),
      upiId: _upiIdCtrl.text.trim(),
      upiPayeeName: _upiPayeeCtrl.text.trim(),
    );

    ref.read(settingsProvider.notifier).updateLocal(updated);
    setState(() => _saving = true);

    final success = await ref.read(settingsProvider.notifier).save();

    if (mounted) {
      setState(() {
        _saving = false;
        if (success) _editing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Settings saved' : 'Failed to save settings'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LoadingSkeleton(width: 200, height: 32),
            const SizedBox(height: 24),
            ...List.generate(4, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LoadingSkeleton.card(),
            )),
          ],
        ),
      ),
      error: (err, _) => ErrorView(
        message: err.toString(),
        onRetry: () => ref.read(settingsProvider.notifier).reload(),
      ),
      data: (settings) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business Settings',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your business configuration',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (!_editing)
                  FilledButton.icon(
                    onPressed: () => _startEditing(settings),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  )
                else
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _saving ? null : _cancelEditing,
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save, size: 18),
                        label: Text(_saving ? 'Saving...' : 'Save'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Business Profile
            _SectionCard(
              title: 'Business Profile',
              icon: Icons.business,
              children: [
                _SettingsField(
                  label: 'Business Name',
                  value: settings.businessName,
                  controller: _businessNameCtrl,
                  editing: _editing,
                ),
                const Divider(height: 1),
                _SettingsField(
                  label: 'GST Number',
                  value: settings.gstNumber.isEmpty ? 'Not set' : settings.gstNumber,
                  controller: _gstCtrl,
                  editing: _editing,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          'Logo',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                        ),
                      ),
                      if (settings.logoUrl != null && settings.logoUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            settings.logoUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.image, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.image, color: Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Feature Flags
            _SectionCard(
              title: 'Feature Flags',
              icon: Icons.toggle_on_outlined,
              children: [
                if (settings.featureFlags.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No feature flags configured',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF94A3B8)),
                    ),
                  )
                else
                  ...settings.featureFlags.entries.map((entry) {
                    return SwitchListTile(
                      title: Text(_humanizeKey(entry.key)),
                      value: entry.value,
                      onChanged: _editing
                          ? (val) {
                              final updated = Map<String, bool>.from(settings.featureFlags);
                              updated[entry.key] = val;
                              ref.read(settingsProvider.notifier).updateLocal(
                                    settings.copyWith(featureFlags: updated),
                                  );
                            }
                          : null,
                    );
                  }),
              ],
            ),
            const SizedBox(height: 16),

            // UPI Settings
            _SectionCard(
              title: 'UPI Settings',
              icon: Icons.payment,
              children: [
                _SettingsField(
                  label: 'UPI ID',
                  value: settings.upiId.isEmpty ? 'Not set' : settings.upiId,
                  controller: _upiIdCtrl,
                  editing: _editing,
                ),
                const Divider(height: 1),
                _SettingsField(
                  label: 'Payee Name',
                  value: settings.upiPayeeName.isEmpty ? 'Not set' : settings.upiPayeeName,
                  controller: _upiPayeeCtrl,
                  editing: _editing,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notification Preferences
            _SectionCard(
              title: 'Notification Preferences',
              icon: Icons.notifications_outlined,
              children: [
                SwitchListTile(
                  title: const Text('All Alerts'),
                  subtitle: const Text('Enable or disable all alert notifications'),
                  value: settings.notificationPreferences.alertsEnabled,
                  onChanged: _editing
                      ? (val) {
                          ref.read(settingsProvider.notifier).updateLocal(
                                settings.copyWith(
                                  notificationPreferences:
                                      settings.notificationPreferences.copyWith(alertsEnabled: val),
                                ),
                              );
                        }
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Daily Summary'),
                  subtitle: const Text('Receive daily business summary'),
                  value: settings.notificationPreferences.dailySummary,
                  onChanged: _editing
                      ? (val) {
                          ref.read(settingsProvider.notifier).updateLocal(
                                settings.copyWith(
                                  notificationPreferences:
                                      settings.notificationPreferences.copyWith(dailySummary: val),
                                ),
                              );
                        }
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Cash Alerts'),
                  subtitle: const Text('Cash mismatch and shortage alerts'),
                  value: settings.notificationPreferences.cashAlerts,
                  onChanged: _editing
                      ? (val) {
                          ref.read(settingsProvider.notifier).updateLocal(
                                settings.copyWith(
                                  notificationPreferences:
                                      settings.notificationPreferences.copyWith(cashAlerts: val),
                                ),
                              );
                        }
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Wastage Alerts'),
                  subtitle: const Text('High wastage notifications'),
                  value: settings.notificationPreferences.wastageAlerts,
                  onChanged: _editing
                      ? (val) {
                          ref.read(settingsProvider.notifier).updateLocal(
                                settings.copyWith(
                                  notificationPreferences:
                                      settings.notificationPreferences.copyWith(wastageAlerts: val),
                                ),
                              );
                        }
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Attendance Alerts'),
                  subtitle: const Text('Late opening and attendance issues'),
                  value: settings.notificationPreferences.attendanceAlerts,
                  onChanged: _editing
                      ? (val) {
                          ref.read(settingsProvider.notifier).updateLocal(
                                settings.copyWith(
                                  notificationPreferences:
                                      settings.notificationPreferences.copyWith(attendanceAlerts: val),
                                ),
                              );
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _humanizeKey(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final String label;
  final String value;
  final TextEditingController controller;
  final bool editing;

  const _SettingsField({
    required this.label,
    required this.value,
    required this.controller,
    required this.editing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: editing
                ? TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                : Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
          ),
        ],
      ),
    );
  }
}
