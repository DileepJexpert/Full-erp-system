import 'dart:async';
import 'dart:math';
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

// ─── Rating Data ────────────────────────────────────────────

const _ratingEmojis = [
  '\uD83D\uDE21', // 1: angry
  '\uD83D\uDE15', // 2: confused
  '\uD83D\uDE10', // 3: neutral
  '\uD83D\uDE0A', // 4: smile
  '\uD83E\uDD29', // 5: star-struck
];

const _ratingLabelsEn = ['Bad', 'Okay', 'Fine', 'Good', 'Great!'];
const _ratingLabelsHi = [
  '\u0916\u0930\u093E\u092C',
  '\u0920\u0940\u0915',
  '\u091A\u0932\u0924\u093E \u0939\u0948',
  '\u0905\u091A\u094D\u091B\u093E',
  '\u092C\u0939\u0941\u0924 \u092C\u0922\u093C\u093F\u092F\u093E',
];

const _ratingColors = [
  Color(0xFFEF4444),
  Color(0xFFF97316),
  Color(0xFFFBBF24),
  Color(0xFF84CC16),
  Color(0xFF22C55E),
];

// ─── Confetti Particle ──────────────────────────────────────

class _ConfettiParticle {
  double startX;
  double startY;
  final Color color;
  final double velocityX;
  final double velocityY;
  final double size;
  final bool isRect;

  double currentX;
  double currentY;
  double opacity = 1.0;

  _ConfettiParticle({
    required this.startX,
    required this.startY,
    required this.color,
    required this.velocityX,
    required this.velocityY,
    required this.size,
    required this.isRect,
  })  : currentX = startX,
        currentY = startY;

  void update(double t) {
    currentX = startX + velocityX * t * 140;
    currentY = startY + velocityY * t * 140 + 0.5 * 800 * t * t;
    opacity = (1.0 - t * 0.8).clamp(0.0, 1.0);
  }
}

// ─── Kiosk Feedback Screen ──────────────────────────────────

class KioskFeedbackScreen extends ConsumerStatefulWidget {
  const KioskFeedbackScreen({super.key});

  @override
  ConsumerState<KioskFeedbackScreen> createState() =>
      _KioskFeedbackScreenState();
}

enum _Phase { rating, phase2, thankYou }

class _KioskFeedbackScreenState extends ConsumerState<KioskFeedbackScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.rating;
  int? _selectedRating;
  final Set<String> _selectedTags = {};
  final _commentController = TextEditingController();
  Timer? _autoResetTimer;

  // Exit lock: 5 rapid taps on business name
  final List<DateTime> _titleTaps = [];

  // Animation controllers
  late AnimationController _emojiScaleController;
  late AnimationController _phaseTransitionController;
  late AnimationController _confettiController;

  // Confetti
  final List<_ConfettiParticle> _confettiParticles = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();
    // Lock to immersive full screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _emojiScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _phaseTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..value = 1.0;

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        if (_confettiParticles.isNotEmpty) {
          setState(() {
            for (final p in _confettiParticles) {
              p.update(_confettiController.value);
            }
          });
        }
      });
  }

  @override
  void dispose() {
    _autoResetTimer?.cancel();
    _commentController.dispose();
    _emojiScaleController.dispose();
    _phaseTransitionController.dispose();
    _confettiController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─── Rating tap handler ─────────────────────────────────

  void _onRatingTap(int rating) {
    if (_phase != _Phase.rating) return;
    HapticFeedback.mediumImpact();

    setState(() => _selectedRating = rating);
    _emojiScaleController.forward(from: 0);

    // Confetti for positive ratings
    if (rating >= 4) {
      _spawnConfetti();
    }

    // Transition after short delay for animation
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _moveToPhase2();
    });
  }

  void _spawnConfetti() {
    _confettiParticles.clear();
    final size = MediaQuery.of(context).size;
    final centerX = size.width / 2;
    final centerY = size.height * 0.45;

    for (int i = 0; i < 50; i++) {
      _confettiParticles.add(_ConfettiParticle(
        startX: centerX + (_random.nextDouble() - 0.5) * 100,
        startY: centerY,
        color: [
          const Color(0xFFFF6B6B),
          const Color(0xFFFFD93D),
          const Color(0xFF6BCB77),
          const Color(0xFF4D96FF),
          const Color(0xFFC77DFF),
          const Color(0xFFFF922B),
          const Color(0xFFFF85A1),
        ][_random.nextInt(7)],
        velocityX: (_random.nextDouble() - 0.5) * 8,
        velocityY: -2 - _random.nextDouble() * 6,
        size: 5 + _random.nextDouble() * 9,
        isRect: _random.nextBool(),
      ));
    }
    _confettiController.forward(from: 0);
  }

  void _moveToPhase2() {
    final config = ref.read(kioskConfigProvider);

    if (config.displayMode == KioskDisplayMode.simple) {
      _submitFeedback();
      _showThankYou();
      return;
    }

    // For withTags mode and rating == 3, go straight to thank you
    if (config.displayMode == KioskDisplayMode.withTags &&
        _selectedRating == 3) {
      _submitFeedback();
      _showThankYou();
      return;
    }

    // Slide-up transition to phase 2
    _phaseTransitionController.value = 0;
    _phaseTransitionController.forward();
    setState(() => _phase = _Phase.phase2);
    _startAutoReset();
  }

  void _showThankYou() {
    _phaseTransitionController.value = 0;
    _phaseTransitionController.forward();
    setState(() => _phase = _Phase.thankYou);
    _autoResetTimer?.cancel();
    final config = ref.read(kioskConfigProvider);
    _autoResetTimer = Timer(
      Duration(seconds: config.autoResetSec),
      _resetToRating,
    );
  }

  void _startAutoReset() {
    _autoResetTimer?.cancel();
    final config = ref.read(kioskConfigProvider);
    _autoResetTimer = Timer(
      Duration(seconds: config.autoResetSec),
      _resetToRating,
    );
  }

  void _resetToRating() {
    _autoResetTimer?.cancel();
    if (!mounted) return;
    _emojiScaleController.reset();
    _confettiParticles.clear();
    _commentController.clear();
    _phaseTransitionController.value = 0;
    _phaseTransitionController.forward();
    setState(() {
      _phase = _Phase.rating;
      _selectedRating = null;
      _selectedTags.clear();
    });
  }

  // ─── Feedback submission ────────────────────────────────

  Future<void> _submitFeedback({String? comment, List<String>? tags}) async {
    if (_selectedRating == null) return;
    final submit = ref.read(submitFeedbackProvider);
    await submit(
      rating: _selectedRating!,
      comment: comment,
      tags: tags,
    );
  }

  void _onSkip() {
    _submitFeedback();
    _showThankYou();
  }

  void _onSubmitComment() {
    _submitFeedback(
      comment: _commentController.text.isNotEmpty
          ? _commentController.text
          : null,
    );
    _showThankYou();
  }

  void _onSubmitTags() {
    _submitFeedback(
      tags: _selectedTags.isNotEmpty ? _selectedTags.toList() : null,
    );
    _showThankYou();
  }

  // ─── Kiosk lock (5 rapid taps to exit) ──────────────────

  void _onTitleTap() {
    final now = DateTime.now();
    _titleTaps.removeWhere(
        (t) => now.difference(t) > const Duration(seconds: 3));
    _titleTaps.add(now);
    if (_titleTaps.length >= 5) {
      _titleTaps.clear();
      _showPinDialog();
    }
  }

  void _showPinDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
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
          FilledButton(
            onPressed: () {
              final config = ref.read(kioskConfigProvider);
              if (pinController.text == config.pin) {
                Navigator.of(ctx).pop();
                _exitKioskMode();
              } else {
                Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Wrong PIN'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
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
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  // ─── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(kioskConfigProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: Stack(
        children: [
          // Subtle radial gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [Color(0xFF1E2030), Color(0xFF0F1117)],
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _phaseTransitionController,
                curve: Curves.easeOut,
              )),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _phaseTransitionController,
                  curve: Curves.easeIn,
                ),
                child: _buildCurrentPhase(config),
              ),
            ),
          ),
          // Confetti overlay
          ..._confettiParticles.map((p) => Positioned(
                left: p.currentX,
                top: p.currentY,
                child: Opacity(
                  opacity: p.opacity.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: p.velocityX * _confettiController.value * 2,
                    child: Container(
                      width: p.size,
                      height: p.isRect ? p.size * 0.6 : p.size,
                      decoration: BoxDecoration(
                        color: p.color,
                        borderRadius: BorderRadius.circular(
                          p.isRect ? 2 : p.size / 2,
                        ),
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCurrentPhase(KioskConfig config) {
    switch (_phase) {
      case _Phase.rating:
        return _buildRatingPhase(config);
      case _Phase.phase2:
        return _buildPhase2(config);
      case _Phase.thankYou:
        return _buildThankYou(config);
    }
  }

  // ─── Phase 1: Rating ───────────────────────────────────

  Widget _buildRatingPhase(KioskConfig config) {
    return Column(
      children: [
        const SizedBox(height: 24),
        // Business name (tap target for exit lock)
        GestureDetector(
          onTap: _onTitleTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            child: Column(
              children: [
                Text(
                  config.businessName.isNotEmpty
                      ? config.businessName
                      : 'Business',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (config.locationName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    config.locationName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        const Spacer(flex: 2),
        // Question text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Text(
                'How was your experience today?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              if (config.showBilingual) ...[
                const SizedBox(height: 10),
                Text(
                  '\u0906\u091C \u0915\u093E \u0905\u0928\u0941\u092D\u0935 \u0915\u0948\u0938\u093E \u0930\u0939\u093E?',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 22,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 48),
        // Emoji rating row with large touch targets
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) => _buildEmojiButton(i, config)),
          ),
        ),
        const Spacer(flex: 3),
        // Powered by
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            'Powered by Business Manager',
            style: TextStyle(
              color: Colors.white.withOpacity(0.15),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiButton(int index, KioskConfig config) {
    final rating = index + 1;
    final isSelected = _selectedRating == rating;
    final hasSelection = _selectedRating != null;

    return GestureDetector(
      onTap: () => _onRatingTap(rating),
      child: AnimatedScale(
        scale: isSelected
            ? 1.3
            : hasSelection
                ? 0.7
                : 1.0,
        duration: Duration(milliseconds: isSelected ? 300 : 200),
        curve: isSelected ? Curves.elasticOut : Curves.easeOut,
        child: AnimatedOpacity(
          opacity: hasSelection && !isSelected ? 0.3 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            // Minimum 100x100dp touch target
            width: 100,
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? _ratingColors[index].withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: isSelected
                  ? Border.all(
                      color: _ratingColors[index].withOpacity(0.4), width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Large emoji (80+ dp)
                Text(
                  _ratingEmojis[index],
                  style: const TextStyle(fontSize: 56, height: 1.2),
                ),
                const SizedBox(height: 10),
                Text(
                  _ratingLabelsEn[index],
                  style: TextStyle(
                    color: isSelected
                        ? _ratingColors[index]
                        : Colors.white.withOpacity(0.7),
                    fontSize: 15,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (config.showBilingual) ...[
                  const SizedBox(height: 2),
                  Text(
                    _ratingLabelsHi[index],
                    style: TextStyle(
                      color: Colors.white.withOpacity(isSelected ? 0.6 : 0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Phase 2: Comment or Tags ──────────────────────────

  Widget _buildPhase2(KioskConfig config) {
    if (config.displayMode == KioskDisplayMode.withComment) {
      return _buildCommentView(config);
    }
    if (config.displayMode == KioskDisplayMode.withTags) {
      final rating = _selectedRating ?? 3;
      if (rating <= 2) {
        return _buildTagsView(
          config,
          config.negativeTags,
          'What could be better?',
          '\u0915\u094D\u092F\u093E \u092C\u0947\u0939\u0924\u0930 \u0939\u094B \u0938\u0915\u0924\u093E \u0939\u0948?',
          isNegative: true,
        );
      }
      if (rating >= 4) {
        return _buildTagsView(
          config,
          config.positiveTags,
          'What did you like?',
          '\u0906\u092A\u0915\u094B \u0915\u094D\u092F\u093E \u092A\u0938\u0902\u0926 \u0906\u092F\u093E?',
          isNegative: false,
        );
      }
    }
    // Fallback: submit and show thank you
    _submitFeedback();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showThankYou());
    return const SizedBox.shrink();
  }

  Widget _buildCommentView(KioskConfig config) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Selected emoji
          Text(
            _ratingEmojis[(_selectedRating ?? 3) - 1],
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          const Text(
            '\uD83C\uDF89 Thank You!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (config.showBilingual) ...[
            const SizedBox(height: 4),
            Text(
              '\u0927\u0928\u094D\u092F\u0935\u093E\u0926!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 20,
              ),
            ),
          ],
          const SizedBox(height: 32),
          Text(
            'Want to tell us more?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 300,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Type your feedback here...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                counterStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              ),
              onTap: _startAutoReset,
              onChanged: (_) => _startAutoReset(),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _onSkip,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child:
                    const Text('SKIP', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 20),
              FilledButton(
                onPressed: _onSubmitComment,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('SUBMIT',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagsView(
    KioskConfig config,
    List<String> tags,
    String titleEn,
    String titleHi, {
    required bool isNegative,
  }) {
    final accentColor =
        isNegative ? const Color(0xFFEF4444) : const Color(0xFF22C55E);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _ratingEmojis[(_selectedRating ?? 3) - 1],
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          Text(
            titleEn,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (config.showBilingual) ...[
            const SizedBox(height: 6),
            Text(
              titleHi,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 18,
              ),
            ),
          ],
          const SizedBox(height: 28),
          // Tags grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withOpacity(0.15)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? accentColor
                          : Colors.white.withOpacity(0.12),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            labelEn,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.7),
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          if (config.showBilingual && labelHi.isNotEmpty)
                            Text(
                              labelHi,
                              style: TextStyle(
                                color: Colors.white
                                    .withOpacity(isSelected ? 0.6 : 0.35),
                                fontSize: 12,
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
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _onSkip,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child:
                    const Text('SKIP', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 20),
              FilledButton(
                onPressed:
                    _selectedTags.isNotEmpty ? _onSubmitTags : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor:
                      const Color(0xFF2563EB).withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('DONE',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Thank You ─────────────────────────────────────────

  Widget _buildThankYou(KioskConfig config) {
    final isPositive = (_selectedRating ?? 3) >= 4;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isPositive ? '\uD83C\uDF89' : '\uD83D\uDE4F',
            style: const TextStyle(fontSize: 80),
          ),
          const SizedBox(height: 24),
          const Text(
            'Thank You!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (config.showBilingual) ...[
            const SizedBox(height: 10),
            Text(
              '\u0927\u0928\u094D\u092F\u0935\u093E\u0926!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 30,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Your feedback helps us improve',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
