import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';

import '/backend/supabase/supabase.dart';

import '/auth/supabase_auth/auth_util.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

import '/index.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  BaseAuthUser? initialUser;
  BaseAuthUser? user;
  bool showSplashImage = true;
  String? _redirectLocation;

  /// Determines whether the app will refresh and build again when a sign
  /// in or sign out happens. This is useful when the app is launched or
  /// on an unexpected logout. However, this must be turned off when we
  /// intend to sign in/out and then navigate or perform any actions after.
  /// Otherwise, this will trigger a refresh and interrupt the action(s).
  bool notifyOnAuthChange = true;

  bool get loading => user == null || showSplashImage;
  bool get loggedIn => user?.loggedIn ?? false;
  bool get initiallyLoggedIn => initialUser?.loggedIn ?? false;
  bool get shouldRedirect => loggedIn && _redirectLocation != null;

  String getRedirectLocation() => _redirectLocation!;
  bool hasRedirect() => _redirectLocation != null;
  void setRedirectLocationIfUnset(String loc) => _redirectLocation ??= loc;
  void clearRedirectLocation() => _redirectLocation = null;

  /// Mark as not needing to notify on a sign in / out when we intend
  /// to perform subsequent actions (such as navigation) afterwards.
  void updateNotifyOnAuthChange(bool notify) => notifyOnAuthChange = notify;

  void update(BaseAuthUser newUser) {
    final shouldUpdate =
        user?.uid == null || newUser.uid == null || user?.uid != newUser.uid;
    initialUser ??= newUser;
    user = newUser;
    // Refresh the app on auth change unless explicitly marked otherwise.
    // No need to update unless the user has changed.
    if (notifyOnAuthChange && shouldUpdate) {
      notifyListeners();
    }
    // Once again mark the notifier as needing to update on auth change
    // (in order to catch sign in / out events).
    updateNotifyOnAuthChange(true);
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

GoRouter createRouter(AppStateNotifier appStateNotifier) => GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: appStateNotifier,
      navigatorKey: appNavigatorKey,
      errorBuilder: (context, state) =>
          appStateNotifier.loggedIn ? V3HomePage() : V3SignInPage(),
      routes: [
        FFRoute(
          name: '_initialize',
          path: '/',
          builder: (context, _) =>
              appStateNotifier.loggedIn ? V3HomePage() : V3SignInPage(),
          routes: [
            // v3 sign-in screens replace the FlutterFlow Auth_Page and
            // ForgotPassword pages on the same routes (2026-11-09).
            FFRoute(
              name: V3SignInPage.routeName,
              path: V3SignInPage.routePath,
              builder: (context, params) => V3SignInPage(),
            ),
            FFRoute(
              name: V3CreateAccountPage.routeName,
              path: V3CreateAccountPage.routePath,
              builder: (context, params) => V3CreateAccountPage(),
            ),
            FFRoute(
              name: V3VerifyPage.routeName,
              path: V3VerifyPage.routePath,
              builder: (context, params) => V3VerifyPage(
                email: params.getParam('email', ParamType.String) ?? '',
                first: params.getParam('first', ParamType.String) ?? '',
                last: params.getParam('last', ParamType.String) ?? '',
              ),
            ),
            FFRoute(
              name: GamesAgesWidget.routeName,
              path: GamesAgesWidget.routePath,
              builder: (context, params) => GamesAgesWidget(),
            ),
            FFRoute(
              name: GamesWidget.routeName,
              path: GamesWidget.routePath,
              builder: (context, params) => GamesWidget(
                gameAge: params.getParam(
                  'gameAge',
                  ParamType.String,
                ),
                gameAgeDescription: params.getParam(
                  'gameAgeDescription',
                  ParamType.String,
                ),
              ),
            ),
            FFRoute(
              name: V3MemberPage.routeName,
              path: V3MemberPage.routePath,
              builder: (context, params) => V3MemberPage(
                memberId: params.getParam('memberID', ParamType.int) ?? 0,
                teamId: params.getParam('teamID', ParamType.int) ?? 0,
              ),
            ),
            FFRoute(
              name: V3TeamsPage.routeName,
              path: V3TeamsPage.routePath,
              builder: (context, params) => V3TeamsPage(),
            ),
            FFRoute(
              name: CreateTeamWidget.routeName,
              path: CreateTeamWidget.routePath,
              builder: (context, params) => CreateTeamWidget(),
            ),
            FFRoute(
              name: JoinTeamWidget.routeName,
              path: JoinTeamWidget.routePath,
              builder: (context, params) => JoinTeamWidget(
                pageParamJoiningCode: params.getParam(
                  'pageParamJoiningCode',
                  ParamType.String,
                ),
              ),
            ),
            FFRoute(
              name: SelectTeamsWidget.routeName,
              path: SelectTeamsWidget.routePath,
              builder: (context, params) => SelectTeamsWidget(),
            ),
            FFRoute(
                name: UserMemberDetailsWidget.routeName,
                path: UserMemberDetailsWidget.routePath,
                builder: (context, params) =>
                    const V3ProfilePage() // v3: members live on the profile page,
                ),
            FFRoute(
              name: ValidatePageWidget.routeName,
              path: ValidatePageWidget.routePath,
              builder: (context, params) => ValidatePageWidget(
                varEmailAddress: params.getParam(
                  'varEmailAddress',
                  ParamType.String,
                ),
              ),
            ),
            FFRoute(
              name: V3ResetPasswordPage.routeName,
              path: V3ResetPasswordPage.routePath,
              builder: (context, params) => V3ResetPasswordPage(
                email: params.getParam('email', ParamType.String) ?? '',
              ),
            ),
            FFRoute(
                name: UpdatePasswordWidget.routeName,
                path: UpdatePasswordWidget.routePath,
                builder: (context, params) =>
                    const V3ChangePasswordPage() // v3,
                ),
            FFRoute(
              name: MatchReportWidget.routeName,
              path: MatchReportWidget.routePath,
              builder: (context, params) => V3MatchReportPage(
                  eventId: params.getParam('paramEventID', ParamType.int) ??
                      0), // v3
            ),
            FFRoute(
              name: MatchReportDetailWidget.routeName,
              path: MatchReportDetailWidget.routePath,
              builder: (context, params) => MatchReportDetailWidget(
                rowMatchReport: params.getParam<ViewMatchReportsRow>(
                  'rowMatchReport',
                  ParamType.SupabaseRow,
                ),
              ),
            ),
            FFRoute(
              name: V3TeamPage.routeName,
              path: V3TeamPage.routePath,
              builder: (context, params) => V3TeamPage(
                teamId: params.getParam('teamID', ParamType.int) ?? 0,
              ),
            ),
            FFRoute(
              name: AttendeeListWidget.routeName,
              path: AttendeeListWidget.routePath,
              // v3: one attendance page for every attendee list.
              builder: (context, params) => V3AttendancePage(
                eventId: params.getParam('eventID', ParamType.int) ?? 0,
                responseId: params.getParam('responseID', ParamType.int),
              ),
            ),
            FFRoute(
                name: EditUserWidget.routeName,
                path: EditUserWidget.routePath,
                builder: (context, params) =>
                    const V3ProfilePage() // v3 profile page,
                ),
            FFRoute(
              name: CheckoutSuccessWidget.routeName,
              path: CheckoutSuccessWidget.routePath,
              builder: (context, params) => V3CheckoutSuccessPage(
                stripeSessionId:
                    params.getParam('stripeSessionId', ParamType.String) ?? '',
              ),
            ),
            FFRoute(
              name: CheckoutFailedWidget.routeName,
              path: CheckoutFailedWidget.routePath,
              builder: (context, params) => const V3CheckoutFailedPage(),
            ),
            FFRoute(
              name: CheckoutWidget.routeName,
              path: CheckoutWidget.routePath,
              builder: (context, params) => V3CheckoutPage(
                eventId: params.getParam('paramEventId', ParamType.int) ?? 0,
                numPayments:
                    params.getParam('paramNumPayments', ParamType.int) ?? 0,
                paymentAmount:
                    params.getParam('paramPaymentAmount', ParamType.int) ?? 0,
                checkoutUrl:
                    params.getParam('paramCheckoutUrl', ParamType.String) ?? '',
                payingMembers: params.getParam<dynamic>(
                      'paramPayingMembers',
                      ParamType.JSON,
                      isList: true,
                    ) ??
                    const [],
              ),
            ),
            FFRoute(
              name: UnpaidTransactionsWidget.routeName,
              path: UnpaidTransactionsWidget.routePath,
              builder: (context, params) => V3PaymentsPage(
                eventId: params.getParam('paramEventID', ParamType.int) ?? 0,
              ),
            ),
            FFRoute(
              name: PaymentTransactionsWidget.routeName,
              path: PaymentTransactionsWidget.routePath,
              builder: (context, params) => V3PaymentsPage(
                eventId: params.getParam('paramEventID', ParamType.int) ?? 0,
                title: params.getParam('eventTitle', ParamType.String),
              ),
            ),
            FFRoute(
              name: SearchPageWidget.routeName,
              path: SearchPageWidget.routePath,
              builder: (context, params) => const V3SearchPage(),
            ),
            FFRoute(
              name: V3EventFormPage.createRouteName,
              path: V3EventFormPage.createRoutePath,
              builder: (context, params) => V3EventFormPage(),
            ),
            FFRoute(
              name: V3EventFormPage.editRouteName,
              path: V3EventFormPage.editRoutePath,
              builder: (context, params) => V3EventFormPage(
                eventId: params.getParam('paramEventId', ParamType.int),
              ),
            ),
            FFRoute(
              name: AdminOptionsWidget.routeName,
              path: AdminOptionsWidget.routePath,
              builder: (context, params) => AdminOptionsWidget(
                eventID: params.getParam(
                  'eventID',
                  ParamType.int,
                ),
              ),
            ),
            FFRoute(
              name: CreateCarPoolWidget.routeName,
              path: CreateCarPoolWidget.routePath,
              builder: (context, params) => V3CarPoolsPage(
                eventId: params.getParam('paramEventID', ParamType.int) ?? 0,
                roleLevel:
                    params.getParam('paramRoleLevel', ParamType.int) ?? 0,
              ),
            ),
            FFRoute(
              name: CarPoolDetailsWidget.routeName,
              path: CarPoolDetailsWidget.routePath,
              builder: (context, params) => V3CarPoolPage(
                eventId: params.getParam('eventID', ParamType.int) ?? 0,
                carPoolId: params.getParam('carPoolId', ParamType.int) ?? 0,
              ),
            ),
            FFRoute(
              name: NotificationDetailsWidget.routeName,
              path: NotificationDetailsWidget.routePath,
              builder: (context, params) => NotificationDetailsWidget(
                paramNotificationID: params.getParam(
                  'paramNotificationID',
                  ParamType.int,
                ),
              ),
            ),
            FFRoute(
              name: AttendeeListAdminsWidget.routeName,
              path: AttendeeListAdminsWidget.routePath,
              // v3: one attendance page for every attendee list.
              builder: (context, params) => V3AttendancePage(
                eventId: params.getParam('eventID', ParamType.int) ?? 0,
                responseId: params.getParam('responseID', ParamType.int),
              ),
            ),
            FFRoute(
              name: TeamSelectorWidget.routeName,
              path: TeamSelectorWidget.routePath,
              builder: (context, params) => TeamSelectorWidget(
                eventId: params.getParam(
                  'eventId',
                  ParamType.int,
                ),
                teamId: params.getParam(
                  'teamId',
                  ParamType.int,
                ),
                squadId: params.getParam(
                  'squadId',
                  ParamType.int,
                ),
                currentAuthToken: params.getParam(
                  'currentAuthToken',
                  ParamType.String,
                ),
              ),
            ),
            FFRoute(
              name: AnalyticsWidget.routeName,
              path: AnalyticsWidget.routePath,
              builder: (context, params) => const V3AnalyticsPage(), // v3
            ),
            FFRoute(
              name: GameDetailsWidget.routeName,
              path: GameDetailsWidget.routePath,
              builder: (context, params) => GameDetailsWidget(
                gameRow: params.getParam<GamesRow>(
                  'gameRow',
                  ParamType.SupabaseRow,
                ),
              ),
            ),
            FFRoute(
              name: FavouritesWidget.routeName,
              path: FavouritesWidget.routePath,
              builder: (context, params) => const V3FavouritesPage(), // v3
            ),
            FFRoute(
              name: MatchScoreWidget.routeName,
              path: MatchScoreWidget.routePath,
              builder: (context, params) => V3ScoreKeeperPage(
                eventId: params.getParam('eventId', ParamType.int) ?? 0,
              ), // v3
            ),
            FFRoute(
              name: OnBoardingWidget.routeName,
              path: OnBoardingWidget.routePath,
              builder: (context, params) => const V3OnboardingPage(), // v3
            ),
            FFRoute(
              name: PendingRequestsWidget.routeName,
              path: PendingRequestsWidget.routePath,
              builder: (context, params) => V3RequestsPage(
                teamId: params.getParam('paramTeamID', ParamType.int) ?? 0,
              ),
            ),
            FFRoute(
              name: JoinTeamNewWidget.routeName,
              path: JoinTeamNewWidget.routePath,
              builder: (context, params) => const V3JoinTeamPage(), // v3
            ),
            FFRoute(
              name: MatchStatsWidget.routeName,
              path: MatchStatsWidget.routePath,
              builder: (context, params) => V3MatchStatsPage(
                eventId: params.getParam('eventId', ParamType.int) ?? 0,
                teamId: params.getParam('teamId', ParamType.int),
              ), // v3
            ),
            FFRoute(
              name: MemberAnalyticsWidget.routeName,
              path: MemberAnalyticsWidget.routePath,
              builder: (context, params) => V3MemberStatsPage(
                  memberId:
                      params.getParam('memberId', ParamType.int) ?? 0), // v3
            ),
            FFRoute(
              name: NotificationsWidget.routeName,
              path: NotificationsWidget.routePath,
              // v3 notifications page on the v2 route name.
              builder: (context, params) => const V3NotificationsPage(),
            ),
            FFRoute(
              name: CreateTeamNewWidget.routeName,
              path: CreateTeamNewWidget.routePath,
              builder: (context, params) => const V3CreateTeamPage(), // v3
            ),
            FFRoute(
              name: EventDetailsWidget.routeName,
              path: EventDetailsWidget.routePath,
              builder: (context, params) => V3EventPage(
                eventID: params.getParam(
                  'eventID',
                  ParamType.int,
                ),
                fromSearch: params.getParam(
                  'fromSearch',
                  ParamType.bool,
                ),
              ),
            ),
            FFRoute(
              name: V3HomePage.routeName,
              path: V3HomePage.routePath,
              builder: (context, params) => V3HomePage(),
            ),
            FFRoute(
              name: ResourcesWidget.routeName,
              path: ResourcesWidget.routePath,
              builder: (context, params) => const V3ResourcesPage(), // v3
            ),
            FFRoute(
              name: ResourcesAddWidget.routeName,
              path: ResourcesAddWidget.routePath,
              builder: (context, params) => ResourcesAddWidget(
                currentAuthToken: params.getParam(
                  'currentAuthToken',
                  ParamType.String,
                ),
              ),
            ),
            FFRoute(
              name: SessionPlannerWidget.routeName,
              path: SessionPlannerWidget.routePath,
              builder: (context, params) => V3SessionPlanPage(
                eventId: params.getParam('pEventId', ParamType.int),
              ), // v3
            ),
            FFRoute(
              name: FavouritesNewWidget.routeName,
              path: FavouritesNewWidget.routePath,
              builder: (context, params) => const V3FavouritesPage(), // v3
            ),
            FFRoute(
              name: MatchReportNewWidget.routeName,
              path: MatchReportNewWidget.routePath,
              builder: (context, params) => V3MatchReportPage(
                  eventId: params.getParam('paramEventId', ParamType.int) ??
                      0), // v3
            ),
            FFRoute(
              name: LiveUpdatesWidget.routeName,
              path: LiveUpdatesWidget.routePath,
              // Live match alerts push /liveUpdate?eventID=<id>.
              builder: (context, params) => V3MatchLivePage(
                  eventId: params.getParam('paramEventId', ParamType.int) ??
                      params.getParam('eventID', ParamType.int) ??
                      0), // v3
            )
          ].map((r) => r.toRoute(appStateNotifier)).toList(),
        ),
      ].map((r) => r.toRoute(appStateNotifier)).toList(),
      observers: ffNavigatorObservers,
    );

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void goNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : goNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void pushNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : pushNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void safePop() {
    // If there is only one route on the stack, navigate to the initial
    // page instead of popping.
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension GoRouterExtensions on GoRouter {
  AppStateNotifier get appState => AppStateNotifier.instance;
  void prepareAuthEvent([bool ignoreRedirect = false]) =>
      appState.hasRedirect() && !ignoreRedirect
          ? null
          : appState.updateNotifyOnAuthChange(false);
  bool shouldRedirect(bool ignoreRedirect) =>
      !ignoreRedirect && appState.hasRedirect();
  void clearRedirectLocation() => appState.clearRedirectLocation();
  void setRedirectLocationIfUnset(String location) =>
      appState.updateNotifyOnAuthChange(false);
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap =>
      extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  // Parameters are empty if the params map is empty or if the only parameter
  // present is the special extra parameter reserved for the transition info.
  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 &&
          state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map(
          (param) async {
            final doc = await asyncParams[param.key]!(param.value)
                .onError((_, __) => null);
            if (doc != null) {
              futureParamValues[param.key] = doc;
              return true;
            }
            return false;
          },
        ),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(
    String paramName,
    ParamType type, {
    bool isList = false,
    List<String>? collectionNamePath,
    StructBuilder<T>? structBuilder,
  }) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) {
      return null;
    }
    final param = state.allParams[paramName];
    // Got parameter from `extras`, so just directly return it.
    if (param is! String) {
      return param;
    }
    // Return serialized value.
    return deserializeParam<T>(
      param,
      type,
      isList,
      collectionNamePath: collectionNamePath,
      structBuilder: structBuilder,
    );
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        redirect: (context, state) {
          if (appStateNotifier.shouldRedirect) {
            final redirectLocation = appStateNotifier.getRedirectLocation();
            appStateNotifier.clearRedirectLocation();
            return redirectLocation;
          }

          if (requireAuth && !appStateNotifier.loggedIn) {
            appStateNotifier.setRedirectLocationIfUnset(state.uri.toString());
            return '/authPage';
          }
          return null;
        },
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = FFParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);
          final child = appStateNotifier.loading
              ? Center(
                  child: SizedBox(
                    width: 50.0,
                    height: 50.0,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        FlutterFlowTheme.of(context).coachSmartGreen,
                      ),
                    ),
                  ),
                )
              : page;

          final transitionInfo = state.transitionInfo;
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  name: state.name,
                  child: child,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ),
                )
              : MaterialPage(
                  key: state.pageKey, name: state.name, child: child);
        },
        routes: routes,
      );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage &&
        location != '/' &&
        location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
