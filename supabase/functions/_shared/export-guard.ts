// Exports email a team or squad list to the address the app sends. Before
// 2026-11-13 any caller could send any team's list to any address. Now the
// address must belong to staff (FLO, coach, admin or super user, role level
// 20+) on that team. v2 and v3 both send the signed-in user's own email, so
// staff exports keep working (roles review, thread "Review what each role
// can see and do", Ken approved 2026-11-13).

// deno-lint-ignore no-explicit-any
type Sql = any;

export async function assertTeamStaffEmail(sql: Sql, teamId: number | string, email: string) {
  const rows = await sql`
    SELECT 1
      FROM public.users u
      JOIN public.user_member_link uml   ON uml.user_id = u.user_id
                                        AND COALESCE(uml.status, 'active') = 'active'
      JOIN public.member_team_link mtl   ON mtl.member_id = uml.member_id
                                        AND mtl.status = 'active'
      JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
      JOIN public.roles r                ON r.role_id = mtrl.role_id
     WHERE lower(u.email_address) = lower(${email})
       AND mtl.team_id = ${teamId}
       AND r.role_level >= 20
     LIMIT 1`;
  if (!rows.length) throw new Error("Only the team's coaches and admins can export this.");
}

export async function assertEventStaffEmail(sql: Sql, eventId: number | string, email: string) {
  const ev = await sql`SELECT team_id FROM public.events WHERE event_id = ${eventId}`;
  if (!ev.length) throw new Error("Event not found.");
  await assertTeamStaffEmail(sql, ev[0].team_id, email);
}
