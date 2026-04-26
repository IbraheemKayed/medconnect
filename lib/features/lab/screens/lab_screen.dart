import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lab_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_theme.dart';

class LabScreen extends ConsumerWidget {
  const LabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labProvider);
    final user = ref.watch(currentUserProvider);

    final filters = [
      {'value': 'all', 'label': 'الكل'},
      {'value': 'pending', 'label': 'بانتظار التحليل'},
      {'value': 'in_progress', 'label': 'جارٍ'},
      {'value': 'completed', 'label': 'مكتمل'},
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
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
                              .read(labProvider.notifier)
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
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    _showAddRequestDialog(context, ref, user!),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('طلب جديد'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(140, 48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            '${state.filtered.length} طلب',
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
                    child: CircularProgressIndicator(
                        color: AppTheme.primary))
                : state.filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.biotech_outlined,
                                size: 64,
                                color: AppTheme.textSecondary),
                            SizedBox(height: 12),
                            Text(
                              'لا يوجد طلبات',
                              style: TextStyle(
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: state.filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final req = state.filtered[index];
                          return _LabRequestCard(
                            request: req,
                            onStatusChange: (s) => ref
                                .read(labProvider.notifier)
                                .updateStatus(req.id, s),
                            onAddResult: () =>
                                _showResultDialog(context, ref, req),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddRequestDialog(
      BuildContext context, WidgetRef ref, user) async {
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

    if (!context.mounted) return;
    Navigator.pop(context);

    final patients = (patientsData as List)
        .map((p) => {'id': p['id'], 'name': p['full_name']})
        .toList();

    final commonTests = [
      'صورة دم كاملة CBC',
      'سكر الدم FBS',
      'وظائف الكلى',
      'وظائف الكبد',
      'الغدة الدرقية TSH',
      'تحليل بول',
      'دهون الدم',
      'فيتامين D',
      'فيتامين B12',
      'CRP',
      'HbA1c',
    ];

    String? selectedPatientId;
    String? selectedTest;
    final customTestController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool useCustomTest = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('طلب تحليل جديد'),
          content: SizedBox(
            width: 480,
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
                          .map((p) => DropdownMenuItem(
                                value: p['id'] as String,
                                child: Text(p['name'] as String),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => selectedPatientId = v),
                      validator: (v) =>
                          v == null ? 'اختر المريض' : null,
                    ),
                    const SizedBox(height: 12),
                    if (!useCustomTest)
                      DropdownButtonFormField<String>(
                        value: selectedTest,
                        decoration: const InputDecoration(
                          labelText: 'نوع التحليل *',
                          prefixIcon: Icon(Icons.biotech_outlined),
                        ),
                        items: commonTests
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => selectedTest = v),
                        validator: (v) =>
                            v == null && !useCustomTest
                                ? 'اختر نوع التحليل'
                                : null,
                      ),
                    if (useCustomTest)
                      TextFormField(
                        controller: customTestController,
                        decoration: const InputDecoration(
                          labelText: 'اسم التحليل *',
                          prefixIcon: Icon(Icons.biotech_outlined),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'أدخل اسم التحليل'
                            : null,
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(
                            () => useCustomTest = !useCustomTest),
                        icon: Icon(
                          useCustomTest
                              ? Icons.list_rounded
                              : Icons.edit_outlined,
                          size: 16,
                        ),
                        label: Text(useCustomTest
                            ? 'اختر من القائمة'
                            : 'أدخل اسم مخصص'),
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
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(100, 40)),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => isLoading = true);

                      final testName = useCustomTest
                          ? customTestController.text.trim()
                          : selectedTest!;

                      final success = await ref
                          .read(labProvider.notifier)
                          .addRequest(
                            patientId: selectedPatientId!,
                            requestedBy: user.id,
                            testName: testName,
                          );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'تم إضافة الطلب بنجاح'
                                : 'حدث خطأ، حاول مرة أخرى'),
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
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResultDialog(
      BuildContext context, WidgetRef ref, LabRequest request) {
    final resultController = TextEditingController(
        text: request.result ?? '');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('نتيجة: ${request.testName}'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المريض: ${request.patientName ?? ''}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: resultController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'النتيجة *',
                    hintText: 'أدخل نتيجة التحليل...',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(100, 40)),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (resultController.text.isEmpty) return;
                      setState(() => isLoading = true);

                      final success = await ref
                          .read(labProvider.notifier)
                          .updateResult(
                            requestId: request.id,
                            result: resultController.text.trim(),
                          );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'تم حفظ النتيجة بنجاح'
                                : 'حدث خطأ، حاول مرة أخرى'),
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
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('حفظ النتيجة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabRequestCard extends StatelessWidget {
  final LabRequest request;
  final Function(String) onStatusChange;
  final VoidCallback onAddResult;

  const _LabRequestCard({
    required this.request,
    required this.onStatusChange,
    required this.onAddResult,
  });

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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: request.statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.biotech_rounded,
              color: request.statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.testName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      request.patientName ?? '',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.medical_services_outlined,
                        size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      request.requestedByName ?? '',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (request.result != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: Text(
                      request.result!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Actions
          if (request.status != 'completed')
            TextButton.icon(
              onPressed: onAddResult,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(request.result == null
                  ? 'إضافة نتيجة'
                  : 'تعديل النتيجة'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
              ),
            ),

          const SizedBox(width: 8),

          // Status
          PopupMenuButton<String>(
            onSelected: onStatusChange,
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'pending',
                  child: Text('بانتظار التحليل')),
              const PopupMenuItem(
                  value: 'in_progress', child: Text('جارٍ')),
              const PopupMenuItem(
                  value: 'completed', child: Text('مكتمل')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: request.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    request.statusLabel,
                    style: TextStyle(
                      color: request.statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down,
                      color: request.statusColor, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}