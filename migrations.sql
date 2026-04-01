-- ============================================================
-- Rep Counter Level 2: Social Features Migration
-- Run this in the Supabase SQL Editor
-- ============================================================

-- 1. Groups table
CREATE TABLE IF NOT EXISTS public.groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  invite_code text UNIQUE NOT NULL,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

-- 2. Profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text,
  avatar_url text,
  group_id uuid REFERENCES public.groups(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- 3. Add user_id column to workouts table
ALTER TABLE public.workouts
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id);

-- 4. Add user_id column to settings table
ALTER TABLE public.settings
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id);

-- 5. Index on workouts(user_id) for fast lookups
CREATE INDEX IF NOT EXISTS idx_workouts_user_id ON public.workouts(user_id);

-- 6. Index on profiles(group_id) for leaderboard queries
CREATE INDEX IF NOT EXISTS idx_profiles_group_id ON public.profiles(group_id);

-- ============================================================
-- 7. Trigger: auto-create profile when a new auth user signs up
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture', NULL)
  )
  ON CONFLICT (id) DO UPDATE SET
    display_name = COALESCE(EXCLUDED.display_name, profiles.display_name),
    avatar_url = COALESCE(EXCLUDED.avatar_url, profiles.avatar_url);
  RETURN NEW;
END;
$$;

-- Drop existing trigger if present, then create
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 8. Enable RLS on all tables
-- ============================================================
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 9. RLS Policies for PROFILES
-- ============================================================

-- Users can read profiles of anyone in their group
DROP POLICY IF EXISTS "profiles_select_group" ON public.profiles;
CREATE POLICY "profiles_select_group" ON public.profiles
  FOR SELECT USING (
    -- Can always read own profile
    id = auth.uid()
    OR
    -- Can read profiles of group members
    (
      group_id IS NOT NULL
      AND group_id = (SELECT p.group_id FROM public.profiles p WHERE p.id = auth.uid())
    )
  );

-- Users can update only their own profile
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Users can insert their own profile (for the trigger / manual upsert)
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (id = auth.uid());

-- ============================================================
-- 10. RLS Policies for GROUPS
-- ============================================================

-- Anyone authenticated can read groups (needed for join-by-code)
DROP POLICY IF EXISTS "groups_select_authenticated" ON public.groups;
CREATE POLICY "groups_select_authenticated" ON public.groups
  FOR SELECT USING (auth.role() = 'authenticated');

-- Authenticated users can create groups
DROP POLICY IF EXISTS "groups_insert_authenticated" ON public.groups;
CREATE POLICY "groups_insert_authenticated" ON public.groups
  FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Only creator can update/delete their group
DROP POLICY IF EXISTS "groups_update_creator" ON public.groups;
CREATE POLICY "groups_update_creator" ON public.groups
  FOR UPDATE USING (created_by = auth.uid());

DROP POLICY IF EXISTS "groups_delete_creator" ON public.groups;
CREATE POLICY "groups_delete_creator" ON public.groups
  FOR DELETE USING (created_by = auth.uid());

-- ============================================================
-- 11. RLS Policies for WORKOUTS
-- ============================================================

-- Drop any existing broad policies that might conflict
DROP POLICY IF EXISTS "workouts_select_all" ON public.workouts;
DROP POLICY IF EXISTS "workouts_insert_all" ON public.workouts;
DROP POLICY IF EXISTS "workouts_update_all" ON public.workouts;
DROP POLICY IF EXISTS "workouts_delete_all" ON public.workouts;
DROP POLICY IF EXISTS "Enable all operations for all users" ON public.workouts;
DROP POLICY IF EXISTS "Allow read workouts" ON public.workouts;
DROP POLICY IF EXISTS "Allow insert workouts" ON public.workouts;
DROP POLICY IF EXISTS "Allow delete workouts" ON public.workouts;

-- Users can read their own workouts (by user_id or device_id) AND group members' workouts
DROP POLICY IF EXISTS "workouts_select" ON public.workouts;
CREATE POLICY "workouts_select" ON public.workouts
  FOR SELECT USING (
    -- Own workouts by user_id
    user_id = auth.uid()
    -- Own workouts by device_id (for anonymous/pre-login data)
    OR (user_id IS NULL AND device_id IS NOT NULL)
    -- Group members' workouts
    OR (
      user_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.profiles p1
        JOIN public.profiles p2 ON p1.group_id = p2.group_id AND p1.group_id IS NOT NULL
        WHERE p1.id = auth.uid() AND p2.id = public.workouts.user_id
      )
    )
  );

-- Users can insert their own workouts
DROP POLICY IF EXISTS "workouts_insert" ON public.workouts;
CREATE POLICY "workouts_insert" ON public.workouts
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    OR user_id IS NULL
  );

-- Users can update their own workouts
DROP POLICY IF EXISTS "workouts_update" ON public.workouts;
CREATE POLICY "workouts_update" ON public.workouts
  FOR UPDATE USING (
    user_id = auth.uid()
    OR (user_id IS NULL AND device_id IS NOT NULL)
  );

-- Users can delete their own workouts
DROP POLICY IF EXISTS "workouts_delete" ON public.workouts;
CREATE POLICY "workouts_delete" ON public.workouts
  FOR DELETE USING (
    user_id = auth.uid()
    OR (user_id IS NULL AND device_id IS NOT NULL)
  );

-- ============================================================
-- 12. RLS Policies for SETTINGS
-- ============================================================
DROP POLICY IF EXISTS "settings_select_all" ON public.settings;
DROP POLICY IF EXISTS "settings_insert_all" ON public.settings;
DROP POLICY IF EXISTS "settings_update_all" ON public.settings;
DROP POLICY IF EXISTS "Enable all operations for all users" ON public.settings;
DROP POLICY IF EXISTS "Allow read settings" ON public.settings;
DROP POLICY IF EXISTS "Allow upsert settings" ON public.settings;
DROP POLICY IF EXISTS "Allow update settings" ON public.settings;

DROP POLICY IF EXISTS "settings_select" ON public.settings;
CREATE POLICY "settings_select" ON public.settings
  FOR SELECT USING (
    user_id = auth.uid()
    OR (user_id IS NULL AND device_id IS NOT NULL)
  );

DROP POLICY IF EXISTS "settings_insert" ON public.settings;
CREATE POLICY "settings_insert" ON public.settings
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    OR user_id IS NULL
  );

DROP POLICY IF EXISTS "settings_update" ON public.settings;
CREATE POLICY "settings_update" ON public.settings
  FOR UPDATE USING (
    user_id = auth.uid()
    OR (user_id IS NULL AND device_id IS NOT NULL)
  );

DROP POLICY IF EXISTS "settings_delete" ON public.settings;
CREATE POLICY "settings_delete" ON public.settings
  FOR DELETE USING (
    user_id = auth.uid()
    OR (user_id IS NULL AND device_id IS NOT NULL)
  );
