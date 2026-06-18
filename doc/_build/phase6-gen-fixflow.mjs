// Generates the Phase 6.1 fix workflow script with an embedded per-page fix list.
// Usage: node doc/_build/phase6-gen-fixflow.mjs <triage-output.json> <out-workflow.mjs>
import fs from 'node:fs';

const inFile = process.argv[2];
const outFile = process.argv[3];
const N_BATCHES = 14;

const dec = s => String(s ?? '')
  .replace(/&gt;/g, '>').replace(/&lt;/g, '<').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');

const wrap = JSON.parse(fs.readFileSync(inFile, 'utf8'));
const pages = (wrap.result ?? wrap).pages || [];

const EXCLUDE = new Set(['doc/doc/bidi_behavior.html']); // rewritten wholesale in 6.3

const FIXDATA = {};
for (const p of pages) {
  if (EXCLUDE.has(p.path)) continue;
  const typos = (p.typos || []).map(t => [t.wrong, t.correct]).filter(t => t[0] && t[1]);
  const links = (p.deadOrLegacyLinks || [])
    .filter(l => l.href && !/^n\/a$/i.test(l.recommendation || '') && !/not present on this page/i.test(l.reason || '') && !/localhost/i.test(l.href))
    .map(l => ({ href: dec(l.href), rec: dec(l.recommendation) }));
  const obsolete = (p.obsoleteRefs || []).map(o => ({ text: dec(o.text), kind: o.kind, rec: o.recommendation }));
  const mojibake = !!p.mojibake;
  const weight = typos.length + links.length + obsolete.length * 2 + (mojibake ? 3 : 0);
  if (weight === 0) continue;
  FIXDATA[p.path] = { typos, links, obsolete, mojibake, weight };
}

// greedy balanced partition by weight
const entries = Object.entries(FIXDATA).sort((a, b) => b[1].weight - a[1].weight);
const bins = Array.from({ length: N_BATCHES }, () => ({ files: [], w: 0 }));
for (const [path, d] of entries) {
  const b = bins.reduce((m, x) => (x.w < m.w ? x : m), bins[0]);
  b.files.push(path);
  b.w += d.weight;
}
const BATCHES = bins.filter(b => b.files.length).map((b, i) => ({ label: 'b' + (i + 1), files: b.files }));

const totals = {
  pages: Object.keys(FIXDATA).length,
  typos: Object.values(FIXDATA).reduce((s, d) => s + d.typos.length, 0),
  links: Object.values(FIXDATA).reduce((s, d) => s + d.links.length, 0),
  obsolete: Object.values(FIXDATA).reduce((s, d) => s + d.obsolete.length, 0),
  mojibake: Object.values(FIXDATA).filter(d => d.mojibake).length,
};

const POLICY = [
  'You are fixing Report Manager documentation pages (recently de-iframed into self-contained HTML). For each file use the Read tool, then the Edit tool to make SURGICAL fixes ONLY inside the <main class="doc-main"> ... </main> region.',
  'NEVER modify: <head>, <header class="doc-top">, the sidebar <div class="doc-nav-wrap"> / <nav class="doc-nav">, the <nav class="doc-crumb"> breadcrumb, or the <footer class="doc-foot">. Preserve ALL content, links, images, IDs, anchors, and HTML validity. Change ONLY what the per-file instructions specify (plus any blatant additional spelling error in the same prose). Do not reformat or re-indent untouched markup.',
  '',
  'FIX TYPES:',
  '1) TYPOS: correct each listed misspelling where it appears in PROSE / visible text. Use whole-word replacement. SKIP occurrences inside code, Pascal identifiers, unit/file names, property names, or URLs.',
  '2) LINKS (given as "href :: recommendation"):',
  '   - "switch to https": change the scheme http:// to https:// in the href (and in the visible anchor text too if the text is that same URL). Never change http://localhost examples.',
  '   - "remove" / host "is gone" / "discontinued" / "dead": remove the hyperlink but KEEP its visible text as plain text (unwrap the <a> ... </a>). If the visible text is itself only the dead URL and the sentence/list-item then makes no sense, remove that whole list-item/sentence. Prefer the smallest sensible change.',
  '   - borland.com repoint: Delphi -> https://www.embarcadero.com/products/delphi ; C++Builder -> https://www.embarcadero.com/products/cbuilder ; Borland Developer Network / BDN articles / generic borland -> https://docwiki.embarcadero.com . Keep the anchor text.',
  '3) MOJIBAKE: replace garbled encoding sequences with the intended character from context, e.g. "Ã‚Â¿" -> "¿", "Ã±" -> "ñ", "â€™" -> "’", "â€œ" -> "“", "â€" -> "”", "Ã³" -> "ó". If a sequence is so corrupted you cannot tell the intended text (e.g. a long garbled run), replace it with a sensible plain-text placeholder or remove it, and note it.',
  '4) OBSOLETE REFS (given as "[recommendation/kind] snippet"):',
  '   - "reword": rewrite the passage so it is no longer misleading and reflects CURRENT reality: the Report Manager Designer is a Windows VCL application (NOT Qt/CLX); complex-text shaping/BiDi uses DirectWrite on Windows and ICU + HarfBuzz on Linux; current Windows targets are Windows 10/11 and Windows Server; .NET and .NET Core libraries are current; output drivers are PDF, SVG, HTML, GDI/printer, plain-text/CSV and the native metafile. Do NOT present discontinued things as current (Internet Explorer ActiveX plugin, Kylix, Win98/ME/NT/2000/XP "all current OS", "Boxed product", Qt-based designer).',
  '     When the passage lists OLD supported targets worth keeping as history (old Delphi/Kylix versions, BDE / DBExpress drivers, CLX), KEEP them but explicitly LABEL them legacy/historical (e.g. add "(legacy)" or "older versions"). Keep wording terse.',
  '   - "remove": delete the obsolete mention cleanly (e.g. the Yahoo Groups reference) without leaving a dangling sentence.',
  '   - "keep-historical": leave the mention; you MAY add a short "legacy" label if it currently reads as if it were current, otherwise leave it untouched.',
  'Be conservative and precise. After editing, report exactly what you changed per file.',
].join('\n');

const VERIFY_POLICY = [
  'You are an ADVERSARIAL verifier checking edits made to Report Manager documentation pages. For each file use Read and inspect ONLY the <main class="doc-main"> region. Your job is to catch problems, not to be charitable.',
  'For each file report:',
  ' - typosRemaining: any of the originally-listed misspellings (or other obvious ones) still present in prose.',
  ' - deadLinksRemaining: any originally-flagged dead/legacy external link still present unfixed (still http:// on a live host, or a still-present dead host). Ignore http://localhost examples.',
  ' - mojibakeRemaining: true if garbled encoding sequences remain.',
  ' - misleadingRemaining: any obsolete claim still presented as CURRENT (IE plugin, Kylix/Qt designer, Win98-XP as current OS, Boxed product) that was supposed to be reworded.',
  ' - breakageOrContentLoss: any broken HTML, removed/duplicated headings, lost images or links, truncated sentences, or edits that leaked outside <main>.',
  ' - verdict: "pass" only if ALL the above are empty/false; otherwise "needs-rework".',
  'Be specific (quote the offending text). Do not edit anything.',
].join('\n');

const script = `export const meta = {
  name: 'doc-fix-phase6-1',
  description: 'Phase 6.1: fix typos / dead links / mojibake and reword obsolete refs across ${totals.pages} doc pages, then adversarially verify',
  phases: [
    { title: 'Fix' },
    { title: 'Verify' },
  ],
}

// Embedded per-page fix list derived from the 6.0 triage.
// Totals: ${totals.pages} pages, ${totals.typos} typos, ${totals.links} links, ${totals.obsolete} obsolete refs, ${totals.mojibake} mojibake pages.
const FIXDATA = ${JSON.stringify(FIXDATA)};
const BATCHES = ${JSON.stringify(BATCHES)};

const POLICY = ${JSON.stringify(POLICY)};
const VERIFY_POLICY = ${JSON.stringify(VERIFY_POLICY)};

const FIX_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    files: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      properties: {
        path: { type: 'string' },
        typosFixed: { type: 'integer' },
        linksFixed: { type: 'integer' },
        obsoleteReworded: { type: 'integer' },
        mojibakeFixed: { type: 'boolean' },
        notes: { type: 'string' },
      },
      required: ['path', 'typosFixed', 'linksFixed', 'obsoleteReworded', 'mojibakeFixed', 'notes'],
    } },
  },
  required: ['files'],
}

const VERIFY_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    files: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      properties: {
        path: { type: 'string' },
        verdict: { type: 'string', enum: ['pass', 'needs-rework'] },
        typosRemaining: { type: 'array', items: { type: 'string' } },
        deadLinksRemaining: { type: 'array', items: { type: 'string' } },
        mojibakeRemaining: { type: 'boolean' },
        misleadingRemaining: { type: 'array', items: { type: 'string' } },
        breakageOrContentLoss: { type: 'array', items: { type: 'string' } },
      },
      required: ['path', 'verdict', 'typosRemaining', 'deadLinksRemaining', 'mojibakeRemaining', 'misleadingRemaining', 'breakageOrContentLoss'],
    } },
  },
  required: ['files'],
}

function fileDirectives(path) {
  const d = FIXDATA[path];
  let s = 'FILE: ' + path + '\\n';
  if (d.mojibake) s += '  - MOJIBAKE present: fix garbled sequences to the intended character.\\n';
  if (d.typos.length) s += '  - Typos: ' + d.typos.map(t => t[0] + '->' + t[1]).join(', ') + '\\n';
  if (d.links.length) s += '  - Links: ' + d.links.map(l => l.href + ' :: ' + l.rec).join('  |  ') + '\\n';
  if (d.obsolete.length) s += '  - Obsolete refs: ' + d.obsolete.map(o => '[' + o.rec + '/' + o.kind + '] ' + o.text).join('  |  ') + '\\n';
  return s;
}

function fixPrompt(files) {
  return POLICY + '\\n\\nApply fixes to these ' + files.length + ' files:\\n\\n' + files.map(fileDirectives).join('\\n');
}
function verifyPrompt(files) {
  return VERIFY_POLICY + '\\n\\nCheck these ' + files.length + ' files (the originally-flagged issues are listed for reference):\\n\\n' + files.map(fileDirectives).join('\\n');
}

const results = await pipeline(
  BATCHES,
  (b) => agent(fixPrompt(b.files), { label: 'fix:' + b.label, phase: 'Fix', schema: FIX_SCHEMA }),
  (fixRes, b) => agent(verifyPrompt(b.files), { label: 'verify:' + b.label, phase: 'Verify', schema: VERIFY_SCHEMA })
    .then(v => ({ batch: b.label, fix: fixRes, verify: v })),
)

const flat = results.filter(Boolean)
const verifyFiles = flat.flatMap(r => (r.verify && r.verify.files) || [])
const fixFiles = flat.flatMap(r => (r.fix && r.fix.files) || [])
const needsRework = verifyFiles.filter(f => f.verdict !== 'pass')
const rollup = {
  batches: flat.length,
  filesFixed: fixFiles.length,
  filesVerified: verifyFiles.length,
  passed: verifyFiles.filter(f => f.verdict === 'pass').length,
  needsRework: needsRework.length,
  totalTyposFixed: fixFiles.reduce((s, f) => s + (f.typosFixed || 0), 0),
  totalLinksFixed: fixFiles.reduce((s, f) => s + (f.linksFixed || 0), 0),
  totalObsoleteReworded: fixFiles.reduce((s, f) => s + (f.obsoleteReworded || 0), 0),
  mojibakeFixed: fixFiles.filter(f => f.mojibakeFixed).length,
}
log('Fixed ' + rollup.filesFixed + ' files; verify pass=' + rollup.passed + ' needs-rework=' + rollup.needsRework)

return { rollup, needsRework, fixFiles, verifyFiles }
`;

fs.writeFileSync(outFile, script, 'utf8');
console.log(`Wrote ${outFile}`);
console.log(`Batches: ${BATCHES.length}; pages: ${totals.pages}; typos: ${totals.typos}; links: ${totals.links}; obsolete: ${totals.obsolete}; mojibake: ${totals.mojibake}`);
console.log('Batch sizes: ' + bins.filter(b => b.files.length).map(b => b.files.length + '/' + b.w).join(' '));
