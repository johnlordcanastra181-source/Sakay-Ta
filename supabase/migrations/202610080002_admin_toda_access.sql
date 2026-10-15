-- Admin TODA registry access.
--
-- RLS already limits writes to public.is_admin() and limits reads to active
-- rows or admins.  PostgREST still needs table privileges before those row
-- policies can be evaluated; the earlier admin grant repair omitted public.todas.

GRANT SELECT, INSERT, UPDATE, DELETE ON public.todas TO authenticated;
