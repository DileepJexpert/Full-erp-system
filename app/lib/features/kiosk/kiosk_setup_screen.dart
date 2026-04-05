import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../core/auth/auth_provider.dart';
import 'kiosk_provider.dart';
import 'kiosk_feedback_screen.dart';

class KioskSetupScreen extends ConsumerStatefulWidget {
  const KioskSetupScreen({super.key});

  @override
  ConsumerState<KioskSetupScreen> createState() => _KioskSetupScreenState();
}

class _KioskSetupScreenState extends ConsumerState<KioskSetupScreen> {
  String? _selectedLocationId;
  String _selectedLocationName = '';
  final _pinController = TextEditingController();
  KioskDisplayMode _displayMode = KioskDisplayMode.simple;
  bool _showBilingual = true;
  double _autoResetSec = 8;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  String get _displayModeLabel {
    switch (_displayMode) {
      case KioskDisplayMode.simple:
        return 'Simple (Rating Only)';
      case KioskDisplayMode.withComment:
        return 'With Comment';
      case KioskDisplayMode.withTags:
        return 'With Tags';
    }
  }

  Future<void> _startKioskMode() async {
    if (_selectedLocationId == null || _selectedLocationId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }
    if (_pinController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 4-digit PIN')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final auth = ref.read(authProvider);
    final businessName = auth.user?.businessName ?? 'Business';
    final deviceId =
        'kiosk_${_selectedLocationId}_${DateTime.now().millisecondsSinceEpoch}';

    // Attempt kiosk auth
    final authenticate = ref.read(kioskAuthProvider);
    final success = await authenticate(
      locationId: _selectedLocationId!,
      deviceId: deviceId,
    );

    final config = KioskConfig(
      locationId: _selectedLocationId!,
      locationName: _selectedLocationName,
      businessName: businessName,
      displayMode: _displayMode,
      autoResetSec: _autoResetSec.round(),
      showBilingual: _showBilingual,
      pin: _pinController.text,
      deviceId: deviceId,
      kioskToken: success
          ? ref.read(kioskConfigProvider).kioskToken
          : '',
    );

    await ref.read(kioskConfigProvider.notifier).saveAndPersist(config);

    if (!mounted) return;

    // Go full screen immersive
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Navigate to kiosk feedback screen, removing all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const _KioskFeedbackLauncher()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(locationsListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Feedback Kiosk'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.touch_app, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'Feedback Kiosk',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set up a tablet as a feedback terminal for customers',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Location dropdown
            Text('Select Location',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            locationsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load locations: $e'),
              data: (locations) {
                return DropdownButtonFormField<String>(
                  value: _selectedLocationId,
                  decoration: const InputDecoration(
                    hintText: 'Choose a location',
                    prefixIcon: Icon(Icons.store),
                  ),
                  items: locations
                      .map((loc) => DropdownMenuItem(
                            value: (loc['id'] ?? loc['_id'] ?? '').toString(),
                            child: Text(loc['name']?.toString() ?? 'Unknown'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedLocationId = val;
                      _selectedLocationName = locations
                              .firstWhere(
                                (l) =>
                                    (l['id'] ?? l['_id']).toString() == val,
                                orElse: () => {'name': ''},
                              )['name']
                              ?.toString() ??
                          '';
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // PIN
            Text('Exit PIN (4 digits)',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Enter 4-digit PIN to lock kiosk',
                prefixIcon: Icon(Icons.lock),
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),

            // Display Mode
            Text('Display Mode',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<KioskDisplayMode>(
              value: _displayMode,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.display_settings),
              ),
              items: const [
                DropdownMenuItem(
                  value: KioskDisplayMode.simple,
                  child: Text('Simple (Rating Only)'),
                ),
                DropdownMenuItem(
                  value: KioskDisplayMode.withComment,
                  child: Text('With Comment'),
                ),
                DropdownMenuItem(
                  value: KioskDisplayMode.withTags,
                  child: Text('With Tags'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _displayMode = val);
              },
            ),
            const SizedBox(height: 24),

            // Bilingual switch
            Card(
              child: SwitchListTile(
                title: const Text('Show Bilingual (Hindi + English)'),
                subtitle: const Text('Display text in both languages'),
                secondary: const Icon(Icons.translate),
                value: _showBilingual,
                onChanged: (val) => setState(() => _showBilingual = val),
              ),
            ),
            const SizedBox(height: 24),

            // Auto-reset slider
            Text('Auto-reset Timer: ${_autoResetSec.round()} seconds',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Slider(
              value: _autoResetSec,
              min: 5,
              max: 15,
              divisions: 10,
              label: '${_autoResetSec.round()}s',
              onChanged: (val) => setState(() => _autoResetSec = val),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5s', style: theme.textTheme.labelSmall),
                Text('15s', style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 32),

            // Preview section
            Text('Preview',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D27),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    _selectedLocationName.isEmpty
                        ? 'Your Location'
                        : _selectedLocationName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'How was your experience today?',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  if (_showBilingual) ...[
                    const SizedBox(height: 4),
                    Text(
                      '\u0906\u091C \u0915\u093E \u0905\u0928\u0941\u092D\u0935 \u0915\u0948\u0938\u093E \u0930\u0939\u093E?',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text('\uD83D\uDE21', style: TextStyle(fontSize: 32)),
                      Text('\uD83D\uDE15', style: TextStyle(fontSize: 32)),
                      Text('\uD83D\uDE10', style: TextStyle(fontSize: 32)),
                      Text('\uD83D\uDE0A', style: TextStyle(fontSize: 32)),
                      Text('\uD83E\uDD29', style: TextStyle(fontSize: 32)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _displayModeLabel,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Start button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _startKioskMode,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 28),
                label: Text(
                  _isLoading ? 'Starting...' : 'Start Kiosk Mode',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'The device will enter full-screen kiosk mode.\n'
                'Use the PIN to exit.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Launcher widget that navigates to the actual kiosk feedback screen.
class _KioskFeedbackLauncher extends StatelessWidget {
  const _KioskFeedbackLauncher();

  @override
  Widget build(BuildContext context) {
    return const KioskFeedbackScreen();
  }
}
