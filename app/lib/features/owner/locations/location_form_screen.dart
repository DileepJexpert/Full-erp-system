import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'locations_screen.dart';

class LocationFormScreen extends ConsumerStatefulWidget {
  final String? locationId;

  const LocationFormScreen({super.key, this.locationId});

  @override
  ConsumerState<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends ConsumerState<LocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isActive = true;
  bool _submitting = false;
  bool _loaded = false;

  bool get isEditing => widget.locationId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> loc) {
    if (_loaded) return;
    _loaded = true;
    _nameController.text = loc['name'] ?? '';
    _addressController.text = loc['address'] ?? '';
    _phoneController.text = loc['phone'] ?? '';
    _isActive = loc['isActive'] ?? true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final payload = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'isActive': _isActive,
      };

      if (isEditing) {
        await api.put('/locations/${widget.locationId}', data: payload);
      } else {
        await api.post('/locations', data: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEditing
                  ? 'Location updated'
                  : 'Location created successfully')),
        );
        ref.invalidate(locationsProvider);
        context.go('/locations');
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
                onPressed: () => context.go('/locations'),
              ),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'Edit Location' : 'Add New Location',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isEditing) _buildEditForm() else _buildForm(),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    final locationsAsync = ref.watch(locationsProvider);
    return locationsAsync.when(
      loading: () => const LoadingSkeleton(height: 300),
      error: (err, _) => ErrorView(
        message: err.toString(),
        onRetry: () => ref.invalidate(locationsProvider),
      ),
      data: (locations) {
        final loc = locations.firstWhere(
          (l) => l['id'] == widget.locationId,
          orElse: () => <String, dynamic>{},
        );
        if (loc.isNotEmpty) _populateFields(loc);
        return _buildForm();
      },
    );
  }

  Widget _buildForm() {
    return Card(
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
                  labelText: 'Location Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Inactive locations are hidden from dispatch'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEditing ? 'Update Location' : 'Create Location'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
