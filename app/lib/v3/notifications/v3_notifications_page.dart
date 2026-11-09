// v3 Notifications. Same data as the FlutterFlow page (get_user_notifications)
// grouped Today / Yesterday / Earlier, a green dot for unread, "Mark all
// read" in the app bar instead of marking everything read on open, and
// Approve / Decline that stay live until the request is handled.
import 'package:flutter/material.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../v3_theme.dart';
import 'v3_notifications_models.dart';

class V3NotificationsPage extends StatefulWidget {
  const V3NotificationsPage({super.key, this.testData});

  /// Widget tests pass the RPC rows here instead of calling Supabase.
  @visibleForTesting
  final List<Map<String, dynamic>>? testData;

  @override
  State<V3NotificationsPage> createState() => _V3NotificationsPageState();
}

class _V3NotificationsPageState extends State<V3NotificationsPage> {
  List<NotifItem> _items = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.testData != null) {
      setState(() {
        _items = [for (final j in widget.testData!) NotifItem.fromJson(j)];
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Notifications could not be loaded.';
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

  Future<void> _badge() async {
    try {
      await actions.updateAppBadge();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- actions

  Future<void> _markAllRead() async {
    try {
      await SupaFlow.client.rpc('mark_all_notifications_read',
          params: {'p_user_id': currentUserUid});
      await _load();
      await _badge();
    } catch (_) {
      _snack('Could not mark them read. Please try again.', warn: true);
    }
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

  Future<void> _tap(NotifItem n) async {
    if (n.opensEvent) {
      if (!n.isRead) _setRead(n, true);
      await context.pushNamed(V3EventPage.routeName, queryParameters: {
        'eventID': serializeParam(n.eventId, ParamType.int)!,
        'fromSearch': serializeParam(false, ParamType.bool)!,
      });
      if (mounted) _load();
    } else if (!n.isRequest) {
      _setRead(n, !n.isRead);
    }
  }

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
    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: V3.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _RolePicker(roles: roles, title: n.title),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    await _run(n, () async {
      final r = await SupaFlow.client.rpc('confirm_member_join', params: {
        'p_member_team_id': n.actionRefId,
        'p_role_ids': picked,
      });
      if (r is Map && r['success'] == false) {
        throw Exception(r['message']);
      }
      await SupaFlow.client
          .rpc('mark_notification_read', params: {'p_notification_id': n.id});
      return r is Map
          ? '${r['message'] ?? 'Request approved'}'
          : 'Request approved';
    });
  }

  Future<void> _declineJoin(NotifItem n) => _run(n, () async {
        await SupaFlow.client.rpc('deny_member_join',
            params: {'p_member_team_id': n.actionRefId});
        await SupaFlow.client
            .rpc('mark_notification_read', params: {'p_notification_id': n.id});
        return 'Request declined';
      });

  Future<void> _approveAccess(NotifItem n) => _run(n, () async {
        await SupaFlow.client.rpc('confirm_user_member_access',
            params: {'p_user_member_id': n.actionRefId});
        await SupaFlow.client
            .rpc('mark_notification_read', params: {'p_notification_id': n.id});
        return 'Access approved';
      });

  Future<void> _declineAccess(NotifItem n) => _run(n, () async {
        await SupaFlow.client.rpc('deny_user_member_access',
            params: {'p_user_member_id': n.actionRefId});
        await SupaFlow.client
            .rpc('mark_notification_read', params: {'p_notification_id': n.id});
        return 'Access declined';
      });

  Future<void> _run(NotifItem n, Future<String> Function() work) async {
    setState(() => _busy.add(n.id));
    try {
      final msg = await work();
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
    final unread = _items.where((n) => !n.isRead && !n.isRequest).length;
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
        actions: [
          if (unread > 0)
            TextButton(
                onPressed: _markAllRead,
                child: Text('Mark all read',
                    style: V3.inter(14,
                        weight: FontWeight.w600, color: V3.green))),
        ],
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
    final busy = _busy.contains(n.id);
    final live = n.isRequest && !n.isRead;
    return GestureDetector(
      onTap: busy ? null : () => _tap(n),
      onLongPress: n.isRequest ? null : () => _longPress(n),
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
              if (live) ...[
                const SizedBox(height: 10),
                busy
                    ? const SizedBox(
                        height: 38,
                        child: Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: V3.green))))
                    : Row(children: [
                        Expanded(
                            child: FilledButton.icon(
                                onPressed: () => n.isJoinRequest
                                    ? _approveJoin(n)
                                    : _approveAccess(n),
                                style: FilledButton.styleFrom(
                                    backgroundColor: V3.green,
                                    foregroundColor: V3.bg,
                                    minimumSize: const Size(0, 38),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                icon: const Icon(Icons.check, size: 18),
                                label: Text('Approve',
                                    style: V3.inter(14,
                                        weight: FontWeight.w600,
                                        color: V3.bg)))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: FilledButton(
                                onPressed: () => n.isJoinRequest
                                    ? _declineJoin(n)
                                    : _declineAccess(n),
                                style: FilledButton.styleFrom(
                                    backgroundColor: V3.card2,
                                    foregroundColor: V3.redText,
                                    minimumSize: const Size(0, 38),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                child: Text('Decline',
                                    style: V3.inter(14,
                                        weight: FontWeight.w600,
                                        color: V3.redText)))),
                      ]),
              ] else if (n.isRequest) ...[
                const SizedBox(height: 6),
                Text('Handled', style: V3.inter(13, color: V3.muted)),
              ],
            ]),
          ),
          if (n.opensEvent)
            const Padding(
                padding: EdgeInsets.only(left: 6, top: 14),
                child: Icon(Icons.chevron_right, color: V3.muted)),
        ]),
      ),
    );
  }

  Widget _grab() => Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.only(top: 14, bottom: 10),
      decoration: BoxDecoration(
          color: V3.barGrey, borderRadius: BorderRadius.circular(3)));
}

/// Roles for a new member: tick one or more, then Confirm.
class _RolePicker extends StatefulWidget {
  const _RolePicker({required this.roles, required this.title});
  final List roles;
  final String title;
  @override
  State<_RolePicker> createState() => _RolePickerState();
}

class _RolePickerState extends State<_RolePicker> {
  final Set<int> _picked = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(top: 14, bottom: 14),
                      decoration: BoxDecoration(
                          color: V3.barGrey,
                          borderRadius: BorderRadius.circular(3)))),
              Text('Approve with which roles?', style: V3.tight(20)),
              const SizedBox(height: 2),
              Text(widget.title, style: V3.inter(14, color: V3.muted)),
              const SizedBox(height: 6),
              for (final r in widget.roles)
                if (r is Map)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: V3.green,
                    checkColor: V3.bg,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _picked.contains(_id(r['role_id'])),
                    title: Text('${r['role_name'] ?? ''}',
                        style: V3.inter(16, weight: FontWeight.w500)),
                    onChanged: (v) => setState(() => v == true
                        ? _picked.add(_id(r['role_id']))
                        : _picked.remove(_id(r['role_id']))),
                  ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                    onPressed: _picked.isEmpty
                        ? null
                        : () => Navigator.pop(context, _picked.toList()),
                    style: FilledButton.styleFrom(
                        backgroundColor: V3.green,
                        disabledBackgroundColor: V3.card2,
                        foregroundColor: V3.bg,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: Text('Confirm',
                        style: V3.inter(16,
                            weight: FontWeight.w700,
                            color: _picked.isEmpty ? V3.muted : V3.bg))),
              ),
            ]),
      ),
    );
  }

  int _id(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
}
