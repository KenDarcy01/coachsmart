// v3 Car pool detail (the FlutterFlow CarPoolDetails page): seats left and
// taken, Reserve a seat (with a child picker when the user looks after
// more than one), Cancel my seat, and for the driver Delete car pool.
// Same data (get_full_car_pool_details), rows (car_pool_detail) and
// rows (car_pool_detail) as v2. Messages go through car_pool_notify, so they
// arrive as push or email by the same rules as every other notification.
import 'package:flutter/material.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../teams/v3_team_models.dart' show V3Avatar;
import '../v3_theme.dart';
import 'v3_car_pool_models.dart';
import '/v3/tracking/v3_track.dart';

class V3CarPoolPage extends StatefulWidget {
  const V3CarPoolPage(
      {super.key,
      required this.eventId,
      required this.carPoolId,
      this.testData});

  final int eventId, carPoolId;

  /// Widget tests pass the RPC result here instead of calling Supabase.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  @override
  State<V3CarPoolPage> createState() => _V3CarPoolPageState();
}

class _V3CarPoolPageState extends State<V3CarPoolPage> {
  CarPoolDetailStruct? _pool;
  bool _loading = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      dynamic r = widget.testData;
      r ??= await SupaFlow.client.rpc('get_full_car_pool_details', params: {
        'p_car_pool_id': widget.carPoolId,
        'p_user_id': currentUserUid,
      });
      final p = r is Map
          ? CarPoolDetailStruct.maybeFromMap(Map<String, dynamic>.from(r))
          : null;
      if (!mounted) return;
      setState(() {
        _pool = p;
        _loading = false;
        _error = p == null ? 'This car pool could not be loaded.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'This car pool could not be loaded.';
      });
    }
  }

  void _snack(String text, {bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
        backgroundColor: warn ? V3.amber : V3.green));
  }

  /// kind: 'reserved', 'cancelled' or 'pool_cancelled'.
  Future<void> _notify(int carPoolId, String kind, int memberId) async {
    if (widget.testData != null) return;
    try {
      V3Track.event('car_pool_action', {'kind': kind});
      await SupaFlow.client.rpc('car_pool_notify', params: {
        'p_car_pool_id': carPoolId,
        'p_kind': kind,
        'p_member_id': memberId,
      });
    } catch (_) {}
  }

  bool get _isDriver => _pool?.driverUserId == currentUserUid;
  List<ReservationsStruct> get _reserved => [
        for (final r in _pool?.reservations ?? const <ReservationsStruct>[])
          if (r.status == 'reserved') r
      ];
  bool get _hasSeat => _reserved.any((r) => r.memberBelongsToUser);

  // ---------------------------------------------------------------- actions

  Future<void> _reserve() async {
    final p = _pool!;
    final members = p.userAssociatedMembers;
    if (members.isEmpty) {
      _snack('No player of yours is on this team.', warn: true);
      return;
    }
    UserAssociatedMembersStruct? m = members.first;
    if (members.length > 1) {
      m = await showModalBottomSheet<UserAssociatedMembersStruct>(
        context: context,
        backgroundColor: V3.card,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _grab(),
            Text('Reserve a seat for whom?', style: V3.tight(20)),
            const SizedBox(height: 6),
            for (final x in members)
              ListTile(
                leading: V3Avatar(nameInitials(x.memberName), size: 36),
                title: Text(x.memberName,
                    style: V3.inter(16, weight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, x),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      );
      if (m == null || !mounted) return;
    }
    final member = m;
    setState(() => _busy = true);
    try {
      final existing = await CarPoolDetailTable().queryRows(
          queryFn: (q) => q
              .eq('car_pool_id', p.carPoolId)
              .eq('member_id', member.memberId)
              .eq('status', 'reserved'));
      if (existing.isNotEmpty) {
        _snack('${member.memberName} already has a seat in this car pool.',
            warn: true);
        return;
      }
      await CarPoolDetailTable().insert({
        'created_at': supaSerialize<DateTime>(getCurrentTimestamp),
        'car_pool_id': p.carPoolId,
        'member_id': member.memberId,
        'status': 'reserved',
      });
      await _load();
      _snack('Seat reserved for ${member.memberName}');
      await _notify(p.carPoolId, 'reserved', member.memberId);
    } catch (_) {
      _snack('Could not reserve the seat. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelSeat(ReservationsStruct r) async {
    final p = _pool!;
    final ok = await _confirm('Cancel this seat?',
        '${r.memberName} loses the seat with ${p.driverName}.', 'Cancel seat');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await CarPoolDetailTable()
          .delete(matchingRows: (q) => q.eq('id', r.reservationId));
      await _load();
      _snack('Seat cancelled');
      await _notify(p.carPoolId, 'cancelled', r.memberId);
    } catch (_) {
      _snack('Could not cancel the seat. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePool() async {
    final p = _pool!;
    final n = _reserved.length;
    final ok = await _confirm(
        'Delete your car pool?',
        n == 0
            ? 'Nobody has reserved a seat yet.'
            : '$n ${n == 1 ? 'person loses their seat and gets' : 'people lose their seats and get'} a notification.',
        'Delete');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      for (final r in p.reservations) {
        if (r.status == 'reserved') {
          await _notify(p.carPoolId, 'pool_cancelled', r.memberId);
        }
        await CarPoolDetailTable().update(
            data: {'status': 'cancelled'},
            matchingRows: (q) => q.eq('id', r.reservationId));
      }
      await CarPoolTable().update(
          data: {'status': 'cancelled'},
          matchingRows: (q) => q.eq('car_pool_id', p.carPoolId));
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (_) {
      _snack('Could not delete the car pool. Please try again.', warn: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V3.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: V3.tight(20)),
        content: Text(body, style: V3.inter(15, color: V3.muted, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep', style: V3.inter(15, color: V3.muted))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: V3.red, foregroundColor: Colors.white),
              child: Text(action,
                  style: V3.inter(15,
                      weight: FontWeight.w700, color: Colors.white))),
        ],
      ),
    );
    return r == true;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final p = _pool;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 32),
            onPressed: () => Navigator.of(context).maybePop()),
        title: Text(p == null ? 'Car pool' : "${p.driverName}'s car",
            maxLines: 1, overflow: TextOverflow.ellipsis, style: V3.tight(20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: V3.green))
          : _error != null || p == null
              ? Center(
                  child:
                      Text(_error ?? '', style: V3.inter(15, color: V3.muted)))
              : RefreshIndicator(
                  color: V3.green,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    children: [
                      if (p.eventTitle.isNotEmpty ||
                          p.eventDateFormatted.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                              [
                                if (p.eventTitle.isNotEmpty) p.eventTitle,
                                if (p.eventDateFormatted.isNotEmpty)
                                  p.eventDateFormatted
                              ].join(' · '),
                              style: V3.inter(13.5, color: V3.muted)),
                        ),
                      Row(children: [
                        _tile('Free', p.freeSeats,
                            p.freeSeats > 0 ? V3.green : V3.muted),
                        const SizedBox(width: 8),
                        _tile('Reserved', p.reservedSeats, V3.text),
                        const SizedBox(width: 8),
                        _tile('Seats', p.totalSeats, V3.text),
                      ]),
                      if ((_hasSeat || _isDriver) && p.driverPhone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: GestureDetector(
                            onTap: () => launchURL('tel:${p.driverPhone}'),
                            child: Container(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              decoration: BoxDecoration(
                                  color: V3.card,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Row(children: [
                                const Icon(Icons.phone_outlined,
                                    color: V3.green, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(
                                        _isDriver
                                            ? 'Your number: ${p.driverPhone}'
                                            : 'Call ${p.driverName}: ${p.driverPhone}',
                                        style: V3.inter(15))),
                              ]),
                            ),
                          ),
                        ),
                      if (!_isDriver && p.freeSeats > 0) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _reserve,
                            style: FilledButton.styleFrom(
                                backgroundColor: V3.green,
                                disabledBackgroundColor:
                                    V3.green.withValues(alpha: .45),
                                foregroundColor: V3.bg,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            icon: const Icon(
                                Icons.airline_seat_recline_normal_outlined,
                                size: 20),
                            label: Text('Reserve a seat',
                                style: V3.inter(16,
                                    weight: FontWeight.w700, color: V3.bg)),
                          ),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
                        child: Text(
                            poolStatusLine(p.freeSeats, p.reservedSeats)
                                .toUpperCase(),
                            style: V3.inter(13,
                                weight: FontWeight.w700,
                                color: V3.green,
                                letterSpacing: .8)),
                      ),
                      if (_reserved.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                              color: V3.card,
                              borderRadius: BorderRadius.circular(14)),
                          child: Column(children: [
                            for (var i = 0; i < _reserved.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                    height: 1, thickness: 1, color: V3.line),
                              _row(_reserved[i]),
                            ],
                          ]),
                        ),
                      if (_isDriver) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _deletePool,
                            style: OutlinedButton.styleFrom(
                                foregroundColor: V3.redText,
                                side:
                                    const BorderSide(color: V3.red, width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            label: Text('Delete car pool',
                                style: V3.inter(16,
                                    weight: FontWeight.w700,
                                    color: V3.redText)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _tile(String label, int n, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
              color: V3.card, borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: V3.inter(12, color: V3.muted)),
            const SizedBox(height: 2),
            Text('$n',
                style: V3.tight(24, weight: FontWeight.w700, color: color)),
          ]),
        ),
      );

  Widget _row(ReservationsStruct r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          V3Avatar(nameInitials(r.memberName),
              size: 36, highlight: r.memberBelongsToUser),
          const SizedBox(width: 12),
          Expanded(
              child: Text(r.memberName,
                  style: V3.inter(16, weight: FontWeight.w500))),
          if (r.memberBelongsToUser)
            TextButton(
                onPressed: _busy ? null : () => _cancelSeat(r),
                child: Text('Cancel seat',
                    style: V3.inter(14,
                        weight: FontWeight.w600, color: V3.redText))),
        ]),
      );

  Widget _grab() => Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.only(top: 14, bottom: 10),
      decoration: BoxDecoration(
          color: V3.barGrey, borderRadius: BorderRadius.circular(3)));
}
