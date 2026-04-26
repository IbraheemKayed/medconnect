import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical_center/core/supabase/supabase_config.dart';
import '../providers/medical_record_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class PatientFileScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String? appointmentId;

  const PatientFileScreen({
    super.key,
    required this.patientId,
    this.appointmentId,
  });

  @override
  ConsumerState<PatientFileScreen> createState() =>
      _PatientFileScreenState();
}

class _PatientFileScreenState extends ConsumerState<PatientFileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(patientFileProvider.notifier).load(widget.patientId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientFileProvider);

    return state.when(
      loading: () => const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('خطأ: $e')),
      ),
      data: (file) {
        if (file == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: Text(file.fullName),
            backgroundColor: AppTheme.surface,
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              tabs: const [
  Tab(text: 'الملف'),
  Tab(text: 'التحاليل'),
  Tab(text: 'الأشعة'),
  Tab(text: 'الوصفات'),
  Tab(text: 'الحساسيات'),
],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
           children: [
  _buildFileTab(file),
  _buildLabTab(file),
  _buildRadiologyTab(file),
  _buildPrescriptionsTab(file),
  _buildAllergiesTab(file),
],
          ),
        );
      },
    );
  }

  Widget _buildFileTab(PatientFile file) {
    final user = ref.read(currentUserProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Text(
                    file.fullName.substring(0, 1),
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(file.fullName,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        children: [
                          if (file.phone != null)
                            _InfoChip(
                                icon: Icons.phone_outlined,
                                label: file.phone!),
                          if (file.age != null)
                            _InfoChip(
                                icon: Icons.cake_outlined,
                                label: '${file.age} سنة'),
                          if (file.gender != null)
                            _InfoChip(
                                icon: Icons.wc_rounded,
                                label: file.gender == 'male'
                                    ? 'ذكر'
                                    : 'أنثى'),
                          if (file.bloodType != null)
                            _InfoChip(
                                icon: Icons.bloodtype_outlined,
                                label: file.bloodType!,
                                color: AppTheme.error),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Add record button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('السجلات الطبية',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              ElevatedButton.icon(
                onPressed: () =>
                    _showAddRecordDialog(file.patientId, user!.id),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة سجل'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(130, 40)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (file.records.isEmpty)
            _EmptyState(
                icon: Icons.folder_open_outlined,
                label: 'لا يوجد سجلات طبية بعد')
          else
            ...file.records.map((record) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.medical_information_outlined,
                                size: 16, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text(record.doctorName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary)),
                            const Spacer(),
                            Text(
                              '${record.createdAt.year}/${record.createdAt.month.toString().padLeft(2, '0')}/${record.createdAt.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                        if (record.diagnosis != null) ...[
                          const SizedBox(height: 8),
                          const Text('التشخيص:',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                          Text(record.diagnosis!,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary)),
                        ],
                        if (record.notes != null) ...[
                          const SizedBox(height: 8),
                          const Text('ملاحظات:',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                          Text(record.notes!,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary)),
                        ],
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildLabTab(PatientFile file) {
    final user = ref.read(currentUserProvider);
    final commonTests = [
      'صورة دم كاملة CBC', 'سكر الدم FBS', 'وظائف الكلى',
      'وظائف الكبد', 'الغدة الدرقية TSH', 'تحليل بول',
      'دهون الدم', 'فيتامين D', 'HbA1c', 'CRP',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('طلبات التحاليل',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              ElevatedButton.icon(
                onPressed: () => _showAddLabDialog(
                    file.patientId, user!.id, commonTests),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('طلب تحليل'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(130, 40)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (file.labRequests.isEmpty)
            _EmptyState(
                icon: Icons.biotech_outlined,
                label: 'لا يوجد طلبات تحاليل')
          else
            ...file.labRequests.map((req) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LabRadCard(
                    title: req.testName,
                    status: req.status,
                    result: req.result,
                    date: req.createdAt,
                    statusLabel: req.status == 'pending'
                        ? 'انتظار'
                        : req.status == 'in_progress'
                            ? 'جارٍ'
                            : 'مكتمل',
                    statusColor: req.status == 'pending'
                        ? const Color(0xFFBA7517)
                        : req.status == 'in_progress'
                            ? const Color(0xFF378ADD)
                            : AppTheme.primary,
                    icon: Icons.biotech_rounded,
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildRadiologyTab(PatientFile file) {
    final user = ref.read(currentUserProvider);
    final scanTypes = [
      'أشعة سينية X-Ray', 'أشعة مقطعية CT Scan',
      'رنين مغناطيسي MRI', 'موجات صوتية Ultrasound',
      'تلفزيونية Fluoroscopy',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('طلبات الأشعة',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              ElevatedButton.icon(
                onPressed: () => _showAddRadiologyDialog(
                    file.patientId, user!.id, scanTypes),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('طلب أشعة'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(130, 40)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (file.radiologyRequests.isEmpty)
            _EmptyState(
                icon: Icons.document_scanner_outlined,
                label: 'لا يوجد طلبات أشعة')
          else
            ...file.radiologyRequests.map((req) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LabRadCard(
                    title: req.scanType,
                    status: req.status,
                    result: req.report,
                    date: req.createdAt,
                    statusLabel: req.status == 'pending'
                        ? 'انتظار'
                        : req.status == 'in_progress'
                            ? 'جارٍ'
                            : 'مكتمل',
                    statusColor: req.status == 'pending'
                        ? const Color(0xFFBA7517)
                        : req.status == 'in_progress'
                            ? const Color(0xFF378ADD)
                            : AppTheme.primary,
                    icon: Icons.document_scanner_rounded,
                    fileUrl: req.fileUrl,
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildPrescriptionsTab(PatientFile file) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('الوصفات الطبية',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            if (file.records.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () =>
                    _showAddPrescriptionDialog(file.records.first.id),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة دواء'),
                style:
                    ElevatedButton.styleFrom(minimumSize: const Size(130, 40)),
              ),
          ],
        ),
        if (file.records.isEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFBA7517).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFBA7517).withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFBA7517), size: 18),
                SizedBox(width: 8),
                Text('لازم تضيف سجل طبي أولاً قبل إضافة وصفة',
                    style: TextStyle(color: Color(0xFFBA7517), fontSize: 13)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (file.prescriptions.isEmpty)
          _EmptyState(
              icon: Icons.medication_outlined, label: 'لا يوجد وصفات طبية')
        else
          ...file.prescriptions.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.medication_rounded,
                            color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.medicineName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                    fontSize: 15)),
                            if (p.dosage != null)
                              Text(p.dosage!,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13)),
                            if (p.duration != null)
                              Text('المدة: ${p.duration}',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13)),
                            if (p.notes != null)
                              Text(p.notes!,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    ),
  );
}

Widget _buildAllergiesTab(PatientFile file) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('الحساسيات',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            ElevatedButton.icon(
              onPressed: () => _showAddAllergyDialog(file.patientId),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('إضافة حساسية'),
              style:
                  ElevatedButton.styleFrom(minimumSize: const Size(140, 40)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (file.allergies.isEmpty)
          _EmptyState(
              icon: Icons.no_meals_outlined, label: 'لا يوجد حساسيات مسجلة')
        else
          ...file.allergies.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: a.severityColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: a.severityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.warning_amber_rounded,
                            color: a.severityColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.allergyName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                    fontSize: 15)),
                            if (a.notes != null)
                              Text(a.notes!,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13)),
                          ],
                        ),
                      ),
                      if (a.severity != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: a.severityColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(a.severityLabel,
                              style: TextStyle(
                                  color: a.severityColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => ref
                            .read(patientFileProvider.notifier)
                            .deleteAllergy(a.id, file.patientId),
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppTheme.error, size: 20),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    ),
  );
}

void _showAddPrescriptionDialog(String medicalRecordId) {
  final medicineController = TextEditingController();
  final dosageController = TextEditingController();
  final durationController = TextEditingController();
  final notesController = TextEditingController();
  List<Map<String, dynamic>> suggestions = [];
  bool isLoading = false;
  bool showSuggestions = false;

  Future<void> searchMedicines(String query, StateSetter setState) async {
    if (query.length < 2) {
      setState(() {
        suggestions = [];
        showSuggestions = false;
      });
      return;
    }
    try {
      final data = await SupabaseConfig.client
          .from('medicines')
          .select()
          .or('name_ar.ilike.%$query%,name_en.ilike.%$query%')
          .limit(8);
      setState(() {
        suggestions = (data as List).cast<Map<String, dynamic>>();
        showSuggestions = suggestions.isNotEmpty;
      });
    } catch (e) {
      setState(() => showSuggestions = false);
    }
  }

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('إضافة دواء'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Medicine autocomplete
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: medicineController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الدواء *',
                      prefixIcon: Icon(Icons.medication_outlined),
                      hintText: 'ابدأ بالكتابة للبحث...',
                    ),
                    onChanged: (v) => searchMedicines(v, setState),
                  ),
                  if (showSuggestions)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: suggestions.map((med) {
                          return InkWell(
                            onTap: () {
                              medicineController.text =
                                  med['name_ar'] as String;
                              setState(() => showSuggestions = false);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.medication_outlined,
                                      size: 16,
                                      color: AppTheme.textSecondary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(med['name_ar'] as String,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.textPrimary)),
                                        if (med['name_en'] != null)
                                          Text(med['name_en'] as String,
                                              style: const TextStyle(
                                                  color:
                                                      AppTheme.textSecondary,
                                                  fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  if (med['category'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        med['category'] as String,
                                        style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: dosageController,
                decoration: const InputDecoration(
                  labelText: 'الجرعة',
                  hintText: 'مثال: حبة مرتين يومياً بعد الأكل',
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: durationController,
                decoration: const InputDecoration(
                  labelText: 'المدة',
                  hintText: 'مثال: 7 أيام',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
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
            style:
                ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
            onPressed: isLoading
                ? null
                : () async {
                    if (medicineController.text.isEmpty) return;
                    setState(() => isLoading = true);
                    final success = await ref
                        .read(patientFileProvider.notifier)
                        .addPrescription(
                          medicalRecordId: medicalRecordId,
                          medicineName: medicineController.text.trim(),
                          dosage: dosageController.text.isEmpty
                              ? null
                              : dosageController.text.trim(),
                          duration: durationController.text.isEmpty
                              ? null
                              : durationController.text.trim(),
                          notes: notesController.text.isEmpty
                              ? null
                              : notesController.text.trim(),
                        );
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إضافة الدواء'),
                            backgroundColor: AppTheme.primary,
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
                        strokeWidth: 2, color: Colors.white))
                : const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}

void _showAddAllergyDialog(String patientId) {
  final allergyController = TextEditingController();
  final notesController = TextEditingController();
  String? selectedSeverity;
  bool isLoading = false;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('إضافة حساسية'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: allergyController,
                decoration: const InputDecoration(
                  labelText: 'اسم الحساسية *',
                  hintText: 'مثال: البنسلين، الفول السوداني...',
                  prefixIcon: Icon(Icons.warning_amber_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedSeverity,
                decoration: const InputDecoration(
                  labelText: 'الشدة',
                  prefixIcon: Icon(Icons.thermostat_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'mild', child: Text('خفيفة')),
                  DropdownMenuItem(
                      value: 'moderate', child: Text('متوسطة')),
                  DropdownMenuItem(value: 'severe', child: Text('شديدة')),
                ],
                onChanged: (v) => setState(() => selectedSeverity = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
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
            style:
                ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
            onPressed: isLoading
                ? null
                : () async {
                    if (allergyController.text.isEmpty) return;
                    setState(() => isLoading = true);
                    final success = await ref
                        .read(patientFileProvider.notifier)
                        .addAllergy(
                          patientId: patientId,
                          allergyName: allergyController.text.trim(),
                          severity: selectedSeverity,
                          notes: notesController.text.isEmpty
                              ? null
                              : notesController.text.trim(),
                        );
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إضافة الحساسية'),
                            backgroundColor: AppTheme.primary,
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
                        strokeWidth: 2, color: Colors.white))
                : const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}

  void _showAddRecordDialog(String patientId, String doctorId) {
    final diagnosisController = TextEditingController();
    final notesController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إضافة سجل طبي'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: diagnosisController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'التشخيص',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
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
                      setState(() => isLoading = true);
                      final success = await ref
                          .read(patientFileProvider.notifier)
                          .addRecord(
                            patientId: patientId,
                            doctorId: doctorId,
                            appointmentId: widget.appointmentId,
                            diagnosis: diagnosisController.text.isEmpty
                                ? null
                                : diagnosisController.text.trim(),
                            notes: notesController.text.isEmpty
                                ? null
                                : notesController.text.trim(),
                          );
                      if (context.mounted) {
                        Navigator.pop(context);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إضافة السجل بنجاح'),
                              backgroundColor: AppTheme.primary,
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
                          strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLabDialog(
      String patientId, String doctorId, List<String> tests) {
    String? selected;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('طلب تحليل'),
          content: SizedBox(
            width: 400,
            child: DropdownButtonFormField<String>(
              value: selected,
              decoration: const InputDecoration(labelText: 'نوع التحليل *'),
              items: tests
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => selected = v),
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
              onPressed: selected == null || isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      final success = await ref
                          .read(patientFileProvider.notifier)
                          .addLabRequest(
                            patientId: patientId,
                            requestedBy: doctorId,
                            testName: selected!,
                          );
                      if (context.mounted) {
                        Navigator.pop(context);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إرسال الطلب'),
                              backgroundColor: AppTheme.primary,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRadiologyDialog(
      String patientId, String doctorId, List<String> types) {
    String? selected;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('طلب أشعة'),
          content: SizedBox(
            width: 400,
            child: DropdownButtonFormField<String>(
              value: selected,
              decoration: const InputDecoration(labelText: 'نوع الأشعة *'),
              items: types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => selected = v),
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
              onPressed: selected == null || isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      final success = await ref
                          .read(patientFileProvider.notifier)
                          .addRadiologyRequest(
                            patientId: patientId,
                            requestedBy: doctorId,
                            scanType: selected!,
                          );
                      if (context.mounted) {
                        Navigator.pop(context);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إرسال الطلب'),
                              backgroundColor: AppTheme.primary,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }

  
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = AppTheme.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(label,
                style:
                    const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _LabRadCard extends StatelessWidget {
  final String title;
  final String status;
  final String? result;
  final DateTime date;
  final String statusLabel;
  final Color statusColor;
  final IconData icon;
  final String? fileUrl;

  const _LabRadCard({
    required this.title,
    required this.status,
    this.result,
    required this.date,
    required this.statusLabel,
    required this.statusColor,
    required this.icon,
    this.fileUrl,
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                Text(
                  '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
                if (result != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: Text(result!,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textPrimary)),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}