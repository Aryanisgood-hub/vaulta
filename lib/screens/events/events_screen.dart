import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/friendly_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../bills/bill_detail_screen.dart';

// ====================================================================
//  Dialogs (shared with the Home and Reimbursements pages)
// ====================================================================

/// New event, with the "is reimbursement available, and how much?" question.
Future<void> showAddEventDialog(BuildContext context, WidgetRef ref) async {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), desc = TextEditingController(), amount = TextEditingController();
  var date = DateTime.now();
  var reimb = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('New event'),
      content: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Event name'), validator: (v) => requiredField(v)),
        const SizedBox(height: 12),
        TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Description (optional)')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.event),
          label: Text(fmtDate(date)),
          onPressed: () async {
            final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setS(() => date = d);
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reimbursement available?'),
          subtitle: const Text('Will the college, department or a sponsor pay some of this event back?'),
          value: reimb,
          onChanged: (v) => setS(() => reimb = v),
        ),
        if (reimb)
          TextFormField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Reimbursement amount', prefixText: '₹ '),
            validator: Money.validate,
          ),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Create')),
      ],
    )),
  );
  if (ok != true) return;
  try {
    await ref.read(eventRepoProvider).add(
      ref.read(clubIdProvider)!,
      name: name.text, date: date, description: desc.text,
      reimbursementAvailable: reimb,
      reimbursementAmount: reimb ? Money.toPaise(amount.text) : 0,
    );
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e), error: true);
  }
}

/// Change an event's name, description or date.
Future<void> showEditEventDialog(BuildContext context, WidgetRef ref, EventItem event) async {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(text: event.name);
  final desc = TextEditingController(text: event.description);
  var date = event.date;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('Edit event'),
      content: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Event name'), validator: (v) => requiredField(v)),
        const SizedBox(height: 12),
        TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Description (optional)')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.event),
          label: Text(fmtDate(date)),
          onPressed: () async {
            final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setS(() => date = d);
          },
        ),
        const SizedBox(height: 10),
        Text('Bills and reports will show the new name everywhere.', style: Theme.of(ctx).textTheme.bodySmall),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Save')),
      ],
    )),
  );
  if (ok != true) return;
  try {
    await ref.read(eventRepoProvider).updateDetails(
      ref.read(clubIdProvider)!, event, name: name.text, date: date, description: desc.text);
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e), error: true);
  }
}

/// Turn reimbursement on/off for an event and set how much.
Future<void> showEditReimbursementDialog(BuildContext context, WidgetRef ref, EventItem event, EventStats stats) async {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(text: event.reimbursementAmount > 0 ? Money.toInput(event.reimbursementAmount) : '');
  var reimb = event.reimbursementAvailable;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: Text('Reimbursement for ${event.name}'),
      content: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reimbursement available?'),
          value: reimb,
          onChanged: stats.received > 0 ? null : (v) => setS(() => reimb = v),
        ),
        if (stats.received > 0)
          Text('${Money.format(stats.received)} is already recorded as received, so this stays on.',
              style: Theme.of(ctx).textTheme.bodySmall),
        if (reimb) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Reimbursement amount', prefixText: '₹ '),
            validator: (v) {
              final e = Money.validate(v);
              if (e != null) return e;
              if (Money.toPaise(v!) < stats.received) return 'Cannot be less than ${Money.format(stats.received)} already received';
              return null;
            },
          ),
        ],
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Save')),
      ],
    )),
  );
  if (ok != true) return;
  try {
    await ref.read(eventRepoProvider).setReimbursement(
      ref.read(clubIdProvider)!, event.id,
      available: reimb, amount: reimb ? Money.toPaise(amount.text) : 0);
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e), error: true);
  }
}

/// Record reimbursement money that has actually arrived.
Future<void> showRecordReceivedDialog(BuildContext context, WidgetRef ref, EventItem event, EventStats stats) async {
  final members = ref.read(clubProvider).valueOrNull?.members ?? const <String>[];
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(), note = TextEditingController();
  var date = DateTime.now();
  String? by;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: Text('Reimbursement received: ${event.name}'),
      content: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Still to receive: ${Money.format(stats.left)}'),
        const SizedBox(height: 12),
        TextFormField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount received', prefixText: '₹ '),
          validator: (v) {
            final e = Money.validate(v);
            if (e != null) return e;
            if (Money.toPaise(v!) > stats.left) return 'Only ${Money.format(stats.left)} is left to receive';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional), e.g. cheque no.')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.event), label: Text(fmtDate(date)),
          onPressed: () async {
            final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
            if (d != null) setS(() => date = d);
          },
        ),
        const SizedBox(height: 12),
        NamePicker(members: members, value: by, onChanged: (v) => by = v),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Record')),
      ],
    )),
  );
  if (ok != true) return;
  try {
    await ref.read(reimbursementRepoProvider).add(ref.read(clubIdProvider)!, ReimbursementEntry(
      eventId: event.id, eventName: event.name, amount: Money.toPaise(amount.text),
      date: date, note: note.text.trim(), doneBy: (by ?? '').trim(),
    ));
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e), error: true);
  }
}

// ====================================================================
//  Events page
// ====================================================================
class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final bills = ref.watch(billsProvider).valueOrNull ?? const <Bill>[];
    final entries = ref.watch(reimbursementsProvider).valueOrNull ?? const <ReimbursementEntry>[];
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: pageBar(context, 'Events'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddEventDialog(context, ref), icon: const Icon(Icons.add), label: const Text('Event')),
      body: events.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(friendlyError(e)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(icon: Icons.celebration_outlined, title: 'No events yet', hint: 'Every bill belongs to an event. Create one first.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final e = list[i];
              final st = EventStats.of(e, bills, entries);
              final count = bills.where((b) => b.eventId == e.id && !b.isVoid).length;
              return Panel(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.id))),
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  CircleAvatar(radius: 22, backgroundColor: cs.primaryContainer, child: Icon(Icons.celebration_outlined, color: cs.onPrimaryContainer)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('${fmtDate(e.date)} • $count bills', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    if (e.reimbursementAvailable) ...[
                      const SizedBox(height: 4),
                      Text('Reimbursement ${Money.format(st.declared)} • left ${Money.format(st.left)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.ok, fontWeight: FontWeight.w600)),
                    ],
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(Money.format(st.net), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('expenditure', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

// ====================================================================
//  Event detail
// ====================================================================
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = (ref.watch(eventsProvider).valueOrNull ?? const <EventItem>[]).where((e) => e.id == eventId).firstOrNull;
    if (event == null) return Scaffold(appBar: AppBar(), body: const LoadingView());
    final allBills = ref.watch(billsProvider).valueOrNull ?? const <Bill>[];
    final allEntries = ref.watch(reimbursementsProvider).valueOrNull ?? const <ReimbursementEntry>[];
    final bills = allBills.where((b) => b.eventId == event.id).toList();
    final entries = allEntries.where((x) => x.eventId == event.id).toList();
    final st = EventStats.of(event, allBills, allEntries);
    final members = ref.watch(clubProvider).valueOrNull?.members ?? const <String>[];
    final cs = Theme.of(context).colorScheme;

    Widget row(String k, String v, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(k, style: const TextStyle(color: Colors.white70)),
            Text(v, style: TextStyle(color: color ?? Colors.white, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(event.name),
        actions: [
          IconButton(
            tooltip: 'Edit event',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showEditEventDialog(context, ref, event),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Panel(
          color: AppColors.teal, borderless: true, radius: 24, padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${fmtDate(event.date)}${event.description.isEmpty ? '' : '  •  ${event.description}'}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 10),
            const Text('Event expenditure', style: TextStyle(color: Colors.white70)),
            Text(Money.format(st.net), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Divider(color: Colors.white24),
            row('Bills total', Money.format(st.gross)),
            row('Reimbursement applied', '- ${Money.format(st.applied)}'),
          ]),
        ),
        const SectionTitle('Reimbursement'),
        Panel(
          color: AppColors.sand, borderless: true, padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!event.reimbursementAvailable) ...[
              const Text('No reimbursement is set for this event.', style: TextStyle(color: AppColors.inkText)),
              const SizedBox(height: 10),
              FilledButton(onPressed: () => showEditReimbursementDialog(context, ref, event, st), child: const Text('Set reimbursement')),
            ] else ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Reimbursement amount', style: TextStyle(color: AppColors.inkText)),
                Text(Money.format(st.declared), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkText)),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Received so far', style: TextStyle(color: AppColors.inkText)),
                Text(Money.format(st.received), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkText)),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Left to use', style: TextStyle(color: AppColors.inkText)),
                Text(Money.format(st.leftToUse), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkText)),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Left to receive', style: TextStyle(color: AppColors.inkText)),
                Text(Money.format(st.left), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkText)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: st.declared == 0 ? 0 : (st.received / st.declared).clamp(0.0, 1.0),
                  minHeight: 8, backgroundColor: Colors.black12, color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (st.left > 0)
                  FilledButton.icon(
                    icon: const Icon(Icons.add_card), label: const Text('Record received'),
                    onPressed: () => showRecordReceivedDialog(context, ref, event, st),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined), label: const Text('Change amount'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.inkText),
                  onPressed: () => showEditReimbursementDialog(context, ref, event, st),
                ),
              ]),
            ],
          ]),
        ),
        if (entries.isNotEmpty) ...[
          const SectionTitle('Reimbursements received'),
          for (final x in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.south_west)),
                  title: Text(Money.format(x.amount), style: TextStyle(fontWeight: FontWeight.w700, decoration: x.isVoid ? TextDecoration.lineThrough : null)),
                  subtitle: Text('${fmtDate(x.date)} • ${x.doneBy}${x.note.isEmpty ? '' : '\n${x.note}'}${x.isVoid ? '\nVOID: ${x.voidReason ?? ''}' : ''}'),
                  isThreeLine: x.note.isNotEmpty || x.isVoid,
                  trailing: x.isVoid ? null : IconButton(
                    tooltip: 'Void',
                    icon: const Icon(Icons.block, size: 20),
                    onPressed: () async {
                      final clubId = ref.read(clubIdProvider)!;
                      final r = await showActionDialog(context, title: 'Void this entry?', members: members, askReason: true,
                          reasonLabel: 'Reason', confirmLabel: 'Void',
                          message: 'Entries are never deleted. Voiding puts this amount back under "left to receive".');
                      if (r == null) return;
                      try {
                        await ref.read(reimbursementRepoProvider).voidEntry(clubId, x.id, '${r.reason} (by ${r.by})');
                      } catch (e) {
                        if (context.mounted) showSnack(context, friendlyError(e), error: true);
                      }
                    },
                  ),
                ),
              ),
            ),
        ],
        const SectionTitle('Bills'),
        if (bills.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No bills for this event yet.')),
        for (final b in bills)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BillTile(bill: b, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BillDetailScreen(billId: b.id)))),
          ),
        SizedBox(height: 4, child: ColoredBox(color: cs.surface)),
      ]),
    );
  }
}
