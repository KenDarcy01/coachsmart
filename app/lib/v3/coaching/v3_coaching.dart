// How the Coaching pieces open each other (Ken approved the Coaching tab
// 2026-11-11): the tab, the one plan builder, the "add games" picker and an
// event's Session plan button. Pages take these as callbacks so each can be
// tested alone; this file is the one place that joins them.
import 'package:flutter/material.dart';

import 'v3_coaching_page.dart';
import 'v3_event_plan_entry.dart';
import 'v3_plan_builder_page.dart';
import 'v3_plans_view.dart';

/// The Coaching tab: Games and Plans. [initialTab] 1 opens on Plans.
class V3Coaching extends StatelessWidget {
  const V3Coaching({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) => V3CoachingPage(
        initialTab: initialTab,
        onOpenPlan: openPlanBuilder,
        plansBuilder: (_) => const V3PlansView(onNewPlan: openPlanBuilder),
      );
}

/// The games list as a picker: + adds to the plan in progress, Done returns.
void openGamePicker(BuildContext context) {
  Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const V3CoachingPage(pickMode: true)));
}

/// The one plan builder, for the plan in progress.
void openPlanBuilder(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const V3PlanBuilderPage(onAddGames: openGamePicker)));
}

/// An event's Session plan button: the event's plan, or the three ways to
/// start one.
Future<void> openCoachingEventPlan(BuildContext context, int eventId) =>
    openEventPlan(context, eventId: eventId, onAddGames: openGamePicker);
