# CoachSmart — Cleanup & Improvement Backlog

Items are grouped by theme and roughly prioritised within each group.
Legend: `[ ]` todo · `[x]` done · `[~]` blocked

---

## App Store Submission

| # | Item | Notes |
|---|---|---|
| [x] | Privacy Manifest configured in FlutterFlow | Mobile Deployment → Privacy Manifest Configurations — all 5 toggles enabled |
| [x] | Privacy Policy page live | `coachsmart.app/privacy.html` |
| [x] | Terms of Service page live | `coachsmart.app/terms.html` |
| [ ] | Set Privacy Policy URL in App Store Connect | `https://coachsmart.app/privacy.html` |
| [ ] | Set Terms of Service URL in App Store Connect | `https://coachsmart.app/terms.html` |
| [ ] | Complete App Privacy Nutrition Label in App Store Connect | Data types: name, email, DoB (month/year), attendance data |
| [ ] | Add Privacy Policy + Terms link on FlutterFlow Auth_Page | Text: "By continuing, you agree to our Terms of Service and Privacy Policy" |
| [ ] | Upload App Store screenshots | 6.7" (iPhone 15 Pro Max) and 6.1" (iPhone 15) minimum |
| [ ] | Add App Review test account in App Store Connect | Needs working Supabase login — create a test member account |
| [ ] | Apple Distribution Certificate renewal | Valid ~30 days from session start; FlutterFlow should auto-renew on next deploy |

---

## Performance

| # | Item | Notes |
|---|---|---|
| [ ] | Pre-aggregate attendance summary table | Replace `eligible_attendees` → `latest_attendance_records` → `attendance_summary` CTE chain in `get_user_home_events` with a trigger-maintained `event_attendance_summary` table. Currently 50% of all DB compute. See design note below. |
| [ ] | Add composite index on `event_user_member_payment` | `CREATE INDEX ON event_user_member_payment(event_id, user_id) WHERE payment_status = 'confirmed'` — removes per-event correlated subquery scan in `get_user_home_events` |
| [ ] | Identify what is calling `get_member_match_stats_detail` | 605ms average, 2.2s max, called as `anon` (no JWT). In the "candidate for removal" list. Stop the caller then drop the function. |
| [ ] | Review realtime subscription volume | Realtime `list_changes` is 35% of DB compute across 2.5M calls. Review whether all active subscriptions are necessary. |

### Attendance Summary Table — Design Note
Create `public.event_attendance_summary(event_id, eligible_count, accepted_count, declined_count, no_response_count, updated_at)`.
Populate via trigger on `event_attendance` INSERT/UPDATE/DELETE and on `member_team_link` INSERT/DELETE (eligible_count changes when roster changes).
`get_user_home_events` replaces the three heavy CTEs with a single LEFT JOIN to this table. Counts are exact and updated atomically in the same transaction as the change.

---

## Security (pre-App Store / pre-scale)

| # | Item | Notes |
|---|---|---|
| [x] | Pin `search_path` on all SECURITY DEFINER functions | Migration `20260521140722` |
| [~] | Enforce `auth.uid()` on 13 "my data" RPC functions | Rolled back — PWA doesn't send JWT. Re-apply after PWA republished (`20260521160000`). Rollback is `20260521170000`. |
| [ ] | Team-membership guard on event-based RPCs | Prevents users accessing events for teams they're not on |
| [ ] | JWT validation on 9 HIGH-risk edge functions | `send-push-notification`, `create-checkout-session`, `stripe-webhook-listener`, `create_stripe_payment_intent`, `send-email`, `get-google-token`, `create_google_sheet_squads`, `event_email_reminder`, `event_match_report_email` |
| [ ] | Drop 29 unused DB views | Confirm none are referenced then drop in a single migration |
| [ ] | Replace `view_match_squads` in 3 export edge functions then drop | Last active view — used by `create_google_sheet_squads` and 2 others |
| [ ] | Fix open relay on `send-email` edge function | Currently no auth check — any caller can send email via CoachSmart |
| [ ] | Fix `get-google-token` — accessible without authentication | |

---

## Database Cleanup

| # | Item | Notes |
|---|---|---|
| [ ] | Resolve `date_of_birth` conflict | Column is used by a webview team sheet printer. Privacy policy currently says "month and year only" — these are inconsistent. Decide: (A) keep full DoB and update privacy policy + App Store nutrition label, or (B) truncate to month/year and update the webview. DO NOT drop the column until resolved. |
| [ ] | Drop `phone_number` from `users` | Referenced in active RPCs (`get_user_event_create_detail`, `get_user_event_edit_detail`, `get_user_team_summary`) and views. Must update RPC RETURNS TABLE + FlutterFlow data types first. |
| [ ] | Drop `profile_pic` from `members` and `teams` | Referenced in 5 RPC RETURNS TABLE signatures and multiple views. Coordinate with FlutterFlow data type removal first. |
| [ ] | Delete `main-push` branch on GitHub | Redundant — all commits already in `main` |
| [ ] | Review hardcoded `service_role` JWT in `check_and_send_notifications()` | Deferred by owner — flagged as known issue |

---

## Notification Banner

| # | Item | Notes |
|---|---|---|
| [ ] | Investigate EventDetails page auto-read logic | All new notifications arrive with `is_read=true` by the time the stream fires. Likely an `onLoad` action in FlutterFlow's EventDetails page marking them read. Fix: either change the banner skip condition from `is_read` to `is_delivered`, or remove the auto-read action. |
| [ ] | Test banner with genuinely fresh notification | Once auto-read issue is resolved, create a new event to trigger a notification and confirm banner appears |

---

## RPC Cleanup (post-PWA republish)

Functions confirmed as never called from the app — safe to drop once PWA is republished and confirmed:
`get_user_clubs`, `get_event_attendance_summary_by_role_and_squad`, `get_event_attendance_details`, `get_event_context_and_next_code`, `get_single_user_event`, `create_match_squad_from_attendance`, `create_new_member_by_code`, `populate_event_notifications`, `get_member_match_stats`, `get_member_match_stats_detail`

---

## PWA

| # | Item | Notes |
|---|---|---|
| [ ] | Republish PWA from FlutterFlow | Months behind native app. Required before re-applying Fix 2 (auth.uid enforcement) and before anon-role API calls can be fixed. |

---

*Last updated: 2026-05-28*
