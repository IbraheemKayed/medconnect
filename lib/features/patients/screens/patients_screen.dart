import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/patients_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class PatientsScreen extends ConsumerWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(patientsProvider);
    final user = ref.watch(currentUserProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search + Add
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) =>
                      ref.read(patientsProvider.notifier).search(v),
                  decoration: const InputDecoration(
                    hintText: 'بحث باسم المريض أو رقم الهاتف...',
                    prefixIcon: Icon(Icons.search_rounded),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddPatientDialog(context, ref, user!.tenantId),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('مريض جديد'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(150, 48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Count
          Text(
            '${state.filtered.length} مريض',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
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
                              Icons.people_outline_rounded,
                              size: 64,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              state.searchQuery.isEmpty
                                  ? 'لا يوجد مرضى بعد'
                                  : 'لا توجد نتائج',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(patientsProvider.notifier).fetchPatients(),
                        child: ListView.separated(
                          itemCount: state.filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final patient = state.filtered[index];
                            return _PatientCard(patient: patient);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddPatientDialog(
      BuildContext context, WidgetRef ref, String tenantId) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedGender;
    String? selectedBlood;
    DateTime? selectedDob;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إضافة مريض جديد'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'أدخل الاسم' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'الجنس',
                        prefixIcon: Icon(Icons.wc_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('ذكر')),
                        DropdownMenuItem(value: 'female', child: Text('أنثى')),
                      ],
                      onChanged: (v) => setState(() => selectedGender = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedBlood,
                      decoration: const InputDecoration(
                        labelText: 'فصيلة الدم',
                        prefixIcon: Icon(Icons.bloodtype_outlined),
                      ),
                      items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                          .map((b) =>
                              DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (v) => setState(() => selectedBlood = v),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cake_outlined,
                          color: AppTheme.textSecondary),
                      title: Text(
                        selectedDob == null
                            ? 'تاريخ الميلاد'
                            : '${selectedDob!.year}/${selectedDob!.month}/${selectedDob!.day}',
                        style: TextStyle(
                          color: selectedDob == null
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime(2000),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => selectedDob = date);
                        }
                      },
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
                      final success = await ref
                          .read(patientsProvider.notifier)
                          .addPatient(
                            fullName: nameController.text.trim(),
                            tenantId: tenantId,
                            phone: phoneController.text.trim().isEmpty
                                ? null
                                : phoneController.text.trim(),
                            gender: selectedGender,
                            bloodType: selectedBlood,
                            dob: selectedDob,
                          );
                      if (context.mounted) {
                        Navigator.pop(context);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إضافة المريض بنجاح'),
                              backgroundColor: AppTheme.primary,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('حدث خطأ، حاول مرة أخرى'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
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

class _PatientCard extends StatelessWidget {
  final Patient patient;
  const _PatientCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            child: Text(
              patient.fullName.substring(0, 1),
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (patient.phone != null) ...[
                      const Icon(Icons.phone_outlined,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        patient.phone!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (patient.age != null) ...[
                      const Icon(Icons.cake_outlined,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${patient.age} سنة',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Badges
          Row(
            children: [
              if (patient.genderLabel.isNotEmpty)
                _badge(patient.genderLabel, const Color(0xFF378ADD)),
              if (patient.bloodType != null) ...[
                const SizedBox(width: 8),
                _badge(patient.bloodType!, AppTheme.error),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}