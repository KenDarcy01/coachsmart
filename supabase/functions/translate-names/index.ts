import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Anthropic from 'npm:@anthropic-ai/sdk'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    // Verify the caller is a valid authenticated Supabase user
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    const { names } = await req.json()
    if (!Array.isArray(names) || names.length === 0) {
      return new Response(JSON.stringify({}), {
        headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    const anthropic = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')! })

    const prompt = `You are an expert in GAA Irish language name translations. Translate each of the following English names to their Irish (Gaeilge) equivalents as used in official GAA documents and Foireann teamsheets. Always attempt a translation — use your best guess for names you are less certain about. Common Irish equivalents: John=Seán, James=Séamus, Patrick=Pádraig, Michael=Micheál, William=Liam, Thomas=Tomás, Brian=Brian, Kevin=Caoimhín, Conor=Conchubhar, Luke=Lúcás, Rory=Ruairí, Fred=Feardorcha, Shay=Sé, Dan=Dónall, Hugh=Aodh, Mark=Marcas, Ben=Beircheart, Darragh=Darragh, Alex=Alastair. For surnames use standard Irish mutation rules where applicable. Return ONLY a valid JSON object mapping each English name to its Irish translation. No explanation, no markdown, no extra text.

Names:
${JSON.stringify(names)}`

    const message = await anthropic.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 2048,
      messages: [{ role: 'user', content: prompt }],
    })

    const text = message.content.find((c) => c.type === 'text')?.text ?? '{}'
    const translations = JSON.parse(text.replace(/```json|```/g, '').trim())

    return new Response(JSON.stringify(translations), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('translate-names error:', err)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }
})
