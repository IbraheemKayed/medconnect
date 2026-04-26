import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_theme.dart';

class ClinicSelectionScreen extends ConsumerStatefulWidget {
  const ClinicSelectionScreen({super.key});

  @override
  ConsumerState<ClinicSelectionScreen> createState() =>
      _ClinicSelectionScreenState();
}

class _ClinicSelectionScreenState
    extends ConsumerState<ClinicSelectionScreen> {
  List<Map<String, dynamic>> _clinics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClinics();
  }

  Future<void> _loadClinics() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final data = await SupabaseConfig.client
          .from('clinic_staff')
          .select('clinic_id, clinics(id, name, specialty)')
          .eq('user_id', user.id);

      setState(() {
        _clinics = (data as List)
            .map((e) => e['clinics'] as Map<String, dynamic>)
            .toList();
        _isLoading = false;
      });

      // لو عيادة وحدة بس — اختارها تلقائياً
      if (_clinics.length == 1) {
        _selectClinic(_clinics.first);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _selectClinic(Map<String, dynamic> clinic) {
    ref.read(authProvider.notifier).selectClinic(
          clinic['id'] as String,
          clinic['name'] as String,
        );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.meeting_room_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'مرحباً، ${user?.fullName ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اختر العيادة للمتابعة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 36),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primary),
                  )
                else if (_clinics.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.error.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppTheme.error, size: 32),
                        const SizedBox(height: 8),
                        const Text(
                          'لم يتم تعيينك لأي عيادة بعد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.error,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'تواصل مع مدير المركز',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () =>
                              ref.read(authProvider.notifier).logout(),
                          child: const Text('تسجيل الخروج'),
                        ),
                      ],
                    ),
                  )
                else
                  ...(_clinics.map((clinic) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _selectClinic(clinic),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(20),
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
                                    color: AppTheme.primary
                                        .withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(10),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        clinic['name'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      if (clinic['specialty'] != null)
                                        Text(
                                          clinic['specialty'] as String,
                                          style: const TextStyle(
                                            color:
                                                AppTheme.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}