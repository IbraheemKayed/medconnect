import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_config.dart';

class LabRequest {
  final String id;
  final String? medicalRecordId;
  final String patientId;
  final String requestedBy;
  final String testName;
  final String status;
  final String? result;
  final DateTime? resultAt;
  final DateTime createdAt;
  final String? patientName;
  final String? requestedByName;

  const LabRequest({
    required this.id,
    this.medicalRecordId,
    required this.patientId,
    required this.requestedBy,
    required this.testName,
    required this.status,
    this.result,
    this.resultAt,
    required this.createdAt,
    this.patientName,
    this.requestedByName,
  });

  factory LabRequest.fromMap(Map<String, dynamic> map) {
    return LabRequest(
      id: map['id'] as String,
      medicalRecordId: map['medical_record_id'] as String?,
      patientId: map['patient_id'] as String,
      requestedBy: map['requested_by'] as String,
      testName: map['test_name'] as String,
      status: map['status'] as String,
      result: map['result'] as String?,
      resultAt: map['result_at'] != null
          ? DateTime.parse(map['result_at']).toLocal()
          : null,
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      patientName: map['patient_name'] as String?,
      requestedByName: map['requested_by_name'] as String?,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending': return 'بانتظار التحليل';
      case 'in_progress': return 'جارٍ';
      case 'completed': return 'مكتمل';
      default: return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending': return const Color(0xFFBA7517);
      case 'in_progress': return const Color(0xFF378ADD);
      case 'completed': return const Color(0xFF1D9E75);
      default: return const Color(0xFF888780);
    }
  }
}

class LabState {
  final List<LabRequest> requests;
  final bool isLoading;
  final String? error;
  final String filterStatus;

  const LabState({
    this.requests = const [],
    this.isLoading = false,
    this.error,
    this.filterStatus = 'all',
  });

  List<LabRequest> get filtered {
    if (filterStatus == 'all') return requests;
    return requests.where((r) => r.status == filterStatus).toList();
  }

  LabState copyWith({
    List<LabRequest>? requests,
    bool? isLoading,
    String? error,
    String? filterStatus,
  }) {
    return LabState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }
}

class LabNotifier extends Notifier<LabState> {
  @override
  LabState build() {
    Future.microtask(() => fetchRequests());
    return const LabState(isLoading: true);
  }

  Future<void> fetchRequests() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await SupabaseConfig.client.rpc('get_lab_requests');
      final requests =
          (data as List).map((e) => LabRequest.fromMap(e)).toList();
      state = state.copyWith(requests: requests, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilter(String status) {
    state = state.copyWith(filterStatus: status);
  }

  Future<bool> addRequest({
    required String patientId,
    required String requestedBy,
    required String testName,
    String? medicalRecordId,
  }) async {
    try {
      await SupabaseConfig.client.from('lab_requests').insert({
        'patient_id': patientId,
        'requested_by': requestedBy,
        'test_name': testName,
        'medical_record_id': medicalRecordId,
        'status': 'pending',
      });
      await fetchRequests();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateResult({
    required String requestId,
    required String result,
  }) async {
    try {
      await SupabaseConfig.client.from('lab_requests').update({
        'result': result,
        'status': 'completed',
        'result_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);
      await fetchRequests();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateStatus(String requestId, String newStatus) async {
    try {
      await SupabaseConfig.client
          .from('lab_requests')
          .update({'status': newStatus})
          .eq('id', requestId);
      await fetchRequests();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final labProvider = NotifierProvider<LabNotifier, LabState>(() {
  return LabNotifier();
});