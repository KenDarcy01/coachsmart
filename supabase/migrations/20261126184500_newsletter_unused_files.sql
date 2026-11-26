-- Newsletter storage tidy-up (Ken, 2026-11-26: "Go for it"). Lists files in
-- the public newsletter bucket that nothing points to any more: photos from
-- deleted drafts, unticked or re-suggested stories, replaced every-issue
-- photos, and PDFs replaced by a rebuild. Files younger than a day are left
-- alone (an upload may not be saved to its story yet). The nightly newsletter
-- harvest deletes them through the Storage API. Approved issues keep their
-- photos and PDF (no time limit for now).
CREATE OR REPLACE FUNCTION public.newsletter_unused_files()
RETURNS SETOF text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT o.name
  FROM storage.objects o
  WHERE o.bucket_id = 'newsletter'
    AND o.created_at < now() - interval '1 day'
    AND NOT EXISTS (SELECT 1 FROM newsletter_stories s WHERE s.photo_path = o.name)
    AND NOT EXISTS (SELECT 1 FROM newsletter_issues i WHERE i.pdf_path = o.name)
    AND NOT EXISTS (
      SELECT 1 FROM newsletter_settings st, jsonb_array_elements(st.standing) x
      WHERE x->>'photo_path' = o.name
    )
  LIMIT 500;
$$;
REVOKE ALL ON FUNCTION public.newsletter_unused_files() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.newsletter_unused_files() TO service_role;
