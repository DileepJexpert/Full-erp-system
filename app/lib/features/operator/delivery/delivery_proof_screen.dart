import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';

// ── Providers ──────────────────────────────────────────────────

final deliveryDetailsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/delivery/current');
  return response.data as Map<String, dynamic>;
});

final gpsLocationProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  // In a real app, this would use geolocator plugin
  // Returning placeholder that the backend can replace with actual GPS
  return {'lat': 0.0, 'lng': 0.0};
});

// ── Screen ─────────────────────────────────────────────────────

class DeliveryProofScreen extends ConsumerStatefulWidget {
  const DeliveryProofScreen({super.key});

  @override
  ConsumerState<DeliveryProofScreen> createState() =>
      _DeliveryProofScreenState();
}

class _DeliveryProofScreenState extends ConsumerState<DeliveryProofScreen> {
  final _receiverNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _photoPath;
  bool _submitting = false;
  final GlobalKey<_SignaturePadState> _signatureKey =
      GlobalKey<_SignaturePadState>();

  @override
  void dispose() {
    _receiverNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    // In a real app, this would use image_picker
    // For now, simulate photo capture
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/delivery/capture-photo');
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _photoPath = data['photoUrl'] ?? data['path'] ?? 'photo_captured';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo captured'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _submitProof() async {
    if (_receiverNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter receiver name'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final gps = await ref.read(gpsLocationProvider.future);
      final hasSignature = _signatureKey.currentState?.hasSignature ?? false;

      await api.post('/delivery/proof', data: {
        'receiverName': _receiverNameCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'photoPath': _photoPath,
        'hasSignature': hasSignature,
        'gpsLat': gps['lat'],
        'gpsLng': gps['lng'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery proof submitted successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveryAsync = ref.watch(deliveryDetailsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Proof'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dispatch/Order details
            deliveryAsync.when(
              loading: () => const LoadingSkeleton(height: 120),
              error: (err, _) => ErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(deliveryDetailsProvider),
              ),
              data: (details) => _OrderDetailsCard(details: details),
            ),
            const SizedBox(height: 20),

            // Photo section
            Text(
              'Photo of Delivered Items',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 120,
              child: OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: Icon(
                  _photoPath != null ? Icons.check_circle : Icons.camera_alt,
                  size: 32,
                  color: _photoPath != null
                      ? const Color(0xFF16A34A)
                      : null,
                ),
                label: Text(
                  _photoPath != null ? 'Photo Captured' : 'Take Photo',
                  style: TextStyle(
                    fontSize: 16,
                    color: _photoPath != null
                        ? const Color(0xFF16A34A)
                        : null,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: _photoPath != null
                        ? const Color(0xFF16A34A)
                        : Theme.of(context).colorScheme.outline,
                    width: _photoPath != null ? 2 : 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Signature section
            Text(
              'Customer Signature',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _SignaturePad(key: _signatureKey),
            const SizedBox(height: 20),

            // Receiver name
            TextField(
              controller: _receiverNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Receiver Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_outlined),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 8),

            // GPS indicator
            Row(
              children: [
                Icon(Icons.gps_fixed,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'GPS location will be auto-captured',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submitProof,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_submitting ? 'Submitting...' : 'Submit Proof'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Order Details Card ─────────────────────────────────────────

class _OrderDetailsCard extends StatelessWidget {
  final Map<String, dynamic> details;

  const _OrderDetailsCard({required this.details});

  @override
  Widget build(BuildContext context) {
    final orderNum =
        details['orderNumber'] ?? details['dispatchNumber'] ?? details['id'] ?? '-';
    final customer = details['customerName'] ?? details['customer'] ?? '-';
    final address = details['address'] ?? details['deliveryAddress'] ?? '-';
    final items =
        (details['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final total = (details['total'] ?? details['amount'] ?? 0).toDouble();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Order #$orderNum',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(customer),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const Divider(height: 16),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['name'] ?? item['itemName'] ?? '-',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          'x${item['qty'] ?? item['quantity'] ?? 1}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )),
            ],
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Total: ${formatRupee(total)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Signature Pad ──────────────────────────────────────────────

class _SignaturePad extends StatefulWidget {
  const _SignaturePad({super.key});

  @override
  _SignaturePadState createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  bool get hasSignature => _strokes.isNotEmpty;

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Stack(
        children: [
          GestureDetector(
            onPanStart: (details) {
              setState(() {
                _currentStroke = [details.localPosition];
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _currentStroke.add(details.localPosition);
              });
            },
            onPanEnd: (details) {
              setState(() {
                _strokes.add(List.from(_currentStroke));
                _currentStroke = [];
              });
            },
            child: CustomPaint(
              size: const Size(double.infinity, 180),
              painter: _SignaturePainter(
                strokes: _strokes,
                currentStroke: _currentStroke,
              ),
            ),
          ),
          if (_strokes.isEmpty && _currentStroke.isEmpty)
            const Center(
              child: Text(
                'Sign here',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: _clear,
              tooltip: 'Clear signature',
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _SignaturePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    if (currentStroke.length >= 2) {
      final path = Path()
        ..moveTo(currentStroke.first.dx, currentStroke.first.dy);
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
