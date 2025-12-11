-- Migration: Add IoT/ESP32 station support
-- Version: 1.0.2
-- Enables cheap microcontroller-based QR displays

-- Add station API key for IoT device authentication
ALTER TABLE stations ADD COLUMN IF NOT EXISTS station_api_key VARCHAR(64);

-- Add display type to know what kind of device is connected
-- 'web' = Browser-based dashboard (tablet/PC)
-- 'esp32' = ESP32 with TFT display
-- 'rpi' = Raspberry Pi based
-- 'none' = No display (static QR only)
ALTER TABLE stations ADD COLUMN IF NOT EXISTS display_type VARCHAR(20) DEFAULT 'web'
  CHECK (display_type IN ('web', 'esp32', 'rpi', 'none'));

-- Track last time station display polled (for health monitoring)
ALTER TABLE stations ADD COLUMN IF NOT EXISTS last_poll_at TIMESTAMPTZ;

-- Track display device info (firmware version, IP, etc)
ALTER TABLE stations ADD COLUMN IF NOT EXISTS display_device_info JSONB DEFAULT '{}';

-- Index for efficient polling
CREATE INDEX IF NOT EXISTS idx_orders_station_pending
  ON orders(station_id, payment_status, expires_at)
  WHERE payment_status = 'PENDING';

-- Function to generate secure station API key
CREATE OR REPLACE FUNCTION generate_station_api_key()
RETURNS TEXT AS $$
BEGIN
  RETURN encode(gen_random_bytes(32), 'hex');
END;
$$ LANGUAGE plpgsql;

-- Add comment for documentation
COMMENT ON COLUMN stations.station_api_key IS 'API key for IoT device authentication. Generate with generate_station_api_key()';
COMMENT ON COLUMN stations.display_type IS 'Type of display device: web (browser), esp32, rpi, or none';
COMMENT ON COLUMN stations.last_poll_at IS 'Last time the display device polled for orders (health check)';
COMMENT ON COLUMN stations.display_device_info IS 'JSON with device info: firmware_version, ip_address, etc';
