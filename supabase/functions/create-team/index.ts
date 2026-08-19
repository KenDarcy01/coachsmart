import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function generateTeamCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = 'TM';
  for (let i = 0; i < 5; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabaseUrl    = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const anonKey        = Deno.env.get('SUPABASE_ANON_KEY')!;

    // Validate the user's JWT
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const body = await req.json();
    const { club_id, team_name, team_juvenile, team_female, car_pooling_allowed, first_name, last_name } = body;

    if (!club_id || !team_name || !first_name || !last_name) {
      return new Response(JSON.stringify({ error: 'Missing required fields: club_id, team_name, first_name, last_name' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Generate a unique team code
    let team_unique_code = '';
    for (let attempt = 0; attempt < 10; attempt++) {
      const candidate = generateTeamCode();
      const { data: existing } = await supabase
        .from('teams')
        .select('team_id')
        .eq('team_unique_code', candidate)
        .maybeSingle();
      if (!existing) { team_unique_code = candidate; break; }
    }
    if (!team_unique_code) throw new Error('Failed to generate a unique team code — please try again.');

    // 1. Create team
    const { data: team, error: teamErr } = await supabase
      .from('teams')
      .insert({
        team_name,
        club_id,
        team_juvenile: team_juvenile ?? false,
        team_female:   team_female   ?? false,
        car_pooling_allowed: car_pooling_allowed ?? true,
        allow_lineup: false,
        team_unique_code,
      })
      .select('team_id')
      .single();
    if (teamErr) throw teamErr;
    const team_id = team.team_id;

    // 2. Default squad
    const { error: squadErr } = await supabase
      .from('squads')
      .insert({ team_id, squad_name: 'No Team', grade: '', squad_colour: '#ffffff', squad_list_seq: 100 });
    if (squadErr) throw squadErr;

    // 3. Team roles — Admin, Coach, FLO, Player (no SuperUser)
    const { error: rolesErr } = await supabase
      .from('team_roles_link')
      .insert([
        { team_id, role_id: 7 },  // Admin
        { team_id, role_id: 8 },  // Coach
        { team_id, role_id: 9 },  // FLO
        { team_id, role_id: 6 },  // Player
      ]);
    if (rolesErr) throw rolesErr;

    // 4. Create member record for the creator
    const { data: member, error: memberErr } = await supabase
      .from('members')
      .insert({ first_name, last_name, user_id: user.id })
      .select('member_id')
      .single();
    if (memberErr) throw memberErr;
    const member_id = member.member_id;

    // 5. Link member to user account
    const { error: umlErr } = await supabase
      .from('user_member_link')
      .insert({ user_id: user.id, member_id });
    if (umlErr) throw umlErr;

    // 6. Link member to team
    const { data: mtl, error: mtlErr } = await supabase
      .from('member_team_link')
      .insert({ member_id, team_id, status: 'active' })
      .select('member_team_id')
      .single();
    if (mtlErr) throw mtlErr;

    // 7. Assign Admin role to creator
    const { error: mtrErr } = await supabase
      .from('member_team_role_link')
      .insert({ member_team_id: mtl.member_team_id, role_id: 7 });
    if (mtrErr) throw mtrErr;

    return new Response(JSON.stringify({ team_id, team_unique_code }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message ?? 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
