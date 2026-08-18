-- ============================================================
-- MCA - Module Pré-Comptabilité — Schéma Complet (Partie 1)
-- Auth, Organisation, Documents, OCR, Doublons
-- Soft delete (deleted_at) sur les tables métier
-- ============================================================

-- Extension UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- FONCTION : updated_at automatique
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- MODULE 1 : AUTHENTIFICATION & UTILISATEURS
-- ============================================================

-- ROLES
CREATE TABLE roles (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    permissions JSONB DEFAULT '{}',
    deleted_at  TIMESTAMP NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

INSERT INTO roles (name, description, permissions) VALUES
    ('admin',           'Administrateur',       '{"all": true}'),
    ('comptable',       'Comptable',            '{"invoices": true, "entries": true, "reports": true}'),
    ('operateur_saisie','Opérateur de saisie',  '{"invoices": true, "documents": true}'),
    ('auditeur',        'Auditeur',             '{"reports": true, "entries.read": true}'),
    ('viewer',          'Lecteur seul',         '{"read": true}');

-- USERS
CREATE TABLE users (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email             VARCHAR(255) NOT NULL UNIQUE,
    password_hash     VARCHAR(255) NOT NULL,
    first_name        VARCHAR(100) NOT NULL,
    last_name         VARCHAR(100) NOT NULL,
    avatar_url        TEXT,
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    email_verified_at TIMESTAMP NULL,
    last_login_at     TIMESTAMP NULL,
    deleted_at        TIMESTAMP NULL,
    created_at        TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- SESSIONS
CREATE TABLE sessions (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token         VARCHAR(500) NOT NULL UNIQUE,
    refresh_token VARCHAR(500) NOT NULL UNIQUE,
    ip_address    VARCHAR(45),
    user_agent    TEXT,
    expires_at    TIMESTAMP NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_user ON sessions(user_id);
CREATE INDEX idx_sessions_token ON sessions(token);
CREATE INDEX idx_sessions_expires ON sessions(expires_at);

-- ============================================================
-- MODULE 2 : ORGANISATION MULTI-ENTREPRISE
-- ============================================================

-- COMPANIES
CREATE TABLE companies (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(255) NOT NULL,
    siren       VARCHAR(20),
    siret       VARCHAR(20),
    nif         VARCHAR(50),
    stat        VARCHAR(50),
    address     TEXT,
    city        VARCHAR(100),
    postal_code VARCHAR(20),
    country     VARCHAR(2) NOT NULL DEFAULT 'MG',
    currency    VARCHAR(3) NOT NULL DEFAULT 'MGA',
    logo_url    TEXT,
    settings    JSONB DEFAULT '{}',
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    deleted_at  TIMESTAMP NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_companies_updated_at
    BEFORE UPDATE ON companies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- USER_COMPANIES (junction — pas de soft delete)
CREATE TABLE user_companies (
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, company_id)
);

-- USER_ROLES (par entreprise — pas de soft delete)
CREATE TABLE user_roles (
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id    UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, role_id, company_id)
);

-- FISCAL_YEARS
CREATE TABLE fiscal_years (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    label      VARCHAR(50) NOT NULL,
    start_date DATE NOT NULL,
    end_date   DATE NOT NULL,
    is_closed  BOOLEAN NOT NULL DEFAULT FALSE,
    closed_at  TIMESTAMP NULL,
    closed_by  UUID REFERENCES users(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_fiscal_dates CHECK (end_date > start_date)
);

CREATE INDEX idx_fiscal_years_company ON fiscal_years(company_id);

CREATE TRIGGER trg_fiscal_years_updated_at
    BEFORE UPDATE ON fiscal_years
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- AUDIT_LOGS (immuable — jamais de delete)
CREATE TABLE audit_logs (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID REFERENCES users(id),
    company_id  UUID REFERENCES companies(id),
    action      VARCHAR(50) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id   UUID NOT NULL,
    old_values  JSONB,
    new_values  JSONB,
    ip_address  VARCHAR(45),
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_company ON audit_logs(company_id);
CREATE INDEX idx_audit_logs_date ON audit_logs(created_at);

-- ============================================================
-- MODULE 3 : IMPORT & DOCUMENTS
-- ============================================================

-- DOCUMENT_BATCHES
CREATE TABLE document_batches (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    uploaded_by     UUID NOT NULL REFERENCES users(id),
    label           VARCHAR(255),
    source          VARCHAR(50) NOT NULL DEFAULT 'upload',
    total_documents INT NOT NULL DEFAULT 0,
    processed_count INT NOT NULL DEFAULT 0,
    failed_count    INT NOT NULL DEFAULT 0,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending',
    deleted_at      TIMESTAMP NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_batch_status CHECK (status IN ('pending','processing','completed','failed'))
);

CREATE INDEX idx_batches_company ON document_batches(company_id) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_batches_updated_at
    BEFORE UPDATE ON document_batches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- DOCUMENTS
CREATE TABLE documents (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    batch_id         UUID REFERENCES document_batches(id) ON DELETE SET NULL,
    company_id       UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    file_name        VARCHAR(500) NOT NULL,
    file_path        TEXT NOT NULL,
    file_size        BIGINT NOT NULL,
    mime_type        VARCHAR(100) NOT NULL,
    file_hash        VARCHAR(128) NOT NULL,
    page_count       INT NOT NULL DEFAULT 1,
    status           VARCHAR(20) NOT NULL DEFAULT 'uploaded',
    processing_score DECIMAL(5,2) NOT NULL DEFAULT 0,
    score_details    JSONB DEFAULT '{}',
    error_message    TEXT,
    metadata         JSONB DEFAULT '{}',
    deleted_at       TIMESTAMP NULL,
    created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_doc_status CHECK (status IN ('uploaded','ocr_pending','ocr_processing','ocr_done','processed','error')),
    CONSTRAINT chk_doc_score CHECK (processing_score >= 0 AND processing_score <= 100)
);

CREATE INDEX idx_documents_hash ON documents(file_hash);
CREATE INDEX idx_documents_company_status ON documents(company_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_score ON documents(processing_score) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_batch ON documents(batch_id);

CREATE TRIGGER trg_documents_updated_at
    BEFORE UPDATE ON documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- OCR_RESULTS (lié au document — pas de soft delete séparé)
CREATE TABLE ocr_results (
    id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id        UUID NOT NULL UNIQUE REFERENCES documents(id) ON DELETE CASCADE,
    raw_text           TEXT,
    structured_data    JSONB,
    detected_type      VARCHAR(50),
    confidence_score   DECIMAL(5,2),
    field_scores       JSONB DEFAULT '{}',
    provider           VARCHAR(50),
    processing_time_ms INT,
    created_at         TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_ocr_type CHECK (detected_type IN ('invoice','credit_note','receipt','other') OR detected_type IS NULL),
    CONSTRAINT chk_ocr_confidence CHECK ((confidence_score >= 0 AND confidence_score <= 100) OR confidence_score IS NULL)
);

CREATE INDEX idx_ocr_document ON ocr_results(document_id);

-- DUPLICATE_GROUPS
CREATE TABLE duplicate_groups (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id  UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    match_type  VARCHAR(50) NOT NULL,
    match_score DECIMAL(5,2),
    status      VARCHAR(20) NOT NULL DEFAULT 'pending',
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMP NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_dup_status CHECK (status IN ('pending','confirmed','dismissed')),
    CONSTRAINT chk_dup_match CHECK (match_type IN ('hash','invoice_number','amount_date','fuzzy'))
);

CREATE INDEX idx_dup_groups_company ON duplicate_groups(company_id, status);

-- DUPLICATE_GROUP_ITEMS
CREATE TABLE duplicate_group_items (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id    UUID NOT NULL REFERENCES duplicate_groups(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    is_original BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE(group_id, document_id)
);

CREATE INDEX idx_dup_items_group ON duplicate_group_items(group_id);
CREATE INDEX idx_dup_items_doc ON duplicate_group_items(document_id);
