// Phase 6.7: delete the dead frame-nav leftover left2.html and add a "Legacy"
// banner (with links to the current approach) to the deprecated pages.
import fs from 'node:fs';
import path from 'node:path';
const ROOT = path.resolve(import.meta.dirname, '..', '..');

// 1) delete the orphan frame-nav leftover left2.html
const left2 = path.join(ROOT, 'doc/doc/left2.html');
if (fs.existsSync(left2)) { fs.unlinkSync(left2); console.log('deleted doc/doc/left2.html'); }

// 2) drop /doc/left2.html from page-meta.json
const metaP = path.join(ROOT, 'doc/_build/page-meta.json');
if (fs.existsSync(metaP)) {
  const m = JSON.parse(fs.readFileSync(metaP, 'utf8'));
  if (m['/doc/left2.html']) { delete m['/doc/left2.html']; fs.writeFileSync(metaP, JSON.stringify(m, null, 2) + '\n', 'utf8'); console.log('removed left2 from page-meta.json'); }
}

// 3) remove the left2 <url> block from sitemap.xml
const smP = path.join(ROOT, 'doc/sitemap.xml');
let sm = fs.readFileSync(smP, 'utf8');
const before = sm.length;
sm = sm.replace(/\s*<url>\s*<loc>https:\/\/reportman\.es\/doc\/left2\.html<\/loc>[\s\S]*?<\/url>/i, '');
if (sm.length !== before) { fs.writeFileSync(smP, sm, 'utf8'); console.log('removed left2 from sitemap.xml'); }

// 4) legacy banners (idempotent: skip if already present)
const BANNERS = {
  'doc/doc/delphinetcomp.html': '<p class="doc-legacy"><b>Legacy:</b> Delphi for .NET is deprecated. For current .NET support see <a href="visualnetcomp.html">Visual Studio .NET</a> and the <a href="dotnetport.html">.NET library setup</a>.</p>',
  'doc/doc/kylixcomp.html': '<p class="doc-legacy"><b>Legacy:</b> Kylix is discontinued. For current Linux builds see <a href="installlin.html">Linux installation</a> and <a href="linuxcomp.html">Linux printreptopdf</a>.</p>',
  'doc/doc/installwebreport.html': '<p class="doc-legacy"><b>Legacy:</b> the ActiveX Internet Explorer plugin is deprecated (Internet Explorer is discontinued). For browser-based output use the <a href="webserverintro.html">Web Report Server</a> (PDF, SVG and HTML).</p>',
};
for (const [rel, banner] of Object.entries(BANNERS)) {
  const f = path.join(ROOT, rel);
  let html = fs.readFileSync(f, 'utf8');
  if (html.includes('doc-legacy')) { console.log('banner already present: ' + rel); continue; }
  // insert right after the first </h1>
  html = html.replace(/(<\/h1>\r?\n)/i, `$1${banner}\n`);
  fs.writeFileSync(f, html, 'utf8');
  console.log('added legacy banner: ' + rel);
}
console.log('done');
