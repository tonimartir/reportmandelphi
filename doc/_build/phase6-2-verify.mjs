// Phase 6.2: confirm every package/groupproj referenced in the install pages exists.
import fs from 'node:fs';
import path from 'node:path';
const ROOT = path.resolve(import.meta.dirname, '..', '..');
let miss = 0;
for (const rel of ['doc/doc/delphicomp.html', 'doc/doc/buildercomp.html']) {
  const h = fs.readFileSync(path.join(ROOT, rel), 'utf8');
  const main = (h.match(/<main class="doc-main">([\s\S]*?)<\/main>/i) || [])[1] || '';
  const toks = new Set();
  for (const m of main.matchAll(/rppack[\w]*\.(?:dpk|bpk)/gi)) toks.add(m[0]);
  for (const m of main.matchAll(/packages\\[\d.]+\\reportman\.groupproj/gi)) toks.add(m[0]);
  if (/rppack_builder2007\b/.test(main)) toks.add('rppack_builder2007.dpk');
  console.log('## ' + rel);
  for (const t of [...toks].sort()) {
    const p = path.join(ROOT, t.replace(/\\/g, path.sep));
    const ok = fs.existsSync(p);
    if (!ok) miss++;
    console.log((ok ? '  OK   ' : '  MISS ') + t);
  }
}
console.log(miss ? ('** MISSING ' + miss + ' **') : 'ALL REFERENCED PACKAGES EXIST');
