import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';

// ── Providers ──────────────────────────────────────────────────

final kdsOrdersProvider =
    FutureProvider.autoDispose<Map<String, List<Map<String, dynamic>>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/kds/orders');
  final data = response.data as Map<String, dynamic>;
  final orders = (data['data'] as List? ?? []).cast<Map<String, dynamic>>();

  final grouped = <String, List<Map<String, dynamic>>>{
    'NEW': [],
    'PREPARING': [],
    'READY': [],
  };
  for (final order in orders) {
    final status = order['status'] ?? 'NEW';
    if (grouped.containsKey(status)) {
      grouped[status]!.add(order);
    }
  }
  return grouped;
});

// ── Screen ─────────────────────────────────────────────────────

class KdsScreen extends ConsumerStatefulWidget {
  const KdsScreen({super.key});

  @override
  ConsumerState<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends ConsumerState<KdsScreen> {
  Timer? _refreshTimer;
  int _previousNewCount = 0;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.invalidate(kdsOrdersProvider);
    });
    // Fullscreen immersive
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _advanceOrder(Map<String, dynamic> order) async {
    final currentStatus = order['status'] ?? 'NEW';
    String nextStatus;
    switch (currentStatus) {
      case 'NEW':
        nextStatus = 'PREPARING';
        break;
      case 'PREPARING':
        nextStatus = 'READY';
        break;
      case 'READY':
        nextStatus = 'SERVED';
        break;
      default:
        return;
    }

    try {
      final api = ref.read(apiClientProvider);
      await api.put('/kds/orders/${order['id']}', data: {
        'status': nextStatus,
      });
      ref.invalidate(kdsOrdersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(kdsOrdersProvider);

    // Vibrate on new order
    ordersAsync.whenData((grouped) {
      final newCount = grouped['NEW']?.length ?? 0;
      if (newCount > _previousNewCount && _previousNewCount > 0) {
        HapticFeedback.heavyImpact();
      }
      _previousNewCount = newCount;
    });

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        cardColor: const Color(0xFF16213E),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F3460),
          title: const Text(
            'Kitchen Display',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => ref.invalidate(kdsOrdersProvider),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        body: ordersAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('Error: $err',
                    style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(kdsOrdersProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (grouped) => Row(
            children: [
              _KdsColumn(
                title: 'NEW ORDERS',
                titleColor: const Color(0xFFE94560),
                orders: grouped['NEW'] ?? [],
                onTapOrder: _advanceOrder,
                nextLabel: 'Start Preparing',
              ),
              Container(width: 1, color: const Color(0xFF2D3348)),
              _KdsColumn(
                title: 'PREPARING',
                titleColor: const Color(0xFFEAB308),
                orders: grouped['PREPARING'] ?? [],
                onTapOrder: _advanceOrder,
                nextLabel: 'Mark Ready',
              ),
              Container(width: 1, color: const Color(0xFF2D3348)),
              _KdsColumn(
                title: 'READY',
                titleColor: const Color(0xFF16A34A),
                orders: grouped['READY'] ?? [],
                onTapOrder: _advanceOrder,
                nextLabel: 'Served',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── KDS Column ─────────────────────────────────────────────────

class _KdsColumn extends StatelessWidget {
  final String title;
  final Color titleColor;
  final List<Map<String, dynamic>> orders;
  final ValueChanged<Map<String, dynamic>> onTapOrder;
  final String nextLabel;

  const _KdsColumn({
    required this.title,
    required this.titleColor,
    required this.orders,
    required this.onTapOrder,
    required this.nextLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: titleColor.withOpacity(0.15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: titleColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${orders.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Text(
                      'No orders',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _KdsOrderCard(
                        order: order,
                        onTap: () => onTapOrder(order),
                        nextLabel: nextLabel,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── KDS Order Card ─────────────────────────────────────────────

class _KdsOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  final String nextLabel;

  const _KdsOrderCard({
    required this.order,
    required this.onTap,
    required this.nextLabel,
  });

  String _timeSince(String? dateStr) {
    if (dateStr == null) return '';
    final created = DateTime.tryParse(dateStr);
    if (created == null) return '';
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
  }

  @override
  Widget build(BuildContext context) {
    final orderNum = order['orderNumber'] ?? order['id'] ?? '-';
    final items =
        (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final priority = order['priority'] ?? 'NORMAL';
    final createdAt = order['createdAt'] ?? order['date'];
    final timeAgo = _timeSince(createdAt?.toString());
    final isUrgent = priority == 'HIGH' || priority == 'URGENT';

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: const Color(0xFF16213E),
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isUrgent
                ? const Color(0xFFE94560)
                : const Color(0xFF2D3348),
            width: isUrgent ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '#$orderNum',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE94560),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        priority,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F3460),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item['qty'] ?? item['quantity'] ?? 1}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item['name'] ?? item['itemName'] ?? '-',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3460),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    nextLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
