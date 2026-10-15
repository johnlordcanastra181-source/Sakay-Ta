
-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.todas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fare_matrix ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile." ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile." ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Drivers Policies
CREATE POLICY "Drivers are viewable by everyone." ON public.drivers FOR SELECT USING (true);
CREATE POLICY "Users can insert their own driver profile." ON public.drivers FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own driver profile." ON public.drivers FOR UPDATE USING (auth.uid() = id);

-- Rides Policies
CREATE POLICY "Passengers and assigned drivers can read rides" ON public.rides FOR SELECT USING (auth.uid() = passenger_id OR auth.uid() = driver_id OR driver_id IS NULL);
CREATE POLICY "Passengers can create rides" ON public.rides FOR INSERT WITH CHECK (auth.uid() = passenger_id);
CREATE POLICY "Participants can update rides" ON public.rides FOR UPDATE USING (auth.uid() = passenger_id OR auth.uid() = driver_id OR (driver_id IS NULL));

-- Notifications Policies
CREATE POLICY "Users can read their own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update their own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- Fare Matrix Policies
CREATE POLICY "Fare matrix is viewable by everyone" ON public.fare_matrix FOR SELECT USING (true);

