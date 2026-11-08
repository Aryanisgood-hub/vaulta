import 'package:flutter/material.dart';

import '../../widgets/shell_scope.dart';
import '../bills/bills_screen.dart';
import '../charts/charts_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../events/events_screen.dart';
import '../income/income_screen.dart';
import '../reimbursements/reimbursements_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import 'side_menu.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  final _history = <int>[]; // pages visited before this one, for the Back button
  final _key = GlobalKey<ScaffoldState>();

  // Order must match the Pages constants.
  static const _pages = <Widget>[
    DashboardScreen(), EventsScreen(), BillsScreen(), ReimbursementsScreen(),
    IncomeScreen(), ChartsScreen(byEvent: false), ChartsScreen(byEvent: true),
    ReportsScreen(), SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        void go(int i) {
          if (i == _i) return;
          setState(() {
            _history.add(_i);
            if (_history.length > 30) _history.removeAt(0);
            _i = i;
          });
        }

        void back() {
          if (_history.isEmpty) return;
          setState(() => _i = _history.removeLast());
        }

        void select(int i) {
          go(i);
          if (!wide) _key.currentState?.closeDrawer();
        }

        final menu = SideMenu(index: _i, onSelect: select);
        return ShellScope(
          wide: wide,
          canGoBack: _history.isNotEmpty,
          openMenu: () => _key.currentState?.openDrawer(),
          goTo: go,
          goBack: back,
          child: PopScope(
            // The phone's own Back button steps back through the pages first.
            canPop: _history.isEmpty,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (_key.currentState?.isDrawerOpen ?? false) {
                _key.currentState!.closeDrawer();
              } else {
                back();
              }
            },
            child: Scaffold(
            key: _key,
            drawer: wide ? null : Drawer(width: 300, child: menu),
            body: Row(children: [
              if (wide) SizedBox(width: 280, child: menu),
              if (wide) const VerticalDivider(width: 1),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: IndexedStack(index: _i, children: _pages),
                  ),
                ),
              ),
            ]),
          ),
          ),
        );
      });
}
