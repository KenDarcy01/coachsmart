# Store screenshots

Builds the App Store and Play Store marketing screenshots (headline, subtitle and phone frame on black).
This replaces the App Screens subscription.

## Make a new set

1. Put raw screenshots from the app (straight off the simulator or phone, not edited) in `raw/`.
   iPhone raw screenshots work for both stores.
2. Edit `screens.json`: the headline (wrap the green word in `*stars*`, `\n` for a line break), the
   subtitle and which file in `raw/` each screen uses. Phone position, size and tilt are under `phone`.
3. Render:

   ```bash
   node store-screens/render.mjs
   ```

   Or render only some screens: `node store-screens/render.mjs 02-attendance`

Output goes to `out/`:

| Folder | Size | Upload to |
|---|---|---|
| `out/iphone-6.9/` | 1320×2868 | App Store Connect, iPhone 6.9" |
| `out/iphone-6.5/` | 1284×2778 | App Store Connect, iPhone 6.5" |
| `out/android-phone/` | 1080×1920 | Play Console, phone screenshots |

To add a size, add an entry to `formats` in `screens.json`.

Needs Node and Playwright (`npm i -g playwright && npx playwright install chromium` outside the Claude sandbox).
Fonts (Roboto) are in `fonts/`, so it renders the same on any machine.

The current files in `raw/` were cut out of the old App Screens exports as stand-ins. Replace them
with real screenshots for sharper results.
