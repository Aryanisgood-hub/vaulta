import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class IncomeScreen extends ConsumerWidget {
  const IncomeScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final members = ref.read(clubProvider).valueOrNull?.members ?? const <String>[];
    final form = GlobalKey<FormState>();
    final amount = TextEditingController(), source = TextEditingController(), note = TextEditingController();
    var type = incomeTypes.first, date = DateTime.now();
    String? by;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('Add income'),
        content: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '), validator: Money.validate),
          const SizedBox(height: 12),
          TextFormField(controller: source, decoration: const InputDecoration(labelText: 'Source (who paid?)'), validator: (v) => requiredField(v)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: type, decoration: const InputDecoration(labelText: 'Type'),
            items: [for (final t in incomeTypes) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (v) => setS(() => type = v ?? type),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 12),
          OutlinedButton.icon(icon: const Icon(Icons.event), label: Text(fmtDate(date)), onPressed: () async {
            final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
            if (d != null) setS(() => date = d);
          }),
          const SizedBox(height: 12),
          NamePicker(members: members, value: by, onChanged: (v) => by = v),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Add')),
        ],
      )),
    );
    if (ok != true) return;
    try {
      await ref.read(incomeRepoProvider).add(ref.read(clubIdProvider)!, Income(
        amount: Money.toPaise(amount.text), source: source.text.trim(), type: type,
        date: date, note: note.text.trim(), doneBy: (by ?? '').trim()));
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final income = ref.watch(incomeProvider);
    final s = ref.watch(summaryProvider);
    final members = ref.watch(clubProvider).valueOrNull?.members ?? const <String>[];
    return Scaffold(
      appBar: pageBar(context, 'Income'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref), icon: const Icon(Icons.add), label: const Text('Income')),
      body: income.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(friendlyError(e)),
        data: (list) => list.isEmpty
            ? const EmptyView(icon: Icons.savings_outlined, title: 'No income recorded', hint: 'Add sponsorships, fees and grants so your balance is accurate.')
            : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
                Panel(child: ListTile(
                  title: const Text('Total income'),
                  trailing: Text(Money.format(s.income), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.ok)),
                )),
                const SizedBox(height: 8),
                for (final i in list)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Panel(child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.south_west)),
                    title: Text(i.source, style: TextStyle(decoration: i.isVoid ? TextDecoration.lineThrough : null)),
                    subtitle: Text('${i.type} • ${fmtDate(i.date)} • ${i.doneBy}${i.isVoid ? '\nVOID: ${i.voidReason ?? ''}' : ''}'),
                    isThreeLine: i.isVoid,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(Money.format(i.amount), style: TextStyle(fontWeight: FontWeight.w700, color: i.isVoid ? null : AppColors.ok)),
                      if (!i.isVoid)
                        IconButton(
                          tooltip: 'Void',
                          icon: const Icon(Icons.block, size: 20),
                          onPressed: () async {
                            final clubId = ref.read(clubIdProvider)!;
                            final r = await showActionDialog(context, title: 'Void this income?', members: members,
                                askReason: true, reasonLabel: 'Reason', confirmLabel: 'Void',
                                message: 'Income is never deleted. Voiding removes it from your balance.');
                            if (r == null) return;
                            try {
                              await ref.read(incomeRepoProvider).voidIncome(clubId, i.id, '${r.reason} (by ${r.by})');
                            } catch (e) {
                              if (context.mounted) showSnack(context, friendlyError(e), error: true);
                            }
                          },
                        ),
                    ]),
                  ))),
              ]),
      ),
    );
  }
}
