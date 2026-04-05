import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';

/// Bottom-sheet widget with the four primary purchase-entry methods.
///
/// Call [PurchaseEntrySelector.show] to present it as a modal.
class PurchaseEntrySelector extends StatelessWidget {
  const PurchaseEntrySelector({super.key});

  /// Show the selector as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PurchaseEntrySelector(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'New Purchase Entry',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            // 2x2 grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _EntryCard(
                  icon: Icons.camera_alt,
                  label: 'Scan Bill',
                  color: AppTheme.primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/purchases/scan');
                  },
                ),
                _EntryCard(
                  icon: Icons.replay,
                  label: 'Repeat Last',
                  color: AppTheme.secondaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/purchases/repeat');
                  },
                ),
                _EntryCard(
                  icon: Icons.mic,
                  label: 'Voice Entry',
                  color: AppTheme.infoColor,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/purchases/voice');
                  },
                ),
                _EntryCard(
                  icon: Icons.edit_note,
                  label: 'Manual Entry',
                  color: AppTheme.successColor,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/suppliers/purchase');
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Barcode link
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push('/purchases/barcode');
              },
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Scan Barcode'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _EntryCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
