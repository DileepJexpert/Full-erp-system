import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';

class SalaryBreakdown {
  final String month;
  final double baseSalary;
  final double lossDeductions;
  final double cashShortfall;
  final double advances;
  final double bonus;
  final double netSalary;
  final String status; // 'PENDING', 'PAID', 'PARTIAL'
  final DateTime? paidOn;

  SalaryBreakdown({
    required this.month,
    this.baseSalary = 0,
    this.lossDeductions = 0,
    this.cashShortfall = 0,
    this.advances = 0,
    this.bonus = 0,
    this.netSalary = 0,
    this.status = 'PENDING',
    this.paidOn,
  });

  factory SalaryBreakdown.fromJson(Map<String, dynamic> json) {
    return SalaryBreakdown(
      month: json['month'] ?? '',
      baseSalary: (json['baseSalary'] ?? 0).toDouble(),
      lossDeductions: (json['lossDeductions'] ?? 0).toDouble(),
      cashShortfall: (json['cashShortfall'] ?? 0).toDouble(),
      advances: (json['advances'] ?? 0).toDouble(),
      bonus: (json['bonus'] ?? 0).toDouble(),
      netSalary: (json['netSalary'] ?? 0).toDouble(),
      status: json['status'] ?? 'PENDING',
      paidOn:
          json['paidOn'] != null ? DateTime.tryParse(json['paidOn']) : null,
    );
  }
}

class MySalaryData {
  final SalaryBreakdown current;
  final List<SalaryBreakdown> history;

  MySalaryData({required this.current, this.history = const []});

  factory MySalaryData.fromJson(Map<String, dynamic> json) {
    final currentJson = json['current'] as Map<String, dynamic>? ?? {};
    final historyJson = json['history'] as List? ?? [];
    return MySalaryData(
      current: SalaryBreakdown.fromJson(currentJson),
      history: historyJson
          .map((j) => SalaryBreakdown.fromJson(j as Map<String, dynamic>))
          .toList(),
    );
  }
}

final mySalaryProvider =
    FutureProvider.autoDispose<MySalaryData>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/salary/my');
  return MySalaryData.fromJson(response.data as Map<String, dynamic>);
});
