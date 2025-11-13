-- Database Schema Design
-- Foundation for multi-tenant behavior

CREATE TABLE companies (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Warehouse name unique per company.
-- One company many warehouses.

CREATE TABLE warehouses (
    id BIGSERIAL PRIMARY KEY,
    company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    location VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (company_id, name)
);

-- SKU unique across platform (global uniqueness).
-- is_bundle distinguishes regular vs bundle products.
-- price uses NUMERIC for precision.

CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    sku VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    price NUMERIC(10, 2),
    is_bundle BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Many-to-many link between products and warehouses, with quantity.
-- Ensures one inventory record per (product, warehouse) pair.
-- quantity updated whenever stock changes.

CREATE TABLE inventory (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    warehouse_id BIGINT NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (product_id, warehouse_id)
);

-- Track every inventory level change.
-- Serves as an immutable audit log.
-- Helps generate stock history, reconcile inventory, and trace issues.

CREATE TABLE inventory_transactions (
    id BIGSERIAL PRIMARY KEY,
    inventory_id BIGINT NOT NULL REFERENCES inventory(id) ON DELETE CASCADE,
    change_type VARCHAR(50) NOT NULL,
    quantity_change INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    note TEXT
);

-- Each company manages its own supplier list.

CREATE TABLE suppliers (
    id BIGSERIAL PRIMARY KEY,
    company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    contact_email VARCHAR(255),
    phone VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (company_id, name)
);

-- Which supplier supplies which product.
-- Enables multiple suppliers for same product, and vice versa.

CREATE TABLE supplier_products (
    id BIGSERIAL PRIMARY KEY,
    supplier_id BIGINT NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    lead_time_days INTEGER,
    cost_price NUMERIC(10, 2),
    UNIQUE (supplier_id, product_id)
);

--For representing bundled products (a recursive relationship).
-- A bundle is a product composed of other products.
-- Prevents self-reference loops.

CREATE TABLE product_bundles (
    bundle_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    component_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (bundle_id, component_id),
    CHECK (bundle_id <> component_id)
);
