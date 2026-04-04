import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';

// Search and filter state
final inventorySearchProvider = StateProvider.autoDispose<String>((ref) => '');
final inventoryCategoryFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

// Items list provider
final inventoryListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/items');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

// Filtered list
final filteredInventoryProvider =
    Provider.autoDispose<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final listAsync = ref.watch(inventoryListProvider);
  final search = ref.watch(inventorySearchProvider).toLowerCase();
  final category = ref.watch(inventoryCategoryFilterProvider);

  return listAsync.whenData((items) {
    var filtered = items;
    if (search.isNotEmpty) {
      filtered = filtered
          .where(
              (i) => (i['name'] ?? '').toString().toLowerCase().contains(search))
          .toList();
    }
    if (category != null && category.isNotEmpty) {
      filtered =
          filtered.where((i) => i['category'] == category).toList();
    }
    return filtered;
  });
});

// Categories derived from items
final inventoryCategoriesProvider =
    Provider.autoDispose<List<String>>((ref) {
  final listAsync = ref.watch(inventoryListProvider);
  return listAsync.whenOrNull(
        data: (items) {
          final cats = items
              .map((i) => i['category']?.toString() ?? '')
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList();
          cats.sort();
          return cats;
        },
      ) ??
      [];
});

// Items state notifier for mutations
class ItemsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final ApiClient _api;

  ItemsNotifier(this._api) : super(const AsyncValue.loading()) {
    fetchItems();
  }

  Future<void> fetchItems() async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.get('/items');
      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] as List).cast<Map<String, dynamic>>();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createItem(Map<String, dynamic> payload) async {
    await _api.post('/items', data: payload);
    await fetchItems();
  }

  Future<void> updateItem(String id, Map<String, dynamic> payload) async {
    await _api.put('/items/$id', data: payload);
    await fetchItems();
  }

  Future<void> deleteItem(String id) async {
    await _api.delete('/items/$id');
    await fetchItems();
  }
}

final itemsNotifierProvider = StateNotifierProvider.autoDispose<ItemsNotifier,
    AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final api = ref.read(apiClientProvider);
  return ItemsNotifier(api);
});
