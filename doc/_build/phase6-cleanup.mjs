// Phase 6.1 straggler cleanup: precise per-file replacements scoped to <main>.
import fs from 'node:fs';
import path from 'node:path';
const ROOT = path.resolve(import.meta.dirname, '..', '..');

function editMain(rel, fn) {
  const abs = path.join(ROOT, rel);
  let html = fs.readFileSync(abs, 'utf8');
  const m = html.match(/(<main class="doc-main">)([\s\S]*?)(<\/main>)/i);
  if (!m) { console.log('NO MAIN  ', rel); return; }
  const before = m[2];
  const after = fn(before);
  if (after === before) { console.log('NOCHANGE ', rel); return; }
  html = html.slice(0, m.index) + m[1] + after + m[3] + html.slice(m.index + m[0].length);
  fs.writeFileSync(abs, html, 'utf8');
  console.log('FIXED    ', rel);
}
const repl = (s, from, to) => s.split(from).join(to);

editMain('doc/doc/webserverinstall.html', s => repl(s, 'sumary', 'summary'));
editMain('doc/doc/usingcompo.html', s => repl(s, 'Tittle', 'Title'));
editMain('doc/doc/drawfunctions.html', s => repl(s, 'backgroung', 'background'));
editMain('doc/doc/refcommontext.html', s => repl(s, 'Aligment', 'Alignment'));
editMain('doc/doc/installwebreport.html', s =>
  repl(repl(s, 'WebReportanX', 'WebReportManX'),
    'http://sourceforge.net/projects/reportman', 'https://sourceforge.net/projects/reportman'));
editMain('doc/doc/exevaluator.html', s =>
  repl(repl(repl(s, 'separator amd other', 'separator and other'),
    'needed numers', 'needed numbers'),
    'NewPattern:Sring', 'NewPattern:String'));
editMain('doc/doc/buildercomp.html', s => repl(s, 'Build a application', 'Build an application'));
editMain('doc/doc/refimage.html', s =>
  repl(repl(s, 'Image propery', 'Image property'), 'prefered save format', 'preferred save format'));
editMain('doc/doc/left2.html', s => repl(s, 'architechture', 'architecture'));
editMain('doc/doc/units/rpvgraphutils.html', s => repl(s, 'rpvgraphutills.pas', 'rpvgraphutils.pas'));
// stale alt text -> remove so build-docs regenerates from the corrected title
editMain('doc/tutorial/integrating.html', s =>
  s.replace(/ alt="Integrating into the application with delphi\/kylix \(screenshot \d\)"/g, ''));

console.log('cleanup done');
