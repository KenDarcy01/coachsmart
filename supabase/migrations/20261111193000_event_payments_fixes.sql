-- Event payment fixes (Ken, 2026-11-11, thread "Check payments on the v3 screens").
--
-- 1. A child counts as paid when ANYONE has paid for them. Until now
--    get_user_event_details only looked at payments the viewing parent made,
--    so a second parent still saw the Pay button and paid again (it happened
--    for event 475). A confirmed payment also always wins over a later
--    expired or failed checkout.
-- 2. get_accepted_unpaid_members (admin Not paid list, reminders) gets the
--    same "confirmed wins" rule.
-- 3. The Home "Paid" tag only shows when every attending player you look
--    after is paid for, not when any one of them is.
-- 4. Payment reminders show the event time in Irish time, not UTC.
-- 5. Payments switched on for the real teams that have taken payments, so
--    their admins can set a price in the v3 event form.
--
-- The functions are patched in place (find and replace on the live
-- definition) so other recent changes to them are kept. Each patch stops the
-- migration if the text it expects is not there.

DO $migration$
DECLARE
    v_def text;
    v_new text;

BEGIN
    ---------------------------------------------------------------- 1
    SELECT pg_get_functiondef('public.get_user_event_details(bigint, uuid)'::regprocedure) INTO v_def;
    v_new := replace(v_def,
        'AND eump.user_id = p_user_id AND eump.payment_status <> ''pending''',
        'AND eump.payment_status <> ''pending''');
    v_new := replace(v_new,
        'PARTITION BY eump.member_id ORDER BY eump.created_at DESC) as rn',
        'PARTITION BY eump.member_id ORDER BY (eump.payment_status = ''confirmed'') DESC, eump.created_at DESC) as rn');
    IF v_new = v_def OR position('(eump.payment_status = ''confirmed'') DESC' in v_new) = 0
       OR position('eump.user_id = p_user_id' in v_new) > 0 THEN
        RAISE EXCEPTION 'get_user_event_details: payment text not found, not patched';
    END IF;
    EXECUTE v_new;

    ---------------------------------------------------------------- 2
    SELECT pg_get_functiondef('public.get_accepted_unpaid_members(bigint)'::regprocedure) INTO v_def;
    v_new := regexp_replace(v_def,
        'ORDER BY eump\.created_at DESC',
        'ORDER BY (eump.payment_status = ''confirmed'') DESC, eump.created_at DESC');
    IF v_new = v_def THEN
        RAISE EXCEPTION 'get_accepted_unpaid_members: payment text not found, not patched';
    END IF;
    EXECUTE v_new;

    ---------------------------------------------------------------- 3
    SELECT pg_get_functiondef('public.get_user_home_events(uuid)'::regprocedure) INTO v_def;
    v_new := regexp_replace(v_def,
        'COALESCE\(\(\s*SELECT TRUE FROM public\.event_user_member_payment eup\s+WHERE eup\.event_id = ue\.event_id AND eup\.user_id = p_user_id\s+AND eup\.payment_status = ''confirmed'' LIMIT 1\s*\), FALSE\) AS event_paid',
        $repl$CASE WHEN ue.payment_required THEN COALESCE((
            -- Paid only when every attending player this user looks after
            -- has a confirmed payment, whoever made it.
            SELECT bool_and(EXISTS (
                       SELECT 1 FROM public.event_user_member_payment eup
                       WHERE eup.event_id = ue.event_id
                         AND eup.member_id = uml.member_id
                         AND eup.payment_status = 'confirmed'))
            FROM public.user_member_link uml
            JOIN LATERAL (
                SELECT ea.response_id
                FROM public.event_attendance ea
                WHERE ea.event_id = ue.event_id AND ea.member_id = uml.member_id
                ORDER BY ea.created_at DESC, ea.attendance_id DESC
                LIMIT 1
            ) la ON la.response_id = 3
            WHERE uml.user_id = p_user_id
              AND EXISTS (
                  SELECT 1
                  FROM public.member_team_link mtl
                  JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
                  JOIN public.roles r ON r.role_id = mtrl.role_id
                  WHERE mtl.member_id = uml.member_id
                    AND mtl.team_id = ue.team_id
                    AND r.role_level = 10)
        ), FALSE) ELSE FALSE END AS event_paid$repl$);
    IF v_new = v_def THEN
        RAISE EXCEPTION 'get_user_home_events: event_paid text not found, not patched';
    END IF;
    EXECUTE v_new;

    ---------------------------------------------------------------- 4
    SELECT pg_get_functiondef('public.send_event_payment_reminders(bigint)'::regprocedure) INTO v_def;
    v_new := replace(v_def,
        'to_char(e.event_date_time, ''Dy FMDD Mon, HH24:MI'')',
        'to_char(e.event_date_time AT TIME ZONE ''Europe/Dublin'', ''Dy FMDD Mon, HH24:MI'')');
    IF v_new = v_def THEN
        RAISE EXCEPTION 'send_event_payment_reminders: date text not found, not patched';
    END IF;
    EXECUTE v_new;
END
$migration$;

---------------------------------------------------------------- 5
-- Clontarf Boys 2013, Girls 2012 and Boys 2016 have all taken event payments.
UPDATE public.teams SET payments = true WHERE team_id IN (73, 75, 82) AND payments IS DISTINCT FROM true;
