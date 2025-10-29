import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });

    const users = [
      {
        email: 'client@example.com',
        password: 'client123',
        tenant_id: '00000000-0000-0000-0000-000000000001',
        role: 'member'
      },
      {
        email: 'admin@sentily.com',
        password: 'admin123',
        tenant_id: '00000000-0000-0000-0000-000000000002',
        role: 'admin'
      }
    ];

    const results = [];

    for (const user of users) {
      const { data: existingUsers } = await supabase.auth.admin.listUsers();
      const exists = existingUsers?.users?.find(u => u.email === user.email);

      if (exists) {
        await supabase.rpc('create_demo_user_membership', {
          p_user_id: exists.id,
          p_tenant_id: user.tenant_id,
          p_role: user.role
        });
        results.push({ email: user.email, status: 'already_exists', id: exists.id });
      } else {
        const { data: newUser, error } = await supabase.auth.admin.createUser({
          email: user.email,
          password: user.password,
          email_confirm: true
        });

        if (error) {
          results.push({ email: user.email, status: 'error', error: error.message });
        } else {
          await supabase.rpc('create_demo_user_membership', {
            p_user_id: newUser.user.id,
            p_tenant_id: user.tenant_id,
            p_role: user.role
          });
          results.push({ email: user.email, status: 'created', id: newUser.user.id });
        }
      }
    }

    return new Response(
      JSON.stringify({ success: true, results }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});