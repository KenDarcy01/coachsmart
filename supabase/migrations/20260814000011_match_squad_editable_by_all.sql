-- Allow any authenticated user to read and edit match squads and their details.
-- The previous policies restricted writes to the user who created the squad
-- (auth.uid() = user_id). Dropping those and replacing with permissive policies
-- for now; tighten to team-membership check later.

DROP POLICY IF EXISTS "Authenticated users can manage their own match_squads." ON public.match_squads;
DROP POLICY IF EXISTS "Authenticated users can manage their own match_squads." ON public.match_squad_details;

CREATE POLICY "Authenticated users can manage match_squads"
    ON public.match_squads
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Authenticated users can manage match_squad_details"
    ON public.match_squad_details
    TO authenticated
    USING (true)
    WITH CHECK (true);
