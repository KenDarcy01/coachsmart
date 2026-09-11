-- RLS for pathway_types
ALTER TABLE public.pathway_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "authenticated_users_can_read"   ON public.pathway_types FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON public.pathway_types FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON public.pathway_types FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON public.pathway_types FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);

-- RLS for pathway_stages
ALTER TABLE public.pathway_stages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "authenticated_users_can_read"   ON public.pathway_stages FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON public.pathway_stages FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON public.pathway_stages FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON public.pathway_stages FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);

-- RLS for pathway_stage_details
ALTER TABLE public.pathway_stage_details ENABLE ROW LEVEL SECURITY;
CREATE POLICY "authenticated_users_can_read"   ON public.pathway_stage_details FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON public.pathway_stage_details FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON public.pathway_stage_details FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON public.pathway_stage_details FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);

-- RLS for club_pathway_link
ALTER TABLE public.club_pathway_link ENABLE ROW LEVEL SECURITY;
CREATE POLICY "authenticated_users_can_read"   ON public.club_pathway_link FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON public.club_pathway_link FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON public.club_pathway_link FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON public.club_pathway_link FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
