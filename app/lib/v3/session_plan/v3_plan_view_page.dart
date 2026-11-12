// View plan (Ken, 2026-11-12): a session's plan as the branded phone PDF, for
// coaches and admins, from the event page. Read only; admins edit through
// Create / Edit plan. The PDF comes from generate-session-plan-pdf with the
// event plan's id, so it carries the club colours and crest.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../v3_theme.dart';
import 'v3_session_plan_api.dart';
import 'v3_session_plan_models.dart';
import '../v3_share.dart';

/// The event's active plan id, or null when it has none (or can't be read).
Future<String?> spEventPlanId(int eventId, {SpCall call = spLiveCall}) async {
  try {
    final r = await call(
        kSpFn, {'action': 'get', 'event_id': eventId, 'user_id': spUserId()});
    if (!r.ok) return null;
    final id = r.map['plan_id'];
    return id == null || '$id'.isEmpty ? null : '$id';
  } catch (_) {
    return null;
  }
}

class V3PlanViewPage extends StatefulWidget {
  const V3PlanViewPage(
      {super.key, required this.planId, this.call = spLiveCall});
  final String planId;
  final SpCall call;

  @override
  State<V3PlanViewPage> createState() => _V3PlanViewPageState();
}

class _V3PlanViewPageState extends State<V3PlanViewPage> {
  Uint8List? _bytes;
  String _name = 'session-plan.pdf';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await widget.call(kSpPdfFn, {
        'plan_id': widget.planId,
        'user_id': spUserId(),
        'platform': 'mobile',
        'format': 'mobile',
      });
      final pdf = '${r.map['pdf'] ?? ''}';
      if (!r.ok || pdf.isEmpty) throw Exception();
      if (!mounted) return;
      setState(() {
        _bytes = base64Decode(pdf);
        _name = '${r.map['filename'] ?? _name}';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'The plan could not be loaded.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
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
        title: Text('Session plan', style: V3.tight(17)),
      ),
      body: _error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, style: V3.inter(16, color: V3.muted)),
                const SizedBox(height: 12),
                TextButton(
                    onPressed: _load,
                    child: Text('Try again',
                        style: V3.inter(16,
                            weight: FontWeight.w600, color: V3.green))),
              ]),
            )
          : bytes == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(color: V3.green),
                    const SizedBox(height: 14),
                    Text('Getting the plan ready…',
                        style: V3.inter(15, color: V3.muted)),
                  ]),
                )
              : Column(children: [
                  Expanded(
                    child: PdfPreview(
                      build: (_) async => bytes,
                      useActions: false,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      pdfFileName: _name,
                      scrollViewDecoration: const BoxDecoration(color: V3.bg),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: V3.green,
                              foregroundColor: V3.bg,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          onPressed: () =>
                              V3Share.pdf(context, bytes, name: _name),
                          icon: const Icon(Icons.ios_share),
                          label: Text('Share plan',
                              style: V3.inter(17,
                                  weight: FontWeight.w700, color: V3.bg)),
                        ),
                      ),
                    ),
                  ),
                ]),
    );
  }
}
