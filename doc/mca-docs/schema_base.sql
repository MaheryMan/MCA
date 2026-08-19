-- ============================================================
-- MCA - Module Pré-Comptabilité — SCHÉMA SIMPLIFIÉ (v1 / MVP)
-- Basé sur schema_part1.sql + schema_part2.sql, épuré pour démarrage rapide
-- PostgreSQL 14+
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. AUTH & ORGANISATION
-- ============================================================

CREATE TABLE roles (
    id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nom  VARCHAR(50) NOT NULL UNIQUE      -- admin, comptable, operateur_saisie...
);

CREATE TABLE users (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email          VARCHAR(255) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    first_name     VARCHAR(100) NOT NULL,
    last_name      VARCHAR(100) NOT NULL,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE companies (
    id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name      VARCHAR(255) NOT NULL,
    nif       VARCHAR(50),
    address   TEXT,
    currency  VARCHAR(3) NOT NULL DEFAULT 'MGA',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Table pivot : un utilisateur peut appartenir à plusieurs entreprises, avec un rôle
CREATE TABLE user_companies (
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    role_id    UUID NOT NULL REFERENCES roles(id),
    PRIMARY KEY (user_id, company_id)
);

CREATE TABLE fiscal_years (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    label      VARCHAR(50) NOT NULL,      -- ex: "Exercice 2026"
    start_date DATE NOT NULL,
    end_date   DATE NOT NULL,
    is_closed  BOOLEAN NOT NULL DEFAULT FALSE
);

-- ============================================================
-- 2. IMPORT & DOCUMENTS (OCR)
-- ============================================================

CREATE TABLE document_batches (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id  UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    uploaded_by UUID NOT NULL REFERENCES users(id),
    status      VARCHAR(20) NOT NULL DEFAULT 'pending',   -- pending, processing, completed, failed
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE documents (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    batch_id          UUID REFERENCES document_batches(id) ON DELETE SET NULL,
    company_id        UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    file_name         VARCHAR(500) NOT NULL,
    file_path         TEXT NOT NULL,
    file_hash         VARCHAR(128) NOT NULL,   -- SHA-256, sert à la détection de doublons
    status            VARCHAR(20) NOT NULL DEFAULT 'uploaded', -- uploaded, ocr_done, processed, error
    processing_score  DECIMAL(5,2) NOT NULL DEFAULT 0,         -- score de pré-traitement (0-100)
    created_at        TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_documents_hash ON documents(file_hash);

CREATE TABLE ocr_results (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id      UUID NOT NULL UNIQUE REFERENCES documents(id) ON DELETE CASCADE,
    raw_text         TEXT,
    structured_data  JSONB,               -- champs extraits : fournisseur, montant, date...
    detected_type    VARCHAR(50),         -- invoice, credit_note, receipt
    confidence_score DECIMAL(5,2)
);

-- Doublons détectés (hash identique, n° facture, montant+date...)
CREATE TABLE duplicate_groups (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    status     VARCHAR(20) NOT NULL DEFAULT 'pending'   -- pending, confirmed, dismissed
);

CREATE TABLE duplicate_group_items (
    group_id    UUID NOT NULL REFERENCES duplicate_groups(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    is_original BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (group_id, document_id)
);

-- ============================================================
-- 3. RÉFÉRENTIEL COMPTABLE
-- ============================================================

CREATE TABLE chart_of_accounts (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    account_number VARCHAR(20) NOT NULL,
    label          VARCHAR(255) NOT NULL,
    account_type   VARCHAR(20) NOT NULL,   -- asset, liability, equity, revenue, expense
    UNIQUE(company_id, account_number)
);

CREATE TABLE journals (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id   UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    code         VARCHAR(10) NOT NULL,     -- AC, VE, BQ, CA, OD
    label        VARCHAR(100) NOT NULL,
    journal_type VARCHAR(20) NOT NULL,     -- purchase, sale, bank, cash, misc
    UNIQUE(company_id, code)
);

CREATE TABLE tax_rates (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    label      VARCHAR(100) NOT NULL,      -- ex: "TVA 20%"
    rate       DECIMAL(5,2) NOT NULL
);

-- ============================================================
-- 4. FOURNISSEURS & FACTURES
-- ============================================================

CREATE TABLE suppliers (
    id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id         UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name               VARCHAR(255) NOT NULL,
    nif                VARCHAR(50),
    email              VARCHAR(255),
    default_account_id UUID REFERENCES chart_of_accounts(id)
);

CREATE TABLE invoices (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    document_id    UUID REFERENCES documents(id),
    supplier_id    UUID REFERENCES suppliers(id),
    fiscal_year_id UUID REFERENCES fiscal_years(id),
    invoice_number VARCHAR(100),
    invoice_date   DATE,
    subtotal       DECIMAL(15,2) NOT NULL DEFAULT 0,
    tax_amount     DECIMAL(15,2) NOT NULL DEFAULT 0,
    total          DECIMAL(15,2) NOT NULL DEFAULT 0,
    status         VARCHAR(20) NOT NULL DEFAULT 'draft',  -- draft, to_review, validated, accounted, rejected
    created_by     UUID NOT NULL REFERENCES users(id),
    created_at     TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invoices_company_status ON invoices(company_id, status);

CREATE TABLE invoice_lines (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id  UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    label       VARCHAR(255) NOT NULL,
    quantity    DECIMAL(10,2) NOT NULL DEFAULT 1,
    unit_price  DECIMAL(15,2) NOT NULL DEFAULT 0,
    tax_rate_id UUID REFERENCES tax_rates(id),
    amount      DECIMAL(15,2) NOT NULL DEFAULT 0
);

-- ============================================================
-- 5. ÉCRITURES COMPTABLES
-- ============================================================

CREATE TABLE journal_entries (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    journal_id     UUID NOT NULL REFERENCES journals(id),
    fiscal_year_id UUID NOT NULL REFERENCES fiscal_years(id),
    invoice_id     UUID REFERENCES invoices(id),
    entry_number   VARCHAR(50) NOT NULL,
    entry_date     DATE NOT NULL,
    label          VARCHAR(255) NOT NULL,
    status         VARCHAR(20) NOT NULL DEFAULT 'draft',   -- draft, posted, reversed
    created_by     UUID NOT NULL REFERENCES users(id),
    UNIQUE(company_id, entry_number)
);

CREATE TABLE journal_entry_lines (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entry_id   UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES chart_of_accounts(id),
    label      VARCHAR(255),
    debit      DECIMAL(15,2) NOT NULL DEFAULT 0,
    credit     DECIMAL(15,2) NOT NULL DEFAULT 0
);

-- ============================================================
-- FIN — schema_base.sql
-- Non inclus volontairement dans cette v1 (à ajouter plus tard) :
-- sessions, audit_logs, categories, payment_methods, notifications,
-- soft delete (deleted_at), triggers updated_at, vues (grand livre,
-- balance, KPIs), contraintes CHECK détaillées, export FEC.
-- ============================================================
