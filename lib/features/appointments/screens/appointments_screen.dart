import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical_center/core/supabase/supabase_config.dart';
import '../providers/appointments_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../patients/providers/patients_provider.dart';
import '../../clinics/providers/clinics_provider.dart';
import '../../staff/providers/staff_provider.dart';
import '../../../core/theme/app_theme.dart';

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appointmentsProvider);
    final user = ref.watch(currentUserProvider);

    final filters = [
      {'value': 'all', 'label': 'الكل'},
      {'value': 'pending', 'label': 'بانتظار التأكيد'},
      {'value': 'confirmed', 'label': 'مؤكد'},
      {'value': 'in_progress', 'label': 'جارٍ'},
      {'value': 'completed', 'label': 'مكتمل'},
      {'value': 'cancelled', 'label': 'ملغى'},
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date picker + Add button
          Row(
            children: [
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: state.selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    ref.read(appointmentsProvider.notifier).setDate(date);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(10),
                    color: AppTheme.surface,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${state.selectedDate.year}/${state.selectedDate.month.toString().padLeft(2, '0')}/${state.selectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  final prev = state.selectedDate.subtract(
                    const Duration(days: 1),
                  );
                  ref.read(appointmentsProvider.notifier).setDate(prev);
                },
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'اليوم السابق',
              ),
              IconButton(
                onPressed: () {
                  final next = state.selectedDate.add(const Duration(days: 1));
                  ref.read(appointmentsProvider.notifier).setDate(next);
                },
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'اليوم التالي',
              ),
              TextButton(
                onPressed: () {
                  ref
                      .read(appointmentsProvider.notifier)
                      .setDate(DateTime.now());
                },
                child: const Text('اليوم'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddAppointmentDialog(context, ref, user!),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('موعد جديد'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(150, 48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final isSelected = state.filterStatus == f['value'];
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilterChip(
                    label: Text(f['label']!),
                    selected: isSelected,
                    onSelected: (_) => ref
                        .read(appointmentsProvider.notifier)
                        .setFilter(f['value']!),
                    selectedColor: AppTheme.primary.withOpacity(0.15),
                    checkmarkColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            '${state.filtered.length} موعد',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),

          // List
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : state.filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 64,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'لا يوجد مواعيد',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: state.filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final apt = state.filtered[index];
                      return _AppointmentCard(
                        appointment: apt,
                        onStatusChange: (newStatus) => ref
                            .read(appointmentsProvider.notifier)
                            .updateStatus(apt.id, newStatus),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddAppointmentDialog(
    BuildContext context,
    WidgetRef ref,
    appUser,
  ) async {
    // جيب البيانات مباشرة
    showDialog(
      context: context,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );

    final patientsData = await SupabaseConfig.client
        .from('patients')
        .select()
        .order('full_name');
    final clinicsData = await SupabaseConfig.client
        .from('clinics')
        .select()
        .eq('is_active', true);
    final doctorsData = await SupabaseConfig.client
        .from('users')
        .select()
        .eq('role', 'doctor')
        .eq('is_active', true);

    if (!context.mounted) return;
    Navigator.pop(context); // أغلق loading

    final patients = (patientsData as List)
        .map((p) => {'id': p['id'], 'name': p['full_name']})
        .toList();
    final clinics = (clinicsData as List)
        .map((c) => {'id': c['id'], 'name': c['name']})
        .toList();
    final doctors = (doctorsData as List)
        .map((d) => {'id': d['id'], 'name': d['full_name']})
        .toList();

    if (!context.mounted) return;

    String? selectedPatientId;
    String? selectedClinicId;
    String? selectedDoctorId;
    const String selectedType = 'in_person';
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إضافة موعد جديد'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedPatientId,
                      decoration: const InputDecoration(
                        labelText: 'المريض *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: patients
                          .map(
                            (p) => DropdownMenuItem(
                              value: p['id'] as String,
                              child: Text(p['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => selectedPatientId = v),
                      validator: (v) => v == null ? 'اختر المريض' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedClinicId,
                      decoration: const InputDecoration(
                        labelText: 'العيادة *',
                        prefixIcon: Icon(Icons.meeting_room_outlined),
                      ),
                      items: clinics
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(c['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => selectedClinicId = v),
                      validator: (v) => v == null ? 'اختر العيادة' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedDoctorId,
                      decoration: const InputDecoration(
                        labelText: 'الدكتور *',
                        prefixIcon: Icon(Icons.medical_services_outlined),
                      ),
                      items: doctors
                          .map(
                            (d) => DropdownMenuItem(
                              value: d['id'] as String,
                              child: Text(d['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => selectedDoctorId = v),
                      validator: (v) => v == null ? 'اختر الدكتور' : null,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_today_outlined,
                        color: AppTheme.textSecondary,
                      ),
                      title: Text(
                        '${selectedDate.year}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setState(() => selectedDate = date);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.access_time_outlined,
                        color: AppTheme.textSecondary,
                      ),
                      title: Text(
                        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                          builder: (context, child) {
                            return Localizations.override(
                              context: context,
                              locale: const Locale('en'),
                              child: child!,
                            );
                          },
                        );
                        if (time != null) {
                          setState(() => selectedTime = time);
                        }
                      },
                    ),

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => isLoading = true);

                      final scheduledAt = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      final success = await ref
                          .read(appointmentsProvider.notifier)
                          .addAppointment(
                            clinicId: selectedClinicId!,
                            patientId: selectedPatientId!,
                            doctorId: selectedDoctorId!,
                            scheduledAt: scheduledAt,
                            type: selectedType,
                            notes: notesController.text.isEmpty
                                ? null
                                : notesController.text,
                            receptionistId: appUser.id,
                          );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'تم إضافة الموعد بنجاح'
                                  : 'حدث خطأ، حاول مرة أخرى',
                            ),
                            backgroundColor: success
                                ? AppTheme.primary
                                : AppTheme.error,
                          ),
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final Function(String) onStatusChange;

  const _AppointmentCard({
    required this.appointment,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final time =
        '${appointment.scheduledAt.hour.toString().padLeft(2, '0')}:${appointment.scheduledAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // Time
          Container(
            width: 60,
            alignment: Alignment.center,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const VerticalDivider(width: 1),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.patientName ?? 'مريض',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      size: 13,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      appointment.doctorName ?? '',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.meeting_room_outlined,
                      size: 13,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      appointment.clinicName ?? '',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: appointment.type == 'video'
                  ? const Color(0xFF534AB7).withOpacity(0.1)
                  : AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              appointment.typeLabel,
              style: TextStyle(
                color: appointment.type == 'video'
                    ? const Color(0xFF534AB7)
                    : AppTheme.primary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Status dropdown
          PopupMenuButton<String>(
            onSelected: onStatusChange,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'pending',
                child: Text('بانتظار التأكيد'),
              ),
              const PopupMenuItem(value: 'confirmed', child: Text('مؤكد')),
              const PopupMenuItem(value: 'in_progress', child: Text('جارٍ')),
              const PopupMenuItem(value: 'completed', child: Text('مكتمل')),
              const PopupMenuItem(value: 'cancelled', child: Text('ملغى')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: appointment.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appointment.statusLabel,
                    style: TextStyle(
                      color: appointment.statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    color: appointment.statusColor,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
