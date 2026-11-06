# Gym check-in kiosk

A full-screen page for a tablet in the gym. Members pick today's S&C session (or **Open gym**), tap their name or scan their QR code, and are checked in. Coaches keep creating teams, squads and S&C events in CoachSmart as now.

- Page: `https://coachsmart.app/webviews/gym-kiosk/`
- Server: Supabase edge function `gym-kiosk` (the only thing the tablet talks to)
- Data: `event_checkins` and `kiosk_devices` (migration `20261105220000_gym_kiosk.sql`), plus the read-only view `view_event_checkins`

Nothing existing in CoachSmart is changed. RSVPs (`event_attendance`) are never written: an RSVP is what someone intended, a check-in is what actually happened.

## What shows up

- **Sessions:** today's events with the **S&C** event code for the club's S&C teams (teams linked to S&C in `club_code_link`, or with S&C events). Check-in is open all day.
- **Names:** for an event, members of that event's team only, its squad first. Shown as first name + surname initial ("Ken D"); a second or third surname letter only where two people would clash, and a number if they still clash. No photos, member codes or dates of birth ever reach the tablet.
- **Open gym:** anyone on one of the club's S&C teams, with no session attached.
- **Walk-in:** not stored; it is any event check-in without an Accept RSVP (no reply or declined). See `view_event_checkins.walk_in`.
- **QR:** the member's `unique_member_code` as a QR code. Scanned from the home screen (or Open gym) it goes to the member's own team session if one starts within an hour either side, otherwise Open gym; scanned inside a session it goes to that session. Someone scanning into another team's session is checked in to Open gym instead. Chrome on Android reads QR codes natively; elsewhere (iPad Safari) the bundled jsQR does.
- **Open gym during a team session:** tapping a name in Open gym while that member's team has a session within an hour asks whether they meant the session.
- **My gym QR:** members open `https://coachsmart.app/webviews/gym-qr/`, sign in once with their CoachSmart login and add it to their home screen. It shows the QR for every member the login is linked to (a parent sees each child), and keeps working offline.

## Setting up a tablet (Android)

1. Open Chrome on the tablet, go to `https://coachsmart.app/webviews/gym-kiosk/`.
2. A **club admin** signs in with their CoachSmart email and password (an Admin of one of the club's S&C teams, or a SuperUser), names the tablet and picks a **coach PIN** (4 to 6 digits). If they admin more than one club they pick the club. The page then uses that club's crest and colours.
3. Chrome menu → **Add to home screen / Install app**, then open it from the home screen (it runs full screen).
4. Lock the tablet to the app: Settings → Security → **App pinning** (or "Pin windows"), then pin the Gym check-in app. A kiosk launcher such as Fully Kiosk Browser also works.
5. Turn off screen timeout (Settings → Display) or keep the tablet on charge; the page also asks the browser to keep the screen awake.

The club can't be changed from the kiosk. To move a tablet to another club, a club admin opens coach mode → **Remove this tablet** (needs their email and password), then sets it up again.

## Coach mode

Press and hold the crest for 2 seconds, enter the coach PIN. Shows each session's check-ins with **Undo**, anything waiting to sync, anything the server refused, **Refresh now** and **Remove this tablet**.

Members can undo a check-in on the day: tap "Not me? Undo" on the Thanks screen, or press and hold a ticked name. Undoing an earlier day's check-in needs the coach PIN.

## Offline

Today's sessions and names are kept on the tablet and refreshed every minute. With no Wi-Fi, taps still work: they are queued on the tablet ("Offline · 3 waiting to sync") and sent when it reconnects. Every check-in has its own id, so a check-in sent twice is only stored once, and two tablets checking in the same person for the same session store it once. QR scans made offline are checked on the server when they sync. Coach mode and setup need a connection.

## Reports

```sql
-- Who came to an event, with RSVP and walk-ins
select first_name, last_name, rsvp, walk_in, checked_in_at
from view_event_checkins where event_id = 1703 order by checked_in_at;

-- Said yes but didn't turn up
select m.first_name, m.last_name
from event_attendance a join members m using (member_id)
where a.event_id = 1703
  and a.attendance_id = (select max(attendance_id) from event_attendance b where b.event_id = a.event_id and b.member_id = a.member_id)
  and a.response_id = 3
  and not exists (select 1 from event_checkins c where c.event_id = a.event_id and c.member_id = a.member_id and c.status = 'active');
```

## Not in this phase

- The "My gym QR" screen in the CoachSmart app (FlutterFlow): show `members.unique_member_code` as a QR code.
- Attended / walk-ins / no-shows on the event screen in the app.
