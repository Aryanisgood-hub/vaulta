import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/friendly_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import 'bill_form_screen.dart';

/// Transaction "receipt" view.
class BillDetailScreen extends ConsumerWidget {
  const BillDetailScreen({super.key, required this.billId});
  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = (ref.watch(billsProvider).valueOrNull ?? const <Bill>[]).where((b) => b.id == billId).firstOrNull;
    final club = ref.watch(clubProvider).valueOrNull;
    final clubId = ref.watch(clubIdProvider);
    if (bill == null || clubId == null) {
      return Scaffold(appBar: AppBar(), body: const LoadingView());
    }
    final repo = ref.read(billRepoProvider);
    final members = club?.members ?? const <String>[];
    final cs = Theme.of(context).colorScheme;

    Future<void> run(Future<void> Function() f) async {
      try { await f(); } catch (e) { if (context.mounted) showSnack(context, friendlyError(e), error: true); }
    }

    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: TextStyle(color: AppColors.inkText.withAlpha(170))),
            const SizedBox(width: 16),
            Expanded(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkText))),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          if (!bill.isVoid)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BillFormScreen(bill: bill))),
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(24)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(bill.isVoid ? Icons.block : Icons.check_circle, size: 16, color: bill.isVoid ? const Color(0xFFFF8A80) : AppColors.ok),
              const SizedBox(width: 8),
              Text(bill.isVoid ? 'Void' : 'Recorded', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(Money.format(bill.amount), style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800, decoration: bill.isVoid ? TextDecoration.lineThrough : null)),
        ),
        const SizedBox(height: 4),
        Center(child: Text(bill.reason, style: Theme.of(context).textTheme.titleMedium)),
        const SizedBox(height: 20),
        if (bill.isVoid)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              color: cs.errorContainer, borderless: true,
              child: ListTile(
                leading: Icon(Icons.block, color: cs.onErrorContainer),
                title: Text('This bill is void', style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w700)),
                subtitle: Text('${bill.voidReason ?? ''}\nIt is frozen and excluded from all totals.', style: TextStyle(color: cs.onErrorContainer)),
                isThreeLine: true,
              ),
            ),
          ),
        Panel(
          color: AppColors.sand, borderless: true, radius: 24, padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(children: [
            row('Event', bill.eventName),
            row('Category', bill.category),
            row('Paid to', bill.paidTo.isEmpty ? '-' : bill.paidTo),
            row('Bill date', fmtDate(bill.date)),
            row('Done by', bill.doneBy),
            if (bill.receiptName != null) row('Receipt', bill.receiptName!),
          ]),
        ),
        const SizedBox(height: 16),
        if (bill.receiptId != null)
          FilledButton.icon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: AppColors.teal, foregroundColor: Colors.white),
            icon: const Icon(Icons.receipt_long),
            label: const Text('View receipt'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(receiptId: bill.receiptId!, name: bill.receiptName ?? 'receipt'))),
          )
        else
          Center(child: Text('No receipt attached', style: TextStyle(color: cs.onSurfaceVariant))),
        if (!bill.isVoid) ...[
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: cs.error),
              icon: const Icon(Icons.block),
              label: const Text('Void this bill'),
              onPressed: () async {
                final r = await showActionDialog(context, title: 'Void bill?', members: members, askReason: true,
                    reasonLabel: 'Why is it being voided?', confirmLabel: 'Void bill',
                    message: 'Bills are never deleted. A voided bill is frozen and stops counting in totals.');
                if (r != null) await run(() => repo.voidBill(clubId, bill, by: r.by, reason: r.reason));
              },
            ),
          ),
        ],
        const SectionTitle('History'),
        StreamBuilder<List<HistoryEntry>>(
          stream: repo.history(clubId, bill.id),
          builder: (context, snap) {
            final list = snap.data ?? const <HistoryEntry>[];
            if (list.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('No history yet'));
            return Column(children: [
              for (final h in list)
                ListTile(
                  dense: true,
                  leading: Icon(switch (h.action) { 'create' => Icons.add_circle_outline, 'edit' => Icons.edit_outlined, 'void' => Icons.block, _ => Icons.check_circle_outline }),
                  title: Text(h.summary.replaceAll('→', 'to')),
                  subtitle: Text('${h.by} • ${fmtDateTime(h.at)}'),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}

/// Private receipt viewer: receipts are read through Firestore rules (no public link).
class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.receiptId, required this.name});
  final String receiptId, name;
  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  late final Future<Uint8List?> _future = ref.read(billRepoProvider).receiptBytes(ref.read(clubIdProvider)!, widget.receiptId);
  bool get _pdf => widget.name.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.name)),
        body: FutureBuilder<Uint8List?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingView();
            if (snap.hasError || snap.data == null) return ErrorView(snap.hasError ? friendlyError(snap.error!) : 'Receipt not found');
            final bytes = snap.data!;
            if (_pdf) {
              return Center(child: FilledButton.icon(
                icon: const Icon(Icons.open_in_new), label: const Text('Open / share PDF'),
                onPressed: () => Share.shareXFiles([XFile.fromData(bytes, mimeType: 'application/pdf')], fileNameOverrides: [widget.name]),
              ));
            }
            return InteractiveViewer(child: Center(child: Image.memory(bytes)));
          },
        ),
      );
}
