import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/demo_config.dart';
import '../../providers/providers.dart';
import '../../widgets/shell_scope.dart';
import '../../widgets/vaulta_logo.dart';

/// Side panel navigation (drawer on phones, permanent on wide screens).
/// The item list scrolls, so it never overflows on short windows.
class SideMenu extends ConsumerStatefulWidget {
  const SideMenu({super.key, required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  ConsumerState<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends ConsumerState<SideMenu> {
  bool _chartsOpen = false;

  @override
  Widget build(BuildContext context) {
    final index = widget.index;
    final onSelect = widget.onSelect;
    final cs = Theme.of(context).colorScheme;
    final club = ref.watch(clubProvider).valueOrNull;
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final demo = ref.watch(demoModeProvider);
    final onCharts = index == Pages.chartsMonthly || index == Pages.chartsEvent;
    final chartsOpen = _chartsOpen || onCharts;

    Future<void> toggleTheme() async {
      final next = dark ? ThemeMode.light : ThemeMode.dark;
      ref.read(themeModeProvider.notifier).state = next;
      await ref.read(prefsProvider).setString('themeMode', next.name);
    }

    return Container(
      color: cs.surfaceContainerLow,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ---- header (fixed)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 8, 10),
            child: Row(children: [
              const VaultaLogo(size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Vaulta', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  if (club != null)
                    Text(club.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  if (demo && demoBadge)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(8)),
                      child: Text('DEMO MODE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: cs.onSecondaryContainer)),
                    ),
                ]),
              ),
              IconButton(
                tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
                icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                onPressed: toggleTheme,
              ),
            ]),
          ),

          // ---- items (scrollable)
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              _NavItem(icon: Icons.space_dashboard_outlined, label: 'Home', big: true, selected: index == Pages.home, onTap: () => onSelect(Pages.home)),
              _NavItem(icon: Icons.celebration_outlined, label: 'Events', big: true, selected: index == Pages.events, onTap: () => onSelect(Pages.events)),
              _NavItem(icon: Icons.receipt_long_outlined, label: 'Bills', big: true, selected: index == Pages.bills, onTap: () => onSelect(Pages.bills)),
              _NavItem(icon: Icons.currency_exchange, label: 'Reimbursements', big: true, selected: index == Pages.reimbursements, onTap: () => onSelect(Pages.reimbursements)),
              _NavItem(icon: Icons.savings_outlined, label: 'Income', big: true, selected: index == Pages.income, onTap: () => onSelect(Pages.income)),
              _NavItem(
                icon: Icons.bar_chart_rounded, label: 'Charts', big: true, selected: onCharts,
                trailing: Icon(chartsOpen ? Icons.expand_less : Icons.expand_more, color: cs.onSurfaceVariant),
                onTap: () => setState(() => _chartsOpen = !chartsOpen),
              ),
              if (chartsOpen) ...[
                _NavItem(label: 'Monthly expenditure', indent: true, selected: index == Pages.chartsMonthly, onTap: () => onSelect(Pages.chartsMonthly)),
                _NavItem(label: 'Event-wise expenditure', indent: true, selected: index == Pages.chartsEvent, onTap: () => onSelect(Pages.chartsEvent)),
              ],
              const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Divider()),
              _NavItem(label: 'Reports & export', selected: index == Pages.reports, onTap: () => onSelect(Pages.reports)),
              _NavItem(label: 'Settings', selected: index == Pages.settings, onTap: () => onSelect(Pages.settings)),
            ]),
          ),

          // ---- sign out (hidden in a demo-only build, which has no sign-in)
          if (!demoOnly) ...[
            const Divider(height: 1),
            _NavItem(
              label: demo ? 'Exit demo' : 'Sign out',
              onTap: () {
                if (demo) {
                  exitDemo(ref);
                } else {
                  ref.read(authServiceProvider).signOut();
                }
              },
            ),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    this.icon,
    required this.label,
    this.selected = false,
    this.big = false,
    this.indent = false,
    this.trailing,
    required this.onTap,
  });
  final IconData? icon;
  final String label;
  final bool selected, big, indent;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.onSurface : cs.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.only(left: indent ? 36 : 12, right: 12, top: 2, bottom: 2),
      child: Material(
        color: selected ? cs.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: big ? 12 : 10),
            child: Row(children: [
              if (icon != null) ...[Icon(icon, size: 26, color: color), const SizedBox(width: 14)],
              Expanded(
                child: Text(label, style: TextStyle(
                    fontSize: big ? 19 : 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color)),
              ),
              if (trailing != null) trailing!,
            ]),
          ),
        ),
      ),
    );
  }
}
