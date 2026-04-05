import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/helpers/terminology.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'staff_provider.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffProvider);
    final t = ref.watch(terminologyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.staffPlural),
        actions: [
          FilledButton.icon(
            onPressed: () => context.push('/staff/new'),
            icon: const Icon(Icons.person_add, size: 18),
            label: Text('Add ${t.staff}'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(staffProvider),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search ${t.staffPlural.toLowerCase()}...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerLow,
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _search = val),
              ),
              const SizedBox(height: 16),
              staffAsync.when(
                loading: () => Column(
                  children: List.generate(
                    5,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LoadingSkeleton(height: 72),
                    ),
                  ),
                ),
                error: (err, _) => ErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(staffProvider),
                ),
                data: (staffList) {
                  var filtered = staffList;
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    filtered = filtered
                        .where((s) =>
                            (s['name'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains(q) ||
                            (s['phone'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains(q))
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.people_outlined,
                      title: 'No staff found',
                      subtitle: 'Add staff members to your team.',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final s = filtered[index];
                      return _StaffCard(staff: s);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final Map<String, dynamic> staff;

  const _StaffCard({required this.staff});

  @override
  Widget build(BuildContext context) {
    final name = staff['name'] ?? '-';
    final phone = staff['phone'] ?? '-';
    final role = staff['role'] ?? '-';
    final location =
        staff['location']?['name'] ?? staff['locationName'] ?? '-';
    final isActive = staff['isActive'] ?? true;

    Color roleColor;
    switch (role.toString().toUpperCase()) {
      case 'OWNER':
        roleColor = const Color(0xFF7C3AED);
        break;
      case 'MANAGER':
        roleColor = const Color(0xFF2563EB);
        break;
      case 'OPERATOR':
        roleColor = const Color(0xFF0891B2);
        break;
      default:
        roleColor = const Color(0xFF64748B);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: roleColor.withOpacity(0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          role.toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: roleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
