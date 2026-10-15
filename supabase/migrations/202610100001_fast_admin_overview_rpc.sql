-- Migration: 202610100001_fast_admin_overview_rpc.sql
-- High-speed single-roundtrip PostgreSQL RPC for Admin Web Overview Dashboard.
-- Eliminates Deno Edge Function cold boot and multiple PostgREST HTTP queries.

-- 1. Index for lightning-fast completed rides revenue aggregation
CREATE INDEX IF NOT EXISTS rides_completed_at_idx 
ON public.rides (completed_at desc) 
WHERE status = 'completed';

-- 2. Fast Admin Overview RPC Function
CREATE OR REPLACE FUNCTION public.get_admin_overview()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_rides bigint;
  v_active_rides bigint;
  v_completed_rides bigint;
  v_cancelled_rides bigint;
  v_total_drivers bigint;
  v_active_drivers bigint;
  v_total_passengers bigint;
  v_pending_drivers bigint;
  v_open_reports bigint;
  v_revenue_today numeric;
  v_manila_today_start timestamptz;
  v_manila_tomorrow_start timestamptz;
  v_week_start timestamptz;
  v_i int;
  v_bucket_start timestamptz;
  v_bucket_end timestamptz;
  v_bucket_rev numeric;
  v_rev_list numeric[];
BEGIN
  -- Strict server-side Admin / Super Admin authorization
  IF auth.uid() IS NULL OR NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'administrator authorization required'
      USING errcode = 'insufficient_privilege';
  END IF;

  -- Asia/Manila (UTC+8) Timezone boundaries
  v_manila_today_start := (date_trunc('day', timezone('Asia/Manila', now())) at time zone 'Asia/Manila');
  v_manila_tomorrow_start := v_manila_today_start + interval '1 day';
  v_week_start := v_manila_today_start - interval '6 days';

  -- Core counts
  SELECT count(*) INTO v_total_rides FROM public.rides;
  SELECT count(*) INTO v_active_rides FROM public.rides WHERE status IN ('searching', 'accepted', 'arrived', 'started');
  SELECT count(*) INTO v_completed_rides FROM public.rides WHERE status = 'completed' AND driver_id IS NOT NULL;
  SELECT count(*) INTO v_cancelled_rides FROM public.rides WHERE status = 'cancelled';
  SELECT count(*) INTO v_total_drivers FROM public.drivers;
  SELECT count(*) INTO v_active_drivers FROM public.drivers WHERE application_status IN ('approved', 'active');
  SELECT count(*) INTO v_total_passengers FROM public.passenger_profiles;
  SELECT count(*) INTO v_pending_drivers FROM public.drivers WHERE application_status = 'pending';
  SELECT count(*) INTO v_open_reports FROM public.reports WHERE status = 'pending';

  -- Revenue Today: sum(fare) of completed trips today
  SELECT coalesce(sum(fare), 0) INTO v_revenue_today
  FROM public.rides
  WHERE status = 'completed'
    AND driver_id IS NOT NULL
    AND completed_at >= v_manila_today_start
    AND completed_at < v_manila_tomorrow_start;

  -- Weekly Revenue: 7 daily buckets from (today - 6 days) up to today
  v_rev_list := array[]::numeric[];
  FOR v_i IN 0..6 LOOP
    v_bucket_start := v_week_start + (v_i || ' days')::interval;
    v_bucket_end := v_bucket_start + interval '1 day';
    
    SELECT coalesce(sum(fare), 0) INTO v_bucket_rev
    FROM public.rides
    WHERE status = 'completed'
      AND driver_id IS NOT NULL
      AND completed_at >= v_bucket_start
      AND completed_at < v_bucket_end;
      
    v_rev_list := array_append(v_rev_list, v_bucket_rev);
  END LOOP;

  RETURN jsonb_build_object(
    'totalRides', v_total_rides,
    'activeRides', v_active_rides,
    'completedRides', v_completed_rides,
    'cancelledRides', v_cancelled_rides,
    'totalDrivers', v_total_drivers,
    'activeDrivers', v_active_drivers,
    'totalPassengers', v_total_passengers,
    'pendingDrivers', v_pending_drivers,
    'openReports', v_open_reports,
    'revenueToday', v_revenue_today,
    'weeklyRevenue', to_jsonb(v_rev_list)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_admin_overview() FROM public;
GRANT EXECUTE ON FUNCTION public.get_admin_overview() TO authenticated;

