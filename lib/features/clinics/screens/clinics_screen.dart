import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical_center/features/clinics/screens/working_hours/working_hours_screen.dart';
import '../providers/clinics_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../staff/providers/staff_provider.dart';
import '../../../core/theme/app_theme.dart';

class ClinicsScreen extends ConsumerWidget {
  const ClinicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clinicsProvider);
    final user = ref.watch(currentUserProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () =>
                    _showAddClinicDialog(context, ref, user!.tenantId),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('عيادة جديدة'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(150, 48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${state.clinics.length} عيادة',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : state.clinics.isEmpty
                ? const Center(
                    child: Text(
                      'لا يوجد عيادات بعد',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: state.clinics.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final clinic = state.clinics[index];
                      return _ClinicCard(
                        clinic: clinic,
                        onToggle: () => ref
                            .read(clinicsProvider.notifier)
                            .toggleActive(clinic.id, clinic.isActive),
                        onManageStaff: () =>
                            _showManageStaffDialog(context, ref, clinic),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddClinicDialog(
    BuildContext context,
    WidgetRef ref,
    String tenantId,
  ) {
    final nameController = TextEditingController();
    final specialtyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    final specialties = [
      'باطنية',
      'نسائية وتوليد',
      'أطفال',
      'عظام',
      'جلدية',
      'عيون',
      'أنف وأذن وحنجرة',
      'قلبية',
      'أسنان',
      'نفسية',
      'عامة',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إضافة عيادة جديدة'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم العيادة *',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'أدخل اسم العيادة' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'التخصص',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                    items: specialties
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => specialtyController.text = v ?? '',
                  ),
                ],
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
                      final success = await ref
                          .read(clinicsProvider.notifier)
                          .addClinic(
                            name: nameController.text.trim(),
                            tenantId: tenantId,
                            specialty: specialtyController.text.isEmpty
                                ? null
                                : specialtyController.text,
                          );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'تم إضافة العيادة بنجاح'
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

  void _showManageStaffDialog(
    BuildContext context,
    WidgetRef ref,
    Clinic clinic,
  ) async {
    final staffList = await ref
        .read(clinicsProvider.notifier)
        .getClinicStaff(clinic.id);

    final allStaff = ref.read(staffProvider).staff;
    final assignedIds = staffList.map((s) => s.userId).toSet();
    final availableStaff = allStaff
        .where((s) => !assignedIds.contains(s.id))
        .toList();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('موظفو ${clinic.name}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // موظفون حاليون
                if (staffList.isNotEmpty) ...[
                  const Text(
                    'الموظفون الحاليون',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...staffList.map(
                    (member) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: member.roleColor.withOpacity(0.1),
                        child: Text(
                          member.fullName.substring(0, 1),
                          style: TextStyle(color: member.roleColor),
                        ),
                      ),
                      title: Text(member.fullName),
                      subtitle: Text(member.roleLabel),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: AppTheme.error,
                        ),
                        onPressed: () async {
                          await ref
                              .read(clinicsProvider.notifier)
                              .removeStaff(member.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                  const Divider(),
                ],

                // إضافة موظف
                if (availableStaff.isNotEmpty) ...[
                  const Text(
                    'إضافة موظف',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...availableStaff
                      .where(
                        (s) => [
                          'doctor',
                          'clinic_receptionist',
                          'nurse',
                        ].contains(s.role),
                      )
                      .map(
                        (member) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: member.roleColor.withOpacity(0.1),
                            child: Text(
                              member.fullName.substring(0, 1),
                              style: TextStyle(color: member.roleColor),
                            ),
                          ),
                          title: Text(member.fullName),
                          subtitle: Text(member.roleLabel),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: AppTheme.primary,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(clinicsProvider.notifier)
                                  .assignStaff(
                                    clinicId: clinic.id,
                                    userId: member.id,
                                    role: member.role,
                                  );
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ),
                      ),
                ],

                if (staffList.isEmpty && availableStaff.isEmpty)
                  const Center(
                    child: Text(
                      'لا يوجد موظفون متاحون',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClinicCard extends StatelessWidget {
  final Clinic clinic;
  final VoidCallback onToggle;
  final VoidCallback onManageStaff;

  const _ClinicCard({
    required this.clinic,
    required this.onToggle,
    required this.onManageStaff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: clinic.isActive
              ? AppTheme.border
              : AppTheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.meeting_room_rounded,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clinic.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (clinic.specialty != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    clinic.specialty!,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onManageStaff,
            icon: const Icon(Icons.people_outline, size: 18),
            label: const Text('الموظفون'),
          ),

          // بعد زر "الموظفون"
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkingHoursScreen(
                  clinicId: clinic.id,
                  clinicName: clinic.name,
                ),
              ),
            ),
            icon: const Icon(Icons.schedule_outlined, size: 18),
            label: const Text('أوقات العمل'),
          ),
          const SizedBox(width: 8),
          Switch(
            value: clinic.isActive,
            onChanged: (_) => onToggle(),
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
