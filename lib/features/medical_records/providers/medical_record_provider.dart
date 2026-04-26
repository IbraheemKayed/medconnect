import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_config.dart';

class PatientFile {
  final String patientId;
  final String fullName;
  final String? phone;
  final String? gender;
  final String? bloodType;
  final int? age;
  final List<MedicalRecord> records;
  final List<LabRequest> labRequests;
  final List<RadiologyRequest> radiologyRequests;
  final List<Prescription> prescriptions;
  final List<Allergy> allergies;

  const PatientFile({
    required this.patientId,
    required this.fullName,
    this.phone,
    this.gender,
    this.bloodType,
    this.age,
    this.records = const [],
    this.labRequests = const [],
    this.radiologyRequests = const [],
    this.prescriptions = const [],
    this.allergies = const [],
  });
}

class MedicalRecord {
  final String id;
  final String? diagnosis;
  final String? notes;
  final DateTime createdAt;
  final String doctorName;

  const MedicalRecord({
    required this.id,
    this.diagnosis,
    this.notes,
    required this.createdAt,
    required this.doctorName,
  });
}

class LabRequest {
  final String id;
  final String testName;
  final String status;
  final String? result;
  final DateTime createdAt;

  const LabRequest({
    required this.id,
    required this.testName,
    required this.status,
    this.result,
    required this.createdAt,
  });
}

class RadiologyRequest {
  final String id;
  final String scanType;
  final String status;
  final String? report;
  final String? fileUrl;
  final DateTime createdAt;

  const RadiologyRequest({
    required this.id,
    required this.scanType,
    required this.status,
    this.report,
    this.fileUrl,
    required this.createdAt,
  });
}

class Prescription {
  final String id;
  final String medicineName;
  final String? dosage;
  final String? duration;
  final String? notes;

  const Prescription({
    required this.id,
    required this.medicineName,
    this.dosage,
    this.duration,
    this.notes,
  });
}

class Allergy {
  final String id;
  final String allergyName;
  final String? severity;
  final String? notes;

  const Allergy({
    required this.id,
    required this.allergyName,
    this.severity,
    this.notes,
  });

  String get severityLabel {
    switch (severity) {
      case 'mild':
        return 'خفيفة';
      case 'moderate':
        return 'متوسطة';
      case 'severe':
        return 'شديدة';
      default:
        return '';
    }
  }

  Color get severityColor {
    switch (severity) {
      case 'mild':
        return const Color(0xFF1D9E75);
      case 'moderate':
        return const Color(0xFFBA7517);
      case 'severe':
        return const Color(0xFFE24B4A);
      default:
        return const Color(0xFF888780);
    }
  }
}

class PatientFileNotifier extends AsyncNotifier<PatientFile?> {
  @override
  Future<PatientFile?> build() async => null;
  Future<void> load(String patientId) async {
    state = const AsyncLoading();
    try {
      final patient = await SupabaseConfig.client
          .from('patients')
          .select()
          .eq('id', patientId)
          .single();

      final records = await SupabaseConfig.client
          .from('medical_records')
          .select('*, users(full_name)')
          .eq('patient_id', patientId)
          .order('created_at', ascending: false);

      final labRequests = await SupabaseConfig.client
          .from('lab_requests')
          .select()
          .eq('patient_id', patientId)
          .order('created_at', ascending: false);

      final radiologyRequests = await SupabaseConfig.client
          .from('radiology_requests')
          .select()
          .eq('patient_id', patientId)
          .order('created_at', ascending: false);

      final prescriptions = await SupabaseConfig.client
          .from('prescriptions')
          .select('*, medical_records!inner(patient_id)')
          .eq('medical_records.patient_id', patientId);

      final allergies = await SupabaseConfig.client
          .from('patient_allergies')
          .select()
          .eq('patient_id', patientId)
          .order('created_at', ascending: false);

      DateTime? dob = patient['dob'] != null
          ? DateTime.parse(patient['dob'])
          : null;
      int? age;
      if (dob != null) {
        final today = DateTime.now();
        age = today.year - dob.year;
        if (today.month < dob.month ||
            (today.month == dob.month && today.day < dob.day))
          age--;
      }

      state = AsyncData(
        PatientFile(
          patientId: patientId,
          fullName: patient['full_name'] as String,
          phone: patient['phone'] as String?,
          gender: patient['gender'] as String?,
          bloodType: patient['blood_type'] as String?,
          age: age,
          records: (records as List)
              .map(
                (r) => MedicalRecord(
                  id: r['id'],
                  diagnosis: r['diagnosis'],
                  notes: r['notes'],
                  createdAt: DateTime.parse(r['created_at']).toLocal(),
                  doctorName: r['users']['full_name'],
                ),
              )
              .toList(),
          labRequests: (labRequests as List)
              .map(
                (r) => LabRequest(
                  id: r['id'],
                  testName: r['test_name'],
                  status: r['status'],
                  result: r['result'],
                  createdAt: DateTime.parse(r['created_at']).toLocal(),
                ),
              )
              .toList(),
          radiologyRequests: (radiologyRequests as List)
              .map(
                (r) => RadiologyRequest(
                  id: r['id'],
                  scanType: r['scan_type'],
                  status: r['status'],
                  report: r['report'],
                  fileUrl: r['file_url'],
                  createdAt: DateTime.parse(r['created_at']).toLocal(),
                ),
              )
              .toList(),
          prescriptions: (prescriptions as List)
              .map(
                (p) => Prescription(
                  id: p['id'],
                  medicineName: p['medicine_name'],
                  dosage: p['dosage'],
                  duration: p['duration'],
                  notes: p['notes'],
                ),
              )
              .toList(),

          allergies: (allergies as List)
              .map(
                (a) => Allergy(
                  id: a['id'],
                  allergyName: a['allergy_name'],
                  severity: a['severity'],
                  notes: a['notes'],
                ),
              )
              .toList(),
        ),
      );
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<bool> addRecord({
    required String patientId,
    required String doctorId,
    String? appointmentId,
    String? diagnosis,
    String? notes,
  }) async {
    try {
      await SupabaseConfig.client.from('medical_records').insert({
        'patient_id': patientId,
        'doctor_id': doctorId,
        'appointment_id': appointmentId,
        'diagnosis': diagnosis,
        'notes': notes,
      });
      await load(patientId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addLabRequest({
    required String patientId,
    required String requestedBy,
    required String testName,
  }) async {
    try {
      await SupabaseConfig.client.from('lab_requests').insert({
        'patient_id': patientId,
        'requested_by': requestedBy,
        'test_name': testName,
        'status': 'pending',
      });
      await load(patientId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addRadiologyRequest({
    required String patientId,
    required String requestedBy,
    required String scanType,
  }) async {
    try {
      await SupabaseConfig.client.from('radiology_requests').insert({
        'patient_id': patientId,
        'requested_by': requestedBy,
        'scan_type': scanType,
        'status': 'pending',
      });
      await load(patientId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addPrescription({
    required String medicalRecordId,
    required String medicineName,
    String? dosage,
    String? duration,
    String? notes,
  }) async {
    try {
      await SupabaseConfig.client.from('prescriptions').insert({
        'medical_record_id': medicalRecordId,
        'medicine_name': medicineName,
        'dosage': dosage,
        'duration': duration,
        'notes': notes,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addAllergy({
  required String patientId,
  required String allergyName,
  String? severity,
  String? notes,
}) async {
  try {
    await SupabaseConfig.client.from('patient_allergies').insert({
      'patient_id': patientId,
      'allergy_name': allergyName,
      'severity': severity,
      'notes': notes,
    });
    await load(patientId);
    return true;
  } catch (e) {
    return false;
  }
}

Future<bool> deleteAllergy(String allergyId, String patientId) async {
  try {
    await SupabaseConfig.client
        .from('patient_allergies')
        .delete()
        .eq('id', allergyId);
    await load(patientId);
    return true;
  } catch (e) {
    return false;
  }
}
}



final patientFileProvider =
    AsyncNotifierProvider<PatientFileNotifier, PatientFile?>(
      PatientFileNotifier.new,
    );
