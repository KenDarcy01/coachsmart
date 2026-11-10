// v3 Checkout pages (the FlutterFlow Checkout, CheckoutSuccess and
// CheckoutFailed pages). Checkout lists who is being paid for and opens
// the Stripe checkout URL the event page already created. Success reads
// the session back (get-checkout-session-details) and shows the receipt;
// Failed says so. Both are reached from the Stripe return URLs.
import 'package:flutter/material.dart';

import '/backend/api_requests/api_calls.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../v3_theme.dart';

String _euro(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

/// A member row of paramPayingMembers (TeamMembersStruct.toMap()).
String payingMemberName(dynamic m) {
  if (m is! Map) return '';
  final full = '${m['member_name'] ?? m['full_name'] ?? ''}'.trim();
  if (full.isNotEmpty) return full;
  return '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
}

class V3CheckoutPage extends StatelessWidget {
  const V3CheckoutPage(
      {super.key,
      required this.eventId,
      required this.numPayments,
      required this.paymentAmount,
      required this.checkoutUrl,
      required this.payingMembers});

  final int eventId, numPayments, paymentAmount;
  final String checkoutUrl;
  final List<dynamic> payingMembers;

  @override
  Widget build(BuildContext context) {
    final names = [
      for (final m in payingMembers)
        if (payingMemberName(m).isNotEmpty) payingMemberName(m)
    ];
    final count = names.isNotEmpty ? names.length : numPayments;
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
        title: Text('Checkout', style: V3.tight(20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text('PAYMENT SUMMARY',
              style: V3.inter(13,
                  weight: FontWeight.w700, color: V3.green, letterSpacing: .8)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: V3.card, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              if (names.isEmpty)
                _line('$count ${count == 1 ? 'player' : 'players'}',
                    _euro(paymentAmount * count))
              else
                for (final n in names) _line(n, _euro(paymentAmount)),
              const Divider(height: 1, thickness: 1, color: V3.line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(children: [
                  Expanded(
                      child: Text('Total',
                          style: V3.inter(16, weight: FontWeight.w700))),
                  Text(_euro(paymentAmount * count),
                      style: V3.tight(20, weight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Text(
              'Pay now opens a secure Stripe page. Your receipt comes by email from Stripe.',
              style: V3.inter(13.5, color: V3.muted, height: 1.45)),
          const SizedBox(height: 18),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed:
                  checkoutUrl.isEmpty ? null : () => launchURL(checkoutUrl),
              style: FilledButton.styleFrom(
                  backgroundColor: V3.green,
                  disabledBackgroundColor: V3.green.withValues(alpha: .45),
                  foregroundColor: V3.bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.lock_outline, size: 20),
              label: Text('Pay now',
                  style: V3.inter(16, weight: FontWeight.w700, color: V3.bg)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String name, String amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(children: [
          Expanded(child: Text(name, style: V3.inter(16))),
          Text(amount, style: V3.inter(16, weight: FontWeight.w600)),
        ]),
      );
}

/// Stripe sends the payer back here with ?stripeSessionId=...
class V3CheckoutSuccessPage extends StatefulWidget {
  const V3CheckoutSuccessPage({super.key, required this.stripeSessionId});
  final String stripeSessionId;

  @override
  State<V3CheckoutSuccessPage> createState() => _V3CheckoutSuccessPageState();
}

class _V3CheckoutSuccessPageState extends State<V3CheckoutSuccessPage> {
  bool _loading = true;
  String _product = '';
  int? _amount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await actions.fetchSupabaseAccessToken();
      final r = await GetCheckoutSessionDetailsCall.call(
          supabaseAccessToken: token, sessionId: widget.stripeSessionId);
      if (r.succeeded && r.jsonBody is Map) {
        final j = r.jsonBody as Map;
        _product = '${j['product'] ?? ''}';
        final a = j['amountTotal'];
        _amount = a is num ? a.toInt() : int.tryParse('$a');
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => _ResultScaffold(
        title: 'Payment received',
        icon: Icons.check,
        color: V3.green,
        headline: 'Thank you. Your payment was received.',
        body: _loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: V3.green))
            : _amount == null
                ? Text('Your receipt is on its way by email from Stripe.',
                    textAlign: TextAlign.center,
                    style: V3.inter(14, color: V3.muted, height: 1.45))
                : Column(children: [
                    if (_product.isNotEmpty)
                      Text(_product,
                          textAlign: TextAlign.center,
                          style: V3.inter(15, weight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(_euro(_amount!),
                        style: V3.tight(30, weight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text('Your receipt is on its way by email from Stripe.',
                        textAlign: TextAlign.center,
                        style: V3.inter(14, color: V3.muted, height: 1.45)),
                  ]),
      );
}

class V3CheckoutFailedPage extends StatelessWidget {
  const V3CheckoutFailedPage({super.key});

  @override
  Widget build(BuildContext context) => _ResultScaffold(
        title: 'Payment not made',
        icon: Icons.close,
        color: V3.red,
        headline: 'The payment did not go through.',
        body: Text(
            'Nothing was charged. Open the event and tap Pay to try again, or contact us if it keeps failing.',
            textAlign: TextAlign.center,
            style: V3.inter(14, color: V3.muted, height: 1.45)),
      );
}

class _ResultScaffold extends StatelessWidget {
  const _ResultScaffold(
      {required this.title,
      required this.icon,
      required this.color,
      required this.headline,
      required this.body});
  final String title, headline;
  final IconData icon;
  final Color color;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(title, style: V3.tight(20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: V3.bg),
            ),
          ),
          const SizedBox(height: 22),
          Text(headline,
              textAlign: TextAlign.center,
              style: V3.tight(22, weight: FontWeight.w700)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: V3.card, borderRadius: BorderRadius.circular(14)),
            child: Center(child: body),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: () => context.goNamed(V3HomePage.routeName),
              style: FilledButton.styleFrom(
                  backgroundColor: V3.green,
                  foregroundColor: V3.bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: Text('Back to Home',
                  style: V3.inter(16, weight: FontWeight.w700, color: V3.bg)),
            ),
          ),
        ],
      ),
    );
  }
}
