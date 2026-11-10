// Rows of get_event_payment_details_v2 (confirmed payments) and
// get_accepted_unpaid_members (attending players with no payment) for
// the v3 event Payments page. Amounts are in cents.
import 'package:intl/intl.dart';

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';

String euro(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

/// payment_date comes back as "04 Nov 2026"; show it as "Wed 4 Nov".
String paidDateLabel(String s) {
  if (s.isEmpty) return '';
  try {
    return DateFormat('EEE d MMM')
        .format(DateFormat('dd MMM yyyy', 'en_US').parse(s));
  } catch (_) {
    return s;
  }
}

class PaidRow {
  PaidRow.fromJson(Map j)
      : paymentId = _i(j['payment_id']),
        memberId = _i(j['member_id']),
        memberName = _s(j['member_full_name']).trim(),
        paidBy = _s(j['user_full_name']).trim(),
        date = _s(j['payment_date']),
        amount = _i(j['amount_paid']),
        net = _i(j['net_amount']),
        fee = _i(j['fee_amount']);

  final int paymentId, memberId, amount, net, fee;
  final String memberName, paidBy, date;

  /// "Paid by Jane Morris · Wed 4 Nov"
  String get subtitle {
    final d = paidDateLabel(date);
    if (paidBy.isEmpty) return d.isEmpty ? 'Paid' : 'Paid $d';
    return d.isEmpty ? 'Paid by $paidBy' : 'Paid by $paidBy · $d';
  }
}

class UnpaidRow {
  UnpaidRow.fromJson(Map j)
      : memberId = _i(j['member_id']),
        memberName = _s(j['member_full_name']).trim(),
        role = _s(j['role_name']);

  final int memberId;
  final String memberName, role;
}

class PaymentsData {
  PaymentsData(
      {required this.paid,
      required this.unpaid,
      required this.price,
      this.title = ''});

  PaymentsData.fromJson(
      {required List paidRows,
      required List unpaidRows,
      required this.price,
      this.title = ''})
      : paid = [
          for (final r in paidRows)
            if (r is Map) PaidRow.fromJson(r)
        ]..sort((a, b) => a.memberName.compareTo(b.memberName)),
        unpaid = [
          for (final r in unpaidRows)
            if (r is Map) UnpaidRow.fromJson(r)
        ];

  final List<PaidRow> paid;
  final List<UnpaidRow> unpaid;

  /// events.payment_amount in cents.
  final int price;
  final String title;

  int get collected => paid.fold(0, (s, r) => s + r.amount);
  int get toClub => paid.fold(0, (s, r) => s + r.net);
  int get stillToPay => unpaid.length * price;

  /// "Remind the 5 who haven't paid" / "Remind the 1 who hasn't paid".
  String get remindLabel => unpaid.length == 1
      ? "Remind the 1 who hasn't paid"
      : "Remind the ${unpaid.length} who haven't paid";
}

/// Initials for a full name ("Aimee Morris" → "AM").
String nameInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final s = parts.map((p) => p[0]).take(2).join().toUpperCase();
  return s.isEmpty ? '?' : s;
}
