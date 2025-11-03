-- Enterprise Integration Demo - PostgreSQL Schema
-- Focus: Idempotency, Audit Trail, and Integration Metrics
-- Author: https://github.com/xdth
-- Date: 2025-11-01

-- Temporary test table to verify initialization
CREATE TABLE IF NOT EXISTS health_check (
    id SERIAL PRIMARY KEY,
    status VARCHAR(50) DEFAULT 'healthy',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert test record
INSERT INTO health_check (status) VALUES ('initialized');

-- Create metabase database for Metabase metadata
CREATE DATABASE metabase;

-- Switch to integration database (this is default from docker-compose)
\c integration_db;
