import 'dart:typed_data';
import 'dart:html' as html;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/radiology_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_theme.dart';

class RadiologyScreen extends ConsumerWidget {
  const RadiologyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(radiologyProvider);
    final user = ref.watch(currentUserProvider);

    final filters = [
      {'value': 'all', 'label': 'الكل'},
      {'value': 'pending', 'label': 'بانتظار التصوير'},
      {'value': 'in_progress', 'label': 'جارٍ'},
      {'value': 'completed', 'label': 'مكتمل'},
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                              .read(radiologyProvider.notifier)
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
                onPressed: () => _showAddRequestDialog(context, ref, user!),
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
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : state.filtered.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.document_scanner_outlined,
                          size: 64,
                          color: AppTheme.textSecondary,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'لا يوجد طلبات',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: state.filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final req = state.filtered[index];
                      return _RadiologyCard(
                        request: req,
                        onStatusChange: (s) => ref
                            .read(radiologyProvider.notifier)
                            .updateStatus(req.id, s),
                        onAddResult: () => _showResultDialog(context, ref, req),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddRequestDialog(BuildContext context, WidgetRef ref, user) async {
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

    final scanTypes = [
      'أشعة سينية X-Ray',
      'أشعة مقطعية CT Scan',
      'رنين مغناطيسي MRI',
      'موجات صوتية Ultrasound',
      'تلفزيونية Fluoroscopy',
      'تصوير الثدي Mammography',
      'سينتيغرافيا Nuclear Scan',
      'أشعة عظام DEXA',
    ];

    String? selectedPatientId;
    String? selectedScanType;
    bool useCustomScan = false;
    final customScanController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('طلب أشعة جديد'),
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
                    if (!useCustomScan)
                      DropdownButtonFormField<String>(
                        value: selectedScanType,
                        decoration: const InputDecoration(
                          labelText: 'نوع الأشعة *',
                          prefixIcon: Icon(Icons.document_scanner_outlined),
                        ),
                        items: scanTypes
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => selectedScanType = v),
                        validator: (v) => v == null && !useCustomScan
                            ? 'اختر نوع الأشعة'
                            : null,
                      ),
                    if (useCustomScan)
                      TextFormField(
                        controller: customScanController,
                        decoration: const InputDecoration(
                          labelText: 'نوع الأشعة *',
                          prefixIcon: Icon(Icons.document_scanner_outlined),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'أدخل نوع الأشعة' : null,
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => useCustomScan = !useCustomScan),
                        icon: Icon(
                          useCustomScan
                              ? Icons.list_rounded
                              : Icons.edit_outlined,
                          size: 16,
                        ),
                        label: Text(
                          useCustomScan ? 'اختر من القائمة' : 'أدخل نوع مخصص',
                        ),
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
                      final scanType = useCustomScan
                          ? customScanController.text.trim()
                          : selectedScanType!;
                      final success = await ref
                          .read(radiologyProvider.notifier)
                          .addRequest(
                            patientId: selectedPatientId!,
                            requestedBy: user.id,
                            scanType: scanType,
                          );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'تم إضافة الطلب بنجاح'
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

  void _showResultDialog(
    BuildContext context,
    WidgetRef ref,
    RadiologyRequest request,
  ) {
    final reportController = TextEditingController(text: request.report ?? '');
    final linkController = TextEditingController(
      text: request.isExternalLink ? request.fileUrl! : '',
    );
    bool isLoading = false;
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    bool useLink = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('نتيجة: ${request.scanType}'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
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
                    controller: reportController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'التقرير',
                      hintText: 'أدخل تقرير الأشعة...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'الصورة:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => setState(() => useLink = !useLink),
                        icon: Icon(
                          useLink
                              ? Icons.upload_file_outlined
                              : Icons.link_rounded,
                          size: 16,
                        ),
                        label: Text(useLink ? 'رفع ملف' : 'إدخال رابط'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (useLink)
                    TextFormField(
                      controller: linkController,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'رابط الصورة',
                        hintText: 'https://...',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                    ),
                  if (!useLink) ...[
                    if (selectedImageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          selectedImageBytes!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedImageName ?? '',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ] else if (request.fileUrl != null &&
                        !request.isExternalLink) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          request.fileUrl!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: () async {
                        final input = html.FileUploadInputElement()
                          ..accept = 'image/*,.pdf'
                          ..click();
                        await input.onChange.first;
                        if (input.files!.isNotEmpty) {
                          final file = input.files![0];
                          final reader = html.FileReader();
                          reader.readAsArrayBuffer(file);
                          await reader.onLoad.first;
                          final bytes = reader.result as List<int>;
                          setState(() {
                            selectedImageBytes = Uint8List.fromList(bytes);
                            selectedImageName = file.name;
                          });
                        }
                      },
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('اختر ملف'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                  ],
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
                      setState(() => isLoading = true);
                      String? finalUrl = useLink
                          ? (linkController.text.isEmpty
                                ? null
                                : linkController.text.trim())
                          : (selectedImageBytes == null
                                ? request.fileUrl
                                : null);

                      if (!useLink &&
                          selectedImageBytes != null &&
                          selectedImageName != null) {
                        finalUrl = await ref
                            .read(radiologyProvider.notifier)
                            .uploadImage(
                              request.id,
                              selectedImageBytes!,
                              selectedImageName!,
                            );
                      }

                      final success = await ref
                          .read(radiologyProvider.notifier)
                          .updateResult(
                            requestId: request.id,
                            report: reportController.text.isEmpty
                                ? null
                                : reportController.text.trim(),
                            fileUrl: finalUrl,
                          );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'تم حفظ النتيجة بنجاح'
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
                  : const Text('حفظ النتيجة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadiologyCard extends StatelessWidget {
  final RadiologyRequest request;
  final Function(String) onStatusChange;
  final VoidCallback onAddResult;

  const _RadiologyCard({
    required this.request,
    required this.onStatusChange,
    required this.onAddResult,
  });

  void _showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              scaleEnabled: true,
              minScale: 0.5,
              maxScale: 5,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 64,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                tooltip: 'فتح في تبويب جديد',
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: request.statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.document_scanner_rounded,
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
                  request.scanType,
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
                      Icons.person_outline,
                      size: 13,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      request.patientName ?? '',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.medical_services_outlined,
                      size: 13,
                      color: AppTheme.textSecondary,
                    ),
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
                if (request.hasReport) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      request.report!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
                if (request.fileUrl != null && request.isExternalLink) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => launchUrl(
                      Uri.parse(request.fileUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            request.fileUrl!,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (request.fileUrl != null && !request.isExternalLink)
                TextButton.icon(
                  onPressed: () => _showImageDialog(context, request.fileUrl!),
                  icon: const Icon(Icons.zoom_in_rounded, size: 16),
                  label: const Text('عرض الصورة'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                  ),
                ),
              TextButton.icon(
                onPressed: onAddResult,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(
                  request.hasReport || request.fileUrl != null
                      ? 'تعديل النتيجة'
                      : 'إضافة نتيجة',
                ),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
              ),
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                onSelected: onStatusChange,
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'pending',
                    child: Text('بانتظار التصوير'),
                  ),
                  const PopupMenuItem(
                    value: 'in_progress',
                    child: Text('جارٍ'),
                  ),
                  const PopupMenuItem(value: 'completed', child: Text('مكتمل')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                      Icon(
                        Icons.arrow_drop_down,
                        color: request.statusColor,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
