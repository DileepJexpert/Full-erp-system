import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_provider.dart';

final recentAlertsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/alerts', queryParameters: {'limit': '5', 'status': 'UNREAD'});
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

class AlertsPanel extends ConsumerWidget {
  const AlertsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(recentAlertsProvider);
    return alertsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Error: $err'),
      data: (alerts) {
        if (alerts.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No unread alerts')));
        return Card(
          child: Column(
            children: [
              ...alerts.map((a) => ListTile(
                leading: _severityIcon(a['severity'] ?? 'INFO'),
                title: Text(a['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(a['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                dense: true,
              )),
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(onPressed: () => context.go('/alerts'), child: const Text('View all alerts')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _severityIcon(String severity) {
    final (icon, color) = switch (severity) {
      'CRITICAL' => (Icons.error, const Color(0xFFDC2626)),
      'WARNING' => (Icons.warning, const Color(0xFFEAB308)),
      _ => (Icons.info, const Color(0xFF0EA5E9)),
    };
    return Icon(icon, color: color, size: 24);
  }
}
