import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/demo_config.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _guard(BuildContext context, Future<void> Function() f) async {
    try { await f(); } catch (e) { if (context.mounted) showSnack(context, friendlyError(e), error: true); }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubProvider).valueOrNull;
    final clubId = ref.watch(clubIdProvider);
    if (club == null || clubId == null) return Scaffold(appBar: AppBar(), body: const LoadingView());
    final repo = ref.read(clubRepoProvider);
    final prefs = ref.read(prefsProvider);

    return Scaffold(
      appBar: pageBar(context, 'Settings'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(child: ListTile(
          leading: const Icon(Icons.groups_outlined),
          title: Text(club.name),
          subtitle: Text(club.email),
        )),

        const SectionTitle('Club budget'),
        Panel(child: Column(children: [
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(Money.format(club.totalBudget)),
            subtitle: const Text('Official budget. Every change is logged.'),
            trailing: FilledButton(
              child: const Text('Change'),
              onPressed: () async {
                final form = GlobalKey<FormState>();
                final amount = TextEditingController(text: Money.toInput(club.totalBudget));
                final reason = TextEditingController();
                String? by;
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('Change budget'),
                  content: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'New budget', prefixText: '₹ '),
                        validator: (v) { try { Money.toPaise(v ?? ''); return null; } on FormatException catch (e) { return e.message; } }),
                    const SizedBox(height: 12),
                    TextFormField(controller: reason, decoration: const InputDecoration(labelText: 'Reason'), validator: (v) => requiredField(v)),
                    const SizedBox(height: 12),
                    NamePicker(members: club.members, value: by, onChanged: (v) => by = v),
                  ]))),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Save')),
                  ],
                ));
                if (ok != true) return;
                await _guard(context, () => repo.updateBudget(clubId,
                    oldBudget: club.totalBudget, newBudget: Money.toPaise(amount.text),
                    by: (by ?? '').trim(), reason: reason.text.trim()));
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Budget change history'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _BudgetLogScreen())),
          ),
        ])),

        const SectionTitle('Categories'),
        _ChipEditor(
          items: club.categories, hint: 'New category',
          onChanged: (v) => _guard(context, () => repo.updateLists(clubId, categories: v)),
        ),
        const SectionTitle('Team names ("Done by")'),
        _ChipEditor(
          items: club.members, hint: 'Add a name',
          helper: 'Everyone shares this club login, so each action records who did it.',
          onChanged: (v) => _guard(context, () => repo.updateLists(clubId, members: v)),
        ),

        const SectionTitle('Security'),
        Panel(child: Column(children: [
          FutureBuilder<bool>(
            future: ref.read(lockServiceProvider).supported(),
            builder: (context, snap) => SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('App lock'),
              subtitle: Text(snap.data == false ? 'Not available on this device' : 'Ask for fingerprint / face / PIN when opening Vaulta'),
              value: ref.watch(lockEnabledProvider),
              onChanged: snap.data != true ? null : (v) async {
                if (v && !await ref.read(lockServiceProvider).authenticate()) return;
                await prefs.setBool('appLock', v);
                ref.read(lockEnabledProvider.notifier).state = v;
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Change password'),
            onTap: () => _changePassword(context, ref),
          ),
        ])),

        const SectionTitle('Appearance'),
        Panel(child: Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: {ref.watch(themeModeProvider)},
            onSelectionChanged: (s) async {
              ref.read(themeModeProvider.notifier).state = s.first;
              await prefs.setString('themeMode', s.first.name);
            },
          ),
        )),

        const SizedBox(height: 24),
        if (!demoOnly) OutlinedButton.icon(
          icon: const Icon(Icons.logout), label: Text(ref.watch(demoModeProvider) ? 'Exit demo' : 'Sign out'),
          onPressed: () async {
            Navigator.of(context).popUntil((r) => r.isFirst);
            if (ref.read(demoModeProvider)) {
              exitDemo(ref);
              return;
            }
            await ref.read(authServiceProvider).signOut();
          },
        ),
      ]),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    if (ref.read(demoModeProvider)) {
      showSnack(context, 'Not available in demo mode.');
      return;
    }
    final form = GlobalKey<FormState>();
    final cur = TextEditingController(), next = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Change password'),
      content: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: cur, obscureText: true, decoration: const InputDecoration(labelText: 'Current password'), validator: (v) => requiredField(v)),
        const SizedBox(height: 12),
        TextFormField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'New password'), validator: passwordRule),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Change')),
      ],
    ));
    if (ok != true) return;
    await _guard(context, () async {
      await ref.read(authServiceProvider).changePassword(cur.text, next.text);
      if (context.mounted) showSnack(context, 'Password changed');
    });
  }
}

class _ChipEditor extends StatefulWidget {
  const _ChipEditor({required this.items, required this.hint, required this.onChanged, this.helper});
  final List<String> items;
  final String hint;
  final String? helper;
  final ValueChanged<List<String>> onChanged;
  @override
  State<_ChipEditor> createState() => _ChipEditorState();
}

class _ChipEditorState extends State<_ChipEditor> {
  final _c = TextEditingController();
  void _add() {
    final v = _c.text.trim();
    if (v.isEmpty || widget.items.contains(v)) return;
    widget.onChanged([...widget.items, v]);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) => Panel(child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.helper != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(widget.helper!, style: Theme.of(context).textTheme.bodySmall)),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final i in widget.items)
              InputChip(label: Text(i), onDeleted: () => widget.onChanged(widget.items.where((x) => x != i).toList())),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _c, decoration: InputDecoration(hintText: widget.hint, isDense: true), onSubmitted: (_) => _add())),
            IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
          ]),
        ]),
      ));
}

class _BudgetLogScreen extends ConsumerWidget {
  const _BudgetLogScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(budgetLogProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Budget history')),
      body: log.isEmpty
          ? const EmptyView(icon: Icons.history, title: 'No budget changes yet')
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final l in log)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Panel(child: ListTile(
                  title: Text('${Money.format(l.oldBudget)} to ${Money.format(l.newBudget)}'),
                  subtitle: Text('${l.reason}\n${l.by} • ${fmtDateTime(l.at)}'),
                  isThreeLine: true,
                ))),
            ]),
    );
  }
}
