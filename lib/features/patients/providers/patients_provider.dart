import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_config.dart';

class Patient {
  final String id;
  final String tenantId;
  final String fullName;
  final String? phone;
  final String? gender;
  final String? bloodType;
  final DateTime? dob;
  final DateTime createdAt;

  const Patient({
    required this.id,
    required this.tenantId,
    required this.fullName,
    this.phone,
    this.gender,
    this.bloodType,
    this.dob,
    required this.createdAt,
  });

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      fullName: map['full_name'] as String,
      phone: map['phone'] as String?,
      gender: map['gender'] as String?,
      bloodType: map['blood_type'] as String?,
      dob: map['dob'] != null ? DateTime.parse(map['dob']) : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  String get genderLabel => gender == 'male' ? 'ذكر' : gender == 'female' ? 'أنثى' : '';

  int? get age {
    if (dob == null) return null;
    final today = DateTime.now();
    int age = today.year - dob!.year;
    if (today.month < dob!.month ||
        (today.month == dob!.month && today.day < dob!.day)) {
      age--;
    }
    return age;
  }
}

// State
class PatientsState {
  final List<Patient> patients;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const PatientsState({
    this.patients = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  List<Patient> get filtered {
    if (searchQuery.isEmpty) return patients;
    return patients.where((p) =>
      p.fullName.contains(searchQuery) ||
      (p.phone ?? '').contains(searchQuery)
    ).toList();
  }

  PatientsState copyWith({
    List<Patient>? patients,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return PatientsState(
      patients: patients ?? this.patients,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// Notifier
class PatientsNotifier extends Notifier<PatientsState> {
  @override
PatientsState build() {
  Future.microtask(() => fetchPatients());
  return const PatientsState(isLoading: true);
}

  Future<void> fetchPatients() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await SupabaseConfig.client
          .from('patients')
          .select()
          .order('created_at', ascending: false);

      final patients = (data as List).map((e) => Patient.fromMap(e)).toList();
      state = state.copyWith(patients: patients, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<bool> addPatient({
    required String fullName,
    required String tenantId,
    String? phone,
    String? gender,
    String? bloodType,
    DateTime? dob,
  }) async {
    try {
      await SupabaseConfig.client.from('patients').insert({
        'tenant_id': tenantId,
        'full_name': fullName,
        'phone': phone,
        'gender': gender,
        'blood_type': bloodType,
        'dob': dob?.toIso8601String().split('T')[0],
      });
      await fetchPatients();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final patientsProvider = NotifierProvider<PatientsNotifier, PatientsState>(() {
  return PatientsNotifier();
});