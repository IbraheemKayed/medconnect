import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_config.dart';

class RadiologyRequest {
  final String id;
  final String? medicalRecordId;
  final String patientId;
  final String requestedBy;
  final String scanType;
  final String status;
  final String? fileUrl;
  final String? report;
  final DateTime? resultAt;
  final DateTime createdAt;
  final String? patientName;
  final String? requestedByName;

  const RadiologyRequest({
    required this.id,
    this.medicalRecordId,
    required this.patientId,
    required this.requestedBy,
    required this.scanType,
    required this.status,
    this.fileUrl,
    this.report,
    this.resultAt,
    required this.createdAt,
    this.patientName,
    this.requestedByName,
  });

  factory RadiologyRequest.fromMap(Map<String, dynamic> map) {
    return RadiologyRequest(
      id: map['id'] as String,
      medicalRecordId: map['medical_record_id'] as String?,
      patientId: map['patient_id'] as String,
      requestedBy: map['requested_by'] as String,
      scanType: map['scan_type'] as String,
      status: map['status'] as String,
      fileUrl: map['file_url'] as String?,
      report: map['report'] as String?,
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
      case 'pending':
        return 'بانتظار التصوير';
      case 'in_progress':
        return 'جارٍ';
      case 'completed':
        return 'مكتمل';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFBA7517);
      case 'in_progress':
        return const Color(0xFF378ADD);
      case 'completed':
        return const Color(0xFF1D9E75);
      default:
        return const Color(0xFF888780);
    }
  }

  bool get hasImage => fileUrl != null && !fileUrl!.startsWith('http') == false
      ? true
      : fileUrl != null;
  bool get hasReport => report != null && report!.isNotEmpty;
  bool get isExternalLink =>
      fileUrl != null &&
      (fileUrl!.startsWith('http://') || fileUrl!.startsWith('https://')) &&
      !fileUrl!.contains('supabase.co/storage');
}

class RadiologyState {
  final List<RadiologyRequest> requests;
  final bool isLoading;
  final String? error;
  final String filterStatus;

  const RadiologyState({
    this.requests = const [],
    this.isLoading = false,
    this.error,
    this.filterStatus = 'all',
  });

  List<RadiologyRequest> get filtered {
    if (filterStatus == 'all') return requests;
    return requests.where((r) => r.status == filterStatus).toList();
  }

  RadiologyState copyWith({
    List<RadiologyRequest>? requests,
    bool? isLoading,
    String? error,
    String? filterStatus,
  }) {
    return RadiologyState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }
}

class RadiologyNotifier extends Notifier<RadiologyState> {
  @override
  RadiologyState build() {
    Future.microtask(() => fetchRequests());
    return const RadiologyState(isLoading: true);
  }

  Future<void> fetchRequests() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await SupabaseConfig.client.rpc('get_radiology_requests');
      final requests = (data as List)
          .map((e) => RadiologyRequest.fromMap(e))
          .toList();
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
    required String scanType,
    String? medicalRecordId,
  }) async {
    try {
      await SupabaseConfig.client.from('radiology_requests').insert({
        'patient_id': patientId,
        'requested_by': requestedBy,
        'scan_type': scanType,
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
    String? report,
    String? fileUrl,
  }) async {
    try {
      await SupabaseConfig.client
          .from('radiology_requests')
          .update({
            'report': report,
            'file_url': fileUrl,
            'status': 'completed',
            'result_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId);
      await fetchRequests();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> uploadImage(
    String requestId,
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final path = 'radiology/$requestId/$fileName';
      await SupabaseConfig.client.storage
          .from('radiology')
          .uploadBinary(path, bytes);

      final url = SupabaseConfig.client.storage
          .from('radiology')
          .getPublicUrl(path);

      return url;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateStatus(String requestId, String newStatus) async {
    try {
      await SupabaseConfig.client
          .from('radiology_requests')
          .update({'status': newStatus})
          .eq('id', requestId);
      await fetchRequests();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final radiologyProvider = NotifierProvider<RadiologyNotifier, RadiologyState>(
  () {
    return RadiologyNotifier();
  },
);
