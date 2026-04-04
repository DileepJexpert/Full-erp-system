/// Data model that holds everything needed to print a POS receipt.
class ReceiptLineItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double gstRate;

  const ReceiptLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.gstRate,
  });

  double get lineTotal => quantity * unitPrice;
  double get cgst => lineTotal * (gstRate / 2) / 100;
  double get sgst => lineTotal * (gstRate / 2) / 100;
}

class ReceiptData {
  final String billNumber;
  final String businessName;
  final String locationName;
  final DateTime dateTime;
  final List<ReceiptLineItem> items;
  final String paymentMode; // CASH, UPI, MIXED
  final double cashAmount;
  final double upiAmount;
  final String? upiRef;
  final String? customerPhone;
  final String? footerMessage;

  const ReceiptData({
    required this.billNumber,
    required this.businessName,
    required this.locationName,
    required this.dateTime,
    required this.items,
    required this.paymentMode,
    this.cashAmount = 0,
    this.upiAmount = 0,
    this.upiRef,
    this.customerPhone,
    this.footerMessage,
  });

  double get subtotal =>
      items.fold<double>(0, (sum, i) => sum + i.lineTotal);

  double get cgstTotal =>
      items.fold<double>(0, (sum, i) => sum + i.cgst);

  double get sgstTotal =>
      items.fold<double>(0, (sum, i) => sum + i.sgst);

  double get grandTotal => subtotal + cgstTotal + sgstTotal;

  /// Derive an effective GST rate label (only meaningful when all items share
  /// the same rate).
  double get effectiveGstRate {
    if (items.isEmpty) return 0;
    final rates = items.map((i) => i.gstRate).toSet();
    if (rates.length == 1) return rates.first;
    return 0; // mixed rates
  }

  /// Build a [ReceiptData] from the JSON returned by `POST /billing`.
  factory ReceiptData.fromBillJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>? ?? []).map((entry) {
      final e = entry as Map<String, dynamic>;
      return ReceiptLineItem(
        name: e['itemName'] as String? ?? e['name'] as String? ?? '',
        quantity: (e['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (e['unitPrice'] as num?)?.toDouble() ?? 0,
        gstRate: (e['gstRate'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    return ReceiptData(
      billNumber: json['billNumber'] as String? ?? json['id'] as String? ?? '',
      businessName: json['businessName'] as String? ?? '',
      locationName: json['locationName'] as String? ?? json['location'] as String? ?? '',
      dateTime: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      items: itemsList,
      paymentMode: json['paymentMode'] as String? ?? 'CASH',
      cashAmount: (json['cashAmount'] as num?)?.toDouble() ?? 0,
      upiAmount: (json['upiAmount'] as num?)?.toDouble() ?? 0,
      upiRef: json['upiTransactionRef'] as String?,
      customerPhone: json['customerPhone'] as String?,
      footerMessage: json['footerMessage'] as String?,
    );
  }
}
