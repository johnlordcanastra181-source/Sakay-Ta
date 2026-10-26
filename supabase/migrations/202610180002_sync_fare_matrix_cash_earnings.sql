-- Synchronize Fare Matrix with Admin Portal settings (Cash-only, 0% commission, 100% driver earnings)
UPDATE public.fare_matrix
SET base_fare = 0.00,
    included_base_distance = 0.00,
    per_km_rate = 5.00,
    minimum_fare = 10.00,
    commission_percent = 0.00,
    updated_at = pg_catalog.now()
WHERE vehicle_type = 'tricycle';

UPDATE public.fare_matrix
SET base_fare = 20.00,
    included_base_distance = 0.00,
    per_km_rate = 5.00,
    minimum_fare = 15.00,
    commission_percent = 0.00,
    updated_at = pg_catalog.now()
WHERE vehicle_type = 'habal';

-- Reconcile any existing incomplete/legacy records so commission is 0 and driver_net equals full fare
UPDATE public.rides
SET commission = 0.00,
    driver_net = fare
WHERE commission <> 0.00 OR driver_net <> fare;

UPDATE public.driver_earnings
SET commission = 0.00,
    net_amount = gross_amount
WHERE commission <> 0.00 OR net_amount <> gross_amount;

