import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/staff_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffProvider);
    final user = ref.watch(currentUserProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) =>
                      ref.read(staffProvider.notifier).search(v),
                  decoration: const InputDecoration(
                    hintText: 'بحث باسم الموظف أو الدور...',
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
                onPressed: () =>
                    _showAddStaffDialog(context, ref, user!.tenantId),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('موظف جديد'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(150, 48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${state.filtered.length} موظف',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : state.filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'لا يوجد موظفون بعد',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: state.filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final member = state.filtered[index];
                          return _StaffCard(
                            member: member,
                            onToggle: () => ref
                                .read(staffProvider.notifier)
                                .toggleActive(member.id, member.isActive),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddStaffDialog(
      BuildContext context, WidgetRef ref, String tenantId) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedRole;
    bool isLoading = false;

    final roles = [
      {'value': 'doctor', 'label': 'دكتور'},
      {'value': 'clinic_receptionist', 'label': 'ريسيبشن عيادة'},
      {'value': 'center_receptionist', 'label': 'ريسيبشن المركز'},
      {'value': 'nurse', 'label': 'ممرض'},
      {'value': 'lab_technician', 'label': 'مختبر'},
      {'value': 'radiology_technician', 'label': 'أشعة'},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إضافة موظف جديد'),
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
                      controller: emailController,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'أدخل البريد';
                        if (!v.contains('@')) return 'بريد غير صحيح';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور *',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
                        if (v.length < 8) return 'كلمة المرور قصيرة (8 أحرف على الأقل)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'الدور الوظيفي *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: roles
                          .map((r) => DropdownMenuItem(
                                value: r['value'],
                                child: Text(r['label']!),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => selectedRole = v),
                      validator: (v) =>
                          v == null ? 'اختر الدور الوظيفي' : null,
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
              style:
                  ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => isLoading = true);
                      final success =
                          await ref.read(staffProvider.notifier).addStaff(
                                email: emailController.text.trim(),
                                password: passwordController.text.trim(),
                                fullName: nameController.text.trim(),
                                role: selectedRole!,
                                tenantId: tenantId,
                                phone: phoneController.text.trim().isEmpty
                                    ? null
                                    : phoneController.text.trim(),
                              );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'تم إضافة الموظف بنجاح'
                                : 'حدث خطأ — تأكد من صلاحيات الـ Service Role'),
                            backgroundColor:
                                success ? AppTheme.primary : AppTheme.error,
                          ),
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final StaffMember member;
  final VoidCallback onToggle;

  const _StaffCard({required this.member, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: member.isActive ? AppTheme.border : AppTheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: member.roleColor.withOpacity(0.1),
            child: Text(
              member.fullName.substring(0, 1),
              style: TextStyle(
                color: member.roleColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (member.phone != null) ...[
                      const Icon(Icons.phone_outlined,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        member.phone!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: member.roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              member.roleLabel,
              style: TextStyle(
                color: member.roleColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: member.isActive,
            onChanged: (_) => onToggle(),
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}