/* CoachSmart: read a Word (.docx) or PowerPoint (.pptx) file in the browser.
 *
 * CSDocExtract.read(file) -> { kind: 'docx'|'pptx'|'pdf', text, pictures: [{ base64, mimeType, name }], pdfBase64? }
 *
 * text is the document in reading order with markers the import AI understands:
 *   [PICTURE n]          where picture n (0-based, in pictures[]) sits
 *   [LINK text -> url]   a hyperlink
 *   === SLIDE n ===      start of a slide (PowerPoint)
 *   SHAPES: ...          the drawn shapes on a slide, on a 0-1000 grid over the slide
 *                        (x right, y down), so the AI can read a drill drawn with shapes.
 * PDFs are passed through whole (the AI reads them directly).
 *
 * Unzipping is done here, not on the server, to keep the server inside its CPU limit.
 */
(function () {
  'use strict';

  const FFLATE = 'https://cdn.jsdelivr.net/npm/fflate@0.8.2/umd/index.js';
  const MAX_PICTURES = 20;
  const MAX_PICTURE_BYTES = 3.5 * 1024 * 1024;
  const IMG_TYPES = { png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif', webp: 'image/webp' };

  let _fflate = null;
  function loadFflate() {
    if (window.fflate) return Promise.resolve(window.fflate);
    if (_fflate) return _fflate;
    _fflate = new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = FFLATE;
      s.onload = () => window.fflate ? resolve(window.fflate) : reject(new Error('Could not load the unzip library'));
      s.onerror = () => reject(new Error('Could not load the unzip library (check your connection)'));
      document.head.appendChild(s);
    });
    return _fflate;
  }

  const readBuf = file => new Promise((res, rej) => {
    const r = new FileReader();
    r.onload = () => res(new Uint8Array(r.result));
    r.onerror = () => rej(new Error('Could not read the file'));
    r.readAsArrayBuffer(file);
  });
  function toBase64(bytes) {
    let s = '';
    for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
    return btoa(s);
  }
  const dec = new TextDecoder();
  const xml = (files, path) => files[path] ? new DOMParser().parseFromString(dec.decode(files[path]), 'application/xml') : null;
  const kids = (el, local) => el ? [...el.getElementsByTagNameNS('*', local)] : [];
  const kid = (el, local) => kids(el, local)[0] || null;
  const dirOf = p => p.slice(0, p.lastIndexOf('/') + 1);
  function resolve(base, target) {
    if (target.startsWith('/')) return target.slice(1);
    const parts = (dirOf(base) + target).split('/');
    const out = [];
    for (const p of parts) { if (p === '..') out.pop(); else if (p !== '.') out.push(p); }
    return out.join('/');
  }
  // Relationships of a part: id -> { target (zip path or URL), external }
  function rels(files, part) {
    const relPath = dirOf(part) + '_rels/' + part.slice(part.lastIndexOf('/') + 1) + '.rels';
    const doc = xml(files, relPath);
    const map = {};
    for (const r of kids(doc, 'Relationship')) {
      const ext = r.getAttribute('TargetMode') === 'External';
      map[r.getAttribute('Id')] = { target: ext ? r.getAttribute('Target') : resolve(part, r.getAttribute('Target')), external: ext };
    }
    return map;
  }

  function makePictures(files) {
    const pictures = [], byPath = {};
    return {
      pictures,
      add(path) {
        if (path in byPath) return byPath[path];
        const ext = (path.split('.').pop() || '').toLowerCase();
        const bytes = files[path];
        if (!bytes || !IMG_TYPES[ext] || bytes.length > MAX_PICTURE_BYTES || bytes.length < 2000 || pictures.length >= MAX_PICTURES) {
          byPath[path] = -1; return -1;
        }
        byPath[path] = pictures.length;
        pictures.push({ base64: toBase64(bytes), mimeType: IMG_TYPES[ext], name: path.split('/').pop() });
        return byPath[path];
      },
    };
  }

  // ── Word ────────────────────────────────────────────────────────────────────
  function readDocx(files) {
    const part = 'word/document.xml';
    const doc = xml(files, part);
    if (!doc) throw new Error('This Word file looks damaged');
    const r = rels(files, part);
    const pics = makePictures(files);
    const lines = [];
    const walkPara = p => {
      let line = '';
      const visit = el => {
        for (const n of el.childNodes) {
          if (n.nodeType !== 1) continue;
          const name = n.localName;
          if (name === 't') line += n.textContent;
          else if (name === 'tab') line += '\t';
          else if (name === 'br' || name === 'cr') line += '\n';
          else if (name === 'hyperlink') {
            const before = line.length;
            visit(n);
            const id = n.getAttributeNS('http://schemas.openxmlformats.org/officeDocument/2006/relationships', 'id') || n.getAttribute('r:id');
            const url = id && r[id]?.external ? r[id].target : '';
            if (url) line = line.slice(0, before) + `[LINK ${line.slice(before)} -> ${url}]`;
          } else if (name === 'blip') {
            const id = n.getAttributeNS('http://schemas.openxmlformats.org/officeDocument/2006/relationships', 'embed') || n.getAttribute('r:embed');
            if (id && r[id] && !r[id].external) {
              const i = pics.add(r[id].target);
              if (i >= 0) line += ` [PICTURE ${i}] `;
            }
          } else visit(n);
        }
      };
      visit(p);
      return line;
    };
    // Paragraphs in body order, tables row by row (cells separated by " | ").
    const body = kid(doc, 'body');
    const walk = el => {
      for (const n of el.childNodes) {
        if (n.nodeType !== 1) continue;
        if (n.localName === 'p') { const t = walkPara(n); if (t.trim()) lines.push(t); }
        else if (n.localName === 'tbl') {
          for (const tr of kids(n, 'tr')) {
            const cells = kids(tr, 'tc').map(tc => kids(tc, 'p').map(walkPara).filter(s => s.trim()).join(' / '));
            if (cells.some(c => c.trim())) lines.push(cells.join(' | '));
          }
        } else walk(n);
      }
    };
    walk(body || doc);
    // Hyperlinks typed as plain text are kept as they are.
    return { kind: 'docx', text: lines.join('\n'), pictures: pics.pictures };
  }

  // ── PowerPoint ──────────────────────────────────────────────────────────────
  const num = (el, a) => parseInt(el?.getAttribute(a) || '0', 10) || 0;
  function readPptx(files) {
    const pres = xml(files, 'ppt/presentation.xml');
    if (!pres) throw new Error('This PowerPoint file looks damaged');
    const sz = kid(pres, 'sldSz');
    const SW = num(sz, 'cx') || 12192000, SH = num(sz, 'cy') || 6858000;
    const presRels = rels(files, 'ppt/presentation.xml');
    const slides = kids(pres, 'sldId').map(s => {
      const id = s.getAttributeNS('http://schemas.openxmlformats.org/officeDocument/2006/relationships', 'id') || s.getAttribute('r:id');
      return presRels[id]?.target;
    }).filter(Boolean);
    const pics = makePictures(files);
    const out = [];
    const G = (x, y) => `(${Math.round(x / SW * 1000)},${Math.round(y / SH * 1000)})`;
    slides.forEach((path, si) => {
      const doc = xml(files, path);
      if (!doc) return;
      const r = rels(files, path);
      const texts = [], shapes = [];
      const walk = (el, M) => {
        for (const n of el.childNodes) {
          if (n.nodeType !== 1) continue;
          const name = n.localName;
          if (name === 'grpSp') {
            const x = kid(kid(n, 'grpSpPr'), 'xfrm');
            if (!x) { walk(n, M); continue; }
            const off = kid(x, 'off'), ext = kid(x, 'ext'), co = kid(x, 'chOff'), ce = kid(x, 'chExt');
            const sx = num(ext, 'cx') / Math.max(1, num(ce, 'cx')), sy = num(ext, 'cy') / Math.max(1, num(ce, 'cy'));
            const tx = num(off, 'x') - num(co, 'x') * sx, ty = num(off, 'y') - num(co, 'y') * sy;
            walk(n, { sx: M.sx * sx, sy: M.sy * sy, tx: M.tx + tx * M.sx, ty: M.ty + ty * M.sy });
          } else if (name === 'sp' || name === 'cxnSp' || name === 'pic') {
            const spPr = [...n.childNodes].find(c => c.localName === 'spPr');
            const x = spPr && kid(spPr, 'xfrm');
            const t = kids(n, 'p').map(p => kids(p, 't').map(t => t.textContent).join('')).filter(s => s.trim()).join(' / ');
            if (name === 'pic') {
              const blip = kid(n, 'blip');
              const id = blip && (blip.getAttributeNS('http://schemas.openxmlformats.org/officeDocument/2006/relationships', 'embed') || blip.getAttribute('r:embed'));
              const i = id && r[id] && !r[id].external ? pics.add(r[id].target) : -1;
              if (i >= 0) texts.push(`[PICTURE ${i}]`);
              continue;
            }
            if (!x) { if (t) texts.push(t); continue; }
            const off = kid(x, 'off'), ext = kid(x, 'ext');
            const X = M.tx + num(off, 'x') * M.sx, Y = M.ty + num(off, 'y') * M.sy;
            const W = num(ext, 'cx') * M.sx, H = num(ext, 'cy') * M.sy;
            const geom = kid(spPr, 'prstGeom')?.getAttribute('prst') || (kid(spPr, 'custGeom') ? 'freeform' : 'shape');
            const ln = kid(spPr, 'ln');
            const dash = kid(ln, 'prstDash')?.getAttribute('val');
            const head = kid(ln, 'headEnd')?.getAttribute('type'), tail = kid(ln, 'tailEnd')?.getAttribute('type');
            const fill = kid(kid(spPr, 'solidFill'), 'srgbClr')?.getAttribute('val') || kid(kid(spPr, 'solidFill'), 'schemeClr')?.getAttribute('val');
            const isLine = name === 'cxnSp' || /line|connector|arrow/i.test(geom) && (W < SW * 0.01 || H < SH * 0.01 || name === 'cxnSp');
            // A big text box is slide text, not part of a drawing.
            if (t && (geom === 'rect' || geom === 'shape') && !fill && W * H > SW * SH * 0.04) { texts.push(t); continue; }
            if (isLine || /Connector|line/i.test(geom)) {
              const fh = x.getAttribute('flipH') === '1', fv = x.getAttribute('flipV') === '1';
              const a = [fh ? X + W : X, fv ? Y + H : Y], b = [fh ? X : X + W, fv ? Y : Y + H];
              const arrows = [head && head !== 'none' ? 'start' : '', tail && tail !== 'none' ? 'end' : ''].filter(Boolean).join('+') || 'none';
              shapes.push(`line ${G(...a)} -> ${G(...b)} arrow=${arrows}${dash && dash !== 'solid' ? ' dashed' : ''}`);
            } else {
              shapes.push(`${geom} at ${G(X + W / 2, Y + H / 2)} size ${Math.round(W / SW * 1000)}x${Math.round(H / SH * 1000)}${fill ? ' fill=' + fill : ''}${t ? ` text="${t}"` : ''}`);
            }
          } else if (name === 'graphicFrame') {
            const t = kids(n, 'tr').map(tr => kids(tr, 'tc').map(tc => kids(tc, 't').map(t => t.textContent).join('')).join(' | ')).filter(s => s.trim()).join('\n');
            if (t) texts.push(t);
          } else walk(n, M);
        }
      };
      walk(kid(doc, 'spTree') || doc, { sx: 1, sy: 1, tx: 0, ty: 0 });
      // Speaker notes often hold the coaching detail.
      const notesPath = Object.values(r).find(v => !v.external && /notesSlide/.test(v.target))?.target;
      const notes = notesPath ? kids(xml(files, notesPath), 'p').map(p => kids(p, 't').map(t => t.textContent).join('')).filter(s => s.trim() && !/^\d+$/.test(s.trim())).join(' / ') : '';
      out.push(`=== SLIDE ${si + 1} ===`);
      if (texts.length) out.push(texts.join('\n'));
      if (shapes.length > 1) out.push('SHAPES (0-1000 grid over the slide):\n' + shapes.slice(0, 120).join('\n'));
      if (notes) out.push('NOTES: ' + notes);
    });
    return { kind: 'pptx', text: out.join('\n'), pictures: pics.pictures };
  }

  async function read(file) {
    const name = (file.name || '').toLowerCase();
    const buf = await readBuf(file);
    if (name.endsWith('.pdf') || file.type === 'application/pdf') {
      if (buf.length > 20 * 1024 * 1024) throw new Error('That PDF is too big (over 20 MB)');
      return { kind: 'pdf', text: '', pictures: [], pdfBase64: toBase64(buf) };
    }
    if (!/\.(docx|pptx)$/.test(name)) throw new Error('Please pick a Word (.docx), PowerPoint (.pptx) or PDF file');
    const { unzipSync } = await loadFflate();
    let files;
    try { files = unzipSync(buf); } catch (_) { throw new Error('Could not open that file. Is it an older .doc or .ppt? Save it as .docx/.pptx or PDF.'); }
    return name.endsWith('.docx') ? readDocx(files) : readPptx(files);
  }

  window.CSDocExtract = { read };
})();
