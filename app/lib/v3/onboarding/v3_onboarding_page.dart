// v3 Onboarding: a native copy of webviews/onboarding.html, the first
// sign-in flow for a user who has not joined a team yet. Replaces the
// FlutterFlow OnBoarding page (a web view) in v3 only; the web page stays
// for the old app.
//
// Same steps, calls and wording as the web page: your name
// (save_onboarding_details), then join as myself / register someone else
// (by name or member code) / ask for a new team, the team joining code with
// a live preview (get_team_by_code), the join (create_new_member_by_code),
// linking to someone already on the roster (request_member_access,
// lookup_member_by_code), the pending screens and the new team request
// (request-new-team). From the native wrapper: Log out at the top, and a
// Continue button once users.onboarding_status turns 'active'. Finishing
// goes to Home, as the wrapper did.
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../auth/v3_auth_widgets.dart' show V3Field;
import '../v3_crest_image.dart';
import '../v3_theme.dart';
import 'v3_onboarding_backend.dart';
import 'v3_onboarding_models.dart';
import '/v3/tracking/v3_track.dart';

class V3OnboardingPage extends StatefulWidget {
  const V3OnboardingPage({super.key, this.testBackend, this.onFinished});

  static String routeName = 'onBoarding';
  static String routePath = 'onBoarding';

  /// Widget tests pass a fake here instead of calling Supabase.
  @visibleForTesting
  final OnboardingBackend? testBackend;

  /// Called instead of going to Home when the flow ends (tests).
  @visibleForTesting
  final VoidCallback? onFinished;

  @override
  State<V3OnboardingPage> createState() => _V3OnboardingPageState();
}

enum _Preview { none, looking, found, unknown }

class _V3OnboardingPageState extends State<V3OnboardingPage> {
  late final OnboardingBackend _api =
      widget.testBackend ?? SupabaseOnboardingBackend();

  bool _loading = true;
  String? _loadError;
  final _history = ObHistory();
  ObScreen get _screen => _history.top ?? ObScreen.details;

  // The signed-in user (currentUser in the web page).
  String _myFirst = '';
  String _myLast = '';

  // Who is being registered.
  String _regFirst = '';
  String _regLast = '';
  bool _isMyself = false;
  int _codeTotal = 3;
  String _joiningCode = '';
  ({int? memberId, String name, String team})? _found;

  final _detailsFirst = TextEditingController();
  final _detailsLast = TextEditingController();
  final _theirFirst = TextEditingController();
  final _theirLast = TextEditingController();
  final _memberCode = TextEditingController();
  final _code = TextEditingController();
  final _reqName = TextEditingController();
  final _reqEmail = TextEditingController();
  final _reqClub = TextEditingController();
  final _reqNotes = TextEditingController();
  String _county = '';

  final Map<ObScreen, String> _errors = {};
  bool _busy = false;

  _Preview _preview = _Preview.none;
  String? _resolvedTeam;
  Timer? _debounce;
  int _lookupSeq = 0;

  // "Got a code?" (2026-11-26): one box for team and club codes.
  final _start = TextEditingController();
  _Preview _startPreview = _Preview.none;
  ObCodeLookup _startLookup = ObCodeLookup.none;
  Timer? _startDebounce;
  int _startSeq = 0;
  String? _clipCode; // a code-like text on the clipboard, offered as Paste

  /// A team code from "Got a code?", filled into the team code screen.
  String _startCode = '';
  String _startTeam = '';

  /// The club behind a club code, for "Is this your club?".
  ObCodeLookup _club = ObCodeLookup.none;
  String _clubCode = '';

  bool _another = false; // "Register another person?" on the who screen
  String _sentName = '';
  String _sentPrefix = '';
  String _sentTeam = '';
  String _sentDetail = '';
  String _pendName = '';
  String _pendTeam = '';
  List<ObPendingItem> _pendingItems = const [];
  String _reqSentEmail = '';

  String? _status; // users.onboarding_status
  StreamSubscription<String?>? _statusSub;

  @override
  void initState() {
    super.initState();
    _statusSub = _api.onboardingStatus().listen((s) {
      if (mounted) setState(() => _status = s);
    }, onError: (_) {});
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _startDebounce?.cancel();
    _statusSub?.cancel();
    for (final c in [
      _detailsFirst,
      _detailsLast,
      _theirFirst,
      _theirLast,
      _memberCode,
      _code,
      _start,
      _reqName,
      _reqEmail,
      _reqClub,
      _reqNotes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------- navigation

  void _show(ObScreen s) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _history.push(s));
  }

  void _goBack() {
    if (_screen == ObScreen.found) {
      _denyExistingMember();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _history.back(hasFirstName: _myFirst.trim().isNotEmpty));
  }

  void _setError(ObScreen s, String? text) =>
      setState(() => text == null ? _errors.remove(s) : _errors[s] = text);

  void _returnToApp() {
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    if (mounted) context.goNamed(V3HomePage.routeName);
  }

  Future<void> _logout() async {
    GoRouter.of(context).prepareAuthEvent();
    await authManager.signOut();
    if (!mounted) return;
    GoRouter.of(context).clearRedirectLocation();
    context.goNamedAuth(V3SignInPage.routeName, context.mounted);
  }

  // ------------------------------------------------------------------ load

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    Map<String, dynamic>? user;
    try {
      user = await _api.loadUser();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Your details could not be loaded. Please try again.';
      });
      return;
    }
    if (!mounted) return;
    _myFirst = '${user?['first_name'] ?? ''}';
    _myLast = '${user?['last_name'] ?? ''}';
    _detailsFirst.text = _myFirst;
    _detailsLast.text = _myLast;
    if (obNeedsDetails(user)) {
      setState(() => _loading = false);
      _show(ObScreen.details);
      return;
    }
    await _checkAndRoute();
  }

  Future<void> _checkAndRoute() async {
    final owned = obMemberIds(await _api.ownedMembers());
    var active = false;
    var pending = <ObPendingItem>[];
    if (owned.isNotEmpty) {
      active = await _api.hasActiveTeamLink(owned);
      if (!active) {
        pending = obPendingItems(await _api.pendingJoinRequests(owned),
            await _api.pendingAccessRequests());
      }
    }
    final follows = active ? false : await _api.followsAnyClub();
    if (!mounted) return;
    final route = obDecideRoute(
        ownedIds: owned,
        hasActiveLink: active,
        pendingCount: pending.length,
        followsClub: follows);
    setState(() => _loading = false);
    switch (route) {
      case ObRoute.home:
        _returnToApp();
      case ObRoute.pendingStatus:
        _pendingItems = pending;
        _show(ObScreen.pendingStatus);
      default:
        _showStart();
    }
  }

  Future<void> _checkPendingStatus() async {
    setState(() => _busy = true);
    _setError(ObScreen.pendingStatus, null);
    final owned = obMemberIds(await _api.ownedMembers());
    final approved = await _api.hasActiveTeamLink(owned);
    if (!mounted) return;
    setState(() => _busy = false);
    if (approved) {
      _returnToApp();
    } else {
      _setError(ObScreen.pendingStatus,
          'Still waiting — no approvals yet. Check back soon.');
    }
  }

  // --------------------------------------------------------------- details

  Future<void> _saveDetails() async {
    final first = _detailsFirst.text.trim();
    final last = _detailsLast.text.trim();
    if (first.isEmpty || last.isEmpty) {
      _setError(ObScreen.details, 'Please enter your first and last name.');
      return;
    }
    setState(() => _busy = true);
    _setError(ObScreen.details, null);
    try {
      await _api.saveDetails(first, last);
      V3Track.event('onboarding_details_saved');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _setError(
          ObScreen.details, 'Could not save your details. Please try again.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _myFirst = first;
      _myLast = last;
    });
    _showStart();
  }

  // ------------------------------------------------------------ got a code

  void _showStart() {
    _show(ObScreen.start);
    _readClipboard();
  }

  /// Offer a copied code (from the club's landing page) as a Paste button.
  /// Android reads it quietly; iPhone and the web would ask first, so
  /// there the button reads only when tapped.
  Future<void> _readClipboard() async {
    if (kIsWeb || Theme.of(context).platform == TargetPlatform.iOS) {
      if (mounted) setState(() => _clipCode = '');
      return;
    }
    try {
      final d = await Clipboard.getData(Clipboard.kTextPlain);
      final c = obCodeFromClipboard(d?.text);
      if (mounted && c != null && _start.text.trim().isEmpty) {
        setState(() => _clipCode = c);
      }
    } catch (_) {}
  }

  Future<void> _paste() async {
    final c = _clipCode?.isNotEmpty == true
        ? _clipCode
        : obCodeFromClipboard(
            (await Clipboard.getData(Clipboard.kTextPlain))?.text);
    if (!mounted) return;
    if (c == null) {
      _setError(ObScreen.start, 'Nothing to paste. Type the code instead.');
      return;
    }
    _start.text = c;
    _onStartChanged(c);
  }

  void _onStartChanged(String raw) {
    final upper = raw.toUpperCase();
    if (upper != raw) {
      _start.value = _start.value.copyWith(
          text: upper,
          selection: TextSelection.collapsed(offset: upper.length));
    }
    final code = obNormaliseCode(upper);
    _startDebounce?.cancel();
    _startSeq++;
    _errors.remove(ObScreen.start);
    setState(() {
      _startLookup = ObCodeLookup.none;
      _startPreview = obShouldLookUp(code) ? _Preview.looking : _Preview.none;
    });
    if (!obShouldLookUp(code)) return;
    final seq = _startSeq;
    _startDebounce = Timer(obLookupDelay, () => _lookupStart(code, seq));
  }

  Future<ObCodeLookup> _lookupStartNow(String code) async {
    try {
      return obParseCodeLookup(await _api.lookupJoinCode(code));
    } catch (_) {
      return ObCodeLookup.none;
    }
  }

  Future<void> _lookupStart(String code, int seq) async {
    final r = await _lookupStartNow(code);
    if (!mounted || seq != _startSeq) return;
    setState(() {
      _startLookup = r;
      _startPreview =
          r.kind == ObCodeKind.none ? _Preview.unknown : _Preview.found;
    });
  }

  Future<void> _submitStart() async {
    final code = obNormaliseCode(_start.text);
    if (code.isEmpty) {
      _setError(ObScreen.start, 'Please enter your code.');
      return;
    }
    setState(() => _busy = true);
    _setError(ObScreen.start, null);
    final r = _startPreview == _Preview.found
        ? _startLookup
        : await _lookupStartNow(code);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r.kind) {
      case ObCodeKind.club:
        _club = r;
        _clubCode = code;
        _errors.remove(ObScreen.club);
        V3Track.event('join_code', {'kind': 'club', 'from': 'onboarding'});
        _show(ObScreen.club);
      case ObCodeKind.team:
        _startCode = code;
        _startTeam = r.teamName;
        _another = false;
        V3Track.event('join_code', {'kind': 'team', 'from': 'onboarding'});
        _show(ObScreen.who);
      case ObCodeKind.none:
        _setError(ObScreen.start,
            "That code isn't recognised. Check it with your club or coach.");
    }
  }

  Future<void> _followClub() async {
    setState(() => _busy = true);
    _setError(ObScreen.club, null);
    dynamic r;
    try {
      r = await _api.followClubByCode(_clubCode);
    } catch (_) {
      r = null;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (r is Map && r['ok'] == true) {
      V3Track.event(
          'club_followed', {'club_id': _club.clubId, 'from': 'onboarding'});
      _returnToApp();
    } else {
      _setError(ObScreen.club, obTryAgain);
    }
  }

  // ------------------------------------------------------------------- who

  void _selectMyself() {
    _regFirst = _myFirst;
    _regLast = _myLast;
    _isMyself = true;
    _codeTotal = 4;
    _prefillTeamCode();
    _show(ObScreen.code);
  }

  /// The team code typed on "Got a code?" goes straight into the team code
  /// screen, already looked up, so it's one tap to send the request.
  void _prefillTeamCode() {
    if (_startCode.isEmpty) return;
    _code.text = _startCode;
    _resolvedTeam = _startTeam.isEmpty ? null : _startTeam;
    _preview = _startTeam.isEmpty ? _Preview.none : _Preview.found;
  }

  void _selectSomeoneElse() {
    _regFirst = '';
    _regLast = '';
    _isMyself = false;
    _show(ObScreen.theirName);
  }

  void _selectByCode() {
    _memberCode.clear();
    _errors.remove(ObScreen.memberCode);
    _show(ObScreen.memberCode);
  }

  void _confirmTheirName() {
    final first = _theirFirst.text.trim();
    final last = _theirLast.text.trim();
    if (first.isEmpty || last.isEmpty) {
      _setError(ObScreen.theirName, 'Please enter their first and last name.');
      return;
    }
    _errors.remove(ObScreen.theirName);
    _regFirst = first;
    _regLast = last;
    _isMyself = false;
    _codeTotal = 5;
    _prefillTeamCode();
    _show(ObScreen.code);
  }

  // ------------------------------------------------------------------ code

  void _onCodeChanged(String raw) {
    final upper = raw.toUpperCase();
    if (upper != raw) {
      _code.value = _code.value.copyWith(
          text: upper,
          selection: TextSelection.collapsed(offset: upper.length));
    }
    final code = upper.trim();
    _debounce?.cancel();
    _lookupSeq++;
    setState(() {
      _resolvedTeam = null;
      _preview = obShouldLookUp(code) ? _Preview.looking : _Preview.none;
    });
    if (!obShouldLookUp(code)) return;
    final seq = _lookupSeq;
    _debounce = Timer(obLookupDelay, () => _lookupCode(code, seq));
  }

  Future<void> _lookupCode(String code, int seq) async {
    String? name;
    try {
      name = obTeamNameFromLookup(await _api.teamByCode(code));
    } catch (_) {
      name = null;
    }
    if (!mounted || seq != _lookupSeq) return;
    setState(() {
      _resolvedTeam = name;
      _preview = name == null ? _Preview.unknown : _Preview.found;
    });
  }

  void _resetCodeScreen() {
    _code.clear();
    _errors.remove(ObScreen.code);
    _preview = _Preview.none;
    _resolvedTeam = null;
    _debounce?.cancel();
    _lookupSeq++;
  }

  Future<void> _submitCode() async {
    final code = obNormaliseCode(_code.text);
    if (code.isEmpty) {
      _setError(ObScreen.code, 'Please enter the team joining code.');
      return;
    }
    setState(() => _busy = true);
    _setError(ObScreen.code, null);
    _joiningCode = code;
    dynamic data;
    try {
      V3Track.event('join_team', {'via': 'new_member', 'from': 'onboarding'});
      data = await _api.createMemberByCode(_regFirst, _regLast, code);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _setError(ObScreen.code, obTryAgain);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final r = obParseJoin(data, resolvedTeamName: _resolvedTeam);
    final memberName = '$_regFirst $_regLast';
    switch (r.kind) {
      case ObJoinKind.error:
        _setError(ObScreen.code, r.message);
      case ObJoinKind.duplicate:
        _found = (memberId: r.memberId, name: memberName, team: r.teamName);
        _errors.remove(ObScreen.found);
        _code.clear();
        _show(ObScreen.found);
      case ObJoinKind.alreadyPending:
        _pendName = memberName;
        _pendTeam = r.teamName;
        _resetCodeScreen();
        _api.updateOnboardingStatus('pending');
        _show(ObScreen.alreadyPending);
      case ObJoinKind.pendingOther:
        _pendName = memberName;
        _pendTeam = r.teamName;
        _resetCodeScreen();
        _api.updateOnboardingStatus('pending_other');
        _show(ObScreen.pendingOther);
      case ObJoinKind.pending:
        _sentName = memberName;
        _sentPrefix = 'has been submitted to join ';
        _sentTeam = r.teamName;
        _sentDetail = 'A team admin will confirm the membership shortly. '
            "You'll receive a notification when it's approved.";
        _resetCodeScreen();
        _api.updateOnboardingStatus('pending');
        _show(ObScreen.sent);
      case ObJoinKind.other:
        break;
    }
  }

  // ----------------------------------------------------------------- found

  Future<void> _confirmExistingMember() async {
    final f = _found;
    if (f?.memberId == null) {
      _setError(ObScreen.found,
          'Please contact your team admin to link your account.');
      return;
    }
    setState(() => _busy = true);
    _setError(ObScreen.found, null);
    String? problem;
    try {
      problem = obAccessError(
          await _api.requestMemberAccess(f!.memberId!, _joiningCode));
      V3Track.event(
          'join_team', {'via': 'existing_member', 'from': 'onboarding'});
    } catch (_) {
      problem = obTryAgain;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (problem != null) {
      _setError(ObScreen.found, problem);
      return;
    }
    _sentName = f!.name;
    _sentPrefix = 'is already on the roster. Your request to link your '
        'account has been sent to the admin of ';
    _sentTeam = f.team;
    _sentDetail = "Once confirmed by the admin, you'll be linked to their "
        "profile. You'll receive a notification when it's approved.";
    _api.updateOnboardingStatus('pending');
    _show(ObScreen.sent);
  }

  void _denyExistingMember() {
    _found = null;
    _errors.remove(ObScreen.found);
    if (_history.previous == ObScreen.memberCode) {
      setState(() => _history.stack.removeLast());
    } else if (_isMyself) {
      _show(ObScreen.who);
    } else {
      _theirFirst.clear();
      _theirLast.clear();
      _errors.remove(ObScreen.theirName);
      _show(ObScreen.theirName);
    }
  }

  // ----------------------------------------------------------- member code

  Future<void> _lookupByMemberCode() async {
    final code = _memberCode.text.trim();
    if (code.isEmpty) {
      _setError(ObScreen.memberCode, 'Please enter the member code.');
      return;
    }
    setState(() => _busy = true);
    _setError(ObScreen.memberCode, null);
    ObMemberLookup r;
    try {
      r = obParseMemberLookup(await _api.lookupMemberByCode(code));
    } catch (_) {
      r = const ObMemberLookup(error: obTryAgain);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) {
      _setError(ObScreen.memberCode, r.error);
      return;
    }
    _joiningCode = r.teamCode;
    _regFirst = r.firstName;
    _regLast = r.lastName;
    _isMyself = false;
    _found = (memberId: r.memberId, name: r.name, team: r.teamName);
    _errors.remove(ObScreen.found);
    _show(ObScreen.found);
  }

  // ------------------------------------------------------------ post-send

  void _addAnother() {
    _regFirst = '';
    _regLast = '';
    _isMyself = false;
    _found = null;
    _theirFirst.clear();
    _theirLast.clear();
    _errors.remove(ObScreen.theirName);
    _resetCodeScreen();
    _startCode = '';
    _startTeam = '';
    _another = true;
    _show(ObScreen.who);
  }

  // -------------------------------------------------------------- new team

  void _selectNewTeam() {
    _reqName.text = '$_myFirst $_myLast'.trim();
    _reqEmail.text = _api.email;
    _reqClub.clear();
    _county = '';
    _reqNotes.clear();
    _errors.remove(ObScreen.newTeam);
    _show(ObScreen.newTeam);
  }

  Future<void> _pickCounty() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: V3.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text('Select county',
                  style: V3.tight(18, weight: FontWeight.w700)),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final c in obCounties)
                  ListTile(
                    minTileHeight: 52,
                    title: Text(c, style: V3.inter(17)),
                    trailing: c == _county
                        ? const Icon(Icons.check, color: V3.green)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(c),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _county = picked);
  }

  Future<void> _submitTeamRequest() async {
    final problem = obNewTeamProblem(club: _reqClub.text, county: _county);
    if (problem != null) {
      _setError(ObScreen.newTeam, problem);
      return;
    }
    final name = _reqName.text.trim().isNotEmpty
        ? _reqName.text.trim()
        : '$_myFirst $_myLast'.trim();
    final email =
        _reqEmail.text.trim().isNotEmpty ? _reqEmail.text.trim() : _api.email;
    setState(() => _busy = true);
    _setError(ObScreen.newTeam, null);
    V3Track.event('new_team_requested', {'from': 'onboarding'});
    final err = await _api.requestNewTeam(obNewTeamBody(
        name: name,
        email: email,
        club: _reqClub.text,
        county: _county,
        notes: _reqNotes.text));
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _setError(ObScreen.newTeam, err);
      return;
    }
    _reqSentEmail = email.isEmpty ? 'your email address' : email;
    _show(ObScreen.newTeamSent);
  }

  /// "Done" after a new team request. The web page closed itself (the
  /// native wrapper ignored that), so here it goes back to the start.
  void _doneNewTeam() {
    setState(() => _history.reset(ObScreen.start));
    _readClipboard();
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final back = !_loading && _loadError == null && obHasBack(_screen);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && back) _goBack();
      },
      child: Scaffold(
        backgroundColor: V3.bg,
        appBar: AppBar(
          backgroundColor: V3.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: back
              ? IconButton(
                  tooltip: 'Back',
                  icon:
                      const Icon(Icons.chevron_left, color: V3.green, size: 40),
                  onPressed: _goBack)
              : null,
          title: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'COACH'),
                TextSpan(text: 'SMART', style: V3.tight(20, color: V3.green)),
              ]),
              style: V3.tight(20, weight: FontWeight.w800)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _logout,
                style: TextButton.styleFrom(
                    minimumSize: const Size(64, 44), foregroundColor: V3.muted),
                child: Text('Log out',
                    style:
                        V3.inter(16, weight: FontWeight.w600, color: V3.muted)),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: V3.green))
                : _loadError != null
                    ? _errorState()
                    : ListView(
                        key: ValueKey(_screen),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                        children: [
                          if (_status == 'active') _continueBanner(),
                          ..._progress(),
                          ..._body(),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_loadError!,
                textAlign: TextAlign.center,
                style: V3.inter(16, color: V3.muted)),
            const SizedBox(height: 20),
            _PrimaryButton(label: 'Try again', onPressed: _init),
          ]),
        ),
      );

  /// The wrapper's Continue button, shown once an admin has approved.
  Widget _continueBanner() => Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: V3.greenTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: V3.nextLine)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text("You're approved", style: V3.tight(18, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Your membership has been confirmed.',
              style: V3.inter(15, color: V3.muted)),
          const SizedBox(height: 12),
          _PrimaryButton(
              label: 'Continue',
              icon: Icons.chevron_right,
              onPressed: _returnToApp),
        ]),
      );

  List<Widget> _progress() {
    final p = obProgress(_screen, codeTotal: _codeTotal);
    if (p == null) return const [SizedBox(height: 36)];
    return [
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 1; i <= p.total; i++)
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < p.current
                  ? V3.green.withValues(alpha: .35)
                  : i == p.current
                      ? V3.green
                      : Colors.transparent,
              border: i > p.current
                  ? Border.all(color: V3.muted, width: 1.5)
                  : null,
            ),
          ),
      ]),
      const SizedBox(height: 28),
      Text(p.label.toUpperCase(),
          style: V3.inter(13,
              weight: FontWeight.w700, color: V3.muted, letterSpacing: .8)),
      const SizedBox(height: 8),
    ];
  }

  Widget _title(String t, {bool centre = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            textAlign: centre ? TextAlign.center : TextAlign.start,
            style: V3.tight(27, weight: FontWeight.w700, height: 1.25)),
      );

  Widget _sub(String t, {bool centre = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Text(t,
            textAlign: centre ? TextAlign.center : TextAlign.start,
            style: V3.inter(16, color: V3.muted, height: 1.5)),
      );

  Widget _error(ObScreen s) {
    final e = _errors[s];
    if (e == null || e.isEmpty) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(e,
          textAlign: TextAlign.center,
          style: V3.inter(15, color: V3.redText, weight: FontWeight.w500)),
    );
  }

  List<Widget> _body() {
    switch (_screen) {
      case ObScreen.details:
        return _details();
      case ObScreen.start:
        return _startScreen();
      case ObScreen.club:
        return _clubScreen();
      case ObScreen.who:
        return _who();
      case ObScreen.theirName:
        return _theirName();
      case ObScreen.memberCode:
        return _memberCodeScreen();
      case ObScreen.code:
        return _codeScreen();
      case ObScreen.found:
        return _foundScreen();
      case ObScreen.alreadyPending:
        return _alreadyPending();
      case ObScreen.pendingOther:
        return _pendingOther();
      case ObScreen.pendingStatus:
        return _pendingStatus();
      case ObScreen.sent:
        return _sent();
      case ObScreen.newTeam:
        return _newTeam();
      case ObScreen.newTeamSent:
        return _newTeamSent();
    }
  }

  List<Widget> _details() => [
        _title("Welcome! Let's get you set up."),
        _sub('What should we call you?'),
        V3Field(
            label: 'First name',
            hint: 'First name',
            controller: _detailsFirst,
            autofillHints: const [AutofillHints.givenName],
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next),
        V3Field(
            label: 'Last name',
            hint: 'Last name',
            controller: _detailsLast,
            autofillHints: const [AutofillHints.familyName],
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveDetails()),
        _PrimaryButton(label: 'Continue', busy: _busy, onPressed: _saveDetails),
        _error(ObScreen.details),
      ];

  List<Widget> _who() => [
        _title(_another
            ? 'Register another person?'
            : _startTeam.isNotEmpty
                ? 'Who is joining $_startTeam?'
                : 'How would you like to get started?'),
        _sub(_another
            ? "Choose how you'd like to continue."
            : 'Choose one to continue.'),
        _ChoiceCard(
            icon: Icons.directions_run,
            label: 'Join as myself',
            sub: 'I play or coach on this team',
            onTap: _selectMyself),
        _ChoiceCard(
            icon: Icons.family_restroom,
            label: 'Register someone else',
            sub: 'My child or another family member',
            onTap: _selectSomeoneElse),
        _ChoiceCard(
            icon: Icons.stadium_outlined,
            label: 'Set up a new team',
            sub: 'Request a new team setup on CoachSmart',
            highlight: true,
            onTap: _selectNewTeam),
      ];

  // "Got a code?" (Ken, 2026-11-26): the only way in. A team code joins a
  // team (the coach approves); a club code follows the club straight away.
  // No club search: no code, no club.
  List<Widget> _startScreen() => [
        _title('Got a code?', centre: true),
        _sub('From your club or your coach.', centre: true),
        TextField(
          key: const ValueKey('start-code'),
          controller: _start,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 20,
          textInputAction: TextInputAction.go,
          onChanged: _onStartChanged,
          onSubmitted: (_) => _submitStart(),
          cursorColor: V3.green,
          style:
              V3.tight(26, weight: FontWeight.w700).copyWith(letterSpacing: 3),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Team or club code',
            hintStyle: V3.inter(17, color: const Color(0xFF6F737C)),
            filled: true,
            fillColor: V3.card,
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: V3.line, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: V3.green, width: 1.5)),
          ),
        ),
        if (_clipCode != null && _start.text.trim().isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste, size: 18),
                label: Text(
                    _clipCode!.isEmpty ? 'Paste code' : 'Paste "$_clipCode"',
                    style:
                        V3.inter(15, weight: FontWeight.w600, color: V3.green)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: V3.green,
                    minimumSize: const Size(44, 44),
                    side: const BorderSide(color: V3.nextLine, width: 1.5),
                    shape: const StadiumBorder()),
              ),
            ),
          ),
        const SizedBox(height: 12),
        _startPreviewLine(),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
              'A team code joins a team (the coach approves). '
              'A club code follows the club straight away.',
              style: V3.inter(14.5, color: V3.muted, height: 1.45)),
        ),
        _PrimaryButton(label: 'Continue', busy: _busy, onPressed: _submitStart),
        _error(ObScreen.start),
        const SizedBox(height: 26),
        Row(children: [
          const Expanded(child: Divider(color: V3.line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('No code?', style: V3.inter(14, color: V3.muted)),
          ),
          const Expanded(child: Divider(color: V3.line)),
        ]),
        const SizedBox(height: 8),
        Text('Ask your club or your coach for one.',
            textAlign: TextAlign.center, style: V3.inter(15, color: V3.muted)),
        const SizedBox(height: 16),
        _ChoiceCard(
            icon: Icons.stadium_outlined,
            label: 'Set up a new team',
            sub: 'Request a new team setup on CoachSmart',
            highlight: true,
            onTap: _selectNewTeam),
      ];

  Widget _startPreviewLine() {
    if (_startPreview == _Preview.none) return const SizedBox(height: 4);
    final found = _startPreview == _Preview.found;
    final l = _startLookup;
    final text = switch (_startPreview) {
      _Preview.looking => 'Looking up code…',
      _Preview.found => l.kind == ObCodeKind.club
          ? 'Club: ${l.clubName}'
          : 'Team: ${l.teamName}',
      _ => 'Code not recognised',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _startPreview == _Preview.looking
          ? null
          : BoxDecoration(
              color: found ? V3.greenTint : V3.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: found ? V3.nextLine : V3.line)),
      child: Row(children: [
        if (found) ...[
          const Icon(Icons.check, color: V3.green, size: 20),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(text,
              style: V3.inter(found ? 16 : 15,
                  weight: found ? FontWeight.w600 : FontWeight.w400,
                  color: found ? V3.green : V3.muted)),
        ),
      ]),
    );
  }

  List<Widget> _clubScreen() => [
        _title('Is this your club?', centre: true),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: V3.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: V3.nextLine, width: 1.5)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              V3CrestImage(_club.crest,
                  size: 56,
                  fallback: const Icon(Icons.shield_outlined,
                      color: V3.green, size: 44)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_club.clubName,
                          style: V3.tight(21, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_club.clubLine,
                          style: V3.inter(15, color: V3.muted)),
                    ]),
              ),
            ]),
            const SizedBox(height: 14),
            Text(
                "You'll follow the club: its news, matches and results on "
                'Home. No team needed.',
                style: V3.inter(15.5, height: 1.45)),
            const SizedBox(height: 10),
            Text(
                'Got a child on a team? Add their team code any time from '
                'the menu.',
                style: V3.inter(14.5, color: V3.muted, height: 1.45)),
          ]),
        ),
        const SizedBox(height: 22),
        _PrimaryButton(
            label: 'Follow ${_club.clubName}',
            busy: _busy,
            onPressed: _followClub),
        _error(ObScreen.club),
        const SizedBox(height: 4),
        _SecondaryButton(label: 'Not my club', onPressed: _goBack),
      ];

  List<Widget> _theirName() => [
        _title('What is their name?'),
        _sub('Enter their name exactly as it appears, or will appear, on '
            'the team roster.'),
        V3Field(
            label: 'First name',
            hint: 'First name',
            controller: _theirFirst,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next),
        V3Field(
            label: 'Last name',
            hint: 'Last name',
            controller: _theirLast,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmTheirName()),
        _PrimaryButton(label: 'Continue', onPressed: _confirmTheirName),
        _error(ObScreen.theirName),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Have their member code?', style: V3.inter(16)),
            TextButton(
              onPressed: _selectByCode,
              style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44), foregroundColor: V3.green),
              child: Text('Use it instead',
                  style:
                      V3.inter(16, weight: FontWeight.w700, color: V3.green)),
            ),
          ],
        ),
      ];

  List<Widget> _memberCodeScreen() => [
        _title('Use their member code'),
        _sub('Another parent or team admin can share this unique code with '
            'you. Enter it below to find the member.'),
        V3Field(
            label: 'Member code',
            hint: 'e.g. MB12345',
            controller: _memberCode,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              final up = v.toUpperCase();
              if (up != v) {
                _memberCode.value = _memberCode.value.copyWith(
                    text: up,
                    selection: TextSelection.collapsed(offset: up.length));
              }
            },
            onSubmitted: (_) => _lookupByMemberCode()),
        _PrimaryButton(
            label: 'Find Member', busy: _busy, onPressed: _lookupByMemberCode),
        _error(ObScreen.memberCode),
      ];

  List<Widget> _codeScreen() => [
        _title('Enter the team joining code'),
        _sub('Your team admin will have shared this with you.'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: V3.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: V3.line)),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: 'Joining as ', style: V3.inter(16, color: V3.muted)),
            TextSpan(
                text: '$_regFirst $_regLast',
                style: V3.inter(16, weight: FontWeight.w700)),
          ])),
        ),
        TextField(
          key: const ValueKey('team-code'),
          controller: _code,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 20,
          textInputAction: TextInputAction.go,
          onChanged: _onCodeChanged,
          onSubmitted: (_) => _submitCode(),
          cursorColor: V3.green,
          style:
              V3.tight(30, weight: FontWeight.w700).copyWith(letterSpacing: 6),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Team code',
            hintStyle: V3.inter(17, color: const Color(0xFF6F737C)),
            filled: true,
            fillColor: V3.card,
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: V3.line, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: V3.green, width: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        _teamPreview(),
        _PrimaryButton(
            label: obJoinLabel(_resolvedTeam),
            busy: _busy,
            onPressed: _submitCode),
        _error(ObScreen.code),
      ];

  Widget _teamPreview() {
    if (_preview == _Preview.none) return const SizedBox(height: 4);
    final found = _preview == _Preview.found;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _preview == _Preview.looking
          ? null
          : BoxDecoration(
              color: found ? V3.greenTint : V3.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: found ? V3.nextLine : V3.line)),
      child: Row(children: [
        if (found) ...[
          const Icon(Icons.check, color: V3.green, size: 20),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
              switch (_preview) {
                _Preview.looking => 'Looking up code…',
                _Preview.found => _resolvedTeam ?? '',
                _ => 'Code not recognised',
              },
              style: V3.inter(found ? 16 : 15,
                  weight: found ? FontWeight.w600 : FontWeight.w400,
                  color: found ? V3.green : V3.muted)),
        ),
      ]),
    );
  }

  List<Widget> _foundScreen() {
    final f = _found;
    return [
      const _HeroIcon(icon: Icons.manage_search, amber: true),
      _title('Already on the roster', centre: true),
      const SizedBox(height: 8),
      Center(child: _NameChip(f?.name ?? '')),
      const SizedBox(height: 12),
      Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'is already a confirmed member of '),
            TextSpan(
                text: f?.team ?? '',
                style: V3.inter(16, weight: FontWeight.w700)),
            const TextSpan(text: '.'),
          ]),
          textAlign: TextAlign.center,
          style: V3.inter(16, color: V3.muted, height: 1.5)),
      const SizedBox(height: 10),
      Text('Is this the person you are registering?',
          textAlign: TextAlign.center,
          style: V3.inter(16, color: V3.muted, height: 1.5)),
      const SizedBox(height: 10),
      Text(
          "If yes, we'll send a request to the team admin to link your "
          "account to their profile. You'll be notified once it's approved.",
          textAlign: TextAlign.center,
          style: V3.inter(15, color: V3.muted, height: 1.5)),
      const SizedBox(height: 28),
      _PrimaryButton(
          label: 'Yes — request access to their profile',
          busy: _busy,
          onPressed: _confirmExistingMember),
      const SizedBox(height: 10),
      _SecondaryButton(
          label: 'No — enter a different name', onPressed: _denyExistingMember),
      _error(ObScreen.found),
    ];
  }

  static const _continueNote = 'Once a team admin approves it, a Continue '
      'button will appear at the top of this screen. Tap it to get started. '
      'You can also log out and log back in after the admin has confirmed '
      'your membership.';

  Widget _muted(String t, {double top = 14}) => Padding(
        padding: EdgeInsets.only(top: top),
        child: Text(t,
            textAlign: TextAlign.center,
            style: V3.inter(15, color: V3.muted, height: 1.5)),
      );

  Widget _teamLine(String before, String team, String after) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text.rich(
            TextSpan(children: [
              TextSpan(text: before),
              TextSpan(
                  text: team, style: V3.inter(16, weight: FontWeight.w700)),
              TextSpan(text: after),
            ]),
            textAlign: TextAlign.center,
            style: V3.inter(16, color: V3.muted, height: 1.5)),
      );

  List<Widget> _alreadyPending() => [
        const _HeroIcon(icon: Icons.schedule, amber: true),
        _title('Awaiting approval', centre: true),
        const SizedBox(height: 8),
        Text('Your request for',
            textAlign: TextAlign.center, style: V3.inter(16, color: V3.muted)),
        const SizedBox(height: 8),
        Center(child: _NameChip(_pendName)),
        _teamLine('to join ', _pendTeam, ' is already pending.'),
        _muted(_continueNote),
        const SizedBox(height: 32),
        _PrimaryButton(label: 'Add another person', onPressed: _addAnother),
      ];

  List<Widget> _pendingOther() => [
        const _HeroIcon(icon: Icons.schedule, amber: true),
        _title('Awaiting approval', centre: true),
        const SizedBox(height: 8),
        Text('A join request for',
            textAlign: TextAlign.center, style: V3.inter(16, color: V3.muted)),
        const SizedBox(height: 8),
        Center(child: _NameChip(_pendName)),
        _teamLine('to ', _pendTeam, ' is already waiting for admin approval.'),
        _muted('Once the admin confirms it, come back and enter the same '
            "name and code — you'll be offered the option to link your "
            'account to their profile.'),
        _muted(_continueNote, top: 10),
        const SizedBox(height: 32),
        _PrimaryButton(label: 'Add another person', onPressed: _addAnother),
      ];

  List<Widget> _pendingStatus() => [
        const _HeroIcon(icon: Icons.schedule, amber: true),
        _title('Awaiting approval', centre: true),
        _muted(
            'Your membership request is pending. Once a team admin approves '
            'it, a Continue button will appear at the top of this screen — '
            "tap it to get started. You'll receive an email when your "
            "request is approved — that's your signal to log back in if "
            "you've closed the app.",
            top: 4),
        const SizedBox(height: 24),
        for (final p in _pendingItems)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: V3.card, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(p.isLink ? Icons.link : Icons.directions_run,
                  color: V3.green, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name.trim(),
                          style: V3.inter(17, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(p.label, style: V3.inter(15, color: V3.muted)),
                    ]),
              ),
            ]),
          ),
        const SizedBox(height: 22),
        _PrimaryButton(
            label: 'Check approval status',
            busy: _busy,
            onPressed: _checkPendingStatus),
        _error(ObScreen.pendingStatus),
      ];

  List<Widget> _sent() => [
        const _HeroIcon(icon: Icons.check, amber: false),
        _title('Request sent!', centre: true),
        const SizedBox(height: 8),
        Center(child: _NameChip(_sentName)),
        _teamLine(_sentPrefix, _sentTeam, '.'),
        _muted(_sentDetail, top: 10),
        const SizedBox(height: 32),
        _PrimaryButton(label: 'Add another person', onPressed: _addAnother),
      ];

  List<Widget> _newTeam() => [
        _title('Set up your team on CoachSmart'),
        _sub('Fill in the details below and our team will be in touch '
            'within 24 hours to get everything set up for you.'),
        V3Field(
            label: 'Your name',
            hint: 'e.g. Joe Bloggs',
            controller: _reqName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next),
        V3Field(
            label: 'Your email',
            hint: 'e.g. joe@example.com',
            controller: _reqEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next),
        V3Field(
            label: 'Club name',
            hint: 'e.g. Ballytown GAA',
            controller: _reqClub,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done),
        Text('County', style: V3.inter(15, color: V3.muted)),
        const SizedBox(height: 8),
        Material(
          color: V3.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: V3.line, width: 1.5)),
          child: InkWell(
            key: const ValueKey('county'),
            borderRadius: BorderRadius.circular(14),
            onTap: _pickCounty,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              child: Row(children: [
                Expanded(
                  child: Text(_county.isEmpty ? 'Select county…' : _county,
                      style: V3.inter(17,
                          weight: FontWeight.w500,
                          color: _county.isEmpty
                              ? const Color(0xFF6F737C)
                              : V3.text)),
                ),
                const Icon(Icons.expand_more, color: V3.muted),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text.rich(TextSpan(children: [
          TextSpan(
              text: 'Anything else? ', style: V3.inter(15, color: V3.muted)),
          TextSpan(
              text: '(optional)',
              style: V3.inter(14, color: const Color(0xFF6F737C))),
        ])),
        const SizedBox(height: 8),
        TextField(
          controller: _reqNotes,
          minLines: 3,
          maxLines: 6,
          cursorColor: V3.green,
          textCapitalization: TextCapitalization.sentences,
          style: V3.inter(17),
          decoration: InputDecoration(
            hintText: 'e.g. number of teams, age groups, any questions…',
            hintStyle: V3.inter(16, color: const Color(0xFF6F737C)),
            filled: true,
            fillColor: V3.card,
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: V3.line, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: V3.green, width: 1.5)),
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
            label: 'Send Request', busy: _busy, onPressed: _submitTeamRequest),
        _error(ObScreen.newTeam),
      ];

  List<Widget> _newTeamSent() => [
        const _HeroIcon(icon: Icons.check, amber: false),
        _title('Request received!', centre: true),
        const SizedBox(height: 4),
        Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'The '),
              TextSpan(
                  text: 'CoachSmart team',
                  style: V3.inter(16, weight: FontWeight.w700)),
              const TextSpan(text: ' will be in touch at '),
              TextSpan(
                  text: _reqSentEmail,
                  style: V3.inter(16, weight: FontWeight.w700)),
              const TextSpan(text: ' within 24 hours to get your team set up.'),
            ]),
            textAlign: TextAlign.center,
            style: V3.inter(16, color: V3.muted, height: 1.5)),
        _muted("Keep an eye on your inbox — we'll send you your team joining "
            'code once everything is ready.'),
        const SizedBox(height: 32),
        _PrimaryButton(label: 'Done', onPressed: _doneNewTeam),
      ];
}

// ------------------------------------------------------------------ pieces

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
      {required this.label,
      required this.onPressed,
      this.busy = false,
      this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: V3.green,
          disabledBackgroundColor: V3.green.withValues(alpha: .45),
          foregroundColor: V3.bg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child:
                    CircularProgressIndicator(strokeWidth: 2.5, color: V3.bg))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style:
                          V3.inter(17, weight: FontWeight.w700, color: V3.bg)),
                ),
                if (icon != null) Icon(icon, color: V3.bg, size: 24),
              ]),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: V3.text,
            side: const BorderSide(color: V3.line, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: V3.inter(17, weight: FontWeight.w500, color: V3.muted)),
        ),
      );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.onTap,
      this.highlight = false});
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: V3.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: highlight ? V3.nextLine : V3.line, width: 1.5)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: V3.card2, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: V3.green, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: V3.inter(18, weight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(sub,
                            style: V3.inter(15, color: V3.muted, height: 1.35)),
                      ]),
                ),
                const Icon(Icons.chevron_right, color: V3.muted, size: 26),
              ]),
            ),
          ),
        ),
      );
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon, required this.amber});
  final IconData icon;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    final c = amber ? V3.amber : V3.green;
    return Center(
      child: Container(
        width: 76,
        height: 76,
        margin: const EdgeInsets.only(top: 12, bottom: 24),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: amber ? V3.amberTint : V3.greenTint,
            border: Border.all(color: c, width: 2)),
        child: Icon(icon, color: c, size: 38),
      ),
    );
  }
}

class _NameChip extends StatelessWidget {
  const _NameChip(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
            color: V3.greenTint,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: V3.nextLine)),
        child: Text(name,
            style: V3.inter(17, weight: FontWeight.w600, color: V3.green)),
      );
}
