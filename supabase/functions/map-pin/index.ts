// map-pin: resolves an event's pasted map link to a position.
// POST { url } -> { lat, lng, name } or { query, name }, or 404 when it
// can't be read. Used by the PWA so the Location row can open the Maps
// app directly (a browser page for the link stays behind, blank, on iPhone).
// Called with the anon key or a user token (verify_jwt stays on).
import { allowedHost, resolvePin } from './resolve.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=86400' },
  })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  try {
    let raw = ''
    if (req.method === 'GET') raw = new URL(req.url).searchParams.get('url') ?? ''
    else raw = String((await req.json().catch(() => ({})))?.url ?? '')
    const link = raw.match(/https?:\/\/\S+/i)?.[0]
    if (!link) return json({ error: 'no link' }, 400)
    let url: URL
    try { url = new URL(link) } catch { return json({ error: 'bad link' }, 400) }
    if (!allowedHost(url)) return json({ error: 'not a map link' }, 400)
    const pin = await resolvePin(url.href)
    if (!pin) return json({ error: 'not found' }, 404)
    return json(pin)
  } catch (e) {
    return json({ error: String(e) }, 500)
  }
})
