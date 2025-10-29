/*
  # AwakenU - Real-time Customer Feedback Platform
  Complete Multi-tenant SaaS Schema

  ## Overview
  Enterprise-grade multi-tenant platform for real-time email feedback analysis
  with sentiment classification, urgency detection, and automated workflows.

  ## Tables

  ### Core Identity & Tenancy
  1. `tenants` - Client organizations (multi-tenant isolation root)
  2. `users` - User accounts linked to auth.users
  3. `tenant_memberships` - Many-to-many user-tenant relationships with roles
  
  ### Subscription & Billing
  4. `subscription_plans` - Plan definitions (Free/Pro/Enterprise)
  5. `subscriptions` - Active subscriptions per tenant
  6. `billing_events` - Stripe webhook events log

  ### Email Integration
  7. `email_integrations` - Connected email providers (Gmail, Graph, IMAP, SendGrid)
  8. `oauth_tokens` - Encrypted OAuth credentials
  
  ### Feedback & Analysis
  9. `feedback_items` - Classified customer messages (core data)
  10. `feedback_attachments` - Email attachments metadata
  11. `feedback_comments` - Internal team notes
  12. `feedback_tags` - Custom categorization
  
  ### Alerts & Notifications
  13. `alerts` - High-priority item notifications
  14. `notification_rules` - User-defined alert rules
  
  ### Automation
  15. `auto_reply_templates` - Response templates
  16. `workflow_automations` - Automated actions
  
  ### Export & Reporting
  17. `export_jobs` - Background export task queue
  18. `report_snapshots` - Saved analytics reports
  
  ### Audit & System
  19. `audit_logs` - Complete activity trail
  20. `system_events` - Background job events
  
  ## Security
  - Row Level Security (RLS) on ALL tables
  - Tenant isolation enforced at database level
  - Encrypted OAuth tokens
  - Comprehensive audit logging

  ## Indexes
  - Optimized for dashboard queries (sentiment, urgency, date ranges)
  - Full-text search on feedback body
  - Efficient filtering and aggregations
*/

-- Drop existing tables if recreating
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS system_events CASCADE;
DROP TABLE IF EXISTS export_jobs CASCADE;
DROP TABLE IF EXISTS report_snapshots CASCADE;
DROP TABLE IF EXISTS workflow_automations CASCADE;
DROP TABLE IF EXISTS auto_reply_templates CASCADE;
DROP TABLE IF EXISTS notification_rules CASCADE;
DROP TABLE IF EXISTS alerts CASCADE;
DROP TABLE IF EXISTS feedback_tags CASCADE;
DROP TABLE IF EXISTS feedback_comments CASCADE;
DROP TABLE IF EXISTS feedback_attachments CASCADE;
DROP TABLE IF EXISTS feedback_items CASCADE;
DROP TABLE IF EXISTS oauth_tokens CASCADE;
DROP TABLE IF EXISTS email_integrations CASCADE;
DROP TABLE IF EXISTS billing_events CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS subscription_plans CASCADE;
DROP TABLE IF EXISTS tenant_memberships CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS tenants CASCADE;

-- Create subscription plans first
CREATE TABLE subscription_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  slug text NOT NULL UNIQUE,
  display_name text NOT NULL,
  description text,
  price_monthly numeric(10,2) NOT NULL DEFAULT 0,
  price_yearly numeric(10,2) NOT NULL DEFAULT 0,
  features jsonb NOT NULL DEFAULT '{}',
  limits jsonb NOT NULL DEFAULT '{}',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create tenants
CREATE TABLE tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE,
  domain text,
  logo_url text,
  settings jsonb DEFAULT '{}',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create users table (extends auth.users)
CREATE TABLE users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  full_name text,
  avatar_url text,
  preferences jsonb DEFAULT '{}',
  last_seen_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create tenant memberships (many-to-many with roles)
CREATE TABLE tenant_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  role text NOT NULL DEFAULT 'client',
  permissions jsonb DEFAULT '[]',
  is_active boolean DEFAULT true,
  invited_by uuid REFERENCES users(id),
  joined_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  UNIQUE(tenant_id, user_id)
);

-- Create subscriptions
CREATE TABLE subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  plan_id uuid REFERENCES subscription_plans(id) NOT NULL,
  stripe_customer_id text,
  stripe_subscription_id text,
  status text NOT NULL DEFAULT 'active',
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at timestamptz,
  canceled_at timestamptz,
  trial_end timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create billing events
CREATE TABLE billing_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  subscription_id uuid REFERENCES subscriptions(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  stripe_event_id text UNIQUE,
  payload jsonb NOT NULL,
  processed boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Create email integrations
CREATE TABLE email_integrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  provider text NOT NULL,
  config jsonb NOT NULL DEFAULT '{}',
  status text DEFAULT 'active',
  last_sync_at timestamptz,
  last_error text,
  sync_count integer DEFAULT 0,
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create OAuth tokens (encrypted)
CREATE TABLE oauth_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_id uuid REFERENCES email_integrations(id) ON DELETE CASCADE NOT NULL,
  provider text NOT NULL,
  access_token text NOT NULL,
  refresh_token text,
  token_type text,
  expires_at timestamptz,
  scope text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create feedback items (core data table)
CREATE TABLE feedback_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  integration_id uuid REFERENCES email_integrations(id) ON DELETE SET NULL,
  
  -- Source info
  external_id text,
  source text NOT NULL DEFAULT 'email',
  platform text NOT NULL DEFAULT 'email',
  
  -- Email content
  subject text,
  body_text text,
  body_html text,
  snippet text,
  
  -- Sender info
  sender_email text NOT NULL,
  sender_name text,
  recipient_email text,
  cc_emails jsonb DEFAULT '[]',
  bcc_emails jsonb DEFAULT '[]',
  
  -- Classification results
  sentiment text,
  sentiment_score numeric(5,4),
  sentiment_confidence numeric(5,4),
  urgency text,
  urgency_score numeric(5,4),
  intent text,
  intent_confidence numeric(5,4),
  priority integer DEFAULT 50,
  
  -- Categories & tags
  category text,
  product text,
  
  -- Status
  status text DEFAULT 'open',
  is_satisfied boolean DEFAULT false,
  satisfied_at timestamptz,
  satisfied_by uuid REFERENCES users(id),
  
  -- Assignment
  assigned_to uuid REFERENCES users(id),
  assigned_at timestamptz,
  
  -- Metadata
  metadata jsonb DEFAULT '{}',
  raw_headers jsonb DEFAULT '{}',
  
  -- Search
  search_vector tsvector,
  
  -- Timestamps
  received_at timestamptz DEFAULT now(),
  processed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  UNIQUE(tenant_id, external_id, integration_id)
);

-- Create feedback attachments
CREATE TABLE feedback_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feedback_id uuid REFERENCES feedback_items(id) ON DELETE CASCADE NOT NULL,
  filename text NOT NULL,
  content_type text,
  size_bytes bigint,
  storage_path text NOT NULL,
  url text,
  created_at timestamptz DEFAULT now()
);

-- Create feedback comments
CREATE TABLE feedback_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feedback_id uuid REFERENCES feedback_items(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES users(id) ON DELETE SET NULL NOT NULL,
  comment text NOT NULL,
  is_internal boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create feedback tags
CREATE TABLE feedback_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  color text DEFAULT '#3b82f6',
  created_at timestamptz DEFAULT now(),
  UNIQUE(tenant_id, name)
);

-- Create alerts
CREATE TABLE alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  feedback_id uuid REFERENCES feedback_items(id) ON DELETE CASCADE,
  alert_type text NOT NULL,
  severity text DEFAULT 'medium',
  title text NOT NULL,
  message text,
  is_read boolean DEFAULT false,
  is_resolved boolean DEFAULT false,
  resolved_at timestamptz,
  resolved_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now()
);

-- Create notification rules
CREATE TABLE notification_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  conditions jsonb NOT NULL,
  actions jsonb NOT NULL,
  is_active boolean DEFAULT true,
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create auto reply templates
CREATE TABLE auto_reply_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  subject text NOT NULL,
  body_text text NOT NULL,
  body_html text,
  variables jsonb DEFAULT '[]',
  conditions jsonb DEFAULT '{}',
  is_active boolean DEFAULT true,
  use_count integer DEFAULT 0,
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create workflow automations
CREATE TABLE workflow_automations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  trigger_conditions jsonb NOT NULL,
  actions jsonb NOT NULL,
  is_active boolean DEFAULT true,
  execution_count integer DEFAULT 0,
  last_executed_at timestamptz,
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create export jobs
CREATE TABLE export_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  created_by uuid REFERENCES users(id) NOT NULL,
  format text NOT NULL,
  filters jsonb DEFAULT '{}',
  status text DEFAULT 'pending',
  file_url text,
  file_size bigint,
  row_count integer,
  error_message text,
  started_at timestamptz,
  completed_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Create report snapshots
CREATE TABLE report_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  report_type text NOT NULL,
  data jsonb NOT NULL,
  filters jsonb DEFAULT '{}',
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now()
);

-- Create audit logs
CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action text NOT NULL,
  resource_type text,
  resource_id uuid,
  changes jsonb,
  metadata jsonb DEFAULT '{}',
  ip_address inet,
  user_agent text,
  created_at timestamptz DEFAULT now()
);

-- Create system events
CREATE TABLE system_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type text NOT NULL,
  resource_type text,
  resource_id uuid,
  payload jsonb NOT NULL,
  status text DEFAULT 'pending',
  processed_at timestamptz,
  error text,
  created_at timestamptz DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX idx_tenants_slug ON tenants(slug);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_tenant_memberships_tenant ON tenant_memberships(tenant_id);
CREATE INDEX idx_tenant_memberships_user ON tenant_memberships(user_id);
CREATE INDEX idx_tenant_memberships_role ON tenant_memberships(role);
CREATE INDEX idx_subscriptions_tenant ON subscriptions(tenant_id);
CREATE INDEX idx_subscriptions_stripe ON subscriptions(stripe_subscription_id);
CREATE INDEX idx_email_integrations_tenant ON email_integrations(tenant_id);
CREATE INDEX idx_email_integrations_status ON email_integrations(status);

CREATE INDEX idx_feedback_tenant ON feedback_items(tenant_id);
CREATE INDEX idx_feedback_integration ON feedback_items(integration_id);
CREATE INDEX idx_feedback_sentiment ON feedback_items(sentiment);
CREATE INDEX idx_feedback_urgency ON feedback_items(urgency);
CREATE INDEX idx_feedback_status ON feedback_items(status);
CREATE INDEX idx_feedback_satisfied ON feedback_items(is_satisfied);
CREATE INDEX idx_feedback_priority ON feedback_items(priority DESC);
CREATE INDEX idx_feedback_received ON feedback_items(received_at DESC);
CREATE INDEX idx_feedback_sender ON feedback_items(sender_email);
CREATE INDEX idx_feedback_platform ON feedback_items(platform);
CREATE INDEX idx_feedback_search ON feedback_items USING gin(search_vector);

CREATE INDEX idx_alerts_tenant ON alerts(tenant_id);
CREATE INDEX idx_alerts_feedback ON alerts(feedback_id);
CREATE INDEX idx_alerts_unread ON alerts(is_read) WHERE is_read = false;
CREATE INDEX idx_export_jobs_tenant ON export_jobs(tenant_id);
CREATE INDEX idx_export_jobs_status ON export_jobs(status);
CREATE INDEX idx_audit_logs_tenant ON audit_logs(tenant_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);

-- Create full-text search trigger
CREATE OR REPLACE FUNCTION feedback_search_vector_update() RETURNS trigger AS $$
BEGIN
  NEW.search_vector := 
    setweight(to_tsvector('english', COALESCE(NEW.subject, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.body_text, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(NEW.sender_email, '')), 'C');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER feedback_search_vector_trigger
  BEFORE INSERT OR UPDATE ON feedback_items
  FOR EACH ROW EXECUTE FUNCTION feedback_search_vector_update();

-- Enable Row Level Security
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE oauth_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE auto_reply_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_automations ENABLE ROW LEVEL SECURITY;
ALTER TABLE export_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_events ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Subscription Plans (public read)
CREATE POLICY "Anyone can view active plans"
  ON subscription_plans FOR SELECT
  USING (is_active = true);

-- RLS Policies: Users
CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  TO authenticated
  USING (id = auth.uid());

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  TO authenticated
  USING (id = auth.uid());

-- RLS Policies: Tenants
CREATE POLICY "Members can view their tenants"
  ON tenants FOR SELECT
  TO authenticated
  USING (
    id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

CREATE POLICY "Admins can update their tenant"
  ON tenants FOR UPDATE
  TO authenticated
  USING (
    id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND role = 'admin' AND is_active = true
    )
  );

-- RLS Policies: Tenant Memberships
CREATE POLICY "Members can view tenant memberships"
  ON tenant_memberships FOR SELECT
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

CREATE POLICY "Admins can manage memberships"
  ON tenant_memberships FOR ALL
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND role = 'admin' AND is_active = true
    )
  );

-- RLS Policies: Email Integrations
CREATE POLICY "Members can view integrations"
  ON email_integrations FOR SELECT
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

CREATE POLICY "Admins can manage integrations"
  ON email_integrations FOR ALL
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND role = 'admin' AND is_active = true
    )
  );

-- RLS Policies: Feedback Items
CREATE POLICY "Members can view tenant feedback"
  ON feedback_items FOR SELECT
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

CREATE POLICY "Members can update tenant feedback"
  ON feedback_items FOR UPDATE
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

CREATE POLICY "System can insert feedback"
  ON feedback_items FOR INSERT
  TO authenticated
  WITH CHECK (
    tenant_id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

-- RLS Policies: Alerts
CREATE POLICY "Members can view tenant alerts"
  ON alerts FOR SELECT
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

CREATE POLICY "Members can update alerts"
  ON alerts FOR UPDATE
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

-- RLS Policies: Export Jobs
CREATE POLICY "Members can view tenant exports"
  ON export_jobs FOR SELECT
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

CREATE POLICY "Members can create exports"
  ON export_jobs FOR INSERT
  TO authenticated
  WITH CHECK (
    tenant_id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

-- RLS Policies: Audit Logs
CREATE POLICY "Members can view tenant audit logs"
  ON audit_logs FOR SELECT
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_memberships 
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

-- Insert default subscription plans
INSERT INTO subscription_plans (name, slug, display_name, description, price_monthly, price_yearly, features, limits)
VALUES 
  (
    'Free',
    'free',
    'Free Plan',
    'Perfect for trying out AwakenU',
    0.00,
    0.00,
    '{"integrations": 1, "export": false, "realtime": false, "retention_days": 30, "alerts": false}'::jsonb,
    '{"max_integrations": 1, "max_feedback_per_month": 100, "max_users": 2}'::jsonb
  ),
  (
    'Pro',
    'pro',
    'Pro Plan',
    'For growing teams and businesses',
    29.99,
    299.00,
    '{"integrations": 5, "export": true, "realtime": true, "retention_days": 365, "auto_reply": true, "alerts": true, "custom_reports": true}'::jsonb,
    '{"max_integrations": 5, "max_feedback_per_month": 10000, "max_users": 10}'::jsonb
  ),
  (
    'Enterprise',
    'enterprise',
    'Enterprise Plan',
    'For large organizations with advanced needs',
    99.99,
    999.00,
    '{"integrations": -1, "export": true, "realtime": true, "retention_days": -1, "auto_reply": true, "alerts": true, "custom_reports": true, "sso": true, "custom_models": true, "priority_support": true, "sla": true}'::jsonb,
    '{"max_integrations": -1, "max_feedback_per_month": -1, "max_users": -1}'::jsonb
  )
ON CONFLICT (slug) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  description = EXCLUDED.description,
  price_monthly = EXCLUDED.price_monthly,
  price_yearly = EXCLUDED.price_yearly,
  features = EXCLUDED.features,
  limits = EXCLUDED.limits;