import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../events/events_screen.dart';

/// Reimbursements, event by event.
///  Left to use     = money already received that the bills haven't needed
///  Left to receive = money promised but not received yet
class ReimbursementsScreen extends ConsumerWidget {
  const ReimbursementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(summaryProvider);
    final events = (ref.watch(eventsProvider).valueOrNull ?? const <EventItem>[]).where((e) => e.reimbursementAvailable).toList();
    final bills = ref.watch(billsProvider).valueOrNull ?? const <Bill>[];
    final entries = ref.watch(reimbursementsProvider).valueOrNull ?? const <ReimbursementEntry>[];
    final cs = Theme.of(context).colorScheme;

    Widget big(String label, String value, String hint, {required Color bg, required Color fg}) => Expanded(
          child: Panel(
            color: bg, borderless: true, radius: 22, padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: fg.withAlpha(200), fontSize: 12.5)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: TextStyle(color: fg, fontSize: 24, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 6),
              Text(hint, style: TextStyle(color: fg.withAlpha(170), fontSize: 11, height: 1.25)),
            ]),
          ),
        );

    return Scaffold(
      appBar: pageBar(context, 'Reimbursements'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          big('Left to use', Money.format(s.leftToUse), 'Received, but your bills have not needed it yet', bg: AppColors.teal, fg: Colors.white),
          const SizedBox(width: 12),
          big('Left to receive', Money.format(s.left), 'Promised, but not received yet', bg: AppColors.sand, fg: AppColors.inkText),
        ]),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Expected ${Money.format(s.declared)}  •  Received ${Money.format(s.received)}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ),
        const SectionTitle('By event'),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyView(
              icon: Icons.currency_exchange,
              title: 'No reimbursements yet',
              hint: 'When you create an event, turn on "Reimbursement available?" and enter the amount. It is tracked here.',
            ),
          ),
        for (final e in events)
          Builder(builder: (context) {
            final st = EventStats.of(e, bills, entries);
            Widget pill(String label, String value, Color color) => Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.id))),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                    Text(fmtDate(e.date), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: st.declared == 0 ? 0 : (st.received / st.declared).clamp(0.0, 1.0),
                      minHeight: 8, color: AppColors.ok, backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Received ${Money.format(st.received)} of ${Money.format(st.declared)}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Row(children: [
                    pill('Left to use', Money.format(st.leftToUse), cs.surfaceContainerHigh),
                    const SizedBox(width: 8),
                    pill('Left to receive', Money.format(st.left), cs.surfaceContainerHigh),
                  ]),
                  if (st.left > 0) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_card, size: 18),
                      label: const Text('Record received'),
                      onPressed: () => showRecordReceivedDialog(context, ref, e, st),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Row(children: [
                        Icon(Icons.check_circle, size: 18, color: AppColors.ok),
                        SizedBox(width: 6),
                        Text('Fully received', style: TextStyle(color: AppColors.ok, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ]),
              ),
            );
          }),
      ]),
    );
  }
}
