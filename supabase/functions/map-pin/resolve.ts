// Turns a pasted map link (usually a Google Maps share link such as
// https://maps.app.goo.gl/abc) into a position, so the app can open the
// phone's maps app directly instead of a browser page. Kept free of Deno
// APIs so it can be tested on its own.

export type Pin = { lat?: number; lng?: number; name?: string; query?: string }

const ALLOWED = /^(maps\.app\.goo\.gl|goo\.gl|(www\.)?google\.[a-z.]+|maps\.google\.[a-z.]+|maps\.apple\.com|maps\.apple|share\.google)$/i

export function allowedHost(url: URL): boolean {
  return (url.protocol === 'https:' || url.protocol === 'http:') && ALLOWED.test(url.hostname)
}

function cleanName(n?: string): string | undefined {
  const t = (n ?? '').trim()
  return !t || LATLNG.test(t) ? undefined : t
}

function coords(lat: string, lng: string): Pin | null {
  const a = Number(lat), b = Number(lng)
  if (!isFinite(a) || !isFinite(b) || Math.abs(a) > 90 || Math.abs(b) > 180) return null
  if (a === 0 && b === 0) return null
  return { lat: a, lng: b }
}

function safeDecode(s: string): string {
  try { return decodeURIComponent(s) } catch { return s }
}

const LATLNG = /^\s*(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)\s*$/

export function parseMapUrl(raw: string): Pin | null {
  let url: URL
  try { url = new URL(raw) } catch { return null }
  let href = url.href
  try { href = decodeURIComponent(url.href.replace(/\+/g, ' ')) } catch { /* keep raw */ }
  const placeMatch = url.pathname.match(/\/maps\/place\/([^/]+)/)
  const name = cleanName(placeMatch
    ? safeDecode(placeMatch[1].replace(/\+/g, ' '))
    : (url.searchParams.get('name') ?? undefined))

  // Exact place position: ...!3d53.43!4d-6.15
  const pd = href.match(/!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)/)
  if (pd) { const c = coords(pd[1], pd[2]); if (c) return { ...c, name } }

  // q / query / ll / daddr as "lat,lng"
  for (const key of ['q', 'query', 'll', 'coordinate', 'daddr', 'destination']) {
    const v = url.searchParams.get(key)
    if (!v) continue
    const m = v.match(LATLNG)
    if (m) { const c = coords(m[1], m[2]); if (c) return { ...c, name } }
  }

  // Search path: /maps/search/53.36,+-6.17
  const sp = url.pathname.match(/\/maps\/search\/([^/]+)/)
  if (sp) {
    const m = safeDecode(sp[1].replace(/\+/g, ' ')).match(LATLNG)
    if (m) { const c = coords(m[1], m[2]); if (c) return { ...c, name } }
  }

  // Map centre: /@53.43,-6.15,715m
  const at = href.match(/@(-?\d+\.\d+),(-?\d+\.\d+)/)
  if (at) { const c = coords(at[1], at[2]); if (c) return { ...c, name } }

  // A text search, e.g. ?q=St. Vincent's GAA Club, Malahide Rd
  const q = url.searchParams.get('q') || url.searchParams.get('query')
  if (q && q.trim()) return { query: q.trim(), name: name ?? q.split(',')[0].trim() }
  if (name) return { query: name, name }
  return null
}

// Follows up to 5 redirects by hand (only to allowed hosts) and parses
// the first URL that gives a position or search.
export async function resolvePin(raw: string, fetchFn: typeof fetch = fetch): Promise<Pin | null> {
  let current: URL
  try { current = new URL(raw.trim()) } catch { return null }
  for (let i = 0; i < 6; i++) {
    if (!allowedHost(current)) return null
    // Short-link hops carry no position of their own.
    const hop = /^(maps\.app\.goo\.gl|goo\.gl|maps\.apple|share\.google)$/i.test(current.hostname) ||
      current.pathname === '/share.google'
    const parsed = hop ? null : parseMapUrl(current.href)
    if (parsed && (parsed.lat !== undefined || i > 0)) return parsed
    if (i === 5) return parsed
    const res = await fetchFn(current.href, { redirect: 'manual' })
    const loc = res.headers.get('location')
    try { await res.body?.cancel() } catch { /* ignore */ }
    if (!loc) return parsed
    current = new URL(loc, current)
  }
  return null
}
