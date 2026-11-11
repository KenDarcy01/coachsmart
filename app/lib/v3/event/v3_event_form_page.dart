// v3 create / edit event form. One page for both: `eventId` null creates.
// Design agreed with Ken 2026-11-09 (app-v3/event-create/design.md):
// grouped cards Team / What / When / Where / Details / Options, proper
// date and time pickers, Repeat as a sheet, pinned Create button.
// Saving uses the same database calls as the FlutterFlow pages
// (create_recurring_events RPC; events table update), so the live app
// sees the events exactly as before.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/upload_data.dart';
import '../v3_theme.dart';
import 'v3_series_scope.dart';

const int kMatchTypeId = 2;

/// Repeat choice: 0 none, 1 weekly, 2 fortnightly (create_recurring_events).
class RepeatRule {
  const RepeatRule(this.type, this.weeks);
  final int type;
  final int weeks;
  static const none = RepeatRule(0, 0);

  /// Sessions this rule makes, as the RPC counts them.
  int sessions() => type == 0 ? 1 : (type == 1 ? weeks : weeks ~/ 2);

  String label() => type == 0
      ? "Doesn't repeat"
      : type == 1
          ? 'Every week · $weeks weeks'
          : 'Every second week · $weeks weeks';
}

/// Plain-English line under the repeat stepper.
String repeatSummary(RepeatRule r, DateTime? start, String typeName) {
  final n = r.sessions();
  if (r.type == 0 || n <= 0) return 'One event only.';
  final what = typeName.isEmpty ? 'event' : typeName.toLowerCase();
  final plural = n == 1
      ? what
      : what == 'match'
          ? 'matches'
          : what == 'training'
              ? 'training sessions'
              : '${what}s';
  if (start == null) return '$n $plural, each with its own replies.';
  final last = start.add(Duration(days: 7 * (r.type == 1 ? 1 : 2) * (n - 1)));
  final f = DateFormat('EEE d MMM');
  return '$n $plural, ${f.format(start)} to ${f.format(last)}, each with its own replies.';
}

/// What the title reads when left empty (mirrors the home RPC's fallback).
String autoTitle(String code, String type, String opposition) {
  final base = [code, type].where((s) => s.isNotEmpty).join(' ');
  if (type.toLowerCase() == 'match' && opposition.trim().isNotEmpty) {
    return '$base v ${opposition.trim()}';
  }
  return base;
}

class V3EventFormPage extends StatefulWidget {
  const V3EventFormPage({super.key, this.eventId});
  final int? eventId;

  static String createRouteName = 'CreateEvent';
  static String createRoutePath = 'createEvent';
  static String editRouteName = 'EditEvent';
  static String editRoutePath = 'editEvent';

  @override
  State<V3EventFormPage> createState() => _V3EventFormPageState();
}

class _V3EventFormPageState extends State<V3EventFormPage> {
  bool get _editing => widget.eventId != null;

  List<CreateTeamsStruct> _teams = [];
  Map<int, bool> _paymentsAllowed = {}; // teamId -> teams.payments (when sent)
  CurrentEventStruct? _current;
  Map<String, dynamic> _currentRaw = {};
  bool _loading = true, _failed = false, _saving = false;

  // form state
  CreateTeamsStruct? _team;
  int _squadId = 0; // 0 = whole team
  int _codeId = 0;
  int _typeId = 0;
  int _audienceId = 0;
  String _homeAway = 'Home';
  DateTime? _date;
  TimeOfDay? _time;
  TimeOfDay? _meet;
  RepeatRule _repeat = RepeatRule.none;
  bool _askReplies = true;
  bool _payment = false;
  final _opposition = TextEditingController();
  final _title = TextEditingController();
  final _venue = TextEditingController();
  final _pin = TextEditingController();
  final _link = TextEditingController();
  final _notes = TextEditingController();
  final _amount = TextEditingController();
  SelectedFile? _photo;
  String _existingImage = '';
  bool _removeImage = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _opposition,
      _title,
      _venue,
      _pin,
      _link,
      _notes,
      _amount
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------ load

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final ApiCallResponse r;
      if (_editing) {
        r = await GetUserEventEditDetailCall.call(
            pUserId: currentUserUid,
            pEventId: widget.eventId,
            supabaseJWTtoken: currentJwtToken);
      } else {
        r = await GetUserEventCreateDetailCall.call(
            pUserId: currentUserUid, supabaseJWTtoken: currentJwtToken);
      }
      if (!r.succeeded || r.jsonBody is! Map) throw Exception('load');
      final body = r.jsonBody as Map;
      final teams = (body['create_teams'] as List? ?? [])
          .map(CreateTeamsStruct.maybeFromMap)
          .whereType<CreateTeamsStruct>()
          .toList()
        ..sort((a, b) => a.teamName.compareTo(b.teamName));
      final pay = <int, bool>{};
      for (final t in (body['create_teams'] as List? ?? [])) {
        if (t is Map && t['payments'] == true)
          pay[(t['team_id'] as num).toInt()] = true;
      }
      _teams = teams;
      _paymentsAllowed = pay;
      if (_editing) {
        _current = CurrentEventStruct.maybeFromMap(body['current_event']);
        if (_current == null) throw Exception('event');
        _currentRaw = Map<String, dynamic>.from(body['current_event'] as Map);
        _fillFromCurrent(_current!);
      } else {
        final def = body['default_team_id'];
        final defId = def == null ? 0 : int.tryParse('$def') ?? 0;
        CreateTeamsStruct? t;
        if (defId > 0) {
          for (final x in teams) {
            if (x.teamId == defId) t = x;
          }
        }
        if (t == null && teams.length == 1) t = teams.first;
        if (t != null) _pickTeam(t);
      }
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _pickTeam(CreateTeamsStruct t) {
    _team = t;
    _squadId = 0;
    _codeId = t.eventCodes.length == 1 ? t.eventCodes.first.id : 0;
    if (!t.eventTypes.any((x) => x.id == _typeId)) {
      _typeId = t.eventTypes.isEmpty ? 0 : t.eventTypes.first.id;
    }
    _audienceId = _defaultAudience(t);
    _payment = false;
  }

  int _defaultAudience(CreateTeamsStruct t) {
    for (final r in t.teamRoles) {
      if (r.name.toLowerCase() == 'player') return r.id;
    }
    return t.teamRoles.isEmpty ? 0 : t.teamRoles.first.id;
  }

  void _fillFromCurrent(CurrentEventStruct e) {
    for (final t in _teams) {
      if (t.teamId == e.teamId) _team = t;
    }
    _team ??= _teams.isEmpty ? null : _teams.first;
    _squadId = e.squadId;
    _codeId = e.eventCodeId;
    _typeId = e.eventTypeId;
    _audienceId = e.audienceId;
    _homeAway = e.homeAway.isEmpty ? 'Home' : e.homeAway;
    final dt = DateTime.tryParse(e.eventDateTime);
    if (dt != null) {
      _date = DateTime(dt.year, dt.month, dt.day);
      _time = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
    _meet = parseMeetTime(e.meetTime);
    _askReplies = e.requestAttendance;
    _opposition.text = e.opposition;
    _title.text = e.eventTitle;
    _venue.text = e.locationName;
    _pin.text = e.locationPin;
    _link.text = e.eventLink;
    _notes.text = e.eventDetails;
    _existingImage = e.eventImage;
    final raw = _currentRaw;
    _payment = raw['payment_required'] == true;
    final amt = raw['payment_amount'];
    // payment_amount is stored in cents; the form shows euro.
    if (amt is num && amt > 0) _amount.text = centsToEuro(amt.toInt());
  }

  int get _seriesLater => (_currentRaw['series_later'] as num?)?.toInt() ?? 0;
  bool get _inSeries => _currentRaw['series_id'] != null && _seriesLater > 1;

  // ---------------------------------------------------------------- derived

  bool get _isMatch => _typeId == kMatchTypeId;
  String get _typeName {
    for (final t in _team?.eventTypes ?? <EventTypesStruct>[]) {
      if (t.id == _typeId) return t.name;
    }
    return '';
  }

  String get _codeName {
    for (final c in _team?.eventCodes ?? <EventCodesStruct>[]) {
      if (c.id == _codeId) return c.name;
    }
    return '';
  }

  DateTime? get _start {
    if (_date == null || _time == null) return null;
    return DateTime(
        _date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
  }

  bool get _paymentsOn =>
      _team != null && (_paymentsAllowed[_team!.teamId] ?? false);

  // ------------------------------------------------------------------ save

  String? _validate() {
    if (_team == null) return 'Pick a team.';
    if (_typeId == 0) return 'Pick an event type.';
    if (_codeId == 0) return 'Pick a code.';
    if (_audienceId == 0) return 'Pick who the event is for.';
    if (_date == null) return 'Pick a date.';
    if (_time == null) return 'Pick a start time.';
    if (!_editing && _venue.text.trim().isEmpty) return 'Enter a venue.';
    if (_payment &&
        _paymentsOn &&
        (euroToCents(_amount.text.trim()) ?? 0) <= 0) {
      return 'Enter the payment amount.';
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      _snack(err, warn: true);
      return;
    }
    setState(() => _saving = true);
    try {
      String? image = _existingImage.isEmpty ? null : _existingImage;
      if (_removeImage) image = null;
      if (_photo != null) {
        image = await uploadSupabaseStorageFile(
            bucketName: 'event_images', selectedFile: _photo!);
      }
      final start = _start!;
      final amount =
          _payment && _paymentsOn ? euroToCents(_amount.text.trim()) : null;
      if (_editing) {
        final wanted = <String, dynamic>{
          'event_title': _title.text.trim(),
          'event_date_time': start.toString(),
          'location_pin': _pin.text.trim(),
          'location_name': _venue.text.trim(),
          'home_away': _isMatch ? _homeAway : null,
          'event_code_id': _codeId,
          'event_type_id': _typeId,
          'audience_id': _audienceId,
          'squad_id': _squadId == 0 ? null : _squadId,
          'request_attendance': _askReplies,
          'event_details': _notes.text.trim(),
          'event_link': _link.text.trim(),
          'meet_time': formatMeetTime(_meet),
          'opposition': _isMatch ? _opposition.text.trim() : null,
          'event_image': image,
          if (_paymentsOn) 'payment_required': _payment && amount != null,
          if (_paymentsOn) 'payment_amount': _payment ? amount : null,
        };
        final changes = changedFields(_currentRaw, wanted);
        if (changes.isEmpty) {
          if (mounted) Navigator.of(context).pop(false);
          return;
        }
        var scope = 'one';
        if (_inSeries) {
          setState(() => _saving = false);
          final pick = await askSeriesScope(context,
              action: 'Save', later: _seriesLater);
          if (pick == null) return;
          scope = pick;
          setState(() => _saving = true);
        }
        final res = await SupaFlow.client.rpc('update_event_series', params: {
          'p_event_id': widget.eventId,
          'p_scope': scope,
          'p_changes': changes,
        });
        final map = res is Map ? res : <String, dynamic>{};
        if (map['success'] != true) {
          _snack((map['message'] ?? 'Could not save the event.').toString(),
              warn: true);
          setState(() => _saving = false);
          return;
        }
        final n = (map['events_updated'] as num?)?.toInt() ?? 1;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(n == 1 ? 'Event saved' : '$n events saved',
                  textAlign: TextAlign.center,
                  style: V3.inter(14, color: V3.bg)),
              backgroundColor: V3.green));
          Navigator.of(context).pop(true);
        }
        return;
      }
      final res = await SupaFlow.client.rpc('create_recurring_events', params: {
        'p_recurring_type': _repeat.type,
        'p_num_weeks': _repeat.type == 0 ? 0 : _repeat.weeks,
        'p_event_title': _title.text.trim(),
        'p_event_date_time': start.toString(),
        'p_event_date_time_2': start.toString(),
        'p_team_id': _team!.teamId,
        'p_created_by': currentUserUid,
        'p_event_type_id': _typeId,
        'p_event_code_id': _codeId,
        'p_audience_id': _audienceId,
        'p_squad_id': _squadId == 0 ? null : _squadId,
        'p_location_name': _venue.text.trim(),
        'p_location_pin': _pin.text.trim(),
        'p_home_away': _isMatch ? _homeAway : null,
        'p_meet_time': formatMeetTime(_meet),
        'p_opposition': _isMatch ? _opposition.text.trim() : null,
        'p_event_details': _notes.text.trim(),
        'p_event_link': _link.text.trim(),
        'p_event_image': image,
        'p_request_attendance': _askReplies,
        'p_notify_admins_changes': true,
        'p_notify_admins_all': false,
        'p_payment_required': _payment && amount != null,
        'p_payment_amount': _payment ? amount : null,
        'p_car_pooling': false,
      });
      final map = res is Map ? res : <String, dynamic>{};
      if (map['success'] != true) {
        _snack((map['message'] ?? 'Could not create the event.').toString(),
            warn: true);
        setState(() => _saving = false);
        return;
      }
      final n = (map['events_created'] as num?)?.toInt() ?? 1;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(n == 1 ? 'Event created' : '$n events created',
                textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
            backgroundColor: V3.green));
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      _snack(
          _editing
              ? 'Could not save the event.'
              : 'Could not create the event.',
          warn: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text, {bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
        backgroundColor: warn ? V3.amber : V3.green));
  }

  // --------------------------------------------------------------- pickers

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final init = _date ?? first;
    final d = await showDatePicker(
      context: context,
      initialDate: init.isBefore(first) && !_editing ? first : init,
      firstDate: _editing && init.isBefore(first) ? init : first,
      lastDate: DateTime(2050),
      builder: _pickerTheme,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(bool meet) async {
    final t = await showTimePicker(
      context: context,
      initialTime: meet
          ? (_meet ?? _time ?? TimeOfDay.now())
          : (_time ?? TimeOfDay.now()),
      builder: (ctx, child) => _pickerTheme(
          ctx,
          MediaQuery(
              data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
              child: child!)),
    );
    if (t == null) return;
    setState(() {
      if (meet) {
        _meet = t;
      } else {
        _time = t;
      }
    });
  }

  Widget _pickerTheme(BuildContext ctx, Widget? child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: V3.green,
              onPrimary: V3.bg,
              surface: V3.card,
              onSurface: V3.text),
          dialogTheme: const DialogThemeData(backgroundColor: V3.card),
        ),
        child: child!,
      );

  Future<void> _pickTeamSheet() async {
    if (_editing || _teams.length < 2) return;
    final t = await showModalBottomSheet<CreateTeamsStruct>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _grab(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Which team?', style: V3.tight(20))),
          ),
          for (final t in _teams)
            ListTile(
              title: Text(t.teamName,
                  style: V3.inter(16, weight: FontWeight.w500)),
              subtitle: Text(t.clubName, style: V3.inter(13, color: V3.muted)),
              trailing: t.teamId == _team?.teamId
                  ? const Icon(Icons.check, color: V3.green)
                  : null,
              onTap: () => Navigator.pop(ctx, t),
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (t != null) setState(() => _pickTeam(t));
  }

  Future<void> _repeatSheet() async {
    var rule = _repeat.type == 0 ? const RepeatRule(0, 8) : _repeat;
    final r = await showModalBottomSheet<RepeatRule>(
      context: context,
      backgroundColor: V3.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Widget opt(String label, int type) => InkWell(
              onTap: () => setSheet(() => rule = RepeatRule(type, rule.weeks)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: V3.line))),
                child: Row(children: [
                  Expanded(
                      child: Text(label,
                          style: V3.inter(16, weight: FontWeight.w500))),
                  Icon(
                      rule.type == type
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: rule.type == type ? V3.green : V3.barGrey),
                ]),
              ),
            );
        Widget step(IconData i, VoidCallback? f) => SizedBox(
              width: 44,
              height: 40,
              child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: f,
                  icon: Icon(i, color: f == null ? V3.barGrey : V3.green)),
            );
        final step2 = rule.type == 2 ? 2 : 1;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _grab(),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Repeat', style: V3.tight(20))),
              const SizedBox(height: 4),
              opt("Doesn't repeat", 0),
              opt('Every week', 1),
              opt('Every second week', 2),
              if (rule.type != 0) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
                  child: Row(children: [
                    Expanded(
                        child: Text('For how many weeks?',
                            style: V3.inter(16, weight: FontWeight.w500))),
                    Container(
                      decoration: BoxDecoration(
                          color: V3.card2,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        step(
                            Icons.remove,
                            rule.weeks - step2 >= step2
                                ? () => setSheet(() => rule =
                                    RepeatRule(rule.type, rule.weeks - step2))
                                : null),
                        SizedBox(
                            width: 36,
                            child: Text('${rule.weeks}',
                                textAlign: TextAlign.center,
                                style: V3.inter(17, weight: FontWeight.w600))),
                        step(
                            Icons.add,
                            rule.weeks + step2 <= 12
                                ? () => setSheet(() => rule =
                                    RepeatRule(rule.type, rule.weeks + step2))
                                : null),
                      ]),
                    ),
                  ]),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(repeatSummary(rule, _start, _typeName),
                      style: V3.inter(14, color: V3.muted, height: 1.35)),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: V3.green,
                      foregroundColor: V3.bg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.pop(ctx, rule),
                  child: Text('Done',
                      style:
                          V3.inter(17, weight: FontWeight.w700, color: V3.bg)),
                ),
              ),
            ]),
          ),
        );
      }),
    );
    if (r != null) {
      setState(() {
        // fortnightly needs an even week count
        final w = r.type == 2 && r.weeks.isOdd ? r.weeks + 1 : r.weeks;
        _repeat =
            r.type == 0 ? RepeatRule.none : RepeatRule(r.type, w.clamp(1, 12));
      });
    }
  }

  Future<void> _pickPhoto() async {
    final files = await selectMediaWithSourceBottomSheet(
      context: context,
      storageFolderPath: 'events',
      allowPhoto: true,
      maxWidth: 1600,
      imageQuality: 85,
      backgroundColor: V3.card,
      textColor: V3.text,
    );
    if (files != null && files.isNotEmpty) {
      setState(() {
        _photo = files.first;
        _removeImage = false;
      });
    }
  }

  Widget _grab() => Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: const Color(0xFF444A56),
          borderRadius: BorderRadius.circular(3)));

  // ----------------------------------------------------------------- build

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
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 40),
            onPressed: () => Navigator.of(context).maybePop()),
        title: Text(_editing ? 'Edit event' : 'New event', style: V3.tight(20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: V3.green))
          : _failed
              ? Center(
                  child: Text('Could not load the form.',
                      style: V3.inter(15, color: V3.muted)))
              : _teams.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                            'You need to be an admin on a team to create events.',
                            textAlign: TextAlign.center,
                            style:
                                V3.inter(15.5, color: V3.muted, height: 1.4)),
                      ),
                    )
                  : Stack(children: [
                      Positioned.fill(child: _form()),
                      if (_saving)
                        const Positioned.fill(
                            child: ColoredBox(
                                color: Color(0x6614181B),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: V3.green)))),
                    ]),
      bottomNavigationBar: _loading || _failed || _teams.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: V3.green,
                        foregroundColor: V3.bg,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check, size: 22),
                    label: Text(_editing ? 'Save changes' : 'Create event',
                        style: V3.inter(17,
                            weight: FontWeight.w700, color: V3.bg)),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _form() {
    final t = _team;
    final squads = [...?t?.squads]
      ..sort((a, b) => a.squadListSeq.compareTo(b.squadListSeq));
    final codes = t?.eventCodes ?? const <EventCodesStruct>[];
    final types = t?.eventTypes ?? const <EventTypesStruct>[];
    final roles = t?.teamRoles ?? const <TeamRolesStruct>[];
    final showSquads = squads.length >= 2;
    final showCodes = codes.length > 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _sec('Team'),
        _card([
          _row(
            'Team',
            t == null
                ? Text('Pick a team',
                    style: V3.inter(15.5, color: const Color(0xFF6F737C)))
                : Text(t.teamName, style: V3.inter(15.5)),
            onTap: !_editing && _teams.length > 1 ? _pickTeamSheet : null,
          ),
          if (t != null && showSquads)
            _row(
                'Squad',
                _chips([
                  _Chip(
                      'All', _squadId == 0, () => setState(() => _squadId = 0)),
                  for (final s in squads)
                    _Chip(s.name, _squadId == s.id,
                        () => setState(() => _squadId = s.id)),
                ])),
          if (t != null && showCodes)
            _row(
                'Code',
                _chips([
                  for (final c in codes)
                    _Chip(c.name, _codeId == c.id,
                        () => setState(() => _codeId = c.id)),
                ])),
        ]),
        if (t != null) ...[
          _sec('What'),
          _types(types),
          if (_isMatch)
            _card([
              _row(
                  'Opposition',
                  _text(_opposition, 'Who are we playing?',
                      cap: TextCapitalization.words)),
              _row(
                  'Home/Away',
                  _segment(['Home', 'Away'], _homeAway,
                      (v) => setState(() => _homeAway = v))),
            ]),
          _sec('When'),
          _card([
            _row(
                'Date',
                _value(
                    _date == null
                        ? null
                        : DateFormat('EEE d MMM yyyy').format(_date!),
                    'Pick a date'),
                onTap: _pickDate),
            _row(
                'Starts',
                _value(_time == null ? null : _fmt(_time!), 'Pick a time',
                    green: true),
                onTap: () => _pickTime(false)),
            _row('Meet at',
                _value(_meet == null ? null : _fmt(_meet!), 'Same as start'),
                onTap: () => _pickTime(true),
                trailing: _meet != null
                    ? IconButton(
                        icon:
                            const Icon(Icons.close, color: V3.muted, size: 20),
                        onPressed: () => setState(() => _meet = null))
                    : null),
            if (!_editing)
              _row('Repeat', Text(_repeat.label(), style: V3.inter(15.5)),
                  onTap: _repeatSheet),
          ]),
          _sec('Where'),
          _card([
            _row(
                'Venue',
                _text(_venue, 'e.g. Seafield, Pitch 2',
                    cap: TextCapitalization.words)),
            _row(
                'Map link',
                _text(_pin, 'Paste a Google Maps link',
                    keyboard: TextInputType.url)),
          ]),
          _sec('Details'),
          _field(
              'Title (optional)',
              _text(_title, autoTitle(_codeName, _typeName, _opposition.text),
                  cap: TextCapitalization.sentences, big: true)),
          if (_title.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
              child: Text(
                  _isMatch
                      ? 'Left empty, the title is made from the code, type and opposition.'
                      : 'Left empty, the title is made from the code and type.',
                  style: V3.inter(13, color: V3.muted)),
            ),
          _field(
              'Notes (optional)',
              _text(_notes, 'Jerseys, water, what to bring…',
                  cap: TextCapitalization.sentences, lines: 4, big: true)),
          _card([
            _row(
              '',
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: V3.card2, borderRadius: BorderRadius.circular(12)),
                  child: _photo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_photo!.bytes, fit: BoxFit.cover))
                      : _existingImage.isNotEmpty && !_removeImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(_existingImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.image_outlined,
                                      color: V3.muted)))
                          : const Icon(Icons.image_outlined,
                              color: V3.muted, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _photo != null
                                ? 'Photo added'
                                : _existingImage.isNotEmpty && !_removeImage
                                    ? 'Photo kept'
                                    : 'Add a photo',
                            style: V3.inter(15.5, weight: FontWeight.w500)),
                        Text('Optional, shows on the event page',
                            style: V3.inter(13, color: V3.muted)),
                      ]),
                ),
                if (_photo != null ||
                    (_existingImage.isNotEmpty && !_removeImage))
                  IconButton(
                      icon: const Icon(Icons.close, color: V3.muted, size: 20),
                      onPressed: () => setState(() {
                            _photo = null;
                            _removeImage = true;
                          })),
              ]),
              onTap: _pickPhoto,
              noKey: true,
            ),
          ]),
          _sec('Options'),
          _card([
            _row('Ask for replies',
                Text('Attending / Decline buttons', style: V3.inter(15.5)),
                trailing: _switch(
                    _askReplies, (v) => setState(() => _askReplies = v))),
            if (_paymentsOn)
              _row(
                  'Payment',
                  Text(_payment ? 'Players pay to attend' : 'Free',
                      style: V3.inter(15.5)),
                  trailing:
                      _switch(_payment, (v) => setState(() => _payment = v))),
            if (_paymentsOn && _payment)
              _row(
                  'Amount',
                  _text(_amount, '0',
                      keyboard:
                          const TextInputType.numberWithOptions(decimal: true),
                      prefix: '€ ',
                      formatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                      ])),
            _row(
                'Link',
                _text(_link, 'Fixture or info page',
                    keyboard: TextInputType.url)),
          ]),
          _card([
            _row(
                'Visible to',
                _chips([
                  for (final r in roles)
                    _Chip(
                        r.namePlural.isEmpty ? r.name : r.namePlural,
                        _audienceId == r.id,
                        () => setState(() => _audienceId = r.id)),
                ])),
          ]),
        ],
      ],
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _sec(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 0, 8),
        child: Text(s.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700, color: V3.green, letterSpacing: .8)),
      );

  Widget _card(List<Widget> rows) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1) const Divider(height: 1, color: V3.line),
          ],
        ]),
      );

  Widget _row(String key, Widget value,
      {VoidCallback? onTap, Widget? trailing, bool noKey = false}) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 30),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (!noKey)
            SizedBox(
                width: 96,
                child: Text(key, style: V3.inter(15.5, color: V3.muted))),
          Expanded(child: value),
          if (trailing != null) trailing,
          if (onTap != null && trailing == null)
            const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.chevron_right, color: V3.muted, size: 22)),
        ]),
      ),
    );
    return onTap == null
        ? child
        : InkWell(
            onTap: onTap, borderRadius: BorderRadius.circular(8), child: child);
  }

  Widget _value(String? v, String placeholder, {bool green = false}) => Text(
        v ?? placeholder,
        style: v == null
            ? V3.inter(15.5, color: const Color(0xFF6F737C))
            : V3.inter(15.5,
                weight: green ? FontWeight.w600 : FontWeight.w400,
                color: green ? V3.green : V3.text),
      );

  Widget _text(TextEditingController c, String hint,
      {TextInputType? keyboard,
      TextCapitalization cap = TextCapitalization.none,
      int lines = 1,
      bool big = false,
      String? prefix,
      List<TextInputFormatter>? formatters}) {
    return TextField(
      controller: c,
      keyboardType: lines > 1 ? TextInputType.multiline : keyboard,
      textCapitalization: cap,
      minLines: lines > 1 ? lines : 1,
      maxLines: lines > 1 ? null : 1,
      inputFormatters: formatters,
      onChanged: (_) => setState(() {}),
      style: V3.inter(big ? 16 : 15.5),
      cursorColor: V3.green,
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        prefixText: prefix,
        prefixStyle: V3.inter(big ? 16 : 15.5),
        hintText: hint,
        hintStyle: V3.inter(big ? 16 : 15.5, color: const Color(0xFF6F737C)),
      ),
    );
  }

  Widget _field(String label, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: V3.inter(12,
                  weight: FontWeight.w500, color: V3.muted, letterSpacing: .5)),
          const SizedBox(height: 6),
          child,
        ]),
      );

  Widget _chips(List<_Chip> items) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in items)
            GestureDetector(
              onTap: c.onTap,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: c.on ? V3.green : V3.card2,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(c.label,
                    style: V3.inter(13.5,
                        weight: FontWeight.w600,
                        color: c.on ? V3.bg : V3.text)),
              ),
            ),
        ],
      );

  Widget _types(List<EventTypesStruct> types) {
    IconData icon(String name) {
      final n = name.toLowerCase();
      if (n.contains('match')) return Icons.sports_soccer;
      if (n.contains('train')) return Icons.directions_run;
      if (n.contains('blitz')) return Icons.emoji_events_outlined;
      if (n.contains('meet')) return Icons.groups_outlined;
      if (n.contains('social')) return Icons.celebration_outlined;
      return Icons.star_outline;
    }

    final tiles = [
      for (final t in types)
        GestureDetector(
          onTap: () => setState(() => _typeId = t.id),
          child: Container(
            width: 108,
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
            decoration: BoxDecoration(
                color: V3.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _typeId == t.id ? V3.green : Colors.transparent,
                    width: 1.5)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon(t.name),
                  size: 24, color: _typeId == t.id ? V3.green : V3.muted),
              const SizedBox(height: 6),
              Text(t.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V3.inter(13,
                      weight: FontWeight.w600,
                      color: _typeId == t.id ? V3.green : V3.text)),
            ]),
          ),
        ),
    ];
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => tiles[i],
      ),
    );
  }

  Widget _segment(List<String> opts, String on, ValueChanged<String> pick) =>
      Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: V3.card2, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          for (final o in opts)
            Expanded(
              child: GestureDetector(
                onTap: () => pick(o),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: o == on ? V3.green : Colors.transparent,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(o,
                      style: V3.inter(13.5,
                          weight: FontWeight.w600,
                          color: o == on ? V3.bg : V3.muted)),
                ),
              ),
            ),
        ]),
      );

  Widget _switch(bool on, ValueChanged<bool> f) => Switch(
        value: on,
        activeThumbColor: Colors.white,
        activeTrackColor: V3.green,
        inactiveTrackColor: const Color(0xFF3A3F4A),
        onChanged: f,
      );
}

class _Chip {
  const _Chip(this.label, this.on, this.onTap);
  final String label;
  final bool on;
  final VoidCallback onTap;
}

/// meet_time is free text in the database ("09:30", "0930", "9.30 sharp").
/// Read what we can as a time; anything else is shown as typed.
TimeOfDay? parseMeetTime(String s) {
  final m = RegExp(r'^\s*(\d{1,2})[:.hH]?(\d{2})\s*$').firstMatch(s);
  if (m == null) return null;
  final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
  if (h > 23 || mi > 59) return null;
  return TimeOfDay(hour: h, minute: mi);
}

String? formatMeetTime(TimeOfDay? t) => t == null
    ? null
    : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "12" or "12.50" → cents; null when not a number.
int? euroToCents(String s) {
  final t = s.trim().replaceAll(',', '.').replaceAll('€', '');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null) return null;
  return (v * 100).round();
}

String centsToEuro(int cents) =>
    cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2);

/// The fields of [wanted] that differ from what the event holds now.
/// Empty strings and nulls count as the same so untouched blanks are not
/// sent; event_date_time compares on the minute.
Map<String, dynamic> changedFields(
    Map<String, dynamic> current, Map<String, dynamic> wanted) {
  String norm(String key, dynamic v) {
    if (v == null) return '';
    if (key == 'event_date_time') {
      final d = DateTime.tryParse('$v');
      return d == null ? '$v' : d.toIso8601String().substring(0, 16);
    }
    return '$v';
  }

  final out = <String, dynamic>{};
  for (final e in wanted.entries) {
    if (norm(e.key, current[e.key]) != norm(e.key, e.value)) {
      out[e.key] = e.value;
    }
  }
  return out;
}
