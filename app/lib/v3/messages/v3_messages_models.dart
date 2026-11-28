// v3 Important messages (pop-up on open) and News (bar on Home), Ken
// 2026-11-14. Super users send for now. Data and calls kept apart from the
// widgets so tests run without a network. Functions: migration
// 20261114170000_app_messages.sql.
import 'package:flutter/painting.dart';

import '/backend/supabase/supabase.dart';

int _int(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
String _s(dynamic v) => v == null ? '' : '$v';
DateTime? _date(dynamic v) => DateTime.tryParse(_s(v))?.toLocal();

enum MessageKind { important, news, fundraiser }

enum MessageAudience { all, players, staff }

extension MessageAudienceText on MessageAudience {
  String get label => switch (this) {
        MessageAudience.all => 'Everyone',
        MessageAudience.players => 'Players and parents',
        MessageAudience.staff => 'Coaches and admins',
      };
}

class AppMessage {
  AppMessage({
    required this.id,
    required this.kind,
    required this.title,
    this.body = '',
    this.linkUrl = '',
    this.linkLabel = '',
    this.fromName = '',
    this.crest = '',
    this.scope = 'all',
    this.clubId,
    this.teamIds = const [],
    this.audience = MessageAudience.all,
    this.startsAt,
    this.endsAt,
    this.seen = false,
    this.endedAt,
    this.reach = 0,
    this.seenCount = 0,
    this.dismissedCount = 0,
    this.teamNames = const [],
    this.imageUrl = '',
    this.priceLabel = '',
    this.tapCount = 0,
    this.push = false,
    this.pushSentAt,
    this.pushCount,
    this.primaryColour = '',
    this.secondaryColour = '',
  });

  factory AppMessage.fromJson(Map j) => AppMessage(
        id: _int(j['id']),
        kind: switch (j['kind']) {
          'news' => MessageKind.news,
          'fundraiser' => MessageKind.fundraiser,
          _ => MessageKind.important,
        },
        title: _s(j['title']),
        body: _s(j['body']),
        linkUrl: _s(j['link_url']),
        linkLabel: _s(j['link_label']),
        fromName: _s(j['from_name']),
        crest: _s(j['crest']),
        scope: _s(j['scope']).isEmpty ? 'all' : _s(j['scope']),
        clubId: j['club_id'] == null ? null : _int(j['club_id']),
        teamIds: [
          if (j['team_ids'] is List)
            for (final t in j['team_ids'] as List) _int(t)
        ],
        audience: MessageAudience.values.firstWhere(
            (a) => a.name == _s(j['audience']),
            orElse: () => MessageAudience.all),
        startsAt: _date(j['starts_at']),
        endsAt: _date(j['ends_at']),
        seen: j['seen'] == true,
        endedAt: _date(j['ended_at']),
        reach: _int(j['reach']),
        seenCount: _int(j['seen_count']),
        dismissedCount: _int(j['dismissed_count']),
        teamNames: [
          if (j['team_names'] is List)
            for (final t in j['team_names'] as List) _s(t)
        ],
        imageUrl: _s(j['image_url']),
        priceLabel: _s(j['price_label']),
        tapCount: _int(j['tap_count']),
        push: j['push'] == true,
        pushSentAt: _date(j['push_sent_at']),
        pushCount: j['push_count'] == null ? null : _int(j['push_count']),
        primaryColour: _s(j['primary_colour']),
        secondaryColour: _s(j['secondary_colour']),
      );

  final int id;
  final MessageKind kind;
  final String title;
  final String body;
  final String linkUrl;
  final String linkLabel;
  final String fromName;
  final String crest;

  /// all (CoachSmart), club or team.
  final String scope;
  final int? clubId;
  final List<int> teamIds;
  final MessageAudience audience;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// News only: this user opened it in the News sheet.
  bool seen;

  // Sender's list only.
  final DateTime? endedAt;
  final int reach;
  final int seenCount;
  final int dismissedCount;
  final List<String> teamNames;

  /// Important only: one optional photo, shown above the title.
  final String imageUrl;

  /// Fundraiser only: the price line ("€10 a line"), and how many people
  /// tapped its button (sender's list).
  final String priceLabel;
  final int tapCount;

  /// Important only (sender's list): a push goes when it starts showing;
  /// once sent (pushSentAt), never again. pushCount = phones reached.
  final bool push;
  final DateTime? pushSentAt;
  final int? pushCount;

  /// The sending club's colours ('#rrggbb'), empty for CoachSmart-wide.
  final String primaryColour;
  final String secondaryColour;

  /// The club colour for the pop-up's stripe and button: the primary colour
  /// unless it is too pale or too dark to stand out on the dark card, then
  /// the secondary; null means CoachSmart green.
  Color? get clubColour {
    Color? parse(String h) {
      final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(h.trim());
      return m == null
          ? null
          : Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
    }

    bool usable(Color? c) {
      if (c == null) return false;
      final l = c.computeLuminance();
      return l > 0.02 && l < 0.85;
    }

    final p = parse(primaryColour), s = parse(secondaryColour);
    if (usable(p)) return p;
    if (usable(s)) return s;
    return null;
  }

  bool get isNews => kind == MessageKind.news;
  bool get isFundraiser => kind == MessageKind.fundraiser;

  /// Live, scheduled or ended, for the sender's Messages page.
  String status(DateTime now) {
    if (endedAt != null || (endsAt != null && !endsAt!.isAfter(now))) {
      return 'ended';
    }
    if (startsAt != null && startsAt!.isAfter(now)) return 'scheduled';
    return 'live';
  }

  /// "Whole club", "U12 Boys", "Everyone on CoachSmart" for the sender.
  String get sentTo {
    if (teamNames.isNotEmpty) return teamNames.join(', ');
    if (scope == 'club') return fromName.isEmpty ? 'Whole club' : fromName;
    return 'Everyone on CoachSmart';
  }
}

/// Set from get_my_club_tools on Home: only SuperUsers may send to
/// everyone on CoachSmart; club officers send to their own club.
class MessagesAccess {
  static bool sendEveryone = false;
}

class MyMessages {
  const MyMessages(
      {this.important = const [],
      this.news = const [],
      this.fundraisers = const [],
      this.pinned = const [],
      this.isSuperUser = false});

  factory MyMessages.fromJson(Map j) => MyMessages(
        important: [
          if (j['important'] is List)
            for (final m in (j['important'] as List).whereType<Map>())
              AppMessage.fromJson(m)
        ],
        news: [
          if (j['news'] is List)
            for (final m in (j['news'] as List).whereType<Map>())
              AppMessage.fromJson(m)
        ],
        fundraisers: [
          if (j['fundraisers'] is List)
            for (final m in (j['fundraisers'] as List).whereType<Map>())
              AppMessage.fromJson(m)
        ],
        pinned: [
          if (j['pinned'] is List)
            for (final m in (j['pinned'] as List).whereType<Map>())
              AppMessage.fromJson(m)
        ],
        isSuperUser: j['is_super_user'] == true,
      );

  final List<AppMessage> important;
  final List<AppMessage> news;

  /// Fundraisers: their own slim row under Club news (2026-11-26).
  final List<AppMessage> fundraisers;
  final bool isSuperUser;

  /// Important messages still running, acknowledged or not: pinned at the
  /// top of the club screen until they end (Ken, 2026-11-26).
  final List<AppMessage> pinned;

  int get unreadNews => news.where((n) => !n.seen).length;
}

class TargetTeam {
  const TargetTeam(this.teamId, this.name);
  final int teamId;
  final String name;
}

class TargetClub {
  const TargetClub(this.clubId, this.name, this.crest, this.teams);

  factory TargetClub.fromJson(Map j) => TargetClub(
        _int(j['club_id']),
        _s(j['club_name']),
        _s(j['crest']),
        [
          if (j['teams'] is List)
            for (final t in (j['teams'] as List).whereType<Map>())
              TargetTeam(_int(t['team_id']), _s(t['team_name']))
        ],
      );

  final int clubId;
  final String name;
  final String crest;
  final List<TargetTeam> teams;
}

class MessagesApi {
  const MessagesApi();

  Future<MyMessages> mine() async {
    final r = await SupaFlow.client.rpc('get_my_app_messages');
    return MyMessages.fromJson(r is Map ? r : const {});
  }

  Future<void> dismiss(int id) =>
      SupaFlow.client.rpc('dismiss_app_message', params: {'p_message_id': id});

  /// A tap on a fundraiser's button, counted for the sender.
  Future<void> tap(int id) =>
      SupaFlow.client.rpc('app_message_tap', params: {'p_id': id});

  Future<void> markSeen(List<int> ids) => ids.isEmpty
      ? Future.value()
      : SupaFlow.client
          .rpc('mark_app_messages_seen', params: {'p_message_ids': ids});

  Future<List<AppMessage>> sent() async {
    final r = await SupaFlow.client.rpc('get_sent_app_messages');
    return [
      if (r is List)
        for (final m in r.whereType<Map>()) AppMessage.fromJson(m)
    ];
  }

  Future<List<TargetClub>> targets() async {
    final r = await SupaFlow.client.rpc('get_app_message_targets');
    return [
      if (r is List)
        for (final c in r.whereType<Map>()) TargetClub.fromJson(c)
    ];
  }

  Future<int> count(int? clubId, List<int> teamIds, MessageAudience a) async {
    final r = await SupaFlow.client.rpc('count_app_message_audience', params: {
      'p_club_id': clubId,
      'p_team_ids': teamIds,
      'p_audience': a.name,
    });
    return _int(r);
  }

  /// Phones with notifications on that a push would reach.
  Future<int> countPush(
      int? clubId, List<int> teamIds, MessageAudience a) async {
    final r = await SupaFlow.client.rpc('count_app_message_push', params: {
      'p_club_id': clubId,
      'p_team_ids': teamIds,
      'p_audience': a.name,
    });
    return _int(r);
  }

  /// Phones a push would reach, split by platform, plus people reached
  /// (for the confirm sheet before an Important push).
  Future<PushReach> countPushDetail(
      int? clubId, List<int> teamIds, MessageAudience a) async {
    final r = await SupaFlow.client
        .rpc('count_app_message_push_detail', params: {
      'p_club_id': clubId,
      'p_team_ids': teamIds,
      'p_audience': a.name,
    });
    final j = (r as Map).cast<String, dynamic>();
    return PushReach(
      people: _int(j['people']),
      phones: _int(j['phones']),
      ios: _int(j['ios']),
      android: _int(j['android']),
    );
  }

  /// Push on or off for a saved Important message (sent when it starts).
  Future<void> setPush(int id, bool on) => SupaFlow.client
      .rpc('set_app_message_push', params: {'p_id': id, 'p_push': on});

  Future<int> save({
    int? id,
    required MessageKind kind,
    required String title,
    required String body,
    String linkUrl = '',
    String linkLabel = '',
    int? clubId,
    List<int> teamIds = const [],
    MessageAudience audience = MessageAudience.all,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final r = await SupaFlow.client.rpc('save_app_message', params: {
      'p_id': id,
      'p_kind': kind.name,
      'p_title': title.trim(),
      'p_body': body.trim(),
      'p_link_url': linkUrl.trim(),
      'p_link_label': linkLabel.trim(),
      'p_club_id': clubId,
      'p_team_ids': teamIds,
      'p_audience': audience.name,
      'p_starts_at': startsAt.toUtc().toIso8601String(),
      'p_ends_at': endsAt.toUtc().toIso8601String(),
    });
    return _int(r);
  }

  Future<void> end(int id, {bool delete = false}) => SupaFlow.client
      .rpc('end_app_message', params: {'p_id': id, 'p_delete': delete});
}

/// Adds https:// when a sender types a bare address.
String normaliseLink(String url) {
  final u = url.trim();
  if (u.isEmpty) return '';
  return u.contains('://') ? u : 'https://$u';
}

/// Who an Important push reaches: phones with push on (iPhone / Android)
/// and everyone the message reaches.
class PushReach {
  const PushReach(
      {required this.people,
      required this.phones,
      required this.ios,
      required this.android});
  final int people;
  final int phones;
  final int ios;
  final int android;
  int get other => (phones - ios - android).clamp(0, phones);
  int get noPush => (people - phones).clamp(0, people);
}
