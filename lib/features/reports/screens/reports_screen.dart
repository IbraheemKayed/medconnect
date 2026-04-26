import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_theme.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _generalData;
  List<Map<String, dynamic>> _doctorStats = [];
  bool _isLoadingGeneral = true;
  bool _isLoadingDoctors = true;
  String _selectedPeriod = 'week';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGeneral();
      _loadDoctors();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGeneral() async {
    setState(() => _isLoadingGeneral = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      final result = await SupabaseConfig.client
          .rpc('get_reports', params: {'tenant_id_input': user.tenantId});
      setState(() {
        _generalData = Map<String, dynamic>.from(result as Map);
        _isLoadingGeneral = false;
      });
    } catch (e) {
      setState(() => _isLoadingGeneral = false);
    }
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoadingDoctors = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      final result = await SupabaseConfig.client.rpc(
        'get_doctor_stats',
        params: {
          'tenant_id_input': user.tenantId,
          'period': _selectedPeriod,
        },
      );
      setState(() {
        _doctorStats = result == null
            ? []
            : (result as List).cast<Map<String, dynamic>>();
        _isLoadingDoctors = false;
      });
    } catch (e) {
      setState(() => _isLoadingDoctors = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tabs
        Container(
          color: AppTheme.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            tabs: const [
              Tab(text: 'التقارير العامة'),
              Tab(text: 'إحصائيات الدكاترة'),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGeneralTab(),
              _buildDoctorsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralTab() {
    if (_isLoadingGeneral) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_generalData == null) {
      return const Center(child: Text('لا يوجد بيانات'));
    }

    return RefreshIndicator(
      onRefresh: _loadGeneral,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ChartCard(
                    title: 'المواعيد حسب الحالة',
                    icon: Icons.calendar_month_rounded,
                    color: AppTheme.primary,
                    child: _BarChart(
                      data: _parseList(_generalData!['appointments_by_status']),
                      labelKey: 'status',
                      valueKey: 'count',
                      labelMap: {
                        'pending': 'انتظار',
                        'confirmed': 'مؤكد',
                        'in_progress': 'جارٍ',
                        'completed': 'مكتمل',
                        'cancelled': 'ملغى',
                      },
                      colorMap: {
                        'pending': const Color(0xFFBA7517),
                        'confirmed': const Color(0xFF378ADD),
                        'in_progress': const Color(0xFF534AB7),
                        'completed': AppTheme.primary,
                        'cancelled': AppTheme.error,
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ChartCard(
                    title: 'المواعيد حسب العيادة',
                    icon: Icons.meeting_room_rounded,
                    color: const Color(0xFF534AB7),
                    child: _BarChart(
                      data: _parseList(_generalData!['appointments_by_clinic']),
                      labelKey: 'clinic_name',
                      valueKey: 'count',
                      barColor: const Color(0xFF534AB7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _ChartCard(
                    title: 'الإيرادات الشهرية (₪)',
                    icon: Icons.trending_up_rounded,
                    color: AppTheme.primary,
                    child: _RevenueChart(
                      data: _parseList(_generalData!['revenue_by_month']),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ChartCard(
                    title: 'أكثر التحاليل طلباً',
                    icon: Icons.biotech_rounded,
                    color: const Color(0xFFBA7517),
                    child: _BarChart(
                      data: _parseList(_generalData!['top_tests']),
                      labelKey: 'test_name',
                      valueKey: 'count',
                      barColor: const Color(0xFFBA7517),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ChartCard(
              title: 'طلبات المختبر حسب الحالة',
              icon: Icons.biotech_outlined,
              color: AppTheme.primary,
              child: _BarChart(
                data: _parseList(_generalData!['lab_by_status']),
                labelKey: 'status',
                valueKey: 'count',
                labelMap: {
                  'pending': 'انتظار',
                  'in_progress': 'جارٍ',
                  'completed': 'مكتمل',
                },
                colorMap: {
                  'pending': const Color(0xFFBA7517),
                  'in_progress': const Color(0xFF378ADD),
                  'completed': AppTheme.primary,
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorsTab() {
    return Column(
      children: [
        // Period selector
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.background,
          child: Row(
            children: [
              const Text('الفترة:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const SizedBox(width: 12),
              _PeriodButton(
                label: 'اليوم',
                value: 'day',
                selected: _selectedPeriod == 'day',
                onTap: () {
                  setState(() => _selectedPeriod = 'day');
                  _loadDoctors();
                },
              ),
              const SizedBox(width: 8),
              _PeriodButton(
                label: 'الأسبوع',
                value: 'week',
                selected: _selectedPeriod == 'week',
                onTap: () {
                  setState(() => _selectedPeriod = 'week');
                  _loadDoctors();
                },
              ),
              const SizedBox(width: 8),
              _PeriodButton(
                label: 'الشهر',
                value: 'month',
                selected: _selectedPeriod == 'month',
                onTap: () {
                  setState(() => _selectedPeriod = 'month');
                  _loadDoctors();
                },
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadDoctors,
                icon: const Icon(Icons.refresh_rounded,
                    color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoadingDoctors
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : _doctorStats.isEmpty
                  ? const Center(
                      child: Text('لا يوجد بيانات',
                          style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _doctorStats.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = _doctorStats[index];
                        return _DoctorStatCard(data: doc);
                      },
                    ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data == null) return [];
    return (data as List).cast<Map<String, dynamic>>();
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _DoctorStatCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DoctorStatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['doctor_name'] as String;
    final patients = (data['patients_count'] as num).toInt();
    final appointments = (data['appointments_count'] as num).toInt();
    final completed = (data['completed_count'] as num).toInt();
    final cancelled = (data['cancelled_count'] as num).toInt();
    final labRequests = (data['lab_requests_count'] as num).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: Text(
                  name.substring(0, 1),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textPrimary)),
                    Text('دكتور',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              // Completion rate
              if (appointments > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'إنجاز ${(completed / appointments * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'المرضى',
                  value: patients.toString(),
                  icon: Icons.people_rounded,
                  color: const Color(0xFF378ADD),
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'المواعيد',
                  value: appointments.toString(),
                  icon: Icons.calendar_today_rounded,
                  color: AppTheme.primary,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'مكتمل',
                  value: completed.toString(),
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.primary,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'ملغى',
                  value: cancelled.toString(),
                  icon: Icons.cancel_outlined,
                  color: AppTheme.error,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'تحاليل',
                  value: labRequests.toString(),
                  icon: Icons.biotech_rounded,
                  color: const Color(0xFFBA7517),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String labelKey;
  final String valueKey;
  final Map<String, String>? labelMap;
  final Map<String, Color>? colorMap;
  final Color barColor;

  const _BarChart({
    required this.data,
    required this.labelKey,
    required this.valueKey,
    this.labelMap,
    this.colorMap,
    this.barColor = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('لا يوجد بيانات',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    final maxVal = data
        .map((e) => (e[valueKey] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: data.map((item) {
        final label =
            labelMap?[item[labelKey]] ?? item[labelKey].toString();
        final value = (item[valueKey] as num).toDouble();
        final ratio = maxVal > 0 ? value / maxVal : 0.0;
        final color = colorMap?[item[labelKey]] ?? barColor;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.border.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio < 0.05 ? 0.05 : ratio,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _RevenueChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('لا يوجد إيرادات بعد',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    final sorted = List<Map<String, dynamic>>.from(data)
      ..sort((a, b) => a['month'].compareTo(b['month']));

    final maxVal = sorted
        .map((e) => (e['total'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: sorted.map((item) {
              final value = (item['total'] as num).toDouble();
              final ratio = maxVal > 0 ? value / maxVal : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        height: 110 * ratio,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: sorted.map((item) {
            return Expanded(
              child: Text(
                item['month'].toString().substring(5),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}