// Spend & gear (2026-11-23, thread "Explore coach expenses and gear orders"):
// data for the team page. Built from the `spend` edge function's `team` reply.
import 'package:flutter/material.dart';

import '../v3_theme.dart';

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

/// €18.40, or €40 when there are no cents and [short] is set.
String spendEuro(double v, {bool short = false}) {
  if (short && v == v.roundToDouble()) {
    return '€${_thousands(v.round().toString())}';
  }
  final s = v.toStringAsFixed(2);
  final dot = s.indexOf('.');
  return '€${_thousands(s.substring(0, dot))}${s.substring(dot)}';
}

String _thousands(String n) {
  final b = StringBuffer();
  for (var i = 0; i < n.length; i++) {
    if (i > 0 && (n.length - i) % 3 == 0) b.write(',');
    b.write(n[i]);
  }
  return b.toString();
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// "Sat 21 Nov".
String spendDay(DateTime d) =>
    '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

String spendYmd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A status pill: label, text colour, background.
class SpendStatus {
  const SpendStatus(this.label, this.color, this.tint);
  final String label;
  final Color color;
  final Color tint;

  static const _blue = Color(0xFF9FC3FF);
  static const _blueTint = Color(0xFF2C3340);

  static SpendStatus of(String s, {bool gear = false, String payback = ''}) {
    switch (s) {
      case 'submitted':
      case 'requested':
        return const SpendStatus(
            'Waiting for the club', V3.amberText, V3.amberTint);
      case 'approved':
        return SpendStatus(
            gear
                ? 'Approved, being ordered'
                : payback == 'none'
                    ? 'Approved'
                    : 'Approved, to be paid back',
            V3.green,
            V3.greenTint);
      case 'queried':
        return const SpendStatus('Club has a question', V3.redText, V3.redTint);
      case 'rejected':
        return const SpendStatus('Not approved', V3.muted, V3.card2);
      case 'paid':
        return const SpendStatus('Paid back', _blue, _blueTint);
      case 'ordered':
        return const SpendStatus('Ordered', _blue, _blueTint);
      case 'delivered':
        return const SpendStatus('Delivered', _blue, _blueTint);
    }
    return SpendStatus(s, V3.muted, V3.card2);
  }
}

class SpendExpense {
  SpendExpense.fromJson(Map m)
      : id = (m['expense_id'] as num).toInt(),
        eventId = (m['event_id'] as num?)?.toInt(),
        spentOn = DateTime.tryParse('${m['spent_on']}') ?? DateTime.now(),
        amount = _d(m['amount']),
        shop = (m['shop'] as String?) ?? '',
        category = (m['category'] as String?) ?? 'Other',
        note = (m['note'] as String?) ?? '',
        payback = (m['payback'] as String?) ?? 'bank',
        status = (m['status'] as String?) ?? 'submitted',
        statusNote = (m['status_note'] as String?) ?? '',
        by = (m['by'] as String?) ?? '',
        mine = m['mine'] == true,
        hasReceipt = m['has_receipt'] == true,
        createdAt = DateTime.tryParse('${m['created_at']}') ?? DateTime.now();
  final int id;
  final int? eventId;
  final DateTime spentOn;
  final double amount;
  final String shop, category, note, payback, status, statusNote, by;
  final bool mine, hasReceipt;
  final DateTime createdAt;

  bool get waiting => status == 'submitted' || status == 'queried';
  SpendStatus get pill => SpendStatus.of(status, payback: payback);
}

class SpendGearLine {
  SpendGearLine.fromJson(Map m)
      : name = '${m['name'] ?? ''}',
        qty = (m['qty'] as num?)?.toInt() ?? 1,
        unitPrice = m['unit_price'] == null ? null : _d(m['unit_price']);
  final String name;
  final int qty;
  final double? unitPrice;
}

class SpendGear {
  SpendGear.fromJson(Map m)
      : id = (m['gear_request_id'] as num).toInt(),
        note = (m['note'] as String?) ?? '',
        status = (m['status'] as String?) ?? 'requested',
        statusNote = (m['status_note'] as String?) ?? '',
        by = (m['by'] as String?) ?? '',
        mine = m['mine'] == true,
        total = _d(m['total']),
        createdAt = DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
        lines = [
          for (final l in (m['lines'] as List? ?? const []).whereType<Map>())
            SpendGearLine.fromJson(l)
        ];
  final int id;
  final String note, status, statusNote, by;
  final bool mine;
  final double total;
  final DateTime createdAt;
  final List<SpendGearLine> lines;

  bool get waiting => status == 'requested' || status == 'queried';
  SpendStatus get pill => SpendStatus.of(status, gear: true);

  /// "6 × Footballs, size 4, 2 × Bibs (set of 10)".
  String get summary =>
      lines.map((l) => l.qty == 1 ? l.name : '${l.qty} × ${l.name}').join(', ');
}

class GearItem {
  GearItem.fromJson(Map m)
      : id = (m['gear_item_id'] as num).toInt(),
        name = '${m['name'] ?? ''}',
        category = (m['category'] as String?) ?? 'Other',
        unitPrice = m['unit_price'] == null ? null : _d(m['unit_price']),
        detail = (m['detail'] as String?) ?? '';
  final int id;
  final String name, category, detail;
  final double? unitPrice;
}

class SpendEvent {
  SpendEvent.fromJson(Map m)
      : id = (m['event_id'] as num).toInt(),
        title = (m['event_title'] as String?) ?? '',
        opposition = (m['opposition'] as String?) ?? '',
        when = DateTime.tryParse('${m['event_date_time']}')?.toLocal();
  final int id;
  final String title, opposition;
  final DateTime? when;

  String get label {
    final what = opposition.isNotEmpty
        ? 'Match v $opposition'
        : (title.isNotEmpty ? title : 'Event');
    return when == null ? what : '$what (${spendDay(when!)})';
  }
}

/// One row in the team's Recent list: an expense or a gear request.
class SpendItem {
  SpendItem.expense(SpendExpense this.expense)
      : gear = null,
        at = expense.createdAt;
  SpendItem.gear(SpendGear this.gear)
      : expense = null,
        at = gear.createdAt;
  final SpendExpense? expense;
  final SpendGear? gear;
  final DateTime at;
}

class SpendData {
  SpendData.fromJson(Map m)
      : teamId = ((m['team'] as Map?)?['team_id'] as num?)?.toInt() ?? 0,
        teamName = '${(m['team'] as Map?)?['team_name'] ?? ''}',
        clubName = '${(m['club'] as Map?)?['club_name'] ?? ''}',
        season = (m['season'] as num?)?.toInt() ?? DateTime.now().year,
        budget = m['budget'] == null ? null : _d(m['budget']),
        used = _d(m['used']),
        waiting = _d(m['waiting']),
        categories = [
          for (final c in (m['categories'] as List? ?? const [])) '$c'
        ],
        expenses = [
          for (final e in (m['expenses'] as List? ?? const []).whereType<Map>())
            SpendExpense.fromJson(e)
        ],
        gear = [
          for (final g in (m['gear'] as List? ?? const []).whereType<Map>())
            SpendGear.fromJson(g)
        ],
        items = [
          for (final i in (m['items'] as List? ?? const []).whereType<Map>())
            GearItem.fromJson(i)
        ],
        events = [
          for (final e in (m['events'] as List? ?? const []).whereType<Map>())
            SpendEvent.fromJson(e)
        ];
  final int teamId;
  final String teamName, clubName;
  final int season;
  final double? budget;
  final double used, waiting;
  final List<String> categories;
  final List<SpendExpense> expenses;
  final List<SpendGear> gear;
  final List<GearItem> items;
  final List<SpendEvent> events;

  double? get left => budget == null ? null : budget! - used;

  /// 0..1 for the budget bar.
  double get usedShare =>
      budget == null || budget! <= 0 ? 0 : (used / budget!).clamp(0, 1);

  List<SpendItem> get recent {
    final all = [
      for (final e in expenses) SpendItem.expense(e),
      for (final g in gear) SpendItem.gear(g),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return all;
  }

  /// The event an expense on [day] most likely belongs to (same day).
  SpendEvent? eventOn(DateTime day) {
    for (final e in events) {
      final w = e.when;
      if (w != null &&
          w.year == day.year &&
          w.month == day.month &&
          w.day == day.day) {
        return e;
      }
    }
    return null;
  }
}
