import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical_center/core/supabase/supabase_config.dart';
import 'package:medical_center/features/appointments/screens/appointments_screen.dart';
import 'package:medical_center/features/clinics/screens/clinics_screen.dart';
import 'package:medical_center/features/invoices/screens/invoices_screen.dart';
import 'package:medical_center/features/lab/screens/lab_screen.dart';
import 'package:medical_center/features/medical_records/screens/patient_file_screen.dart';
import 'package:medical_center/features/patients/screens/patients_screen.dart';
import 'package:medical_center/features/radiology/screens/radiology_screen.dart';
import 'package:medical_center/features/reports/screens/reports_screen.dart';
import 'package:medical_center/features/settings/screens/settings_screen.dart';
import 'package:medical_center/features/staff/screens/staff_screen.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final menuItems = _getMenuItems(user?.role ?? '', user?.tenantId);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            color: AppTheme.textPrimary,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.local_hospital_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'مركز الشفاء',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getRoleLabel(user?.role ?? ''),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),

                // Menu Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      final isSelected = _selectedIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          selected: isSelected,
                          selectedTileColor: AppTheme.primary.withOpacity(0.15),
                          selectedColor: AppTheme.primary,
                          iconColor: Colors.white54,
                          textColor: Colors.white70,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          leading: Icon(item.icon, size: 20),
                          title: Text(
                            item.label,
                            style: const TextStyle(fontSize: 14),
                          ),
                          onTap: () => setState(() => _selectedIndex = index),
                        ),
                      );
                    },
                  ),
                ),

                // User info + logout
                const Divider(color: Colors.white12, height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.2),
                    child: Text(
                      user?.fullName.substring(0, 1) ?? 'U',
                      style: const TextStyle(color: AppTheme.primary),
                    ),
                  ),
                  title: Text(
                    user?.fullName ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: () => _confirmLogout(context),
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: AppTheme.surface,
                    border: Border(bottom: BorderSide(color: AppTheme.border)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        menuItems[_selectedIndex].label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _getGreeting(),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Page content
                Expanded(child: menuItems[_selectedIndex].screen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 17) return 'مساء الخير';
    return 'مساء النور';
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              minimumSize: const Size(80, 40),
            ),
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case AppConstants.roleCenterAdmin:
        return 'مدير المركز';
      case AppConstants.roleDoctor:
        return 'دكتور';
      case AppConstants.roleCenterReceptionist:
        return 'ريسيبشن';
      case AppConstants.roleNurse:
        return 'تمريض';
      case AppConstants.roleLabTechnician:
        return 'مختبر';
      case AppConstants.roleRadiologyTechnician:
        return 'أشعة';
      default:
        return role;
    }
  }

  List<_MenuItem> _getMenuItems(String role, String? tenantId) {
    switch (role) {
      case AppConstants.roleCenterAdmin:
        return [
          _MenuItem(
            label: 'الرئيسية',
            icon: Icons.dashboard_rounded,
            screen: _HomeTab(tenantId: tenantId ?? ''),
          ),
          _MenuItem(
            label: 'المواعيد',
            icon: Icons.calendar_month_rounded,
            screen: const AppointmentsScreen(),
          ),
          _MenuItem(
            label: 'المرضى',
            icon: Icons.people_rounded,
            screen: const PatientsScreen(),
          ),
          _MenuItem(
            label: 'العيادات',
            icon: Icons.meeting_room_rounded,
            screen: const ClinicsScreen(),
          ),
          _MenuItem(
            label: 'الموظفون',
            icon: Icons.badge_rounded,
            screen: const StaffScreen(),
          ),
          _MenuItem(
            label: 'المختبر',
            icon: Icons.biotech_rounded,
            screen: const LabScreen(),
          ),
          _MenuItem(
            label: 'الأشعة',
            icon: Icons.document_scanner_rounded,
            screen: const RadiologyScreen(),
          ),
          _MenuItem(
            label: 'الفواتير',
            icon: Icons.receipt_long_rounded,
            screen: const InvoicesScreen(),
          ),
          _MenuItem(
            label: 'التقارير',
            icon: Icons.bar_chart_rounded,
            screen: const ReportsScreen(),
          ),
          _MenuItem(
            label: 'الإعدادات',
            icon: Icons.settings_rounded,
            screen: const SettingsScreen(),
          ),
        ];

      case AppConstants.roleCenterReceptionist:
        return [
          _MenuItem(
            label: 'الرئيسية',
            icon: Icons.dashboard_rounded,
            screen: _HomeTab(tenantId: tenantId ?? ''),
          ),
          _MenuItem(
            label: 'المواعيد',
            icon: Icons.calendar_month_rounded,
            screen: const AppointmentsScreen(),
          ),
          _MenuItem(
            label: 'المرضى',
            icon: Icons.people_rounded,
            screen: const PatientsScreen(),
          ),
          _MenuItem(
            label: 'الفواتير',
            icon: Icons.receipt_long_rounded,
            screen: const InvoicesScreen(),
          ),
        ];

      case AppConstants.roleDoctor:
        return [
          _MenuItem(
            label: 'الرئيسية',
            icon: Icons.dashboard_rounded,
            screen: _HomeTab(tenantId: tenantId ?? ''),
          ),
          _MenuItem(
            label: 'المواعيد',
            icon: Icons.calendar_month_rounded,
            screen: const AppointmentsScreen(),
          ),
          _MenuItem(
            label: 'المرضى',
            icon: Icons.people_rounded,
            screen: const PatientsScreen(),
          ),
          _MenuItem(
            label: 'الملفات الطبية',
            icon: Icons.folder_shared_rounded,
            screen: const _MedicalRecordsTab(),
          ),
          _MenuItem(
            label: 'طلبات المختبر',
            icon: Icons.biotech_rounded,
            screen: const LabScreen(),
          ),
          _MenuItem(
            label: 'طلبات الأشعة',
            icon: Icons.document_scanner_rounded,
            screen: const RadiologyScreen(),
          ),
        ];

      case AppConstants.roleClinicReceptionist:
        return [
          _MenuItem(
            label: 'الرئيسية',
            icon: Icons.dashboard_rounded,
            screen: _HomeTab(tenantId: tenantId ?? ''),
          ),
          _MenuItem(
            label: 'المواعيد',
            icon: Icons.calendar_month_rounded,
            screen: const AppointmentsScreen(),
          ),
          _MenuItem(
            label: 'المرضى',
            icon: Icons.people_rounded,
            screen: const PatientsScreen(),
          ),
          _MenuItem(
            label: 'الفواتير',
            icon: Icons.receipt_long_rounded,
            screen: const InvoicesScreen(),
          ),
        ];

      case AppConstants.roleNurse:
        return [
          _MenuItem(
            label: 'الرئيسية',
            icon: Icons.dashboard_rounded,
            screen: _HomeTab(tenantId: tenantId ?? ''),
          ),
          _MenuItem(
            label: 'المواعيد',
            icon: Icons.calendar_month_rounded,
            screen: const AppointmentsScreen(),
          ),
          _MenuItem(
            label: 'المرضى',
            icon: Icons.people_rounded,
            screen: const PatientsScreen(),
          ),
        ];

      case AppConstants.roleLabTechnician:
        return [
          _MenuItem(
            label: 'الرئيسية',
            icon: Icons.dashboard_rounded,
            screen: _HomeTab(tenantId: tenantId ?? ''),
          ),
          _MenuItem(
            label: 'طلبات التحاليل',
            icon: Icons.biotech_rounded,
            screen: const LabScreen(),
          ),
        ];

      case AppConstants.roleRadiologyTechnician:
        return [
          _MenuItem(
            label: 'الرئيسية',
            icon: Icons.dashboard_rounded,
            screen: _HomeTab(tenantId: tenantId ?? ''),
          ),
          _MenuItem(
            label: 'طلبات الأشعة',
            icon: Icons.document_scanner_rounded,
            screen: const RadiologyScreen(),
          ),
        ];

      default:
        return [
          _MenuItem(
            label: 'الرئيسية',
            icon: Icons.dashboard_rounded,
            screen: _HomeTab(tenantId: tenantId ?? ''),
          ),
        ];
    }
  }
}

// Model للقائمة
class _MenuItem {
  final String label;
  final IconData icon;
  final Widget screen;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.screen,
  });
}

// Placeholder مؤقت للشاشات
class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.construction_rounded,
            size: 48,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'قريباً — $label',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// Home Tab — إحصائيات
class _HomeTab extends ConsumerStatefulWidget {
  final String tenantId;
  const _HomeTab({required this.tenantId});

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  List<Map<String, dynamic>> _recentAppointments = [];

  @override
  void initState() {
    super.initState();
    debugPrint('HomeTab initState — tenantId: ${widget.tenantId}');
    if (widget.tenantId.isNotEmpty) {
      _loadStats();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    debugPrint('Loading stats for tenant: ${widget.tenantId}');
    try {
      final stats = await SupabaseConfig.client.rpc(
        'get_dashboard_stats',
        params: {'tenant_id_input': widget.tenantId},
      );

      debugPrint('Stats: $stats');

      final now = DateTime.now();
      final appointments = await SupabaseConfig.client.rpc(
        'get_appointments',
        params: {
          'start_date': DateTime(
            now.year,
            now.month,
            now.day,
          ).toUtc().toIso8601String(),
          'end_date': DateTime(
            now.year,
            now.month,
            now.day,
            23,
            59,
            59,
          ).toUtc().toIso8601String(),
        },
      );

      if (mounted) {
        setState(() {
          _stats = Map<String, dynamic>.from(stats as Map);
          _recentAppointments = (appointments as List)
              .cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadStats(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.6,
              children: [
                _StatCard(
                  label: 'مواعيد اليوم',
                  value: '${_stats?['today_appointments'] ?? 0}',
                  icon: Icons.calendar_today_rounded,
                  color: AppTheme.primary,
                ),
                _StatCard(
                  label: 'المرضى',
                  value: '${_stats?['total_patients'] ?? 0}',
                  icon: Icons.people_rounded,
                  color: const Color(0xFF378ADD),
                ),
                _StatCard(
                  label: 'طلبات المختبر',
                  value: '${_stats?['pending_lab'] ?? 0}',
                  icon: Icons.biotech_rounded,
                  color: const Color(0xFFBA7517),
                ),
                _StatCard(
                  label: 'الفواتير المعلقة',
                  value: '${_stats?['unpaid_invoices'] ?? 0}',
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFFE24B4A),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent appointments
            Container(
              padding: const EdgeInsets.all(20),
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
                      const Text(
                        'مواعيد اليوم',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_recentAppointments.length} موعد',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_recentAppointments.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'لا يوجد مواعيد اليوم',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentAppointments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final apt = _recentAppointments[index];
                        final scheduledAt = DateTime.parse(
                          apt['scheduled_at'],
                        ).toLocal();
                        final time =
                            '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}';

                        Color statusColor;
                        switch (apt['status']) {
                          case 'confirmed':
                            statusColor = const Color(0xFF378ADD);
                            break;
                          case 'completed':
                            statusColor = AppTheme.primary;
                            break;
                          case 'cancelled':
                            statusColor = AppTheme.error;
                            break;
                          default:
                            statusColor = const Color(0xFFBA7517);
                        }

                        final isDoctor =
                            ref.read(currentUserProvider)?.role == 'doctor';

                        return InkWell(
                          onTap: isDoctor
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PatientFileScreen(
                                        patientId: apt['patient_id'] as String,
                                        appointmentId: apt['id'] as String,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  alignment: Alignment.center,
                                  child: Text(
                                    time,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.primary.withOpacity(
                                    0.1,
                                  ),
                                  child: Text(
                                    (apt['patient_name'] as String).substring(
                                      0,
                                      1,
                                    ),
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        apt['patient_name'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${apt['doctor_name']} — ${apt['clinic_name']}',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    apt['status'] == 'pending'
                                        ? 'بانتظار التأكيد'
                                        : apt['status'] == 'confirmed'
                                        ? 'مؤكد'
                                        : apt['status'] == 'completed'
                                        ? 'مكتمل'
                                        : apt['status'] == 'cancelled'
                                        ? 'ملغى'
                                        : apt['status'],
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicalRecordsTab extends ConsumerWidget {
  const _MedicalRecordsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ابحث عن مريض لعرض ملفه الطبي',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _PatientSearchField(),
        ],
      ),
    );
  }
}

class _PatientSearchField extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PatientSearchField> createState() =>
      _PatientSearchFieldState();
}

class _PatientSearchFieldState extends ConsumerState<_PatientSearchField> {
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final data = await SupabaseConfig.client
          .from('patients')
          .select()
          .ilike('full_name', '%$query%')
          .limit(10);
      setState(() {
        _results = (data as List).cast<Map<String, dynamic>>();
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          onChanged: _search,
          decoration: InputDecoration(
            hintText: 'ابحث باسم المريض...',
            prefixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                : const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        ..._results.map((patient) {
          DateTime? dob = patient['dob'] != null
              ? DateTime.parse(patient['dob'])
              : null;
          int? age;
          if (dob != null) {
            final today = DateTime.now();
            age = today.year - dob.year;
            if (today.month < dob.month ||
                (today.month == dob.month && today.day < dob.day)) {
              age--;
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PatientFileScreen(patientId: patient['id'] as String),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: Text(
                        (patient['full_name'] as String).substring(0, 1),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient['full_name'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (patient['phone'] != null || age != null)
                            Text(
                              [
                                if (patient['phone'] != null) patient['phone'],
                                if (age != null) '$age سنة',
                              ].join(' · '),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
