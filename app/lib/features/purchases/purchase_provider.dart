import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';

// ---------------------------------------------------------------------------
// Scan / Parse providers
// ---------------------------------------------------------------------------

/// POST base64-encoded image to OCR endpoint; returns extracted bill data.
final scanBillProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, base64Image) async {
    final api = ref.read(apiClientProvider);
    final response = await api.post('/purchases/scan-bill', data: {
      'image': base64Image,
    });
    final data = response.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  },
);

/// POST raw text (e.g. pasted or typed) for server-side parsing.
final parseTextProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, text) async {
    final api = ref.read(apiClientProvider);
    final response = await api.post('/purchases/parse-text', data: {
      'text': text,
    });
    final data = response.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  },
);

/// POST voice transcript for NLP-based extraction.
final parseVoiceProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, transcript) async {
    final api = ref.read(apiClientProvider);
    final response = await api.post('/purchases/parse-voice', data: {
      'transcript': transcript,
    });
    final data = response.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  },
);

/// Fetch the last purchase for a given supplier to repeat it.
final repeatLastProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, supplierId) async {
    final api = ref.read(apiClientProvider);
    final response = await api.get('/purchases/repeat-last', queryParameters: {
      'supplierId': supplierId,
    });
    final data = response.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  },
);

/// Look up a product by barcode.
final lookupBarcodeProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, barcode) async {
    final api = ref.read(apiClientProvider);
    final response = await api.get('/purchases/barcode-lookup', queryParameters: {
      'barcode': barcode,
    });
    final data = response.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  },
);

// ---------------------------------------------------------------------------
// Lists
// ---------------------------------------------------------------------------

/// All saved purchase templates for the current business.
final purchaseTemplatesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/purchases/templates');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

/// Purchases awaiting owner/manager approval.
final pendingApprovalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response =
      await api.get('/purchases', queryParameters: {'status': 'PENDING_APPROVAL'});
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

/// Purchases entered today at the operator's current location.
final todayPurchasesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final response =
      await api.get('/purchases', queryParameters: {'date': today});
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

/// Low-stock items where centralStock <= minStockLevel.
final lowStockItemsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/inventory/low-stock');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Mutations (helper functions)
// ---------------------------------------------------------------------------

/// Save a single purchase entry.
Future<Map<String, dynamic>> savePurchase(
  ApiClient api,
  Map<String, dynamic> purchaseData,
) async {
  final response = await api.post('/purchases', data: purchaseData);
  final data = response.data as Map<String, dynamic>;
  return data['data'] as Map<String, dynamic>;
}

/// Save multiple scanned bills in one batch.
Future<List<dynamic>> batchSavePurchases(
  ApiClient api,
  List<Map<String, dynamic>> purchases,
) async {
  final response = await api.post('/purchases/batch', data: {
    'purchases': purchases,
  });
  final data = response.data as Map<String, dynamic>;
  return data['data'] as List<dynamic>;
}

/// Approve a pending purchase.
Future<void> approvePurchase(ApiClient api, String purchaseId) async {
  await api.post('/purchases/$purchaseId/approve');
}

/// Reject a pending purchase with a reason.
Future<void> rejectPurchase(
  ApiClient api,
  String purchaseId,
  String reason,
) async {
  await api.post('/purchases/$purchaseId/reject', data: {'reason': reason});
}

/// Persist the current purchase as a reusable template.
Future<void> saveTemplate(
  ApiClient api,
  Map<String, dynamic> templateData,
) async {
  await api.post('/purchases/templates', data: templateData);
}

/// Delete a purchase template.
Future<void> deleteTemplate(ApiClient api, String templateId) async {
  await api.delete('/purchases/templates/$templateId');
}

/// Add an alias for an inventory item.
Future<void> addItemAlias(
  ApiClient api,
  String itemId,
  String alias,
) async {
  await api.post('/inventory/$itemId/aliases', data: {'alias': alias});
}

/// Fetch aliases for all items.
final itemAliasesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/inventory/aliases');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});
