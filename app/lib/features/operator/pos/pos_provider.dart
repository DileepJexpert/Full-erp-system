import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';

class PosItem {
  final String id;
  final String name;
  final double sellPrice;
  final double gstRate;
  final String category;
  final String unit;

  const PosItem({
    required this.id,
    required this.name,
    required this.sellPrice,
    required this.gstRate,
    required this.category,
    required this.unit,
  });

  factory PosItem.fromJson(Map<String, dynamic> json) {
    return PosItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      sellPrice: (json['sellPrice'] ?? 0).toDouble(),
      gstRate: (json['gstRate'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      unit: json['unit'] ?? '',
    );
  }
}

class CartItem {
  final PosItem item;
  int quantity;

  CartItem({required this.item, this.quantity = 1});

  double get lineTotal => quantity * item.sellPrice;
  double get cgst => lineTotal * (item.gstRate / 2) / 100;
  double get sgst => lineTotal * (item.gstRate / 2) / 100;
  double get totalWithGst => lineTotal + cgst + sgst;
}

enum PaymentMode { cash, upi, mixed }

class CartState {
  final List<CartItem> items;
  final PaymentMode paymentMode;
  final double cashAmount;
  final String? upiRef;
  final bool isSubmitting;
  final String? customerPhone;

  const CartState({
    this.items = const [],
    this.paymentMode = PaymentMode.cash,
    this.cashAmount = 0,
    this.upiRef,
    this.isSubmitting = false,
    this.customerPhone,
  });

  double get subtotal => items.fold(0, (sum, i) => sum + i.lineTotal);
  double get cgstTotal => items.fold(0, (sum, i) => sum + i.cgst);
  double get sgstTotal => items.fold(0, (sum, i) => sum + i.sgst);
  double get total => subtotal + cgstTotal + sgstTotal;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    PaymentMode? paymentMode,
    double? cashAmount,
    String? upiRef,
    bool? isSubmitting,
    String? customerPhone,
  }) {
    return CartState(
      items: items ?? this.items,
      paymentMode: paymentMode ?? this.paymentMode,
      cashAmount: cashAmount ?? this.cashAmount,
      upiRef: upiRef ?? this.upiRef,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      customerPhone: customerPhone ?? this.customerPhone,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  final ApiClient _api;
  final UserInfo? _user;

  CartNotifier(this._api, this._user) : super(const CartState());

  void addItem(PosItem item) {
    final items = [...state.items];
    final index = items.indexWhere((c) => c.item.id == item.id);
    if (index >= 0) {
      items[index].quantity++;
    } else {
      items.add(CartItem(item: item));
    }
    state = state.copyWith(items: items);
  }

  void removeItem(String itemId) {
    final items = state.items.where((c) => c.item.id != itemId).toList();
    state = state.copyWith(items: items);
  }

  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }
    final items = [...state.items];
    final index = items.indexWhere((c) => c.item.id == itemId);
    if (index >= 0) {
      items[index].quantity = quantity;
      state = state.copyWith(items: items);
    }
  }

  void setPaymentMode(PaymentMode mode) {
    state = state.copyWith(paymentMode: mode);
  }

  void setCashAmount(double amount) {
    state = state.copyWith(cashAmount: amount);
  }

  void setCustomerPhone(String? phone) {
    state = state.copyWith(customerPhone: phone);
  }

  void clearCart() {
    state = const CartState();
  }

  Future<Map<String, dynamic>?> submitBill(String locationId) async {
    if (state.isEmpty) return null;
    state = state.copyWith(isSubmitting: true);
    try {
      final paymentMode = switch (state.paymentMode) {
        PaymentMode.cash => 'CASH',
        PaymentMode.upi => 'UPI',
        PaymentMode.mixed => 'MIXED',
      };
      final total = state.total;
      final cashAmount = state.paymentMode == PaymentMode.cash
          ? total
          : state.paymentMode == PaymentMode.mixed
              ? state.cashAmount
              : 0.0;
      final upiAmount = total - cashAmount;

      final response = await _api.post('/billing', data: {
        'locationId': locationId,
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'items': state.items.map((c) => {
          'itemId': c.item.id,
          'quantity': c.quantity,
          'unitPrice': c.item.sellPrice,
        }).toList(),
        'paymentMode': paymentMode,
        'cashAmount': cashAmount,
        'upiAmount': upiAmount,
        if (state.upiRef != null) 'upiTransactionRef': state.upiRef,
        if (state.customerPhone != null) 'customerPhone': state.customerPhone,
      });

      final bill = response.data as Map<String, dynamic>;
      clearCart();
      return bill;
    } catch (e) {
      rethrow;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}

// Providers
final posItemsProvider = FutureProvider<List<PosItem>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/inventory', queryParameters: {'limit': '100', 'isActive': 'true'});
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List)
      .map((j) => PosItem.fromJson(j as Map<String, dynamic>))
      .where((item) => item.sellPrice > 0)
      .toList();
});

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final api = ref.read(apiClientProvider);
  final user = ref.read(authProvider).user;
  return CartNotifier(api, user);
});
