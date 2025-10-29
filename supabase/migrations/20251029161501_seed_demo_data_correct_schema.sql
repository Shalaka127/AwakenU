/*
  # Seed Demo Data for AwakenU Platform

  1. Demo Tenants
    - Client organization for client@example.com
    - Admin organization for admin@sentily.com

  2. Sample Feedback Items
    - Mix of positive, negative, and neutral sentiment
    - Various urgency levels (high, medium, low)
    - Recent timestamps for realistic dashboard

  3. Helper Function
    - create_demo_user_membership for linking auth users to tenants

  Note: Demo users must be created through Supabase Auth API
*/

-- Create demo tenants
INSERT INTO tenants (id, name, slug, domain, is_active, settings)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'Demo Client Organization', 'demo-client', 'example.com', true, '{"notifications": true, "theme": "dark"}'::jsonb),
  ('00000000-0000-0000-0000-000000000002', 'Sentily Admin Organization', 'sentily-admin', 'sentily.com', true, '{"notifications": true, "theme": "dark"}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- Create helper function for linking users to tenants
CREATE OR REPLACE FUNCTION create_demo_user_membership(
  p_user_id uuid,
  p_tenant_id uuid,
  p_role text DEFAULT 'member'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO tenant_memberships (user_id, tenant_id, role, is_active)
  VALUES (p_user_id, p_tenant_id, p_role, true)
  ON CONFLICT (user_id, tenant_id) DO UPDATE
  SET role = p_role, is_active = true, updated_at = NOW();
END;
$$;

-- Add sample feedback items
INSERT INTO feedback_items (
  tenant_id,
  source,
  platform,
  sender_email,
  sender_name,
  subject,
  body_text,
  snippet,
  sentiment,
  sentiment_score,
  sentiment_confidence,
  urgency,
  urgency_score,
  status,
  is_satisfied,
  received_at
)
VALUES
  -- Positive feedback
  (
    '00000000-0000-0000-0000-000000000001',
    'email',
    'gmail',
    'happy.customer@test.com',
    'Alice Johnson',
    'Excellent service!',
    'I am extremely satisfied with your product. The customer support team was very helpful and resolved my issue quickly. Highly recommend to anyone looking for quality service!',
    'I am extremely satisfied with your product...',
    'positive',
    0.85,
    0.96,
    'low',
    0.15,
    'resolved',
    true,
    NOW() - INTERVAL '5 days'
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'email',
    'gmail',
    'satisfied.user@test.com',
    'Bob Martinez',
    'Great features and updates',
    'The new features you added are amazing! Everything works smoothly and the interface is very intuitive. Keep up the good work!',
    'The new features you added are amazing!...',
    'positive',
    0.80,
    0.92,
    'low',
    0.20,
    'resolved',
    true,
    NOW() - INTERVAL '4 days'
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'email',
    'outlook',
    'happy.client@test.com',
    'Henry Brown',
    'Love the recent updates!',
    'Thank you for listening to user feedback. The recent updates have made everything so much better! Really appreciate your dedication.',
    'Thank you for listening to user feedback...',
    'positive',
    0.78,
    0.90,
    'low',
    0.18,
    'resolved',
    true,
    NOW() - INTERVAL '8 days'
  ),
  
  -- Negative feedback (high urgency)
  (
    '00000000-0000-0000-0000-000000000001',
    'email',
    'gmail',
    'angry.customer@test.com',
    'Carol Williams',
    'URGENT: Cannot access my account!',
    'This is completely unacceptable! I have been trying to login for 3 hours and nothing works. I need immediate assistance or I will cancel my subscription and leave a terrible review!',
    'This is completely unacceptable! I have been trying...',
    'negative',
    -0.75,
    0.94,
    'high',
    0.92,
    'open',
    false,
    NOW() - INTERVAL '2 hours'
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'email',
    'gmail',
    'frustrated.user@test.com',
    'David Chen',
    'URGENT: Double billing issue',
    'I was charged twice this month! This is very frustrating and unprofessional. I need a refund immediately. Please fix your billing system before you lose more customers!',
    'I was charged twice this month! This is very...',
    'negative',
    -0.70,
    0.88,
    'high',
    0.88,
    'open',
    false,
    NOW() - INTERVAL '1 day'
  ),
  
  -- Negative feedback (medium urgency)
  (
    '00000000-0000-0000-0000-000000000001',
    'email',
    'outlook',
    'unhappy.user@test.com',
    'Grace Lee',
    'Performance problems continue',
    'The application has been very slow lately. It takes forever to load pages and I keep getting timeout errors. This is affecting my productivity.',
    'The application has been very slow lately...',
    'negative',
    -0.55,
    0.82,
    'medium',
    0.65,
    'open',
    false,
    NOW() - INTERVAL '12 hours'
  ),
  
  -- Neutral feedback
  (
    '00000000-0000-0000-0000-000000000001',
    'email',
    'gmail',
    'neutral.user@test.com',
    'Emma Davis',
    'Question about reporting features',
    'Can you tell me more about the reporting capabilities? I would like to understand what data is available and how I can export it.',
    'Can you tell me more about the reporting...',
    'neutral',
    0.05,
    0.65,
    'medium',
    0.45,
    'open',
    false,
    NOW() - INTERVAL '3 days'
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'email',
    'outlook',
    'interested.user@test.com',
    'Frank Wilson',
    'Pricing and upgrade inquiry',
    'I am considering upgrading to the enterprise plan. Could you provide more details about the pricing structure and what additional features are included?',
    'I am considering upgrading to the enterprise plan...',
    'neutral',
    0.10,
    0.70,
    'medium',
    0.50,
    'open',
    false,
    NOW() - INTERVAL '6 hours'
  )
ON CONFLICT DO NOTHING;
