import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/friendly_error.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import 'bill_detail_screen.dart';
import 'bill_form_screen.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(billsProvider);
    final bills = ref.watch(filteredBillsProvider);
    final events = ref.watch(eventsProvider).valueOrNull ?? const [];
    final club = ref.watch(clubProvider).valueOrNull;
    final status = ref.watch(billStatusProvider);
    final eventF = ref.watch(billEventProvider);
    final catF = ref.watch(billCategoryProvider);

    return Scaffold(
      appBar: pageBar(context, 'Bills'),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Bill'),
        onPressed: () {
          if (events.isEmpty) {
            showSnack(context, 'Create an event first (Events tab). Every bill belongs to an event.');
            return;
          }
          Navigator.push(context, MaterialPageRoute(builder: (_) => const BillFormScreen()));
        },
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search reason, person, amount, event…'),
            onChanged: (v) => ref.read(billQueryProvider.notifier).state = v,
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final s in const [('active', 'Active'), ('void', 'Void'), ('all', 'All')])
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(
                label: Text(s.$2), selected: status == s.$1,
                onSelected: (_) => ref.read(billStatusProvider.notifier).state = s.$1)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: PopupMenuButton<String?>(
              onSelected: (v) => ref.read(billEventProvider.notifier).state = v == '' ? null : v,
              itemBuilder: (_) => [
                const PopupMenuItem(value: '', child: Text('All events')),
                for (final e in events) PopupMenuItem(value: e.id, child: Text(e.name)),
              ],
              child: Chip(avatar: const Icon(Icons.celebration_outlined, size: 16),
                  label: Text(eventF == null ? 'Event' : events.where((e) => e.id == eventF).map((e) => e.name).firstOrNull ?? 'Event')),
            )),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: PopupMenuButton<String?>(
              onSelected: (v) => ref.read(billCategoryProvider.notifier).state = v == '' ? null : v,
              itemBuilder: (_) => [
                const PopupMenuItem(value: '', child: Text('All categories')),
                for (final c in club?.categories ?? const <String>[]) PopupMenuItem(value: c, child: Text(c)),
              ],
              child: Chip(avatar: const Icon(Icons.category_outlined, size: 16), label: Text(catF ?? 'Category')),
            )),
          ]),
        ),
        Expanded(
          child: all.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(friendlyError(e)),
            data: (_) => bills.isEmpty
                ? const EmptyView(icon: Icons.receipt_long_outlined, title: 'No bills found', hint: 'Tap "Bill" to add one, or change the filters.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    itemCount: bills.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => BillTile(
                      bill: bills[i],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BillDetailScreen(billId: bills[i].id))),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}
