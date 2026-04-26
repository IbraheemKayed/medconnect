import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_config.dart';

class Clinic {
  final String id;
  final String tenantId;
  final String name;
  final String? specialty;
  final bool isActive;

  const Clinic({
    required this.id,
    required this.tenantId,
    required this.name,
    this.specialty,
    required this.isActive,
  });

  factory Clinic.fromMap(Map<String, dynamic> map) {
    return Clinic(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      name: map['name'] as String,
      specialty: map['specialty'] as String?,
      isActive: map['is_active'] as bool,
    );
  }
}

class ClinicStaffMember {
  final String id;
  final String userId;
  final String clinicId;
  final String role;
  final String fullName;
  final String? phone;

  const ClinicStaffMember({
    required this.id,
    required this.userId,
    required this.clinicId,
    required this.role,
    required this.fullName,
    this.phone,
  });

  factory ClinicStaffMember.fromMap(Map<String, dynamic> map) {
    final user = map['users'] as Map<String, dynamic>;
    return ClinicStaffMember(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      clinicId: map['clinic_id'] as String,
      role: map['role'] as String,
      fullName: user['full_name'] as String,
      phone: user['phone'] as String?,
    );
  }

  String get roleLabel {
    switch (role) {
      case 'doctor': return 'دكتور';
      case 'clinic_receptionist': return 'ريسيبشن';
      case 'nurse': return 'ممرض';
      default: return role;
    }
  }

  Color get roleColor {
    switch (role) {
      case 'doctor': return const Color(0xFF1D9E75);
      case 'clinic_receptionist': return const Color(0xFF378ADD);
      case 'nurse': return const Color(0xFFBA7517);
      default: return const Color(0xFF888780);
    }
  }
}

class ClinicsState {
  final List<Clinic> clinics;
  final bool isLoading;
  final String? error;

  const ClinicsState({
    this.clinics = const [],
    this.isLoading = false,
    this.error,
  });

  ClinicsState copyWith({
    List<Clinic>? clinics,
    bool? isLoading,
    String? error,
  }) {
    return ClinicsState(
      clinics: clinics ?? this.clinics,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ClinicsNotifier extends Notifier<ClinicsState> {
  @override
  ClinicsState build() {
    Future.microtask(() => fetchClinics());
    return const ClinicsState(isLoading: true);
  }

  Future<void> fetchClinics() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await SupabaseConfig.client
          .from('clinics')
          .select()
          .order('created_at', ascending: false);

      final clinics = (data as List).map((e) => Clinic.fromMap(e)).toList();
      state = state.copyWith(clinics: clinics, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> addClinic({
    required String name,
    required String tenantId,
    String? specialty,
  }) async {
    try {
      await SupabaseConfig.client.from('clinics').insert({
        'tenant_id': tenantId,
        'name': name,
        'specialty': specialty,
      });
      await fetchClinics();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleActive(String clinicId, bool current) async {
    try {
      await SupabaseConfig.client
          .from('clinics')
          .update({'is_active': !current})
          .eq('id', clinicId);
      await fetchClinics();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<ClinicStaffMember>> getClinicStaff(String clinicId) async {
    try {
      final data = await SupabaseConfig.client
          .from('clinic_staff')
          .select('*, users(full_name, phone)')
          .eq('clinic_id', clinicId);

      return (data as List)
          .map((e) => ClinicStaffMember.fromMap(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> assignStaff({
    required String clinicId,
    required String userId,
    required String role,
  }) async {
    try {
      await SupabaseConfig.client.from('clinic_staff').insert({
        'clinic_id': clinicId,
        'user_id': userId,
        'role': role,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeStaff(String clinicStaffId) async {
    try {
      await SupabaseConfig.client
          .from('clinic_staff')
          .delete()
          .eq('id', clinicStaffId);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final clinicsProvider = NotifierProvider<ClinicsNotifier, ClinicsState>(() {
  return ClinicsNotifier();
});