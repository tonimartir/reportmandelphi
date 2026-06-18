// Phase 6.6: turn the meta workflow output into doc/_build/page-meta.json
// Usage: node doc/_build/phase6-6-build-meta.mjs <workflow-output.json>
import fs from 'node:fs';
import path from 'node:path';
const ROOT = path.resolve(import.meta.dirname, '..', '..');

const wrap = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const pages = (wrap.result ?? wrap).pages || [];

function webPath(p) {
  p = p.replace(/\\/g, '/');
  if (p.startsWith('doc/doc/units/')) return '/doc/units/' + p.slice('doc/doc/units/'.length);
  if (p.startsWith('doc/doc/')) return '/doc/' + p.slice('doc/doc/'.length);
  if (p.startsWith('doc/tutorial/')) return '/tutorial/' + p.slice('doc/tutorial/'.length);
  return '/' + p;
}
function clamp(s, n) {
  s = String(s).replace(/\s+/g, ' ').trim();
  if (s.length <= n) return s;
  let c = s.slice(0, n);
  const sp = c.lastIndexOf(' ');
  if (sp > n * 0.6) c = c.slice(0, sp);
  return c.trim();
}

const out = {};
let descs = 0, titles = 0, over = 0;
for (const pg of pages) {
  if (!pg.path || !pg.desc) continue;
  const wp = webPath(pg.path);
  const entry = {};
  if (pg.title && pg.title.trim()) { entry.title = clamp(pg.title, 70); titles++; }
  const d = clamp(pg.desc, 155);
  if (String(pg.desc).trim().length > 155) over++;
  entry.desc = d;
  descs++;
  out[wp] = entry;
}

// keep keys sorted for a stable diff
const sorted = {};
for (const k of Object.keys(out).sort()) sorted[k] = out[k];
fs.writeFileSync(path.join(ROOT, 'doc/_build/page-meta.json'), JSON.stringify(sorted, null, 2) + '\n', 'utf8');
console.log(`page-meta.json: ${descs} descriptions (${titles} title overrides; ${over} descs were >155 and got clamped)`);
// longest description after clamp (sanity)
const longest = Math.max(...Object.values(sorted).map(e => e.desc.length));
console.log('longest desc after clamp: ' + longest);
