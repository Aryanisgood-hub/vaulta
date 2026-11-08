import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/friendly_error.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

/// Add a bill, or edit an existing active bill when [bill] is given.
class BillFormScreen extends ConsumerStatefulWidget {
  const BillFormScreen({super.key, this.bill});
  final Bill? bill;
  @override
  ConsumerState<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends ConsumerState<BillFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.bill == null ? '' : Money.toInput(widget.bill!.amount));
  late final _reason = TextEditingController(text: widget.bill?.reason);
  late final _paidTo = TextEditingController(text: widget.bill?.paidTo);
  late String? _eventId = widget.bill?.eventId;
  late String? _category = widget.bill?.category;
  late DateTime _date = widget.bill?.date ?? DateTime.now();
  late String? _doneBy = widget.bill?.doneBy;
  Uint8List? _bytes;
  String? _fileName, _contentType;
  bool _saving = false;

  bool get _editing => widget.bill != null;

  Future<void> _pick(String kind) async {
    final suspend = ref.read(lockSuspendProvider.notifier);
    suspend.state = true; // don't auto-lock while the camera/picker is open
    try {
      Uint8List raw;
      var name = 'receipt.jpg';
      var isPdf = false;
      if (kind == 'file') {
        final r = await FilePicker.platform.pickFiles(
            type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'], withData: true);
        final f = r?.files.single;
        if (f?.bytes == null) return;
        raw = f!.bytes!;
        name = f.name;
        isPdf = name.toLowerCase().endsWith('.pdf');
      } else {
        final x = await ImagePicker().pickImage(
            source: kind == 'camera' ? ImageSource.camera : ImageSource.gallery,
            imageQuality: 80, maxWidth: 2000);
        if (x == null) return;
        raw = await x.readAsBytes();
        name = x.name;
      }
      if (isPdf) {
        if (raw.length > maxReceiptBytes) {
          if (mounted) showSnack(context, 'That PDF is over 700 KB. Attach a photo of the bill instead.', error: true);
          return;
        }
        setState(() { _bytes = raw; _fileName = name; _contentType = 'application/pdf'; });
      } else {
        final small = await compressReceiptImage(raw);
        if (small == null) {
          if (mounted) showSnack(context, 'Could not read or shrink that image.', error: true);
          return;
        }
        final base = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
        setState(() { _bytes = small; _fileName = '$base.jpg'; _contentType = 'image/jpeg'; });
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not attach file: ${friendlyError(e)}', error: true);
    } finally {
      suspend.state = false;
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_eventId == null) { showSnack(context, 'Choose an event', error: true); return; }
    final events = ref.read(eventsProvider).valueOrNull ?? const <EventItem>[];
    final clubId = ref.read(clubIdProvider)!;
    final repo = ref.read(billRepoProvider);
    setState(() => _saving = true);
    try {
      var path = widget.bill?.receiptId, rname = widget.bill?.receiptName;
      if (_bytes != null) {
        path = await repo.uploadReceipt(clubId, _bytes!, _fileName!, _contentType!);
        rname = _fileName;
      }
      final bill = Bill(
        id: widget.bill?.id ?? '',
        eventId: _eventId!,
        eventName: events.firstWhere((e) => e.id == _eventId).name,
        amount: Money.toPaise(_amount.text),
        reason: _reason.text.trim(),
        paidTo: _paidTo.text.trim(),
        category: _category ?? 'Other',
        date: _date,
        receiptId: path,
        receiptName: rname,
        doneBy: _doneBy!.trim(),
      );
      if (_editing) {
        await repo.edit(clubId, widget.bill!, bill);
      } else {
        await repo.add(clubId, bill);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider).valueOrNull ?? const <EventItem>[];
    final club = ref.watch(clubProvider).valueOrNull;
    final cats = club?.categories ?? const <String>[];
    final members = club?.members ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit bill' : 'New bill')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          DropdownButtonFormField<String>(
            value: events.any((e) => e.id == _eventId) ? _eventId : null,
            decoration: const InputDecoration(labelText: 'Event'),
            items: [for (final e in events) DropdownMenuItem(value: e.id, child: Text(e.name))],
            onChanged: (v) => setState(() => _eventId = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
            validator: Money.validate,
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason / item'), validator: (v) => requiredField(v)),
          const SizedBox(height: 12),
          TextFormField(controller: _paidTo, decoration: const InputDecoration(labelText: 'Paid to (shop / person)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: cats.contains(_category) ? _category : null,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [for (final c in cats) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _category = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.event), label: Text('Bill date: ${fmtDate(_date)}'),
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: 12),
          NamePicker(members: members, value: _doneBy, onChanged: (v) => _doneBy = v),
          const SectionTitle('Receipt'),
          if (_bytes != null)
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.attach_file), title: Text(_fileName ?? 'Attached'),
                trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _bytes = null; _fileName = null; })))
          else if (widget.bill?.receiptName != null)
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.receipt_long), title: Text(widget.bill!.receiptName!), subtitle: const Text('Current receipt (pick a new one to replace)')),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: () => _pick('camera'), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera')),
            OutlinedButton.icon(onPressed: () => _pick('gallery'), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery')),
            OutlinedButton.icon(onPressed: () => _pick('file'), icon: const Icon(Icons.upload_file), label: const Text('Image / PDF')),
          ]),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_editing ? 'Save changes' : 'Add bill'),
          ),
        ]),
      ),
    );
  }
}
