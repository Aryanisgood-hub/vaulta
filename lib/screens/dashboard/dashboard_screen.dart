import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/shell_scope.dart';
import '../bills/bill_detail_screen.dart';
import '../bills/bill_form_screen.dart';
import '../events/events_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubProvider).valueOrNull;
    final s = ref.watch(summaryProvider);
    final bills = ref.watch(billsProvider);
    final events = ref.watch(eventsProvider).valueOrNull ?? const <EventItem>[];
    final cs = Theme.of(context).colorScheme;
    final scope = ShellScope.maybeOf(context);

    final recent = (bills.valueOrNull ?? const <Bill>[]).where((b) => !b.isVoid).take(6).toList();
    final cats = s.byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final bar = s.over ? const Color(0xFFFF8A80) : (s.warn ? AppColors.warn : AppColors.sand);
    final receivedRatio = s.declared == 0 ? 0.0 : (s.received / s.declared).clamp(0.0, 1.0);

    void addBill() {
      if (events.isEmpty) {
        showSnack(context, 'Create an event first. Every bill belongs to an event.');
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BillFormScreen()));
    }

    return Scaffold(
      appBar: pageBar(context, 'Home'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        Center(
          child: Text('Hi, ${club?.name ?? ''}',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 18),

        if (s.over || s.warn)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              color: s.over ? cs.errorContainer : AppColors.sand, borderless: true,
              child: ListTile(
                leading: Icon(s.over ? Icons.error_outline : Icons.warning_amber_rounded, color: s.over ? cs.error : const Color(0xFF8A5A00)),
                title: Text(s.over ? 'Budget exceeded' : '80% of your funds are used',
                    style: TextStyle(fontWeight: FontWeight.w700, color: s.over ? cs.onErrorContainer : AppColors.inkText)),
                subtitle: Text('${Money.format(s.spent)} spent of ${Money.format(s.funds)} available',
                    style: TextStyle(color: s.over ? cs.onErrorContainer : AppColors.inkText)),
              ),
            ),
          ),

        // ---- Balance card
        Panel(
          color: AppColors.teal, borderless: true, radius: 26, padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Remaining balance', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(Money.format(s.remaining), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: s.utilization.clamp(0.0, 1.0), minHeight: 9, backgroundColor: Colors.white24, color: bar),
            ),
            const SizedBox(height: 6),
            Text('${(s.utilization * 100).clamp(0, 999).toStringAsFixed(0)}% of ${Money.format(s.funds)} used',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),

        // ---- Quick actions
        const SizedBox(height: 18),
        Row(children: [
          _QuickAction(icon: Icons.add_card_outlined, label: 'Add bill', onTap: addBill),
          _QuickAction(icon: Icons.celebration_outlined, label: 'New event', onTap: () => showAddEventDialog(context, ref)),
          _QuickAction(icon: Icons.currency_exchange, label: 'Reimburse', onTap: () => scope?.goTo(Pages.reimbursements)),
          _QuickAction(icon: Icons.assessment_outlined, label: 'Reports', onTap: () => scope?.goTo(Pages.reports)),
        ]),

        // ---- Total spent
        const SizedBox(height: 22),
        Panel(
          color: AppColors.teal, borderless: true, radius: 24,
          onTap: () => scope?.goTo(Pages.bills),
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total spent', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(Money.format(s.spent), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Bills ${Money.format(s.gross)}  −  reimbursement ${Money.format(s.appliedReimbursement)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            const SizedBox(width: 12),
            _Ring(value: s.utilization, color: Colors.white, track: Colors.white24, textColor: Colors.white, caption: 'of funds'),
          ]),
        ),

        // ---- Reimbursements: left to use / left to receive
        const SizedBox(height: 12),
        Panel(
          color: AppColors.sand, borderless: true, radius: 24,
          onTap: () => scope?.goTo(Pages.reimbursements),
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Reimbursements', style: TextStyle(color: AppColors.inkText, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _Mini(label: 'Left to use', value: Money.format(s.leftToUse))),
                  Expanded(child: _Mini(label: 'Left to receive', value: Money.format(s.left))),
                ]),
                const SizedBox(height: 8),
                Text('Received ${Money.format(s.received)} of ${Money.format(s.declared)} expected',
                    style: const TextStyle(color: AppColors.inkText, fontSize: 12)),
              ]),
            ),
            const SizedBox(width: 12),
            _Ring(value: receivedRatio, color: AppColors.teal, track: Colors.black12, textColor: AppColors.inkText, caption: 'received'),
          ]),
        ),

        if (club != null && club.totalBudget == 0 && s.gross == 0)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Panel(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Welcome to Vaulta!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Your club\'s money, organised and transparent. To get going:\n\n'
                    '1.  Open Settings and set your club budget\n'
                    '2.  Add your team\'s names in Settings\n'
                    '3.  Create an event, then add bills',
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
              ]),
            ),
          ),

        if (cats.isNotEmpty) ...[
          const SectionTitle('Spending by category'),
          Panel(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              for (final c in cats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(c.key), Text(Money.format(c.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: s.gross == 0 ? 0 : c.value / s.gross, minHeight: 6,
                      borderRadius: BorderRadius.circular(6), color: cs.primary, backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ]),
                ),
            ]),
          ),
        ],

        const SectionTitle('Recent transactions'),
        if (bills.isLoading)
          const LoadingView()
        else if (recent.isEmpty)
          const EmptyView(icon: Icons.receipt_long_outlined, title: 'No bills yet', hint: 'Use "Add bill" above to record your first one')
        else
          for (final b in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BillTile(bill: b, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BillDetailScreen(billId: b.id)))),
            ),
      ]),
    );
  }
}

/// Small number block used inside the reimbursement card.
class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.inkText, fontSize: 12)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(color: AppColors.inkText, fontSize: 22, fontWeight: FontWeight.w800)),
        ),
      ]);
}

/// Percentage ring (real data, instead of a decorative icon).
class _Ring extends StatelessWidget {
  const _Ring({required this.value, required this.color, required this.track, required this.textColor, required this.caption});
  final double value;
  final Color color, track, textColor;
  final String caption;
  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).clamp(0, 999).round();
    return SizedBox(
      width: 68, height: 68,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 68, height: 68,
          child: CircularProgressIndicator(value: value.clamp(0.0, 1.0), strokeWidth: 7, color: color, backgroundColor: track, strokeCap: StrokeCap.round),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$pct%', style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 15)),
          Text(caption, style: TextStyle(color: textColor.withAlpha(190), fontSize: 8.5)),
        ]),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primaryContainer, border: Border.all(color: cs.outlineVariant)),
            child: Icon(icon, color: cs.onPrimaryContainer, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
