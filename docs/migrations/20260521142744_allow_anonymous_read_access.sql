-- ==========================================
-- MIGRATION: Allow Anonymous Read Access to Public Family Data
-- ==========================================
-- This migration allows unauthenticated users to view family tree data
-- (persons, relationships, and custom_events) without requiring login.
-- Write operations still require authentication and appropriate roles.

-- PERSONS: Allow anonymous read access
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.persons;
CREATE POLICY "Enable read access for all users" ON public.persons
  FOR SELECT
  USING (true);

-- RELATIONSHIPS: Allow anonymous read access
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.relationships;
CREATE POLICY "Enable read access for all users" ON public.relationships
  FOR SELECT
  USING (true);

-- CUSTOM_EVENTS: Allow anonymous read access
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.custom_events;
CREATE POLICY "Enable read access for all users" ON public.custom_events
  FOR SELECT
  USING (true);

-- Note: Write policies (INSERT, UPDATE, DELETE) remain unchanged
-- and still require authentication with admin or editor role.
