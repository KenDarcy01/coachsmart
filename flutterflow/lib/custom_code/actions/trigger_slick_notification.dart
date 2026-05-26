// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/api_requests/api_calls.dart';
import 'index.dart';

import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

// ---------------------------------------------------------------------------
// DEBUG LOGGER
// All logs visible in Chrome F12 > Console
// Filter by '[SlickNotif]' to isolate these logs
// ---------------------------------------------------------------------------

const String _sTag = '[SlickNotif]';
int _sBannerInstanceCount = 0;

void _sLog(String msg) => print('$_sTag ✅ $msg');
void _sLogWarn(String msg) => print('$_sTag ⚠️  $msg');
void _sLogError(String msg, [Object? e]) =>
    print('$_sTag 🔴 $msg${e != null ? ' | error: $e' : ''}');
void _sLogStep(String step, String detail) => print('$_sTag ▶ [$step] $detail');

void _sLogBannerState(
  String location,
  int instanceId, {
  required bool mounted,
  required bool ctrlNull,
  required bool slideNull,
  required bool fadeNull,
  required bool dismissing,
  required double dragOffset,
}) {
  print(
    '$_sTag 🔍 [BannerState @ $location] '
    'instance=#$instanceId | '
    'mounted=$mounted | '
    'ctrl=${ctrlNull ? "NULL" : "ok"} | '
    'slide=${slideNull ? "NULL" : "ok"} | '
    'fade=${fadeNull ? "NULL" : "ok"} | '
    'dismissing=$dismissing | '
    'dragOffset=$dragOffset',
  );
}

// ---------------------------------------------------------------------------
// BACKGROUND PUSH HANDLER
// Top-level function required by FCM.
// Register in main.dart before runApp():
//   FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('$_sTag ▶ [BGHandler] Push received'
      ' | title: ${message.notification?.title}'
      ' | body: ${message.notification?.body}'
      ' | data: ${message.data}');
}

// ---------------------------------------------------------------------------
// OVERLAY STATE
// ---------------------------------------------------------------------------

OverlayEntry? _activeBannerEntry;
Timer? _activeDismissTimer;

void _removeBanner() {
  _sLogStep(
      'BannerManager',
      'removeBanner | '
          'entry=${_activeBannerEntry != null ? "exists" : "null"} | '
          'timer=${_activeDismissTimer != null ? "exists" : "null"}');
  _activeDismissTimer?.cancel();
  _activeDismissTimer = null;
  try {
    _activeBannerEntry?.remove();
  } catch (e) {
    _sLogError('_removeBanner: entry.remove() threw (already detached?)', e);
  }
  _activeBannerEntry = null;
  _sLog('Banner removed from overlay ✓');
}

void _pauseDismissTimer() {
  _sLogStep(
      'BannerManager',
      'pauseTimer | '
          'timer=${_activeDismissTimer != null ? "exists" : "null"}');
  _activeDismissTimer?.cancel();
  _sLogStep('BannerManager', 'Dismiss timer paused');
}

// ---------------------------------------------------------------------------
// BANNER WIDGET
// ---------------------------------------------------------------------------

class _SlickBanner extends StatefulWidget {
  const _SlickBanner({
    required this.title,
    required this.body,
    required this.instanceId,
    required this.onDismiss,
    required this.onDragStart,
  });

  final String title;
  final String body;
  final int instanceId;
  final VoidCallback onDismiss;
  final VoidCallback onDragStart;

  @override
  State<_SlickBanner> createState() => _SlickBannerState();
}

class _SlickBannerState extends State<_SlickBanner>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<Offset>? _slide;
  Animation<double>? _fade;
  double _dragOffset = 0.0;
  bool _dismissing = false;

  void _i(String step, String detail) =>
      _sLogStep('Banner#${widget.instanceId}.$step', detail);
  void _iWarn(String msg) => _sLogWarn('Banner#${widget.instanceId} — $msg');
  void _iError(String msg, [Object? e]) =>
      _sLogError('Banner#${widget.instanceId} — $msg', e);

  void _dumpState(String location) {
    _sLogBannerState(
      location,
      widget.instanceId,
      mounted: mounted,
      ctrlNull: _ctrl == null,
      slideNull: _slide == null,
      fadeNull: _fade == null,
      dismissing: _dismissing,
      dragOffset: _dragOffset,
    );
  }

  void _safeSetState(String caller, VoidCallback fn) {
    _i(
        'safeSetState',
        'called from $caller | '
            'mounted=$mounted | '
            'ctrlNull=${_ctrl == null}');
    if (!mounted) {
      _iWarn('safeSetState[$caller] aborted — not mounted');
      _dumpState('safeSetState[$caller]:notMounted');
      return;
    }
    if (_ctrl == null) {
      _iWarn('safeSetState[$caller] aborted — controller null');
      _dumpState('safeSetState[$caller]:ctrlNull');
      return;
    }
    try {
      setState(fn);
      _i('safeSetState', '$caller — setState completed ✓');
    } catch (e) {
      _iError('safeSetState[$caller] threw', e);
      _dumpState('safeSetState[$caller]:threw');
    }
  }

  @override
  void initState() {
    super.initState();
    _i(
        'initState',
        'begin — instance #${widget.instanceId} | '
            'title="${widget.title}" | '
            'body="${widget.body}"');

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    );
    _i('initState', 'AnimationController created ✓');

    _slide = Tween<Offset>(
      begin: const Offset(0.0, -1.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl!,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInQuart,
    ));
    _i('initState', 'slide animation created ✓');

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl!,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
        reverseCurve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
    _i('initState', 'fade animation created ✓');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _i('postFrameCallback',
          'fired | mounted=$mounted | ctrlNull=${_ctrl == null}');
      if (mounted && _ctrl != null) {
        _ctrl!.forward();
        _i('postFrameCallback', 'forward() called — animation started ✓');
      } else {
        _iWarn('postFrameCallback — skipping forward() | '
            'mounted=$mounted | ctrlNull=${_ctrl == null}');
        _dumpState('postFrameCallback:skipped');
      }
    });

    _i('initState', 'complete');
  }

  @override
  void dispose() {
    _i(
        'dispose',
        'begin | ctrlNull=${_ctrl == null} | '
            'dismissing=$_dismissing');
    _ctrl?.dispose();
    _ctrl = null;
    _i('dispose', 'complete');
    super.dispose();
  }

  Future<void> _animateOut() async {
    _i(
        'animateOut',
        'called | dismissing=$_dismissing | '
            'mounted=$mounted | ctrlNull=${_ctrl == null}');

    if (_dismissing) {
      _iWarn('animateOut — already dismissing, skipping');
      return;
    }
    if (!mounted) {
      _iWarn('animateOut — not mounted');
      _dumpState('animateOut:notMounted');
      return;
    }
    if (_ctrl == null) {
      _iWarn('animateOut — ctrl null, calling onDismiss directly');
      _dumpState('animateOut:ctrlNull');
      widget.onDismiss();
      return;
    }

    _dismissing = true;
    _i('animateOut', 'starting reverse animation...');

    try {
      await _ctrl!.reverse();
      _i('animateOut', 'reverse complete ✓');
    } catch (e) {
      _iError('animateOut reverse threw', e);
    }

    _i('animateOut',
        'post-await | mounted=$mounted | ctrlNull=${_ctrl == null}');

    if (mounted) {
      _i('animateOut', 'calling widget.onDismiss()');
      widget.onDismiss();
    } else {
      _iWarn('animateOut — not mounted after await, '
          'calling _removeBanner directly');
      _removeBanner();
    }
  }

  @override
  Widget build(BuildContext context) {
    _i(
        'build',
        'called | ctrlNull=${_ctrl == null} | '
            'slideNull=${_slide == null} | '
            'fadeNull=${_fade == null} | '
            'mounted=$mounted | '
            'dragOffset=$_dragOffset');

    if (_ctrl == null || _slide == null || _fade == null) {
      _iWarn('build — animations not ready, returning SizedBox.shrink()');
      return const SizedBox.shrink();
    }

    final double topPad = MediaQuery.of(context).padding.top;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    _i('build', 'topPad=$topPad | isDark=$isDark');

    final Color cardBg = isDark
        ? const Color(0xFF1C1C1E).withOpacity(0.88)
        : Colors.white.withOpacity(0.92);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0D0D0D);
    final Color subtitleColor =
        isDark ? const Color(0xFFAAAAAA) : const Color(0xFF6B6B6B);
    final Color pillColor = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.black.withOpacity(0.08);
    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.09)
        : Colors.black.withOpacity(0.06);

    return Stack(
      children: [
        Positioned(
          top: topPad + 10 + _dragOffset,
          left: 12,
          right: 12,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: (_) {
              _i('drag', 'start | dragOffset=$_dragOffset');
              widget.onDragStart();
            },
            onVerticalDragUpdate: (details) {
              final double next = _dragOffset + details.delta.dy;
              if (next > 8.0) return;
              _safeSetState(
                  'dragUpdate', () => _dragOffset = next.clamp(-300.0, 8.0));
            },
            onVerticalDragEnd: (details) {
              final double? velocity = details.primaryVelocity;
              final bool flung = (velocity ?? 0) < -500;
              _i(
                  'drag',
                  'end | velocity=$velocity | '
                      'flung=$flung | dragOffset=$_dragOffset');
              if (flung || _dragOffset < -72) {
                _i('drag', 'threshold met — dismissing');
                HapticFeedback.lightImpact();
                _animateOut();
              } else {
                _i('drag', 'threshold not met — snapping back');
                _safeSetState('dragEnd:snapBack', () => _dragOffset = 0.0);
              }
            },
            onTap: () {
              _i('tap', 'received — dismissing');
              HapticFeedback.selectionClick();
              _animateOut();
            },
            child: SlideTransition(
              position: _slide!,
              child: FadeTransition(
                opacity: _fade!,
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: borderColor, width: 0.75),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(isDark ? 0.5 : 0.12),
                              blurRadius: 36,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: pillColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    color: pillColor,
                                    child: Icon(
                                      Icons.notifications_rounded,
                                      size: 22,
                                      color: isDark
                                          ? Colors.white.withOpacity(0.75)
                                          : Colors.black.withOpacity(0.55),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'YOUR APP NAME', // ← replace
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                              color: subtitleColor,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            'now',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: subtitleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: titleColor,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: subtitleColor,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ENTRY POINT
// ---------------------------------------------------------------------------

Future<void> triggerSlickNotification(
  BuildContext context,
  String? title,
  String? body,
) async {
  _sLogStep(
      'triggerSlickNotification', 'Called | title="$title" | body="$body"');

  final String resolvedTitle = (title != null && title.trim().isNotEmpty)
      ? title.trim()
      : 'New notification';
  final String resolvedBody =
      (body != null && body.trim().isNotEmpty) ? body.trim() : '';

  _sLogStep('triggerSlickNotification',
      'Resolved | title="$resolvedTitle" | body="$resolvedBody"');

  // Fire haptics immediately for responsiveness.
  try {
    await HapticFeedback.mediumImpact();
    _sLogStep('Haptics', 'mediumImpact fired ✓');
  } catch (e) {
    _sLogWarn('Haptic feedback failed: $e');
  }

  // Defer overlay work to post-frame. FlutterFlow's realtime callbacks can
  // fire mid-build-cycle, which causes overlay insertion to fail silently.
  // addPostFrameCallback guarantees we're outside any build cycle.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    OverlayState? overlay;
    String overlaySource = 'none';

    // Strategy 1 — root navigator overlay.
    // rootNavigator:true walks to the root Navigator which always has an
    // overlay, bypassing any nested GoRouter navigators in FlutterFlow.
    if (context.mounted) {
      try {
        final NavigatorState? nav =
            Navigator.maybeOf(context, rootNavigator: true);
        if (nav != null && nav.overlay != null) {
          overlay = nav.overlay;
          overlaySource = 'rootNavigator.overlay';
          _sLogStep('Overlay', 'Resolved via rootNavigator.overlay ✓');
        }
      } catch (e) {
        _sLogError('Strategy 1 (rootNavigator) threw', e);
      }
    }

    // Strategy 2 — Overlay.maybeOf on provided context.
    if (overlay == null && context.mounted) {
      try {
        final OverlayState? o = Overlay.maybeOf(context);
        if (o != null) {
          overlay = o;
          overlaySource = 'Overlay.maybeOf(context)';
          _sLogStep('Overlay', 'Resolved via Overlay.maybeOf ✓');
        }
      } catch (e) {
        _sLogError('Strategy 2 (Overlay.maybeOf) threw', e);
      }
    } else if (overlay == null) {
      _sLogWarn('Provided context is not mounted — trying fallback');
    }

    // Strategy 3 — primary focus context.
    if (overlay == null) {
      try {
        final BuildContext? fc =
            WidgetsBinding.instance.focusManager.primaryFocus?.context;
        if (fc != null && fc.mounted) {
          final NavigatorState? nav =
              Navigator.maybeOf(fc, rootNavigator: true);
          if (nav != null && nav.overlay != null) {
            overlay = nav.overlay;
            overlaySource = 'focusManager+rootNavigator';
            _sLogStep(
                'Overlay', 'Resolved via focusManager+rootNavigator ✓');
          }
        }
      } catch (e) {
        _sLogError('Strategy 3 (focusManager) threw', e);
      }
    }

    if (overlay == null) {
      _sLogError('All overlay strategies failed — banner cannot show');
      return;
    }

    _sLog('OverlayState resolved via $overlaySource ✓');

    // Remove any existing banner before inserting a new one.
    if (_activeBannerEntry != null) {
      _sLogStep('Overlay', 'Replacing existing banner');
      _activeDismissTimer?.cancel();
      try {
        _activeBannerEntry?.remove();
      } catch (e) {
        _sLogError('Failed to remove existing banner entry', e);
      }
      _activeBannerEntry = null;
    }

    final int instanceId = ++_sBannerInstanceCount;
    _sLogStep(
        'Overlay',
        'Creating _SlickBanner instance #$instanceId | '
            'title="$resolvedTitle" | body="$resolvedBody"');

    _activeBannerEntry = OverlayEntry(
      builder: (_) => _SlickBanner(
        title: resolvedTitle,
        body: resolvedBody,
        instanceId: instanceId,
        onDismiss: _removeBanner,
        onDragStart: _pauseDismissTimer,
      ),
    );

    try {
      overlay!.insert(_activeBannerEntry!);
      _sLog('Banner #$instanceId inserted into overlay ✓');
    } catch (e) {
      _sLogError('overlay.insert() threw — banner not shown', e);
      _activeBannerEntry = null;
      return;
    }

    _activeDismissTimer = Timer(const Duration(seconds: 4), () {
      _sLogStep('AutoDismiss', '4s elapsed — dismissing banner #$instanceId');
      _removeBanner();
    });

    _sLog('Auto-dismiss timer started (4s) for banner #$instanceId ✓');
  });

  // Ensure a frame is scheduled so the postFrameCallback fires even if
  // the app is idle (no ongoing animations or user interaction).
  WidgetsBinding.instance.scheduleFrame();
}
