import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_provider.dart';

/// Voice/text entry screen for purchase input.
///
/// Provides a large text field where the operator can type or paste a
/// transcript (e.g. "10 kg rice at 45, 5 kg sugar at 40"). A mic icon
/// hints at future speech-to-text integration.
class VoiceEntryScreen extends ConsumerStatefulWidget {
  const VoiceEntryScreen({super.key});

  @override
  ConsumerState<VoiceEntryScreen> createState() => _VoiceEntryScreenState();
}

class _VoiceEntryScreenState extends ConsumerState<VoiceEntryScreen> {
  final _controller = TextEditingController();
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _process() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please enter or dictate the purchase details');
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/purchases/parse-voice', data: {
        'transcript': text,
      });
      final data = response.data as Map<String, dynamic>;
      final extracted = data['data'] as Map<String, dynamic>;
      extracted['entryMethod'] = 'VOICE';

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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Entry'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppTheme.infoColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Type or paste what was purchased. Example:\n"10 kg rice at 45, 5 kg sugar at 40 from Krishna Traders"',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppTheme.infoColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Mic icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _processing
                      ? Colors.red.shade50
                      : AppTheme.primaryColor.withOpacity(0.1),
                ),
                child: Icon(
                  _processing ? Icons.mic : Icons.mic_none,
                  size: 40,
                  color:
                      _processing ? AppTheme.errorColor : AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Text input
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText:
                      'Type purchase details here...\n\ne.g. "10 kg rice 45 rs, 5 kg sugar 40 rs, 2 litre oil 120 rs from ABC Traders"',
                  border: const OutlineInputBorder(),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
              ),
            ],

            const SizedBox(height: 16),

            // Process button
            FilledButton.icon(
              onPressed: _processing || _controller.text.trim().isEmpty
                  ? null
                  : _process,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_fix_high),
              label:
                  Text(_processing ? 'Processing...' : 'Process & Review'),
            ),
          ],
        ),
      ),
    );
  }
}
