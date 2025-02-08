-- Ensure UUID extension is enabled for user IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table for authenticated users
CREATE TABLE IF NOT EXISTS users (
    google_uid VARCHAR(255) PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for QR codes created by users
CREATE TABLE IF NOT EXISTS qr_codes (
    qr_uid UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_by VARCHAR(255) REFERENCES users(google_uid) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    embedded_link TEXT NOT NULL,
    short_url VARCHAR(255) UNIQUE NOT NULL
);

-- Table for tracking each QR code scan (detailed tracking)
CREATE TABLE IF NOT EXISTS qr_scans (
    scan_id SERIAL PRIMARY KEY,
    qr_uid UUID REFERENCES qr_codes(qr_uid) ON DELETE CASCADE,
    user_cookie VARCHAR(255) NULL, -- If using browser cookies for tracking
    ip_address INET NOT NULL,
    user_agent TEXT NOT NULL,
    referrer TEXT NULL,
    scanned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for precomputed scan counts (to speed up analytics queries)
CREATE TABLE IF NOT EXISTS qr_scan_aggregates (
    qr_uid UUID PRIMARY KEY REFERENCES qr_codes(qr_uid) ON DELETE CASCADE,
    total_scans INTEGER DEFAULT 0,
    last_scanned_at TIMESTAMP DEFAULT NULL
);

-- Table for tracking anonymous users (avoiding duplicate scans)
CREATE TABLE IF NOT EXISTS temp_users (
    anon_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    qr_uid UUID REFERENCES qr_codes(qr_uid) ON DELETE CASCADE,
    amount_scanned INTEGER DEFAULT 1,
    last_scanned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
