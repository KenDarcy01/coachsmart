-- Track which platform each user last accessed CoachSmart from
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS last_platform text CHECK (last_platform IN ('ios', 'android', 'web')),
  ADD COLUMN IF NOT EXISTS last_active_at timestamp with time zone;

-- RPC called on app launch to record platform + timestamp
CREATE OR REPLACE FUNCTION public.update_user_platform(p_platform text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  UPDATE public.users
  SET
    last_platform  = p_platform,
    last_active_at = now()
  WHERE user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_user_platform(text) TO authenticated, anon;
