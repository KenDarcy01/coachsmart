// v3 team Payments page (team Stripe Connect, 2026-11-12, thread "Plan Stripe
// Connect for team payouts"). A team admin connects the team's own Stripe
// account so event payments go straight to the team's bank; CoachSmart never
// holds a team's money. Stripe hosts the sign-up and does the ID and bank
// checks. Backend: team-stripe edge function (status / start / set_payments).
//
// The payments switch only turns on once Stripe says the account can take
// payments. Teams that took payments before Connect ("legacy") keep using the
// CoachSmart account until they connect.
//
// Opening Stripe is two taps (get the link, then open it) so the browser never
// blocks the new tab on the web build.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '/backend/supabase/supabase.dart';
import '../v3_theme.dart';
import '/v3/tracking/v3_track.dart';

class V3TeamPaymentsPage extends StatefulWidget {
  const V3TeamPaymentsPage(
      {super.key, required this.teamId, required this.teamName});
  final int teamId;
  final String teamName;

  @override
  State<V3TeamPaymentsPage> createState() => _V3TeamPaymentsPageState();
}

class _TeamStripe {
  _TeamStripe(Map m)
      : connected = m['connected'] == true,
        ready = m['ready'] == true,
        detailsSubmitted = m['details_submitted'] == true,
        payoutsEnabled = m['payouts_enabled'] == true,
        due = (m['due'] as num?)?.toInt() ?? 0,
        name = m['name'] as String?,
        payments = m['payments'] == true,
        legacy = m['legacy'] == true;
  final bool connected, ready, detailsSubmitted, payoutsEnabled;
  final int due;
  final String? name;
  final bool payments, legacy;
}

class _V3TeamPaymentsPageState extends State<V3TeamPaymentsPage>
    with WidgetsBindingObserver {
  _TeamStripe? _s;
  String? _error;
  bool _busy = false;
  String? _link; // Stripe sign-up link, ready to open

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from Stripe: show the new state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _link != null) {
      _link = null;
      _load();
    }
  }

  Future<Map?> _call(Map<String, dynamic> body) async {
    try {
      final res = await SupaFlow.client.functions
          .invoke('team-stripe', body: {'team_id': widget.teamId, ...body});
      final d = res.data;
      if (d is Map && d['success'] == true) return d['data'] as Map?;
      throw Exception(d is Map ? d['error'] : null);
    } on FunctionException catch (e) {
      final d = e.details;
      _snack(d is Map && d['error'] is String
          ? d['error'] as String
          : 'Something went wrong. Please try again.');
    } catch (e) {
      final m = e.toString().replaceFirst('Exception: ', '');
      _snack(m.isNotEmpty && m != 'null'
          ? m
          : 'Something went wrong. Please try again.');
    }
    return null;
  }

  Future<void> _load() async {
    final d = await _call({'action': 'status'});
    if (!mounted) return;
    setState(() {
      if (d != null) {
        _s = _TeamStripe(d);
        _error = null;
      } else if (_s == null) {
        _error = 'Could not load payments for this team.';
      }
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: V3.card2,
        content: Text(text, style: V3.inter(15, weight: FontWeight.w500))));
  }

  Future<void> _getLink() async {
    setState(() => _busy = true);
    V3Track.event('team_stripe_start', {'team_id': widget.teamId});
    final d = await _call({'action': 'start'});
    if (!mounted) return;
    setState(() {
      _busy = false;
      _link = d?['url'] as String?;
    });
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      _snack('Could not open Stripe.');
    }
  }

  Future<void> _setPayments(bool on) async {
    setState(() => _busy = true);
    V3Track.event('team_payments_switch', {'team_id': widget.teamId, 'on': on});
    final d = await _call({'action': 'set_payments', 'on': on});
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (d != null) _s = _TeamStripe(d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 40),
            onPressed: () => Navigator.of(context).pop()),
        title: Text('Payments', style: V3.tight(20)),
      ),
      body: s == null
          ? Center(
              child: _error != null
                  ? Text(_error!, style: V3.inter(15, color: V3.muted))
                  : const CircularProgressIndicator(color: V3.green))
          : RefreshIndicator(
              color: V3.green,
              backgroundColor: V3.card,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                children: [
                  Text(widget.teamName,
                      style: V3.inter(14, color: V3.muted)),
                  const SizedBox(height: 10),
                  _statusCard(s),
                  if (s.ready) ...[
                    const SizedBox(height: 12),
                    _switchCard(s),
                  ],
                  if (s.legacy) ...[
                    const SizedBox(height: 12),
                    _note(
                        'Payments for this team are still collected by CoachSmart. Connect Stripe to have them paid straight to your team instead.',
                        amber: true),
                  ],
                  const SizedBox(height: 16),
                  _howItWorks(),
                ],
              ),
            ),
    );
  }

  Widget _statusCard(_TeamStripe s) {
    final IconData icon;
    final Color colour, tint;
    final String title, body;
    if (s.ready) {
      icon = Icons.check_circle;
      colour = V3.green;
      tint = V3.greenTint;
      title = 'Stripe connected';
      body = s.payoutsEnabled
          ? 'Payments go straight to ${s.name?.isNotEmpty == true ? s.name : 'your Stripe account'} and on to your bank.'
          : 'Payments go to your Stripe account. Stripe still needs your bank details before it can pay out.';
    } else if (s.connected) {
      icon = Icons.hourglass_top;
      colour = V3.amberText;
      tint = V3.amberTint;
      title = s.detailsSubmitted ? 'Stripe is checking your details' : 'Finish your Stripe setup';
      body = s.due > 0
          ? 'Stripe needs ${s.due} more ${s.due == 1 ? 'detail' : 'details'} before the team can take payments.'
          : 'This usually takes a few minutes. Pull down to check again.';
    } else {
      icon = Icons.account_balance_outlined;
      colour = V3.text;
      tint = V3.card2;
      title = 'Get paid straight to your bank';
      body =
          'Connect a Stripe account for the team. Parents pay in the app and Stripe pays the money into your bank.';
    }
    final String action = s.ready
        ? 'Open Stripe'
        : (s.connected ? 'Continue setup' : 'Set up with Stripe');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, color: colour, size: 24)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title, style: V3.tight(18, color: V3.text))),
        ]),
        const SizedBox(height: 10),
        Text(body, style: V3.inter(15, color: V3.muted, height: 1.4)),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: _link != null
              ? FilledButton.icon(
                  key: const ValueKey('team-stripe-open-link'),
                  onPressed: () => _open(_link!),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text('Open Stripe sign-up',
                      style: V3.inter(15,
                          weight: FontWeight.w700, color: V3.bg)),
                  style: _btn())
              : FilledButton(
                  key: const ValueKey('team-stripe-action'),
                  onPressed: _busy
                      ? null
                      : (s.ready
                          ? () => _open('https://dashboard.stripe.com')
                          : _getLink),
                  style: _btn(),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: V3.bg))
                      : Text(action,
                          style: V3.inter(15,
                              weight: FontWeight.w700, color: V3.bg))),
        ),
        if (_link != null) ...[
          const SizedBox(height: 8),
          Text('When you are done in Stripe, come back here.',
              style: V3.inter(13, color: V3.muted)),
        ],
      ]),
    );
  }

  ButtonStyle _btn() => FilledButton.styleFrom(
      backgroundColor: V3.green,
      foregroundColor: V3.bg,
      disabledBackgroundColor: V3.barGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)));

  Widget _switchCard(_TeamStripe s) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Take payments at events',
                      style: V3.inter(16, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Adds a payment option when you create an event.',
                      style: V3.inter(13, color: V3.muted)),
                ]),
          ),
          Switch(
            key: const ValueKey('team-payments-switch'),
            value: s.payments,
            activeThumbColor: Colors.white,
            activeTrackColor: V3.green,
            inactiveTrackColor: const Color(0xFF3A3F4A),
            onChanged: _busy ? null : _setPayments,
          ),
        ]),
      );

  Widget _note(String text, {bool amber = false}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: amber ? V3.amberTint : V3.card,
            borderRadius: BorderRadius.circular(14),
            border: amber ? Border.all(color: V3.amberLine) : null),
        child: Text(text,
            style: V3.inter(14,
                color: amber ? V3.amberText : V3.muted, height: 1.4)),
      );

  Widget _howItWorks() {
    Widget line(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 7, right: 10),
              child: Icon(Icons.circle, size: 6, color: V3.green),
            ),
            Expanded(
                child: Text(t,
                    style: V3.inter(14, color: V3.muted, height: 1.4))),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('How it works', style: V3.inter(15, weight: FontWeight.w600)),
      const SizedBox(height: 10),
      line(
          'Stripe asks who is signing up: you as a person, or your club. That is your call.'),
      line(
          'Stripe checks ID and bank details. CoachSmart never sees your bank details.'),
      line(
          'Stripe takes its card fee from each payment, about 1.5% + €0.25.'),
      line(
          'Refunds you make in the app come out of the team\'s Stripe balance.'),
    ]);
  }
}
