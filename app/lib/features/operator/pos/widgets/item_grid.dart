import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/formatters/currency.dart';
import '../pos_provider.dart';

class ItemGrid extends ConsumerStatefulWidget {
  final List<PosItem> items;
  const ItemGrid({super.key, required this.items});

  @override
  ConsumerState<ItemGrid> createState() => _ItemGridState();
}

class _ItemGridState extends ConsumerState<ItemGrid> {
  String _search = '';
  String? _selectedCategory;

  List<PosItem> get filteredItems {
    var items = widget.items;
    if (_search.isNotEmpty) {
      items = items.where((i) => i.name.toLowerCase().contains(_search.toLowerCase())).toList();
    }
    if (_selectedCategory != null) {
      items = items.where((i) => i.category == _selectedCategory).toList();
    }
    return items;
  }

  Set<String> get categories => widget.items.map((i) => i.category).toSet();

  @override
  Widget build(BuildContext context) {
    final items = filteredItems;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 4 : 2;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search items...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        // Category chips
        if (categories.length > 1)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('All', null),
                ...categories.map((c) => _chip(c, c)),
              ],
            ),
          ),
        const SizedBox(height: 4),
        // Item grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _ItemCard(item: item);
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, String? category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = category),
        selectedColor: const Color(0xFF2563EB),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final PosItem item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartItem = cart.items.where((c) => c.item.id == item.id).firstOrNull;
    final qty = cartItem?.quantity ?? 0;

    return Material(
      color: qty > 0 ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => ref.read(cartProvider.notifier).addItem(item),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: qty > 0 ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              width: qty > 0 ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (qty > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('×$qty', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              const Spacer(),
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                formatRupee(item.sellPrice),
                style: const TextStyle(
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                'per ${item.unit}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
