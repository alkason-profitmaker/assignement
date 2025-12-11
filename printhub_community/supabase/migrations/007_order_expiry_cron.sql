-- Migration: Add order expiry cron job
-- Version: 1.0.5
-- Runs every 15 minutes to expire pending orders

-- Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Grant usage to postgres user
GRANT USAGE ON SCHEMA cron TO postgres;

-- Create cron job to call expire-orders Edge Function every 15 minutes
-- Note: In Supabase, you configure this via Dashboard > Database > Extensions > pg_cron
-- Or via the cron.schedule function below

-- Schedule the expiry job (runs at minute 0, 15, 30, 45 of every hour)
SELECT cron.schedule(
  'expire-pending-orders',           -- job name
  '*/15 * * * *',                    -- every 15 minutes
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/expire-orders',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Alternative: Direct database update (if Edge Function approach doesn't work)
-- This is a fallback that runs directly in PostgreSQL
SELECT cron.schedule(
  'expire-pending-orders-direct',    -- job name
  '*/15 * * * *',                    -- every 15 minutes
  $$
  UPDATE orders
  SET
    payment_status = 'FAILED',
    print_status = 'FAILED',
    print_error_code = 'ORDER_EXPIRED',
    updated_at = NOW()
  WHERE
    payment_status = 'PENDING'
    AND expires_at < NOW();
  $$
);

-- Add comment for documentation
COMMENT ON EXTENSION pg_cron IS 'Job scheduler for PostgreSQL - used for order expiry';
