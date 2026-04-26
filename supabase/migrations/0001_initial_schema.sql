-- ============================================================
-- Motrix — Schema inicial
-- Migración: 0001_initial_schema.sql
-- ============================================================

-- ============================================================
-- TENANTS
-- ============================================================
CREATE TABLE tenants (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name           TEXT NOT NULL,
  slug           TEXT UNIQUE NOT NULL,
  plan           TEXT NOT NULL DEFAULT 'trial' CHECK (plan IN ('trial', 'active', 'suspended')),
  business_name  TEXT,
  rut            TEXT,
  address        TEXT,
  phone          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- PROFILES (extiende auth.users de Supabase)
-- ============================================================
CREATE TABLE profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  full_name   TEXT,
  role        TEXT NOT NULL DEFAULT 'mechanic' CHECK (role IN ('owner', 'mechanic')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- CLIENTS
-- ============================================================
CREATE TABLE clients (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  full_name   TEXT NOT NULL,
  phone       TEXT,
  email       TEXT,
  rut         TEXT,
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- MOTORCYCLES
-- ============================================================
CREATE TABLE motorcycles (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  client_id    UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  brand        TEXT NOT NULL,
  model        TEXT NOT NULL,
  year         INT,
  displacement INT,
  plate        TEXT,
  color        TEXT,
  vin          TEXT,
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- WORK ORDERS (OT)
-- ============================================================
CREATE TABLE work_orders (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  motorcycle_id    UUID NOT NULL REFERENCES motorcycles(id),
  client_id        UUID NOT NULL REFERENCES clients(id),
  code             TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'reception' CHECK (
                     status IN ('reception', 'diagnosis', 'repair', 'ready', 'delivered')
                   ),
  description      TEXT,
  diagnosis        TEXT,
  reception_notes  TEXT,
  assigned_to      UUID REFERENCES profiles(id),
  received_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  estimated_at     TIMESTAMPTZ,
  delivered_at     TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(tenant_id, code)
);

-- ============================================================
-- TRIGGER: actualiza updated_at automáticamente
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER work_orders_updated_at
  BEFORE UPDATE ON work_orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- SECUENCIA DE CÓDIGO OT POR TENANT
-- Genera OT-0001, OT-0002... independiente por taller
-- ============================================================
CREATE TABLE ot_sequences (
  tenant_id   UUID PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE,
  last_number INT NOT NULL DEFAULT 0
);

CREATE OR REPLACE FUNCTION generate_ot_code(p_tenant_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_number INT;
BEGIN
  INSERT INTO ot_sequences (tenant_id, last_number)
  VALUES (p_tenant_id, 1)
  ON CONFLICT (tenant_id) DO UPDATE
    SET last_number = ot_sequences.last_number + 1
  RETURNING last_number INTO v_number;

  RETURN 'OT-' || LPAD(v_number::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Helper: obtiene tenant_id del usuario autenticado desde el JWT
CREATE OR REPLACE FUNCTION auth_tenant_id()
RETURNS UUID AS $$
  SELECT (auth.jwt() -> 'user_metadata' ->> 'tenant_id')::UUID;
$$ LANGUAGE sql STABLE;

-- Helper: obtiene rol del usuario autenticado
CREATE OR REPLACE FUNCTION auth_user_role()
RETURNS TEXT AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE;

-- Habilitar RLS en todas las tablas
ALTER TABLE tenants       ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles      ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients       ENABLE ROW LEVEL SECURITY;
ALTER TABLE motorcycles   ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_orders   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ot_sequences  ENABLE ROW LEVEL SECURITY;

-- TENANTS: cada usuario solo ve su tenant
CREATE POLICY "tenant_select" ON tenants
  FOR SELECT USING (id = auth_tenant_id());

-- PROFILES: solo perfiles del mismo tenant
CREATE POLICY "profiles_select" ON profiles
  FOR SELECT USING (tenant_id = auth_tenant_id());

CREATE POLICY "profiles_insert" ON profiles
  FOR INSERT WITH CHECK (tenant_id = auth_tenant_id());

CREATE POLICY "profiles_update" ON profiles
  FOR UPDATE USING (tenant_id = auth_tenant_id());

-- CLIENTS
CREATE POLICY "clients_all" ON clients
  FOR ALL USING (tenant_id = auth_tenant_id())
  WITH CHECK (tenant_id = auth_tenant_id());

-- MOTORCYCLES
CREATE POLICY "motorcycles_all" ON motorcycles
  FOR ALL USING (tenant_id = auth_tenant_id())
  WITH CHECK (tenant_id = auth_tenant_id());

-- WORK ORDERS
CREATE POLICY "work_orders_all" ON work_orders
  FOR ALL USING (tenant_id = auth_tenant_id())
  WITH CHECK (tenant_id = auth_tenant_id());

-- OT SEQUENCES
CREATE POLICY "ot_sequences_all" ON ot_sequences
  FOR ALL USING (tenant_id = auth_tenant_id())
  WITH CHECK (tenant_id = auth_tenant_id());

  -- ============================================================
-- ÍNDICES para performance
-- ============================================================
CREATE INDEX idx_profiles_tenant        ON profiles(tenant_id);
CREATE INDEX idx_clients_tenant         ON clients(tenant_id);
CREATE INDEX idx_motorcycles_tenant     ON motorcycles(tenant_id);
CREATE INDEX idx_motorcycles_client     ON motorcycles(client_id);
CREATE INDEX idx_work_orders_tenant     ON work_orders(tenant_id);
CREATE INDEX idx_work_orders_status     ON work_orders(tenant_id, status);
CREATE INDEX idx_work_orders_client     ON work_orders(client_id);
CREATE INDEX idx_work_orders_motorcycle ON work_orders(motorcycle_id);