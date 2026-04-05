import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/business_provider.dart';
import '../../../shared/formatters/currency.dart';
import 'pos_provider.dart';
import 'widgets/item_grid.dart';
import 'widgets/cart_panel.dart';
import 'widgets/payment_sheet.dart';

/// Adaptive POS that changes layout/features based on business type.
/// Wraps the standard POS with type-specific enhancements.
class AdaptivePosScreen extends ConsumerWidget {
  const AdaptivePosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(businessConfigProvider);
    final cart = ref.watch(cartProvider);
    final itemsAsync = ref.watch(posItemsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;

    final businessType = configAsync.when(
      data: (c) => c.type,
      loading: () => '',
      error: (_, __) => '',
    );

    return Scaffold(
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (items) {
          // Choose layout based on business type
          final itemWidget = _buildItemSection(businessType, items, ref);

          if (isDesktop) {
            return Row(
              children: [
                Expanded(flex: 3, child: itemWidget),
                Container(width: 1, color: const Color(0xFFE2E8F0)),
                Expanded(flex: 2, child: CartPanel(cart: cart)),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: itemWidget),
              _MobileCartBar(cart: cart),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemSection(String businessType, List<PosItem> items, WidgetRef ref) {
    switch (businessType) {
      case 'PHARMACY_CHAIN':
        return _PharmacyPosView(items: items);
      case 'KIRANA':
        return _KiranaPosView(items: items);
      case 'LAUNDRY':
      case 'SERVICE':
      case 'COACHING':
        return _ServicePosView(items: items, businessType: businessType);
      default:
        // Food-based businesses use the standard grid
        return ItemGrid(items: items);
    }
  }
}

/// Pharmacy POS: Search-first layout with barcode button, batch/expiry info
class _PharmacyPosView extends ConsumerStatefulWidget {
  final List<PosItem> items;
  const _PharmacyPosView({required this.items});

  @override
  ConsumerState<_PharmacyPosView> createState() => _PharmacyPosViewState();
}

class _PharmacyPosViewState extends ConsumerState<_PharmacyPosView> {
  String _search = '';

  List<PosItem> get filtered => _search.isEmpty
      ? widget.items
      : widget.items.where((i) => i.name.toLowerCase().contains(_search.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search-first bar with barcode icon
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search medicine by name...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  // Barcode scan placeholder
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Barcode scanner - coming soon')),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // List view (not grid - pharmacies need more detail per item)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
              return _PharmacyItemTile(item: item);
            },
          ),
        ),
      ],
    );
  }
}

class _PharmacyItemTile extends ConsumerWidget {
  final PosItem item;
  const _PharmacyItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartItem = cart.items.where((c) => c.item.id == item.id).firstOrNull;
    final qty = cartItem?.quantity ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${item.category} | ${item.unit}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatRupee(item.sellPrice), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
            const SizedBox(width: 12),
            if (qty > 0) ...[
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.id, qty - 1),
              ),
              Text('$qty', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF2563EB), size: 24),
              onPressed: () => ref.read(cartProvider.notifier).addItem(item),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kirana POS: Category-first with weight entry support
class _KiranaPosView extends ConsumerStatefulWidget {
  final List<PosItem> items;
  const _KiranaPosView({required this.items});

  @override
  ConsumerState<_KiranaPosView> createState() => _KiranaPosViewState();
}

class _KiranaPosViewState extends ConsumerState<_KiranaPosView> {
  String? _selectedCategory;
  String _search = '';

  Set<String> get categories => widget.items.map((i) => i.category).toSet();

  List<PosItem> get filtered {
    var items = widget.items;
    if (_selectedCategory != null) {
      items = items.where((i) => i.category == _selectedCategory).toList();
    }
    if (_search.isNotEmpty) {
      items = items.where((i) => i.name.toLowerCase().contains(_search.toLowerCase())).toList();
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Barcode scanner - coming soon')),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Category tabs at top (prominent for kirana)
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _categoryChip('All', null),
              ...categories.map((c) => _categoryChip(c, c)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // List with quantity + weight entry
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
              return _KiranaItemTile(item: item);
            },
          ),
        ),
      ],
    );
  }

  Widget _categoryChip(String label, String? category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : null, fontWeight: isSelected ? FontWeight.w600 : null)),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = category),
        selectedColor: const Color(0xFF2563EB),
        showCheckmark: false,
      ),
    );
  }
}

class _KiranaItemTile extends ConsumerWidget {
  final PosItem item;
  const _KiranaItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartItem = cart.items.where((c) => c.item.id == item.id).firstOrNull;
    final qty = cartItem?.quantity ?? 0;
    final isWeightItem = item.unit == 'kg' || item.unit == 'g' || item.unit == 'L' || item.unit == 'ml';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('${formatRupee(item.sellPrice)} / ${item.unit}',
                      style: const TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (isWeightItem && qty == 0)
              // Show "Add by weight" button for weight items
              OutlinedButton.icon(
                onPressed: () => _showWeightDialog(context, ref),
                icon: const Icon(Icons.scale, size: 16),
                label: const Text('Weigh', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              )
            else ...[
              if (qty > 0)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.id, qty - 1),
                  visualDensity: VisualDensity.compact,
                ),
              if (qty > 0) Text('$qty', style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFF2563EB), size: 24),
                onPressed: () => ref.read(cartProvider.notifier).addItem(item),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showWeightDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter weight for ${item.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            suffixText: item.unit,
            hintText: 'e.g., 0.5',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final weight = double.tryParse(controller.text);
              if (weight != null && weight > 0) {
                // Add as quantity (weight-based)
                ref.read(cartProvider.notifier).addItem(item);
                ref.read(cartProvider.notifier).updateQuantity(item.id, weight.ceil());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

/// Service POS: Simple service list with fee amounts (Laundry, Coaching, Service)
class _ServicePosView extends ConsumerStatefulWidget {
  final List<PosItem> items;
  final String businessType;
  const _ServicePosView({required this.items, required this.businessType});

  @override
  ConsumerState<_ServicePosView> createState() => _ServicePosViewState();
}

class _ServicePosViewState extends ConsumerState<_ServicePosView> {
  String _search = '';

  List<PosItem> get filtered => _search.isEmpty
      ? widget.items
      : widget.items.where((i) => i.name.toLowerCase().contains(_search.toLowerCase())).toList();

  String get _searchHint => switch (widget.businessType) {
    'LAUNDRY' => 'Search services (wash, dry clean...)',
    'COACHING' => 'Search courses or fees...',
    _ => 'Search services...',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: _searchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = filtered[index];
              return _ServiceItemTile(item: item);
            },
          ),
        ),
      ],
    );
  }
}

class _ServiceItemTile extends ConsumerWidget {
  final PosItem item;
  const _ServiceItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartItem = cart.items.where((c) => c.item.id == item.id).firstOrNull;
    final qty = cartItem?.quantity ?? 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEFF6FF),
        child: Icon(Icons.miscellaneous_services, color: const Color(0xFF2563EB), size: 20),
      ),
      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('per ${item.unit}', style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatRupee(item.sellPrice), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF16A34A))),
          const SizedBox(width: 8),
          qty > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('x$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                )
              : IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF2563EB)),
                  onPressed: () => ref.read(cartProvider.notifier).addItem(item),
                ),
        ],
      ),
      onTap: () => ref.read(cartProvider.notifier).addItem(item),
    );
  }
}

/// Mobile cart bar (reused from original POS)
class _MobileCartBar extends ConsumerWidget {
  final CartState cart;
  const _MobileCartBar({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cart.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${cart.itemCount} items',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B))),
                  Text(formatRupee(cart.total),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => PaymentSheet(total: cart.total),
              ),
              icon: const Icon(Icons.payment),
              label: Text('Pay ${formatRupee(cart.total)}'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
