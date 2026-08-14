-- Revert the delete-on-rebuild added in 000009.
-- Match squad history is intentional: downstream queries use
-- DISTINCT ON (member_id, event_id) ORDER BY match_squad_id DESC
-- to pick the most recently created squad run.
--
-- Keeps all other fixes from 000009:
--   - mtl.status = 'active' filter
--   - Squad-scope filter (event.squad_id)
--   - Deterministic grade-10 role_id selection
--   - NULL guard on missing event

CREATE OR REPLACE FUNCTION public.create_match_squad_from_attendance(
    p_event_id bigint,
    p_user_id  uuid
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_new_match_squad_id bigint;
    v_team_id            bigint;
    v_event_squad_id     bigint;
    v_lookup_code_id     bigint;
    v_member_record      RECORD;
    v_squad_id_final     bigint;
BEGIN
    SELECT e.team_id, e.squad_id
      INTO v_team_id, v_event_squad_id
      FROM public.events e
     WHERE e.event_id = p_event_id;

    IF v_team_id IS NULL THEN
        RETURN NULL;
    END IF;

    v_lookup_code_id := public.get_updated_event_code(p_event_id);

    INSERT INTO public.match_squads (event_id, user_id)
    VALUES (p_event_id, p_user_id)
    RETURNING match_squad_id INTO v_new_match_squad_id;

    FOR v_member_record IN
        SELECT DISTINCT ON (ea.member_id)
            ea.member_id,
            ea.response_id,
            (
                SELECT mtrl2.role_id
                  FROM public.member_team_link       mtl2
                  JOIN public.member_team_role_link  mtrl2 ON mtl2.member_team_id = mtrl2.member_team_id
                  JOIN public.roles                  r2    ON mtrl2.role_id        = r2.role_id
                 WHERE mtl2.member_id = ea.member_id
                   AND mtl2.team_id   = v_team_id
                   AND mtl2.status    = 'active'
                   AND r2.role_grade  = 10
                 ORDER BY r2.role_level DESC, mtrl2.role_id ASC
                 LIMIT 1
            ) AS role_id
        FROM public.event_attendance ea
        JOIN public.member_team_link mtl
            ON ea.member_id = mtl.member_id
           AND mtl.team_id  = v_team_id
           AND mtl.status   = 'active'
        JOIN public.members m ON ea.member_id = m.member_id
        WHERE ea.event_id    = p_event_id
          AND m.status      != 'deleted'
          AND (
              v_event_squad_id IS NULL
              OR EXISTS (
                  SELECT 1
                    FROM public.member_squad_link msl
                   WHERE msl.member_id = ea.member_id
                     AND msl.team_id   = v_team_id
                     AND msl.squad_id  = v_event_squad_id
                     AND msl.code_id   = v_lookup_code_id
              )
          )
        ORDER BY ea.member_id, ea.created_at DESC
    LOOP
        IF v_member_record.response_id = 3 AND v_member_record.role_id IS NOT NULL THEN
            v_squad_id_final := NULL;

            SELECT squad_id INTO v_squad_id_final
              FROM public.member_squad_link
             WHERE member_id = v_member_record.member_id
               AND team_id   = v_team_id
               AND code_id   = v_lookup_code_id
             LIMIT 1;

            IF v_squad_id_final = 0 THEN v_squad_id_final := NULL; END IF;

            INSERT INTO public.match_squad_details (
                match_squad_id, event_id, user_id, team_id,
                squad_id, member_id, role_id
            ) VALUES (
                v_new_match_squad_id, p_event_id, p_user_id, v_team_id,
                v_squad_id_final, v_member_record.member_id, v_member_record.role_id
            );
        END IF;
    END LOOP;

    RETURN v_new_match_squad_id;
END;
$$;
