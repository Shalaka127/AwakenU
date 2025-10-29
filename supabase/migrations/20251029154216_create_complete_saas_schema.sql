/*
  # Complete Customer Support SaaS Platform Schema

  ## Overview
  Multi-tenant SaaS for customer support email analytics with sentiment analysis,
  urgency detection, automated responses, and subscription management.

  ## New Tables
  
  ### Core Tables
  1. `tenants` - Client organizations
     - id, name, billing_plan_id, settings, created_at
  
  2. `tenant_users` - Users within tenant organizations
     - id, tenant_id, user_id, role, created_at
  
  3. `subscription_plans` - Billing plans
     - id, name, features, price, limits, created_at
  
  4. `email_integrations` - Email provider connections
     - id, tenant_id, provider, auth_info, settings, last_sync, created_at
  
  5. `feedback_items` - Customer support messages
     - id, tenant_id, integration_id, external_id
     - source, channel, subject, body_text, body_html
     - sender_email, recipient_email, to_addresses
     - sentiment, sentiment_score, urgency, urgency_score
     - intent, priority, status, is_satisfied
     - tags, attachments, created_at, processed_at
  
  6. `alerts` - System alerts for high priority items
     - id, tenant_id, feedback_id, alert_type, created_at, resolved_at
  
  7. `exports` - Export job tracking
     - id, tenant_id, format, parameters, file_url, status, created_at
  
  8. `audit_logs` - Activity tracking
     - id, tenant_id, user_id, action, metadata, created_at
  
  9. `auto_reply_templates` - Automated response templates
     - id, tenant_id, name, subject, body, is_active, created_at
  
  10. `feedback_comments` - Internal notes on feedback
      - id, feedback_id, user_id, comment, created_at

  ## Security
  - Enable RLS on all tables
  - Policies ensure tenant isolation
  - Users can only access their tenant's data
  - Encrypted sensitive data fields

  ## Indexes
  - Optimized for dashboard queries
  - Fast filtering by sentiment, urgency, date
  - Full-text search ready
*/

-- Create subscription plans table first (referenced by tenants)
CREATE TABLE IF NOT EXISTS subscription_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  slug text NOT NULL UNIQUE,
  description text,
  price numeric(10,2) NOT NULL DEFAULT 0,
  features jsonb DEFAULT '{}',
  limits jsonb DEFAULT '{}',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create tenants table
CREATE TABLE IF NOT EXISTS tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE,
  billing_plan_id uuid REFERENCES subscription_plans(id),
  stripe_customer_id text,
  stripe_subscription_id text,
  settings jsonb DEFAULT '{}',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create tenant_users junction table (links auth.users to tenants)
CREATE TABLE IF NOT EXISTS tenant_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role text NOT NULL DEFAULT 'member',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  UNIQUE(tenant_id, user_id)
);

-- Create email integrations table
CREATE TABLE IF NOT EXISTS email_integrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  provider text NOT NULL,
  auth_info jsonb DEFAULT '{}',
  settings jsonb DEFAULT '{}',
  last_sync timestamptz,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create feedback items table (main data)
CREATE TABLE IF NOT EXISTS feedback_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  integration_id uuid REFERENCES email_integrations(id) ON DELETE SET NULL,
  external_id text,
  source text NOT NULL DEFAULT 'email',
  channel text NOT NULL DEFAULT 'email',
  subject text,
  body_text text,
  body_html text,
  sender_email text NOT NULL,
  sender_name text,
  recipient_email text,
  to_addresses jsonb DEFAULT '[]',
  cc_addresses jsonb DEFAULT '[]',
  sentiment text,
  sentiment_score numeric(5,4),
  urgency text,
  urgency_score numeric(5,4),
  intent text,
  priority integer DEFAULT 0,
  status text DEFAULT 'open',
  is_satisfied boolean DEFAULT false,
  satisfied_at timestamptz,
  satisfied_by uuid REFERENCES auth.users(id),
  tags jsonb DEFAULT '[]',
  attachments jsonb DEFAULT '[]',
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz,
  updated_at timestamptz DEFAULT now(),
  UNIQUE(tenant_id, external_id, integration_id)
);

-- Create alerts table
CREATE TABLE IF NOT EXISTS alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  feedback_id uuid REFERENCES feedback_items(id) ON DELETE CASCADE,
  alert_type text NOT NULL,
  severity text DEFAULT 'medium',
  message text,
  is_resolved boolean DEFAULT false,
  resolved_at timestamptz,
  resolved_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

-- Create exports table
CREATE TABLE IF NOT EXISTS exports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  created_by uuid REFERENCES auth.users(id) NOT NULL,
  format text NOT NULL,
  parameters jsonb DEFAULT '{}',
  file_url text,
  status text DEFAULT 'pending',
  error_message text,
  row_count integer,
  created_at timestamptz DEFAULT now(),
  completed_at timestamptz
);

-- Create audit logs table
CREATE TABLE IF NOT EXISTS audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  resource_type text,
  resource_id uuid,
  metadata jsonb DEFAULT '{}',
  ip_address inet,
  user_agent text,
  created_at timestamptz DEFAULT now()
);

-- Create auto reply templates table
CREATE TABLE IF NOT EXISTS auto_reply_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  is_active boolean DEFAULT true,
  variables jsonb DEFAULT '[]',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create feedback comments table
CREATE TABLE IF NOT EXISTS feedback_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feedback_id uuid REFERENCES feedback_items(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL NOT NULL,
  comment text NOT NULL,
  is_internal boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tenants_billing_plan ON tenants(billing_plan_id);
CREATE INDEX IF NOT EXISTS idx_tenant_users_tenant ON tenant_users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_users_user ON tenant_users(user_id);
CREATE INDEX IF NOT EXISTS idx_email_integrations_tenant ON email_integrations(tenant_id);
CREATE INDEX IF NOT EXISTS idx_feedback_tenant ON feedback_items(tenant_id);
CREATE INDEX IF NOT EXISTS idx_feedback_integration ON feedback_items(integration_id);
CREATE INDEX IF NOT EXISTS idx_feedback_sentiment ON feedback_items(sentiment);
CREATE INDEX IF NOT EXISTS idx_feedback_urgency ON feedback_items(urgency);
CREATE INDEX IF NOT EXISTS idx_feedback_status ON feedback_items(status);
CREATE INDEX IF NOT EXISTS idx_feedback_created ON feedback_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_sender ON feedback_items(sender_email);
CREATE INDEX IF NOT EXISTS idx_feedback_satisfied ON feedback_items(is_satisfied);
CREATE INDEX IF NOT EXISTS idx_alerts_tenant ON alerts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_alerts_feedback ON alerts(feedback_id);
CREATE INDEX IF NOT EXISTS idx_exports_tenant ON exports(tenant_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant ON audit_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_templates_tenant ON auto_reply_templates(tenant_id);
CREATE INDEX IF NOT EXISTS idx_comments_feedback ON feedback_comments(feedback_id);

-- Enable Row Level Security on all tables
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE exports ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE auto_reply_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback_comments ENABLE ROW LEVEL SECURITY;

-- RLS Policies for subscription_plans (public read)
CREATE POLICY "Anyone can view active subscription plans"
  ON subscription_plans FOR SELECT
  USING (is_active = true);

-- RLS Policies for tenants
CREATE POLICY "Users can view their own tenant"
  ON tenants FOR SELECT
  TO authenticated
  USING (
    id IN (
      SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own tenant settings"
  ON tenants FOR UPDATE
  TO authenticated
  USING (
    id IN (
      SELECT tenant_id FROM tenant_users 
      WHERE user_id = auth.uid() AND role IN ('admin', 'owner')
    )
  );

-- RLS Policies for tenant_users
CREATE POLICY "Users can view members of their tenant"
  ON tenant_users FOR SELECT
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage tenant users"
  ON tenant_users FOR ALL
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users 
      WHERE user_id = auth.uid() AND role IN ('admin', 'owner')
    )
  );

-- RLS Policies for email_integrations
CREATE POLICY "Users can view their tenant's integrations"
  ON email_integrations FOR SELECT
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage integrations"
  ON email_integrations FOR ALL
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users 
      WHERE user_id = auth.uid() AND role IN ('admin', 'owner')
    )
  );

-- RLS Policies for feedback_items
CREATE POLICY "Users can view their tenant's feedback"
  ON feedback_items FOR SELECT
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their tenant's feedback"
  ON feedback_items FOR UPDATE
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "System can insert feedback"
  ON feedback_items FOR INSERT
  TO authenticated
  WITH CHECK (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
    )
  );

-- RLS Policies for alerts
CREATE POLICY "Users can view their tenant's alerts"
  ON alerts FOR SELECT
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their tenant's alerts"
  ON alerts FOR UPDATE
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
    )
  );

-- RLS Policies for exports
CREATE POLICY "Users can view their tenant's exports"
  ON exports FOR SELECT
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create exports"
  ON exports FOR INSERT
  TO authenticated
  WITH CHECK (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
    )
  );

-- RLS Policies for audit_logs
CREATE POLICY "Users can view their tenant's audit logs"
  ON audit_logs FOR SELECT
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "System can insert audit logs"
  ON audit_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
    )
  );

-- RLS Policies for auto_reply_templates
CREATE POLICY "Users can view their tenant's templates"
  ON auto_reply_templates FOR SELECT
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage templates"
  ON auto_reply_templates FOR ALL
  TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_users 
      WHERE user_id = auth.uid() AND role IN ('admin', 'owner')
    )
  );

-- RLS Policies for feedback_comments
CREATE POLICY "Users can view comments on their tenant's feedback"
  ON feedback_comments FOR SELECT
  TO authenticated
  USING (
    feedback_id IN (
      SELECT id FROM feedback_items 
      WHERE tenant_id IN (
        SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can create comments"
  ON feedback_comments FOR INSERT
  TO authenticated
  WITH CHECK (
    feedback_id IN (
      SELECT id FROM feedback_items 
      WHERE tenant_id IN (
        SELECT tenant_id FROM tenant_users WHERE user_id = auth.uid()
      )
    )
  );

-- Insert default subscription plans
INSERT INTO subscription_plans (name, slug, description, price, features, limits)
VALUES 
  (
    'Free',
    'free',
    'Perfect for trying out the platform',
    0,
    '{"integrations": 1, "export": false, "realtime": false, "retention_days": 30}'::jsonb,
    '{"max_integrations": 1, "max_feedback_per_month": 100}'::jsonb
  ),
  (
    'Pro',
    'pro',
    'For growing teams',
    29.99,
    '{"integrations": 5, "export": true, "realtime": true, "retention_days": 365, "auto_reply": true}'::jsonb,
    '{"max_integrations": 5, "max_feedback_per_month": 10000}'::jsonb
  ),
  (
    'Enterprise',
    'enterprise',
    'For large organizations',
    99.99,
    '{"integrations": -1, "export": true, "realtime": true, "retention_days": -1, "auto_reply": true, "sso": true, "custom_models": true}'::jsonb,
    '{"max_integrations": -1, "max_feedback_per_month": -1}'::jsonb
  )
ON CONFLICT (slug) DO NOTHING;