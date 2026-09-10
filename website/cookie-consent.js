(function () {
  var STORAGE_KEY = 'cs_cookie_consent';

  // Already decided — do nothing
  if (localStorage.getItem(STORAGE_KEY)) return;

  var banner = document.createElement('div');
  banner.id = 'cs-cookie-banner';
  banner.innerHTML =
    '<div class="cs-cc-inner">' +
      '<p class="cs-cc-text">' +
        'We use essential cookies to keep the site working and, where you\'ve given consent, ' +
        'Firebase may collect anonymised analytics to help us improve CoachSmart. ' +
        'For full details see our <a href="/privacy.html">Privacy Policy</a>.' +
      '</p>' +
      '<div class="cs-cc-btns">' +
        '<button id="cs-cc-reject">Reject non-essential</button>' +
        '<button id="cs-cc-accept">Accept all</button>' +
      '</div>' +
    '</div>';

  var style = document.createElement('style');
  style.textContent =
    '#cs-cookie-banner{' +
      'position:fixed;bottom:0;left:0;right:0;z-index:9999;' +
      'background:#1E222B;border-top:1px solid #2e3441;' +
      'padding:16px 5%;font-family:"DM Sans",sans-serif;font-size:14px;color:#c2cad4;' +
    '}' +
    '.cs-cc-inner{' +
      'max-width:960px;margin:0 auto;display:flex;align-items:center;' +
      'gap:24px;flex-wrap:wrap;' +
    '}' +
    '.cs-cc-text{flex:1;min-width:240px;line-height:1.5;}' +
    '.cs-cc-text a{color:#87C232;text-decoration:underline;}' +
    '.cs-cc-btns{display:flex;gap:10px;flex-shrink:0;}' +
    '#cs-cc-reject{' +
      'padding:9px 18px;border-radius:6px;border:1px solid #2e3441;' +
      'background:transparent;color:#c2cad4;cursor:pointer;font-size:13px;white-space:nowrap;' +
    '}' +
    '#cs-cc-reject:hover{border-color:#8a93a0;}' +
    '#cs-cc-accept{' +
      'padding:9px 18px;border-radius:6px;border:none;' +
      'background:#87C232;color:#15181f;cursor:pointer;font-weight:600;font-size:13px;white-space:nowrap;' +
    '}' +
    '#cs-cc-accept:hover{background:#9ad93e;}' +
    '@media(max-width:600px){' +
      '.cs-cc-inner{flex-direction:column;gap:14px;}' +
      '.cs-cc-btns{width:100%;}' +
      '#cs-cc-reject,#cs-cc-accept{flex:1;text-align:center;}' +
    '}';

  document.head.appendChild(style);
  document.body.appendChild(banner);

  function dismiss(choice) {
    localStorage.setItem(STORAGE_KEY, choice);
    banner.style.transition = 'opacity 0.3s';
    banner.style.opacity = '0';
    setTimeout(function () { banner.remove(); }, 300);
  }

  document.getElementById('cs-cc-accept').addEventListener('click', function () {
    dismiss('accepted');
  });
  document.getElementById('cs-cc-reject').addEventListener('click', function () {
    dismiss('rejected');
  });
})();
