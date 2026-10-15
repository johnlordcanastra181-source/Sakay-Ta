CREATE OR REPLACE FUNCTION public.test_booking()
RETURNS public.rides
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  res public.rides;
  passenger_id uuid;
  driver_id uuid;
BEGIN
  -- Get any passenger
  SELECT id INTO passenger_id FROM public.profiles LIMIT 1;
  -- Get the driver
  SELECT user_id INTO driver_id FROM public.drivers WHERE application_status = 'approved' LIMIT 1;
  
  -- We must set auth.uid() for the duration of this call
  -- In plpgsql we can't easily mock auth.uid() without SET LOCAL config
  -- BUT we can just duplicate the INSERT statement here to see what constraints fail!
  
  insert into public.rides (
    id, passenger_id, driver_id, passenger_name, passenger_phone, vehicle_type,
    pickup_address, pickup_latitude, pickup_longitude, pickup_province,
    destination_address, destination_latitude, destination_longitude, destination_province,
    distance_km, duration_minutes, fare, commission, driver_net,
    payment_method, status
  ) values (
    gen_random_uuid()::text, passenger_id, driver_id, 'Test', '123', 'habal',
    'A', 9.96, 124.01, null,
    'B', 9.97, 124.02, null,
    10.0, 10, 50, 7.5,
    42.5, 'cash', 'searching'
  ) returning * into res;
  
  return res;
END;
$$;
GRANT EXECUTE ON FUNCTION public.test_booking TO anon;
