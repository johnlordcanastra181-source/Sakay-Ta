CREATE OR REPLACE FUNCTION public.test_booking_rpc()
RETURNS public.rides
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  res public.rides;
  passenger_id uuid;
  driver_id uuid;
BEGIN
  -- Get the driver
  SELECT user_id INTO driver_id FROM public.drivers WHERE application_status = 'approved' LIMIT 1;
  
  -- Call the actual RPC.
  -- Wait, request_ride_with_id requires auth.uid()!
  -- We can't mock auth.uid() in plpgsql without setting config which is tricky.
  -- But we CAN just copy the EXACT validation logic here and see what fails!
  
  if distance_km < 0 or duration_minutes < 0 then raise exception 'invalid route metrics'; end if;
  -- Wait, it's just simpler if I don't use this.
  
END;
$$;
