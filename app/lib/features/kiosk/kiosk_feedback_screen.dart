import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'kiosk_provider.dart';

// ─── Tag Labels (bilingual) ─────────────────────────────────

const _tagLabels = <String, Map<String, String>>{
  'slow_service': {'en': 'Slow Service', 'hi': '\u0927\u0940\u092E\u0940 \u0938\u0947\u0935\u093E', 'emoji': '\uD83D\uDC0C'},
  'bad_quality': {'en': 'Bad Quality', 'hi': '\u0916\u0930\u093E\u092C \u0917\u0941\u0923\u0935\u0924\u094D\u0924\u093E', 'emoji': '\uD83D\uDC4E'},
  'rude_staff': {'en': 'Rude Staff', 'hi': '\u092C\u0926\u0924\u092E\u0940\u091C\u093C \u0938\u094D\u091F\u093E\u092B', 'emoji': '\uD83D\uDE24'},
  'wrong_order': {'en': 'Wrong Order', 'hi': '\u0917\u0932\u0924 \u0911\u0930\u094D\u0921\u0930', 'emoji': '\u274C'},
  'not_clean': {'en': 'Not Clean', 'hi': '\u0938\u093E\u092B \u0928\u0939\u0940\u0902', 'emoji': '\uD83E\uDDF9'},
  'overpriced': {'en': 'Overpriced', 'hi': '\u092E\u0939\u0902\u0917\u093E', 'emoji': '\uD83D\uDCB0'},
  'tasty_food': {'en': 'Tasty Food', 'hi': '\u0938\u094D\u0935\u093E\u0926\u093F\u0937\u094D\u091F', 'emoji': '\uD83D\uDE0B'},
  'fast_service': {'en': 'Fast Service', 'hi': '\u0924\u0947\u091C\u093C \u0938\u0947\u0935\u093E', 'emoji': '\u26A1'},
  'friendly_staff': {'en': 'Friendly Staff', 'hi': '\u0905\u091A\u094D\u091B\u093E \u0938\u094D\u091F\u093E\u092B', 'emoji': '\uD83D\uDE0A'},
  'clean_place': {'en': 'Clean Place', 'hi': '\u0938\u093E\u092B \u091C\u0917\u0939', 'emoji': '\u2728'},
  'good_value': {'en': 'Good Value', 'hi': '\u092A\u0948\u0938\u093E \u0935\u0938\u0942\u0932', 'emoji': '\uD83D\uDC8E'},
  'will_recommend': {'en': 'Will Recommend', 'hi': '\u0938\u093F\u092B\u093E\u0930\u093F\u0936 \u0915\u0930\u0942\u0902\u0917\u093E', 'emoji': '\uD83D\uDC4D'},
};

// ─── Rating Emojis ──────────────────────────────────────────

const _ratingEmojis = [
  {'emoji': '\uD83D\uDE21', 'label': 'Terrible', 'hi': '\u092C\u0939\u0941\u0924 \u0916\u0930\u093E\u092C', 'color': 0xFFEF4444},
  {'emoji': '\uD83D\uDE15', 'label': 'Bad', 'hi': '\u0916\u0930\u093E\u092C', 'color': 0xFFF97316},
  {'emoji': '\uD83D\uDE10', 'label': 'OK', 'hi': '\u0920\u0940\u0915', 'color': 0xFFFBBF24},
  {'emoji': '\uD83D\uDE0A', 'label': 'Good', 'hi': '\u0905\u091A\u094D\u091B\u093E', 'color': 0xFF84CC16},
  {'emoji': '\uD83E\uDD29', 'label': 'Amazing', 'hi': '\u092C\u0939\u0941\u0924 \u0905\u091A\u094D\u091B\u093E', 'color': 0xFF22C55E},
];

// ─── Kiosk Feedback Screen ──────────────────────────────────

class KioskFeedbackScreen extends ConsumerStatefulWidget {
  const KioskFeedbackScreen({super.key});

  @override
  ConsumerState<KioskFeedbackScreen> createState() => _KioskFeedbackScreenState();
}

enum _KioskPhase { rating, phase2, thankYou }

class _KioskFeedbackScreenState extends ConsumerState<KioskFeedbackScreen>
    with TickerProviderStateMixin {
  _KioskPhase _phase = _KioskPhase.rating;
  int? _selectedRating;
  final Set<String> _selectedTags = {};
  final _commentController = TextEditingController();
  Timer? _autoResetTimer;
  int _logoTapCount = 0;
  DateTime? _lastLogoTap;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _autoResetTimer?.cancel();
    _commentController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _resetToPhase1() {
    _autoResetTimer?.cancel();
    setState(() {
      _phase = _KioskPhase.rating;
      _selectedRating = null;
      _selectedTags.clear();
      _commentController.clear();
    });
    _fadeController.reset();
    _fadeController.forward();
  }

  void _startAutoReset() {
    _autoResetTimer?.cancel();
    final config = ref.read(kioskConfigProvider);
    _autoResetTimer = Timer(
      Duration(seconds: config.autoResetSec),
      _resetToPhase1,
    );
  }

  void _onRatingTap(int rating) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedRating = rating;
    });

    _scaleController.reset();
    _scaleController.forward();

    // Determine phase 2 behavior
    final config = ref.read(kioskConfigProvider);
    final mode = config.displayMode;

    if (mode == KioskDisplayMode.simple) {
      _submitAndThank();
    } else {
      // Transition to phase 2
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _fadeController.reset();
        _fadeController.forward();
        setState(() => _phase = _KioskPhase.phase2);
        _startAutoReset();
      });
    }
  }

  void _submitAndThank() {
    final rating = _selectedRating;
    if (rating == null) return;

    // Fire-and-forget API call
    final submit = ref.read(submitFeedbackProvider);
    submit(
      rating: rating,
      comment: _commentController.text.isNotEmpty ? _commentController.text : null,
      tags: _selectedTags.isNotEmpty ? _selectedTags.toList() : null,
    );

    _fadeController.reset();
    _fadeController.forward();
    setState(() => _phase = _KioskPhase.thankYou);

    // Auto-reset after thank you
    _autoResetTimer?.cancel();
    _autoResetTimer = Timer(const Duration(seconds: 3), _resetToPhase1);
  }

  void _handleLogoTap() {
    final now = DateTime.now();
    if (_lastLogoTap != null && now.difference(_lastLogoTap!).inSeconds > 3) {
      _logoTapCount = 0;
    }
    _lastLogoTap = now;
    _logoTapCount++;

    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      _showExitDialog();
    }
  }

  void _showExitDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Kiosk Mode'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: 'Enter 4-digit PIN',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final config = ref.read(kioskConfigProvider);
              if (pinController.text == config.pin) {
                Navigator.of(ctx).pop();
                _exitKioskMode();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect PIN')),
                );
              }
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  void _exitKioskMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Navigate back to the app's main route
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(kioskConfigProvider);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1D27),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // Header with business name + kiosk lock
              _buildHeader(config),
              // Main content
              Expanded(
                child: Center(
                  child: _phase == _KioskPhase.rating
                      ? _buildRatingPhase(config, isLandscape)
                      : _phase == _KioskPhase.phase2
                          ? _buildPhase2(config, isLandscape)
                          : _buildThankYou(config),
                ),
              ),
              // Footer
              _buildFooter(config),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(KioskConfig config) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Logo area (5-tap to exit)
          GestureDetector(
            onTap: _handleLogoTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.store, color: Color(0xFF2563EB), size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.locationName.isNotEmpty ? config.locationName : 'Feedback',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (config.businessName.isNotEmpty)
                  Text(
                    config.businessName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingPhase(KioskConfig config, bool isLandscape) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'How was your experience today?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: isLandscape ? 26 : 24,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          if (config.showBilingual) ...[
            const SizedBox(height: 6),
            Text(
              '\u0906\u091C \u0915\u093E \u0905\u0928\u0941\u092D\u0935 \u0915\u0948\u0938\u093E \u0930\u0939\u093E?',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: isLandscape ? 20 : 18,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: isLandscape ? 40 : 48),
          // Emoji grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final r = _ratingEmojis[i];
              final rating = i + 1;
              final isSelected = _selectedRating == rating;
              return GestureDetector(
                onTap: () => _onRatingTap(rating),
                child: AnimatedScale(
                  scale: isSelected ? 1.3 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isLandscape ? 72 : 64,
                        height: isLandscape ? 72 : 64,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(r['color'] as int).withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? Border.all(color: Color(r['color'] as int), width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            r['emoji'] as String,
                            style: TextStyle(fontSize: isLandscape ? 44 : 40),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r['label'] as String,
                        style: TextStyle(
                          color: Colors.white.withOpacity(isSelected ? 1.0 : 0.6),
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (config.showBilingual) ...[
                        const SizedBox(height: 2),
                        Text(
                          r['hi'] as String,
                          style: TextStyle(
                            color: Colors.white.withOpacity(isSelected ? 0.8 : 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: isLandscape ? 24 : 32),
          Text(
            'Tap to rate',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhase2(KioskConfig config, bool isLandscape) {
    final mode = config.displayMode;
    final rating = _selectedRating ?? 3;

    if (mode == KioskDisplayMode.withComment) {
      return _buildCommentPhase(config, isLandscape);
    }

    if (mode == KioskDisplayMode.withTags) {
      if (rating <= 2) {
        return _buildTagPhase(config, config.negativeTags, 'What went wrong?',
            '\u0915\u094D\u092F\u093E \u0917\u0932\u0924 \u0939\u0941\u0906?', isLandscape);
      }
      if (rating >= 4) {
        return _buildTagPhase(config, config.positiveTags, 'What did you like?',
            '\u0906\u092A\u0915\u094B \u0915\u094D\u092F\u093E \u092A\u0938\u0902\u0926 \u0906\u092F\u093E?', isLandscape);
      }
      // Rating 3 = skip tags, submit directly
      _submitAndThank();
      return const SizedBox.shrink();
    }

    // Fallback
    _submitAndThank();
    return const SizedBox.shrink();
  }

  Widget _buildCommentPhase(KioskConfig config, bool isLandscape) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _ratingEmojis[(_selectedRating ?? 3) - 1]['emoji'] as String,
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 16),
          Text(
            'Tell us more (optional)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (config.showBilingual) ...[
            const SizedBox(height: 4),
            Text(
              '\u0914\u0930 \u092C\u0924\u093E\u090F\u0902 (\u0935\u0948\u0915\u0932\u094D\u092A\u093F\u0915)',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 200,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Your feedback...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              counterStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            ),
            onTap: () {
              // Reset auto-reset when user interacts
              _startAutoReset();
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _submitAndThank,
                child: Text(
                  'Skip',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                ),
              ),
              const SizedBox(width: 24),
              ElevatedButton(
                onPressed: _submitAndThank,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagPhase(
    KioskConfig config,
    List<String> tags,
    String titleEn,
    String titleHi,
    bool isLandscape,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _ratingEmojis[(_selectedRating ?? 3) - 1]['emoji'] as String,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            titleEn,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (config.showBilingual) ...[
            const SizedBox(height: 4),
            Text(
              titleHi,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: tags.map((tag) {
              final info = _tagLabels[tag];
              final isSelected = _selectedTags.contains(tag);
              final emoji = info?['emoji'] ?? '';
              final labelEn = info?['en'] ?? tag;
              final labelHi = info?['hi'] ?? '';

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (isSelected) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  });
                  _startAutoReset();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2563EB).withOpacity(0.3)
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : Colors.white.withOpacity(0.15),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            labelEn,
                            style: TextStyle(
                              color: Colors.white.withOpacity(isSelected ? 1.0 : 0.7),
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          if (config.showBilingual && labelHi.isNotEmpty)
                            Text(
                              labelHi,
                              style: TextStyle(
                                color: Colors.white.withOpacity(isSelected ? 0.7 : 0.4),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _submitAndThank,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _selectedTags.isEmpty ? 'Skip' : 'Submit',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThankYou(KioskConfig config) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('\uD83D\uDE4F', style: TextStyle(fontSize: 72)),
        const SizedBox(height: 20),
        Text(
          'Thank You!',
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (config.showBilingual) ...[
          const SizedBox(height: 6),
          Text(
            '\u0927\u0928\u094D\u092F\u0935\u093E\u0926!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 24,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Your feedback helps us improve',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(KioskConfig config) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Powered by ERP System',
        style: TextStyle(
          color: Colors.white.withOpacity(0.2),
          fontSize: 11,
        ),
      ),
    );
  }
}
