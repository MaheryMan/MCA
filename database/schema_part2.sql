-- ============================================================
-- MCA - Module Pré-Comptabilité — Schéma Complet (Partie 2)
-- Référentiel, Factures, Comptabilité, Vues
-- Soft delete (deleted_at) sur les tables métier
-- ============================================================

-- ============================================================
-- MODULE 4 : RÉFÉRENTIEL
-- ============================================================

-- PLAN COMPTABLE
CREATE TABLE chart_of_accounts (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    parent_id      UUID REFERENCES chart_of_accounts(id),
    account_number VARCHAR(20) NOT NULL,
    label          VARCHAR(255) NOT NULL,
    account_type   VARCHAR(20) NOT NULL,
    is_leaf        BOOLEAN NOT NULL DEFAULT TRUE,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    deleted_at     TIMESTAMP NULL,
    created_at     TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_account_type CHECK (account_type IN ('asset','liability','equity','revenue','expense')),
    UNIQUE(company_id, account_number)
);

CREATE INDEX idx_coa_company ON chart_of_accounts(company_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_coa_number ON chart_of_accounts(company_id, account_number) WHERE deleted_at IS NULL;
CREATE INDEX idx_coa_parent ON chart_of_accounts(parent_id);

CREATE TRIGGER trg_coa_updated_at
    BEFORE UPDATE ON chart_of_accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- JOURNAUX
CREATE TABLE journals (
    id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id         UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    code               VARCHAR(10) NOT NULL,
    label              VARCHAR(100) NOT NULL,
    journal_type       VARCHAR(20) NOT NULL,
    default_account_id UUID REFERENCES chart_of_accounts(id),
    is_active          BOOLEAN NOT NULL DEFAULT TRUE,
    deleted_at         TIMESTAMP NULL,
    created_at         TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_journal_type CHECK (journal_type IN ('purchase','sale','bank','cash','misc')),
    UNIQUE(company_id, code)
);

CREATE INDEX idx_journals_company ON journals(company_id) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_journals_updated_at
    BEFORE UPDATE ON journals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- TAUX DE TVA
CREATE TABLE tax_rates (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    code       VARCHAR(20) NOT NULL,
    label      VARCHAR(100) NOT NULL,
    rate       DECIMAL(5,2) NOT NULL,
    account_id UUID REFERENCES chart_of_accounts(id),
    is_active  BOOLEAN NOT NULL DEFAULT TRUE,
    deleted_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_tax_rate CHECK (rate >= 0 AND rate <= 100)
);

CREATE INDEX idx_tax_rates_company ON tax_rates(company_id) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_tax_rates_updated_at
    BEFORE UPDATE ON tax_rates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CATEGORIES
CREATE TABLE categories (
    id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id         UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    parent_id          UUID REFERENCES categories(id),
    name               VARCHAR(100) NOT NULL,
    code               VARCHAR(20),
    default_account_id UUID REFERENCES chart_of_accounts(id),
    is_active          BOOLEAN NOT NULL DEFAULT TRUE,
    deleted_at         TIMESTAMP NULL,
    created_at         TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_categories_company ON categories(company_id) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_categories_updated_at
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- MOYENS DE PAIEMENT
CREATE TABLE payment_methods (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name       VARCHAR(100) NOT NULL,
    code       VARCHAR(20) NOT NULL,
    is_active  BOOLEAN NOT NULL DEFAULT TRUE,
    deleted_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payment_methods_company ON payment_methods(company_id) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_payment_methods_updated_at
    BEFORE UPDATE ON payment_methods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- MODULE 5 : FOURNISSEURS & FACTURES
-- ============================================================

-- FOURNISSEURS
CREATE TABLE suppliers (
    id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id         UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name               VARCHAR(255) NOT NULL,
    code               VARCHAR(50),
    nif                VARCHAR(50),
    stat               VARCHAR(50),
    email              VARCHAR(255),
    phone              VARCHAR(50),
    address            TEXT,
    default_account_id UUID REFERENCES chart_of_accounts(id),
    default_journal_id UUID REFERENCES journals(id),
    payment_terms_days INT NOT NULL DEFAULT 30,
    metadata           JSONB DEFAULT '{}',
    is_active          BOOLEAN NOT NULL DEFAULT TRUE,
    deleted_at         TIMESTAMP NULL,
    created_at         TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_suppliers_company ON suppliers(company_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_suppliers_name ON suppliers(company_id, name) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_suppliers_updated_at
    BEFORE UPDATE ON suppliers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- FACTURES
CREATE TABLE invoices (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id       UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    document_id      UUID REFERENCES documents(id),
    supplier_id      UUID REFERENCES suppliers(id),
    category_id      UUID REFERENCES categories(id),
    fiscal_year_id   UUID REFERENCES fiscal_years(id),
    invoice_number   VARCHAR(100),
    invoice_type     VARCHAR(20) NOT NULL DEFAULT 'invoice',
    direction        VARCHAR(10) NOT NULL DEFAULT 'inbound',
    invoice_date     DATE,
    due_date         DATE,
    currency         VARCHAR(3) NOT NULL DEFAULT 'MGA',
    subtotal         DECIMAL(15,2) NOT NULL DEFAULT 0,
    tax_amount       DECIMAL(15,2) NOT NULL DEFAULT 0,
    total            DECIMAL(15,2) NOT NULL DEFAULT 0,
    payment_status   VARCHAR(20) NOT NULL DEFAULT 'unpaid',
    status           VARCHAR(20) NOT NULL DEFAULT 'draft',
    processing_score DECIMAL(5,2) NOT NULL DEFAULT 0,
    validated_by     UUID REFERENCES users(id),
    validated_at     TIMESTAMP NULL,
    notes            TEXT,
    ocr_corrections  JSONB DEFAULT '{}',
    created_by       UUID NOT NULL REFERENCES users(id),
    deleted_at       TIMESTAMP NULL,
    created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_inv_type CHECK (invoice_type IN ('invoice','credit_note','receipt')),
    CONSTRAINT chk_inv_direction CHECK (direction IN ('inbound','outbound')),
    CONSTRAINT chk_inv_pay_status CHECK (payment_status IN ('unpaid','partial','paid')),
    CONSTRAINT chk_inv_status CHECK (status IN ('draft','to_review','validated','accounted','rejected'))
);

CREATE INDEX idx_invoices_company_status ON invoices(company_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_invoices_supplier ON invoices(supplier_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_invoices_date ON invoices(invoice_date) WHERE deleted_at IS NULL;
CREATE INDEX idx_invoices_number ON invoices(company_id, invoice_number) WHERE deleted_at IS NULL;
CREATE INDEX idx_invoices_document ON invoices(document_id);
CREATE INDEX idx_invoices_score ON invoices(processing_score) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_invoices_updated_at
    BEFORE UPDATE ON invoices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- LIGNES DE FACTURE (liées à la facture — soft delete via parent)
CREATE TABLE invoice_lines (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id  UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    line_number INT NOT NULL,
    description TEXT,
    account_id  UUID REFERENCES chart_of_accounts(id),
    quantity    DECIMAL(10,3) NOT NULL DEFAULT 1,
    unit_price  DECIMAL(15,2) NOT NULL DEFAULT 0,
    amount_ht   DECIMAL(15,2) NOT NULL DEFAULT 0,
    tax_rate_id UUID REFERENCES tax_rates(id),
    tax_amount  DECIMAL(15,2) NOT NULL DEFAULT 0,
    amount_ttc  DECIMAL(15,2) NOT NULL DEFAULT 0,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invoice_lines_invoice ON invoice_lines(invoice_id);

CREATE TRIGGER trg_invoice_lines_updated_at
    BEFORE UPDATE ON invoice_lines
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- MODULE 6 : ÉCRITURES COMPTABLES
-- ============================================================

-- ÉCRITURES (immuables une fois postées — soft delete pour brouillons)
CREATE TABLE journal_entries (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    journal_id     UUID NOT NULL REFERENCES journals(id),
    fiscal_year_id UUID NOT NULL REFERENCES fiscal_years(id),
    invoice_id     UUID REFERENCES invoices(id),
    entry_number   VARCHAR(50) NOT NULL,
    entry_date     DATE NOT NULL,
    label          VARCHAR(255) NOT NULL,
    reference      VARCHAR(100),
    status         VARCHAR(20) NOT NULL DEFAULT 'draft',
    is_balanced    BOOLEAN NOT NULL DEFAULT TRUE,
    posted_by      UUID REFERENCES users(id),
    posted_at      TIMESTAMP NULL,
    created_by     UUID NOT NULL REFERENCES users(id),
    deleted_at     TIMESTAMP NULL,
    created_at     TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_entry_status CHECK (status IN ('draft','posted','reversed')),
    UNIQUE(company_id, entry_number)
);

CREATE INDEX idx_entries_company_date ON journal_entries(company_id, entry_date) WHERE deleted_at IS NULL;
CREATE INDEX idx_entries_journal ON journal_entries(journal_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_entries_invoice ON journal_entries(invoice_id);
CREATE INDEX idx_entries_fiscal ON journal_entries(fiscal_year_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_entries_status ON journal_entries(company_id, status) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_entries_updated_at
    BEFORE UPDATE ON journal_entries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- LIGNES D'ÉCRITURE (liées à l'écriture — pas de soft delete séparé)
CREATE TABLE journal_entry_lines (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entry_id    UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
    account_id  UUID NOT NULL REFERENCES chart_of_accounts(id),
    label       VARCHAR(255),
    debit       DECIMAL(15,2) NOT NULL DEFAULT 0,
    credit      DECIMAL(15,2) NOT NULL DEFAULT 0,
    tax_rate_id UUID REFERENCES tax_rates(id),
    line_number INT NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_line_amounts CHECK (debit >= 0 AND credit >= 0),
    CONSTRAINT chk_line_not_both CHECK (NOT (debit > 0 AND credit > 0))
);

CREATE INDEX idx_entry_lines_entry ON journal_entry_lines(entry_id);
CREATE INDEX idx_entry_lines_account ON journal_entry_lines(account_id);

-- ============================================================
-- MODULE 7 : NOTIFICATIONS
-- ============================================================

CREATE TABLE notifications (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    type       VARCHAR(50) NOT NULL,
    title      VARCHAR(255) NOT NULL,
    message    TEXT,
    data       JSONB DEFAULT '{}',
    is_read    BOOLEAN NOT NULL DEFAULT FALSE,
    read_at    TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX idx_notifications_date ON notifications(created_at);

-- ============================================================
-- VUES UTILES
-- ============================================================

-- Vue : Documents à traiter (score < 50, non supprimés)
CREATE OR REPLACE VIEW v_documents_to_process AS
SELECT
    d.id, d.file_name, d.processing_score, d.status,
    d.company_id, d.created_at,
    b.label AS batch_label,
    o.detected_type, o.confidence_score
FROM documents d
LEFT JOIN document_batches b ON d.batch_id = b.id
LEFT JOIN ocr_results o ON o.document_id = d.id
WHERE d.deleted_at IS NULL
  AND d.processing_score < 50
  AND d.status NOT IN ('error')
ORDER BY d.processing_score ASC, d.created_at ASC;

-- Vue : Documents pré-traités (score >= 50)
CREATE OR REPLACE VIEW v_documents_pretreated AS
SELECT
    d.id, d.file_name, d.processing_score, d.status,
    d.company_id, d.created_at,
    o.structured_data, o.detected_type, o.confidence_score
FROM documents d
LEFT JOIN ocr_results o ON o.document_id = d.id
WHERE d.deleted_at IS NULL
  AND d.processing_score >= 50
ORDER BY d.processing_score DESC;

-- Vue : Grand Livre
CREATE OR REPLACE VIEW v_grand_livre AS
SELECT
    je.company_id,
    je.entry_date,
    je.entry_number,
    j.code AS journal_code,
    j.label AS journal_label,
    coa.account_number,
    coa.label AS account_label,
    jel.label AS line_label,
    jel.debit,
    jel.credit,
    je.reference,
    je.status
FROM journal_entry_lines jel
JOIN journal_entries je ON jel.entry_id = je.id
JOIN journals j ON je.journal_id = j.id
JOIN chart_of_accounts coa ON jel.account_id = coa.id
WHERE je.deleted_at IS NULL
  AND je.status = 'posted'
ORDER BY coa.account_number, je.entry_date, je.entry_number;

-- Vue : Balance Générale
CREATE OR REPLACE VIEW v_balance_generale AS
SELECT
    je.company_id,
    coa.account_number,
    coa.label AS account_label,
    coa.account_type,
    SUM(jel.debit) AS total_debit,
    SUM(jel.credit) AS total_credit,
    SUM(jel.debit) - SUM(jel.credit) AS solde
FROM journal_entry_lines jel
JOIN journal_entries je ON jel.entry_id = je.id
JOIN chart_of_accounts coa ON jel.account_id = coa.id
WHERE je.deleted_at IS NULL
  AND je.status = 'posted'
GROUP BY je.company_id, coa.account_number, coa.label, coa.account_type
ORDER BY coa.account_number;

-- Vue : Dashboard KPIs factures
CREATE OR REPLACE VIEW v_invoice_kpis AS
SELECT
    company_id,
    COUNT(*) FILTER (WHERE status = 'draft') AS drafts,
    COUNT(*) FILTER (WHERE status = 'to_review') AS to_review,
    COUNT(*) FILTER (WHERE status = 'validated') AS validated,
    COUNT(*) FILTER (WHERE status = 'accounted') AS accounted,
    COUNT(*) FILTER (WHERE status = 'rejected') AS rejected,
    COUNT(*) AS total,
    COALESCE(SUM(total) FILTER (WHERE status = 'accounted'), 0) AS total_accounted,
    COALESCE(AVG(processing_score), 0) AS avg_score
FROM invoices
WHERE deleted_at IS NULL
GROUP BY company_id;

-- ============================================================
-- SEED DATA : Journaux par défaut
-- ============================================================
-- Note: à exécuter après création d'une entreprise
-- Exemple pour une entreprise avec id 'COMPANY_ID' :
--
-- INSERT INTO journals (company_id, code, label, journal_type) VALUES
--     ('COMPANY_ID', 'AC', 'Journal des Achats',      'purchase'),
--     ('COMPANY_ID', 'VE', 'Journal des Ventes',      'sale'),
--     ('COMPANY_ID', 'BQ', 'Journal de Banque',       'bank'),
--     ('COMPANY_ID', 'CA', 'Journal de Caisse',       'cash'),
--     ('COMPANY_ID', 'OD', 'Opérations Diverses',     'misc');
--
-- INSERT INTO tax_rates (company_id, code, label, rate) VALUES
--     ('COMPANY_ID', 'TVA20',  'TVA 20%',        20.00),
--     ('COMPANY_ID', 'TVA0',   'Exonéré de TVA',  0.00);
