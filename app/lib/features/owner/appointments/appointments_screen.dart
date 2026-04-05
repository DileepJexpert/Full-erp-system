import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';

// ── Providers ──────────────────────────────────────────────────

final appointmentDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final appointmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final date = ref.watch(appointmentDateProvider);
  final response = await api.get('/appointments', queryParameters: {
    'date': formatDateApi(date),
  });
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

// ── Screen ─────────────────────────────────────────────────────

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  static const _statusColors = {
    'SCHEDULED': Color(0xFF2563EB),
    'CONFIRMED': Color(0xFF0891B2),
    'IN_PROGRESS': Color(0xFFEAB308),
    'COMPLETED': Color(0xFF16A34A),
    'CANCELLED': Color(0xFFDC2626),
    'NO_SHOW': Color(0xFF64748B),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(appointmentDateProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Appointment',
            onPressed: () => _showCreateAppointment(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(appointmentsProvider),
        child: Column(
          children: [
            // Calendar strip
            _CalendarStrip(
              selectedDate: selectedDate,
              onDateSelected: (date) =>
                  ref.read(appointmentDateProvider.notifier).state = date,
            ),
            const Divider(height: 1),
            // Appointments list
            Expanded(
              child: appointmentsAsync.when(
                loading: () => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: List.generate(
                      4,
                      (_) => const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: LoadingSkeleton(height: 88),
                      ),
                    ),
                  ),
                ),
                error: (err, _) => ErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(appointmentsProvider),
                ),
                data: (appointments) {
                  if (appointments.isEmpty) {
                    return const EmptyState(
                      icon: Icons.calendar_month_outlined,
                      title: 'No appointments',
                      subtitle: 'No appointments scheduled for this date.',
                    );
                  }
                  // Sort by time
                  appointments.sort((a, b) {
                    final aTime = a['time'] ?? a['timeSlot'] ?? '';
                    final bTime = b['time'] ?? b['timeSlot'] ?? '';
                    return aTime.toString().compareTo(bTime.toString());
                  });
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final a = appointments[index];
                      return _AppointmentCard(
                        appointment: a,
                        onStatusChange: (newStatus) =>
                            _updateStatus(context, ref, a, newStatus),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref,
      Map<String, dynamic> appointment, String newStatus) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/appointments/${appointment['id']}', data: {
        'status': newStatus,
      });
      ref.invalidate(appointmentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment $newStatus'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _showCreateAppointment(
      BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final serviceCtrl = TextEditingController();
    final staffCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selectedDate = ref.read(appointmentDateProvider);
    TimeOfDay selectedTime = TimeOfDay.now();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'New Appointment',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(formatDate(selectedDate)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setSheetState(() => selectedTime = picked);
                          }
                        },
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text(selectedTime.format(ctx)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: serviceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Service',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: staffCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Staff',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Book Appointment'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/appointments', data: {
          'date': formatDateApi(selectedDate),
          'time': '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
          'customerName': nameCtrl.text.trim(),
          'customerPhone': phoneCtrl.text.trim(),
          'service': serviceCtrl.text.trim(),
          'assignedStaff': staffCtrl.text.trim(),
          'notes': notesCtrl.text.trim(),
          'status': 'SCHEDULED',
        });
        ref.invalidate(appointmentsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment booked'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }

    nameCtrl.dispose();
    phoneCtrl.dispose();
    serviceCtrl.dispose();
    staffCtrl.dispose();
    notesCtrl.dispose();
  }
}

// ── Calendar Strip ─────────────────────────────────────────────

class _CalendarStrip extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _CalendarStrip({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = startOfWeek.add(Duration(days: index));
          final isSelected = date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

          return GestureDetector(
            onTap: () => onDateSelected(date),
            child: Container(
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : isToday
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.5)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      )
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        [date.weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Appointment Card ───────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final ValueChanged<String> onStatusChange;

  const _AppointmentCard({
    required this.appointment,
    required this.onStatusChange,
  });

  static const _statusColors = {
    'SCHEDULED': Color(0xFF2563EB),
    'CONFIRMED': Color(0xFF0891B2),
    'IN_PROGRESS': Color(0xFFEAB308),
    'COMPLETED': Color(0xFF16A34A),
    'CANCELLED': Color(0xFFDC2626),
    'NO_SHOW': Color(0xFF64748B),
  };

  List<String> _availableActions(String status) {
    switch (status) {
      case 'SCHEDULED':
        return ['CONFIRMED', 'CANCELLED', 'NO_SHOW'];
      case 'CONFIRMED':
        return ['IN_PROGRESS', 'CANCELLED', 'NO_SHOW'];
      case 'IN_PROGRESS':
        return ['COMPLETED', 'CANCELLED'];
      default:
        return [];
    }
  }

  static const _actionLabels = {
    'CONFIRMED': 'Confirm',
    'IN_PROGRESS': 'Start',
    'COMPLETED': 'Complete',
    'CANCELLED': 'Cancel',
    'NO_SHOW': 'No-Show',
  };

  @override
  Widget build(BuildContext context) {
    final time = appointment['time'] ?? appointment['timeSlot'] ?? '-';
    final customer =
        appointment['customerName'] ?? appointment['customer'] ?? '-';
    final service = appointment['service'] ?? '-';
    final staff = appointment['assignedStaff'] ?? appointment['staff'] ?? '';
    final status = appointment['status'] ?? 'SCHEDULED';
    final statusColor = _statusColors[status] ?? Colors.grey;
    final actions = _availableActions(status);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        service,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (staff.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    staff,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: actions.map((action) {
                  final isNegative =
                      action == 'CANCELLED' || action == 'NO_SHOW';
                  return SizedBox(
                    height: 30,
                    child: isNegative
                        ? OutlinedButton(
                            onPressed: () => onStatusChange(action),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFDC2626)),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(_actionLabels[action] ?? action,
                                style: const TextStyle(fontSize: 12)),
                          )
                        : FilledButton(
                            onPressed: () => onStatusChange(action),
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(_actionLabels[action] ?? action,
                                style: const TextStyle(fontSize: 12)),
                          ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
