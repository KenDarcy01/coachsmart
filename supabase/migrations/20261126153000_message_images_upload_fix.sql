-- Fix photo upload on the club Messages page (Ken 2026-11-26: "Couldn't add
-- that photo"). The message_images_insert policy read public.club_officers
-- directly, which the authenticated role cannot select, so every upload failed
-- with "permission denied for table club_officers". The check now runs inside
-- a SECURITY DEFINER helper; club_officers stays unreadable to clients.

CREATE OR REPLACE FUNCTION public.message_image_upload_ok(p_folder text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
  SELECT coalesce(public.is_app_super_user(), false)
      OR EXISTS (SELECT 1 FROM club_officers o
                  WHERE o.user_id = auth.uid() AND o.is_active AND o.can_messages
                    AND o.club_id::text = p_folder);
$$;
REVOKE ALL ON FUNCTION public.message_image_upload_ok(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.message_image_upload_ok(text) TO authenticated;

DROP POLICY IF EXISTS message_images_insert ON storage.objects;
CREATE POLICY message_images_insert ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'message-images'
  AND public.message_image_upload_ok((storage.foldername(name))[1]));
