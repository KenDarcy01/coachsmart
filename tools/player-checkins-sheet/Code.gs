/**
 * Player check-ins: keeps the Clontarf Girls 2012 team sheet and the CoachSmart
 * check-ins portal (coachsmart.app/clontarf-gaa/feile27/checkins/) in step.
 *
 * Paste into the team sheet: Extensions > Apps Script, replace Code.gs, save.
 * Then Project Settings > Script properties: add PC_SECRET (the same value as the
 * PC_SHEET_SECRET secret on the player-checkins edge function).
 * Reload the sheet: a "Check-ins" menu appears.
 *
 * How the two stay in step (the app is the master copy):
 *  - Sync now: first sends cells changed in the sheet since the last sync to the
 *    app, then writes everything from the app back into the sheet. Assessor
 *    Name/Email always apply. Card text and check-in cells only apply while the
 *    card is still with its coach; once it's with the reviewer or approved, the
 *    app's version wins and the sheet is told which rows were skipped.
 *  - Turn on automatic sync: runs Sync every hour (no pop-ups).
 *  - Player status (Active / Inactive, a dropdown next to Role) always applies.
 *    Only Active girls show on the website and get a family card.
 *  - Help Video (link): put several links in the cell, one per line, for several videos.
 * Tabs: "Team List - Football" and "Team List - Camogie". Headings in row 1,
 * matched by name, so columns can move. Player status, Status and Last updated are added if missing.
 */
var URL_ = 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/player-checkins';
// The public anon key (the same one the website uses). The secret is what lets the sheet in.
var ANON_ = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4';
var TABS_ = { 'Team List - Football': 'football', 'Team List - Camogie': 'camogie' };
var SYNC_TAB_ = '_sync';
var MONTHS_ = { jan: '01', feb: '02', mar: '03', apr: '04', may: '05' };
// Sheet heading (lower case, no spaces at the ends) -> field.
var FIELDS_ = {
  'member name': 'player_name', 'role': 'role', 'assessor name': 'assessor_name', 'assessor email': 'assessor_email',
  'superpower': 'superpower', 'development': 'development', 'how': 'how', 'help video (link)': 'video_url', 'help video': 'video_url',
  'help videos': 'video_url', 'help videos (links)': 'video_url', 'player status': 'player_status',
  'status': 'status', 'last updated': 'updated_at'
};
var SENT_ = ['player_status', 'assessor_name', 'assessor_email', 'superpower', 'development', 'how', 'video_url'];
var PLAYER_STATUS_ = 'Player status';

function onOpen() {
  SpreadsheetApp.getUi().createMenu('Check-ins')
    .addItem('Sync now', 'syncNow')
    .addSeparator()
    .addItem('Turn on automatic sync (hourly)', 'autoOn')
    .addItem('Turn off automatic sync', 'autoOff')
    .addToUi();
}

function syncNow() { var r = sync_(); SpreadsheetApp.getUi().alert('Check-ins', r, SpreadsheetApp.getUi().ButtonSet.OK); }
function syncHourly() { sync_(); }

function autoOn() {
  autoOff();
  ScriptApp.newTrigger('syncHourly').timeBased().everyHours(1).create();
  SpreadsheetApp.getUi().alert('Automatic sync is on. The sheet updates from the app every hour.');
}
function autoOff() {
  ScriptApp.getProjectTriggers().forEach(function (t) { if (t.getHandlerFunction() === 'syncHourly') ScriptApp.deleteTrigger(t); });
}

function sync_() {
  var lock = LockService.getDocumentLock();
  if (!lock.tryLock(30000)) return 'Another sync is running. Try again in a minute.';
  try {
    var ss = SpreadsheetApp.getActive();
    var base = readBase_(ss);
    var push = [];
    var tabs = {};
    Object.keys(TABS_).forEach(function (name) {
      var sh = ss.getSheetByName(name);
      if (!sh) return;
      var t = readTab_(sh, TABS_[name]);
      tabs[name] = t;
      t.rows.forEach(function (r) {
        var key = t.code + '|' + nameKey_(r.player_name);
        var was = base[key];
        var out = { code: t.code, player_name: r.player_name, checks: {} };
        var any = false;
        SENT_.forEach(function (f) {
          if (!(f in r)) return;
          if (!was ? r[f] !== '' : r[f] !== (was[f] || '')) { out[f] = r[f]; any = true; }
        });
        Object.keys(r.checks).forEach(function (d) {
          if (!was ? r.checks[d] !== '' : r.checks[d] !== ((was.checks || {})[d] || '')) { out.checks[d] = r.checks[d]; any = true; }
        });
        if (any || !was) push.push(out);
      });
    });

    var res1 = call_({ action: 'sheet_push', by: Session.getActiveUser().getEmail(), rows: push });
    var res2 = call_({ action: 'sheet_pull' });

    // Write the app's copy back into each tab and remember it as the new baseline.
    var byKey = {};
    res2.rows.forEach(function (r) { byKey[r.code + '|' + nameKey_(r.player_name)] = r; });
    Object.keys(tabs).forEach(function (name) { writeTab_(ss.getSheetByName(name), tabs[name], byKey); });
    writeBase_(ss, res2.rows);

    var msg = ['Synced ' + new Date().toLocaleString() + '.', 'Sent ' + push.length + ' changed rows; ' + res1.created + ' new and ' + res1.updated + ' updated in the app.'];
    if (res1.skipped.length) msg.push('\nNot changed in the app (change these in the app instead):\n- ' + res1.skipped.join('\n- '));
    if (res1.unmatched.length) msg.push('\nNo CoachSmart player with this name, so her family can\'t open the card yet:\n- ' + res1.unmatched.join('\n- '));
    if (res1.flagged.length) msg.push('\nPlease reword (these can\'t go to a family as they are):\n- ' + res1.flagged.join('\n- '));
    return msg.join('\n');
  } catch (e) {
    return 'Sync failed: ' + e.message;
  } finally {
    lock.releaseLock();
  }
}

function call_(body) {
  var secret = PropertiesService.getScriptProperties().getProperty('PC_SECRET');
  if (!secret) throw new Error('Add the PC_SECRET script property first (Extensions > Apps Script > Project Settings).');
  var res = UrlFetchApp.fetch(URL_, {
    method: 'post', contentType: 'application/json', muteHttpExceptions: true,
    headers: { Authorization: 'Bearer ' + ANON_, apikey: ANON_, 'x-pc-secret': secret },
    payload: JSON.stringify(body)
  });
  var j = {};
  try { j = JSON.parse(res.getContentText()); } catch (e) {}
  if (res.getResponseCode() >= 300 || j.error) throw new Error(j.error || ('HTTP ' + res.getResponseCode()));
  return j;
}

// ---- reading and writing a team tab ----
function headMap_(sh) {
  addPlayerStatus_(sh);
  var lastCol = sh.getLastColumn();
  var heads = sh.getRange(1, 1, 1, lastCol).getValues()[0].map(function (h) { return String(h || '').trim(); });
  ['Status', 'Last updated'].forEach(function (h) {
    if (heads.map(function (x) { return x.toLowerCase(); }).indexOf(h.toLowerCase()) < 0) {
      lastCol++;
      sh.getRange(1, lastCol).setValue(h).setFontWeight('bold');
      heads.push(h);
    }
  });
  var map = { fields: {}, checks: {} };
  heads.forEach(function (h, i) {
    var k = h.toLowerCase();
    if (FIELDS_[k]) map.fields[FIELDS_[k]] = i;
    var m = k.match(/^check\s+([a-z]{3})[a-z]*\s+(\d{1,2})$/);
    if (m && MONTHS_[m[1]]) map.checks['2027-' + MONTHS_[m[1]] + '-' + ('0' + m[2]).slice(-2)] = i;
  });
  map.width = heads.length;
  return map;
}

// Adds the "Player status" column (Active / Inactive dropdown) just after Role, once.
// The first sync then fills it from the app.
function addPlayerStatus_(sh) {
  var lastCol = sh.getLastColumn();
  var heads = sh.getRange(1, 1, 1, lastCol).getValues()[0].map(function (h) { return String(h || '').trim().toLowerCase(); });
  var at = heads.indexOf(PLAYER_STATUS_.toLowerCase());
  if (at < 0) {
    var role = heads.indexOf('role');
    var after = role >= 0 ? role + 1 : 1;
    sh.insertColumnAfter(after);
    at = after;
    sh.getRange(1, at + 1).setValue(PLAYER_STATUS_).setFontWeight('bold');
  }
  var n = sh.getLastRow() - 1;
  if (n < 1) return;
  heads = sh.getRange(1, 1, 1, sh.getLastColumn()).getValues()[0].map(function (h) { return String(h || '').trim().toLowerCase(); });
  var roleCol = heads.indexOf('role');
  var rule = SpreadsheetApp.newDataValidation().requireValueInList(['Active', 'Inactive'], true).setAllowInvalid(false).build();
  // Only the player rows get the dropdown; coaches and FLOs below are left alone.
  var roles = roleCol >= 0 ? sh.getRange(2, roleCol + 1, n, 1).getValues() : null;
  sh.getRange(2, at + 1, n, 1).setDataValidations(roles
    ? roles.map(function (r) { return [String(r[0]).trim().toLowerCase() === 'player' ? rule : null]; })
    : Array.apply(null, Array(n)).map(function () { return [rule]; }));
}

function readTab_(sh, code) {
  var map = headMap_(sh);
  var n = sh.getLastRow() - 1;
  var values = n > 0 ? sh.getRange(2, 1, n, map.width).getValues() : [];
  var rows = [];
  values.forEach(function (v, i) {
    var role = map.fields.role != null ? String(v[map.fields.role]).trim().toLowerCase() : 'player';
    var name = String(v[map.fields.player_name] || '').trim();
    if (!name || role !== 'player') return;
    var r = { row: i + 2, player_name: name, checks: {} };
    SENT_.forEach(function (f) { if (map.fields[f] != null) r[f] = String(v[map.fields[f]] || '').trim(); });
    Object.keys(map.checks).forEach(function (d) { r.checks[d] = String(v[map.checks[d]] || '').trim(); });
    rows.push(r);
  });
  return { code: code, map: map, rows: rows };
}

function writeTab_(sh, t, byKey) {
  var n = sh.getLastRow() - 1;
  if (n < 1) return;
  // One column at a time, in one read and one write each, touching only the columns the app owns.
  var cols = {};
  ['player_status', 'superpower', 'development', 'how', 'video_url', 'status', 'updated_at', 'assessor_name', 'assessor_email'].forEach(function (f) {
    if (t.map.fields[f] != null) cols[t.map.fields[f]] = function (a) { return f === 'updated_at' ? (a.updated_at ? new Date(a.updated_at) : '') : (a[f] || ''); };
  });
  Object.keys(t.map.checks).forEach(function (d) { cols[t.map.checks[d]] = function (a) { return (a.checks || {})[d] || ''; }; });
  Object.keys(cols).forEach(function (c) {
    var range = sh.getRange(2, Number(c) + 1, n, 1);
    var vals = range.getValues();
    var changed = false;
    t.rows.forEach(function (r) {
      var a = byKey[t.code + '|' + nameKey_(r.player_name)];
      if (!a) return;
      var v = cols[c](a);
      var cur = vals[r.row - 2][0];
      var same = (v instanceof Date && cur instanceof Date) ? v.getTime() === cur.getTime() : String(cur) === String(v);
      if (!same) { vals[r.row - 2][0] = v; changed = true; }
    });
    if (changed) range.setValues(vals);
  });
}

// ---- the baseline: what the sheet held after the last sync ----
function readBase_(ss) {
  var sh = ss.getSheetByName(SYNC_TAB_);
  var base = {};
  if (!sh || sh.getLastRow() < 1) return base;
  sh.getRange(1, 1, sh.getLastRow(), 2).getValues().forEach(function (v) {
    try { base[v[0]] = JSON.parse(v[1]); } catch (e) {}
  });
  return base;
}

function writeBase_(ss, rows) {
  var sh = ss.getSheetByName(SYNC_TAB_) || ss.insertSheet(SYNC_TAB_);
  sh.hideSheet();
  sh.clear();
  if (!rows.length) return;
  sh.getRange(1, 1, rows.length, 2).setValues(rows.map(function (r) {
    var keep = { checks: r.checks || {} };
    SENT_.forEach(function (f) { keep[f] = r[f] || ''; });
    return [r.code + '|' + nameKey_(r.player_name), JSON.stringify(keep)];
  }));
}

function nameKey_(s) {
  return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[’'`.\-]/g, '')
    .replace(/\s+/g, ' ').trim().toLowerCase();
}
