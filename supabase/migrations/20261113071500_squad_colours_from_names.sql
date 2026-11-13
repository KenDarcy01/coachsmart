-- Squad colours (Ken, 2026-11-13): 33 older squads have no colour stored (null,
-- '' or the #ffffff default) although the name says it ("Blue Team"), so the
-- v3 stats bars fell back to green. Set the colour from the name, using the
-- colour picker's palette (webviews/cs-colour-picker.js). Only squads without
-- a real colour are touched; "No Team" is left alone. squad_image is unchanged.
-- Undo: set squad_colour back to NULL for these squad_ids.

UPDATE public.squads s
SET squad_colour = v.hex
FROM (VALUES
    ('blue',   '#2F6FD6'),
    ('red',    '#D63B3B'),
    ('green',  '#2FA84F'),
    ('yellow', '#F2C230'),
    ('orange', '#F07B22'),
    ('purple', '#8A4FD6'),
    ('black',  '#1A1A1A')
) AS v(word, hex)
WHERE (s.squad_colour IS NULL OR trim(s.squad_colour) = '' OR lower(s.squad_colour) = '#ffffff')
  AND lower(s.squad_name) ~ ('\m' || v.word || '\M');
