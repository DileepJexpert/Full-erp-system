import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'marketplace_provider.dart';

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(marketplaceListingsProvider);
    final selectedCategory = ref.watch(marketplaceCategoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(marketplaceListingsProvider),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search listings...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                  isDense: true,
                ),
                onChanged: (val) =>
                    ref.read(marketplaceSearchProvider.notifier).state = val,
              ),
              const SizedBox(height: 12),
              // Category filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: selectedCategory == null,
                      onSelected: (_) => ref
                          .read(marketplaceCategoryProvider.notifier)
                          .state = null,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Raw Materials'),
                      selected: selectedCategory == 'raw_materials',
                      onSelected: (_) => ref
                          .read(marketplaceCategoryProvider.notifier)
                          .state = selectedCategory == 'raw_materials'
                          ? null
                          : 'raw_materials',
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Packaging'),
                      selected: selectedCategory == 'packaging',
                      onSelected: (_) => ref
                          .read(marketplaceCategoryProvider.notifier)
                          .state = selectedCategory == 'packaging'
                          ? null
                          : 'packaging',
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Equipment'),
                      selected: selectedCategory == 'equipment',
                      onSelected: (_) => ref
                          .read(marketplaceCategoryProvider.notifier)
                          .state = selectedCategory == 'equipment'
                          ? null
                          : 'equipment',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              listingsAsync.when(
                loading: () => Column(
                  children: List.generate(
                    4,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LoadingSkeleton.card(),
                    ),
                  ),
                ),
                error: (err, _) => ErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(marketplaceListingsProvider),
                ),
                data: (listings) {
                  if (listings.isEmpty) {
                    return const EmptyState(
                      icon: Icons.store_outlined,
                      title: 'No listings found',
                      subtitle: 'Try adjusting your search or filters.',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: listings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final listing = listings[index];
                      return _ListingCard(listing: listing);
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

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> listing;

  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = listing['name'] ?? 'Unnamed';
    final supplierName =
        listing['supplierName'] ?? listing['supplier']?['name'] ?? '-';
    final price = (listing['pricePerUnit'] ?? listing['price'] ?? 0).toDouble();
    final unit = listing['unit'] ?? 'unit';
    final minOrder = listing['minOrder'] ?? listing['minOrderQty'] ?? 0;
    final rating = (listing['supplierRating'] ?? listing['rating'] ?? 0).toDouble();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Detail view could be navigated to
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.inventory_2_outlined,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(supplierName,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: const Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${formatRupee(price)}/$unit',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Min: $minOrder',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Rating stars
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      if (i < rating.floor()) {
                        return const Icon(Icons.star,
                            size: 16, color: Color(0xFFFBBF24));
                      } else if (i < rating) {
                        return const Icon(Icons.star_half,
                            size: 16, color: Color(0xFFFBBF24));
                      }
                      return const Icon(Icons.star_border,
                          size: 16, color: Color(0xFFCBD5E1));
                    }),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rating.toStringAsFixed(1),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
