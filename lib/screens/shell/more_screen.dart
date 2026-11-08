import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money.dart';
import '../../providers/providers.dart';
import '../reimbursements/reimbursements_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(summaryProvider).pendingReimbursement;
    void open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(
          leading: const Icon(Icons.currency_exchange),
          title: const Text('Reimbursements'),
          subtitle: Text(pending > 0 ? '${Money.format(pending)} owed to members' : 'Nothing pending'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => open(const ReimbursementsScreen()),
        )),
        const SizedBox(height: 8),
        Card(child: ListTile(
          leading: const Icon(Icons.assessment_outlined),
          title: const Text('Reports & export'),
          subtitle: const Text('Excel backup, event & monthly reports, PDF'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => open(const ReportsScreen()),
        )),
        const SizedBox(height: 8),
        Card(child: ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          subtitle: const Text('Budget, categories, team names, security, theme'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => open(const SettingsScreen()),
        )),
      ]),
    );
  }
}
