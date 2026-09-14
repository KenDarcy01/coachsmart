ALTER TABLE public.pathway_stage_details
  ADD COLUMN IF NOT EXISTS detail_category text NOT NULL DEFAULT 'Player Pathways'
  CONSTRAINT pathway_stage_details_category_check
  CHECK (detail_category IN ('Player Pathways', 'Sample Sessions'));
