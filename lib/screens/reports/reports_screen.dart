import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/friendly_error.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/export_service.dart';
import '../../widgets/common.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _busy = false;

  Future<void> _guard(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _stamp() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _backup() => _guard(() async {
        final club = ref.read(clubProvider).valueOrNull!;
        final bytes = ExportService.fullBackup(
          club: club,
          summary: ref.read(summaryProvider),
          bills: ref.read(billsProvider).valueOrNull ?? const [],
          income: ref.read(incomeProvider).valueOrNull ?? const [],
          events: ref.read(eventsProvider).valueOrNull ?? const [],
          entries: ref.read(reimbursementsProvider).valueOrNull ?? const [],
          log: await ref.read(budgetLogProvider.future),
        );
        await ExportService.share(bytes, 'vaulta-backup-${_stamp()}.xlsx', ExportService.xlsxMime);
      });

  Future<String?> _format() => showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.table_chart_outlined), title: const Text('Excel (.xlsx)'), onTap: () => Navigator.pop(ctx, 'xlsx')),
          ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('PDF'), onTap: () => Navigator.pop(ctx, 'pdf')),
        ])),
      );

  Future<void> _export({
    required String title, required String subtitle, required String file,
    required List<Bill> bills, List<Income> income = const [], required String format,
    List<String> notes = const [],
  }) async {
    final clubName = ref.read(clubProvider).valueOrNull?.name ?? '';
    if (format == 'pdf') {
      final bytes = await ExportService.billsPdf(clubName: clubName, title: title, subtitle: subtitle, bills: bills, income: income, notes: notes);
      await ExportService.share(bytes, '$file.pdf', ExportService.pdfMime);
    } else {
      final bytes = ExportService.billsReport(title.length > 28 ? title.substring(0, 28) : title, bills, income: income, notes: notes);
      await ExportService.share(bytes, '$file.xlsx', ExportService.xlsxMime);
    }
  }

  Future<void> _eventReport() async {
    final events = ref.read(eventsProvider).valueOrNull ?? const <EventItem>[];
    if (events.isEmpty) { showSnack(context, 'No events yet'); return; }
    final ev = await showModalBottomSheet<EventItem>(
      context: context,
      builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true, children: [
        const ListTile(title: Text('Choose an event', style: TextStyle(fontWeight: FontWeight.w700))),
        for (final e in events) ListTile(title: Text(e.name), subtitle: Text(fmtDate(e.date)), onTap: () => Navigator.pop(ctx, e)),
      ])),
    );
    if (ev == null || !mounted) return;
    final format = await _format();
    if (format == null) return;
    final evBills = (ref.read(billsProvider).valueOrNull ?? const <Bill>[]).where((b) => b.eventId == ev.id).toList();
    final st = EventStats.of(ev, evBills, ref.read(reimbursementsProvider).valueOrNull ?? const <ReimbursementEntry>[]);
    await _guard(() => _export(
          title: ev.name, subtitle: 'Event report • ${fmtDate(ev.date)}',
          file: 'vaulta-event-${ev.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}',
          bills: evBills,
          format: format,
          notes: [
            'Bills total: ${Money.forPdf(st.gross)}',
            if (ev.reimbursementAvailable) ...[
              'Reimbursement expected: ${Money.forPdf(st.declared)}',
              'Event expenditure after reimbursement: ${Money.forPdf(st.net)}',
              'Reimbursement received: ${Money.forPdf(st.received)}',
              'Reimbursement left to use: ${Money.forPdf(st.leftToUse)}',
              'Reimbursement left to receive: ${Money.forPdf(st.left)}',
            ],
          ],
        ));
  }

  Future<void> _monthlyReport() async {
    final picked = await showDatePicker(
        context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100),
        helpText: 'Pick any day in the month');
    if (picked == null || !mounted) return;
    final format = await _format();
    if (format == null) return;
    bool inMonth(DateTime d) => d.year == picked.year && d.month == picked.month;
    await _guard(() => _export(
          title: 'Monthly report', subtitle: fmtMonth(picked),
          file: 'vaulta-month-${picked.year}-${picked.month.toString().padLeft(2, '0')}',
          bills: (ref.read(billsProvider).valueOrNull ?? const <Bill>[]).where((b) => inMonth(b.date)).toList(),
          income: (ref.read(incomeProvider).valueOrNull ?? const <Income>[]).where((i) => inMonth(i.date)).toList(),
          format: format,
        ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: pageBar(context, 'Reports & export'),
        body: Stack(children: [
          ListView(padding: const EdgeInsets.all(16), children: [
            Panel(child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Full backup (Excel)'),
              subtitle: const Text('Summary, bills, income, events and budget changes. Do this monthly.'),
              onTap: _busy ? null : _backup,
            )),
            const SizedBox(height: 8),
            Panel(child: ListTile(
              leading: const Icon(Icons.celebration_outlined),
              title: const Text('Event report'),
              subtitle: const Text('All bills for one event, with total (Excel or PDF)'),
              onTap: _busy ? null : _eventReport,
            )),
            const SizedBox(height: 8),
            Panel(child: ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Monthly report'),
              subtitle: const Text('Spending and income in one month (Excel or PDF)'),
              onTap: _busy ? null : _monthlyReport,
            )),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Voided records are excluded from reports. Receipt photos stay in secure storage; reports list each receipt\'s file name.'),
            ),
          ]),
          if (_busy) const LinearProgressIndicator(),
        ]),
      );
}
