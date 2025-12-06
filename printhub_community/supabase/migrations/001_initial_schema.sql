-- PrintHub Community Database Schema
-- Version: 1.0.0
-- Created: December 2025

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- ENUMS
-- ============================================

-- Print job status enum
CREATE TYPE print_job_status AS ENUM (
    'pending',
    'processing',
    'printing',
    'ready',
    'collected',
    'expired',
    'failed',
    'refunded'
);

-- Payment status enum
CREATE TYPE payment_status AS ENUM (
    'pending',
    'success',
    'failed',
    'refunded'
);

-- Color mode enum
CREATE TYPE color_mode AS ENUM (
    'bw',
    'color',
    'mixed'
);

-- ============================================
-- TABLES
-- ============================================

-- Societies table (for multi-society support in future)
CREATE TABLE societies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    pincode VARCHAR(10),
    station_location TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone_number VARCHAR(15) NOT NULL,
    name VARCHAR(100),
    flat_number VARCHAR(20),
    tower VARCHAR(50),
    society_id UUID REFERENCES societies(id),
    email VARCHAR(255),
    avatar_url TEXT,
    is_profile_complete BOOLEAN DEFAULT false,
    fcm_token TEXT,
    total_prints INTEGER DEFAULT 0,
    total_spent DECIMAL(10, 2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(phone_number)
);

-- Print jobs table
CREATE TABLE print_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    society_id UUID REFERENCES societies(id),

    -- Document details
    file_name VARCHAR(255) NOT NULL,
    file_url TEXT NOT NULL,
    file_size_bytes INTEGER NOT NULL,
    mime_type VARCHAR(100) NOT NULL,

    -- Print specifications
    total_pages INTEGER NOT NULL,
    bw_pages INTEGER DEFAULT 0,
    color_pages INTEGER DEFAULT 0,
    color_mode color_mode DEFAULT 'bw',
    copies INTEGER DEFAULT 1,

    -- Pricing
    bw_price_per_page DECIMAL(5, 2) DEFAULT 2.00,
    color_price_per_page DECIMAL(5, 2) DEFAULT 10.00,
    total_amount DECIMAL(10, 2) NOT NULL,

    -- Status tracking
    status print_job_status DEFAULT 'pending',
    pickup_code VARCHAR(10),

    -- Timestamps
    payment_at TIMESTAMPTZ,
    printing_started_at TIMESTAMPTZ,
    ready_at TIMESTAMPTZ,
    collected_at TIMESTAMPTZ,
    expired_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Epson Connect integration
    epson_job_id VARCHAR(100),

    -- Cover page URL
    cover_page_url TEXT,

    -- Error tracking
    error_message TEXT,
    retry_count INTEGER DEFAULT 0
);

-- Payments table
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    print_job_id UUID NOT NULL REFERENCES print_jobs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Payment details
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'INR',

    -- Razorpay details
    razorpay_order_id VARCHAR(100),
    razorpay_payment_id VARCHAR(100),
    razorpay_signature VARCHAR(255),

    -- Status
    status payment_status DEFAULT 'pending',

    -- UPI details (for reference)
    upi_transaction_id VARCHAR(100),

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,

    -- Refund details
    refund_id VARCHAR(100),
    refund_amount DECIMAL(10, 2),
    refunded_at TIMESTAMPTZ,
    refund_reason TEXT
);

-- Printer status table (for monitoring)
CREATE TABLE printer_status (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    society_id UUID REFERENCES societies(id),

    -- Status
    is_online BOOLEAN DEFAULT true,
    is_paper_available BOOLEAN DEFAULT true,
    is_ink_available BOOLEAN DEFAULT true,

    -- Ink levels (percentage)
    black_ink_level INTEGER,
    cyan_ink_level INTEGER,
    magenta_ink_level INTEGER,
    yellow_ink_level INTEGER,

    -- Paper
    paper_count INTEGER,

    -- Maintenance
    last_maintenance_at TIMESTAMPTZ,
    next_maintenance_at TIMESTAMPTZ,

    -- Stats
    total_prints_today INTEGER DEFAULT 0,
    total_prints_month INTEGER DEFAULT 0,

    -- Timestamps
    last_checked_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Content
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,

    -- Metadata
    type VARCHAR(50) NOT NULL,
    data JSONB,

    -- Status
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Daily stats table (for analytics)
CREATE TABLE daily_stats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    society_id UUID REFERENCES societies(id),
    date DATE NOT NULL,

    -- Counts
    total_jobs INTEGER DEFAULT 0,
    completed_jobs INTEGER DEFAULT 0,
    failed_jobs INTEGER DEFAULT 0,

    -- Pages
    total_bw_pages INTEGER DEFAULT 0,
    total_color_pages INTEGER DEFAULT 0,

    -- Revenue
    total_revenue DECIMAL(10, 2) DEFAULT 0,
    total_refunds DECIMAL(10, 2) DEFAULT 0,

    -- Unique users
    unique_users INTEGER DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(society_id, date)
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_users_society ON users(society_id);
CREATE INDEX idx_print_jobs_user ON print_jobs(user_id);
CREATE INDEX idx_print_jobs_status ON print_jobs(status);
CREATE INDEX idx_print_jobs_created ON print_jobs(created_at DESC);
CREATE INDEX idx_print_jobs_pickup_code ON print_jobs(pickup_code);
CREATE INDEX idx_payments_print_job ON payments(print_job_id);
CREATE INDEX idx_payments_user ON payments(user_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id) WHERE is_read = false;

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate pickup code
CREATE OR REPLACE FUNCTION generate_pickup_code()
RETURNS VARCHAR(6) AS $$
DECLARE
    chars VARCHAR(34) := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    result VARCHAR(6) := '';
    i INTEGER;
BEGIN
    FOR i IN 1..6 LOOP
        result := result || substr(chars, floor(random() * 34 + 1)::INTEGER, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate print job amount
CREATE OR REPLACE FUNCTION calculate_print_amount(
    p_bw_pages INTEGER,
    p_color_pages INTEGER,
    p_copies INTEGER DEFAULT 1,
    p_bw_price DECIMAL DEFAULT 2.00,
    p_color_price DECIMAL DEFAULT 10.00
)
RETURNS DECIMAL AS $$
BEGIN
    RETURN ((p_bw_pages * p_bw_price) + (p_color_pages * p_color_price)) * p_copies;
END;
$$ LANGUAGE plpgsql;

-- Function to update user stats on payment
CREATE OR REPLACE FUNCTION update_user_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'success' AND (OLD IS NULL OR OLD.status != 'success') THEN
        UPDATE users
        SET
            total_prints = total_prints + 1,
            total_spent = total_spent + NEW.amount,
            updated_at = NOW()
        WHERE id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TRIGGERS
-- ============================================

-- Update timestamps
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_print_jobs_updated_at
    BEFORE UPDATE ON print_jobs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_printer_status_updated_at
    BEFORE UPDATE ON printer_status
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Auto-generate pickup code for new jobs
CREATE OR REPLACE FUNCTION auto_generate_pickup_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.pickup_code IS NULL THEN
        NEW.pickup_code := generate_pickup_code();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_pickup_code_trigger
    BEFORE INSERT ON print_jobs
    FOR EACH ROW
    EXECUTE FUNCTION auto_generate_pickup_code();

-- Update user stats on payment success
CREATE TRIGGER update_user_stats_trigger
    AFTER INSERT OR UPDATE ON payments
    FOR EACH ROW
    EXECUTE FUNCTION update_user_stats();

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE print_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Print jobs policies
CREATE POLICY "Users can view own print jobs" ON print_jobs
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own print jobs" ON print_jobs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own pending print jobs" ON print_jobs
    FOR UPDATE USING (auth.uid() = user_id AND status = 'pending');

-- Payments policies
CREATE POLICY "Users can view own payments" ON payments
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own payments" ON payments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Notifications policies
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- ============================================
-- SEED DATA
-- ============================================

-- Insert pilot society
INSERT INTO societies (id, name, address, city, state, pincode, station_location, is_active)
VALUES (
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'Sample Residency',
    '123 Main Street, Phase 1',
    'Bangalore',
    'Karnataka',
    '560001',
    'Near Security Gate, Ground Floor',
    true
);

-- Insert initial printer status
INSERT INTO printer_status (society_id, is_online, is_paper_available, is_ink_available, paper_count)
VALUES (
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    true,
    true,
    true,
    500
);

-- ============================================
-- STORAGE BUCKETS (run via Supabase Dashboard or API)
-- ============================================

-- Create storage bucket for documents
-- Note: This needs to be run via Supabase Dashboard or Storage API
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('documents', 'documents', false);

-- Storage policies would be:
-- - Allow authenticated users to upload to their own folder
-- - Allow authenticated users to read their own files
-- - Files auto-delete after 24 hours (via scheduled job)

COMMENT ON TABLE users IS 'Registered users of the PrintHub platform';
COMMENT ON TABLE print_jobs IS 'Print job requests and their status';
COMMENT ON TABLE payments IS 'Payment transactions for print jobs';
COMMENT ON TABLE societies IS 'Residential societies where PrintHub operates';
COMMENT ON TABLE printer_status IS 'Real-time status of printers in each society';
COMMENT ON TABLE notifications IS 'Push notification history for users';
COMMENT ON TABLE daily_stats IS 'Daily aggregated statistics for analytics';
