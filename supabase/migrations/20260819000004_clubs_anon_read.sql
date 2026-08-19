-- Club names are public info needed for the create-team webview,
-- which may query before the JWT session is fully established.
CREATE POLICY "anon_can_read_clubs"
ON public.clubs
FOR SELECT
TO anon
USING (true);
