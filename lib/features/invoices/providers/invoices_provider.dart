import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_config.dart';

class Invoice {
  final String id;
  final String tenantId;
  final String patientId;
  final String? appointmentId;
  final double totalAmount;
  final String status;
  final String? paymentMethod;
  final DateTime? paidAt;
  final DateTime createdAt;
  final String? patientName;

  const Invoice({
    required this.id,
    required this.tenantId,
    required this.patientId,
    this.appointmentId,
    required this.totalAmount,
    required this.status,
    this.paymentMethod,
    this.paidAt,
    required this.createdAt,
    this.patientName,
  });

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      patientId: map['patient_id'] as String,
      appointmentId: map['appointment_id'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      status: map['status'] as String,
      paymentMethod: map['payment_method'] as String?,
      paidAt: map['paid_at'] != null
          ? DateTime.parse(map['paid_at']).toLocal()
          : null,
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      patientName: map['patient_name'] as String?,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'unpaid': return 'غير مدفوعة';
      case 'paid': return 'مدفوعة';
      case 'cancelled': return 'ملغاة';
      default: return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'unpaid': return const Color(0xFFE24B4A);
      case 'paid': return const Color(0xFF1D9E75);
      case 'cancelled': return const Color(0xFF888780);
      default: return const Color(0xFF888780);
    }
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'cash': return 'نقداً';
      case 'card': return 'بطاقة';
      case 'insurance': return 'تأمين';
      default: return '';
    }
  }
}

class InvoicesState {
  final List<Invoice> invoices;
  final bool isLoading;
  final String? error;
  final String filterStatus;

  const InvoicesState({
    this.invoices = const [],
    this.isLoading = false,
    this.error,
    this.filterStatus = 'all',
  });

  List<Invoice> get filtered {
    if (filterStatus == 'all') return invoices;
    return invoices.where((i) => i.status == filterStatus).toList();
  }

  double get totalPaid => invoices
      .where((i) => i.status == 'paid')
      .fold(0, (sum, i) => sum + i.totalAmount);

  double get totalUnpaid => invoices
      .where((i) => i.status == 'unpaid')
      .fold(0, (sum, i) => sum + i.totalAmount);

  InvoicesState copyWith({
    List<Invoice>? invoices,
    bool? isLoading,
    String? error,
    String? filterStatus,
  }) {
    return InvoicesState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }
}

class InvoicesNotifier extends Notifier<InvoicesState> {
  @override
  InvoicesState build() {
    Future.microtask(() => fetchInvoices());
    return const InvoicesState(isLoading: true);
  }

  Future<void> fetchInvoices() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await SupabaseConfig.client.rpc('get_invoices');
      final invoices =
          (data as List).map((e) => Invoice.fromMap(e)).toList();
      state = state.copyWith(invoices: invoices, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilter(String status) {
    state = state.copyWith(filterStatus: status);
  }

  Future<bool> addInvoice({
    required String tenantId,
    required String patientId,
    required double totalAmount,
    String? appointmentId,
  }) async {
    try {
      await SupabaseConfig.client.from('invoices').insert({
        'tenant_id': tenantId,
        'patient_id': patientId,
        'appointment_id': appointmentId,
        'total_amount': totalAmount,
        'status': 'unpaid',
      });
      await fetchInvoices();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAsPaid({
    required String invoiceId,
    required String paymentMethod,
  }) async {
    try {
      await SupabaseConfig.client.from('invoices').update({
        'status': 'paid',
        'payment_method': paymentMethod,
        'paid_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', invoiceId);
      await fetchInvoices();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> cancelInvoice(String invoiceId) async {
    try {
      await SupabaseConfig.client
          .from('invoices')
          .update({'status': 'cancelled'})
          .eq('id', invoiceId);
      await fetchInvoices();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final invoicesProvider =
    NotifierProvider<InvoicesNotifier, InvoicesState>(() {
  return InvoicesNotifier();
});