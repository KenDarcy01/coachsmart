// Club followers (Ken, 2026-11-26): follow a club with its club code, no
// team and no approval. There is no club search: no code, no club.
// Server: migration 20261126190000_club_followers.sql.
import '/backend/supabase/supabase.dart';

int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
String _s(dynamic v) => v == null ? '' : '$v';

class FollowedClub {
  const FollowedClub({
    required this.clubId,
    required this.name,
    this.crest = '',
    this.county = '',
    this.sportId = 1,
    this.following = false,
  });

  factory FollowedClub.fromJson(Map j) => FollowedClub(
        clubId: _i(j['club_id']),
        name: _s(j['club_name']),
        crest: _s(j['crest']),
        county: _s(j['county']),
        sportId: _i(j['sport_id']) == 0 ? 1 : _i(j['sport_id']),
        following: j['following'] == true,
      );

  final int clubId;
  final String name, crest, county;
  final int sportId;
  final bool following;

  /// "GAA", "Rugby", "Soccer"
  String get sport =>
      switch (sportId) { 2 => 'Soccer', 3 => 'Rugby', _ => 'GAA' };

  /// "GAA · Dublin"
  String get line => county.isEmpty ? sport : '$sport · $county';

  /// Chip label when the user is in several clubs: always the full club
  /// name (Ken, 2026-11-26).
  static String chipLabel(FollowedClub c, List<FollowedClub> all) => c.name;
}

/// What a typed code is.
enum CodeKind { none, club, team }

class CodeLookup {
  const CodeLookup(this.kind, {this.club, this.teamName = ''});
  final CodeKind kind;
  final FollowedClub? club;
  final String teamName;
  static const none = CodeLookup(CodeKind.none);

  factory CodeLookup.fromJson(dynamic v) {
    if (v is! Map) return none;
    return switch (v['kind']) {
      'club' when v['club'] is Map =>
        CodeLookup(CodeKind.club, club: FollowedClub.fromJson(v['club'])),
      'team' => CodeLookup(CodeKind.team, teamName: _s(v['team_name'])),
      _ => none,
    };
  }
}

/// Codes are letters and digits; spaces don't count.
String normaliseCode(String raw) =>
    raw.replaceAll(RegExp(r'\s'), '').toUpperCase();

class FollowApi {
  const FollowApi();

  SupabaseClient get _sb => SupaFlow.client;

  Future<List<FollowedClub>> myClubs() async {
    final r = await _sb.rpc('get_my_followed_clubs');
    return [
      if (r is List)
        for (final x in r)
          if (x is Map) FollowedClub.fromJson(x)
    ];
  }

  Future<CodeLookup> lookup(String code) async => CodeLookup.fromJson(
      await _sb.rpc('lookup_join_code', params: {'p_code': code}));

  /// The club followed, or null when the code isn't an open club's.
  Future<FollowedClub?> follow(String code) async {
    final r = await _sb.rpc('follow_club_by_code', params: {'p_code': code});
    if (r is Map && r['ok'] == true && r['club'] is Map) {
      return FollowedClub.fromJson(r['club']);
    }
    return null;
  }

  Future<void> unfollow(int clubId) =>
      _sb.rpc('unfollow_club', params: {'p_club_id': clubId});
}
