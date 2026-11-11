// v3 Join Team: a native copy of webviews/join-team.html (the JoinTeamNew
// route). Same steps, calls and wording as the page:
//   who → (their name | member code) → team joining code → result
//   who → set up a new team → request received
// Calls: users (own name), get_team_by_code (live preview),
// create_new_member_by_code, request_member_access, lookup_member_by_code
// and the request-new-team edge function.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../v3_theme.dart';
import 'v3_join_team_api.dart';
import 'v3_join_team_models.dart';

class V3JoinTeamPage extends StatefulWidget {
  const V3JoinTeamPage({super.key, this.api});

  /// Widget tests pass a fake here; the app leaves it null.
  @visibleForTesting
  final JoinTeamApi? api;

  @override
  State<V3JoinTeamPage> createState() => _V3JoinTeamPageState();
}

enum _Lookup { none, looking, found, unknown }

class _V3JoinTeamPageState extends State<V3JoinTeamPage> {
  late final JoinTeamApi _api = widget.api ?? const JoinTeamApi();

  bool _loading = true;
  String? _loadError;
  String _myFirst = '', _myLast = '', _myEmail = '';

  final List<JoinStep> _stack = [JoinStep.who];
  JoinStep get _step => _stack.last;

  Registering _reg = const Registering('', '');
  FoundMember? _found;
  String _joiningCode = '';
  int _pendingCount = 0;
  bool _another = false; // "Register another person?" heading on who

  // Live team lookup on the code screen.
  Timer? _debounce;
  _Lookup _lookup = _Lookup.none;
  String? _resolvedTeam;

  // What the result screens show.
  String _resultName = '', _resultTeam = '', _sentAction = '', _sentDetail = '';
  String _sentEmail = '';

  bool _busy = false;
  final Map<JoinStep, String> _errors = {};

  final _first = TextEditingController();
  final _last = TextEditingController();
  final _memberCode = TextEditingController();
  final _code = TextEditingController();
  final _reqName = TextEditingController();
  final _reqEmail = TextEditingController();
  final _reqClub = TextEditingController();
  final _reqNotes = TextEditingController();
  String _county = '';

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [
      _first,
      _last,
      _memberCode,
      _code,
      _reqName,
      _reqEmail,
      _reqClub,
      _reqNotes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      final me = await _api.me();
      if (!mounted) return;
      setState(() {
        _myFirst = me.firstName;
        _myLast = me.lastName;
        _myEmail = me.email;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Your details could not be loaded. Please try again.';
      });
    }
  }

  // ------------------------------------------------------------ navigation

  void _go(JoinStep s) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _errors.remove(s);
      if (_stack.last != s) _stack.add(s);
    });
  }

  void _close() => Navigator.of(context).maybePop();

  void _back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_step == JoinStep.found) return _denyExisting();
    if (isEndStep(_step) || _stack.length <= 1) return _close();
    setState(() => _stack.removeLast());
  }

  // ------------------------------------------------------------------ who

  void _selectMyself() {
    _reg = Registering(_myFirst, _myLast, isMyself: true);
    _go(JoinStep.code);
  }

  void _selectSomeoneElse() {
    _reg = const Registering('', '');
    _go(JoinStep.theirName);
  }

  void _selectByCode() {
    _memberCode.clear();
    _go(JoinStep.memberCode);
  }

  void _selectNewTeam() {
    _reqName.text = '$_myFirst $_myLast'.trim();
    _reqEmail.text = _myEmail;
    _reqClub.clear();
    _reqNotes.clear();
    _county = '';
    _go(JoinStep.newTeam);
  }

  // ------------------------------------------------------------ their name

  void _confirmTheirName() {
    final f = _first.text.trim(), l = _last.text.trim();
    if (f.isEmpty || l.isEmpty) {
      setState(() => _errors[JoinStep.theirName] =
          'Please enter their first and last name.');
      return;
    }
    _reg = Registering(f, l);
    _go(JoinStep.code);
  }

  // ------------------------------------------------------- team code lookup

  void _onCodeChanged(String raw) {
    _debounce?.cancel();
    final code = cleanCode(raw);
    setState(() {
      _resolvedTeam = null;
      _lookup = shouldLookUp(code) ? _Lookup.looking : _Lookup.none;
    });
    if (!shouldLookUp(code)) return;
    _debounce =
        Timer(const Duration(milliseconds: 500), () => _lookupCode(code));
  }

  Future<void> _lookupCode(String code) async {
    String? team;
    try {
      team = teamNameFromLookup(await _api.teamByCode(code));
    } catch (_) {
      team = null;
    }
    // Ignore an answer for a code that has since been changed.
    if (!mounted || cleanCode(_code.text) != code) return;
    setState(() {
      _resolvedTeam = team;
      _lookup = team != null ? _Lookup.found : _Lookup.unknown;
    });
  }

  void _resetCode() {
    _debounce?.cancel();
    _code.clear();
    _errors.remove(JoinStep.code);
    _resolvedTeam = null;
    _lookup = _Lookup.none;
  }

  Future<void> _submitCode() async {
    final code = cleanCode(_code.text);
    if (code.isEmpty) {
      setState(
          () => _errors[JoinStep.code] = 'Please enter the team joining code.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _errors.remove(JoinStep.code);
    });
    _joiningCode = code;
    dynamic data;
    try {
      data = await _api.createMemberByCode(
          firstName: _reg.firstName, lastName: _reg.lastName, code: code);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errors[JoinStep.code] = kTryAgain;
      });
      return;
    }
    if (!mounted) return;
    final r = JoinResult.fromRpc(data,
        resolvedTeam: _resolvedTeam, memberName: _reg.name);
    setState(() => _busy = false);
    switch (r.outcome) {
      case JoinOutcome.error:
      case JoinOutcome.alreadyMember:
      case JoinOutcome.unknown:
        setState(() => _errors[JoinStep.code] = r.message);
      case JoinOutcome.duplicate:
        _found = FoundMember(r.memberId, _reg.name, r.teamName);
        _resetCode();
        _go(JoinStep.found);
      case JoinOutcome.alreadyPending:
        _resultName = _reg.name;
        _resultTeam = r.teamName;
        _resetCode();
        _go(JoinStep.alreadyPending);
      case JoinOutcome.pendingOther:
        _resultName = _reg.name;
        _resultTeam = r.teamName;
        _resetCode();
        _go(JoinStep.pendingOther);
      case JoinOutcome.pending:
        _pendingCount++;
        _resultName = _reg.name;
        _resultTeam = r.teamName;
        _sentAction = 'has been submitted to join ';
        _sentDetail =
            "A team admin will confirm the membership shortly. You'll receive a notification when it's approved.";
        _resetCode();
        _go(JoinStep.sent);
    }
  }

  // --------------------------------------------------------- found member

  Future<void> _confirmExisting() async {
    final f = _found;
    if (f?.memberId == null) {
      setState(() => _errors[JoinStep.found] =
          'Please contact your team admin to link your account.');
      return;
    }
    setState(() {
      _busy = true;
      _errors.remove(JoinStep.found);
    });
    String? err;
    try {
      err = accessRequestError(
          await _api.requestMemberAccess(f!.memberId!, _joiningCode));
    } catch (_) {
      err = kTryAgain;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _errors[JoinStep.found] = err!);
      return;
    }
    _pendingCount++;
    _resultName = f!.name;
    _resultTeam = f.teamName;
    _sentAction =
        'is already on the roster. Your request to link your account has been sent to the admin of ';
    _sentDetail =
        "Once confirmed by the admin, you'll be linked to their profile. You'll receive a notification when it's approved.";
    _go(JoinStep.sent);
  }

  /// "No — enter a different name": back to the member code screen when the
  /// member came from there, else to who (myself) or a cleared name form.
  void _denyExisting() {
    setState(() {
      _found = null;
      _errors.remove(JoinStep.found);
      _stack.removeLast();
      if (_stack.isNotEmpty && _stack.last == JoinStep.memberCode) return;
      final target = _reg.isMyself ? JoinStep.who : JoinStep.theirName;
      while (_stack.length > 1 && _stack.last != target) {
        _stack.removeLast();
      }
      if (_stack.last != target) _stack.add(target);
      if (target == JoinStep.theirName) {
        _first.clear();
        _last.clear();
        _errors.remove(JoinStep.theirName);
      }
    });
  }

  // ---------------------------------------------------------- member code

  Future<void> _lookupByMemberCode() async {
    final mc = _memberCode.text.trim();
    if (mc.isEmpty) {
      setState(
          () => _errors[JoinStep.memberCode] = 'Please enter the member code.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _errors.remove(JoinStep.memberCode);
    });
    MemberLookup r;
    try {
      r = MemberLookup.fromRpc(await _api.lookupMemberByCode(mc));
    } catch (_) {
      r = MemberLookup.fromRpc(null);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.found) {
      setState(() => _errors[JoinStep.memberCode] = r.error!);
      return;
    }
    _joiningCode = r.teamCode;
    _reg = Registering(r.firstName, r.lastName);
    _found = FoundMember(r.memberId, r.name, r.teamName);
    _go(JoinStep.found);
  }

  // ------------------------------------------------------------ after send

  void _addAnother() {
    _reg = const Registering('', '');
    _found = null;
    _first.clear();
    _last.clear();
    _resetCode();
    setState(() {
      _errors.clear();
      _another = true;
      _stack
        ..clear()
        ..add(JoinStep.who);
    });
  }

  void _finish() {
    setState(() {
      _stack
        ..clear()
        ..add(JoinStep.done);
    });
  }

  // -------------------------------------------------------- new team form

  Future<void> _submitTeamRequest() async {
    final err = newTeamError(club: _reqClub.text, county: _county);
    if (err != null) {
      setState(() => _errors[JoinStep.newTeam] = err);
      return;
    }
    final name = _reqName.text.trim().isNotEmpty
        ? _reqName.text.trim()
        : '$_myFirst $_myLast'.trim();
    final email =
        _reqEmail.text.trim().isNotEmpty ? _reqEmail.text.trim() : _myEmail;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _errors.remove(JoinStep.newTeam);
    });
    try {
      await _api.requestNewTeam(newTeamBody(
          name: name,
          email: email,
          club: _reqClub.text,
          county: _county,
          notes: _reqNotes.text));
      if (!mounted) return;
      _sentEmail = email.isNotEmpty ? email : 'your email address';
      setState(() => _busy = false);
      _go(JoinStep.newTeamSent);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errors[JoinStep.newTeam] = e is JoinTeamError
            ? e.message
            : 'Could not send request — please try again.';
      });
    }
  }

  Future<void> _pickCounty() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: V3.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .75),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text('County', style: V3.tight(18)),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final c in kCounties)
                  InkWell(
                    onTap: () => Navigator.of(ctx).pop(c),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.centerLeft,
                      child: Row(children: [
                        Expanded(child: Text(c, style: V3.inter(17))),
                        if (c == _county)
                          const Icon(Icons.check, color: V3.green),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (picked != null) setState(() => _county = picked);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          (_stack.length <= 1 || isEndStep(_step)) && _step != JoinStep.found,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: V3.bg,
          appBar: AppBar(
            backgroundColor: V3.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.chevron_left, color: V3.green, size: 32),
                onPressed: _back),
            title: Text(
                _step == JoinStep.newTeam || _step == JoinStep.newTeamSent
                    ? 'New Team Request'
                    : 'Join Team',
                style: V3.tight(17)),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator(color: V3.green))
              : _loadError != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(_loadError!,
                              textAlign: TextAlign.center,
                              style: V3.inter(16, color: V3.muted))))
                  : SafeArea(
                      top: false,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: ListView(
                          key: ValueKey(_step),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          children: _screen(),
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  List<Widget> _screen() => switch (_step) {
        JoinStep.who => _who(),
        JoinStep.theirName => _theirName(),
        JoinStep.memberCode => _memberCodeScreen(),
        JoinStep.code => _codeScreen(),
        JoinStep.found => _foundScreen(),
        JoinStep.alreadyPending => _alreadyPending(),
        JoinStep.pendingOther => _pendingOther(),
        JoinStep.sent => _sent(),
        JoinStep.newTeam => _newTeam(),
        JoinStep.newTeamSent => _newTeamSent(),
        JoinStep.done => _done(),
      };

  List<Widget> _who() => [
        const _Progress(step: 1),
        _StepLabel('What would you like to do?'),
        _Title(_another ? 'Register another person?' : 'Join or set up a team'),
        _Sub(_another
            ? "Choose how you'd like to continue."
            : 'Choose one to continue.'),
        _Choice(
            icon: Icons.directions_run,
            label: 'Join as myself',
            sub: 'I play or coach on this team',
            onTap: _selectMyself),
        _Choice(
            icon: Icons.family_restroom,
            label: 'Register someone else',
            sub: 'My child or another family member',
            onTap: _selectSomeoneElse),
        _Choice(
            icon: Icons.stadium_outlined,
            label: 'Set up a new team',
            sub: 'Request a new team setup on CoachSmart',
            highlight: true,
            onTap: _selectNewTeam),
      ];

  List<Widget> _theirName() => [
        const _Progress(step: 2),
        _StepLabel('Step 2 of 2'),
        _Title('What is their name?'),
        _Sub(
            'Enter their name exactly as it appears, or will appear, on the team roster.'),
        _Field(
            label: 'First Name',
            controller: _first,
            hint: 'First name',
            caps: TextCapitalization.words,
            action: TextInputAction.next),
        _Field(
            label: 'Last Name',
            controller: _last,
            hint: 'Last name',
            caps: TextCapitalization.words,
            onSubmit: (_) => _confirmTheirName()),
        _Primary('Continue', onTap: _confirmTheirName),
        _Error(_errors[JoinStep.theirName]),
        const SizedBox(height: 20),
        Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Have their member code?', style: V3.inter(16)),
              TextButton(
                  onPressed: _selectByCode,
                  style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: V3.green),
                  child: Text('Use it instead',
                      style: V3.inter(16,
                          weight: FontWeight.w600, color: V3.green))),
            ]),
      ];

  List<Widget> _memberCodeScreen() => [
        const _Progress(step: 2),
        _StepLabel('Step 2 of 2'),
        _Title('Use their member code'),
        _Sub(
            'Another parent or team admin can share this unique code with you. Enter it below to find the member.'),
        _Field(
            label: 'Member Code',
            controller: _memberCode,
            hint: 'e.g. MB12345',
            upper: true,
            maxLength: 20,
            onSubmit: (_) => _lookupByMemberCode()),
        _Primary(_busy ? 'Looking up…' : 'Find Member',
            busy: _busy, onTap: _lookupByMemberCode),
        _Error(_errors[JoinStep.memberCode]),
      ];

  List<Widget> _codeScreen() => [
        const _Progress(step: 2),
        _StepLabel('Step 2 of 2'),
        _Title('Enter the team joining code'),
        _Sub('Your team admin will have shared this with you.'),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: V3.card, borderRadius: BorderRadius.circular(14)),
          child: Text.rich(
              TextSpan(style: V3.inter(16, color: V3.muted), children: [
            const TextSpan(text: 'Joining as '),
            TextSpan(
                text: _reg.name, style: V3.inter(16, weight: FontWeight.w700)),
          ])),
        ),
        TextField(
          controller: _code,
          autofocus: true,
          textAlign: TextAlign.center,
          maxLength: 20,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [_UpperCase()],
          onChanged: _onCodeChanged,
          onSubmitted: (_) => _submitCode(),
          cursorColor: V3.green,
          style:
              V3.tight(26, weight: FontWeight.w700).copyWith(letterSpacing: 4),
          decoration: _decoration('Team code').copyWith(counterText: ''),
        ),
        _preview(),
        const SizedBox(height: 8),
        _Primary(_busy ? 'Checking…' : requestButtonLabel(_resolvedTeam),
            busy: _busy, onTap: _submitCode),
        _Error(_errors[JoinStep.code]),
      ];

  Widget _preview() {
    if (_lookup == _Lookup.none) return const SizedBox(height: 12);
    final (IconData? icon, String text, Color color) = switch (_lookup) {
      _Lookup.looking => (null, 'Looking up code…', V3.muted),
      _Lookup.found => (Icons.check, _resolvedTeam ?? '', V3.green),
      _ => (Icons.error_outline, 'Code not recognised', V3.amberText),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
        ] else ...[
          const SizedBox(
              width: 16,
              height: 16,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: V3.muted)),
          const SizedBox(width: 10),
        ],
        Flexible(
            child: Text(text,
                textAlign: TextAlign.center,
                style: V3.inter(16, weight: FontWeight.w600, color: color))),
      ]),
    );
  }

  List<Widget> _foundScreen() {
    final f = _found;
    return [
      const _Hero(Icons.person_search, amber: true),
      _Title('Already on the roster', centre: true),
      _Chip(f?.name ?? ''),
      _CentreText.rich([
        const TextSpan(text: 'is already a confirmed member of '),
        _strong(f?.teamName ?? ''),
        const TextSpan(text: '.'),
      ]),
      _CentreText('Is this the person you are registering?'),
      _CentreText(
          "If yes, we'll send a request to the team admin to link your account to their profile. You'll be notified once it's approved.",
          small: true),
      const SizedBox(height: 20),
      _Primary(_busy ? 'Sending…' : 'Yes — request access to their profile',
          busy: _busy, onTap: _confirmExisting),
      _Secondary('No — enter a different name', onTap: _denyExisting),
      _Error(_errors[JoinStep.found]),
    ];
  }

  List<Widget> _alreadyPending() => [
        const _Hero(Icons.schedule, amber: true),
        _Title('Already submitted', centre: true),
        _CentreText("You've already sent a request for"),
        _Chip(_resultName),
        _CentreText.rich([
          const TextSpan(text: 'to join '),
          _strong(_resultTeam),
          const TextSpan(text: '.'),
        ]),
        _CentreText(
            "It's waiting for admin approval. You'll receive a notification once it's confirmed.",
            small: true),
        ..._afterSend(),
      ];

  List<Widget> _pendingOther() => [
        const _Hero(Icons.schedule, amber: true),
        _Title('Already submitted by someone else', centre: true),
        _CentreText('Another parent has already sent a join request for'),
        _Chip(_resultName),
        _CentreText.rich([
          const TextSpan(text: 'to '),
          _strong(_resultTeam),
          const TextSpan(text: ", and it's waiting for admin approval."),
        ]),
        _CentreText(
            "Once the admin confirms the membership, come back here and enter the same name and code — you'll be offered the option to link your account to their profile.",
            small: true),
        ..._afterSend(),
      ];

  List<Widget> _sent() => [
        const _Hero(Icons.check),
        _Title('Request sent!', centre: true),
        _Chip(_resultName),
        _CentreText.rich([
          TextSpan(text: _sentAction),
          _strong(_resultTeam),
          const TextSpan(text: '.'),
        ]),
        _CentreText(_sentDetail, small: true),
        ..._afterSend(),
      ];

  List<Widget> _afterSend() => [
        const SizedBox(height: 24),
        _Primary('Add another person', onTap: _addAnother),
        _Secondary("I'm done for now", onTap: _finish),
      ];

  List<Widget> _newTeam() => [
        _StepLabel('New Team Request'),
        _Title('Set up your team on CoachSmart'),
        _Sub(
            'Fill in the details below and our team will be in touch within 24 hours to get everything set up for you.'),
        _Field(
            label: 'Your Name',
            controller: _reqName,
            hint: 'e.g. Joe Bloggs',
            caps: TextCapitalization.words,
            action: TextInputAction.next),
        _Field(
            label: 'Your Email',
            controller: _reqEmail,
            hint: 'e.g. joe@example.com',
            keyboard: TextInputType.emailAddress,
            action: TextInputAction.next),
        _Field(
            label: 'Club Name',
            controller: _reqClub,
            hint: 'e.g. Ballytown GAA',
            caps: TextCapitalization.words,
            action: TextInputAction.next),
        _Label('County'),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: V3.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickCounty,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    border: Border.all(color: V3.line),
                    borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(
                      child: Text(_county.isEmpty ? 'Select county…' : _county,
                          style: V3.inter(17,
                              color: _county.isEmpty ? _hintColour : V3.text))),
                  const Icon(Icons.expand_more, color: V3.muted),
                ]),
              ),
            ),
          ),
        ),
        _Field(
            label: 'Anything else? (optional)',
            controller: _reqNotes,
            hint: 'e.g. number of teams, age groups, any questions…',
            lines: 4),
        _Primary(_busy ? 'Sending…' : 'Send Request',
            busy: _busy, onTap: _submitTeamRequest),
        _Error(_errors[JoinStep.newTeam]),
      ];

  List<Widget> _newTeamSent() => [
        const _Hero(Icons.check),
        _Title('Request received!', centre: true),
        _CentreText.rich([
          const TextSpan(text: 'The '),
          _strong('CoachSmart team'),
          const TextSpan(text: ' will be in touch at '),
          _strong(_sentEmail),
          const TextSpan(text: ' within 24 hours to get your team set up.'),
        ]),
        _CentreText(
            "Keep an eye on your inbox — we'll send you your team joining code once everything is ready.",
            small: true),
        const SizedBox(height: 24),
        _Primary('Done', onTap: _close),
      ];

  List<Widget> _done() => [
        const _Hero(Icons.check),
        _Title("You're all set!", centre: true),
        _CentreText(doneText(_pendingCount)),
        const SizedBox(height: 24),
        _Primary('Done', onTap: _close),
      ];
}

// ------------------------------------------------------------- pieces

const _hintColour = Color(0xFF6F737C);

InputDecoration _decoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: V3.inter(17, color: _hintColour),
      filled: true,
      fillColor: V3.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: V3.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: V3.green, width: 1.5)),
    );

TextSpan _strong(String t) =>
    TextSpan(text: t, style: V3.inter(17, weight: FontWeight.w700));

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        child: Row(children: [
          for (var i = 1; i <= 2; i++) ...[
            Expanded(
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                    color: i <= step ? V3.green : V3.line,
                    borderRadius: BorderRadius.circular(3)),
              ),
            ),
            if (i < 2) const SizedBox(width: 8),
          ],
        ]),
      );
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700, color: V3.green, letterSpacing: .8)),
      );
}

class _Title extends StatelessWidget {
  const _Title(this.text, {this.centre = false});
  final String text;
  final bool centre;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            textAlign: centre ? TextAlign.center : TextAlign.start,
            style: V3.tight(26, weight: FontWeight.w700)),
      );
}

class _Sub extends StatelessWidget {
  const _Sub(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Text(text, style: V3.inter(16, color: V3.muted, height: 1.4)),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: V3.inter(15, weight: FontWeight.w600, color: V3.muted)),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.caps = TextCapitalization.none,
    this.keyboard,
    this.action,
    this.onSubmit,
    this.upper = false,
    this.maxLength,
    this.lines = 1,
  });
  final String label, hint;
  final TextEditingController controller;
  final TextCapitalization caps;
  final TextInputType? keyboard;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmit;
  final bool upper;
  final int? maxLength;
  final int lines;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Label(label),
          TextField(
            controller: controller,
            textCapitalization: upper ? TextCapitalization.characters : caps,
            keyboardType: lines > 1 ? TextInputType.multiline : keyboard,
            textInputAction: lines > 1 ? null : action,
            onSubmitted: onSubmit,
            autocorrect: !upper,
            maxLength: maxLength,
            minLines: lines,
            maxLines: lines,
            inputFormatters: upper ? [_UpperCase()] : null,
            cursorColor: V3.green,
            style: V3.inter(17),
            decoration: _decoration(hint).copyWith(counterText: ''),
          ),
        ]),
      );
}

class _Primary extends StatelessWidget {
  const _Primary(this.label, {required this.onTap, this.busy = false});
  final String label;
  final VoidCallback onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: busy ? null : onTap,
            style: FilledButton.styleFrom(
              backgroundColor: V3.green,
              disabledBackgroundColor: V3.green.withValues(alpha: .45),
              foregroundColor: V3.bg,
              disabledForegroundColor: V3.bg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: V3.inter(17, weight: FontWeight.w700, color: V3.bg)),
          ),
        ),
      );
}

class _Secondary extends StatelessWidget {
  const _Secondary(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: V3.text,
              side: const BorderSide(color: V3.line, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: V3.inter(17, weight: FontWeight.w600)),
          ),
        ),
      );
}

class _Error extends StatelessWidget {
  const _Error(this.text);
  final String? text;
  @override
  Widget build(BuildContext context) => text == null || text!.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(text!,
              textAlign: TextAlign.center,
              style: V3.inter(16, color: V3.redText, height: 1.35)),
        );
}

class _Choice extends StatelessWidget {
  const _Choice(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.onTap,
      this.highlight = false});
  final IconData icon;
  final String label, sub;
  final VoidCallback onTap;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: V3.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: highlight ? V3.nextLine : V3.line, width: 1.5)),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: V3.greenTint,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: V3.green, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: V3.inter(17, weight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(sub, style: V3.inter(15, color: V3.muted)),
                      ]),
                ),
                const Icon(Icons.chevron_right, color: V3.muted, size: 26),
              ]),
            ),
          ),
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero(this.icon, {this.amber = false});
  final IconData icon;
  final bool amber;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 20),
        child: Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: amber ? V3.amberTint : V3.greenTint,
                border: Border.all(
                    color: amber ? V3.amberLine : V3.nextLine, width: 2)),
            child: Icon(icon, size: 42, color: amber ? V3.amber : V3.green),
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: V3.greenTint, borderRadius: BorderRadius.circular(20)),
            child: Text(name,
                textAlign: TextAlign.center,
                style: V3.inter(17, weight: FontWeight.w700, color: V3.green)),
          ),
        ),
      );
}

class _CentreText extends StatelessWidget {
  const _CentreText(this.text, {this.small = false}) : spans = null;
  const _CentreText.rich(this.spans)
      : text = '',
        small = false;
  final String text;
  final List<InlineSpan>? spans;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final style = V3.inter(small ? 15 : 17,
        color: small ? V3.muted : V3.text, height: 1.4);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: spans != null
          ? Text.rich(TextSpan(style: style, children: spans),
              textAlign: TextAlign.center)
          : Text(text, textAlign: TextAlign.center, style: style),
    );
  }
}
