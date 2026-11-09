/**
 * Clontarf senior diary: publish this sheet to coachsmart.app/clontarf-gaa/senior-diary/
 *
 * Paste into the sheet: Extensions > Apps Script, replace Code.gs with this file, save.
 * Then Project Settings (cog) > Script properties > add DIARY_SECRET with the secret
 * Claude gave you. Reload the sheet: a "Diary" menu appears with "Publish to players".
 *
 * Anyone who can edit the sheet can publish. Nothing changes for players until
 * someone presses Publish, and nothing is saved if the sheet has a mistake:
 * the errors are listed with the tab and row to fix.
 *
 * Tabs (names must match). Headings are found in the top rows; in the styled
 * sheet they are on row 4 with a grey hint row under them. Extra columns such
 * as Coach notes are never sent to players.
 *   Events      Status | Date | Start | End | Type | Title | Where | Details | Who | Link
 *   Activities  Status | From | To | Days | Time | Type | Title | Minutes | Subtitle | Steps | Video link | Who | Replaces plan
 *   Notes       Status | From | To | Who | Message      (or the old Player | From | To | Note)
 *   Schedule    Date | When | Session | Note | Player
 *   Sessions    Code | Kind | Session | Subtitle | Minutes | Track lift | Section | Section note | Exercise | Detail | Video
 *   Blocks      Block | From | To | Aim
 *   Settings    Setting | Value        (Check-in form, Weights guidance)
 * Only rows with Status = Live reach players.
 */
var URL_ = 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/diary-sheet-publish';
// Public anon key (the same one the diary page uses). It only gets the call past
// Supabase's gateway; the DIARY_SECRET script property is what allows a publish.
var ANON_ = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4';
var TABS_ = ['Settings', 'Blocks', 'Sessions', 'Schedule', 'Notes', 'Events', 'Activities'];

function onOpen() {
  SpreadsheetApp.getUi().createMenu('Diary').addItem('Publish to players', 'publishDiary')
    .addSeparator().addItem('Upgrade sheet layout (once)', 'upgradeLayout').addToUi();
}

function publishDiary() {
  var ui = SpreadsheetApp.getUi();
  var secret = PropertiesService.getScriptProperties().getProperty('DIARY_SECRET');
  if (!secret) { ui.alert('Not set up yet', 'Add the DIARY_SECRET script property first (Extensions > Apps Script > Project Settings).', ui.ButtonSet.OK); return; }

  var ss = SpreadsheetApp.getActive(), tz = ss.getSpreadsheetTimeZone(), tabs = {};
  TABS_.forEach(function (name) {
    var sh = ss.getSheetByName(name);
    if (!sh) return;
    var range = sh.getDataRange(), shown = range.getDisplayValues();
    tabs[name] = range.getValues().map(function (row, i) {
      return row.map(function (v, j) {
        if (!(v instanceof Date)) return String(v);
        // A time-only cell (e.g. Start 19:30) comes back as a date in 1899;
        // send it as shown (19:30) since old dates carry odd time-zone offsets.
        return v.getFullYear() < 1901 ? shown[i][j] : Utilities.formatDate(v, tz, 'yyyy-MM-dd');
      });
    });
  });

  var res = UrlFetchApp.fetch(URL_, {
    method: 'post', contentType: 'application/json', muteHttpExceptions: true,
    headers: { Authorization: 'Bearer ' + ANON_, apikey: ANON_, 'x-diary-secret': secret },
    payload: JSON.stringify({ by: Session.getActiveUser().getEmail(), tabs: tabs })
  });

  var out;
  try { out = JSON.parse(res.getContentText()); } catch (e) { out = { error: res.getContentText() }; }
  var warn = (out.warnings || []).length ? '\n\nWorth a look:\n• ' + out.warnings.join('\n• ') : '';
  if (out.ok) {
    ui.alert('Published', 'Players will see this the next time they open the diary.\n\n' + out.summary + warn, ui.ButtonSet.OK);
  } else {
    var why = out.errors ? '• ' + out.errors.join('\n• ') : (out.error || ('Error ' + res.getResponseCode()));
    ui.alert('Not published', 'Nothing has changed for players. Fix these and publish again:\n\n' + why + warn, ui.ButtonSet.OK);
  }
}

/* ------------------------------------------------------------------------
 * One-off: Diary > Upgrade sheet layout
 * Restyles this sheet to match the girls' Féile sheet: a title, headings on
 * row 4 with grey hints under them, a Coach notes column, and the new Events,
 * Activities and Notes tabs (with Status: Suggested / Live / Off). Nothing is
 * deleted: the old Notes rows move to the new Notes tab as Live, and every
 * plan row stays as it is. Safe to run twice (styled tabs are skipped).
 * ---------------------------------------------------------------------- */
var RED_ = '#ED1B2E', NAVY_ = '#1B2A4E', DATE_ = 'ddd d mmm yy', TIME_ = 'hh:mm';
var STATUS_ = ['Suggested', 'Live', 'Off'];

var LAYOUT_ = {
  Events: { title: 'Events & meetups', sub: 'Informal things the squad should know about. No RSVP, no tick box. Matches and training stay in CoachSmart.',
    cols: [['Status', 'Live shows; Suggested waits for you; Off hides', 11], ['Date', '', 14], ['Start', '24h', 8], ['End', 'optional', 8], ['Type', 'pick from list', 13],
      ['Title', 'Short, shows in the timeline and This week', 30], ['Where', 'Venue or meeting point', 24], ['Details', 'One or two lines under the title', 44],
      ['Who', "All, or a player's CoachSmart email", 22], ['Link', 'Optional: map, form, poster', 26], ['Coach notes', 'Never shown to players', 28]],
    lists: { Status: STATUS_, Type: ['Meeting', 'Social', 'Fundraiser', 'Club event', 'Testing', 'Physio', 'Gear', 'Notice'] },
    fmt: { Date: DATE_, Start: TIME_, End: TIME_ },
    rows: [['Suggested', '2026-11-12', '19:30', '20:30', 'Meeting', 'Squad meeting: plan for 2027', 'Clubhouse', 'Off-season review and what the next block looks like. All panel welcome.', 'All', '', 'Example row'],
      ['Suggested', '2026-11-21', '10:00', '12:00', 'Testing', 'Fitness testing morning', 'Clontarf pitch 2', 'Jump, 10 m and 20 m sprint and a short run test. Bring boots and runners.', 'All', '', 'Example row'],
      ['Suggested', '2026-11-28', '11:00', '12:00', 'Gear', '2027 training kit sizing', 'Clubhouse', 'Try on sizes for the new training top and shorts.', 'All', '', 'Example row'],
      ['Suggested', '2026-12-12', '19:30', '', 'Social', 'Panel Christmas night', 'TBC', 'Partners welcome. Details in the WhatsApp group.', 'All', '', 'Example row'],
      ['Suggested', '2026-12-25', '10:30', '11:30', 'Club event', 'Christmas Day swim', 'Bull Wall', 'Club tradition. Fancy dress optional, hot drinks after.', 'All', '', 'Example row']] },
  Activities: { title: 'Activities', sub: 'Extra things to do on a day or run of days: recovery, mobility, challenges. They get a tick box like the plan’s sessions.',
    cols: [['Status', 'Live shows; Suggested waits for you; Off hides', 11], ['From', 'First day', 14], ['To', 'Blank = one day only', 14], ['Days', 'Every day, Weekdays, or e.g. Mon, Wed', 14],
      ['Time', 'First, Then, Any time or 24h', 10], ['Type', 'pick from list (sets the icon)', 13], ['Title', 'Short', 28], ['Minutes', 'Duration chip', 8],
      ['Subtitle', 'One line under the title', 34], ['Steps', 'One per line: Step title | how to do it', 46], ['Video link', 'Optional, shows a Watch button', 26],
      ['Who', "All, or a player's CoachSmart email", 22], ['Replaces plan', "Yes = hides that day's planned sessions", 11], ['Coach notes', 'Never shown', 26]],
    lists: { Status: STATUS_, Type: ['Gym', 'Speed', 'Run', 'Recovery', 'Mobility', 'Rehab', 'Skills', 'Challenge', 'Diet', 'Rest'], 'Replaces plan': ['Yes', 'No'] },
    fmt: { From: DATE_, To: DATE_ },
    rows: [['Suggested', '2026-11-09', '2026-11-15', 'Every day', 'Any time', 'Mobility', 'Daily 10-minute mobility', 10, 'Between blocks: keep moving well', 'Hips | 90/90 switches, 6 each side\nAnkles | Knee-to-wall, 10 each side\nUpper back | Open books, 6 each side', '', 'All', 'No', 'Example row'],
      ['Suggested', '2026-11-15', '2026-12-20', 'Sun', 'Any time', 'Recovery', 'Recovery swim or sea dip', 20, 'Easy swim, or 5 min in the sea at the Bull Wall', '', '', 'All', 'No', 'Example row'],
      ['Suggested', '2026-12-21', '2027-01-03', 'Every day', 'Any time', 'Challenge', '10,000 steps over Christmas', '', 'Log your daily steps and send them with your check-in', '', '', 'All', 'No', 'Example row'],
      ['Suggested', '2026-12-25', '', '', 'Any time', 'Rest', 'Christmas Day', '', 'Rest, eat well, enjoy it. Happy Christmas!', '', '', 'All', 'Yes', 'Example row']] },
  Notes: { title: 'Coach notes to players', sub: 'Messages for the “From your coach” box on a day or run of days, for the whole squad or one player.',
    cols: [['Status', 'Live shows; Suggested waits for you; Off hides', 11], ['From', 'The day it starts', 14], ['To', 'Blank = one day only', 14],
      ['Who', "All, or a player's CoachSmart email", 24], ['Message', 'Shows in the From your coach box', 60], ['Coach notes', 'Never shown', 28]],
    lists: { Status: STATUS_ }, fmt: { From: DATE_, To: DATE_ },
    rows: [['Suggested', '2026-11-09', '', 'All', 'Block 1 is done, well done. Easy week before Block 2: move, sleep, and keep the mobility going.', 'Example row']] },
  Schedule: { title: 'Team schedule', sub: 'The day-by-day plan: one row per session per day. Player rows replace the team plan for that player on that date.',
    hints: { Date: '', When: 'First, Then or Any time', Session: 'A code from Sessions, or Rest', Note: 'For Rest: what to show', Player: "Blank = whole squad, or a player's email" },
    lists: { When: ['First', 'Then', 'Any time'] }, fmt: { Date: DATE_ } },
  Sessions: { title: 'Session library', sub: 'Every gym, speed and run session, one row per exercise. Fill the first six columns on a session’s first row only.',
    hints: { Code: 'Unique, e.g. G1-W2', Kind: 'gym, speed or run', Session: 'Name in the timeline', Subtitle: 'One line under the name', Minutes: 'Duration chip',
      'Track lift': 'Gym only: lift players log', Section: 'e.g. Prepare, A · Power', 'Section note': 'Shows above the exercises', Exercise: 'Tick box item', Detail: 'Dose · cue', Video: 'Optional, shows a Watch button' },
    lists: { Kind: ['gym', 'speed', 'run'] } },
  Blocks: { title: 'Training blocks', sub: 'Each block sets the week count in the header and the aim shown on Mondays.',
    hints: { Block: 'Name in the header', From: 'A Monday', To: 'A Sunday', Aim: 'Shown on each Monday of the block' }, fmt: { From: DATE_, To: DATE_ } },
  Settings: { title: 'Settings', sub: 'One value each. Used across the whole diary.', hints: {}, noNotes: true }
};

var HOW_ = ['How this sheet works',
  'One sheet for everything the senior diary shows that CoachSmart can’t create itself. Matches and training stay in CoachSmart.',
  'Quick-add tabs (same as the girls’ sheet): Events, Activities, Notes. Status: Live shows in the diary, Suggested is waiting for a coach to check, Off hides it.',
  'Events: meetings, socials, testing days, gear, physio slots. They show in the day’s timeline and This week with no tick box and no RSVP.',
  'Activities: extra things players do, with a tick box. From/To and Days repeat them (e.g. every Sunday in December). Replaces plan = Yes hides that day’s planned sessions.',
  'Steps: one step per line inside the cell (Alt+Enter, or Option+Enter on Mac). Write “Step title | how to do it”.',
  'Who: All for the squad, or a player’s CoachSmart email for one player only (e.g. a rehab plan). The diary needs a login, so emails are never public.',
  'Programme tabs: Schedule, Sessions, Blocks, Settings hold David’s plan.',
  'Nothing changes for players until someone presses Diary > Publish to players. Mistakes are listed by tab and row and nothing is saved.',
  'Keep rows 1 to 5 of each tab as they are (title, headings, grey hints): publishing looks for the headings there.',
  'Coach notes columns are never shown to players. The example rows are all Suggested: edit or delete them.'];

function styleHead_(sh, title, sub, heads, hints, widths) {
  sh.getRange(1, 1).setValue('SENIOR DIARY · ' + title).setFontFamily('Oswald').setFontSize(16).setFontWeight('bold').setFontColor(RED_);
  sh.setRowHeight(1, 32);
  sh.getRange(2, 1).setValue(sub).setFontSize(10).setFontStyle('italic').setFontColor('#555555');
  var n = heads.length;
  sh.getRange(4, 1, 1, n).setValues([heads]).setFontWeight('bold').setFontColor(NAVY_).setBackground('#F3F4F8')
    .setBorder(null, null, true, null, null, null, RED_, SpreadsheetApp.BorderStyle.SOLID_MEDIUM).setVerticalAlignment('middle').setWrap(true);
  sh.getRange(5, 1, 1, n).setValues([hints]).setFontSize(9).setFontStyle('italic').setFontColor('#888888').setWrap(true).setVerticalAlignment('top');
  if (widths) widths.forEach(function (w, i) { sh.setColumnWidth(i + 1, Math.round(w * 7.5)); });
  sh.setFrozenRows(5);
}

function lists_(sh, heads, lists, fmt) {
  var rows = Math.max(sh.getMaxRows() - 5, 300);
  if (sh.getMaxRows() < rows + 5) sh.insertRowsAfter(sh.getMaxRows(), rows + 5 - sh.getMaxRows());
  Object.keys(lists || {}).forEach(function (h) {
    var i = heads.indexOf(h); if (i < 0) return;
    sh.getRange(6, i + 1, rows, 1).setDataValidation(SpreadsheetApp.newDataValidation().requireValueInList(lists[h], true).setAllowInvalid(true).build());
  });
  Object.keys(fmt || {}).forEach(function (h) {
    var i = heads.indexOf(h); if (i >= 0) sh.getRange(6, i + 1, rows, 1).setNumberFormat(fmt[h]);
  });
  sh.getRange(6, 1, rows, heads.length).setWrap(true).setVerticalAlignment('top');
}

function styled_(sh) { return String(sh.getRange(1, 1).getValue()).indexOf('SENIOR DIARY') === 0; }
function asDate_(s) { if (!s) return ''; var p = s.split('-'); return new Date(+p[0], +p[1] - 1, +p[2]); }

function newTab_(ss, name, L, extraRows) {
  var sh = ss.insertSheet(name);
  var heads = L.cols.map(function (c) { return c[0]; });
  styleHead_(sh, L.title, L.sub, heads, L.cols.map(function (c) { return c[1]; }), L.cols.map(function (c) { return c[2]; }));
  lists_(sh, heads, L.lists, L.fmt);
  var rows = (extraRows || []).concat(L.rows || []).map(function (r) {
    return r.map(function (v, i) { return (L.fmt && L.fmt[heads[i]] === DATE_ && typeof v === 'string') ? asDate_(v) : v; });
  });
  if (rows.length) sh.getRange(6, 1, rows.length, heads.length).setValues(rows);
  return sh;
}

function upgradeLayout() {
  var ss = SpreadsheetApp.getActive(), ui = SpreadsheetApp.getUi();
  if (ui.alert('Upgrade sheet layout', 'This restyles the tabs and adds Events, Activities and the new Notes tab. No plan rows are removed. Carry on?', ui.ButtonSet.OK_CANCEL) !== ui.Button.OK) return;

  // Programme tabs: add the title and hint rows above/below the existing headings, plus Coach notes.
  ['Schedule', 'Sessions', 'Blocks', 'Settings'].forEach(function (name) {
    var sh = ss.getSheetByName(name), L = LAYOUT_[name];
    if (!sh || styled_(sh)) return;
    var heads = sh.getRange(1, 1, 1, sh.getLastColumn()).getValues()[0].map(String).filter(String);
    if (!L.noNotes && heads.indexOf('Coach notes') < 0) { heads.push('Coach notes'); sh.getRange(1, heads.length).setValue('Coach notes'); }
    sh.insertRowsBefore(1, 3);
    sh.insertRowsAfter(4, 1);
    styleHead_(sh, L.title, L.sub, heads, heads.map(function (h) { return h === 'Coach notes' ? 'Never shown' : (L.hints[h] || ''); }), null);
    lists_(sh, heads, L.lists, L.fmt);
  });

  // Notes: the old Player | From | To | Note rows become Live rows for that player.
  var old = ss.getSheetByName('Notes'), moved = [];
  if (old && !styled_(old)) {
    var v = old.getDataRange().getValues(), tz = ss.getSpreadsheetTimeZone();
    var f = function (x) { return x instanceof Date ? Utilities.formatDate(x, tz, 'yyyy-MM-dd') : String(x || ''); };
    v.slice(1).forEach(function (r) { if (r.join('')) moved.push(['Live', f(r[1]), f(r[2]), String(r[0]), String(r[3]), 'Moved from the old Notes tab']); });
    old.setName('Notes (old)');
  }
  if (!ss.getSheetByName('Notes')) newTab_(ss, 'Notes', LAYOUT_.Notes, moved);
  if (old && ss.getSheetByName('Notes (old)')) ss.deleteSheet(old);
  if (!ss.getSheetByName('Events')) newTab_(ss, 'Events', LAYOUT_.Events);
  if (!ss.getSheetByName('Activities')) newTab_(ss, 'Activities', LAYOUT_.Activities);

  // Read me becomes How to use.
  var how = ss.getSheetByName('Read me') || ss.getSheetByName('How to use') || ss.insertSheet('How to use');
  how.setName('How to use'); how.clear();
  how.getRange(1, 1, HOW_.length, 1).setValues(HOW_.map(function (s) { return [s]; })).setWrap(true).setVerticalAlignment('top');
  how.getRange(1, 1).setFontFamily('Oswald').setFontSize(16).setFontWeight('bold').setFontColor(RED_);
  how.setColumnWidth(1, 820);

  ['Events', 'Activities', 'Notes', 'Schedule', 'Sessions', 'Blocks', 'Settings', 'How to use'].forEach(function (name, i) {
    var sh = ss.getSheetByName(name); if (sh) { ss.setActiveSheet(sh); ss.moveActiveSheet(i + 1); }
  });
  ss.setActiveSheet(ss.getSheetByName('Events'));
  ui.alert('Done', 'The sheet now matches the girls’ format. The example rows on Events, Activities and Notes are Suggested, so players won’t see them. Publish as usual when you’re ready.', ui.ButtonSet.OK);
}
