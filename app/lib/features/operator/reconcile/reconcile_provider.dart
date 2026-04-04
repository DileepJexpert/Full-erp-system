import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';

class DispatchItem {
  final String id;
  final String itemId;
  final String itemName;
  final String unit;
  final int dispatched;
  int sold;
  int returned;

  DispatchItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.dispatched,
    this.sold = 0,
    this.returned = 0,
  });

  int get wasted => dispatched - sold - returned;

  factory DispatchItem.fromJson(Map<String, dynamic> json) {
    return DispatchItem(
      id: json['id'] ?? '',
      itemId: json['itemId'] ?? '',
      itemName: json['itemName'] ?? json['item']?['name'] ?? '',
      unit: json['unit'] ?? json['item']?['unit'] ?? 'pcs',
      dispatched: json['dispatched'] ?? json['quantity'] ?? 0,
      sold: json['sold'] ?? 0,
      returned: json['returned'] ?? 0,
    );
  }

  DispatchItem copyWith({int? sold, int? returned}) {
    return DispatchItem(
      id: id,
      itemId: itemId,
      itemName: itemName,
      unit: unit,
      dispatched: dispatched,
      sold: sold ?? this.sold,
      returned: returned ?? this.returned,
    );
  }
}

class ReconcileState {
  final List<DispatchItem> items;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final bool submitted;

  const ReconcileState({
    this.items = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.submitted = false,
  });

  int get totalDispatched => items.fold(0, (sum, i) => sum + i.dispatched);
  int get totalSold => items.fold(0, (sum, i) => sum + i.sold);
  int get totalReturned => items.fold(0, (sum, i) => sum + i.returned);
  int get totalWasted => items.fold(0, (sum, i) => sum + i.wasted);
  int get itemCount => items.length;

  ReconcileState copyWith({
    List<DispatchItem>? items,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool? submitted,
  }) {
    return ReconcileState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      submitted: submitted ?? this.submitted,
    );
  }
}

class ReconcileNotifier extends StateNotifier<ReconcileState> {
  final ApiClient _api;

  ReconcileNotifier(this._api) : super(const ReconcileState());

  Future<void> loadDispatch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/dispatch/today');
      final data = response.data;
      final List items;
      if (data is Map<String, dynamic>) {
        items = data['items'] as List? ?? data['data'] as List? ?? [];
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }
      final dispatchItems = items
          .map((j) => DispatchItem.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(items: dispatchItems, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load dispatch: $e',
      );
    }
  }

  void updateSold(int index, int sold) {
    if (index < 0 || index >= state.items.length) return;
    final items = [...state.items];
    final item = items[index];
    final clampedSold = sold.clamp(0, item.dispatched - item.returned);
    items[index] = item.copyWith(sold: clampedSold);
    state = state.copyWith(items: items);
  }

  void updateReturned(int index, int returned) {
    if (index < 0 || index >= state.items.length) return;
    final items = [...state.items];
    final item = items[index];
    final clampedReturned = returned.clamp(0, item.dispatched - item.sold);
    items[index] = item.copyWith(returned: clampedReturned);
    state = state.copyWith(items: items);
  }

  Future<bool> submit() async {
    if (state.items.isEmpty) return false;
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _api.post('/reconciliation', data: {
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'items': state.items
            .map((i) => {
                  'dispatchItemId': i.id,
                  'itemId': i.itemId,
                  'dispatched': i.dispatched,
                  'sold': i.sold,
                  'returned': i.returned,
                  'wasted': i.wasted,
                })
            .toList(),
      });
      state = state.copyWith(isSubmitting: false, submitted: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Failed to submit reconciliation: $e',
      );
      return false;
    }
  }
}

final reconcileProvider =
    StateNotifierProvider.autoDispose<ReconcileNotifier, ReconcileState>((ref) {
  final api = ref.read(apiClientProvider);
  final notifier = ReconcileNotifier(api);
  notifier.loadDispatch();
  return notifier;
});
