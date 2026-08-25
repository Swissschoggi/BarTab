-- 004_social_features.sql
-- Adds outdoor seating to bars, avatar_url to profiles, and an avatars storage bucket.

-- ============================================================
-- 1. Bars: add outdoor_seating column
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'bars'
      AND column_name  = 'outdoor_seating'
  ) THEN
    ALTER TABLE public.bars
      ADD COLUMN outdoor_seating boolean NOT NULL DEFAULT false;
  END IF;
END
$$;

-- ============================================================
-- 2. Profiles (or users): add avatar_url column
-- ============================================================
-- The table may be called "profiles" or "users" depending on
-- earlier migrations. We try both.

DO $$
BEGIN
  -- If a profiles table exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'profiles'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name   = 'profiles'
        AND column_name  = 'avatar_url'
    ) THEN
      ALTER TABLE public.profiles
        ADD COLUMN avatar_url text;
    END IF;
  END IF;

  -- If a users table exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'users'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name   = 'users'
        AND column_name  = 'avatar_url'
    ) THEN
      ALTER TABLE public.users
        ADD COLUMN avatar_url text;
    END IF;
  END IF;
END
$$;

-- ============================================================
-- 3. Storage bucket for avatars
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 4. Storage RLS policies for avatars bucket
-- ============================================================

-- Anyone can read avatars (bucket is public, but explicit policy is safer)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename  = 'objects'
      AND policyname = 'Avatar images are publicly accessible'
  ) THEN
    CREATE POLICY "Avatar images are publicly accessible"
      ON storage.objects
      FOR SELECT
      USING (bucket_id = 'avatars');
  END IF;
END
$$;

-- Authenticated users can upload their own avatar
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename  = 'objects'
      AND policyname = 'Users can upload their own avatar'
  ) THEN
    CREATE POLICY "Users can upload their own avatar"
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;
END
$$;

-- Users can update their own avatar
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename  = 'objects'
      AND policyname = 'Users can update their own avatar'
  ) THEN
    CREATE POLICY "Users can update their own avatar"
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;
END
$$;

-- Users can delete their own avatar
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename  = 'objects'
      AND policyname = 'Users can delete their own avatar'
  ) THEN
    CREATE POLICY "Users can delete their own avatar"
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;
END
$$;
