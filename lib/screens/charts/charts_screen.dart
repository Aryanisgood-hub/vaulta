import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/chart_data.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/shell_scope.dart';
import '../events/events_screen.dart';

/// Two chart views, switched from the side menu (or the toggle at the top):
///  - monthly expenditure
///  - event-wise expenditure
class ChartsScreen extends ConsumerStatefulWidget {
  const ChartsScreen({super.key, required this.byEvent});
  final bool byEvent;
  @override
  ConsumerState<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends ConsumerState<ChartsScreen> {
  int _months = 6;

  @override
  Widget build(BuildContext context) {
    final scope = ShellScope.maybeOf(context);
    final bills = ref.watch(billsProvider).valueOrNull ?? const <Bill>[];
    final events = ref.watch(eventsProvider).valueOrNull ?? const <EventItem>[];
    final entries = ref.watch(reimbursementsProvider).valueOrNull ?? const <ReimbursementEntry>[];

    return Scaffold(
      appBar: pageBar(context, widget.byEvent ? 'Event-wise expenditure' : 'Monthly expenditure'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Monthly'), icon: Icon(Icons.calendar_month_outlined)),
            ButtonSegment(value: true, label: Text('By event'), icon: Icon(Icons.celebration_outlined)),
          ],
          selected: {widget.byEvent},
          onSelectionChanged: (s) => scope?.goTo(s.first ? Pages.chartsEvent : Pages.chartsMonthly),
        ),
        const SizedBox(height: 16),
        if (widget.byEvent) ..._eventView(context, events, bills, entries) else ..._monthlyView(context, bills),
      ]),
    );
  }

  // ===================================================================
  //  Monthly
  // ===================================================================
  List<Widget> _monthlyView(BuildContext context, List<Bill> bills) {
    final cs = Theme.of(context).colorScheme;
    final data = monthlyTotals(bills, _months, DateTime.now());
    final total = data.fold<int>(0, (a, m) => a + m.amount);
    final maxV = data.fold<int>(0, (a, m) => m.amount > a ? m.amount : a);
    final highest = data.reduce((a, b) => b.amount > a.amount ? b : a);
    final labelFmt = _months > 6 ? 9.0 : 11.0;

    return [
      Row(children: [
        const Expanded(child: Text('Bills spent each month', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: 6, label: Text('6 mo')), ButtonSegment(value: 12, label: Text('12 mo'))],
          selected: {_months},
          onSelectionChanged: (s) => setState(() => _months = s.first),
        ),
      ]),
      const SizedBox(height: 12),
      if (total == 0)
        const Panel(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: EmptyView(icon: Icons.bar_chart_rounded, title: 'No spending in this period', hint: 'Add bills and your monthly chart appears here.'),
        )
      else
        Panel(
          padding: const EdgeInsets.fromLTRB(10, 22, 10, 12),
          child: SizedBox(
            height: 250,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < data.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      SizedBox(
                        height: 16,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(data[i].amount == 0 ? '' : Money.compact(data[i].amount),
                              style: TextStyle(fontSize: labelFmt, fontWeight: FontWeight.w700, color: cs.onSurface)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        key: ValueKey('m$_months-$i-${data[i].amount}'),
                        tween: Tween(begin: 0, end: maxV == 0 ? 0 : data[i].amount / maxV),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Container(
                          height: (v * 180).clamp(data[i].amount == 0 ? 2.0 : 4.0, 180.0),
                          decoration: BoxDecoration(
                            color: i == data.length - 1 ? cs.primary : cs.primary.withAlpha(120),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(_mon(data[i].month), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('Darker bar = current month. Bills are counted by bill date, before reimbursements.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _Stat(label: 'Total', value: Money.format(total), color: AppColors.teal, light: true)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(label: 'Monthly average', value: Money.format((total / _months).round()), color: AppColors.sand)),
      ]),
      const SizedBox(height: 10),
      _Stat(
        label: 'Highest month',
        value: highest.amount == 0 ? '-' : '${fmtMonth(highest.month)}  •  ${Money.format(highest.amount)}',
        color: AppColors.sand,
      ),
    ];
  }

  String _mon(DateTime d) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1];

  // ===================================================================
  //  Event-wise
  // ===================================================================
  List<Widget> _eventView(BuildContext context, List<EventItem> events, List<Bill> bills, List<ReimbursementEntry> entries) {
    final cs = Theme.of(context).colorScheme;
    final data = eventTotals(events, bills, entries).where((t) => t.stats.gross > 0 || t.stats.declared > 0).toList();
    final totalNet = data.fold<int>(0, (a, t) => a + t.stats.net);
    final totalGross = data.fold<int>(0, (a, t) => a + t.stats.gross);
    final maxGross = data.fold<int>(1, (a, t) => t.stats.gross > a ? t.stats.gross : a);

    if (data.isEmpty) {
      return const [
        Panel(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: EmptyView(icon: Icons.bar_chart_rounded, title: 'No event spending yet', hint: 'Create events and add bills to compare them here.'),
        ),
      ];
    }

    Widget legendDot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(t, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]);

    return [
      Row(children: [
        Expanded(child: _Stat(label: 'Total expenditure', value: Money.format(totalNet), color: AppColors.teal, light: true)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(label: 'Bills before reimbursement', value: Money.format(totalGross), color: AppColors.sand)),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 16, runSpacing: 4, children: [
        legendDot(cs.primary, 'Expenditure (after reimbursement)'),
        legendDot(cs.primary.withAlpha(70), 'Bills total'),
      ]),
      const SizedBox(height: 10),
      Panel(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(children: [
          for (var i = 0; i < data.length; i++) ...[
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: data[i].event.id))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(data[i].event.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                    const SizedBox(width: 8),
                    Text(Money.format(data[i].stats.net), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (context, c) {
                    final st = data[i].stats;
                    final w = c.maxWidth;
                    return TweenAnimationBuilder<double>(
                      key: ValueKey('e$i-${st.gross}-${st.net}'),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (_, t, __) => Stack(children: [
                        Container(height: 14, width: w, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8))),
                        Container(height: 14, width: w * (st.gross / maxGross) * t, decoration: BoxDecoration(color: cs.primary.withAlpha(70), borderRadius: BorderRadius.circular(8))),
                        Container(height: 14, width: w * (st.net / maxGross) * t, decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8))),
                      ]),
                    );
                  }),
                  const SizedBox(height: 6),
                  Text(
                    'Bills ${Money.format(data[i].stats.gross)}'
                    '${data[i].event.reimbursementAvailable ? '  •  Reimbursement ${Money.format(data[i].stats.declared)}' : ''}'
                    '  •  ${fmtDate(data[i].event.date)}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ]),
              ),
            ),
            if (i != data.length - 1) Divider(height: 1, color: cs.outlineVariant),
          ],
        ]),
      ),
    ];
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color, this.light = false});
  final String label, value;
  final Color color;
  final bool light; // true -> white text on a dark card
  @override
  Widget build(BuildContext context) {
    final fg = light ? Colors.white : AppColors.inkText;
    return Panel(
      color: color, borderless: true, radius: 20, padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: fg.withAlpha(190), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
