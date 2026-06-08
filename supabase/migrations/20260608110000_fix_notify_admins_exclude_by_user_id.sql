-- Fix actor exclusion to work by user_id instead of member_id.
-- The previous fix (20260608100000) compared member IDs, which fails when the
-- actor has separate member records for player and admin roles. Resolving the
-- actor's user_id first and excluding by user_id handles all cases.

CREATE OR REPLACE FUNCTION "public"."notify_admins_attendance_change"("p_event_id_param" integer, "p_member_id_param" integer, "p_response_id" integer, "p_attendance_id" bigint) RETURNS TABLE("notifications_created" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET search_path = 'public'
    AS $$
DECLARE
    created_count         INT := 0;
    v_logo_url            TEXT := 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/sign/coachsmartimages/CoachSmart%20Logo%20Transparent.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV82OTA4NmRkYy01MWQ3LTQ1NzUtYWYwMC1mZjQxYmMyNDU2YWMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJjb2FjaHNtYXJ0aW1hZ2VzL0NvYWNoU21hcnQgTG9nbyBUcmFuc3BhcmVudC5wbmciLCJpYXQiOjE3NzQ2MDYzOTksImV4cCI6MjYzODYwNjM5OX0.20yMzSYnG08kYjMK6cmGMvwA6VPGvm9_yHG-CmEfSIs';
    v_notify_all          BOOLEAN;
    v_notify_changes      BOOLEAN;
    v_prev_response_id    BIGINT;
    v_is_change_of_mind   BOOLEAN := false;
    v_response_word       TEXT;
    v_prev_response_word  TEXT;
    v_response_colour     TEXT;
    v_prev_response_colour TEXT;
    v_badge_label         TEXT;
    v_admin_count         INT := 0;
    v_event_exists        BOOLEAN := false;
    v_member_exists       BOOLEAN := false;
    v_actor_user_id       UUID;
BEGIN

    RAISE NOTICE '=== notify_admins_attendance_change START ===';
    RAISE NOTICE 'Inputs: p_event_id_param=%, p_member_id_param=%, p_response_id=%, p_attendance_id=%',
        p_event_id_param, p_member_id_param, p_response_id, p_attendance_id;

    -- -------------------------------------------------------------------------
    -- STEP 1: Check event exists and read notification flags
    -- -------------------------------------------------------------------------
    SELECT
        true,
        COALESCE(notify_admins_all, false),
        COALESCE(notify_admins_changes, false)
    INTO v_event_exists, v_notify_all, v_notify_changes
    FROM public.events
    WHERE event_id = p_event_id_param;

    IF NOT v_event_exists THEN
        RAISE NOTICE 'EXIT: Event % not found', p_event_id_param;
        RETURN QUERY SELECT 0;
        RETURN;
    END IF;

    RAISE NOTICE 'Event found: notify_admins_all=%, notify_admins_changes=%', v_notify_all, v_notify_changes;

    IF NOT v_notify_all AND NOT v_notify_changes THEN
        RAISE NOTICE 'EXIT: Both notification flags are false/null — nothing to do';
        RETURN QUERY SELECT 0;
        RETURN;
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 2: Check member exists
    -- -------------------------------------------------------------------------
    SELECT true INTO v_member_exists
    FROM public.members
    WHERE member_id = p_member_id_param;

    IF NOT v_member_exists THEN
        RAISE NOTICE 'EXIT: Member % not found', p_member_id_param;
        RETURN QUERY SELECT 0;
        RETURN;
    END IF;

    RAISE NOTICE 'Member % found', p_member_id_param;

    -- -------------------------------------------------------------------------
    -- STEP 2b: Resolve the actor's user_id so we can exclude them regardless
    --          of which member record they hold an admin role under.
    -- -------------------------------------------------------------------------
    SELECT uml.user_id INTO v_actor_user_id
    FROM public.user_member_link uml
    WHERE uml.member_id = p_member_id_param
    LIMIT 1;

    RAISE NOTICE 'Actor user_id resolved: %', v_actor_user_id;

    -- -------------------------------------------------------------------------
    -- STEP 3: Look up previous attendance record (strictly before p_attendance_id)
    -- -------------------------------------------------------------------------
    SELECT response_id
    INTO v_prev_response_id
    FROM public.event_attendance
    WHERE event_id    = p_event_id_param
      AND member_id   = p_member_id_param
      AND attendance_id < p_attendance_id
    ORDER BY attendance_id DESC
    LIMIT 1;

    RAISE NOTICE 'Previous attendance lookup: attendance_id < % → prev_response_id=%',
        p_attendance_id, v_prev_response_id;

    -- -------------------------------------------------------------------------
    -- STEP 4: Apply flag logic gate
    -- -------------------------------------------------------------------------
    IF NOT v_notify_all AND v_notify_changes THEN
        RAISE NOTICE 'Mode: notify_changes only — checking for genuine change of mind';
        IF v_prev_response_id IS NULL THEN
            RAISE NOTICE 'EXIT: No previous response found — first time responding, skipping';
            RETURN QUERY SELECT 0;
            RETURN;
        END IF;
        IF v_prev_response_id = p_response_id THEN
            RAISE NOTICE 'EXIT: Previous response (%) = current response (%) — no change of mind, skipping',
                v_prev_response_id, p_response_id;
            RETURN QUERY SELECT 0;
            RETURN;
        END IF;
        v_is_change_of_mind := true;
        RAISE NOTICE 'Change of mind confirmed: % → %', v_prev_response_id, p_response_id;
    END IF;

    IF v_notify_all THEN
        RAISE NOTICE 'Mode: notify_all — will create notification regardless';
        IF v_prev_response_id IS NOT NULL AND v_prev_response_id <> p_response_id THEN
            v_is_change_of_mind := true;
            RAISE NOTICE 'Also a change of mind: % → %', v_prev_response_id, p_response_id;
        END IF;
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 5: Resolve messaging variables
    -- -------------------------------------------------------------------------
    v_response_word := CASE p_response_id
        WHEN 3 THEN 'accepted'
        WHEN 4 THEN 'declined'
        ELSE        'updated'
    END;

    v_prev_response_word := CASE v_prev_response_id
        WHEN 3 THEN 'accepted'
        WHEN 4 THEN 'declined'
        ELSE        'updated'
    END;

    v_response_colour := CASE p_response_id
        WHEN 3 THEN '#87C232'
        WHEN 4 THEN '#e05252'
        ELSE        '#e7ebee'
    END;

    v_prev_response_colour := CASE v_prev_response_id
        WHEN 3 THEN '#87C232'
        WHEN 4 THEN '#e05252'
        ELSE        '#e7ebee'
    END;

    v_badge_label := CASE
        WHEN v_is_change_of_mind THEN 'CHANGE OF ATTENDANCE'
        WHEN p_response_id = 3   THEN 'ATTENDANCE ACCEPTED'
        WHEN p_response_id = 4   THEN 'ATTENDANCE DECLINED'
        ELSE                          'ATTENDANCE UPDATED'
    END;

    RAISE NOTICE 'Messaging: response_word=%, prev_response_word=%, badge_label=%, is_change_of_mind=%',
        v_response_word, v_prev_response_word, v_badge_label, v_is_change_of_mind;

    -- -------------------------------------------------------------------------
    -- STEP 6: Check admin count before attempting insert (excluding actor by user_id)
    -- -------------------------------------------------------------------------
    SELECT COUNT(DISTINCT u.user_id)
    INTO v_admin_count
    FROM public.member_team_link mtl
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.members m                  ON mtl.member_id = m.member_id
    JOIN public.user_member_link uml       ON m.member_id = uml.member_id
    JOIN public.users u                    ON uml.user_id = u.user_id
    JOIN public.events e                   ON e.team_id = mtl.team_id
    WHERE e.event_id = p_event_id_param
      AND mtrl.role_id = 7
      AND u.user_id != v_actor_user_id;

    RAISE NOTICE 'Admin users found for team (excluding actor user_id=%): %', v_actor_user_id, v_admin_count;

    IF v_admin_count = 0 THEN
        RAISE NOTICE 'WARN: No other admin users (role_id=7) found for this team — no notifications will be created';
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 7: Insert one notification record per team admin (excluding actor by user_id)
    -- -------------------------------------------------------------------------
    RAISE NOTICE 'Proceeding with INSERT...';

    INSERT INTO public.notifications (
        recipient_user_id,
        team_id,
        event_id,
        link_page,
        is_delivered,
        is_read,
        delivery_method,
        created_at,
        push_title,
        push_body,
        email_title,
        email_body,
        app_title,
        app_body
    )
    WITH target_event AS (
        SELECT
            e.event_id,
            e.event_date_time,
            e.team_id,
            t.team_name,
            CASE
                WHEN e.event_title IS NOT NULL AND e.event_title <> '' THEN e.event_title
                ELSE (
                    CASE
                        WHEN t.team_female = true AND ec.code_id = 3 THEN 'Camogie'
                        ELSE COALESCE(ec.event_code, '')
                    END || ' ' ||
                    COALESCE(et.event_type, '') ||
                    CASE
                        WHEN et.event_type_id = 2
                         AND e.opposition IS NOT NULL
                         AND e.opposition <> ''
                        THEN ' - ' || e.opposition
                        ELSE ''
                    END
                )
            END AS display_title,
            trim(to_char(e.event_date_time, 'Day, Mon DD, YYYY "at" HH24:MI')) AS date_time_formatted
        FROM public.events e
        JOIN public.teams t ON e.team_id = t.team_id
        LEFT JOIN public.event_codes ec ON e.event_code_id = ec.code_id
        LEFT JOIN public.event_types et ON e.event_type_id = et.event_type_id
        WHERE e.event_id = p_event_id_param
    ),
    changing_member AS (
        SELECT
            COALESCE(
                NULLIF(trim(m.first_name || ' ' || COALESCE(m.last_name, '')), ''),
                'A member'
            ) AS full_name
        FROM public.members m
        WHERE m.member_id = p_member_id_param
    ),
    admin_users AS (
        SELECT DISTINCT
            u.user_id,
            u.first_name AS user_fname,
            u.fcm_token
        FROM target_event te
        JOIN public.member_team_link mtl       ON te.team_id = mtl.team_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.members m                  ON mtl.member_id = m.member_id
        JOIN public.user_member_link uml       ON m.member_id = uml.member_id
        JOIN public.users u                    ON uml.user_id = u.user_id
        WHERE mtrl.role_id = 7
          AND u.user_id != v_actor_user_id  -- exclude the user who made the change (by user_id, handles multiple member records)
    )
    SELECT
        au.user_id,
        te.team_id,
        te.event_id,

        'coachsmartv2://coachsmartv2.com/eventDetails?eventID=' || te.event_id::text || '&fromSearch=false',

        false,  -- is_delivered

        -- is_read: true for email (user sees it in inbox), false for push (requires app interaction)
        CASE
            WHEN au.fcm_token IS NOT NULL AND au.fcm_token <> '' THEN false
            ELSE true
        END,

        CASE
            WHEN au.fcm_token IS NOT NULL AND au.fcm_token <> '' THEN 'push'
            ELSE 'email'
        END,

        NOW(),

        -- push_title
        te.team_name || ': Change of Attendance',

        -- push_body
        CASE
            WHEN v_is_change_of_mind THEN
                cm.full_name || ' has changed their attendance from ' ||
                v_prev_response_word || ' to ' || v_response_word || ' for ' ||
                trim(te.display_title) || ' on ' || te.date_time_formatted
            ELSE
                cm.full_name || ' has ' || v_response_word || ' attendance for ' ||
                trim(te.display_title) || ' on ' || te.date_time_formatted
        END,

        -- email_title
        CASE
            WHEN v_is_change_of_mind THEN
                te.team_name || ': Change of Attendance — ' || cm.full_name
            ELSE
                te.team_name || ': ' ||
                CASE p_response_id
                    WHEN 3 THEN 'Attendance Accepted'
                    WHEN 4 THEN 'Attendance Declined'
                    ELSE        'Attendance Updated'
                END || ' — ' || cm.full_name
        END,

        -- email_body HTML
        '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>CoachSmart</title></head>' ||
        '<body style="margin:0;padding:0;background-color:#111418;font-family:Arial,Helvetica,sans-serif;">' ||
        '<table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 20px;"><tr><td align="center">' ||
        '<table width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#212529;border-radius:16px;overflow:hidden;border:1px solid #3a3f4b;">' ||

        -- Header
        '<tr><td style="background-color:#1E222B;padding:28px 24px;text-align:center;border-bottom:3px solid #87C232;">' ||
        '<table cellpadding="0" cellspacing="0" style="margin:0 auto;"><tr>' ||
        '<td style="padding-right:16px;vertical-align:middle;">' ||
        '<img src="' || v_logo_url || '" alt="CoachSmart" width="80" style="display:block;height:auto;border:0;"></td>' ||
        '<td style="vertical-align:middle;text-align:left;">' ||
        '<p style="margin:0;font-size:26px;font-weight:900;letter-spacing:2.5px;line-height:1;font-family:Arial,Helvetica,sans-serif;">' ||
        '<span style="color:#c8ccd0;">COACH</span><span style="color:#87C232;">SMART</span></p>' ||
        '<p style="margin:5px 0 0 0;font-size:9px;font-weight:700;letter-spacing:4px;color:#87C232;font-family:Arial,Helvetica,sans-serif;">COACHING&nbsp;&nbsp;MADE&nbsp;&nbsp;SIMPLE</p>' ||
        '</td></tr></table></td></tr>' ||

        -- Body
        '<tr><td style="padding:28px 28px 24px;">' ||
        '<p style="margin:0 0 6px 0;font-size:15px;color:#e7ebee;font-family:Arial,Helvetica,sans-serif;">Hi ' || au.user_fname || ',</p>' ||

        CASE
            WHEN v_is_change_of_mind THEN
                '<p style="margin:0 0 20px 0;font-size:14px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
                '<strong style="color:#e7ebee;">' || cm.full_name || '</strong> has changed their attendance from ' ||
                '<strong style="color:' || v_prev_response_colour || ';">' || v_prev_response_word || '</strong>' ||
                ' to <strong style="color:' || v_response_colour || ';">' || v_response_word || '</strong> for the following event:</p>'
            ELSE
                '<p style="margin:0 0 20px 0;font-size:14px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
                '<strong style="color:#e7ebee;">' || cm.full_name || '</strong> has <strong style="color:' || v_response_colour || ';">' || v_response_word || '</strong> attendance for the following event:</p>'
        END ||

        -- Event card
        '<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 22px 0;"><tr>' ||
        '<td style="background:#2c313a;border-left:3px solid #87C232;padding:16px 18px;border-radius:0 8px 8px 0;">' ||
        '<p style="margin:0 0 5px 0;color:#e7ebee;font-size:15px;font-weight:700;font-family:Arial,Helvetica,sans-serif;">' || trim(te.display_title) || '</p>' ||
        '<p style="margin:0;color:#a3a3a3;font-size:13px;font-family:Arial,Helvetica,sans-serif;">' || te.date_time_formatted || '</p>' ||
        '</td></tr></table>' ||

        -- Status badge
        '<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 4px 0;"><tr>' ||
        '<td style="background:#2c313a;border-radius:8px;padding:16px 18px;border:1px solid #3a3f4b;">' ||
        '<p style="margin:0 0 4px 0;font-size:13px;font-weight:700;color:#87C232;font-family:Arial,Helvetica,sans-serif;letter-spacing:0.5px;">' || v_badge_label || '</p>' ||
        '<p style="margin:0;font-size:13px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
        CASE
            WHEN v_is_change_of_mind THEN
                cm.full_name || ' has changed their mind. You may wish to review your squad in the CoachSmart app.'
            ELSE
                cm.full_name || ' has ' || v_response_word || ' their attendance. You may wish to review your squad in the CoachSmart app.'
        END ||
        '</p></td></tr></table>' ||

        '</td></tr>' ||

        -- Footer
        '<tr><td style="padding:16px 28px;border-top:1px solid #3a3f4b;text-align:center;">' ||
        '<p style="margin:0 0 4px 0;font-size:11px;color:#555;letter-spacing:1.5px;font-family:Arial,Helvetica,sans-serif;">COACHSMART &middot; COACHING MADE SIMPLE</p>' ||
        '<p style="margin:0;font-size:11px;color:#444;font-family:Arial,Helvetica,sans-serif;">You received this because you are a team admin on CoachSmart.</p>' ||
        '</td></tr>' ||

        '</table></td></tr></table></body></html>',

        -- app_title
        CASE
            WHEN v_is_change_of_mind THEN
                'Change of Attendance — ' || cm.full_name
            ELSE
                CASE p_response_id
                    WHEN 3 THEN 'Attendance Accepted'
                    WHEN 4 THEN 'Attendance Declined'
                    ELSE        'Attendance Updated'
                END || ' — ' || cm.full_name
        END,

        -- app_body
        CASE
            WHEN v_is_change_of_mind THEN
                cm.full_name || ' has changed their attendance from ' ||
                v_prev_response_word || ' to ' || v_response_word || ' for ' ||
                trim(te.display_title) || ' on ' || te.date_time_formatted
            ELSE
                cm.full_name || ' has ' || v_response_word || ' attendance for ' ||
                trim(te.display_title) || ' on ' || te.date_time_formatted
        END

    FROM admin_users au
    CROSS JOIN target_event te
    CROSS JOIN changing_member cm;

    GET DIAGNOSTICS created_count = ROW_COUNT;

    RAISE NOTICE 'INSERT complete: % notification row(s) created', created_count;
    RAISE NOTICE '=== notify_admins_attendance_change END ===';

    RETURN QUERY SELECT created_count;
END;
$$;
