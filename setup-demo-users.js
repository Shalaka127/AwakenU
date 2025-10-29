import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.VITE_SUPABASE_URL || 'https://zcezahdnvfaemarwdhdw.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.error('❌ SUPABASE_SERVICE_ROLE_KEY environment variable is required');
  console.log('Please set it in your environment or .env file');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function setupDemoUsers() {
  console.log('🚀 Setting up demo users...\n');

  // Create client user
  console.log('Creating client user: client@example.com');
  const { data: clientUser, error: clientError } = await supabase.auth.admin.createUser({
    email: 'client@example.com',
    password: 'client123',
    email_confirm: true
  });

  if (clientError) {
    if (clientError.message.includes('already registered')) {
      console.log('✓ Client user already exists');
      const { data: { users } } = await supabase.auth.admin.listUsers();
      const existing = users.find(u => u.email === 'client@example.com');
      if (existing) {
        await linkUserToTenant(existing.id, '00000000-0000-0000-0000-000000000001', 'member');
      }
    } else {
      console.error('❌ Error creating client user:', clientError.message);
    }
  } else {
    console.log('✓ Client user created:', clientUser.user.id);
    await linkUserToTenant(clientUser.user.id, '00000000-0000-0000-0000-000000000001', 'member');
  }

  // Create admin user
  console.log('\nCreating admin user: admin@sentily.com');
  const { data: adminUser, error: adminError } = await supabase.auth.admin.createUser({
    email: 'admin@sentily.com',
    password: 'admin123',
    email_confirm: true
  });

  if (adminError) {
    if (adminError.message.includes('already registered')) {
      console.log('✓ Admin user already exists');
      const { data: { users } } = await supabase.auth.admin.listUsers();
      const existing = users.find(u => u.email === 'admin@sentily.com');
      if (existing) {
        await linkUserToTenant(existing.id, '00000000-0000-0000-0000-000000000002', 'admin');
      }
    } else {
      console.error('❌ Error creating admin user:', adminError.message);
    }
  } else {
    console.log('✓ Admin user created:', adminUser.user.id);
    await linkUserToTenant(adminUser.user.id, '00000000-0000-0000-0000-000000000002', 'admin');
  }

  console.log('\n✅ Demo users setup complete!');
  console.log('\nYou can now login with:');
  console.log('  Client: client@example.com / client123');
  console.log('  Admin:  admin@sentily.com / admin123');
}

async function linkUserToTenant(userId, tenantId, role) {
  const { error } = await supabase.rpc('create_demo_user_membership', {
    p_user_id: userId,
    p_tenant_id: tenantId,
    p_role: role
  });

  if (error) {
    console.error(`❌ Error linking user to tenant:`, error.message);
  } else {
    console.log(`✓ User linked to tenant as ${role}`);
  }
}

setupDemoUsers().catch(console.error);
