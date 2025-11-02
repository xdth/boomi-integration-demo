-- PostgreSQL initialization script
-- Tables will be added in Step 5
-- This file ensures the volume mount doesn't fail

-- Temporary test table to verify initialization
CREATE TABLE IF NOT EXISTS health_check (
    id SERIAL PRIMARY KEY,
    status VARCHAR(50) DEFAULT 'healthy',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert test record
INSERT INTO health_check (status) VALUES ('initialized');
