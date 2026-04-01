-- Fix infinite recursion in profiles RLS policy
-- The issue: profiles_select_group queries profiles to get group_id, triggering the same policy

-- First, create a security definer function that bypasses RLS to get the user's group_id
CREATE OR REPLACE FUNCTION public.get_my_group_id()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT group_id FROM public.profiles WHERE id = auth.uid();
$$;

-- Now fix the profiles select policy to use the function instead of a subquery
DROP POLICY IF EXISTS "profiles_select_group" ON public.profiles;
CREATE POLICY "profiles_select_group" ON public.profiles
  FOR SELECT USING (
    -- Can always read own profile
    id = auth.uid()
    OR
    -- Can read profiles of group members
    (
      group_id IS NOT NULL
      AND group_id = public.get_my_group_id()
    )
  );

-- Also fix workouts select policy which has the same issue
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
        SELECT 1 FROM public.profiles p2
        WHERE p2.id = public.workouts.user_id
          AND p2.group_id IS NOT NULL
          AND p2.group_id = public.get_my_group_id()
      )
    )
  );
