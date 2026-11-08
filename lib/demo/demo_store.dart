import 'dart:async';
import 'dart:typed_data';

import '../core/constants/app_info.dart';
import '../core/constants/demo_config.dart';
import '../core/utils/money.dart';
import '../models/models.dart';

/// A value that can be watched as a stream (emits the current value first).
class Live<T> {
  Live(this._value);
  T _value;
  final _ping = StreamController<void>.broadcast();

  T get value => _value;
  set value(T v) {
    _value = v;
    _ping.add(null);
  }

  Stream<T> watch() async* {
    yield _value;
    await for (final _ in _ping.stream) {
      yield _value;
    }
  }
}

/// All demo data lives here, in memory. Everything is made up.
/// Dates are relative to "today", so the charts always look current.
class DemoStore {
  DemoStore() {
    _seed();
  }

  final club = Live<Club>(const Club(id: 'demo', name: demoClubName, email: 'demo@vaulta.app', totalBudget: 0, categories: defaultCategories, members: []));
  final events = Live<List<EventItem>>(const []);
  final bills = Live<List<Bill>>(const []);
  final income = Live<List<Income>>(const []);
  final reimbursements = Live<List<ReimbursementEntry>>(const []);
  final budgetLog = Live<List<BudgetLog>>(const []);
  final history = Live<Map<String, List<HistoryEntry>>>(const {});
  final receipts = <String, Uint8List>{};

  int _next = 1000;
  String nextId(String prefix) => '$prefix${_next++}';

  // ---- setters that keep lists sorted (newest first) ----
  void setEvents(List<EventItem> l) => events.value = ([...l]..sort((a, b) => b.date.compareTo(a.date)));
  void setBills(List<Bill> l) => bills.value = ([...l]..sort((a, b) => b.date.compareTo(a.date)));
  void setIncome(List<Income> l) => income.value = ([...l]..sort((a, b) => b.date.compareTo(a.date)));
  void setReimbursements(List<ReimbursementEntry> l) => reimbursements.value = ([...l]..sort((a, b) => b.date.compareTo(a.date)));

  void addHistory(String billId, HistoryEntry e) {
    final m = {...history.value};
    m[billId] = [e, ...(m[billId] ?? const <HistoryEntry>[])];
    history.value = m;
  }

  // ======================================================================
  //  Seed data
  // ======================================================================
  void _seed() {
    final now = DateTime.now();
    DateTime day(int daysAgo) => DateTime(now.year, now.month, now.day - daysAgo);
    int rs(num rupees) => (rupees * 100).round();

    club.value = Club(
      id: 'demo',
      name: demoClubName,
      email: 'demo@vaulta.app',
      totalBudget: rs(40000),
      categories: defaultCategories,
      members: const ['Aarav', 'Diya', 'Rohan', 'Meera'],
    );

    // ---------------- events ----------------
    final ev = <EventItem>[
      EventItem(id: 'ev0', name: 'Recruitment Drive', date: day(205), description: 'Stalls and posters across campus'),
      EventItem(id: 'ev1', name: 'Freshers Orientation', date: day(142), description: 'Welcome session for first years', reimbursementAvailable: true, reimbursementAmount: rs(15000)),
      EventItem(id: 'ev2', name: 'Flutter Workshop', date: day(118), description: 'Hands-on app development session', reimbursementAvailable: true, reimbursementAmount: rs(8000)),
      EventItem(id: 'ev3', name: 'TechFest 2026', date: day(92), description: 'Annual two-day technical festival', reimbursementAvailable: true, reimbursementAmount: rs(40000)),
      EventItem(id: 'ev4', name: 'CTF Night', date: day(60), description: 'Capture-the-flag security contest', reimbursementAvailable: true, reimbursementAmount: rs(10000)),
      EventItem(id: 'ev5', name: 'Hackathon 24h', date: day(30), description: '24-hour build challenge', reimbursementAvailable: true, reimbursementAmount: rs(30000)),
      EventItem(id: 'ev6', name: 'Alumni Meetup', date: day(11), description: 'Evening with club alumni'),
      EventItem(id: 'ev7', name: 'Design Sprint', date: day(4), description: 'Two-day UI/UX sprint'),
      EventItem(id: 'ev8', name: 'Annual Day', date: day(-15), description: 'Upcoming: club annual celebration', reimbursementAvailable: true, reimbursementAmount: rs(20000)),
    ];
    setEvents(ev);

    // ---------------- bills ----------------
    var n = 0;
    Bill bill(String eventId, String reason, String category, String paidTo, num rupees, int offset, String by,
        {bool receipt = false, String? voidReason}) {
      final e = ev.firstWhere((e) => e.id == eventId);
      final date = DateTime(e.date.year, e.date.month, e.date.day + offset);
      n++;
      return Bill(
        id: 'db$n', eventId: eventId, eventName: e.name, amount: rs(rupees), reason: reason,
        paidTo: paidTo, category: category, date: date,
        receiptId: receipt ? 'demo-receipt' : null, receiptName: receipt ? 'bill_$n.jpg' : null,
        doneBy: by, status: voidReason == null ? 'active' : 'void', voidReason: voidReason,
        createdAt: date, voidedAt: voidReason == null ? null : DateTime(date.year, date.month, date.day + 1),
      );
    }

    final list = <Bill>[
      // Recruitment Drive: 6,200
      bill('ev0', 'Posters and flyers printing', 'Printing', 'QuickPrint Hub', 2400, -2, 'Diya', receipt: true),
      bill('ev0', 'Banner (6 x 3 ft)', 'Marketing', 'SignCraft', 1800, -1, 'Aarav'),
      bill('ev0', 'Snacks for volunteers', 'Food', 'Campus Canteen', 2000, 0, 'Rohan'),
      // Freshers Orientation: 11,400
      bill('ev1', 'Welcome kits (pens, stickers)', 'Equipment', 'Stationery Mart', 4200, -3, 'Meera', receipt: true),
      bill('ev1', 'Refreshments for 120 attendees', 'Food', 'Campus Canteen', 5400, 0, 'Aarav', receipt: true),
      bill('ev1', 'Stage decoration', 'Marketing', 'Event Decor Co.', 1800, -1, 'Diya'),
      // Flutter Workshop: 9,200
      bill('ev2', 'Speaker honorarium', 'Other', 'Guest speaker', 5000, 0, 'Rohan', receipt: true),
      bill('ev2', 'Lunch and tea', 'Food', 'Campus Canteen', 3200, 0, 'Meera'),
      bill('ev2', 'Participation certificates', 'Printing', 'QuickPrint Hub', 1000, 1, 'Diya'),
      // TechFest 2026: 52,300 (+ one voided duplicate)
      bill('ev3', 'Stage and sound system rental', 'Equipment', 'SoundWave Rentals', 14500, -1, 'Aarav', receipt: true),
      bill('ev3', 'Prizes (trophies and vouchers)', 'Prizes', 'TrophyWorld', 12000, 0, 'Diya', receipt: true),
      bill('ev3', 'Food stall coupons', 'Food', 'Campus Canteen', 9800, 0, 'Rohan'),
      bill('ev3', 'Banners, standees and posters', 'Printing', 'SignCraft', 6400, -4, 'Meera', receipt: true),
      bill('ev3', 'Travel for guest judges', 'Travel', 'CabGo', 4200, 0, 'Aarav'),
      bill('ev3', 'Volunteer T-shirts', 'Marketing', 'PrintMyTee', 5400, -5, 'Diya', receipt: true),
      bill('ev3', 'Banners, standees and posters (duplicate)', 'Printing', 'SignCraft', 6400, -4, 'Meera', voidReason: 'Entered twice by mistake'),
      // CTF Night: 6,900
      bill('ev4', 'Cloud servers for challenges', 'Equipment', 'CloudHost', 3900, -2, 'Rohan', receipt: true),
      bill('ev4', 'Prizes and goodies', 'Prizes', 'TrophyWorld', 2000, 0, 'Meera'),
      bill('ev4', 'Pizza night', 'Food', 'Pizza Point', 1000, 0, 'Aarav'),
      // Hackathon 24h: 38,750
      bill('ev5', 'Venue and power backup', 'Equipment', 'Auditorium Services', 11000, -1, 'Aarav', receipt: true),
      bill('ev5', 'Meals (24 hours)', 'Food', 'Campus Canteen', 14500, 0, 'Rohan', receipt: true),
      bill('ev5', 'Prizes (1st, 2nd, 3rd)', 'Prizes', 'TrophyWorld', 9000, 1, 'Diya', receipt: true),
      bill('ev5', 'Swag and stationery', 'Marketing', 'Stationery Mart', 4250, -3, 'Meera'),
      // Alumni Meetup: 7,850
      bill('ev6', 'Hall booking', 'Other', 'College Auditorium', 3500, -2, 'Aarav', receipt: true),
      bill('ev6', 'High tea', 'Food', 'Campus Canteen', 3200, 0, 'Diya'),
      bill('ev6', 'Memento for chief guest', 'Prizes', 'TrophyWorld', 1150, 0, 'Rohan'),
      // Design Sprint: 2,400
      bill('ev7', 'Whiteboards and markers', 'Equipment', 'Stationery Mart', 1400, -1, 'Meera'),
      bill('ev7', 'Snacks', 'Food', 'Campus Canteen', 1000, 0, 'Aarav'),
    ];
    setBills(list);

    // ---------------- bill history ----------------
    final hist = <String, List<HistoryEntry>>{};
    for (final b in list) {
      final entries = <HistoryEntry>[
        HistoryEntry(action: 'create', by: b.doneBy, summary: 'Created bill of ${Money.format(b.amount)} for "${b.reason}"', at: b.date.add(const Duration(hours: 11))),
      ];
      if (b.reason == 'Stage and sound system rental') {
        entries.insert(0, HistoryEntry(action: 'edit', by: 'Aarav', summary: 'Changed amount ${Money.format(rs(14000))} to ${Money.format(b.amount)}', at: b.date.add(const Duration(hours: 30))));
      }
      if (b.isVoid) {
        entries.insert(0, HistoryEntry(action: 'void', by: 'Meera', summary: 'Voided: ${b.voidReason}', at: b.date.add(const Duration(hours: 28))));
      }
      hist[b.id] = entries;
    }
    history.value = hist;

    // ---------------- income ----------------
    setIncome([
      Income(id: 'di1', amount: rs(12000), source: 'BrightPath Solutions', type: 'Sponsorship', date: day(90), note: 'TechFest sponsor', doneBy: 'Aarav'),
      Income(id: 'di2', amount: rs(9500), source: 'TechFest registrations', type: 'Registration fees', date: day(92), note: '95 participants', doneBy: 'Diya'),
      Income(id: 'di3', amount: rs(6000), source: 'Annual membership fees', type: 'Membership fees', date: day(150), note: '60 members', doneBy: 'Rohan'),
      Income(id: 'di4', amount: rs(3000), source: 'Alumni donation', type: 'Other', date: day(10), note: 'After the meetup', doneBy: 'Meera'),
      Income(id: 'di5', amount: rs(5000), source: 'Sponsor cheque', type: 'Sponsorship', date: day(75), doneBy: 'Aarav', status: 'void', voidReason: 'Cheque bounced (by Aarav)'),
    ]);

    // ---------------- reimbursement money received ----------------
    ReimbursementEntry got(String eventId, num rupees, int daysAfterEvent, String note, String by, {String? voidReason}) {
      final e = ev.firstWhere((e) => e.id == eventId);
      n++;
      return ReimbursementEntry(
        id: 'dr$n', eventId: eventId, eventName: e.name, amount: rs(rupees),
        date: DateTime(e.date.year, e.date.month, e.date.day + daysAfterEvent), note: note, doneBy: by,
        status: voidReason == null ? 'active' : 'void', voidReason: voidReason,
      );
    }

    setReimbursements([
      got('ev1', 10000, 20, 'Cheque 004512', 'Aarav'),
      got('ev1', 5000, 35, 'Balance paid by college office', 'Aarav'),
      got('ev2', 8000, 15, 'Department grant', 'Diya'),
      got('ev3', 15000, 25, 'First instalment', 'Rohan'),
      got('ev3', 10000, 50, 'Second instalment', 'Rohan'),
      got('ev3', 5000, 52, 'Posted by mistake', 'Diya', voidReason: 'Entered wrongly (by Diya)'),
      got('ev4', 10000, 12, 'Department fund', 'Meera'),
      got('ev5', 12000, 10, 'First instalment', 'Aarav'),
    ]);

    // ---------------- budget history ----------------
    budgetLog.value = [
      BudgetLog(oldBudget: rs(30000), newBudget: rs(40000), by: 'Aarav', reason: 'Increased after the TechFest sponsorship', at: day(60)),
      BudgetLog(oldBudget: 0, newBudget: rs(30000), by: 'Aarav', reason: 'Initial budget for the year', at: day(200)),
    ];
  }
}
