-- Migration: Add FAILED to payment_status constraint
-- Version: 1.0.3
-- Allows tracking of failed payments explicitly

-- Drop the existing constraint and add new one with FAILED status
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_payment_status_check;
ALTER TABLE orders ADD CONSTRAINT orders_payment_status_check
  CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED'));

-- Add comment for documentation
COMMENT ON COLUMN orders.payment_status IS 'Payment status: PENDING (awaiting), PAID (success), FAILED (declined), REFUNDED (money returned)';
