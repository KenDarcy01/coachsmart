// v3 Car pooling for an event (the FlutterFlow CreateCarPool page): the
// car pools on offer, and for coaches (role 30+) an "Offer a car pool"
// sheet. Data: get_event_car_pools; a new pool is a car_pool row, as v2.
import 'package:flutter/material.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../teams/v3_team_models.dart' show V3Avatar;
import '../v3_theme.dart';
import 'v3_car_pool_models.dart';

class V3CarPoolsPage extends StatefulWidget {
  const V3CarPoolsPage(
      {super.key, required this.eventId, this.roleLevel = 0, this.testData});

  final int eventId;
  final int roleLevel;

  /// Widget tests pass the RPC result here instead of calling Supabase.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  @override
  State<V3CarPoolsPage> createState() => _V3CarPoolsPageState();
}

class _V3CarPoolsPageState extends State<V3CarPoolsPage> {
  CarPoolParentStruct? _data;
  bool _loading = true, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      dynamic r = widget.testData;
      r ??= await SupaFlow.client.rpc('get_event_car_pools', params: {
        'p_event_id': widget.eventId,
        'p_user_id': currentUserUid,
      });
      final d = r is Map
          ? CarPoolParentStruct.maybeFromMap(Map<String, dynamic>.from(r))
          : null;
      if (!mounted) return;
      setState(() {
        _data = d ?? CarPoolParentStruct();
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Car pools could not be loaded.';
      });
    }
  }

  bool get _canOffer =>
      widget.roleLevel >= 30 || (_data?.currentUserRoleLevel ?? 0) >= 30;

  void _snack(String text, {bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
        backgroundColor: warn ? V3.amber : V3.green));
  }

  Future<void> _offer() async {
    final seats = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => const _SeatsSheet(),
    );
    if (seats == null || seats <= 0 || !mounted) return;
    setState(() => _saving = true);
    try {
      await CarPoolTable().insert({
        'user_id': currentUserUid,
        'number_of_seats': seats,
        'event_id': widget.eventId,
        'status': 'open',
      });
      await _load();
      _snack('Your car pool is up. Thanks for offering.');
    } catch (_) {
      _snack('Could not create the car pool. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open(CarPoolsStruct p) async {
    await context.pushNamed(CarPoolDetailsWidget.routeName, queryParameters: {
      'eventID': serializeParam(widget.eventId, ParamType.int)!,
      'carPoolId': serializeParam(p.carPoolId, ParamType.int)!,
      'roleLevel': serializeParam(widget.roleLevel, ParamType.int)!,
    });
    if (mounted) _load();
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final pools = d?.carPools ?? const <CarPoolsStruct>[];
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 40),
            onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Car pooling', style: V3.tight(20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: V3.green))
          : _error != null
              ? Center(
                  child: Text(_error!, style: V3.inter(15, color: V3.muted)))
              : RefreshIndicator(
                  color: V3.green,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    children: [
                      if (_canOffer) ...[
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _offer,
                            style: OutlinedButton.styleFrom(
                                foregroundColor: V3.green,
                                side: const BorderSide(
                                    color: V3.green, width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            icon: const Icon(Icons.directions_car_outlined,
                                size: 20),
                            label: Text('Offer a car pool',
                                style: V3.inter(16,
                                    weight: FontWeight.w700, color: V3.green)),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                          'Drivers with spare seats for this event. Tap one to reserve a seat.',
                          style: V3.inter(13.5, color: V3.muted, height: 1.45)),
                      const SizedBox(height: 14),
                      if (pools.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
                          child: Text(
                              _canOffer
                                  ? 'No car pools yet. Offer one if you have spare seats.'
                                  : 'No car pools yet. Check back closer to the event.',
                              textAlign: TextAlign.center,
                              style:
                                  V3.inter(15, color: V3.muted, height: 1.4)),
                        )
                      else
                        for (final p in pools) _card(p),
                    ],
                  ),
                ),
    );
  }

  Widget _card(CarPoolsStruct p) {
    final mine = p.driverUserId == currentUserUid;
    return GestureDetector(
      onTap: () => _open(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          V3Avatar(nameInitials(p.driverName), highlight: mine),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mine ? '${p.driverName} (you)' : p.driverName,
                  style: V3.inter(16, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(seatsLine(p.totalSeats, p.freeSeats),
                  style: V3.inter(13, color: V3.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          _seatPill(p.freeSeats),
          const Icon(Icons.chevron_right, color: V3.muted),
        ]),
      ),
    );
  }

  Widget _seatPill(int free) => Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: free > 0 ? V3.greenTint : V3.card2,
            borderRadius: BorderRadius.circular(9)),
        child: Text(free > 0 ? '$free free' : 'Full',
            style: V3.inter(12,
                weight: FontWeight.w600,
                color: free > 0 ? V3.green : V3.muted)),
      );
}

/// "How many spare seats?" with a stepper, 1 to 8.
class _SeatsSheet extends StatefulWidget {
  const _SeatsSheet();
  @override
  State<_SeatsSheet> createState() => _SeatsSheetState();
}

class _SeatsSheetState extends State<_SeatsSheet> {
  int _seats = 3;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(top: 14, bottom: 14),
              decoration: BoxDecoration(
                  color: V3.barGrey, borderRadius: BorderRadius.circular(3))),
          Text('How many spare seats?', style: V3.tight(20)),
          const SizedBox(height: 4),
          Text('Not counting the driver. Parents reserve a seat per player.',
              textAlign: TextAlign.center,
              style: V3.inter(14, color: V3.muted, height: 1.4)),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _step(Icons.remove, _seats > 1, () => setState(() => _seats--)),
            SizedBox(
                width: 80,
                child: Text('$_seats',
                    textAlign: TextAlign.center,
                    style: V3.tight(40, weight: FontWeight.w700))),
            _step(Icons.add, _seats < 8, () => setState(() => _seats++)),
          ]),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
                onPressed: () => Navigator.pop(context, _seats),
                style: FilledButton.styleFrom(
                    backgroundColor: V3.green,
                    foregroundColor: V3.bg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: Text('Offer $_seats ${_seats == 1 ? 'seat' : 'seats'}',
                    style:
                        V3.inter(16, weight: FontWeight.w700, color: V3.bg))),
          ),
        ]),
      ),
    );
  }

  Widget _step(IconData icon, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: enabled ? V3.card2 : V3.card,
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: enabled ? V3.text : V3.muted),
        ),
      );
}
