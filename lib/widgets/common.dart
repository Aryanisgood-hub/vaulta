import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../core/utils/money.dart';
import '../models/models.dart';
import 'shell_scope.dart';
import 'vaulta_logo.dart';

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
}

/// App bar for the pages inside the side-menu shell (adds the menu button on phones).
PreferredSizeWidget pageBar(BuildContext context, String title, {List<Widget>? actions}) {
  final scope = ShellScope.maybeOf(context);
  final showMenu = scope != null && !scope.wide;
  return AppBar(
    automaticallyImplyLeading: false,
    leading: showMenu ? IconButton(icon: const Icon(Icons.menu_rounded), tooltip: 'Menu', onPressed: scope.openMenu) : null,
    title: Text(title),
    actions: [
      ...?actions,
      // Vaulta logo (top right): tap to jump to Home from any page.
      if (scope != null)
        Padding(
          padding: const EdgeInsets.only(right: 14, left: 4),
          child: Tooltip(
            message: 'Home',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => scope.goTo(Pages.home),
              child: const VaultaLogo(size: 36),
            ),
          ),
        ),
    ],
  );
}

/// Rounded surface used everywhere instead of Card.
class Panel extends StatelessWidget {
  const Panel({super.key, this.child, this.color, this.padding, this.onTap, this.radius = 20, this.borderless = false});
  final Widget? child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double radius;
  final bool borderless;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget content = child ?? const SizedBox.shrink();
    if (padding != null) content = Padding(padding: padding!, child: content);
    return Material(
      color: color ?? cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: borderless ? BorderSide.none : BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center)),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.hint});
  final IconData icon;
  final String title;
  final String? hint;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            ],
          ]),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

/// Small rounded label, e.g. "- ₹250".
class AmountPill extends StatelessWidget {
  const AmountPill(this.text, {super.key, this.strike = false});
  final String text;
  final bool strike;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withAlpha(120)),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, decoration: strike ? TextDecoration.lineThrough : null)),
    );
  }
}

/// One transaction row: avatar, title + date, amount pill.
class BillTile extends StatelessWidget {
  const BillTile({super.key, required this.bill, this.onTap});
  final Bill bill;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Panel(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: bill.isVoid ? cs.surfaceContainerHighest : cs.primaryContainer,
            child: Icon(bill.receiptId != null ? Icons.receipt_long : Icons.receipt_outlined,
                color: bill.isVoid ? cs.outline : cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bill.reason, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, decoration: bill.isVoid ? TextDecoration.lineThrough : null)),
              const SizedBox(height: 2),
              Text('${bill.isVoid ? 'VOID • ' : ''}${fmtDate(bill.date)} • ${bill.eventName}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 8),
          AmountPill('- ${Money.format(bill.amount)}', strike: bill.isVoid),
        ]),
      ),
    );
  }
}

/// Dropdown of the club's saved names, or a text field when none are saved yet.
class NamePicker extends StatelessWidget {
  const NamePicker({super.key, required this.members, required this.value, required this.onChanged, this.label = 'Done by'});
  final List<String> members;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label, helperText: 'Tip: save your team\'s names in Settings'),
        validator: (v) => requiredField(v),
        onChanged: onChanged,
      );
    }
    return DropdownButtonFormField<String>(
      value: members.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [for (final m in members) DropdownMenuItem(value: m, child: Text(m))],
      validator: (v) => v == null ? 'Required' : null,
      onChanged: onChanged,
    );
  }
}

/// Asks "who is doing this?" (and optionally why). Returns null if cancelled.
Future<({String by, String reason})?> showActionDialog(
  BuildContext context, {
  required String title,
  required List<String> members,
  String confirmLabel = 'Confirm',
  bool askReason = false,
  String? reasonLabel,
  String? message,
}) {
  final form = GlobalKey<FormState>();
  String? by;
  final reason = TextEditingController();
  return showDialog<({String by, String reason})>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (message != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(message)),
            if (askReason) ...[
              TextFormField(
                controller: reason,
                decoration: InputDecoration(labelText: reasonLabel ?? 'Reason'),
                validator: (v) => requiredField(v),
              ),
              const SizedBox(height: 12),
            ],
            NamePicker(members: members, value: by, onChanged: (v) => by = v),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(ctx, (by: (by ?? '').trim(), reason: reason.text.trim()));
            }
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
