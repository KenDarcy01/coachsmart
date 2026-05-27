# CoachSmart — AI Session Briefing

## What This App Is
CoachSmart is a **GAA (Gaelic Athletic Association) coaching management app** for ~1,000 active users. It manages events, attendance, car pools, match squads, match reports, team rosters, notifications, and payments for GAA clubs across Ireland.

## Two App Surfaces
| Surface | Tech | Status |
|---|---|---|
| Native iOS | FlutterFlow → TestFlight | Active dev / latest build |
| PWA | FlutterFlow web build → Firebase Hosting | Months behind; being updated |

The PWA is deployed automatically when code is pushed to `main` via `.github/workflows/firebase-deploy.yml` (Firebase project: `coach-smart-new-mpqa5l`).

## Git Workflow
- **Develop on**: `claude/review-coachsmart-repo-HHk5i`
- **Deploy via**: `main` (Firebase auto-deploys on push to main; Supabase migrations applied manually via `supabase db push`)
- Always merge working branch → main after commits

## Branch Structure — IMPORTANT
| Branch | Owner | Contents |
|---|---|---|
| `main` | Us | `supabase/`, edge functions, migrations, `flutterflow/` subfolder (PWA build source, may lag) |
| `flutterflow` | FlutterFlow | Flutter project at **root** — `lib/`, `ios/`, `pubspec.yaml` etc. This is the authoritative Flutter source |

**Rules:**
- FlutterFlow pushes to `flutterflow` branch — never delete this branch
- Custom Dart code lives at `lib/custom_code/` on the `flutterflow` branch (NOT `flutterflow/lib/` on `main`)
- Never commit directly to the `flutterflow/` subfolder on `main` — it only drives the PWA Firebase build and will lag behind
- Supabase migrations and edge functions are committed to `main` only

## Stack
- **Frontend**: FlutterFlow (Dart/Flutter) — source in `flutterflow/`
- **Backend**: Supabase (PostgreSQL + Auth + Storage)
- **Edge Functions**: 20 Deno/TypeScript functions in `supabase/functions/`
- **Hosting**: Firebase Hosting (website + PWA)
- **Migrations**: `supabase/migrations/` — apply with `supabase db push` from Codespace

## Key Integrations
- **Stripe**: Payments for club events (`create-checkout-session`, `stripe-webhook-listener`, `create_stripe_payment_intent`)
- **Firebase FCM**: Push notifications (`send-push-notification`, `cron_push_batch_notifications`, `trigger-push-notification`)
- **Google Sheets**: Export match squads (`create_google_sheet_squads`, `get-google-token`)
- **Email**: Event reminders + match reports + attendance change alerts (`event_email_reminder`, `event_match_report_email`, `send-email`, `send-change-of-attendance`)
- **pg_cron**: Scheduled notification dispatch (`check_and_send_notifications` → `cron_batch_notification_send`)

## Database Schema (Key Tables)
```
users ──< user_member_link >── members ──< member_team_link >── teams ──< clubs
                                                 │
                                    member_team_role_link → roles
                                    member_squad_link → squads
                                                 │
teams ──< events ──< event_attendance (member responses)
events ──< match_squads ──< match_squad_details
events ──< car_pool ──< car_pool_detail
events ──< match_reports ──< match_scores
users ──< notifications
```

Full table list: `clubs`, `teams`, `events`, `event_types`, `event_codes`, `event_attendance`, `event_response_type`, `members`, `users`, `user_member_link`, `member_team_link`, `member_team_role_link`, `roles`, `squads`, `member_squad_link`, `car_pool`, `car_pool_detail`, `notifications`, `reminders`, `match_squads`, `match_squad_details`, `match_reports`, `match_scores`, `match_scores_details`, `match_score_types`, `games`, `game_ages`, `invitations`, `legacy_users`, `event_user_payment`, `event_user_member_payment`, `sport`, `team_roles_link`, `club_code_link`.

## Role System
Roles have a `role_level` and `role_grade`. Grade 100 = admin/management, grade 10 = player/athlete. `role_level` determines what data a user can see within the team hierarchy.

## RPC Functions (31 total — all SECURITY DEFINER)
All functions have `SET search_path = 'public'` pinned (migration `20260521140722`).

**Actively called from app:**
`get_user_home_events`, `get_user_event_details`, `get_team_members_by_role`, `get_user_notifications`, `get_event_car_pools`, `get_user_event_create_detail`, `get_event_attendance_by_role`, `get_event_attendance_by_role_v2`, `get_event_attendance_summary_by_role_and_squad_v2`, `get_event_attendance_summary_by_role`, `get_events_list`, `get_full_car_pool_details`, `get_event_admin_detail`, `get_user_team_summary`, `get_user_event_edit_detail`, `get_updated_event_code`

**Infrastructure only (pg_cron / triggers / RLS):**
`check_and_send_notifications`, `handle_new_user`, `notify_admins_attendance_change`, `is_owner_of_member_team_role`

**Called from edge functions:**
`get_unresponded_events`, `get_unresponded_events_v2`

**Candidate for removal (wrapper defined, never invoked):**
`get_user_clubs (parameterised)`, `get_event_attendance_summary_by_role_and_squad`, `get_event_attendance_details`, `get_event_context_and_next_code`, `get_single_user_event`, `create_match_squad_from_attendance`, `create_new_member_by_code`, `populate_event_notifications`, `get_member_match_stats`, `get_member_match_stats_detail`

## Security Work In Progress (pre-App Store)
| # | Fix | Status |
|---|---|---|
| 1 | Pin `search_path` on all SECURITY DEFINER functions | **Done** (migration `20260521140722`) |
| 2 | Enforce `auth.uid()` on 13 "my data" RPC functions | **Rolled back** — PWA doesn't send JWT. Re-apply after PWA update (`20260521160000`). Rollback is `20260521170000`. |
| 3 | Team-membership guard on event-based RPCs | Pending |
| 4 | JWT validation on 9 HIGH-risk edge functions | Pending |
| 5 | Drop 30 unused DB views | Pending |
| 6 | Replace `view_match_squads` in 3 export edge functions + drop | Pending |

## Known Issues / Deferred
- Hardcoded `service_role` JWT in `check_and_send_notifications()` — deferred by owner
- `send-email` edge function is an open relay (no auth check)
- `get-google-token` accessible without authentication

## Important Constraints
- **Production app with ~1,000 users** — all migrations must be safe and non-breaking
- PWA is months behind native app — any change that relies on JWT auth breaks PWA until it is republished
- Goal: **no DB views** (31 exist; only `view_match_squads` is in active use)
- Goal: **clean RLS** before App Store submission
