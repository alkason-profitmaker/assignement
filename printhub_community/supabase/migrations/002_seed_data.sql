-- PrintHub Community Seed Data
-- Version: 1.0.0
-- Sample data for development and testing

-- ============================================
-- Sample Society
-- ============================================
INSERT INTO societies (
    id,
    name,
    address,
    city,
    pincode,
    total_flats,
    paytm_mid,
    paytm_key,
    contact_name,
    contact_phone,
    contact_email,
    commission_percent,
    is_active,
    onboarded_at
) VALUES (
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'Green Valley Apartments',
    '123 Main Road, Koramangala',
    'Bangalore',
    '560034',
    250,
    'PRINTHUB_GVA_001',
    'encrypted_key_placeholder',
    'Rajesh Kumar',
    '9876543210',
    'rajesh@greenvalley.com',
    40.00,
    true,
    NOW()
);

-- ============================================
-- Sample Station
-- ============================================
INSERT INTO stations (
    id,
    society_id,
    name,
    location_description,
    epson_printer_email,
    soundbox_id,
    has_color,
    is_active
) VALUES (
    'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'Main Gate Station',
    'Near security office, beside visitor parking',
    'greenvalley_maingate@print.epsonconnect.com',
    'SOUNDBOX_GVA_001',
    true,
    true
);

-- Add a second station
INSERT INTO stations (
    id,
    society_id,
    name,
    location_description,
    epson_printer_email,
    soundbox_id,
    has_color,
    is_active
) VALUES (
    'b2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'Clubhouse Station',
    'Inside clubhouse, near reception desk',
    'greenvalley_clubhouse@print.epsonconnect.com',
    'SOUNDBOX_GVA_002',
    true,
    true
);

-- ============================================
-- Sample User (for testing)
-- Note: In production, users are created via phone OTP
-- ============================================
INSERT INTO users (
    id,
    phone,
    name,
    society_id,
    flat_number,
    email,
    is_active
) VALUES (
    'c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a44',
    '9876543211',
    'Amit Sharma',
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'A-101',
    'amit@example.com',
    true
);

-- ============================================
-- Sample Credits (for testing)
-- ============================================
INSERT INTO credits (
    user_id,
    pages_bw,
    pages_color,
    reason,
    expires_at
) VALUES (
    'c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a44',
    2,
    0,
    'Welcome bonus for new user',
    NOW() + INTERVAL '90 days'
);

-- ============================================
-- Verification Queries
-- ============================================
-- SELECT * FROM societies;
-- SELECT * FROM stations;
-- SELECT * FROM users;
-- SELECT * FROM credits;
