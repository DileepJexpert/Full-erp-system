import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

final marketplaceSearchProvider = StateProvider<String>((ref) => '');
final marketplaceCategoryProvider = StateProvider<String?>((ref) => null);

final marketplaceListingsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final search = ref.watch(marketplaceSearchProvider);
  final category = ref.watch(marketplaceCategoryProvider);

  final params = <String, dynamic>{};
  if (search.isNotEmpty) params['search'] = search;
  if (category != null) params['category'] = category;

  final response =
      await api.get('/marketplace/listings', queryParameters: params);
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['data'] != null) {
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final marketplaceOrdersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/marketplace/orders');
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['data'] != null) {
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

Future<void> placeOrder(WidgetRef ref, Map<String, dynamic> order) async {
  final api = ref.read(apiClientProvider);
  await api.post('/marketplace/orders', data: order);
  ref.invalidate(marketplaceOrdersProvider);
}

Future<void> rateSupplier(
    WidgetRef ref, String orderId, int rating, String? review) async {
  final api = ref.read(apiClientProvider);
  await api.post('/marketplace/orders/$orderId/rate', data: {
    'rating': rating,
    'review': review,
  });
  ref.invalidate(marketplaceOrdersProvider);
}
