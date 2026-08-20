-- Fix create_team_with_admin:
--   1. Capture squad_id from default squad insert.
--   2. Set squad_id on member_team_link.
--   3. Insert member_squad_link so the creator appears in the squad.

CREATE OR REPLACE FUNCTION public.create_team_with_admin(
  p_club_id             bigint,
  p_team_name           text,
  p_team_juvenile       boolean,
  p_team_female         boolean,
  p_car_pooling_allowed boolean,
  p_first_name          text,
  p_last_name           text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_user_id        uuid;
  v_team_id        bigint;
  v_team_code      text;
  v_squad_id       bigint;
  v_member_id      bigint;
  v_member_team_id bigint;
  v_chars          text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_attempt        int  := 0;
  v_candidate      text;
  v_exists         boolean;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Generate a unique team code (format: TM + 5 chars)
  LOOP
    v_candidate := 'TM';
    FOR i IN 1..5 LOOP
      v_candidate := v_candidate || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
    END LOOP;
    SELECT EXISTS(SELECT 1 FROM teams WHERE team_unique_code = v_candidate) INTO v_exists;
    EXIT WHEN NOT v_exists;
    v_attempt := v_attempt + 1;
    IF v_attempt >= 10 THEN
      RAISE EXCEPTION 'Failed to generate a unique team code — please try again';
    END IF;
  END LOOP;
  v_team_code := v_candidate;

  -- 1. Team
  INSERT INTO teams (team_name, club_id, team_juvenile, team_female, car_pooling_allowed, allow_lineup, team_unique_code)
  VALUES (p_team_name, p_club_id, p_team_juvenile, p_team_female, p_car_pooling_allowed, false, v_team_code)
  RETURNING team_id INTO v_team_id;

  -- 2. Default squad
  INSERT INTO squads (team_id, squad_name, grade, squad_colour, squad_list_seq)
  VALUES (v_team_id, 'No Team', '', '#ffffff', 100)
  RETURNING squad_id INTO v_squad_id;

  -- 3. Team roles — Admin, Coach, FLO, Player (no SuperUser)
  INSERT INTO team_roles_link (team_id, role_id)
  VALUES (v_team_id, 7), (v_team_id, 8), (v_team_id, 9), (v_team_id, 6);

  -- 4. Member record for the creator
  INSERT INTO members (first_name, last_name, user_id)
  VALUES (p_first_name, p_last_name, v_user_id)
  RETURNING member_id INTO v_member_id;

  -- 5. Link member to user account
  INSERT INTO user_member_link (user_id, member_id)
  VALUES (v_user_id, v_member_id);

  -- 6. Link member to team (with default squad)
  INSERT INTO member_team_link (member_id, team_id, squad_id, status)
  VALUES (v_member_id, v_team_id, v_squad_id, 'active')
  RETURNING member_team_id INTO v_member_team_id;

  -- 7. Assign Admin role to creator
  INSERT INTO member_team_role_link (member_team_id, role_id)
  VALUES (v_member_team_id, 7);

  -- 8. Link member to default squad
  INSERT INTO member_squad_link (member_id, squad_id, team_id)
  VALUES (v_member_id, v_squad_id, v_team_id);

  RETURN jsonb_build_object('team_id', v_team_id, 'team_unique_code', v_team_code);
END;
$$;
