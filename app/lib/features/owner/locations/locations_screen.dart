import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'locations_provider.dart';

class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Locations'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/locations/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Location'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(locationsProvider),
        child: locationsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                4,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LoadingSkeleton.card(),
                ),
              ),
            ),
          ),
          error: (err, _) => ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(locationsProvider),
          ),
          data: (locations) {
            if (locations.isEmpty) {
              return const EmptyState(
                icon: Icons.location_on_outlined,
                title: 'No locations yet',
                subtitle: 'Add your first business location.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final loc = locations[index];
                return _LocationCard(location: loc);
              },
            );
          },
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final Map<String, dynamic> location;

  const _LocationCard({required this.location});

  @override
  Widget build(BuildContext context) {
    final name = location['name'] ?? '-';
    final address = location['address'] ?? '-';
    final isActive = location['isActive'] ?? true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.storefront_outlined,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
