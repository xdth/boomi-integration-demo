-- Enterprise Integration Demo - PostgreSQL Schema
-- Focus: Idempotency, Audit Trail, and Integration Metrics
-- Author: https://github.com/xdth
-- Date: 2025-11-01

-- Create metabase database for Metabase metadata (if not exists)
SELECT 'CREATE DATABASE metabase'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'metabase')\gexec

-- ============================================
-- CORE TABLES FOR INTEGRATION FLOW
-- ============================================

-- Sales Orders table with idempotency key
CREATE TABLE IF NOT EXISTS sales_orders (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(100) UNIQUE NOT NULL,  -- From BOD, used for idempotency
    idempotency_key VARCHAR(255) UNIQUE NOT NULL,  -- Prevents duplicate processing
    customer_id VARCHAR(100) NOT NULL,
    customer_name VARCHAR(255),
    order_date TIMESTAMP NOT NULL,
    
    -- Original EUR amounts
    amount_eur DECIMAL(15,2) NOT NULL,
    tax_eur DECIMAL(15,2) DEFAULT 0,
    total_eur DECIMAL(15,2) NOT NULL,
    
    -- Converted CAD amounts (populated after FX conversion)
    amount_cad DECIMAL(15,2),
    tax_cad DECIMAL(15,2),
    total_cad DECIMAL(15,2),
    fx_rate DECIMAL(10,6),
    fx_conversion_date TIMESTAMP,
    
    -- Invoice tracking
    invoice_id VARCHAR(100),
    invoice_created_at TIMESTAMP,
    invoice_status VARCHAR(50),
    
    -- Processing metadata
    processing_status VARCHAR(50) DEFAULT 'pending',  -- pending, processing, completed, error
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    
    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    
    -- Routing information
    route_path VARCHAR(50),  -- 'normal', 'error', 'duplicate'
    
    CONSTRAINT chk_status CHECK (processing_status IN ('pending', 'processing', 'completed', 'error'))
);

-- FX Rates historical tracking
CREATE TABLE IF NOT EXISTS fx_rates (
    id SERIAL PRIMARY KEY,
    from_currency VARCHAR(3) NOT NULL,
    to_currency VARCHAR(3) NOT NULL,
    rate DECIMAL(10,6) NOT NULL,
    source VARCHAR(100),  -- API source name
    fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Create composite index for lookups
    UNIQUE(from_currency, to_currency, fetched_at)
);

-- FX Conversions audit trail
CREATE TABLE IF NOT EXISTS fx_conversions (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(100) REFERENCES sales_orders(order_id),
    original_amount DECIMAL(15,2) NOT NULL,
    original_currency VARCHAR(3) NOT NULL,
    converted_amount DECIMAL(15,2) NOT NULL,
    converted_currency VARCHAR(3) NOT NULL,
    fx_rate DECIMAL(10,6) NOT NULL,
    fx_rate_id INTEGER REFERENCES fx_rates(id),
    conversion_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Integration Events for monitoring
CREATE TABLE IF NOT EXISTS integration_events (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,  -- 'order_received', 'fx_converted', 'invoice_created', etc.
    event_source VARCHAR(100) NOT NULL,  -- 'mock_ion', 'boomi', 'fx_api', 'invoice_ninja'
    event_status VARCHAR(50) NOT NULL,  -- 'success', 'warning', 'error'
    order_id VARCHAR(100),
    event_data JSONB,  -- Flexible field for event-specific data
    error_details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Performance tracking
    duration_ms INTEGER  -- Processing duration in milliseconds
);

-- Integration Errors for dead letter queue tracking
CREATE TABLE IF NOT EXISTS integration_errors (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(100),
    error_type VARCHAR(100) NOT NULL,  -- 'validation_error', 'fx_api_error', 'invoice_api_error', etc.
    error_message TEXT NOT NULL,
    error_stack TEXT,
    raw_payload TEXT,  -- Store the original message that failed
    minio_path VARCHAR(500),  -- Path to archived error document in MinIO
    retry_attempts INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    is_resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP,
    resolution_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX IF NOT EXISTS idx_orders_idempotency ON sales_orders(idempotency_key);
CREATE INDEX IF NOT EXISTS idx_orders_status ON sales_orders(processing_status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON sales_orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fx_rates_lookup ON fx_rates(from_currency, to_currency, fetched_at DESC);
CREATE INDEX IF NOT EXISTS idx_event_type ON integration_events(event_type);
CREATE INDEX IF NOT EXISTS idx_event_status ON integration_events(event_status);
CREATE INDEX IF NOT EXISTS idx_event_order_id ON integration_events(order_id);
CREATE INDEX IF NOT EXISTS idx_event_created_at ON integration_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_error_type ON integration_errors(error_type);
CREATE INDEX IF NOT EXISTS idx_error_resolved ON integration_errors(is_resolved);
CREATE INDEX IF NOT EXISTS idx_error_created ON integration_errors(created_at DESC);

-- ============================================
-- VIEWS FOR METABASE DASHBOARDS
-- ============================================

-- Daily processing summary
CREATE OR REPLACE VIEW v_daily_processing_summary AS
SELECT 
    DATE(created_at) as processing_date,
    COUNT(*) as total_orders,
    COUNT(CASE WHEN processing_status = 'completed' THEN 1 END) as successful_orders,
    COUNT(CASE WHEN processing_status = 'error' THEN 1 END) as failed_orders,
    COUNT(CASE WHEN route_path = 'duplicate' THEN 1 END) as duplicate_orders,
    AVG(CASE WHEN fx_rate IS NOT NULL THEN fx_rate END) as avg_fx_rate,
    SUM(total_eur) as total_eur_value,
    SUM(total_cad) as total_cad_value
FROM sales_orders
GROUP BY DATE(created_at);

-- FX rate trends
CREATE OR REPLACE VIEW v_fx_rate_trends AS
SELECT 
    DATE(fetched_at) as date,
    from_currency,
    to_currency,
    AVG(rate) as avg_rate,
    MIN(rate) as min_rate,
    MAX(rate) as max_rate,
    COUNT(*) as rate_checks
FROM fx_rates
WHERE from_currency = 'EUR' AND to_currency = 'CAD'
GROUP BY DATE(fetched_at), from_currency, to_currency;

-- Integration performance metrics
CREATE OR REPLACE VIEW v_integration_performance AS
SELECT 
    event_type,
    event_source,
    DATE(created_at) as event_date,
    COUNT(*) as event_count,
    AVG(duration_ms) as avg_duration_ms,
    MAX(duration_ms) as max_duration_ms,
    COUNT(CASE WHEN event_status = 'success' THEN 1 END) as success_count,
    COUNT(CASE WHEN event_status = 'error' THEN 1 END) as error_count
FROM integration_events
GROUP BY event_type, event_source, DATE(created_at);

-- Error analysis view
CREATE OR REPLACE VIEW v_error_analysis AS
SELECT 
    error_type,
    DATE(created_at) as error_date,
    COUNT(*) as error_count,
    COUNT(CASE WHEN is_resolved THEN 1 END) as resolved_count,
    AVG(retry_attempts) as avg_retry_attempts
FROM integration_errors
GROUP BY error_type, DATE(created_at);

-- ============================================
-- FUNCTIONS FOR BUSINESS LOGIC
-- ============================================

-- Function to check idempotency
CREATE OR REPLACE FUNCTION check_order_exists(p_order_id VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM sales_orders WHERE order_id = p_order_id);
END;
$$ LANGUAGE plpgsql;

-- Function to calculate order statistics
CREATE OR REPLACE FUNCTION get_order_statistics()
RETURNS TABLE(
    total_orders BIGINT,
    successful_orders BIGINT,
    failed_orders BIGINT,
    duplicate_orders BIGINT,
    avg_processing_time_ms NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_orders,
        COUNT(CASE WHEN processing_status = 'completed' THEN 1 END)::BIGINT as successful_orders,
        COUNT(CASE WHEN processing_status = 'error' THEN 1 END)::BIGINT as failed_orders,
        COUNT(CASE WHEN route_path = 'duplicate' THEN 1 END)::BIGINT as duplicate_orders,
        AVG(e.duration_ms)::NUMERIC as avg_processing_time_ms
    FROM sales_orders o
    LEFT JOIN integration_events e ON o.order_id = e.order_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- INITIAL SEED DATA
-- ============================================

-- Insert sample FX rate
INSERT INTO fx_rates (from_currency, to_currency, rate, source)
VALUES ('EUR', 'CAD', 1.4850, 'seed_data')
ON CONFLICT (from_currency, to_currency, fetched_at) DO NOTHING;

-- Health check table for container verification
CREATE TABLE IF NOT EXISTS health_check (
    id SERIAL PRIMARY KEY,
    status VARCHAR(50) DEFAULT 'healthy',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO health_check (status) VALUES ('schema_complete');
