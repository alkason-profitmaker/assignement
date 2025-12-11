-- Migration: Add QR data column for Paytm Dynamic QR
-- Version: 1.0.1
-- This stores the Paytm QR data for station display

-- Add qr_data column to orders table
-- This stores the Paytm dynamic QR string for display on station screens
ALTER TABLE orders ADD COLUMN IF NOT EXISTS qr_data TEXT;

-- Add qr_code_id column for Paytm tracking
ALTER TABLE orders ADD COLUMN IF NOT EXISTS qr_code_id VARCHAR(100);

-- Comment for documentation
COMMENT ON COLUMN orders.qr_data IS 'Paytm dynamic QR code data string for station display';
COMMENT ON COLUMN orders.qr_code_id IS 'Paytm QR code ID for tracking';
