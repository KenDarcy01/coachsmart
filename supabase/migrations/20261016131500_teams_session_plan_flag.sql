-- Team-level switch for the AI session planner on the event details page.
--   teams.session_plan : FlutterFlow shows the event session plan button when true;
--                        session-plan.html shows "not switched on" for teams without it
--                        (existing plans still open; users.ai_features also allows it).
-- Off by default, so no existing team changes. Teamsheets keep using teams.teamsheet.

ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS session_plan boolean NOT NULL DEFAULT false;
