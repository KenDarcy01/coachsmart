-- Match reports can now say which squad they are about and who the opposition was.
-- Both are optional: older reports and the current FlutterFlow insert leave them empty.

ALTER TABLE public.match_reports ADD COLUMN IF NOT EXISTS squad_id bigint;
ALTER TABLE public.match_reports ADD COLUMN IF NOT EXISTS opposition text;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'match_reports_squad_id_fkey') THEN
    ALTER TABLE public.match_reports
      ADD CONSTRAINT match_reports_squad_id_fkey
      FOREIGN KEY (squad_id) REFERENCES public.squads(squad_id) ON DELETE SET NULL;
  END IF;
END $$;
