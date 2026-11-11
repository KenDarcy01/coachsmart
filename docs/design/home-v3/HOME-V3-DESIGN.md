# Home screen v3 — design handoff ("Timeline")

Status: **approved direction, ready to implement** (Ken, 2026-11-11).
Design canvas: https://claude.ai/artifact/UeBjjLdRgemoimwBK4axTj (round 3 row, artboards D1–D5).
Reference renders: `reference/D1-Parent.html` … `D5-QuietWeek.html` — open in a browser at 390 px wide. They are plain inline-styled HTML; no build step. The crests in them are **placeholder shields**, not club artwork: the real `clubs.crest` image goes in that slot.

This document is the design. It says *what* Home should look like and how it behaves, mapped to the data the app already has. It does not say how to build it in FlutterFlow; the project decides that.

---

## 1. Why the current build is being replaced

Every card in the current v3 Home carries seven things: a crest, the team name in green caps, a title, a venue line, a full-width coloured progress bar, a sentence of three coloured counts, and a coloured reply pill. Above the list sit a large crest strip and a row of team chips. Nothing stands out and the eye has nowhere to rest.

The original v2 Home was calmer (one compact card: team, title, three small coloured dots, one quiet line for reply and meet time) but repeated the full date heading above every card and did not allow replying from Home.

The new design keeps v2's calm and fixes both of its faults.

## 2. The idea in one paragraph

Home is a **vertical timeline**. A thin green rail runs down the left. Each day appears **once**, as a large numeral and weekday sitting on the rail, and only when the day changes. Each event is a dot on the rail with its content to the right: time, meet time, title, then one line of club · team · venue, then the attendance ring and the user's reply. The club **crest** is the only colour on the screen apart from brand green; it is on every event and in every team chip, because a child playing GAA, rugby and soccer has three teams all called "U13" and the club is what tells them apart. Parents can reply from Home with a ✓ / ✕ pair. Nothing else is coloured.

## 3. What was removed from the current build, and why

| Removed | Why |
|---|---|
| Large crest strip above the list | Crest now lives on each event and in each chip; the strip was decoration. |
| Club filter | Replaced by one team filter whose chips carry the club crest. |
| Team name in green caps on every card | Green is reserved for *the rail, the next event and your own "Attending"*. Team name becomes a muted meta line. |
| Full-width coloured progress bar | Replaced by a 26 px ring. Same information, a quarter of the space. |
| "62 attending · 2 declined · 9 no reply" sentence with three coloured numbers | Replaced by "14 attending" (white) and "3 no reply · 2 declined" (muted). Red is gone. |
| Coloured reply pill | Replaced by a ✓ / ✕ pair (unreplied) or a quiet one-word status (replied). |
| Date heading above every card | Day marker appears once per day, on the rail. |
| Bottom bar on parent Home | Brief: only coaches get the bottom bar. |

## 4. Tokens

Colours (unchanged brand):

| Token | Value | Use |
|---|---|---|
| `bg` | `#14181B` | Screen background |
| `surface` | `#1E222B` | Chip bar, unselected chips |
| `surface2` | `#252A34` | Selected chip fill |
| `text` | `#F1F4F8` | Primary text |
| `muted` | `#A1A1A2` | Secondary text, declined, cancelled |
| `green` | `#87C232` | Rail, next-event dot and numeral, Attending, ring fill, selected-chip ring, Paid tag |
| `line` | `rgba(241,244,248,0.08)` | Hairlines |
| `green-dim` | `rgba(135,194,50,0.16)` | Not used on Home v3 (kept for consistency elsewhere) |

Type: **Inter** for text, **Inter Tight** for numerals and headings (time, day numeral). Both are Google Fonts; `google_fonts` is already in `pubspec.yaml`. Tabular numerals everywhere a count or time appears.

Contrast: every text colour above passes 4.5:1 on `bg` and `surface`. Do not introduce lighter greys.

## 5. Screen anatomy (390 × 844, iPhone)

```
┌─ Header, 56 px ─────────────────────────────────┐
│ [≡ 44×44]        Home (17/600)      [🔔 44×44 ●]│   bell dot = unread > 0
├─ Team chips, 44 px tall, 16 px side padding ────┤
│ (All) ([crest] Boys 2013) ([crest] U13) …       │   horizontal scroll, always shown
├─ Timeline (scrolls) ────────────────────────────┤
│ 16 │ 44 day │ 24 dot │ content … │ 16           │   rail at x = 72 (16 + 44 + 12)
│    │  11    │   ●    │ 17:50 Meet 17:30 in 2h   │
│    │  WED   │   │    │ Football Training        │
│    │        │   │    │ [crest] Clontarf GAA · Boys 2013 · Club Astro
│    │        │   │    │ (ring) 14 attending      ✓ Attending
│    │        │   │    │        3 no reply · 2 declined
│    │        │   ○    │ 19:00 Meet 18:45 …       │
├─ Coach only: bottom bar 84 px ──────────────────┤
│ Home · Resources · Favourites · Add event       │
└─────────────────────────────────────────────────┘
```

Grid per event row: `44px | 24px | 1fr`, column gap 4 px. First row of a new day has 22 px top padding, subsequent rows 8 px; 10 px bottom.

### 5.1 Header
Unchanged from current build: menu (left, green), "Home" (17 px / 600, centred), bell (right, green). Unread badge is an 8 px green dot at the bell's top-right, not a number.

### 5.2 Team chip bar
- One row, horizontally scrollable, 8 px gap, 16 px side padding, 4 px top.
- **Always shown**, even when the user has a single team.
- First chip is `All`, text only.
- Every other chip: the team's **club crest at 28 px** then the team name. Height 44, radius 22, padding 0 14 0 8 (text-only chip: 0 14).
- Unselected: `surface` fill, `muted` text. Selected: `surface2` fill, `text` text, 1 px inset ring in green at 60 % alpha.
- Order: the order `user_teams` arrives in (it is already sorted by name with "All Teams" first).
- Selecting a chip filters the timeline to that `team_id`. The layout does not change; only density.

### 5.3 Rail
A 2 px vertical line at x = 72 running the full height of the scroll area. Solid green at the top fading to green at 18 % alpha by 120 px down; it stays at 18 % for the rest. (In Flutter: a `LinearGradient` with stops `[0, 120/height, 1]`.)

### 5.4 Day marker
Shown only on the **first event of each calendar day**, in the 44 px column: the day-of-month in Inter Tight 26 px / 800, letter-spacing −0.02 em, then the weekday in 10 px / 700, uppercase, letter-spacing 0.12 em, `muted`, 4 px below. The numeral is **green** when that day contains the next upcoming event, otherwise `text`.

No "Today" word. The numeral plus the pulsing dot carries it.

### 5.5 Rail dot (24 px column, centred, 6 px from the row top)
| State | Dot |
|---|---|
| Next upcoming event (first non-cancelled event in the whole list) | 14 px solid green, with a 2.2 s pulse (box-shadow ring expanding 0 → 9 px, green 55 % → 0). |
| Any other event | 12 px, `bg` fill, 2 px green ring. |
| Cancelled | 12 px, `bg` fill, 2 px `muted` ring. |
| Quiet day (see 6.6) | 8 px, `bg` fill, 2 px `muted` 50 % ring. |

### 5.6 Event row content (parent)
Laid out as `[crest 40 px] [12 px gap] [text column]`, crest top-aligned 2 px down.

1. **Line 1** — time in Inter Tight 18 / 700; then `Meet HH:MM` 13 px muted; then, only on the next event, `in 2h 30m` 12 px / 700 green; then, if paid, the **Paid** tag. 10 px gaps.
2. **Line 2** — title, 16 / 600, 3 px above.
3. **Line 3** — `Clontarf GAA · Boys 2013 · Club Astro`: club name in `text` / 500, the rest `muted`; 13 px; 3 px above.
4. **Footer** (10 px above) — left: attendance ring 26 px + "14 attending" (12.5 / 600) over "3 no reply · 2 declined" (11.5 muted). Right: reply control (5.8).

Crest: `clubs.crest` for the event's `club_id`, 40 px, cover-fit, circular or as supplied. If the club has no crest, show a 40 px circle in `surface2` with the club's initial in `muted` — never the CoachSmart icon.

### 5.7 Attendance ring
A 26 px circle (3.5 px stroke). Track: `text` at 12 % alpha. Fill: green arc from 12 o'clock, clockwise, proportion = `accepted_count / (accepted + no_response + declined)`. If the total is 0, show the track only. Accessible label: "{a} attending, {n} no reply, {d} declined". Wording order is always **Attending, No reply, Declined**.

### 5.8 Reply control
- **No reply yet** (`response_id` is 0 / null): a ✓ / ✕ pair. Two 40 px squares, radius 12, 6 px apart. ✓ is outlined green (1.5 px at 55 % alpha) with a green tick; ✕ is outlined `muted` (45 %) with a muted cross. Tapping writes the response and the pair becomes the status below. Optimistic update; revert on failure.
- **Attending** (`response_id` = 3): green tick + "Attending", 13 / 600 green. Tapping it opens the event (no inline change of mind from Home; that is deliberate — changing a reply is a decision that belongs on the event page).
- **Declined** (`response_id` = 4): muted cross + "Declined", 13 / 600 muted. Same tap behaviour.
- Events with `request_attendance = false` show neither pair nor status; the footer is the ring only.

### 5.9 Tags
`Cancelled` and `Paid`: 11 px / 700, uppercase, letter-spacing 0.06 em, 1 px outline, radius 6, padding 5 × 8. Cancelled is `muted`; Paid is green. Tags sit on line 1 after the meet time.

### 5.10 Coach variant (D3)
Same row, two differences:
- Footer counts become one line of three equal-weight numbers: **14** attending · **6** no reply · **1** declined (numbers `text` / 700, words `muted`), because *no reply* is the number a coach acts on.
- Reply pair is 36 px instead of 40.
- The bottom bar (Home · Resources · Favourites · Add event) is present. Icons line-stroke, active item green.

A user is a coach on Home when `highest_role_level` ≥ the coach threshold the app already uses for the bottom bar. Do not add a new rule.

## 6. States

### 6.1 Next event
Exactly one event is "next": the first in date order that is not cancelled. Its dot pulses, its day numeral is green, and line 1 carries "in {countdown}". Countdown format: `in 2h 30m` under 24 h, `in 2 days` otherwise, hidden if the event has started.

### 6.2 Replied / not replied — see 5.8.

### 6.3 Cancelled (`event_status = 'cancelled'`)
Time and title in `muted` with strike-through. Crest at 45 % opacity. `Cancelled` tag on line 1. No ring, no reply control, line 3 shows club · team only.

### 6.4 Paid (`payment_required` and `event_paid`)
Green `Paid` tag on line 1. Everything else as normal. Payment *due* has no Home treatment in this round; it stays on the event page.

### 6.5 Filtered (D4)
Chip selected; only that team's events on the rail. Day markers still appear once per remaining day.

### 6.6 Quiet day (D5)
If **today** has no events, the first row is a quiet-day marker: today's numeral and weekday, the small quiet dot, and "Nothing on today" in 14 px muted. The rail continues to the next event. Only today gets this; empty days between events are simply absent.

### 6.7 Nothing upcoming at all
Today's quiet-day marker, then nothing. The rail stops after it. No illustration, no call to action.

### 6.8 Squad events
If `squad_name` is present, append it to line 3 after the team: `Clontarf GAA · Girls 2012 · Blue · Home pitch`. No colour, no squad image on Home.

## 7. Data mapping — `get_user_home_events`

Everything below already comes back from the RPC except the one row marked **ADD**.

| Design element | Field |
|---|---|
| Team chips | `user_teams[]`: `team_id`, `team_name`, `club_id`; skip the synthetic `team_id = 0` "All Teams" row and render `All` yourself |
| Crest in a chip / on an event | `clubs[]` where `club_id` matches; use `crest`. Skip the synthetic "All Clubs" row |
| Day numeral, grouping, countdown, time | **ADD** `event_date_time` (raw ISO timestamp) to `final_events_data` — see §8 |
| Meet time | `meet_time` (text, as entered) |
| Title | `event_title` (already the effective title) |
| Club name on line 3 | `clubs[].club_name` via `club_id` |
| Team on line 3 | `team_name` |
| Squad on line 3 | `squad_name` |
| Venue | `location_name` |
| Ring and counts | `accepted_count`, `no_response_count`, `declined_count` |
| User's reply | `response_id` (3 attending, 4 declined, 0/null none); `member_id` for the write |
| Show reply control at all | `request_attendance` |
| Cancelled | `event_status` |
| Paid tag | `payment_required && event_paid` |
| Coach bottom bar | `highest_role_level` |
| Bell dot | `unread_notifications > 0` |

## 8. Backend change (one, additive)

`get_user_home_events` returns the date only as `event_date_time_formatted` ("Tuesday, 10 November, 2026 at 17:50"). The timeline needs the raw timestamp. Add `ue.event_date_time` to the `final_events_data` select so each event also carries `event_date_time` (ISO 8601). This adds a key and changes nothing existing, so it is safe for the PWA. New migration file, today's date prefix, no timestamp collision (last is `20261111153000`).

## 9. Behaviour

- Pull to refresh re-runs the RPC; the list keeps scroll position where possible.
- Tapping anywhere on an event row except the reply control opens the event page (existing navigation).
- Tapping ✓ or ✕ writes the reply using the **same action the event page already uses** (assumption; if that action needs event-page state, add a thin wrapper rather than a new write path). After a successful write, update that row in place — do not reload the whole list.
- Chip selection persists while the app is open; on cold start, `All`.
- The pulse animation is decorative: respect "Reduce Motion" by showing the solid dot without the ring.

## 10. Out of scope for this round

- Event detail page, car pool, payments due, squad images.
- Changing an existing reply from Home.
- Any new filter beyond team.
- Any coach "nudge no-replies" feature. The coach variant only re-weights the numbers.

## 11. Acceptance checklist

- [ ] A parent with one child in three clubs sees three chips with three different crests, and each event's crest matches its chip.
- [ ] Each date appears exactly once on the rail.
- [ ] Exactly one dot pulses; it is the first non-cancelled upcoming event.
- [ ] An unreplied event shows ✓ / ✕; tapping ✓ turns it into "Attending" without a full reload; the counts on that row change by one.
- [ ] A cancelled event is struck through, crest dimmed, no ring, no reply control.
- [ ] A paid event shows a green Paid tag.
- [ ] Parent Home has no bottom bar; coach Home has one.
- [ ] A day with nothing on shows "Nothing on today" on the rail (today only).
- [ ] Selecting a team chip changes which events show, nothing else.
- [ ] The only colours on screen are the brand set plus the crests.
