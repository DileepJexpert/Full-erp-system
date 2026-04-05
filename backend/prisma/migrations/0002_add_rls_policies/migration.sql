-- Enable RLS and add policies for multi-tenant isolation
-- This provides defense-in-depth alongside the Prisma middleware

-- Helper function to get current business context
CREATE OR REPLACE FUNCTION current_business_id() RETURNS TEXT AS $$
  SELECT current_setting('app.current_business_id', true);
$$ LANGUAGE sql STABLE;

-- Macro to enable RLS on a table
-- We'll apply to all tables that have businessId column

DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOR tbl IN
    SELECT table_name FROM information_schema.columns
    WHERE column_name = 'businessId'
      AND table_schema = 'public'
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', tbl);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', tbl);

    -- Policy: rows visible only when businessId matches session variable
    EXECUTE format(
      'CREATE POLICY tenant_isolation_%I ON %I
       USING ("businessId" = current_business_id())
       WITH CHECK ("businessId" = current_business_id())',
      tbl, tbl
    );
  END LOOP;
END;
$$;
