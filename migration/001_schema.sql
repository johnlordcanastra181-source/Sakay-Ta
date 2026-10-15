-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Core Profiles (Replacing users & passengers)
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  firebase_uid TEXT UNIQUE,
  full_name TEXT NOT NULL,
  email TEXT,
  phone_number TEXT,
  role TEXT NOT NULL DEFAULT 'passenger' CHECK (role IN ('passenger', 'driver', 'admin', 'super_admin')),
  status TEXT NOT NULL DEFAULT 'active',
  profile_photo_url TEXT,
  avatar_color INTEGER DEFAULT 0,
  is_online BOOLEAN DEFAULT false,
  is_available BOOLEAN DEFAULT true,
  last_seen_at TIMESTAMPTZ,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  location_updated_at TIMESTAMPTZ,
  active_ride_id UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- TODAs
CREATE TABLE public.todas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  firebase_id TEXT UNIQUE,
  name TEXT NOT NULL,
  city TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Driver Profiles & Verification (Replacing drivers)
CREATE TABLE public.drivers (
  id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  application_status TEXT DEFAULT 'pending',
  verification_status TEXT DEFAULT 'pending',
  vehicle_type TEXT NOT NULL,
  plate_number TEXT,
  make TEXT,
  model TEXT,
  year INTEGER,
  color TEXT,
  toda_id UUID REFERENCES public.todas(id) ON DELETE SET NULL,
  license_type TEXT,
  license_number TEXT,
  doc_license_front TEXT,
  doc_license_back TEXT,
  doc_or_cr TEXT,
  doc_profile TEXT,
  rating_average DOUBLE PRECISION DEFAULT 0.0,
  rating_count INTEGER DEFAULT 0,
  total_trips INTEGER DEFAULT 0,
  submitted_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Rides (Replacing rides and bookings)
CREATE TABLE public.rides (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  firebase_id TEXT UNIQUE,
  passenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES public.drivers(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'searching' CHECK (status IN ('searching', 'accepted', 'arrived', 'started', 'completed', 'cancelled')),
  vehicle_type TEXT NOT NULL,
  pickup_address TEXT NOT NULL,
  pickup_lat DOUBLE PRECISION NOT NULL,
  pickup_lng DOUBLE PRECISION NOT NULL,
  dropoff_address TEXT NOT NULL,
  dropoff_lat DOUBLE PRECISION NOT NULL,
  dropoff_lng DOUBLE PRECISION NOT NULL,
  distance_km DOUBLE PRECISION NOT NULL,
  fare DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ
);

-- Ratings
CREATE TABLE public.ratings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  firebase_id TEXT UNIQUE,
  ride_id UUID UNIQUE NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
  from_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  to_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Notifications
CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  firebase_id TEXT UNIQUE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ride_id UUID REFERENCES public.rides(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Fare Matrix
CREATE TABLE public.fare_matrix (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_type TEXT UNIQUE NOT NULL,
  base_fare DOUBLE PRECISION NOT NULL,
  per_km_rate DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Reports
CREATE TABLE public.reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  firebase_id TEXT UNIQUE,
  reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  description TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Payments
CREATE TABLE public.payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  firebase_id TEXT UNIQUE,
  ride_id UUID NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
  payer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  payee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount DOUBLE PRECISION NOT NULL,
  method TEXT NOT NULL,
  status TEXT NOT NULL,
  reference TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $DO$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$DO$ language 'plpgsql';

-- Add triggers to update 'updated_at' automatically
CREATE TRIGGER update_profiles_modtime BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION update_modified_column();
CREATE TRIGGER update_drivers_modtime BEFORE UPDATE ON public.drivers FOR EACH ROW EXECUTE FUNCTION update_modified_column();
CREATE TRIGGER update_todas_modtime BEFORE UPDATE ON public.todas FOR EACH ROW EXECUTE FUNCTION update_modified_column();
CREATE TRIGGER update_fare_matrix_modtime BEFORE UPDATE ON public.fare_matrix FOR EACH ROW EXECUTE FUNCTION update_modified_column();
CREATE TRIGGER update_reports_modtime BEFORE UPDATE ON public.reports FOR EACH ROW EXECUTE FUNCTION update_modified_column();

