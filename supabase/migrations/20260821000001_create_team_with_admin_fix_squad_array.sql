-- Restructure create_team_with_admin to avoid array handling for squad_ids.
-- Instead: create member first, then loop over club codes creating each squad
-- and inserting member_squad_link in the same iteration so squad_id is always
-- available immediately. Also adds default squad_image for "No Team" squads.

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
  v_user_id          uuid;
  v_team_id          bigint;
  v_team_code        text;
  v_member_id        bigint;
  v_member_team_id   bigint;
  v_sq               bigint;
  v_first_squad_id   bigint;
  v_code_rec         record;
  v_chars            text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_attempt          int  := 0;
  v_candidate        text;
  v_exists           boolean;
  v_no_team_image    text := 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/sign/coachsmartimages/Grey%20Team.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV82OTA4NmRkYy01MWQ3LTQ1NzUtYWYwMC1mZjQxYmMyNDU2YWMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJjb2FjaHNtYXJ0aW1hZ2VzL0dyZXkgVGVhbS5wbmciLCJpYXQiOjE3NTY0NDg1OTgsImV4cCI6MjYyMDQ0ODU5OH0.LRFMMpY8ifKkQDGxwMhKArQeyz-__9SIWn-1bQG0rA4';
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Generate a unique team code (format: TM + 5 chars)
  LOOP
    v_candidate := 'TM';
    FOR j IN 1..5 LOOP
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

  -- 2. Team roles — Admin, Coach, FLO, Player (no SuperUser)
  INSERT INTO team_roles_link (team_id, role_id)
  VALUES (v_team_id, 7), (v_team_id, 8), (v_team_id, 9), (v_team_id, 6);

  -- 3. Member record for the creator
  INSERT INTO members (first_name, last_name, user_id)
  VALUES (p_first_name, p_last_name, v_user_id)
  RETURNING member_id INTO v_member_id;

  -- 4. Link member to user account
  INSERT INTO user_member_link (user_id, member_id)
  VALUES (v_user_id, v_member_id);

  -- 5. One "No Team" squad per club code; insert member_squad_link immediately
  --    so squad_id is never lost to array handling.
  FOR v_code_rec IN
    SELECT code_id FROM club_code_link WHERE club_id = p_club_id ORDER BY code_id
  LOOP
    INSERT INTO squads (team_id, squad_name, grade, squad_colour, squad_list_seq, squad_image)
    VALUES (v_team_id, 'No Team', '', '#ffffff', 100, v_no_team_image)
    RETURNING squad_id INTO v_sq;

    IF v_first_squad_id IS NULL THEN
      v_first_squad_id := v_sq;
    END IF;

    INSERT INTO member_squad_link (member_id, squad_id, team_id, code_id)
    VALUES (v_member_id, v_sq, v_team_id, v_code_rec.code_id);
  END LOOP;

  -- Fallback: club has no codes configured
  IF v_first_squad_id IS NULL THEN
    INSERT INTO squads (team_id, squad_name, grade, squad_colour, squad_list_seq, squad_image)
    VALUES (v_team_id, 'No Team', '', '#ffffff', 100, v_no_team_image)
    RETURNING squad_id INTO v_sq;
    v_first_squad_id := v_sq;

    INSERT INTO member_squad_link (member_id, squad_id, team_id)
    VALUES (v_member_id, v_first_squad_id, v_team_id);
  END IF;

  -- 6. Link member to team (squad_id = first squad)
  INSERT INTO member_team_link (member_id, team_id, squad_id, member_team_code, status)
  VALUES (v_member_id, v_team_id, v_first_squad_id, v_team_code, 'active')
  RETURNING member_team_id INTO v_member_team_id;

  -- 7. Assign Admin role to creator
  INSERT INTO member_team_role_link (member_team_id, role_id)
  VALUES (v_member_team_id, 7);

  RETURN jsonb_build_object('team_id', v_team_id, 'team_unique_code', v_team_code);
END;
$$;
