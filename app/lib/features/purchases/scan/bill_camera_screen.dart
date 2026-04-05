import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_provider.dart';

class BillCameraScreen extends ConsumerStatefulWidget {
  const BillCameraScreen({super.key});

  @override
  ConsumerState<BillCameraScreen> createState() => _BillCameraScreenState();
}

class _BillCameraScreenState extends ConsumerState<BillCameraScreen> {
  final _picker = ImagePicker();
  bool _processing = false;
  String? _error;

  Future<void> _captureAndScan() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (photo == null) return;

      setState(() {
        _processing = true;
        _error = null;
      });

      final bytes = await File(photo.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      final api = ref.read(apiClientProvider);
      final response = await api.post('/purchases/scan-bill', data: {
        'image': base64Image,
      });
      final data = response.data as Map<String, dynamic>;
      final extracted = data['data'] as Map<String, dynamic>;

      if (!mounted) return;
      context.push('/purchases/scan/review', extra: extracted);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Scan Bill'),
      ),
      body: Stack(
        children: [
          // Main content
          Center(
            child: _processing
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        'Reading bill...',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Extracting items and prices',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Take a photo of the bill',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We will extract items, quantities,\nand prices automatically',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppTheme.errorColor),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),

          // Camera button at bottom
          if (!_processing)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton.large(
                  heroTag: 'bill_camera',
                  onPressed: _captureAndScan,
                  backgroundColor: AppTheme.primaryColor,
                  child: const Icon(Icons.camera_alt, size: 36, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
