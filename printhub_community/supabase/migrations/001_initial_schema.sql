-- PrintHub Community Database Schema
-- Version: 1.0.0
-- This migration creates the initial database schema for PrintHub Community

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- Table: societies
-- Master table for all registered societies
-- ============================================
CREATE TABLE societies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(50) NOT NULL,
    pincode VARCHAR(10) NOT NULL,
    total_flats INTEGER,
    paytm_mid VARCHAR(50) NOT NULL UNIQUE,
    paytm_key VARCHAR(100) NOT NULL, -- Encrypted
    contact_name VARCHAR(100),
    contact_phone VARCHAR(15),
    contact_email VARCHAR(100),
    commission_percent DECIMAL(5,2) DEFAULT 40.00,
    is_active BOOLEAN DEFAULT true,
    onboarded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for city-based queries
CREATE INDEX idx_societies_city ON societies(city);
CREATE INDEX idx_societies_pincode ON societies(pincode);
CREATE INDEX idx_societies_active ON societies(is_active) WHERE is_active = true;

-- ============================================
-- Table: stations
-- Printer stations within societies
-- ============================================
CREATE TABLE stations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    society_id UUID NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    location_description VARCHAR(255),
    epson_printer_email VARCHAR(100) NOT NULL UNIQUE,
    epson_access_token TEXT, -- Encrypted
    soundbox_id VARCHAR(50),
    has_color BOOLEAN DEFAULT true,
    is_active BOOLEAN DEFAULT true,
    last_health_check TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for society lookup
CREATE INDEX idx_stations_society ON stations(society_id);
CREATE INDEX idx_stations_active ON stations(is_active) WHERE is_active = true;

-- ============================================
-- Table: users
-- Registered app users
-- ============================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(15) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    society_id UUID NOT NULL REFERENCES societies(id) ON DELETE RESTRICT,
    flat_number VARCHAR(20) NOT NULL,
    email VARCHAR(100),
    total_orders INTEGER DEFAULT 0,
    total_pages INTEGER DEFAULT 0,
    total_spent_paise INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    last_order_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for user lookup
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_society ON users(society_id);
CREATE UNIQUE INDEX idx_users_society_flat ON users(society_id, flat_number);

-- ============================================
-- Table: orders
-- All print orders
-- ============================================
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number SERIAL UNIQUE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    society_id UUID NOT NULL REFERENCES societies(id) ON DELETE RESTRICT,
    station_id UUID NOT NULL REFERENCES stations(id) ON DELETE RESTRICT,
    file_name VARCHAR(255) NOT NULL,
    file_hash VARCHAR(64),
    total_pages INTEGER NOT NULL,
    bw_pages INTEGER NOT NULL,
    color_pages INTEGER NOT NULL,
    copies INTEGER DEFAULT 1,
    amount_paise INTEGER NOT NULL,
    credits_used_paise INTEGER DEFAULT 0,
    final_amount_paise INTEGER NOT NULL,
    paytm_order_id VARCHAR(50) UNIQUE,
    paytm_txn_id VARCHAR(50),
    payment_status VARCHAR(20) DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'PAID', 'REFUNDED')),
    paid_at TIMESTAMPTZ,
    epson_job_id VARCHAR(100),
    print_status VARCHAR(20) DEFAULT 'WAITING' CHECK (print_status IN ('WAITING', 'QUEUED', 'PRINTING', 'DONE', 'FAILED')),
    print_error_code VARCHAR(50),
    printed_at TIMESTAMPTZ,
    refund_status VARCHAR(20) CHECK (refund_status IN ('INITIATED', 'COMPLETED')),
    refund_reason VARCHAR(100),
    refund_type VARCHAR(20) CHECK (refund_type IN ('AUTO', 'GOOD_FAITH')),
    paytm_refund_id VARCHAR(50),
    goodwill_credit_given BOOLEAN DEFAULT false,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for order queries
CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_station ON orders(station_id);
CREATE INDEX idx_orders_society ON orders(society_id);
CREATE INDEX idx_orders_paytm ON orders(paytm_order_id);
CREATE INDEX idx_orders_status ON orders(payment_status, print_status);
CREATE INDEX idx_orders_created ON orders(created_at DESC);
CREATE INDEX idx_orders_expires ON orders(expires_at) WHERE payment_status = 'PENDING';

-- ============================================
-- Table: credits
-- Goodwill credits for users
-- ============================================
CREATE TABLE credits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pages_bw INTEGER NOT NULL,
    pages_color INTEGER DEFAULT 0,
    pages_bw_used INTEGER DEFAULT 0,
    pages_color_used INTEGER DEFAULT 0,
    reason VARCHAR(100) NOT NULL,
    source_order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for credit lookup
CREATE INDEX idx_credits_user ON credits(user_id);
CREATE INDEX idx_credits_expires ON credits(expires_at) WHERE expires_at > NOW();

-- ============================================
-- Functions and Triggers
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for societies table
CREATE TRIGGER update_societies_updated_at
    BEFORE UPDATE ON societies
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger for orders table
CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to update user stats on order completion
CREATE OR REPLACE FUNCTION update_user_stats_on_order_complete()
RETURNS TRIGGER AS $$
BEGIN
    -- Only update on successful print completion
    IF NEW.print_status = 'DONE' AND OLD.print_status != 'DONE' THEN
        UPDATE users
        SET
            total_orders = total_orders + 1,
            total_pages = total_pages + NEW.total_pages * NEW.copies,
            total_spent_paise = total_spent_paise + NEW.final_amount_paise,
            last_order_at = NOW()
        WHERE id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for user stats update
CREATE TRIGGER trigger_update_user_stats
    AFTER UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_user_stats_on_order_complete();

-- ============================================
-- Row Level Security (RLS) Policies
-- ============================================

-- Enable RLS on all tables
ALTER TABLE societies ENABLE ROW LEVEL SECURITY;
ALTER TABLE stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE credits ENABLE ROW LEVEL SECURITY;

-- Societies: Users can only read their own society
CREATE POLICY "Users can view their own society"
    ON societies FOR SELECT
    USING (id IN (SELECT society_id FROM users WHERE id = auth.uid()));

-- Stations: Users can view stations in their society
CREATE POLICY "Users can view stations in their society"
    ON stations FOR SELECT
    USING (society_id IN (SELECT society_id FROM users WHERE id = auth.uid()));

-- Users: Users can only view and update their own record
CREATE POLICY "Users can view own record"
    ON users FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "Users can update own record"
    ON users FOR UPDATE
    USING (id = auth.uid());

-- Orders: Users can only view and create their own orders
CREATE POLICY "Users can view own orders"
    ON orders FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can create own orders"
    ON orders FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- Credits: Users can only view their own credits
CREATE POLICY "Users can view own credits"
    ON credits FOR SELECT
    USING (user_id = auth.uid());

-- ============================================
-- Service Role Policies (for Edge Functions)
-- ============================================

-- Allow service role full access for webhooks
CREATE POLICY "Service role full access on societies"
    ON societies FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on stations"
    ON stations FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on users"
    ON users FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on orders"
    ON orders FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on credits"
    ON credits FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================
-- Comments for documentation
-- ============================================
COMMENT ON TABLE societies IS 'Master table for registered residential societies';
COMMENT ON TABLE stations IS 'Print stations within societies, each with unique Epson printer';
COMMENT ON TABLE users IS 'Registered app users, scoped to their society';
COMMENT ON TABLE orders IS 'All print orders with full lifecycle tracking';
COMMENT ON TABLE credits IS 'Goodwill credits given for print failures';

COMMENT ON COLUMN orders.amount_paise IS 'Total order amount before credits in paise';
COMMENT ON COLUMN orders.credits_used_paise IS 'Credit value applied in paise';
COMMENT ON COLUMN orders.final_amount_paise IS 'Amount charged after credits in paise';
COMMENT ON COLUMN societies.paytm_key IS 'Encrypted Paytm merchant key';
COMMENT ON COLUMN stations.epson_access_token IS 'Encrypted Epson Connect access token';
