-- Two fixes:
--
-- 1. Replace USING (true) on match_squads and match_squad_details with
--    team-membership checks. Any authenticated user who belongs to the team
--    that owns the event can read and write that event's squads.
--    This prevents a signed-in user from another club accessing squad data.
--
-- 2. Revoke EXECUTE from anon on write RPCs that should never be callable
--    without authentication (PWA does not call these — they are admin/management
--    operations that require a signed-in session).

-- ─── 1a. match_squads ─────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Authenticated users can manage match_squads" ON public.match_squads;

CREATE POLICY "team_member_can_manage_match_squads"
    ON public.match_squads
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.events e
            JOIN public.member_team_link mtl ON mtl.team_id = e.team_id
            JOIN public.user_member_link uml ON uml.member_id = mtl.member_id
            WHERE e.event_id = match_squads.event_id
              AND uml.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.events e
            JOIN public.member_team_link mtl ON mtl.team_id = e.team_id
            JOIN public.user_member_link uml ON uml.member_id = mtl.member_id
            WHERE e.event_id = match_squads.event_id
              AND uml.user_id = auth.uid()
        )
    );

-- ─── 1b. match_squad_details ──────────────────────────────────────────────────
-- team_id is a direct column on this table; fall back to joining through
-- match_squads → events for any rows where team_id is NULL.

DROP POLICY IF EXISTS "Authenticated users can manage match_squad_details" ON public.match_squad_details;

CREATE POLICY "team_member_can_manage_match_squad_details"
    ON public.match_squad_details
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.member_team_link mtl
            JOIN public.user_member_link uml ON uml.member_id = mtl.member_id
            WHERE mtl.team_id = match_squad_details.team_id
              AND uml.user_id = auth.uid()
        )
        OR (
            match_squad_details.team_id IS NULL
            AND EXISTS (
                SELECT 1
                FROM public.match_squads ms
                JOIN public.events e ON e.event_id = ms.event_id
                JOIN public.member_team_link mtl ON mtl.team_id = e.team_id
                JOIN public.user_member_link uml ON uml.member_id = mtl.member_id
                WHERE ms.match_squad_id = match_squad_details.match_squad_id
                  AND uml.user_id = auth.uid()
            )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.member_team_link mtl
            JOIN public.user_member_link uml ON uml.member_id = mtl.member_id
            WHERE mtl.team_id = match_squad_details.team_id
              AND uml.user_id = auth.uid()
        )
        OR (
            match_squad_details.team_id IS NULL
            AND EXISTS (
                SELECT 1
                FROM public.match_squads ms
                JOIN public.events e ON e.event_id = ms.event_id
                JOIN public.member_team_link mtl ON mtl.team_id = e.team_id
                JOIN public.user_member_link uml ON uml.member_id = mtl.member_id
                WHERE ms.match_squad_id = match_squad_details.match_squad_id
                  AND uml.user_id = auth.uid()
            )
        )
    );

-- ─── 2. Revoke EXECUTE from anon on dangerous write RPCs ──────────────────────
-- remove_member_from_team had GRANT ALL to anon in the baseline schema and was
-- re-granted three times — this is the live exposure that needs closing.
-- create_recurring_events has no explicit anon grant but inherits default
-- privileges; revoke it defensively.
-- confirm_member_join and deny_member_join have multiple overloads and were
-- never granted to anon — no revoke needed for those.

REVOKE EXECUTE ON FUNCTION public.remove_member_from_team(bigint, bigint) FROM anon;
REVOKE EXECUTE ON FUNCTION public.create_recurring_events     FROM anon;
