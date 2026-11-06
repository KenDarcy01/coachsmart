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
  SpreadsheetApp.getUi().createMenu('Diary').addItem('Publish to players', 'publishDiary').addToUi();
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
