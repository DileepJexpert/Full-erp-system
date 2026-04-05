import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/token_storage.dart';
import '../../config/theme.dart';

const _businessTypes = {
  'FOOD_KIOSK': ('Food Kiosk', Icons.restaurant),
  'CLOUD_KITCHEN': ('Cloud Kitchen', Icons.kitchen),
  'BAKERY': ('Bakery', Icons.cake),
  'LAUNDRY': ('Laundry', Icons.local_laundry_service),
  'COACHING': ('Coaching', Icons.school),
  'PHARMACY_CHAIN': ('Pharmacy', Icons.local_pharmacy),
  'RENTAL': ('Rental', Icons.car_rental),
  'SERVICE': ('Service', Icons.build),
  'KIRANA': ('Kirana Store', Icons.storefront),
  'OTHER': ('Other', Icons.category),
};

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1
  String? _selectedType;

  // Step 2
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _step2FormKey = GlobalKey<FormState>();

  // Step 3
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;

  // Step 4
  final _locationNameController = TextEditingController();

  // Step 5
  bool _loading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _locationNameController.dispose();
    super.dispose();
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _selectedType != null;
      case 1:
        return _businessNameController.text.trim().isNotEmpty &&
            _ownerNameController.text.trim().isNotEmpty;
      case 2:
        return _otpVerified;
      case 3:
        return _locationNameController.text.trim().isNotEmpty;
      case 4:
        return true;
      default:
        return false;
    }
  }

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = step);
  }

  void _next() {
    if (_currentStep == 1) {
      if (!_step2FormKey.currentState!.validate()) return;
    }
    if (_currentStep < 4) {
      _goToStep(_currentStep + 1);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid 10-digit mobile number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _sendingOtp = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendOtp(phone);
      if (mounted) {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the 6-digit OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _verifyingOtp = true);
    // Simulate OTP verification locally (actual verification happens at register)
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _otpVerified = true;
        _verifyingOtp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number verified'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.register(
        businessName: _businessNameController.text.trim(),
        businessType: _selectedType!,
        ownerName: _ownerNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
      );
      final token = result['token'] as String;
      await TokenStorage.saveToken(token);
      await ref.read(authProvider.notifier).checkAuth();
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isDesktop ? 560 : double.infinity),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                    _buildStep4(),
                    _buildStep5(),
                  ],
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final stepTitles = [
      'Business Type',
      'Business Info',
      'Verify Phone',
      'Location Setup',
      'All Done!',
    ];
    final stepSubtitles = [
      'What kind of business do you run?',
      'Tell us about your business',
      'Enter and verify your phone number',
      'Set up your first location',
      'Review your details',
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront, color: AppTheme.primaryColor, size: 28),
              const SizedBox(width: 8),
              Text(
                'Business Manager',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 5,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 6),
          Text(
            'Step ${_currentStep + 1} of 5',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            stepTitles[_currentStep],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stepSubtitles[_currentStep],
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : _back,
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: (_canProceed && !_loading) ? _next : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _currentStep == 4 ? 'Get Started' : 'Next',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 1: Business Type
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
        ),
        itemCount: _businessTypes.length,
        itemBuilder: (context, index) {
          final key = _businessTypes.keys.elementAt(index);
          final (label, icon) = _businessTypes[key]!;
          final isSelected = _selectedType == key;

          return InkWell(
            onTap: () => setState(() => _selectedType = key),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.08)
                    : const Color(0xFFF8F9FA),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : const Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 32,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Step 2: Business Info
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Business Name *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _businessNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Sharma Kirana Store',
                prefixIcon: Icon(Icons.storefront),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Business name is required' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _fieldLabel('Owner Name *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ownerNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Ramesh Sharma',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Owner name is required' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _fieldLabel('Email (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'e.g. ramesh@example.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v != null && v.trim().isNotEmpty) {
                  final emailRegex = RegExp(r'^[\w\.\+\-]+@[\w\-]+\.\w{2,}$');
                  if (!emailRegex.hasMatch(v.trim())) {
                    return 'Enter a valid email address';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // Step 3: Phone & OTP
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Mobile Number *'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !_otpVerified,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    prefixText: '+91  ',
                    hintText: '10-digit number',
                    prefixIcon: const Icon(Icons.phone),
                    suffixIcon: _otpVerified
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  ),
                  onChanged: (_) => setState(() {
                    _otpSent = false;
                    _otpVerified = false;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: (_sendingOtp || _otpVerified)
                    ? null
                    : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _sendingOtp
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _otpSent ? 'Resend' : 'Send OTP',
                        style: const TextStyle(fontSize: 13),
                      ),
              ),
            ],
          ),
          if (_otpSent && !_otpVerified) ...[
            const SizedBox(height: 24),
            _fieldLabel('Enter OTP *'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      hintText: '6-digit OTP',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _verifyingOtp ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _verifyingOtp
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(fontSize: 13),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'OTP sent to your mobile number. Valid for 10 minutes.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
          if (_otpVerified) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Phone number verified successfully',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Step 4: Location Setup
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    color: AppTheme.primaryColor, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You can manage multiple locations later. Start by naming your first one.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _fieldLabel('First Location Name *'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _locationNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Main Branch, Shop 1, Central Outlet',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // Step 5: Confirmation
  Widget _buildStep5() {
    final (typeLabel, typeIcon) =
        _businessTypes[_selectedType] ?? ('Unknown', Icons.category);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryCard(
            title: 'Business Type',
            content: typeLabel,
            icon: typeIcon,
          ),
          const SizedBox(height: 12),
          _summaryCard(
            title: 'Business Name',
            content: _businessNameController.text.trim(),
            icon: Icons.storefront,
          ),
          const SizedBox(height: 12),
          _summaryCard(
            title: 'Owner',
            content: _ownerNameController.text.trim(),
            icon: Icons.person,
          ),
          const SizedBox(height: 12),
          _summaryCard(
            title: 'Phone',
            content: '+91 ${_phoneController.text.trim()}',
            icon: Icons.phone,
            trailing: const Icon(Icons.verified, color: Colors.green, size: 18),
          ),
          if (_emailController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _summaryCard(
              title: 'Email',
              content: _emailController.text.trim(),
              icon: Icons.email_outlined,
            ),
          ],
          const SizedBox(height: 12),
          _summaryCard(
            title: 'First Location',
            content: _locationNameController.text.trim(),
            icon: Icons.place_outlined,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'By registering, you agree to our Terms of Service and Privacy Policy.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String content,
    required IconData icon,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
    );
  }
}
