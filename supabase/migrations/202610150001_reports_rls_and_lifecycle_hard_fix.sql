-- SAKAY TA: File Report / Submit Report hard fix.
--
-- Root causes addressed:
--   1. Admins had no INSERT policy on public.reports, so reports filed manually
--      from the Admin Portal were rejected unless reporter_id = auth.uid() and
--      status = 'pending'.
--   2. reporter_id must be nullable so admin-filed reports and preserved
--      reports from deleted accounts remain valid (idempotent re-assertion).
--
-- RLS remains ENABLED. Non-admin insert rules are unchanged:
--   reports_authenticated_create: reporter_id = auth.uid() AND status = 'pending'.

ALTER TABLE public.reports ALTER COLUMN reporter_id DROP NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reports'
      AND policyname = 'reports_admin_insert'
  ) THEN
    CREATE POLICY reports_admin_insert ON public.reports
      FOR INSERT TO authenticated
      WITH CHECK (public.is_admin());
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE ON public.reports TO authenticated;

-- Ensure Admin Manage Reports receives live INSERT/UPDATE events.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'reports'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.reports;
  END IF;
END $$;

