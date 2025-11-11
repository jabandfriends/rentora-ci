-- =========================================
-- APARTMENT MANAGEMENT SYSTEM DATABASE SCHEMA
-- =========================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =========================================
-- 1. USERS (Enhanced)
-- =========================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    must_change_password BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    reset_password_token VARCHAR(255),
    reset_password_expires TIMESTAMPTZ,
    national_id VARCHAR(13),
    birth_date DATE,
    phone_number VARCHAR(15), -- Support international formats
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(15),
    profile_image_url TEXT,
    last_login TIMESTAMPTZ,
    login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Default super admin with proper password hashing
INSERT INTO users (first_name, last_name, email, password_hash)
VALUES ('Super', 'Admin', 'admin@example.com', crypt('admin123', gen_salt('bf')))
ON CONFLICT (email) DO NOTHING;

-- =========================================
-- 2. APARTMENTS (Enhanced)
-- =========================================
CREATE TABLE IF NOT EXISTS apartments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    logo_url TEXT,
    phone_number VARCHAR(15),
    tax_id VARCHAR(13),
    payment_due_day INTEGER CHECK (payment_due_day BETWEEN 1 AND 31) DEFAULT 30,
    late_fee NUMERIC(10,2) DEFAULT 0,
    late_fee_type VARCHAR(10) DEFAULT 'fixed' CHECK (late_fee_type IN ('fixed', 'percentage')),
    grace_period_days INTEGER DEFAULT 3,
    address TEXT,
    city VARCHAR(50),
    state VARCHAR(50),
    postal_code VARCHAR(10),
    country VARCHAR(50) DEFAULT 'Thailand',
    timezone VARCHAR(50) DEFAULT 'Asia/Bangkok',
    currency VARCHAR(3) DEFAULT 'THB',
    created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'setup_incomplete' CHECK (status IN ('setup_incomplete', 'setup_in_progress', 'active', 'inactive')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_apartments_updated_at BEFORE UPDATE ON apartments
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 3. APARTMENT USERS
-- =========================================
CREATE TABLE IF NOT EXISTS apartment_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    apartment_id UUID REFERENCES apartments(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'tenant' CHECK (role IN ('tenant', 'admin','maintenance','accountant')),  --     admin  = manager
    created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(apartment_id, user_id)
);

CREATE TRIGGER update_apartment_users_updated_at BEFORE UPDATE ON apartment_users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 4. BUILDINGS (Enhanced)
-- =========================================
CREATE TABLE IF NOT EXISTS buildings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    apartment_id UUID REFERENCES apartments(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    total_floors INTEGER,
    building_type VARCHAR(20) DEFAULT 'residential',
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_buildings_updated_at BEFORE UPDATE ON buildings
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 5. FLOORS (Enhanced)
-- =========================================
CREATE TABLE IF NOT EXISTS floors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    building_id UUID REFERENCES buildings(id) ON DELETE CASCADE,
    floor_number INTEGER NOT NULL,
    floor_name VARCHAR(50), -- e.g., "Ground Floor", "Mezzanine"
    total_units INTEGER DEFAULT 0,
    floor_plan_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(building_id, floor_number)
);

CREATE TRIGGER update_floors_updated_at BEFORE UPDATE ON floors
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 6. UNITS (Enhanced)
-- =========================================
CREATE TABLE IF NOT EXISTS units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    floor_id UUID REFERENCES floors(id) ON DELETE CASCADE,
    unit_name VARCHAR(50) NOT NULL,
    unit_type VARCHAR(20) DEFAULT 'apartment', -- apartment, studio, penthouse, commercial
    status VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available', 'occupied', 'maintenance', 'reserved')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(floor_id, unit_name)
);

CREATE TRIGGER update_units_updated_at BEFORE UPDATE ON units
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 7. UTILITIES (Enhanced)
-- =========================================
CREATE TABLE IF NOT EXISTS utilities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    apartment_id UUID REFERENCES apartments(id) ON DELETE CASCADE,
    utility_name VARCHAR(50) NOT NULL,
    utility_type VARCHAR(20) NOT NULL CHECK (utility_type IN ('fixed', 'meter')),
    category VARCHAR(20) DEFAULT 'utility' CHECK (category IN ('utility', 'service', 'fee')), -- water, electricity, gas, internet, etc.
    fixed_price NUMERIC(10,2),
    unit_price NUMERIC(10,4), -- More precision for utility rates
    minimum_charge NUMERIC(10,2) DEFAULT 0,
    -- Tiered pricing structure
    billing_cycle VARCHAR(10) DEFAULT 'monthly' CHECK (billing_cycle IN ('monthly', 'quarterly', 'yearly')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_utilities_updated_at BEFORE UPDATE ON utilities
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 8. EXTRA SERVICES
-- =========================================
CREATE TABLE IF NOT EXISTS extra_services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    apartment_id UUID REFERENCES apartments(id) ON DELETE CASCADE,
    service_name VARCHAR(50) NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL,
    billing_type VARCHAR(20) DEFAULT 'monthly' CHECK (billing_type IN ('monthly', 'one_time', 'daily', 'yearly')),
    category VARCHAR(30) DEFAULT 'service', -- parking, gym, pool, security, etc.
    requires_approval BOOLEAN DEFAULT false,
    max_quantity INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_extra_services_updated_at BEFORE UPDATE ON extra_services
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 9. UNIT SERVICES
-- =========================================
CREATE TABLE IF NOT EXISTS unit_services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_id UUID REFERENCES extra_services(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE CASCADE,
    quantity INTEGER DEFAULT 1,
    monthly_price NUMERIC(10,2), -- Calculated price based on quantity
    start_date DATE NOT NULL,
    end_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    approved_by_user_id UUID REFERENCES users(id),
    approved_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(unit_id, service_id, start_date)
);

CREATE TRIGGER update_unit_services_updated_at BEFORE UPDATE ON unit_services
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 10. APARTMENT PAYMENT METHODS(Enhanced)
-- =========================================
CREATE TABLE IF NOT EXISTS apartment_payment_methods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    apartment_id UUID REFERENCES apartments(id) ON DELETE CASCADE,
    method_name VARCHAR(50) NOT NULL,
    method_type VARCHAR(20) NOT NULL CHECK (method_type IN ('bank_transfer', 'promptpay')),
    bank_name VARCHAR(100),
    bank_account_number VARCHAR(50),
    account_holder_name VARCHAR(100),
    promptpay_number VARCHAR(20),
    promptpay_qr_url TEXT,
    instructions TEXT,
    processing_fee_percentage NUMERIC(5,2) DEFAULT 0,
    processing_fee_fixed NUMERIC(10,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    display_order INTEGER DEFAULT 0,
    created_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_apartment_payment_methods_updated_at BEFORE UPDATE ON apartment_payment_methods
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 11. CONTRACTS (Enhanced)
-- =========================================
CREATE TABLE IF NOT EXISTS contracts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contract_number VARCHAR(50) UNIQUE,
    unit_id UUID REFERENCES units(id) ON DELETE CASCADE,
    tenant_user_id UUID REFERENCES users(id),
    rental_type VARCHAR(20) NOT NULL CHECK (rental_type IN ('daily', 'monthly', 'yearly')),
    start_date DATE NOT NULL,
    end_date DATE,
    rental_price NUMERIC(10,2) NOT NULL,
    deposit_amount NUMERIC(10,2),
    advance_payment_months INTEGER DEFAULT 0,
    late_fee_amount NUMERIC(10,2),
    utilities_included BOOLEAN DEFAULT false,
    services_included JSONB DEFAULT '[]', -- Array of included service IDs
    terms_and_conditions TEXT,
    special_conditions TEXT,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('draft', 'active', 'terminated', 'expired', 'renewed')),
    auto_renewal BOOLEAN DEFAULT false,
    renewal_notice_days INTEGER DEFAULT 30,
    electricity_meter_start_reading NUMERIC(10, 2) NOT NULL,
    water_meter_start_reading NUMERIC(10, 2) NOT NULL,
    termination_date DATE,
    termination_reason TEXT,
    terminated_by_user_id UUID REFERENCES users(id),
    document_url TEXT, -- PDF contract document
    signed_at TIMESTAMPTZ,
    created_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Generate contract number trigger
CREATE OR REPLACE FUNCTION generate_contract_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.contract_number IS NULL THEN
        NEW.contract_number := 'CT-' || TO_CHAR(NOW(), 'YYYYMM') || '-' || LPAD(nextval('contract_sequence')::text, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS contract_sequence START 1;

CREATE TRIGGER set_contract_number BEFORE INSERT ON contracts
FOR EACH ROW EXECUTE FUNCTION generate_contract_number();

CREATE TRIGGER update_contracts_updated_at BEFORE UPDATE ON contracts
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 12. UNIT UTILITIES
-- =========================================
CREATE TABLE IF NOT EXISTS unit_utilities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    unit_id UUID REFERENCES units(id) ON DELETE CASCADE,
    utility_id UUID REFERENCES utilities(id) ON DELETE CASCADE,
    reading_date DATE NOT NULL,
    meter_start NUMERIC(12,4),
    meter_end NUMERIC(12,4),
    usage_amount NUMERIC(12,4), -- Calculated or manual entry
    usage_month DATE NOT NULL, -- First day of the month
    calculated_cost NUMERIC(10,2),
    notes TEXT,
    read_by_user_id UUID REFERENCES users(id),
    verified_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(unit_id, utility_id, usage_month)
);

CREATE TRIGGER update_unit_utilities_updated_at BEFORE UPDATE ON unit_utilities
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 13. MONTHLY INVOICE
-- =========================================
CREATE TABLE IF NOT EXISTS invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_number VARCHAR(50) UNIQUE,
    apartment_id UUID REFERENCES apartments(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE CASCADE,
    contract_id UUID REFERENCES contracts(id),
    tenant_user_id UUID REFERENCES users(id),
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    generation_month DATE NOT NULL, -- First day of the month
    due_date DATE NOT NULL,
    
    -- Amount breakdowns
    rental_amount NUMERIC(10,2) DEFAULT 0,
    utilities_amount NUMERIC(10,2) DEFAULT 0,
    services_amount NUMERIC(10,2) DEFAULT 0,
    late_fees_amount NUMERIC(10,2) DEFAULT 0,
    discounts_amount NUMERIC(10,2) DEFAULT 0,
    tax_amount NUMERIC(10,2) DEFAULT 0,
    total_amount NUMERIC(10,2) NOT NULL,
    
    payment_status VARCHAR(20) DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'partially_paid', 'paid', 'overdue', 'cancelled')),
    paid_amount NUMERIC(10,2) DEFAULT 0,
    payment_due_date DATE,
    
    -- Invoice metadata
    notes TEXT,
    is_recurring BOOLEAN DEFAULT true,
    pdf_url TEXT,
    sent_at TIMESTAMPTZ,
    viewed_at TIMESTAMPTZ,
    
    generated_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(unit_id, generation_month)
);

-- Generate invoice number trigger
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.invoice_number IS NULL THEN
        NEW.invoice_number := 'INV-' || TO_CHAR(NOW(), 'YYYYMM') || '-' || LPAD(nextval('invoice_sequence')::text, 5, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS invoice_sequence START 1;

CREATE TRIGGER set_invoice_number BEFORE INSERT ON invoices
FOR EACH ROW EXECUTE FUNCTION generate_invoice_number();

CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 14. PAYMENTS
-- =========================================
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_number VARCHAR(50) UNIQUE,
    invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
    amount NUMERIC(10,2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    payment_method_id UUID REFERENCES apartment_payment_methods(id),
    transaction_id VARCHAR(100), -- Bank/gateway transaction ID
    reference_number VARCHAR(100), -- Payment reference
    processing_fee NUMERIC(10,2) DEFAULT 0,
    
    -- Payment details
    paid_by_user_id UUID REFERENCES users(id),
    received_by_user_id UUID REFERENCES users(id),
    
    -- Dates
    paid_at TIMESTAMPTZ ,
    processed_at TIMESTAMPTZ,
    
    -- Status and verification
    payment_status VARCHAR(20) DEFAULT 'completed' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
    verification_status VARCHAR(20) DEFAULT 'pending' CHECK (verification_status IN ('pending', 'verified', 'rejected')),
    verified_by_user_id UUID REFERENCES users(id),
    verified_at TIMESTAMPTZ,
    
    -- Attachments and notes
    receipt_url TEXT,
    slip_image_url TEXT,
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Generate payment number trigger
CREATE OR REPLACE FUNCTION generate_payment_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.payment_number IS NULL THEN
        NEW.payment_number := 'PAY-' || TO_CHAR(NOW(), 'YYYYMM') || '-' || LPAD(nextval('payment_sequence')::text, 5, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS payment_sequence START 1;

CREATE TRIGGER set_payment_number BEFORE INSERT ON payments
FOR EACH ROW EXECUTE FUNCTION generate_payment_number();

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 15. MAINTENANCE REQUESTS
-- =========================================
CREATE TABLE IF NOT EXISTS maintenance_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_number VARCHAR(50) UNIQUE,
    unit_id UUID REFERENCES units(id) ON DELETE CASCADE,
    tenant_user_id UUID REFERENCES users(id),
    assigned_to_user_id UUID REFERENCES users(id),
    
    title VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(30) DEFAULT 'general', -- plumbing, electrical, hvac, general, etc.
    
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'assigned', 'in_progress', 'completed', 'cancelled')),
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    
    -- Scheduling
    requested_date DATE,
    appointment_date TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    due_date TIMESTAMPTZ,
    
    -- Cost and time tracking
    estimated_hours NUMERIC(4,1),
    actual_hours NUMERIC(4,1),
    estimated_cost NUMERIC(10,2),
    actual_cost NUMERIC(10,2),
    
    -- Additional details
    work_summary TEXT,
    tenant_feedback TEXT,
    tenant_rating INTEGER CHECK (tenant_rating BETWEEN 1 AND 5),
    
    is_emergency BOOLEAN DEFAULT false,
    is_recurring BOOLEAN DEFAULT false,
    recurring_schedule VARCHAR(20) CHECK (recurring_schedule IN ('weekly','monthly','quarterly','yearly')), -- weekly, monthly, quarterly
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Generate ticket number trigger
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.ticket_number IS NULL THEN
        NEW.ticket_number := 'TK-' || TO_CHAR(NOW(), 'YYYYMM') || '-' || LPAD(nextval('ticket_sequence')::text, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS ticket_sequence START 1;

CREATE TRIGGER set_ticket_number BEFORE INSERT ON maintenance_requests
FOR EACH ROW EXECUTE FUNCTION generate_ticket_number();

CREATE TRIGGER update_maintenance_requests_updated_at BEFORE UPDATE ON maintenance_requests
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 16. NOTIFICATIONS
-- =========================================
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    apartment_id UUID REFERENCES apartments(id) ON DELETE CASCADE,
    type VARCHAR(30) NOT NULL, -- invoice_generated, payment_received, maintenance_scheduled, etc.
    title VARCHAR(200) NOT NULL,
    message TEXT,
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================
-- 17. AUDIT LOGS (New)
-- =========================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name VARCHAR(50) NOT NULL,
    record_id UUID,
    action VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    changed_by_apartment_user_id UUID REFERENCES apartment_users(id) ON DELETE SET NULL,
    apartment_id UUID REFERENCES apartments(id) ON DELETE CASCADE,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS adhoc_invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    adhoc_number VARCHAR(50) UNIQUE,

    -- References
    apartment_id UUID REFERENCES apartments(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE CASCADE,
    tenant_user_id UUID REFERENCES users(id) ON DELETE SET NULL,

    -- Invoice details
    title VARCHAR(200) NOT NULL,
    description TEXT,
    category VARCHAR(30) DEFAULT 'miscellaneous', -- penalty , miscellaneous

    -- Amount details
    final_amount NUMERIC(10,2) NOT NULL, -- already includes total + tax
    paid_amount NUMERIC(10,2) DEFAULT 0,

    -- Dates
    invoice_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE,

    -- Monthly invoice integration
    include_in_monthly BOOLEAN DEFAULT true,
    target_monthly_invoice_month DATE, -- Which month's invoice to include this in
    monthly_invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL, -- Set when included
    included_at TIMESTAMPTZ, -- When it was included in monthly invoice

    -- Payment tracking
    payment_status VARCHAR(20) DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'cancelled','overdue')),
    paid_at TIMESTAMPTZ,

    -- Admin details
    created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    approved_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,

    -- Status and notes
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('draft', 'active', 'cancelled', 'included')),
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),

    -- Attachments and documentation
    receipt_urls JSONB DEFAULT '[]', -- Array of receipt/document URLs
    images JSONB DEFAULT '[]', -- Array of image URLs (for proof of purchase, etc.)
    notes TEXT,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT check_adhoc_amounts CHECK (
    final_amount >= 0 AND
    paid_amount >= 0 AND
    paid_amount <= final_amount
    ),
    CONSTRAINT check_adhoc_dates CHECK (
    due_date IS NULL OR due_date >= invoice_date
    )
);

CREATE SEQUENCE IF NOT EXISTS adhoc_sequence START 1;

CREATE OR REPLACE FUNCTION generate_adhoc_number()
    RETURNS TRIGGER AS $$
BEGIN
    IF NEW.adhoc_number IS NULL THEN
        NEW.adhoc_number := 'ADHOC-' || TO_CHAR(NOW(), 'YYYYMM') || '-' ||
                            LPAD(nextval('adhoc_sequence')::text, 5, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER set_adhoc_number
    BEFORE INSERT ON adhoc_invoices
    FOR EACH ROW
EXECUTE FUNCTION generate_adhoc_number();

CREATE TRIGGER update_adhoc_invoices_updated_at
    BEFORE UPDATE ON adhoc_invoices
    FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


CREATE TABLE IF NOT EXISTS supplies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    apartment_id UUID REFERENCES apartments(id) ON DELETE CASCADE,

    name VARCHAR(100) NOT NULL,

    -- Category as VARCHAR with allowed values
    category VARCHAR(50) NOT NULL CHECK (category IN ('electrical', 'plumbing', 'cleaning', 'hvac', 'painting', 'general')),

    description TEXT,
    unit VARCHAR(20) NOT NULL,  -- e.g., pcs, liters, boxes
    stock_quantity INT DEFAULT 0 CHECK (stock_quantity >= 0),
    min_stock INT DEFAULT 5 CHECK (min_stock >= 0), -- alert when below this
    cost_per_unit NUMERIC(10,2) DEFAULT 0 CHECK (cost_per_unit >= 0),
    is_deleted BOOLEAN default false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_supplies_updated_at
    BEFORE UPDATE ON supplies
    FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE IF NOT EXISTS maintenance_supplies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    maintenance_request_id UUID REFERENCES maintenance_requests(id) ON DELETE CASCADE,
    supply_id UUID REFERENCES supplies(id) ON DELETE RESTRICT,
    quantity_used INT NOT NULL CHECK (quantity_used > 0),
    cost NUMERIC(10,2) NOT NULL ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS supply_transactions (
   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
   supply_id UUID REFERENCES supplies(id) ON DELETE CASCADE,
   maintenance_request_id UUID REFERENCES maintenance_requests(id),
   apartment_user_id UUID REFERENCES apartment_users(id) ON DELETE SET NULL,
   transaction_type VARCHAR(20) CHECK (transaction_type IN ('purchase', 'use', 'adjustment')),
    number_type VARCHAR(20) CHECK (number_type IN('negative','positive')),
   quantity INT NOT NULL,
   note TEXT,
   created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION calculate_maintenance_supply_cost()
    RETURNS TRIGGER AS $$
DECLARE
    unit_cost NUMERIC(10,2);
BEGIN
    -- Get cost per unit from supplies table
    SELECT cost_per_unit INTO unit_cost FROM supplies WHERE id = NEW.supply_id;

    -- Calculate total cost
    NEW.cost := unit_cost * NEW.quantity_used;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calculate_maintenance_supply_cost
    BEFORE INSERT ON maintenance_supplies
    FOR EACH ROW
EXECUTE FUNCTION calculate_maintenance_supply_cost();



-- =========================================
-- INDEXES
-- =========================================

-- Users indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_active ON users(is_active);
CREATE INDEX idx_users_last_login ON users(last_login);

-- Apartment users indexes
CREATE INDEX idx_apartment_users_apartment ON apartment_users(apartment_id);
CREATE INDEX idx_apartment_users_user ON apartment_users(user_id);
CREATE INDEX idx_apartment_users_role ON apartment_users(role);
CREATE INDEX idx_apartment_users_active ON apartment_users(is_active);

-- Units indexes
CREATE INDEX idx_units_floor ON units(floor_id);
CREATE INDEX idx_units_status ON units(status);
CREATE INDEX idx_units_type ON units(unit_type);

-- Floors and buildings indexes
CREATE INDEX idx_floors_building ON floors(building_id);
CREATE INDEX idx_buildings_apartment ON buildings(apartment_id);
CREATE INDEX idx_buildings_status ON buildings(status);

-- Contract indexes
CREATE INDEX idx_contracts_unit ON contracts(unit_id);
CREATE INDEX idx_contracts_tenant ON contracts(tenant_user_id);
CREATE INDEX idx_contracts_status ON contracts(status);
CREATE INDEX idx_contracts_dates ON contracts(start_date, end_date);
CREATE INDEX idx_contracts_number ON contracts(contract_number);

-- Invoice indexes
CREATE INDEX idx_invoices_unit_month ON invoices(unit_id, generation_month);
CREATE INDEX idx_invoices_tenant ON invoices(tenant_user_id);
CREATE INDEX idx_invoices_status ON invoices(payment_status);
CREATE INDEX idx_invoices_due_date ON invoices(due_date);
CREATE INDEX idx_invoices_apartment ON invoices(apartment_id);
CREATE INDEX idx_invoices_number ON invoices(invoice_number);

-- Payment indexes
CREATE INDEX idx_payments_invoice ON payments(invoice_id);
CREATE INDEX idx_payments_user ON payments(paid_by_user_id);
CREATE INDEX idx_payments_date ON payments(paid_at);
CREATE INDEX idx_payments_status ON payments(payment_status);
CREATE INDEX idx_payments_number ON payments(payment_number);

-- Unit utilities indexes
CREATE INDEX idx_unit_utilities_unit_month ON unit_utilities(unit_id, usage_month);
CREATE INDEX idx_unit_utilities_utility ON unit_utilities(utility_id);

-- Maintenance request indexes
CREATE INDEX idx_maintenance_unit ON maintenance_requests(unit_id);
CREATE INDEX idx_maintenance_tenant ON maintenance_requests(tenant_user_id);
CREATE INDEX idx_maintenance_assigned ON maintenance_requests(assigned_to_user_id);
CREATE INDEX idx_maintenance_status ON maintenance_requests(status);
CREATE INDEX idx_maintenance_priority ON maintenance_requests(priority);
CREATE INDEX idx_maintenance_dates ON maintenance_requests(requested_date, due_date);
CREATE INDEX idx_maintenance_ticket ON maintenance_requests(ticket_number);

-- Notification indexes
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_apartment ON notifications(apartment_id);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read, created_at);

-- Audit log indexes
CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(changed_by_apartment_user_id);
CREATE INDEX idx_audit_logs_apartment ON audit_logs(apartment_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at);

-- Apartment status index
CREATE INDEX idx_apartments_status ON apartments(status);

-- ad-hoc invoice
CREATE INDEX idx_adhoc_invoices_apartment ON adhoc_invoices(apartment_id);
CREATE INDEX idx_adhoc_invoices_unit ON adhoc_invoices(unit_id);
CREATE INDEX idx_adhoc_invoices_tenant ON adhoc_invoices(tenant_user_id);
CREATE INDEX idx_adhoc_invoices_number ON adhoc_invoices(adhoc_number);
CREATE INDEX idx_adhoc_invoices_status ON adhoc_invoices(status);
CREATE INDEX idx_adhoc_invoices_payment_status ON adhoc_invoices(payment_status);
CREATE INDEX idx_adhoc_invoices_category ON adhoc_invoices(category);
CREATE INDEX idx_adhoc_invoices_date ON adhoc_invoices(invoice_date);
CREATE INDEX idx_adhoc_invoices_monthly_target ON adhoc_invoices(target_monthly_invoice_month, include_in_monthly) WHERE include_in_monthly = true;
CREATE INDEX idx_adhoc_invoices_pending_inclusion ON adhoc_invoices(apartment_id, target_monthly_invoice_month, include_in_monthly, status) WHERE include_in_monthly = true AND monthly_invoice_id IS NULL AND status = 'active';

ALTER TABLE apartments ENABLE ROW LEVEL SECURITY;
ALTER TABLE apartment_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_requests ENABLE ROW LEVEL SECURITY;


CREATE INDEX idx_invoices_unpaid ON invoices(unit_id, due_date) 
WHERE payment_status IN ('unpaid', 'partially_paid');

CREATE INDEX idx_contracts_active ON contracts(unit_id, start_date, end_date)
WHERE status = 'active';

CREATE INDEX idx_maintenance_open ON maintenance_requests(unit_id, created_at)
WHERE status IN ('pending', 'assigned', 'in_progress');


-- Additional check constraints
ALTER TABLE contracts ADD CONSTRAINT check_contract_dates 
CHECK (end_date IS NULL OR end_date >= start_date);

ALTER TABLE invoices ADD CONSTRAINT check_invoice_amounts 
CHECK (total_amount >= 0 AND paid_amount >= 0 AND paid_amount <= total_amount);

ALTER TABLE payments ADD CONSTRAINT check_payment_amount 
CHECK (amount > 0);

ALTER TABLE unit_utilities ADD CONSTRAINT check_meter_readings 
CHECK (meter_end IS NULL OR meter_start IS NULL OR meter_end >= meter_start);

--==================================================
-- MOCK DATA ----------------------------------------
--==================================================
-- Create Apartment and return ID
DO $$
DECLARE
    v_apartment_id UUID;
    v_admin_user_id UUID;
    v_admin_apartment_user_id UUID;
BEGIN
    SELECT id INTO v_admin_user_id FROM users WHERE email = 'admin@example.com';

    INSERT INTO apartments (id, name, address, city, created_by_user_id, status)
    VALUES (
               gen_random_uuid(),
               'GreenVille Apartment',
               '123 Sukhumvit Rd, Bangkok',
               'Bangkok',
               v_admin_user_id,
               'active'
           )
    RETURNING id INTO v_apartment_id;

    INSERT INTO apartment_users (id, apartment_id, user_id, role, created_by_user_id)
    VALUES (
               gen_random_uuid(),
               v_apartment_id,
               v_admin_user_id,
               'admin',
               v_admin_user_id
           )
    RETURNING id INTO v_admin_apartment_user_id;

    RAISE NOTICE '✅ Apartment Created: %, Admin Linked: %', v_apartment_id, v_admin_apartment_user_id;
END $$;

DO $$
DECLARE
    v_apartment_id UUID;
    v_building_id UUID;
BEGIN
    SELECT id INTO v_apartment_id FROM apartments WHERE name = 'GreenVille Apartment';

    INSERT INTO buildings (id, apartment_id, name, total_floors)
    VALUES (
               gen_random_uuid(),
               v_apartment_id,
               'Building A',
               2
           )
    RETURNING id INTO v_building_id;

    RAISE NOTICE '🏢 Building Created: %', v_building_id;
END $$;

DO $$
DECLARE
    v_building_id UUID;
    v_floor1_id UUID;
    v_floor2_id UUID;
BEGIN
    SELECT id INTO v_building_id FROM buildings WHERE name = 'Building A';

    INSERT INTO floors (id, building_id, floor_number, floor_name, total_units)
    VALUES
        (gen_random_uuid(), v_building_id, 1, 'First Floor', 12),
        (gen_random_uuid(), v_building_id, 2, 'Second Floor', 12);

    RAISE NOTICE '🏬 Floors created for Building A';
END $$;

-- Floor 1
DO $$
DECLARE
    v_floor_id UUID;
    i INT;
BEGIN
    SELECT id INTO v_floor_id FROM floors WHERE floor_number = 1;

    FOR i IN 1..12 LOOP
            INSERT INTO units (id, floor_id, unit_name, status)
            VALUES (
                       gen_random_uuid(),
                       v_floor_id,
                       FORMAT('A1-%02s', i),
                       'available'
                   );
        END LOOP;

    RAISE NOTICE '✅ Floor 1: 12 units created';
END $$;

-- Floor 2
DO $$
DECLARE
    v_floor_id UUID;
    i INT;
BEGIN
    SELECT id INTO v_floor_id FROM floors WHERE floor_number = 2;

    FOR i IN 1..12 LOOP
            INSERT INTO units (id, floor_id, unit_name, status)
            VALUES (
                       gen_random_uuid(),
                       v_floor_id,
                       FORMAT('A2-%02s', i),
                       'available'
                   );
        END LOOP;

    RAISE NOTICE '✅ Floor 2: 12 units created';
END $$;

DO $$
    DECLARE
        v_apartment_id UUID;
    BEGIN
        SELECT id INTO v_apartment_id FROM apartments WHERE name = 'GreenVille Apartment';

        -- Electricity
        INSERT INTO utilities (id, apartment_id, utility_name, utility_type, category, unit_price, billing_cycle, is_active)
        VALUES (
                   gen_random_uuid(),
                   v_apartment_id,
                   'electric',
                   'meter',      -- meter-based
                   'utility',
                   4.50,         -- THB per kWh example
                   'monthly',
                   TRUE
               );

        -- Water
        INSERT INTO utilities (id, apartment_id, utility_name, utility_type, category, unit_price, billing_cycle, is_active)
        VALUES (
                   gen_random_uuid(),
                   v_apartment_id,
                   'water',
                   'meter',      -- meter-based
                   'utility',
                   25.00,        -- THB per cubic meter example
                   'monthly',
                   TRUE
               );

        RAISE NOTICE '✅ Utilities (Water & Electricity) added for Apartment %', v_apartment_id;
    END $$;
DO $$
DECLARE
    v_apartment_id UUID;
    v_admin_user_id UUID;
BEGIN
    -- Get apartment id
    SELECT id INTO v_apartment_id FROM apartments WHERE name = 'GreenVille Apartment';

    -- Get admin user id
    SELECT id INTO v_admin_user_id FROM users WHERE email = 'admin@example.com';

    -- Bank Transfer
    INSERT INTO apartment_payment_methods (
        id, apartment_id, method_name, method_type, bank_name, bank_account_number, account_holder_name,
        processing_fee_percentage, is_active, created_by_user_id
    )
    VALUES (
               gen_random_uuid(),
               v_apartment_id,
               'bank_transfer',
               'bank_transfer',
               'Bangkok Bank',
               '123-456-7890',
               'GreenVille Apartment Co., Ltd.',
               0.0,
               TRUE,
               v_admin_user_id
           );

    RAISE NOTICE '✅ Apartment Payment Methods added for Apartment %', v_apartment_id;
END $$;

DO $$
DECLARE
    v_apartment_id UUID;
BEGIN
    -- Get apartment id
    SELECT id INTO v_apartment_id FROM apartments WHERE name = 'GreenVille Apartment';

    -- ===============================
    -- Add default extra services with proper categories
    -- ===============================
    INSERT INTO extra_services (
        apartment_id,
        service_name,
        description,
        price,
        billing_type,
        category,
        requires_approval,
        max_quantity,
        is_active,
        created_at,
        updated_at
    )
    VALUES
        (v_apartment_id, 'Gym Access', 'Access to the apartment gym facilities', 500, 'monthly', 'gym', false, 1, TRUE, NOW(), NOW()),
        (v_apartment_id, 'Swimming Pool', 'Access to the swimming pool', 300, 'monthly', 'pool', false, 1, TRUE, NOW(), NOW()),
        (v_apartment_id, 'Reserved Parking', 'Reserved parking space per month', 1000, 'monthly', 'parking', true, 1, TRUE, NOW(), NOW()),
        (v_apartment_id, 'Housekeeping', 'Weekly housekeeping service', 800, 'monthly', 'service', true, 1, TRUE, NOW(), NOW()),
        (v_apartment_id, 'Security Monitoring', '24/7 security monitoring', 400, 'monthly', 'security', false, 1, TRUE, NOW(), NOW());

    RAISE NOTICE '✅ Default apartment extra services added for Apartment %', v_apartment_id;
END $$;
-- Function to clean up old audit logs (older than 2 years)
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM audit_logs 
    WHERE created_at < NOW() - INTERVAL '2 years';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up old notifications (older than 6 months)
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM notifications 
    WHERE created_at < NOW() - INTERVAL '6 months'
    OR (expires_at IS NOT NULL AND expires_at < NOW());
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;


