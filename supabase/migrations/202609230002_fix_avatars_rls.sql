-- Drop existing incorrect policies
DROP POLICY IF EXISTS avatars_owner_insert ON storage.objects;
DROP POLICY IF EXISTS avatars_owner_update ON storage.objects;
DROP POLICY IF EXISTS avatars_owner_delete ON storage.objects;
DROP POLICY IF EXISTS avatars_owner_select ON storage.objects;

-- Create robust policies for the avatars bucket using path-based foldername evaluation
CREATE POLICY avatars_owner_select ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY avatars_owner_insert ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY avatars_owner_update ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY avatars_owner_delete ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

