import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/demo_config.dart';
import '../demo/demo_repositories.dart';
import '../demo/demo_store.dart';
import '../models/models.dart';
import '../repositories/bill_repository.dart';
import '../repositories/club_repository.dart';
import '../repositories/event_repository.dart';
import '../repositories/income_repository.dart';
import '../repositories/reimbursement_repository.dart';
import '../services/auth_service.dart';
import '../services/lock_service.dart';

// ------------------------------------------------------------- preferences
final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  // Only two modes: light and dark (dark by default).
  return ref.read(prefsProvider).getString('themeMode') == 'light' ? ThemeMode.light : ThemeMode.dark;
});

final lockEnabledProvider =
    StateProvider<bool>((ref) => ref.read(prefsProvider).getBool('appLock') ?? false);
final lockedProvider = StateProvider<bool>((_) => false);
/// True while the camera / file picker is open, so the app doesn't lock itself.
final lockSuspendProvider = StateProvider<bool>((_) => false);

// ---------------------------------------------------------------- services
final authServiceProvider = Provider((_) => AuthService(FirebaseAuth.instance));
final lockServiceProvider = Provider((_) => LockService());

// ------------------------------------------------------------ repositories
// ------------------------------------------------------------- demo mode
/// True while someone is exploring the app with sample data (nothing touches Firebase).
final demoModeProvider = StateProvider<bool>((_) => demoOnly);

void enterDemo(WidgetRef ref) => ref.read(demoModeProvider.notifier).state = true;
void exitDemo(WidgetRef ref) => ref.read(demoModeProvider.notifier).state = false;

/// Fresh sample data every time demo mode is switched on or off.
final demoStoreProvider = Provider<DemoStore>((ref) {
  ref.watch(demoModeProvider);
  return DemoStore();
});

final clubRepoProvider = Provider<ClubRepository>((ref) => ref.watch(demoModeProvider)
    ? DemoClubRepository(ref.watch(demoStoreProvider))
    : ClubRepository(FirebaseFirestore.instance));
final eventRepoProvider = Provider<EventRepository>((ref) => ref.watch(demoModeProvider)
    ? DemoEventRepository(ref.watch(demoStoreProvider))
    : EventRepository(FirebaseFirestore.instance));
final billRepoProvider = Provider<BillRepository>((ref) => ref.watch(demoModeProvider)
    ? DemoBillRepository(ref.watch(demoStoreProvider))
    : BillRepository(FirebaseFirestore.instance));
final incomeRepoProvider = Provider<IncomeRepository>((ref) => ref.watch(demoModeProvider)
    ? DemoIncomeRepository(ref.watch(demoStoreProvider))
    : IncomeRepository(FirebaseFirestore.instance));
final reimbursementRepoProvider = Provider<ReimbursementRepository>((ref) => ref.watch(demoModeProvider)
    ? DemoReimbursementRepository(ref.watch(demoStoreProvider))
    : ReimbursementRepository(FirebaseFirestore.instance));

// -------------------------------------------------------------------- auth
final authStateProvider =
    StreamProvider<User?>((_) => FirebaseAuth.instance.userChanges());

/// Non-null only for a signed-in user whose email is verified.
final clubIdProvider = Provider<String?>((ref) {
  if (ref.watch(demoModeProvider)) return 'demo';
  final u = ref.watch(authStateProvider).valueOrNull;
  return (u != null && u.emailVerified) ? u.uid : null;
});

// -------------------------------------------------------------------- data
final clubProvider = StreamProvider<Club?>((ref) {
  final id = ref.watch(clubIdProvider);
  if (id == null) return Stream.value(null);
  return ref.watch(clubRepoProvider).watch(id);
});

final eventsProvider = StreamProvider<List<EventItem>>((ref) {
  final id = ref.watch(clubIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(eventRepoProvider).watch(id);
});

final _rawBillsProvider = StreamProvider<List<Bill>>((ref) {
  final id = ref.watch(clubIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(billRepoProvider).watch(id);
});

/// event id -> current event name
final _eventNamesProvider = Provider<Map<String, String>>((ref) {
  final events = ref.watch(eventsProvider).valueOrNull ?? const <EventItem>[];
  return {for (final e in events) e.id: e.name};
});

/// Bills with the event's *current* name, so renaming an event updates every bill (even voided ones).
final billsProvider = Provider<AsyncValue<List<Bill>>>((ref) {
  final names = ref.watch(_eventNamesProvider);
  return ref.watch(_rawBillsProvider).whenData((list) => [
        for (final b in list)
          (names[b.eventId] != null && names[b.eventId] != b.eventName) ? b.withEventName(names[b.eventId]!) : b,
      ]);
});

final incomeProvider = StreamProvider<List<Income>>((ref) {
  final id = ref.watch(clubIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(incomeRepoProvider).watch(id);
});

final _rawReimbursementsProvider = StreamProvider<List<ReimbursementEntry>>((ref) {
  final id = ref.watch(clubIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(reimbursementRepoProvider).watch(id);
});

final reimbursementsProvider = Provider<AsyncValue<List<ReimbursementEntry>>>((ref) {
  final names = ref.watch(_eventNamesProvider);
  return ref.watch(_rawReimbursementsProvider).whenData((list) => [
        for (final r in list)
          (names[r.eventId] != null && names[r.eventId] != r.eventName) ? r.withEventName(names[r.eventId]!) : r,
      ]);
});

final budgetLogProvider = StreamProvider<List<BudgetLog>>((ref) {
  final id = ref.watch(clubIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(clubRepoProvider).watchBudgetLog(id);
});

final summaryProvider = Provider<Summary>((ref) {
  final club = ref.watch(clubProvider).valueOrNull;
  final bills = ref.watch(billsProvider).valueOrNull ?? const [];
  final income = ref.watch(incomeProvider).valueOrNull ?? const [];
  final events = ref.watch(eventsProvider).valueOrNull ?? const [];
  final entries = ref.watch(reimbursementsProvider).valueOrNull ?? const [];
  return Summary.from(club?.totalBudget ?? 0, bills, income, events, entries);
});

// ----------------------------------------------------------- bill filters
final billQueryProvider = StateProvider<String>((_) => '');
final billStatusProvider = StateProvider<String>((_) => 'active'); // active | void | all
final billEventProvider = StateProvider<String?>((_) => null);
final billCategoryProvider = StateProvider<String?>((_) => null);

final filteredBillsProvider = Provider<List<Bill>>((ref) {
  final bills = ref.watch(billsProvider).valueOrNull ?? const [];
  final q = ref.watch(billQueryProvider).trim().toLowerCase();
  final status = ref.watch(billStatusProvider);
  final event = ref.watch(billEventProvider);
  final cat = ref.watch(billCategoryProvider);
  return bills.where((b) {
    if (status == 'active' && b.isVoid) return false;
    if (status == 'void' && !b.isVoid) return false;
    if (event != null && b.eventId != event) return false;
    if (cat != null && b.category != cat) return false;
    if (q.isEmpty) return true;
    return [b.reason, b.paidTo, b.doneBy, b.eventName, b.category, (b.amount / 100).toString()]
        .any((f) => f.toLowerCase().contains(q));
  }).toList();
});
