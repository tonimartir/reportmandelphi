// Phase 6.1 independent (deterministic) residual checker.
// Usage: node doc/_build/phase6-residuals.mjs <triage-output.json>
import fs from 'node:fs';
import path from 'node:path';

const inFile = process.argv[2];
const ROOT = path.resolve(import.meta.dirname, '..', '..'); // repo root
const dec = s => String(s ?? '').replace(/&gt;/g,'>').replace(/&lt;/g,'<').replace(/&quot;/g,'"').replace(/&#39;/g,"'").replace(/&amp;/g,'&');
const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const wrap = JSON.parse(fs.readFileSync(inFile, 'utf8'));
const pages = (wrap.result ?? wrap).pages || [];

function readMain(rel) {
  const abs = path.join(ROOT, rel);
  if (!fs.existsSync(abs)) return null;
  const html = fs.readFileSync(abs, 'utf8');
  const m = html.match(/<main class="doc-main">([\s\S]*?)<\/main>/i);
  return { html, main: m ? m[1] : html };
}

// all doc html files for global scans
function allDocFiles() {
  const dirs = ['doc/doc', 'doc/doc/units', 'doc/tutorial'];
  const out = [];
  for (const d of dirs) {
    const abs = path.join(ROOT, d);
    if (!fs.existsSync(abs)) continue;
    for (const f of fs.readdirSync(abs)) if (f.endsWith('.html')) out.push(d + '/' + f);
  }
  return out;
}

// 1) typo residuals (page-scoped, from triage)
const typoResiduals = [];
for (const p of pages) {
  if (!(p.typos || []).length) continue;
  const r = readMain(p.path);
  if (!r) continue;
  for (const t of p.typos) {
    const wrong = t.wrong;
    if (!wrong) continue;
    const re = /^[\w]+$/.test(wrong) ? new RegExp('\\b' + esc(wrong) + '\\b') : new RegExp(esc(wrong));
    if (re.test(r.main)) typoResiduals.push({ path: p.path, wrong, correct: t.correct });
  }
}

// 2) mojibake global scan
const MOJI = /Ã.|â€|Â¿|Â¡|ï¿½|Ã¢â‚¬/;
const mojibakeHits = [];
for (const rel of allDocFiles()) {
  const r = readMain(rel);
  if (r && MOJI.test(r.main)) {
    const sample = (r.main.match(/(Ã.|â€\S*|ï¿½|Ã¢â‚¬\S*)/) || [''])[0];
    mojibakeHits.push({ path: rel, sample });
  }
}

// 3) dead-host substrings global scan
const DEAD = ['www.borland.com','bdn.borland.com','geocities.com','wiki.rubyonrails.org','trolltech.com',
  'plugindoc.mozdev.org','iol.ie/%7Elocka','iol.ie/~locka','reportman.dnsalias.net','sancharnet.in',
  'starship.python.net','wincvs.org'];
const deadHits = [];
for (const rel of allDocFiles()) {
  const r = readMain(rel);
  if (!r) continue;
  for (const h of DEAD) if (r.main.includes(h)) deadHits.push({ path: rel, host: h });
}

// 4) plain http:// external links remaining (exclude localhost / reportman.es / schemas)
const httpHits = [];
for (const rel of allDocFiles()) {
  const r = readMain(rel);
  if (!r) continue;
  const re = /href=["']http:\/\/([^"'\/]+)/gi;
  let m; const hosts = new Set();
  while ((m = re.exec(r.main))) {
    const host = m[1].toLowerCase();
    if (host.includes('localhost') || host.includes('reportman.es') || host.includes('schemas.') || host.includes('www.w3.org')) continue;
    hosts.add(host);
  }
  if (hosts.size) httpHits.push({ path: rel, hosts: [...hosts] });
}

// 5) markup breakage heuristic: heading opened, closed with </p>
const markupHits = [];
for (const rel of allDocFiles()) {
  const r = readMain(rel);
  if (!r) continue;
  const issues = [];
  // <hN ...> ... </p>  with no intervening </hN or <
  const reH = /<h([1-6])\b[^>]*>([^<]*)<\/p>/gi;
  let m;
  while ((m = reH.exec(r.main))) issues.push(`<h${m[1]}> closed by </p>: "${m[2].trim().slice(0,40)}"`);
  // crude unbalanced <p> vs </p>
  const op = (r.main.match(/<p\b[^>]*>/gi) || []).length;
  const cl = (r.main.match(/<\/p>/gi) || []).length;
  if (Math.abs(op - cl) > 1) issues.push(`p balance: ${op} open / ${cl} close`);
  if (issues.length) markupHits.push({ path: rel, issues });
}

const out = { typoResiduals, mojibakeHits, deadHits, httpHits, markupHits };
fs.writeFileSync(path.join(ROOT, 'doc/_build/phase6-residuals.json'), JSON.stringify(out, null, 2));

console.log('=== TYPO RESIDUALS (' + typoResiduals.length + ') ===');
for (const t of typoResiduals) console.log(`  ${t.path.replace('doc/doc/','').replace('doc/tutorial/','tut/')}: ${t.wrong} -> ${t.correct}`);
console.log('=== MOJIBAKE (' + mojibakeHits.length + ') ===');
for (const t of mojibakeHits) console.log(`  ${t.path.replace('doc/doc/','')}: ${JSON.stringify(t.sample)}`);
console.log('=== DEAD HOSTS (' + deadHits.length + ') ===');
for (const t of deadHits) console.log(`  ${t.path.replace('doc/doc/','')}: ${t.host}`);
console.log('=== HTTP EXTERNAL REMAINING (' + httpHits.length + ' files) ===');
for (const t of httpHits) console.log(`  ${t.path.replace('doc/doc/','')}: ${t.hosts.join(', ')}`);
console.log('=== MARKUP BREAKAGE (' + markupHits.length + ' files) ===');
for (const t of markupHits) console.log(`  ${t.path.replace('doc/doc/','')}: ${t.issues.join(' | ')}`);
