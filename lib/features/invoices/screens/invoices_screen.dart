import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/invoices_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_theme.dart';

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(invoicesProvider);

    final filters = [
      {'value': 'all', 'label': 'الكل'},
      {'value': 'unpaid', 'label': 'غير مدفوعة'},
      {'value': 'paid', 'label': 'مدفوعة'},
      {'value': 'cancelled', 'label': 'ملغاة'},
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'إجمالي المدفوع',
                  value: '${state.totalPaid.toStringAsFixed(2)} ₪',
                  color: AppTheme.primary,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  label: 'إجمالي غير المدفوع',
                  value: '${state.totalUnpaid.toStringAsFixed(2)} ₪',
                  color: AppTheme.error,
                  icon: Icons.pending_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  label: 'عدد الفواتير',
                  value: '${state.invoices.length}',
                  color: const Color(0xFF378ADD),
                  icon: Icons.receipt_long_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters + Add
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filters.map((f) {
                      final isSelected = state.filterStatus == f['value'];
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilterChip(
                          label: Text(f['label']!),
                          selected: isSelected,
                          onSelected: (_) => ref
                              .read(invoicesProvider.notifier)
                              .setFilter(f['value']!),
                          selectedColor: AppTheme.primary.withOpacity(0.15),
                          checkmarkColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddInvoiceDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('فاتورة جديدة'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(150, 48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            '${state.filtered.length} فاتورة',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primary))
                : state.filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64,
                                color: AppTheme.textSecondary),
                            SizedBox(height: 12),
                            Text('لا يوجد فواتير',
                                style: TextStyle(
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: state.filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final invoice = state.filtered[index];
                          return _InvoiceCard(
                            invoice: invoice,
                            onPay: () =>
                                _showPayDialog(context, ref, invoice),
                            onCancel: () => ref
                                .read(invoicesProvider.notifier)
                                .cancelInvoice(invoice.id),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddInvoiceDialog(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);

    showDialog(
      context: context,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    final patientsData = await SupabaseConfig.client
        .from('patients')
        .select()
        .order('full_name');

    if (!context.mounted) return;
    Navigator.pop(context);

    final patients = (patientsData as List)
        .map((p) => {'id': p['id'], 'name': p['full_name']})
        .toList();

    String? selectedPatientId;
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('فاتورة جديدة'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedPatientId,
                    decoration: const InputDecoration(
                      labelText: 'المريض *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: patients
                        .map((p) => DropdownMenuItem(
                              value: p['id'] as String,
                              child: Text(p['name'] as String),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => selectedPatientId = v),
                    validator: (v) =>
                        v == null ? 'اختر المريض' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ *',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                      suffixText: '₪',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'أدخل المبلغ';
                      if (double.tryParse(v) == null)
                        return 'مبلغ غير صحيح';
                      return null;
                    },
                  ),
                ],
              ),
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
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => isLoading = true);

                      final success = await ref
                          .read(invoicesProvider.notifier)
                          .addInvoice(
                            tenantId: user!.tenantId,
                            patientId: selectedPatientId!,
                            totalAmount:
                                double.parse(amountController.text),
                          );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'تم إنشاء الفاتورة بنجاح'
                                : 'حدث خطأ، حاول مرة أخرى'),
                            backgroundColor: success
                                ? AppTheme.primary
                                : AppTheme.error,
                          ),
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayDialog(
      BuildContext context, WidgetRef ref, Invoice invoice) {
    String selectedMethod = 'cash';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تسجيل الدفع'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(invoice.patientName ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      Text(
                        '${invoice.totalAmount.toStringAsFixed(2)} ₪',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('طريقة الدفع:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _PayMethodButton(
                      label: 'نقداً',
                      icon: Icons.payments_outlined,
                      selected: selectedMethod == 'cash',
                      onTap: () =>
                          setState(() => selectedMethod = 'cash'),
                    ),
                    const SizedBox(width: 8),
                    _PayMethodButton(
                      label: 'بطاقة',
                      icon: Icons.credit_card_rounded,
                      selected: selectedMethod == 'card',
                      onTap: () =>
                          setState(() => selectedMethod = 'card'),
                    ),
                    const SizedBox(width: 8),
                    _PayMethodButton(
                      label: 'تأمين',
                      icon: Icons.health_and_safety_outlined,
                      selected: selectedMethod == 'insurance',
                      onTap: () =>
                          setState(() => selectedMethod = 'insurance'),
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
                  minimumSize: const Size(120, 40)),
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      final success = await ref
                          .read(invoicesProvider.notifier)
                          .markAsPaid(
                            invoiceId: invoice.id,
                            paymentMethod: selectedMethod,
                          );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'تم تسجيل الدفع بنجاح'
                                : 'حدث خطأ، حاول مرة أخرى'),
                            backgroundColor: success
                                ? AppTheme.primary
                                : AppTheme.error,
                          ),
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('تأكيد الدفع'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayMethodButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PayMethodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withOpacity(0.1)
                : AppTheme.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color:
                      selected ? AppTheme.primary : AppTheme.textSecondary,
                  size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  const _InvoiceCard({
    required this.invoice,
    required this.onPay,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: invoice.statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long_rounded,
                color: invoice.statusColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.patientName ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${invoice.createdAt.year}/${invoice.createdAt.month.toString().padLeft(2, '0')}/${invoice.createdAt.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    if (invoice.paymentMethod != null) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.payment_rounded,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(invoice.paymentMethodLabel,
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Text(
            '${invoice.totalAmount.toStringAsFixed(2)} ₪',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 16),

          // Status badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: invoice.statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              invoice.statusLabel,
              style: TextStyle(
                  color: invoice.statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),

          // Actions
          if (invoice.status == 'unpaid') ...[
            ElevatedButton(
              onPressed: onPay,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 36),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('دفع'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(60, 36),
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
              ),
              child: const Text('إلغاء'),
            ),
          ],
        ],
      ),
    );
  }
}