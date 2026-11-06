/**
 * Clontarf Girls 2012 · Road to Féile: the coaches' sheet for the diary at
 * coachsmart.app/clontarf-gaa/feile27/
 *
 * For things CoachSmart doesn't create: meetups and other no-RSVP events,
 * activities on certain days, and day or week notes. Matches, training and
 * S&C stay in CoachSmart.
 *
 * Set up once:
 *   1. Extensions > Apps Script, replace Code.gs with this file, save.
 *   2. Project Settings (cog) > Script properties > add DIARY_SECRET with the
 *      secret Claude gave you.
 *   3. Back in the sheet, reload. A "Diary" menu appears. Run Diary > Set up tabs
 *      (Google asks you to allow the script the first time).
 *
 * Every row has a Status:
 *   Suggested  added by Claude (Diary > Pull suggestions). Never shown.
 *   Live       shown to the girls after the next Diary > Publish.
 *   Off        a draft or a no. Never shown.
 * Coach notes are never sent anywhere.
 */
var URL_ = 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/team-diary-sheet';
// Public anon key (the same one the diary page uses). It only gets the call past
// Supabase's gateway; the DIARY_SECRET script property is what allows a publish.
var ANON_ = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4';
var CODE_ = 'TMA47A5';
var RED_ = '#ED1B2E', NAVY_ = '#1B3A6B', GREY_ = '#F3F4F8';
var STATUS_ = ['Suggested', 'Live', 'Off'];
var HEAD_ROW_ = 4, FIRST_ROW_ = 6;

var TABS_ = {
  Events: {
    title: 'Events & meetups',
    sub: 'Informal things the girls should know about. No RSVP, no tick box. Matches, training and S&C stay in CoachSmart.',
    cols: [['Status', 11, 'Suggested / Live / Off'], ['Date', 14, ''], ['Start', 8, '24h'], ['End', 8, 'optional'],
      ['Type', 13, 'pick from list'], ['Title', 30, 'Short: shows in the timeline and This week'], ['Where', 24, 'Venue or meeting point'],
      ['Details', 44, 'One or two lines under the title'], ['Who', 10, 'All, or one squad'], ['Link', 26, 'Optional: map, form, poster (https://)'],
      ['Coach notes', 30, 'Never shown to the girls']],
    lists: { Type: ['Meetup', 'Social', 'Fundraiser', 'Club event', 'Gear', 'Notice'], Who: ['All', 'Blue', 'Red', 'Green'] },
    dates: ['Date'], times: ['Start', 'End'],
    examples: [
      ['Off', '2026-11-21', '11:00', '12:30', 'Meetup', 'Team walk on the Bull Wall', 'Bull Wall car park', 'Bring a jacket and a water bottle. Hot chocolate after.', 'All', '', 'Example row'],
      ['Off', '2026-12-18', '18:30', '20:30', 'Social', 'Christmas party', 'Clubhouse', 'Pizza, music and the Kris Kindle. Dress up!', 'All', '', 'Example row']]
  },
  Activities: {
    title: 'Activities',
    sub: 'Things to do on a day or run of days: home sessions, runs, challenges, diet habits. They get a tick box like the plan\'s own items.',
    cols: [['Status', 11, 'Suggested / Live / Off'], ['From', 14, 'First day'], ['To', 14, 'Blank = one day only'],
      ['Days', 14, 'Every day, Weekdays, Weekends, or Mon, Wed...'], ['Time', 8, '24h, blank = any time'], ['Type', 14, 'pick from list'],
      ['Where it shows', 15, 'Timeline or Every day list'], ['Title', 28, 'Short'], ['Minutes', 9, 'Duration chip'],
      ['Subtitle', 34, 'One line under the title'], ['Steps', 46, 'One per line: Step title | how to do it'],
      ['Video link', 26, 'Optional: adds a Watch button'], ['Replaces plan', 11, 'Yes = hides the planned run / home session that day'],
      ['Coach notes', 30, 'Never shown']],
    lists: { Type: ['Home session', 'Run', 'Skills', 'Challenge', 'Diet', 'Rest'], 'Where it shows': ['Timeline', 'Every day list'], 'Replaces plan': ['Yes', 'No'] },
    dates: ['From', 'To'], times: ['Time'],
    examples: [
      ['Off', '2026-11-26', '', '', '18:30', 'Home session', 'Timeline', 'Wall ball challenge', '15', 'Beat your score from last week',
        'Warm up | 2 min jog on the spot and arm circles\nLeft hand only | 50 catches off the wall\nRight hand only | 50 catches\nScore | Clean catches in 60 s, write it down', '', 'Yes', 'Example row'],
      ['Off', '2027-02-01', '2027-02-07', 'Every day', '', 'Diet', 'Every day list', 'Breakfast every day', '', 'Something with protein before school', '', '', 'No', 'Example row']]
  },
  Notes: {
    title: 'Day & week notes',
    sub: 'The box under the day title, and an optional Eating well tip. A week note (date = any day that week) shows every day Mon to Sun.',
    cols: [['Status', 11, 'Suggested / Live / Off'], ['Date', 14, 'The day, or any day in the week'], ['Applies to', 11, 'Day or Week'],
      ['Message', 50, 'Shows in the box under the day title'], ['Eating well tip', 40, 'Optional: replaces the day\'s tip'], ['Coach notes', 30, 'Never shown']],
    lists: { 'Applies to': ['Day', 'Week'] },
    dates: ['Date'], times: [],
    examples: [['Off', '2027-04-23', 'Day', 'Féile tomorrow! Pack your bag tonight: boots, gumshield, helmet, water.', 'Pasta or rice for dinner, plenty of water.', 'Example row']]
  }
};

function onOpen() {
  SpreadsheetApp.getUi().createMenu('Diary')
    .addItem('Publish to the girls', 'publishDiary')
    .addItem('Check for mistakes (no publish)', 'checkDiary')
    .addSeparator()
    .addItem('Pull Claude\'s suggestions', 'pullSuggestions')
    .addSeparator()
    .addItem('Set up tabs', 'setUpTabs')
    .addToUi();
}

// ---- talking to CoachSmart ----
function call_(payload) {
  var secret = PropertiesService.getScriptProperties().getProperty('DIARY_SECRET');
  if (!secret) throw new Error('Add the DIARY_SECRET script property first (Extensions > Apps Script > Project Settings).');
  payload.code = CODE_;
  var res = UrlFetchApp.fetch(URL_, {
    method: 'post', contentType: 'application/json', muteHttpExceptions: true,
    headers: { Authorization: 'Bearer ' + ANON_, apikey: ANON_, 'x-diary-secret': secret },
    payload: JSON.stringify(payload)
  });
  try { return JSON.parse(res.getContentText()); } catch (e) { return { error: res.getContentText() || ('Error ' + res.getResponseCode()) }; }
}

function tabsForSend_() {
  var ss = SpreadsheetApp.getActive(), tz = ss.getSpreadsheetTimeZone(), out = {};
  Object.keys(TABS_).forEach(function (name) {
    var sh = ss.getSheetByName(name);
    if (!sh) return;
    var head = sh.getRange(HEAD_ROW_, 1, 1, sh.getLastColumn()).getValues()[0];
    var keep = head.map(function (h) { return String(h).trim() !== 'Coach notes'; });
    // Sent from row 1 so error messages can give the real row number.
    out[name] = sh.getRange(1, 1, Math.max(HEAD_ROW_, sh.getLastRow()), head.length).getValues()
      .map(function (row) {
        return row.filter(function (_, i) { return keep[i]; }).map(function (v) {
          if (!(v instanceof Date)) return String(v);
          return v.getFullYear() < 1950 ? Utilities.formatDate(v, tz, 'HH:mm') : Utilities.formatDate(v, tz, 'yyyy-MM-dd');
        });
      });
  });
  return out;
}

function send_(dryRun) {
  var ui = SpreadsheetApp.getUi(), out;
  try { out = call_({ action: 'publish', dryRun: dryRun, by: Session.getActiveUser().getEmail(), tabs: tabsForSend_() }); }
  catch (e) { ui.alert('Not set up yet', e.message, ui.ButtonSet.OK); return; }
  var warn = (out.warnings || []).length ? '\n\nWorth a look:\n• ' + out.warnings.join('\n• ') : '';
  if (out.ok) {
    ui.alert(dryRun ? 'All good' : 'Published',
      (dryRun ? 'Nothing was published. ' : 'The girls will see this within 5 minutes of opening the diary.\n\n') + out.summary + warn, ui.ButtonSet.OK);
  } else {
    var why = out.errors ? '• ' + out.errors.join('\n• ') : (out.error || 'Something went wrong');
    ui.alert(dryRun ? 'Fix these before publishing' : 'Not published',
      (dryRun ? '' : 'Nothing has changed for the girls. ') + 'Only Live rows are checked.\n\n' + why + warn, ui.ButtonSet.OK);
  }
}
function publishDiary() { send_(false); }
function checkDiary() { send_(true); }

function pullSuggestions() {
  var ui = SpreadsheetApp.getUi(), out;
  try { out = call_({ action: 'suggestions' }); } catch (e) { ui.alert('Not set up yet', e.message, ui.ButtonSet.OK); return; }
  if (!out.ok) { ui.alert('Couldn\'t get suggestions', out.error || 'Something went wrong', ui.ButtonSet.OK); return; }
  if (!out.rows.length) { ui.alert('No new suggestions', 'Claude hasn\'t suggested anything new since the last pull.', ui.ButtonSet.OK); return; }
  var ss = SpreadsheetApp.getActive(), count = {};
  out.rows.forEach(function (r) {
    var sh = ss.getSheetByName(r.tab);
    if (!sh) return;
    var at = Math.max(sh.getLastRow() + 1, FIRST_ROW_);
    sh.getRange(at, 1, 1, r.cells.length).setValues([r.cells]);
    count[r.tab] = (count[r.tab] || 0) + 1;
  });
  ui.alert('Suggestions added', Object.keys(count).map(function (t) { return count[t] + ' on ' + t; }).join(', ') +
    '.\n\nThey\'re highlighted yellow with Status = Suggested. Change any wording, set Live for the ones you want, then Diary > Publish.', ui.ButtonSet.OK);
}

// ---- building the tabs (only adds tabs that don't exist yet) ----
function setUpTabs() {
  var ss = SpreadsheetApp.getActive(), made = [];
  Object.keys(TABS_).forEach(function (name) {
    if (ss.getSheetByName(name)) return;
    build_(ss.insertSheet(name), TABS_[name]);
    made.push(name);
  });
  if (!ss.getSheetByName('How to use')) { howTo_(ss.insertSheet('How to use')); made.push('How to use'); }
  var blank = ss.getSheetByName('Sheet1');
  if (blank && blank.getLastRow() === 0 && ss.getSheets().length > 1) ss.deleteSheet(blank);
  SpreadsheetApp.getUi().alert(made.length ? 'Added: ' + made.join(', ') : 'All the tabs are already there.');
}

function build_(sh, t) {
  var n = t.cols.length, last = 300;
  sh.setHiddenGridlines(true);
  sh.getRange(1, 1).setValue('ROAD TO FÉILE · ' + t.title).setFontSize(16).setFontWeight('bold').setFontColor(RED_);
  sh.getRange(2, 1).setValue(t.sub).setFontStyle('italic').setFontColor('#555555');
  sh.getRange(HEAD_ROW_, 1, 1, n).setValues([t.cols.map(function (c) { return c[0]; })])
    .setFontWeight('bold').setFontColor(NAVY_).setBackground(GREY_).setVerticalAlignment('middle')
    .setBorder(null, null, true, null, null, null, RED_, SpreadsheetApp.BorderStyle.SOLID_MEDIUM);
  sh.getRange(HEAD_ROW_ + 1, 1, 1, n).setValues([t.cols.map(function (c) { return c[2]; })])
    .setFontSize(9).setFontStyle('italic').setFontColor('#888888').setWrap(true).setVerticalAlignment('top');
  t.cols.forEach(function (c, i) { sh.setColumnWidth(i + 1, c[1] * 7 + 10); });
  var body = sh.getRange(FIRST_ROW_, 1, last - FIRST_ROW_ + 1, n);
  body.setWrap(true).setVerticalAlignment('top');
  var col = function (h) { return t.cols.map(function (c) { return c[0]; }).indexOf(h) + 1; };
  var list = function (h, vals) {
    sh.getRange(FIRST_ROW_, col(h), last - FIRST_ROW_ + 1, 1)
      .setDataValidation(SpreadsheetApp.newDataValidation().requireValueInList(vals, true).setAllowInvalid(false).build());
  };
  list('Status', STATUS_);
  Object.keys(t.lists).forEach(function (h) { list(h, t.lists[h]); });
  t.dates.forEach(function (h) {
    sh.getRange(FIRST_ROW_, col(h), last - FIRST_ROW_ + 1, 1).setNumberFormat('ddd d mmm yy')
      .setDataValidation(SpreadsheetApp.newDataValidation().requireDate().setAllowInvalid(false).build());
  });
  t.times.forEach(function (h) { sh.getRange(FIRST_ROW_, col(h), last - FIRST_ROW_ + 1, 1).setNumberFormat('HH:mm'); });
  var abs = 'A' + FIRST_ROW_ + ':' + String.fromCharCode(64 + n) + last;
  sh.setConditionalFormatRules([
    SpreadsheetApp.newConditionalFormatRule().whenFormulaSatisfied('=$A' + FIRST_ROW_ + '="Suggested"').setBackground('#FFF4CC').setRanges([sh.getRange(abs)]).build(),
    SpreadsheetApp.newConditionalFormatRule().whenFormulaSatisfied('=$A' + FIRST_ROW_ + '="Live"').setBackground('#EAF6EE').setRanges([sh.getRange('A' + FIRST_ROW_ + ':A' + last)]).build(),
    SpreadsheetApp.newConditionalFormatRule().whenFormulaSatisfied('=$A' + FIRST_ROW_ + '="Off"').setFontColor('#9AA0AC').setRanges([sh.getRange(abs)]).build()
  ]);
  sh.getRange(FIRST_ROW_, 1, t.examples.length, n).setValues(t.examples);
  sh.setFrozenRows(HEAD_ROW_ + 1);
  sh.setFrozenColumns(2);
}

function howTo_(sh) {
  var lines = [
    ['How this sheet works', true],
    ['One row per item. Status decides who sees it: Suggested (from Claude, never shown), Live (shown after you publish), Off (draft or no).', false],
    ['When you\'re happy, use Diary > Publish to the girls. Nothing changes on the diary until you publish. Diary > Check for mistakes tests it without publishing.', false],
    ['Events: meetups, socials, fundraisers, gear days, notices. They show in the day\'s timeline and This week with no tick box and no RSVP.', false],
    ['Activities: things the girls do. From/To + Days repeat it (e.g. every Sat in January). "Every day list" puts it in the Every day card instead of the timeline.', false],
    ['Steps: one per line inside the cell (Ctrl+Enter, or Cmd+Enter on a Mac). Write "Step title | how to do it".', false],
    ['Replaces plan = Yes hides the planned run, home session or rest day on those days so the girls aren\'t doubled up.', false],
    ['Notes: a Day note shows in the box under the day title; a Week note shows every day that week.', false],
    ['Claude\'s ideas: Diary > Pull Claude\'s suggestions adds them at the bottom of each tab, yellow, with the reason in Coach notes.', false],
    ['Never here: matches, team training, S&C. Create those in CoachSmart and they appear automatically.', false],
    ['Never put girls\' names in this sheet: the diary is a public page. Coach notes are never sent anywhere.', false]];
  sh.setHiddenGridlines(true);
  sh.setColumnWidth(1, 760);
  lines.forEach(function (l, i) {
    var c = sh.getRange(i + 1, 1).setValue(l[0]).setWrap(true);
    if (l[1]) c.setFontSize(16).setFontWeight('bold').setFontColor(RED_);
  });
}
