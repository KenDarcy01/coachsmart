ALTER TABLE public.lineup
    ADD COLUMN created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
