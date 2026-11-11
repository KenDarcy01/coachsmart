// v3 Notifications. Same data and read rules as the FlutterFlow page
// (Ken, 2026-11-11):
//  - Plain notices (no action) are marked read 2 seconds after the page
//    opens (mark_all_notifications_read), the app badge is refreshed.
//  - Rows that need an action stay unread until it is done:
//    * event reminders ('attend') clear on the server once every child on
//      them has an answer, from any screen and by any linked parent;
//    * join / access requests clear for every admin once one admin acts.
//  - Nothing opens another page. Reminders carry Going / Can't go buttons
//    for each of the user's children who hasn't answered, requests carry
//    Approve / Decline. Only the tapped button shows a spinner.
//  - A realtime listener on the user's rows reloads the list, so a request
//    another admin handles, or a child another parent answers, updates live.
import 'dart:async';

import 'package:flutter/material.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/custom_code/actions/index.dart' as actions;
import '../teams/v3_role_picker.dart';
import '../v3_theme.dart';
import 'v3_notifications_models.dart';

class V3NotificationsPage extends StatefulWidget {
  const V3NotificationsPage({super.key, this.testData, this.testMembers});

  /// Widget tests pass the RPC rows here instead of calling Supabase.
  @visibleForTesting
  final List<Map<String, dynamic>>? testData;

  /// Widget tests: event id -> the user's children on that event.
  @visibleForTesting
  final Map<int, List<NotifMember>>? testMembers;

  @override
  State<V3NotificationsPage> createState() => _V3NotificationsPageState();
}

class _V3NotificationsPageState extends State<V3NotificationsPage> {
  List<NotifItem> _items = [];
  bool _loading = true;
  String? _error;

  /// Notification id -> the button being saved ('approve' / 'decline').
  final Map<int, String> _busy = {};

  /// Event id -> the children who had no answer when the reminder was first
  /// shown this visit. Kept after they answer so the chosen button stays lit
  /// and can be changed.
  final Map<int, List<NotifMember>> _members = {};

  /// "eventId:memberId" -> the reply being saved.
  final Map<String, int> _replying = {};

  Timer? _autoRead;
  Timer? _debounce;
  RealtimeChannel? _channel;

  bool get _test => widget.testData != null;

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (!mounted) return;
      _autoRead = Timer(const Duration(seconds: 2), _markNoticesRead);
    });
    _listen();
  }

  @override
  void dispose() {
    _autoRead?.cancel();
    _debounce?.cancel();
    final ch = _channel;
    if (ch != null) {
      try {
        SupaFlow.client.removeChannel(ch);
      } catch (_) {}
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- data

  Future<void> _load() async {
    if (_test) {
      setState(() {
        _items = [for (final j in widget.testData!) NotifItem.fromJson(j)];
        _members.addAll(widget.testMembers ?? const {});
        _loading = false;
      });
      return;
    }
    try {
      final r = await SupaFlow.client.rpc('get_user_notifications',
          params: {'p_user_id': currentUserUid, 'p_limit': 100});
      if (!mounted) return;
      setState(() {
        _items = [
          for (final j in (r is List ? r : const []))
            if (j is Map) NotifItem.fromJson(j)
        ];
        _loading = false;
        _error = null;
      });
      _loadMembers();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Notifications could not be loaded.';
      });
    }
  }

  /// For each open reminder, the user's children on that event who haven't
  /// answered yet (the same list the event page shows its buttons for).
  Future<void> _loadMembers() async {
    final ids = {
      for (final n in _items)
        if (n.isAttend && !n.isRead && !_members.containsKey(n.eventId))
          n.eventId
    };
    await Future.wait(ids.map((id) async {
      try {
        final r = await GetUserEventDetailsCall.call(
          pEventId: id,
          pUserId: currentUserUid,
          supabaseJWTtoken: currentJwtToken,
        );
        final d = UserEventDetailsStruct.maybeFromMap(r.jsonBody);
        if (d == null) return;
        final open = d.requestAttendance && d.eventId != 0;
        _members[id] = [
          if (open)
            for (final m in d.teamMembers)
              if (m.responseId != 3 && m.responseId != 4)
                NotifMember(
                    m.memberId,
                    m.firstName.isNotEmpty ? m.firstName : m.lastName,
                    m.responseId),
        ];
      } catch (_) {}
    }));
    if (mounted && ids.isNotEmpty) setState(() {});
  }

  /// Reload when any of the user's rows change (another admin handled a
  /// request, another parent answered, a new notification came in).
  void _listen() {
    if (_test || currentUserUid.isEmpty) return;
    try {
      _channel = SupaFlow.client
          .channel('v3-notifs-$currentUserUid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'recipient_user_id',
                value: currentUserUid),
            callback: (_) {
              _debounce?.cancel();
              _debounce =
                  Timer(const Duration(milliseconds: 600), () => _load());
            },
          )
          .subscribe();
    } catch (_) {}
  }

  void _snack(String text, {bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
        backgroundColor: warn ? V3.amber : V3.green));
  }

  Future<void> _badge() async {
    try {
      await actions.updateAppBadge();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- read

  /// FlutterFlow rule: 2 seconds after opening, every plain notice is read.
  /// Rows with an action are left alone by the server function.
  Future<void> _markNoticesRead() async {
    if (_test) {
      setState(() {
        _items = [
          for (final n in _items) n.needsAction || n.isRead ? n : n.asRead(),
        ];
      });
      return;
    }
    if (!_items.any((n) => !n.isRead && !n.needsAction)) return;
    try {
      await SupaFlow.client.rpc('mark_all_notifications_read',
          params: {'p_user_id': currentUserUid});
      await _load();
      await _badge();
    } catch (_) {}
  }

  Future<void> _setRead(NotifItem n, bool read) async {
    try {
      if (read) {
        await SupaFlow.client
            .rpc('mark_notification_read', params: {'p_notification_id': n.id});
      } else {
        await NotificationsTable().update(
            data: {'is_read': false, 'when_read': null},
            matchingRows: (q) => q.eq('id', n.id));
      }
      await _load();
      await _badge();
    } catch (_) {
      _snack('Could not update that notification.', warn: true);
    }
  }

  // Long press on a plain notice: mark read / unread, as the FlutterFlow
  // page's menu did. Rows with an action follow their own rules.
  Future<void> _longPress(NotifItem n) async {
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _grab(),
          ListTile(
            leading: Icon(
                n.isRead ? Icons.mark_email_unread_outlined : Icons.done_all,
                color: V3.green),
            title: Text(n.isRead ? 'Mark as unread' : 'Mark as read',
                style: V3.inter(16, weight: FontWeight.w500)),
            onTap: () => Navigator.pop(ctx, 'toggle'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (pick == 'toggle') _setRead(n, !n.isRead);
  }

  // ---------------------------------------------------------------- replies

  /// Going (3) / Can't go (4) for one child, saved the same way as the
  /// event page. The server clears the reminder (for every linked parent)
  /// once all of the user's children on it have answered.
  Future<void> _reply(NotifItem n, NotifMember m, int responseId) async {
    if (m.responseId == responseId) return;
    final key = '${n.eventId}:${m.memberId}';
    setState(() => _replying[key] = responseId);
    try {
      if (!_test) {
        final row = await EventAttendanceTable().insert({
          'event_id': n.eventId,
          'member_id': m.memberId,
          'response_id': responseId,
        });
        await NotifyAdminsAttendanceChangeCall.call(
          supabaseJWTtoken: currentJwtToken,
          pMemberIdParam: m.memberId,
          pEventIdParam: n.eventId,
          pResponseId: responseId,
          pAttendanceId: row.attendanceId,
        );
      }
      m.responseId = responseId;
      if (!_test) {
        await _load();
        await _badge();
      }
    } catch (_) {
      _snack('Could not save the reply. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _replying.remove(key));
    }
  }

  // ---------------------------------------------------------------- requests

  /// Approve a join request: pick the roles, then confirm_member_join.
  Future<void> _approveJoin(NotifItem n) async {
    List roles = [];
    try {
      final r = await SupaFlow.client
          .rpc('get_team_roles', params: {'p_team_id': n.teamId});
      roles = r is List ? r : [];
    } catch (_) {}
    if (!mounted) return;
    if (roles.isEmpty) {
      _snack('No roles found for this team.', warn: true);
      return;
    }
    final picked = await pickRoles(context, roles: roles, title: n.title);
    if (picked == null || picked.isEmpty || !mounted) return;
    await _run(n, 'approve', () async {
      final r = await SupaFlow.client.rpc('confirm_member_join', params: {
        'p_member_team_id': n.actionRefId,
        'p_role_ids': picked,
      });
      if (r is Map && r['success'] == false) {
        throw Exception(r['message']);
      }
      return r is Map
          ? '${r['message'] ?? 'Request approved'}'
          : 'Request approved';
    });
  }

  Future<void> _declineJoin(NotifItem n) => _run(n, 'decline', () async {
        await SupaFlow.client.rpc('deny_member_join',
            params: {'p_member_team_id': n.actionRefId});
        return 'Request declined';
      });

  Future<void> _approveAccess(NotifItem n) => _run(n, 'approve', () async {
        await SupaFlow.client.rpc('confirm_user_member_access',
            params: {'p_user_member_id': n.actionRefId});
        return 'Access approved';
      });

  Future<void> _declineAccess(NotifItem n) => _run(n, 'decline', () async {
        await SupaFlow.client.rpc('deny_user_member_access',
            params: {'p_user_member_id': n.actionRefId});
        return 'Access declined';
      });

  /// Runs a request action. Like the FlutterFlow page, first check that no
  /// other admin got there first (their action marks every copy read).
  Future<void> _run(
      NotifItem n, String which, Future<String> Function() work) async {
    setState(() => _busy[n.id] = which);
    try {
      final rows = await NotificationsTable()
          .queryRows(queryFn: (q) => q.eq('id', n.id));
      if (rows.isNotEmpty && rows.first.isRead == true) {
        await _load();
        _snack('Someone else has already dealt with this request.', warn: true);
        return;
      }
      final msg = await work();
      await SupaFlow.client
          .rpc('mark_notification_read', params: {'p_notification_id': n.id});
      await _load();
      await _badge();
      _snack(msg);
    } catch (e) {
      _snack('That did not go through. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _busy.remove(n.id));
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
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
        title: Text('Notifications', style: V3.tight(20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: V3.green))
          : _error != null
              ? Center(
                  child: Text(_error!, style: V3.inter(15, color: V3.muted)))
              : _items.isEmpty
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text('No notifications yet.',
                              textAlign: TextAlign.center,
                              style: V3.inter(15, color: V3.muted))))
                  : RefreshIndicator(
                      color: V3.green,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        children: [
                          for (final g
                              in groupNotifs(_items, DateTime.now())) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
                              child: Text(g.$1.toUpperCase(),
                                  style: V3.inter(13,
                                      weight: FontWeight.w700,
                                      color: V3.green,
                                      letterSpacing: .8)),
                            ),
                            for (final n in g.$2) _card(n),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _card(NotifItem n) {
    final liveRequest = n.isRequest && !n.isRead;
    final kids = n.isAttend ? _members[n.eventId] : null;
    // Reply buttons while the reminder is open, and after a reply made on
    // this visit so the choice stays visible.
    final showReplies = kids != null &&
        kids.isNotEmpty &&
        (!n.isRead || kids.any((m) => m.answered));
    return GestureDetector(
      onLongPress: n.needsAction ? null : () => _longPress(n),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 6, right: 10),
              decoration: BoxDecoration(
                  color: n.isRead ? Colors.transparent : V3.green,
                  shape: BoxShape.circle)),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(n.teamName,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(12.5,
                            weight: FontWeight.w500, color: V3.green))),
                const SizedBox(width: 8),
                Text(n.timeLabel, style: V3.inter(12.5, color: V3.muted)),
              ]),
              const SizedBox(height: 3),
              Text(n.title,
                  style: V3.inter(15.5,
                      weight: FontWeight.w600,
                      color: n.isRead ? V3.muted : V3.text)),
              if (n.body.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(n.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(14, color: V3.muted, height: 1.35)),
              ],
              if (showReplies) ...[
                const SizedBox(height: 6),
                for (final m in kids) _replyRow(n, m),
              ],
              if (liveRequest) ...[
                const SizedBox(height: 10),
                _requestButtons(n),
              ] else if (n.isRequest) ...[
                const SizedBox(height: 6),
                Text('Handled', style: V3.inter(13, color: V3.muted)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  // "✓ Aoife" | "✗ Aoife", the same buttons as the event page. Unanswered:
  // both light. Chosen: solid green or red, the other dim. Only the tapped
  // button shows the spinner.
  Widget _replyRow(NotifItem n, NotifMember m) {
    final saving = _replying['${n.eventId}:${m.memberId}'];
    final going = m.responseId == 3;
    final declined = m.responseId == 4;
    const dim = Color(0xFF7C8089);

    Widget button(bool isGo) {
      final on = isGo ? going : declined;
      final Color bg;
      final Color fg;
      if (on) {
        bg = isGo ? V3.green : V3.red;
        fg = isGo ? V3.bg : Colors.white;
      } else {
        bg = V3.card2;
        fg = m.answered ? dim : V3.text;
      }
      return Expanded(
        child: GestureDetector(
          onTap: saving != null ? null : () => _reply(n, m, isGo ? 3 : 4),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (saving == (isGo ? 3 : 4))
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else
                Icon(isGo ? Icons.check : Icons.close, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(15, weight: FontWeight.w700, color: fg)),
              ),
            ]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        button(true),
        const SizedBox(width: 8),
        button(false),
      ]),
    );
  }

  Widget _requestButtons(NotifItem n) {
    final saving = _busy[n.id];
    Widget spinner(Color c) => SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: c));
    return Row(children: [
      Expanded(
          child: FilledButton(
              onPressed: saving != null
                  ? null
                  : () => n.isJoinRequest ? _approveJoin(n) : _approveAccess(n),
              style: FilledButton.styleFrom(
                  backgroundColor: V3.green,
                  disabledBackgroundColor: V3.green,
                  foregroundColor: V3.bg,
                  minimumSize: const Size(0, 38),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                saving == 'approve'
                    ? spinner(V3.bg)
                    : const Icon(Icons.check, size: 18, color: V3.bg),
                const SizedBox(width: 6),
                Text('Approve',
                    style: V3.inter(14, weight: FontWeight.w600, color: V3.bg)),
              ]))),
      const SizedBox(width: 8),
      Expanded(
          child: FilledButton(
              onPressed: saving != null
                  ? null
                  : () => n.isJoinRequest ? _declineJoin(n) : _declineAccess(n),
              style: FilledButton.styleFrom(
                  backgroundColor: V3.card2,
                  disabledBackgroundColor: V3.card2,
                  foregroundColor: V3.redText,
                  minimumSize: const Size(0, 38),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: saving == 'decline'
                  ? spinner(V3.redText)
                  : Text('Decline',
                      style: V3.inter(14,
                          weight: FontWeight.w600, color: V3.redText)))),
    ]);
  }

  Widget _grab() => Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.only(top: 14, bottom: 10),
      decoration: BoxDecoration(
          color: V3.barGrey, borderRadius: BorderRadius.circular(3)));
}
