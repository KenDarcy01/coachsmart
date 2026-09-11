CREATE TABLE public.club_pathway_link (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  club_id bigint NOT NULL,
  pathway_type_id bigint NOT NULL,
  CONSTRAINT club_pathway_link_pkey PRIMARY KEY (id),
  CONSTRAINT club_pathway_link_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(club_id),
  CONSTRAINT club_pathway_link_pathway_type_id_fkey FOREIGN KEY (pathway_type_id) REFERENCES public.pathway_types(pathway_type_id),
  CONSTRAINT club_pathway_link_unique UNIQUE (club_id, pathway_type_id)
);
