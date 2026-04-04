import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import 'staff_screen.dart';

class StaffFormScreen extends ConsumerStatefulWidget {
  const StaffFormScreen({super.key});

  @override
  ConsumerState<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends ConsumerState<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _baseSalaryController = TextEditingController();
  String _role = 'STAFF';
  String _salaryType = 'FIXED';
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _baseSalaryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/auth/users', data: {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _role,
        'salaryType': _salaryType,
        'baseSalary': double.tryParse(_baseSalaryController.text) ?? 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff member added successfully')),
        );
        ref.invalidate(staffListProvider);
        context.go('/staff');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/staff'),
              ),
              const SizedBox(width: 8),
              Text(
                'Add Staff Member',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        prefixText: '+91 ',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().length < 10)
                          ? 'Valid phone number required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: const InputDecoration(
                        labelText: 'Role *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
                        DropdownMenuItem(
                            value: 'MANAGER', child: Text('Manager')),
                      ],
                      onChanged: (v) => setState(() => _role = v ?? 'STAFF'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _salaryType,
                      decoration: const InputDecoration(
                        labelText: 'Salary Type *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance_wallet),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'FIXED', child: Text('Fixed Monthly')),
                        DropdownMenuItem(
                            value: 'DAILY', child: Text('Daily Wage')),
                        DropdownMenuItem(
                            value: 'COMMISSION',
                            child: Text('Commission Based')),
                      ],
                      onChanged: (v) =>
                          setState(() => _salaryType = v ?? 'FIXED'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _baseSalaryController,
                      decoration: InputDecoration(
                        labelText: _salaryType == 'DAILY'
                            ? 'Daily Rate *'
                            : 'Base Salary *',
                        border: const OutlineInputBorder(),
                        prefixText: '\u20B9 ',
                        prefixIcon: const Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (v == null || double.tryParse(v) == null)
                              ? 'Valid amount required'
                              : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.person_add),
                        label: Text(
                            _submitting ? 'Adding...' : 'Add Staff Member'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
