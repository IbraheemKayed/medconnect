import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../../core/theme/app_theme.dart';

class WorkingHoursScreen extends ConsumerStatefulWidget {
  final String clinicId;
  final String clinicName;

  const WorkingHoursScreen({
    super.key,
    required this.clinicId,
    required this.clinicName,
  });

  @override
  ConsumerState<WorkingHoursScreen> createState() =>
      _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends ConsumerState<WorkingHoursScreen> {
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _hours = [];
  String? _selectedDoctorId;
  bool _isLoading = true;

  final _days = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء',
    'الخميس', 'الجمعة', 'السبت'
  ];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      final data = await SupabaseConfig.client
          .from('clinic_staff')
          .select('users(id, full_name)')
          .eq('clinic_id', widget.clinicId)
          .eq('role', 'doctor');

      setState(() {
        _doctors = (data as List)
            .map((e) => e['users'] as Map<String, dynamic>)
            .toList();
        _isLoading = false;
      });

      if (_doctors.isNotEmpty) {
        _selectedDoctorId = _doctors.first['id'] as String;
        await _loadHours();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHours() async {
    if (_selectedDoctorId == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseConfig.client
          .from('clinic_working_hours')
          .select()
          .eq('clinic_id', widget.clinicId)
          .eq('doctor_id', _selectedDoctorId!)
          .order('day_of_week');

      setState(() {
        _hours = (data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _getHourForDay(int day) {
    try {
      return _hours.firstWhere((h) => h['day_of_week'] == day);
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleDay(int day, bool enabled) async {
    if (_selectedDoctorId == null) return;
    final existing = _getHourForDay(day);

    if (enabled && existing == null) {
      await _showEditDialog(day, null);
    } else if (!enabled && existing != null) {
      await SupabaseConfig.client
          .from('clinic_working_hours')
          .delete()
          .eq('id', existing['id']);
      await _loadHours();
    }
  }

  Future<void> _showEditDialog(int day, Map<String, dynamic>? existing) async {
    TimeOfDay startTime = existing != null
        ? _parseTime(existing['start_time'])
        : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = existing != null
        ? _parseTime(existing['end_time'])
        : const TimeOfDay(hour: 17, minute: 0);
    int slotDuration = existing?['slot_duration_minutes'] ?? 30;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${_days[day]} — ${widget.clinicName}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_outlined,
                      color: AppTheme.primary),
                  title: const Text('وقت البداية'),
                  trailing: Text(
                    '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: startTime,
                      builder: (c, child) => Localizations.override(
                          context: c,
                          locale: const Locale('en'),
                          child: child!),
                    );
                    if (t != null) setState(() => startTime = t);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_filled_outlined,
                      color: AppTheme.primary),
                  title: const Text('وقت النهاية'),
                  trailing: Text(
                    '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: endTime,
                      builder: (c, child) => Localizations.override(
                          context: c,
                          locale: const Locale('en'),
                          child: child!),
                    );
                    if (t != null) setState(() => endTime = t);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('مدة الموعد:'),
                    const Spacer(),
                    DropdownButton<int>(
                      value: slotDuration,
                      items: [15, 20, 30, 45, 60].map((m) =>
                          DropdownMenuItem(
                              value: m, child: Text('$m دقيقة'))).toList(),
                      onChanged: (v) =>
                          setState(() => slotDuration = v ?? 30),
                    ),
                  ],
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
              onPressed: () async {
                final startStr =
                    '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                final endStr =
                    '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

                if (existing != null) {
                  await SupabaseConfig.client
                      .from('clinic_working_hours')
                      .update({
                    'start_time': startStr,
                    'end_time': endStr,
                    'slot_duration_minutes': slotDuration,
                  }).eq('id', existing['id']);
                } else {
                  await SupabaseConfig.client
                      .from('clinic_working_hours')
                      .insert({
                    'clinic_id': widget.clinicId,
                    'doctor_id': _selectedDoctorId,
                    'day_of_week': day,
                    'start_time': startStr,
                    'end_time': endStr,
                    'slot_duration_minutes': slotDuration,
                  });
                }
                if (context.mounted) Navigator.pop(context);
                await _loadHours();
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
        hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('أوقات عمل ${widget.clinicName}'),
        backgroundColor: AppTheme.surface,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Doctor selector
                  if (_doctors.length > 1) ...[
                    const Text('الدكتور:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Row(
                      children: _doctors.map((d) {
                        final isSelected = _selectedDoctorId == d['id'];
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: FilterChip(
                            label: Text(d['full_name'] as String),
                            selected: isSelected,
                            onSelected: (_) async {
                              setState(
                                  () => _selectedDoctorId = d['id']);
                              await _loadHours();
                            },
                            selectedColor:
                                AppTheme.primary.withOpacity(0.15),
                            checkmarkColor: AppTheme.primary,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  const Text('أيام العمل:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.separated(
                      itemCount: 7,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, day) {
                        final hour = _getHourForDay(day);
                        final isActive = hour != null;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? AppTheme.primary.withOpacity(0.3)
                                  : AppTheme.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: Text(
                                  _days[day],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              if (isActive) ...[
                                const Icon(Icons.access_time_outlined,
                                    size: 16,
                                    color: AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  '${_parseTime(hour['start_time']).hour.toString().padLeft(2, '0')}:${_parseTime(hour['start_time']).minute.toString().padLeft(2, '0')} — ${_parseTime(hour['end_time']).hour.toString().padLeft(2, '0')}:${_parseTime(hour['end_time']).minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13),
                                ),
                                const SizedBox(width: 12),
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
                                    '${hour['slot_duration_minutes']} د',
                                    style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 12),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () =>
                                      _showEditDialog(day, hour),
                                  icon: const Icon(Icons.edit_outlined,
                                      color: AppTheme.primary,
                                      size: 18),
                                ),
                              ] else
                                const Expanded(
                                  child: Text('مغلق',
                                      style: TextStyle(
                                          color:
                                              AppTheme.textSecondary)),
                                ),
                              Switch(
                                value: isActive,
                                onChanged: (v) => _toggleDay(day, v),
                                activeColor: AppTheme.primary,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}