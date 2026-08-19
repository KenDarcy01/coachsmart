-- Club names are public info needed for the create-team webview,
-- which may query before the JWT session is fully established.
-- Migration 20260727000011 revoked both the table SELECT grant and any anon RLS
-- policy — restore both here.
GRANT SELECT ON public.clubs TO anon;

CREATE POLICY "anon_can_read_clubs"
ON public.clubs
FOR SELECT
TO anon
USING (true);
