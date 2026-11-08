import 'package:flutter/widgets.dart';

/// Page indexes of the side menu / IndexedStack.
class Pages {
  static const home = 0, events = 1, bills = 2, reimbursements = 3, income = 4,
      chartsMonthly = 5, chartsEvent = 6, reports = 7, settings = 8;
}

/// Lets pages open the side menu, jump to another page and go back.
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.wide,
    required this.canGoBack,
    required this.openMenu,
    required this.goTo,
    required this.goBack,
    required super.child,
  });
  final bool wide, canGoBack;
  final VoidCallback openMenu, goBack;
  final ValueChanged<int> goTo;

  static ShellScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope old) => wide != old.wide || canGoBack != old.canGoBack;
}
