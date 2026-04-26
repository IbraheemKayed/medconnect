import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_config.dart';

class StaffMember {
  final String id;
  final String tenantId;
  final String fullName;
  final String role;
  final String? phone;
  final bool isActive;

  const StaffMember({
    required this.id,
    required this.tenantId,
    required this.fullName,
    required this.role,
    this.phone,
    required this.isActive,
  });

  factory StaffMember.fromMap(Map<String, dynamic> map) {
    return StaffMember(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String,
      phone: map['phone'] as String?,
      isActive: map['is_active'] as bool,
    );
  }

  String get roleLabel {
    switch (role) {
      case 'center_admin': return 'مدير المركز';
      case 'center_receptionist': return 'ريسيبشن المركز';
      case 'doctor': return 'دكتور';
      case 'clinic_receptionist': return 'ريسيبشن عيادة';
      case 'nurse': return 'ممرض';
      case 'lab_technician': return 'مختبر';
      case 'radiology_technician': return 'أشعة';
      default: return role;
    }
  }

  Color get roleColor {
    switch (role) {
      case 'doctor': return const Color(0xFF1D9E75);
      case 'center_admin': return const Color(0xFF534AB7);
      case 'nurse': return const Color(0xFF378ADD);
      case 'lab_technician': return const Color(0xFFBA7517);
      case 'radiology_technician': return const Color(0xFFD85A30);
      default: return const Color(0xFF888780);
    }
  }
}

class StaffState {
  final List<StaffMember> staff;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const StaffState({
    this.staff = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  List<StaffMember> get filtered {
    if (searchQuery.isEmpty) return staff;
    return staff.where((s) =>
      s.fullName.contains(searchQuery) ||
      s.roleLabel.contains(searchQuery)
    ).toList();
  }

  StaffState copyWith({
    List<StaffMember>? staff,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return StaffState(
      staff: staff ?? this.staff,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class StaffNotifier extends Notifier<StaffState> {
 @override
StaffState build() {
  Future.microtask(() => fetchStaff());
  return const StaffState(isLoading: true);
}

  Future<void> fetchStaff() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await SupabaseConfig.client
          .from('users')
          .select()
          .neq('role', 'patient')
          .order('created_at', ascending: false);

      final staff = (data as List).map((e) => StaffMember.fromMap(e)).toList();
      state = state.copyWith(staff: staff, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<bool> addStaff({
  required String email,
  required String password,
  required String fullName,
  required String role,
  required String tenantId,
  String? phone,
}) async {
  try {
    final adminClient = SupabaseConfig.adminClient;

    final response = await adminClient.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true,
      ),
    );

    if (response.user == null) return false;

    await SupabaseConfig.client.from('users').insert({
      'id': response.user!.id,
      'tenant_id': tenantId,
      'full_name': fullName,
      'role': role,
      'phone': phone,
    });

    await fetchStaff();
    return true;
  } catch (e) {
    return false;
  }
}

  Future<bool> toggleActive(String userId, bool currentStatus) async {
    try {
      await SupabaseConfig.client
          .from('users')
          .update({'is_active': !currentStatus})
          .eq('id', userId);
      await fetchStaff();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final staffProvider = NotifierProvider<StaffNotifier, StaffState>(() {
  return StaffNotifier();
});