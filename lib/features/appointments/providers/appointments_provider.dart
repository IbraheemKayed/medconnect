import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_config.dart';

class Appointment {
  final String id;
  final String clinicId;
  final String patientId;
  final String doctorId;
  final String? receptionistId;
  final DateTime scheduledAt;
  final String status;
  final String type;
  final String? notes;
  final String? patientName;
  final String? doctorName;
  final String? clinicName;

  const Appointment({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.doctorId,
    this.receptionistId,
    required this.scheduledAt,
    required this.status,
    required this.type,
    this.notes,
    this.patientName,
    this.doctorName,
    this.clinicName,
  });
  factory Appointment.fromRpc(Map<String, dynamic> map) {
  return Appointment(
    id: map['id'] as String,
    clinicId: map['clinic_id'] as String,
    patientId: map['patient_id'] as String,
    doctorId: map['doctor_id'] as String,
    receptionistId: map['receptionist_id'] as String?,
    scheduledAt: DateTime.parse(map['scheduled_at']).toLocal(),
    status: map['status'] as String,
    type: map['type'] as String? ?? 'in_person',
    notes: map['notes'] as String?,
    patientName: map['patient_name'] as String?,
    doctorName: map['doctor_name'] as String?,
    clinicName: map['clinic_name'] as String?,
  );
}

  factory Appointment.fromMap(Map<String, dynamic> map) {
  return Appointment(
    id: map['id'] as String,
    clinicId: map['clinic_id'] as String,
    patientId: map['patient_id'] as String,
    doctorId: map['doctor_id'] as String,
    receptionistId: map['receptionist_id'] as String?,
    scheduledAt: DateTime.parse(map['scheduled_at']).toLocal(),
    status: map['status'] as String,
    type: map['type'] as String? ?? 'in_person',
    notes: map['notes'] as String?,
    patientName: map['patients'] != null
        ? map['patients']['full_name'] as String?
        : null,
    doctorName: map['users'] != null
        ? map['users']['full_name'] as String?
        : null,
    clinicName: map['clinics'] != null
        ? map['clinics']['name'] as String?
        : null,
  );
}
  String get statusLabel {
    switch (status) {
      case 'pending': return 'بانتظار التأكيد';
      case 'confirmed': return 'مؤكد';
      case 'in_progress': return 'جارٍ';
      case 'completed': return 'مكتمل';
      case 'cancelled': return 'ملغى';
      default: return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending': return const Color(0xFFBA7517);
      case 'confirmed': return const Color(0xFF378ADD);
      case 'in_progress': return const Color(0xFF534AB7);
      case 'completed': return const Color(0xFF1D9E75);
      case 'cancelled': return const Color(0xFFE24B4A);
      default: return const Color(0xFF888780);
    }
  }

  String get typeLabel => type == 'video' ? 'فيديو' : 'حضوري';
}

class AppointmentsState {
  final List<Appointment> appointments;
  final bool isLoading;
  final String? error;
  final String filterStatus;
  final DateTime selectedDate;

  const AppointmentsState({
    this.appointments = const [],
    this.isLoading = false,
    this.error,
    this.filterStatus = 'all',
    required this.selectedDate,
  });

  List<Appointment> get filtered {
    return appointments.where((a) {
      final matchStatus =
          filterStatus == 'all' || a.status == filterStatus;
      return matchStatus;
    }).toList();
  }

  AppointmentsState copyWith({
    List<Appointment>? appointments,
    bool? isLoading,
    String? error,
    String? filterStatus,
    DateTime? selectedDate,
  }) {
    return AppointmentsState(
      appointments: appointments ?? this.appointments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filterStatus: filterStatus ?? this.filterStatus,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

class AppointmentsNotifier extends Notifier<AppointmentsState> {
  @override
  AppointmentsState build() {
    Future.microtask(() => fetchAppointments());
    return AppointmentsState(selectedDate: DateTime.now());
  }

  Future<void> fetchAppointments() async {
  state = state.copyWith(isLoading: true, error: null);
  try {
    final date = state.selectedDate;
    final startOfDay =
        DateTime(date.year, date.month, date.day).toUtc().toIso8601String();
    final endOfDay =
        DateTime(date.year, date.month, date.day, 23, 59, 59)
            .toUtc()
            .toIso8601String();

    final data = await SupabaseConfig.client.rpc('get_appointments', params: {
      'start_date': startOfDay,
      'end_date': endOfDay,
    });

    final appointments =
        (data as List).map((e) => Appointment.fromRpc(e)).toList();
    state = state.copyWith(appointments: appointments, isLoading: false);
  } catch (e) {
    state = state.copyWith(isLoading: false, error: e.toString());
  }
}

  void setDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
    fetchAppointments();
  }

  void setFilter(String status) {
    state = state.copyWith(filterStatus: status);
  }

  Future<bool> addAppointment({
    required String clinicId,
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    String type = 'in_person',
    String? notes,
    String? receptionistId,
  }) async {
    try {
      await SupabaseConfig.client.from('appointments').insert({
        'clinic_id': clinicId,
        'patient_id': patientId,
        'doctor_id': doctorId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'type': type,
        'notes': notes,
        'receptionist_id': receptionistId,
        'status': 'pending',
      });
      await fetchAppointments();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateStatus(String appointmentId, String newStatus) async {
    try {
      await SupabaseConfig.client
          .from('appointments')
          .update({'status': newStatus})
          .eq('id', appointmentId);
      await fetchAppointments();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final appointmentsProvider =
    NotifierProvider<AppointmentsNotifier, AppointmentsState>(() {
  return AppointmentsNotifier();
});