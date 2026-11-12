#!/usr/bin/env python3
"""Builds the slicker homepage preview. A = asset prefix ('assets/v3/' for the
preview, '/assets/v3/' on the live site), R = root prefix for links."""
import sys
A = sys.argv[1] if len(sys.argv) > 1 else 'assets/v3/'
R = sys.argv[2] if len(sys.argv) > 2 else 'https://coachsmart.app'
LOGO = sys.argv[3] if len(sys.argv) > 3 else 'logo.svg'
LIVE = len(sys.argv) > 4
OUT = sys.argv[4] if LIVE else 'index.html'
HEADX = "<script>if (location.hostname === 'web.coachsmart.app') location.replace('/web/');</script>\n" if LIVE else ''
ICONS = '<link rel="icon" type="image/png" href="/images/CoachSmart%20-%20Black%20Icon.PNG">\n<link rel="apple-touch-icon" href="/images/CoachSmart%20-%20Black%20Icon.PNG">\n' if LIVE else ''
TAIL = '<script src="/cookie-consent.js"></script>\n' if LIVE else ''

APPLE = '<svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor" aria-hidden="true"><path d="M16.37 12.6c-.02-2.3 1.88-3.4 1.96-3.46-1.07-1.56-2.73-1.78-3.32-1.8-1.41-.14-2.76.83-3.48.83-.72 0-1.82-.81-3-.79-1.54.02-2.96.9-3.76 2.28-1.6 2.78-.41 6.9 1.15 9.16.76 1.1 1.67 2.34 2.86 2.3 1.15-.05 1.58-.74 2.97-.74 1.38 0 1.78.74 2.99.72 1.24-.02 2.02-1.12 2.77-2.23.87-1.28 1.23-2.52 1.25-2.58-.03-.01-2.4-.92-2.42-3.66zM14.1 5.86c.63-.77 1.06-1.83.94-2.89-.91.04-2.01.61-2.66 1.37-.58.67-1.1 1.75-.96 2.79 1.01.08 2.05-.52 2.68-1.27z"/></svg>'
PLAY = '<svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><path fill="#34a853" d="M3.6 2.3 13.4 12l-9.8 9.7c-.3-.2-.5-.6-.5-1.1V3.4c0-.5.2-.9.5-1.1z"/><path fill="#fbbc04" d="m17 8.4-3.6 3.6L17 15.6l4-2.3c.8-.5.8-1.7 0-2.2z"/><path fill="#4285f4" d="M3.6 21.7 13.4 12l3.6 3.6-11.6 6.6c-.7.4-1.4.2-1.8-.5z"/><path fill="#ea4335" d="M3.6 2.3c.4-.7 1.1-.9 1.8-.5L17 8.4 13.4 12z"/></svg>'
STORES = (f'<a class="btn store" href="https://apps.apple.com/ie/app/coachsmart/id6747903007" target="_blank" rel="noopener">{APPLE}<span><small>Download on the</small>App Store</span></a>'
          f'<a class="btn light store" href="https://play.google.com/store/apps/details?id=my.coachsmartV2" target="_blank" rel="noopener">{PLAY}<span><small>Get it on</small>Google Play</span></a>')


def img(name, lazy=True, cls='scr'):
    l = ' loading="lazy"' if lazy else ''
    return (f'<img{l} decoding="async" class="{cls}" src="{A}{name}-600.jpg" '
            f'srcset="{A}{name}-600.jpg 600w, {A}{name}.jpg 1179w" sizes="(max-width:900px) 280px, 330px" alt="">')


def phone(name, s=None, lazy=True, extra=''):
    st = f' style="--s:{s}"' if s else ''
    return f'<div class="iphone {extra}"{st}><div class="clip">{img(name, lazy)}<div class="island2"></div></div></div>'


def show(sid, eyebrow, title, lead, items, flip=False):
    """items: (chip label, heading, text, image)"""
    lis = ''.join(
        f'<li><button type="button" data-k="{k}"><span class="n">{k+1:02d}</span><span class="tx"><b>{h}</b><span class="d">{t}</span></span></button></li>'
        for k, (c, h, t, i) in enumerate(items))
    chips = '|'.join(c for c, h, t, i in items)
    imgs = ''.join(img(i) for c, h, t, i in items)
    return f'''
<section id="{sid}" class="band"><div class="wrap">
  <div class="show{' flip' if flip else ''} rv" data-labels="{chips}">
    <div class="copy">
      <div class="eyebrow">{eyebrow}</div>
      <h2>{title}</h2>
      <p class="sub">{lead}</p>
      <div class="chips" role="tablist"></div>
      <ol class="pts">{lis}</ol>
    </div>
    <div class="device">
      <div class="halo"></div>
      <div class="iphone"><div class="clip">{imgs}<div class="island2"></div></div></div>
      <div class="cap"><b></b><span></span></div>
      <div class="dots"></div>
    </div>
  </div>
</div></section>'''


CSS = r'''
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{--g:#87c232;--bg:#0f1215;--app:#14181b;--card:#1e222b;--card2:#252a35;--line:rgba(255,255,255,.08);--text:#f1f4f8;--muted:#a1a1a2;--soft:#c9ced6}
html{scroll-behavior:smooth;-webkit-text-size-adjust:100%;overflow-x:hidden}
body{background:var(--bg);color:var(--text);font-family:'DM Sans',sans-serif;font-size:17px;line-height:1.55;overflow-x:hidden;-webkit-font-smoothing:antialiased}
a{color:inherit;text-decoration:none}
button{font:inherit;color:inherit;background:none;border:0;cursor:pointer;text-align:left}
.wrap{max-width:1160px;margin:0 auto;padding:0 24px}

/* nav */
nav{position:sticky;top:12px;z-index:50;margin:12px auto 0;max-width:1100px;width:calc(100% - 24px);display:flex;align-items:center;justify-content:space-between;padding:9px 10px 9px 18px;border-radius:16px;background:rgba(24,28,35,.72);backdrop-filter:blur(18px) saturate(140%);-webkit-backdrop-filter:blur(18px) saturate(140%);border:1px solid var(--line)}
.logo{display:flex;align-items:center;gap:10px;font-family:'Bebas Neue';font-size:25px;letter-spacing:2px}
.logo img{height:25px}.logo .s{color:var(--g)}
.links{display:flex;gap:26px;font-size:15px;color:var(--soft)}
.links a{transition:color .2s}.links a:hover{color:#fff}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;background:var(--g);color:#10130c;font-weight:700;padding:13px 22px;border-radius:13px;font-size:16px;box-shadow:0 10px 30px rgba(135,194,50,.28);transition:transform .2s,box-shadow .2s}
.btn:hover{transform:translateY(-2px);box-shadow:0 14px 36px rgba(135,194,50,.38)}
.btn.sm{padding:9px 16px;font-size:14px;box-shadow:none}
.btn.light{background:#fff;color:#111;box-shadow:none}
.btn.ghost{background:rgba(255,255,255,.06);color:var(--text);border:1px solid var(--line);box-shadow:none}
.btn.store{text-align:left;line-height:1.1;padding:10px 20px}
.btn.store small{display:block;font-size:11px;font-weight:500;opacity:.8}

/* iPhone frame */
.iphone{--s:.8;position:relative;flex:none;width:calc(390px*var(--s) + 20px);padding:10px;border-radius:calc(56px*var(--s) + 10px);
  background:linear-gradient(145deg,#4a4f57,#22252a 30%,#3a3e45 60%,#1b1d21);box-shadow:0 0 0 1px #0a0b0d,0 40px 80px rgba(0,0,0,.6),inset 0 0 0 1.5px rgba(255,255,255,.12)}
.iphone::before{content:"";position:absolute;left:-3px;top:22%;width:3px;height:9%;border-radius:2px 0 0 2px;background:#2b2e33;box-shadow:0 calc(90px*var(--s)) 0 #2b2e33}
.iphone::after{content:"";position:absolute;right:-3px;top:28%;width:3px;height:14%;border-radius:0 2px 2px 0;background:#2b2e33}
.iphone .clip{width:calc(390px*var(--s));height:calc(845px*var(--s));border-radius:calc(48px*var(--s));overflow:hidden;background:var(--app);position:relative}
.iphone .clip img.scr{display:block;width:100%;height:100%;object-fit:cover;object-position:top}
.island2{position:absolute;top:calc(11px*var(--s));left:50%;transform:translateX(-50%);width:calc(112px*var(--s));height:calc(33px*var(--s));border-radius:99px;background:#000;z-index:3}

/* hero */
.hero{text-align:center;padding:72px 0 0;position:relative;overflow:hidden}
.hero::before{content:"";position:absolute;left:50%;top:330px;width:1100px;height:760px;transform:translateX(-50%);background:radial-gradient(closest-side,rgba(135,194,50,.24),transparent);filter:blur(20px);z-index:-1}
.hero::after{content:"";position:absolute;inset:0;z-index:-2;background-image:linear-gradient(rgba(255,255,255,.035) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.035) 1px,transparent 1px);background-size:56px 56px;-webkit-mask-image:radial-gradient(ellipse 70% 55% at 50% 30%,#000,transparent);mask-image:radial-gradient(ellipse 70% 55% at 50% 30%,#000,transparent)}
.tagpill{display:inline-flex;gap:10px;align-items:center;padding:6px 6px 6px 14px;border-radius:999px;background:rgba(255,255,255,.05);border:1px solid var(--line);font-size:14px;color:var(--soft)}
.tagpill b{background:var(--g);color:#111;border-radius:999px;padding:3px 10px;font-size:12px}
h1{font-size:clamp(40px,6.2vw,80px);line-height:1.02;font-weight:700;letter-spacing:-.035em;margin:22px auto 20px;max-width:1100px}
h1 span{background:linear-gradient(90deg,#87c232,#d8f59b);-webkit-background-clip:text;background-clip:text;color:transparent}
.lead{color:var(--soft);font-size:clamp(17px,1.6vw,20px);max-width:640px;margin:0 auto}
.cta{display:flex;gap:12px;justify-content:center;margin-top:30px;flex-wrap:wrap}
.proof{display:flex;gap:8px 22px;justify-content:center;flex-wrap:wrap;margin-top:22px;color:var(--muted);font-size:14.5px}
.proof span::before{content:"✓";color:var(--g);font-weight:800;margin-right:7px}
.stage{position:relative;height:640px;margin:56px -24px 0;overflow:hidden}
.stage .iphone{position:absolute;left:50%;top:0}
.stage .ph-c{--s:.86;transform:translateX(-50%);z-index:3}
.stage .ph-l{--s:.72;transform:translateX(calc(-50% - 320px));top:92px;opacity:.9}
.stage .ph-r{--s:.72;transform:translateX(calc(-50% + 320px));top:92px;opacity:.9}
.float{position:absolute;left:50%;z-index:4;background:rgba(26,30,38,.86);backdrop-filter:blur(14px);-webkit-backdrop-filter:blur(14px);border:1px solid rgba(255,255,255,.12);border-radius:16px;padding:11px 16px;text-align:left;font-size:14px;box-shadow:0 20px 40px rgba(0,0,0,.5);animation:bob 6s ease-in-out infinite}
.float small{display:block;color:var(--muted);font-size:12px}
.float b{font-size:16px}.float .g{color:var(--g)}
.float.f1{transform:translateX(-560px);top:60px}
.float.f2{transform:translateX(330px);top:20px;animation-delay:-2s}
.float.f3{transform:translateX(380px);top:420px;animation-delay:-4s}
@keyframes bob{50%{margin-top:-10px}}
.fade{position:absolute;left:0;right:0;bottom:0;height:200px;background:linear-gradient(transparent,var(--bg));z-index:5;pointer-events:none}
.codes{display:flex;justify-content:center;gap:10px 14px;flex-wrap:wrap;position:relative;z-index:6;margin-top:6px;padding-bottom:10px}
.codes span{font-weight:700;letter-spacing:1.5px;font-size:12.5px;color:#aeb4bd;padding:7px 14px;border-radius:999px;border:1px solid var(--line);background:rgba(20,24,27,.8)}

/* sections */
section{padding:96px 0}
section.band{padding:84px 0;overflow:hidden}
.head{text-align:center;max-width:760px;margin:0 auto 46px}
.eyebrow{color:var(--g);font-weight:700;font-size:13.5px;letter-spacing:2px;text-transform:uppercase}
h2{font-size:clamp(32px,4.2vw,54px);line-height:1.04;letter-spacing:-.03em;margin:10px 0 14px}
.head p,.sub{color:var(--soft);font-size:18.5px}

/* showcase */
.show{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:72px;align-items:center}
.show.flip .copy{order:2}.show.flip .device{order:1}
.show .copy{max-width:540px}
.show.flip .copy{justify-self:end}
.pts{list-style:none;margin-top:26px;display:grid;gap:4px}
.pts button{display:flex;gap:16px;width:100%;padding:13px 16px;border-radius:16px;border:1px solid transparent;position:relative;overflow:hidden;transition:background .25s,border-color .25s}
.pts .n{font-family:'Bebas Neue';font-size:20px;line-height:1.35;color:#5d646f;transition:color .25s;width:22px;flex:none}
.pts b{display:block;font-size:18px;color:#aab0b9;transition:color .25s;font-weight:600}
.pts .d{display:block;color:var(--soft);font-size:15.5px;max-height:0;opacity:0;overflow:hidden;transition:max-height .4s ease,opacity .3s,margin .3s}
.pts button:hover b{color:#fff}
.pts button.on{background:linear-gradient(180deg,#20252e,#1a1e25);border-color:var(--line)}
.pts button.on .n{color:var(--g)}.pts button.on b{color:#fff}
.pts button.on .d{max-height:120px;opacity:1;margin-top:4px}
.pts button.on::after{content:"";position:absolute;left:0;bottom:0;height:2px;width:100%;background:var(--g);transform-origin:left;transform:scaleX(0)}
.pts button.on.run::after{animation:fill var(--dur,5s) linear forwards}
@keyframes fill{to{transform:scaleX(1)}}
.device{position:relative;display:flex;flex-direction:column;align-items:center}
.halo{position:absolute;left:50%;top:50%;width:560px;height:560px;transform:translate(-50%,-50%);background:radial-gradient(closest-side,rgba(135,194,50,.22),transparent);z-index:-1;pointer-events:none}
.show .iphone{--s:.82}
.show .clip{touch-action:pan-y;cursor:grab}
.show .clip img.scr{position:absolute;inset:0;opacity:0;transform:scale(1.03);transition:opacity .5s ease,transform .6s ease}
.show .clip img.scr.on{opacity:1;transform:none}
.chips,.cap,.dots{display:none}

/* cards */
.grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:16px}
.card{position:relative;overflow:hidden;border-radius:24px;background:linear-gradient(180deg,#1f242d,#181c23);border:1px solid var(--line);padding:28px;transition:border-color .3s,transform .3s}
.card:hover{border-color:rgba(135,194,50,.35);transform:translateY(-3px)}
.card h3{font-size:22px;letter-spacing:-.4px;line-height:1.15}
.card p{color:var(--soft);font-size:15.5px;margin-top:8px}
.tg{display:inline-block;font-size:11.5px;font-weight:700;color:var(--g);background:rgba(135,194,50,.12);border:1px solid rgba(135,194,50,.3);padding:3px 10px;border-radius:999px;margin-bottom:12px;letter-spacing:.6px}
.feed{margin-top:18px;display:grid;gap:8px}
.feed div{display:flex;justify-content:space-between;align-items:center;background:#12161a;border:1px solid var(--line);border-radius:12px;padding:10px 14px;font-size:14.5px}
.feed em{font-style:normal;font-size:12px;font-weight:700;padding:3px 9px;border-radius:999px;background:rgba(135,194,50,.18);color:var(--g)}
.feed em.r{background:rgba(217,56,56,.2);color:#ff8a8a}.feed em.w{background:rgba(255,255,255,.08);color:#c9ced6}
.big{font-family:'Bebas Neue';font-size:56px;line-height:1;color:var(--g);margin-top:16px}
.big span{color:#5d646f}
.notif{text-align:left;margin-top:18px;background:#262b34;border-radius:18px;padding:12px 14px;font-size:14px;color:#dfe3e8}
.notif .hd{display:flex;align-items:center;gap:8px;font-size:12px;color:#aeb4bd;letter-spacing:.3px}
.notif .hd i{width:22px;height:22px;border-radius:6px;background:var(--g);display:grid;place-items:center}
.notif .hd i img{width:16px;filter:brightness(0)}
.notif .hd span{margin-left:auto}
.notif b{display:block;margin-top:6px;font-size:15px;color:#fff}
.pdf{min-height:440px}
.pdf .txt{max-width:330px;position:relative;z-index:2}
.paper{position:absolute;border-radius:10px;overflow:hidden;box-shadow:0 30px 60px rgba(0,0,0,.6);background:#fff;transition:transform .5s ease}
.paper img{display:block;width:100%}
.paper.p1{width:300px;right:150px;top:44px;transform:rotate(-4deg)}
.paper.p2{width:250px;right:28px;top:150px;transform:rotate(5deg)}
.pdf:hover .p1{transform:rotate(-6deg) translate(-8px,-6px)}.pdf:hover .p2{transform:rotate(7deg) translate(8px,4px)}
.quote{background:#0f1215;border:1px solid var(--line);border-radius:18px;padding:16px 20px;font-size:16.5px;margin-top:12px}
.quote::before{display:block;font-size:12px;margin-bottom:4px}
.quote.me::before{content:"You said";color:var(--muted)}
.quote.cs{border-color:rgba(135,194,50,.4)}
.quote.cs::before{content:"CoachSmart";color:var(--g);font-weight:700}
.lockrow{display:grid;grid-template-columns:auto 1fr;gap:28px;align-items:center}
.lockrow .iphone{--s:.5;margin-bottom:-150px}

.ai{border-radius:32px;padding:56px;background:linear-gradient(135deg,#243315,#1a1e25 55%);border:1px solid rgba(135,194,50,.3);display:grid;grid-template-columns:1fr 1fr;gap:40px;align-items:center}
.roles{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}
.role{border-radius:24px;padding:30px;background:var(--card);border:1px solid var(--line)}
.role .ic{width:46px;height:46px;border-radius:14px;display:grid;place-items:center;background:rgba(135,194,50,.15);font-size:22px}
.role h3{margin:18px 0 6px;font-size:22px}
.role ul{list-style:none;color:var(--soft);font-size:15.5px;display:grid;gap:8px;margin-top:12px}
.role li::before{content:"✓  ";color:var(--g);font-weight:800}
.steps{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;counter-reset:s}
.step{background:var(--card);border:1px solid var(--line);border-radius:20px;padding:24px;position:relative}
.step b{font-family:'Bebas Neue';font-size:44px;color:var(--g);font-weight:400;line-height:1}
.step h4{font-size:18px;margin:8px 0 4px}
.step p{color:var(--soft);font-size:15px}
.final{text-align:center;padding:90px 24px;margin:0 auto 70px;max-width:1112px;border-radius:36px;background:radial-gradient(700px 320px at 50% 115%,rgba(135,194,50,.34),transparent),linear-gradient(180deg,#1f242d,#161a20);border:1px solid rgba(135,194,50,.25)}
.final p{color:var(--soft);font-size:18.5px}
footer{border-top:1px solid var(--line);padding:28px 0;color:var(--muted);font-size:14px}
footer .wrap{display:flex;justify-content:space-between;gap:20px;flex-wrap:wrap}
.flinks{display:flex;gap:18px;flex-wrap:wrap}.flinks a:hover{color:var(--g)}

/* reveal */
.rv{opacity:0;transform:translateY(26px);transition:opacity .7s ease,transform .7s ease}
.rv.in{opacity:1;transform:none}
@media (prefers-reduced-motion:reduce){.rv{opacity:1;transform:none;transition:none}.float{animation:none}.show .clip img.scr{transition:none}html{scroll-behavior:auto}}

@media (max-width:900px){
 .links{display:none}
 .hero{padding-top:48px}
 .stage{height:520px;margin-top:40px}
 .stage .ph-c{--s:.72}
 .stage .ph-l{--s:.58;transform:translateX(calc(-50% - 190px));top:70px;opacity:.55}
 .stage .ph-r{--s:.58;transform:translateX(calc(-50% + 190px));top:70px;opacity:.55}
 .float{display:none}
 section{padding:64px 0}section.band{padding:56px 0}
 .show,.show.flip{display:block;text-align:center}
 .show .copy,.show.flip .copy{max-width:none;justify-self:auto}
 .pts{display:none}
 .chips{display:flex;gap:8px;overflow-x:auto;margin:22px -24px 0;padding:2px 24px 6px;scrollbar-width:none;-webkit-overflow-scrolling:touch}
 .chips::-webkit-scrollbar{display:none}
 .chips button{flex:none;position:relative;overflow:hidden;font-weight:600;font-size:14px;color:var(--soft);background:rgba(255,255,255,.05);border:1px solid var(--line);border-radius:999px;padding:8px 15px;text-align:center}
 .chips button.on{color:#fff;border-color:rgba(135,194,50,.6);background:rgba(135,194,50,.14)}
 .chips button.on::after{content:"";position:absolute;left:0;bottom:0;height:2px;width:100%;background:var(--g);transform-origin:left;transform:scaleX(0)}
 .chips button.on.run::after{animation:fill var(--dur,5s) linear forwards}
 .device{margin-top:22px}
 .show .iphone{--s:.7}
 .halo{width:420px;height:420px}
 .cap{display:block;min-height:104px;margin-top:20px;max-width:420px;padding:0 4px}
 .cap b{display:block;font-size:19px}
 .cap span{display:block;color:var(--soft);font-size:15.5px;margin-top:4px}
 .dots{display:flex;gap:6px;margin-top:6px;justify-content:center}
 .dots i{width:6px;height:6px;border-radius:50%;background:#3a404b;transition:background .3s,width .3s}
 .dots i.on{background:var(--g);width:18px;border-radius:3px}
 .grid3,.grid2,.roles,.ai{grid-template-columns:1fr}
 .ai{padding:28px}
 .steps{grid-template-columns:1fr 1fr}
 .pdf{min-height:0}
 .pdf .txt{max-width:none}
 .paper{position:relative!important;right:auto!important;top:auto!important}
 .papers{display:flex;justify-content:center;margin:26px 0 -70px}
 .paper.p1{width:56%;margin-right:-10%}.paper.p2{width:46%;margin-top:60px}
 .lockrow{grid-template-columns:1fr}.lockrow .iphone{order:2;margin:6px auto -150px}
 .final{margin:0 16px 50px;padding:64px 20px;border-radius:28px}
}
'''

JS = r'''
(function(){
  var still=window.matchMedia('(prefers-reduced-motion: reduce)').matches, DUR=5000;
  document.querySelectorAll('.show').forEach(function(w){
    var imgs=[].slice.call(w.querySelectorAll('img.scr')), pts=[].slice.call(w.querySelectorAll('.pts button'));
    var chipsEl=w.querySelector('.chips'), dotsEl=w.querySelector('.dots'), cap=w.querySelector('.cap');
    var labels=w.getAttribute('data-labels').split('|'), i=0, timer=null, auto=!still, seen=false;
    var chips=labels.map(function(t,k){var b=document.createElement('button');b.type='button';b.textContent=t;
      b.addEventListener('click',function(){auto=false;go(k)});chipsEl.appendChild(b);
      dotsEl.appendChild(document.createElement('i'));return b});
    var dots=[].slice.call(dotsEl.children);
    pts.forEach(function(b,k){b.addEventListener('click',function(){auto=false;go(k)})});
    function go(k){
      k=(k+imgs.length)%imgs.length;i=k;clearTimeout(timer);
      imgs.forEach(function(im,n){im.classList.toggle('on',n===k)});
      [pts,chips].forEach(function(set){set.forEach(function(b,n){b.classList.remove('run');b.classList.toggle('on',n===k)})});
      dots.forEach(function(d,n){d.classList.toggle('on',n===k)});
      cap.firstChild.textContent=pts[k].querySelector('b').textContent;
      cap.lastChild.textContent=pts[k].querySelector('.d').textContent;
      var c=chips[k];
      if(c.offsetParent&&seen){chipsEl.scrollTo({left:c.offsetLeft-chipsEl.offsetLeft-(chipsEl.clientWidth-c.clientWidth)/2,behavior:still?'auto':'smooth'})}
      if(auto&&seen){[pts[k],c].forEach(function(b){void b.offsetWidth;b.style.setProperty('--dur',DUR+'ms');b.classList.add('run')});
        timer=setTimeout(function(){go(i+1)},DUR)}
    }
    var clip=w.querySelector('.clip'), x0=null;
    clip.addEventListener('pointerdown',function(e){x0=e.clientX});
    clip.addEventListener('pointerup',function(e){if(x0===null)return;var dx=e.clientX-x0;x0=null;auto=false;
      go(i+(Math.abs(dx)>30&&dx>0?-1:1))});
    clip.addEventListener('pointercancel',function(){x0=null});
    if('IntersectionObserver' in window){
      new IntersectionObserver(function(es){es.forEach(function(e){seen=e.isIntersecting;if(seen)go(i);else clearTimeout(timer)})},{threshold:.35}).observe(w.querySelector('.device'));
    } else {seen=true}
    go(0);
  });
  var rv=document.querySelectorAll('.rv');
  if(still||!('IntersectionObserver' in window)){rv.forEach(function(e){e.classList.add('in')})}
  else{var io=new IntersectionObserver(function(es){es.forEach(function(e){if(e.isIntersecting){e.target.classList.add('in');io.unobserve(e.target)}})},{threshold:.12,rootMargin:'0px 0px -40px 0px'});
    rv.forEach(function(e){io.observe(e)})}
})();
'''

attendance = show('attendance', 'Attendance first', 'No more WhatsApp polls',
    "Every training and match gets one-tap replies, live numbers and automatic reminders, so you know who's coming before you pack the cones.", [
    ('Your week', 'Your week on one timeline', 'Every training and match from all your teams in one list. Reply straight from the card.', 'home'),
    ('One-tap reply', 'Reply in one tap', 'Players and parents tap Going or Not going. Meet time, venue and notes sit right underneath.', 'event-match'),
    ("Who's coming", "See who's coming", "Who's going, who isn't and who hasn't replied, split by squad and ready to pick from.", 'attending'),
    ('Team trends', 'Every team, all season', 'Attendance and reply rates for each team, set against this time last year.', 'an-teams'),
    ('Player record', "Every player's record", 'Training and matches by code, and the last ten events at a glance. Spot the ones drifting away.', 'player'),
    ('Fair game time', "See who's being picked", "Every squad place across the season. Find the player who hasn't had a game yet, before their parents do.", 'an-squads'),
])

plan = show('smart', 'Then the smart stuff', 'Session plans that write themselves',
    'Once you know who\'s coming, CoachSmart plans the session around them. Pick your drills, set the length, and change anything just by saying it.', [
    ('Build', 'Build from your favourites', 'Choose the drills you like, set the length and say what you want to work on.', 'plan-build'),
    ('Your plan', 'A full plan in seconds', 'Timings, numbers and the weather checked, laid out for the players who said yes.', 'plan-view'),
    ('Every drill', 'Every drill written up', 'Setup, how to play, coaching points and a way to make it harder. Tap any line to edit it.', 'plan-drills'),
    ('By voice', 'Change it by voice', 'Hold the mic and say what you want changed. The plan updates itself.', 'plan-voice'),
    ('Drill library', "Your club's drill library", 'Warm-ups, drills and games by age and code. Save your favourites and add them to a plan.', 'fav'),
    ('Drill card', 'Diagrams for every drill', 'Each one has a clear diagram, setup and coaching points, and a printable card.', 'gdetail'),
    ('Add your own', 'Add your own drills', 'Take a photo, sketch it or just describe it. CoachSmart writes it up and draws the diagram.', 'add-drill'),
], flip=True)

match = show('matchday', 'Matchday', 'Keep the score. Share it live.',
    'The clock runs and you keep the score by tap or by voice. The moment you start, the match goes live for the whole club.', [
    ('Tap', 'Score keeper', 'A running clock for each half and big buttons for goals, points and wides. Works with no signal.', 'sk-tap'),
    ('Voice', 'Or just say it', 'Hold the mic and say "Point, Cian". No typing on the sideline.', 'sk-voice'),
    ('Full time', 'Full-time check', "At the whistle it checks the score against the ref's, then the stats are ready to share.", 'sk-ft'),
    ('Live', 'Follow the match live', "Parents and anyone who couldn't make it watch the clock, the score and every scorer as it happens.", 'lm-live'),
    ('Stats', "Who's ahead, and when", 'A live chart of the lead through the game, plus a full timeline of every score.', 'lm-stats'),
    ('Alerts', 'Alerts your way', 'Every score, goals only, or just half time and full time. Tap the bell to choose.', 'lm-alerts'),
    ('All matches', 'Every match in the club', "What's live now, what's coming up today and the results, in one list.", 'lm-matches'),
])

HTML = f'''<!DOCTYPE html>
<html lang="en">
<head>
{HEADX}<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="description" content="CoachSmart is the coaching app for attendance, session plans, team selection, score keeping and match reports. Built around GAA, ready for any team sport. Free on iPhone and Android.">
{ICONS}<title>CoachSmart · Coaching Made Simple</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Bebas+Neue&family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,600;9..40,700&display=swap" rel="stylesheet">
<style>{CSS}</style>
</head>
<body>

<nav>
  <a class="logo" href="{R}/"><img src="{LOGO}" alt="">COACH<span class="s">SMART</span></a>
  <div class="links"><a href="#attendance">Attendance</a><a href="#smart">Session plans</a><a href="#matchday">Matchday</a><a href="#club">For clubs</a><a href="{R}/help/">Help</a></div>
  <a class="btn sm" href="#download">Get the app</a>
</nav>

<header class="hero"><div class="wrap">
  <a class="tagpill" href="#download">GAA first. Ready for any sport <b>Free →</b></a>
  <h1>Know who's coming.<br><span>Every session, every match.</span></h1>
  <p class="lead">Players reply in one tap, you see the numbers straight away, and reminders chase the rest. Then plan the session, pick the team and keep the score, all in one app.</p>
  <div class="cta">{STORES}</div>
  <div class="proof"><span>Free to download</span><span>iPhone and Android</span><span>Set up in minutes</span></div>
  <div class="stage">
    {phone('event-match', lazy=False, extra='ph-l')}
    {phone('home', lazy=False, extra='ph-c')}
    {phone('an-teams', lazy=False, extra='ph-r')}
    <div class="float f1"><small>Reminder sent</small><b>9 haven't replied yet</b></div>
    <div class="float f2"><small>Tonight's training</small><b><span class="g">24</span> going · 5 to reply</b></div>
    <div class="float f3"><small>Coach alert</small><b><span class="g">✓</span> Aoife accepted</b></div>
    <div class="fade"></div>
  </div>
  <div class="codes"><span>FOOTBALL</span><span>HURLING</span><span>CAMOGIE</span><span>LADIES FOOTBALL</span><span>RUGBY</span><span>SOCCER</span><span>NURSERY TO ADULT</span></div>
</div></header>
{attendance}

<section style="padding-top:0"><div class="wrap">
  <div class="grid3">
    <div class="card rv">
      <span class="tg">LIVE</span>
      <h3>Replies as they happen</h3>
      <p>Watch the numbers change in the hour before training.</p>
      <div class="feed">
        <div>Aoife B. <em>Going</em></div>
        <div>Rory K. <em class="r">Injured</em></div>
        <div>Ciara N. <em>Going</em></div>
        <div>Liam C. <em class="w">Reminded</em></div>
      </div>
      <div class="big">24 <span>/ 31</span></div>
      <p>going so far</p>
    </div>
    <div class="card rv" style="transition-delay:.08s">
      <span class="tg">AUTOMATIC</span>
      <h3>Reminders and alerts</h3>
      <p>Anyone who hasn't replied gets a reminder, and coaches are told when someone changes their mind.</p>
      <div class="notif"><div class="hd"><i><img src="{LOGO}" alt=""></i>COACHSMART<span>now</span></div><b>Ardcairn Girls 2017</b>Attendance responses needed for Aoife and Seán — Camogie Training</div>
      <div class="notif"><div class="hd"><i><img src="{LOGO}" alt=""></i>COACHSMART<span>2h ago</span></div><b>Ardcairn Boys 2014: Change of Attendance</b>Ciara Nolan has changed their attendance from accepted to declined for Football Training on Thu 12 Nov, 18:30</div>
    </div>
    <div class="card rv" style="transition-delay:.16s">
      <span class="tg">FAMILIES</span>
      <h3>All your teams, one list</h3>
      <p>Coach two teams, or have kids in three? Every event from every club and team in one place.</p>
      <div class="feed"><div>Ardcairn Boys 2014 <em>Thu 18:30</em></div><div>Ardcairn Girls 2017 <em>Fri 17:00</em></div><div>Ardcairn Boys 2014 <em>Sat 10:30</em></div></div>
      <h3 style="margin-top:26px">Everything for the day</h3>
      <p>Where, when to meet and who you're playing, with directions in one tap.</p>
    </div>
  </div>
</div></section>
{plan}

<section style="padding-top:0"><div class="wrap">
  <div class="card pdf rv">
    <div class="txt">
      <span class="tg">PRINT-READY</span>
      <h3>In your club's colours</h3>
      <p>Session plans and drill cards as PDFs with your crest, timings and diagrams. Share them with the other coaches or print them for the clubhouse.</p>
    </div>
    <div class="papers">
      <div class="paper p1"><img loading="lazy" decoding="async" src="{A}plan-pdf-600.jpg" alt=""></div>
      <div class="paper p2"><img loading="lazy" decoding="async" src="{A}game-card.jpg" alt=""></div>
    </div>
  </div>
</div></section>
{match}

<section style="padding-top:0"><div class="wrap">
  <div class="grid2">
    <div class="card rv" style="overflow:hidden">
      <div class="lockrow">
        {phone('lm-lock')}
        <div>
          <span class="tg">ON THE LOCK SCREEN</span>
          <h3>Never miss a score</h3>
          <p>Followers get each score as it happens, with the scorer's name when the coach gives one. Share a link with family outside the club too.</p>
        </div>
      </div>
    </div>
    <div class="card rv" style="transition-delay:.08s">
      <span class="tg">AI</span>
      <h3>Match reports in your own words</h3>
      <p>Talk through the game on the drive home. CoachSmart tidies it into a report and keeps how you said it.</p>
      <div class="quote me">"Slow start, two points down at the water break, but the subs gave us legs and Ciara's goal settled it."</div>
      <div class="quote cs">After a slow start we were two points down at the water break. The subs brought fresh legs and Ciara Nolan's goal settled it in the second half.</div>
    </div>
  </div>
</div></section>

<section style="padding-top:0"><div class="wrap">
  <div class="ai rv">
    <div>
      <div class="eyebrow">Speaks coach</div>
      <h2>Talk to it like you'd talk to your selector</h2>
      <p class="sub">Every mic in CoachSmart works the same way: hold, speak, check the words, done. It understands GAA terms, keeps your own words and never makes you fill in a form on the sideline.</p>
    </div>
    <div>
      <div class="quote me">"Make the warm-up fifteen minutes and take out the cool-down."</div>
      <div class="quote cs">Plan updated. Warm-up is now 15 minutes and the cool-down is removed.</div>
      <div class="quote me">"Point, Cian."</div>
      <div class="quote cs">Ardcairn 1-07. Point for Cian Brennan at 25'.</div>
    </div>
  </div>
</div></section>

<section id="club"><div class="wrap">
  <div class="head rv"><div class="eyebrow">For the whole club</div><h2>One app, three jobs</h2></div>
  <div class="roles">
    <div class="role rv"><div class="ic">📋</div><h3>Coaches</h3><ul><li>Attendance for every session</li><li>Session plans, drills and team selection</li><li>Score keeper and match reports</li></ul></div>
    <div class="role rv" style="transition-delay:.08s"><div class="ic">👪</div><h3>Players &amp; parents</h3><ul><li>Reply to events in one tap</li><li>Reminders before every event</li><li>Follow the match live</li></ul></div>
    <div class="role rv" style="transition-delay:.16s"><div class="ic">🏟</div><h3>Club officers</h3><ul><li>Attendance across every team</li><li>Shared plan and drill library</li><li>Your crest and colours on every PDF</li></ul></div>
  </div>
</div></section>

<section id="start" style="padding-top:0"><div class="wrap">
  <div class="head rv"><div class="eyebrow">Get started</div><h2>Up and running in minutes</h2></div>
  <div class="steps">
    <div class="step rv"><b>1</b><h4>Download</h4><p>Free on the App Store and Google Play.</p></div>
    <div class="step rv" style="transition-delay:.06s"><b>2</b><h4>Add your team</h4><p>Invite players and parents with a team code.</p></div>
    <div class="step rv" style="transition-delay:.12s"><b>3</b><h4>Add your sessions</h4><p>Set up training once for the season.</p></div>
    <div class="step rv" style="transition-delay:.18s"><b>4</b><h4>Know who's coming</h4><p>Replies come in, reminders do the chasing.</p></div>
  </div>
</div></section>

<div class="final rv" id="download">
  <h2>Ready for your next session?</h2>
  <p>Free to download. Built around GAA and ready for any team sport.</p>
  <div class="cta">{STORES}</div>
</div>
<footer><div class="wrap"><span>© 2026 CoachSmart · Coaching Made Simple</span><span class="flinks"><a href="{R}/privacy.html">Privacy</a><a href="{R}/terms.html">Terms</a><a href="{R}/data-deletion.html">Data deletion</a><a href="{R}/help/">Help</a><a href="{R}/contact.html">Contact</a></span></div></footer>

<script>{JS}</script>
{TAIL}</body>
</html>
'''
open(OUT, 'w').write(HTML)
print(len(HTML))
