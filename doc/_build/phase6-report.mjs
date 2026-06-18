// Phase 6.0 - turn the triage workflow output into a findings sheet.
// Usage: node doc/_build/phase6-report.mjs <workflow-output.json> [out.md]
import fs from 'node:fs';

const inFile = process.argv[2];
const outFile = process.argv[3] || 'doc/_build/phase6-findings.md';

const wrap = JSON.parse(fs.readFileSync(inFile, 'utf8'));
const data = wrap.result ?? wrap;
const pages = data.pages || [];
const rollup = data.rollup || {};

const dec = s => String(s ?? '')
  .replace(/&gt;/g, '>').replace(/&lt;/g, '<').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
const cell = s => dec(s).replace(/\|/g, '\\|').replace(/\r?\n/g, ' ').trim();

const out = [];
const w = s => out.push(s);

w('# Phase 6.0 — Documentation triage findings');
w('');
w(`Auto-generated from the multi-agent triage of ${rollup.totalPages} doc pages. ` +
  `Source: \`${inFile.replace(/\\/g, '/')}\`.`);
w('');
w('## Rollup');
w('');
w('| Metric | Value |');
w('|---|---|');
w(`| Pages triaged | ${rollup.totalPages} |`);
w(`| Priority high / medium / low | ${rollup.byPriority?.high} / ${rollup.byPriority?.medium} / ${rollup.byPriority?.low} |`);
w(`| Pages with typos (total typos) | ${rollup.withTypos} (${rollup.totalTypos}) |`);
w(`| Pages with mojibake | ${rollup.withMojibake} |`);
w(`| Pages with obsolete refs (total) | ${rollup.withObsoleteRefs} (${rollup.totalObsoleteRefs}) |`);
w(`| Pages with dead/legacy links (total) | ${rollup.withDeadLinks} (${rollup.totalDeadLinks}) |`);
w(`| Weak/missing title | ${rollup.weakOrMissingTitle} |`);
w(`| Weak/auto-generated description | ${rollup.weakOrAutoDesc} |`);
w('');

// ---- A. Mojibake ----
const moji = pages.filter(p => p.mojibake);
w(`## A. Mojibake — encoding corruption (${moji.length} pages)`);
w('');
if (moji.length) {
  for (const p of moji) w(`- \`${p.path}\` — ${cell(p.title)}`);
} else w('_none_');
w('');

// ---- B. Dead / legacy external links ----
const linkRows = [];
for (const p of pages) for (const l of (p.deadOrLegacyLinks || [])) {
  if (!l.href || /^n\/a$/i.test(l.recommendation) || /not present on this page/i.test(l.reason)) continue;
  linkRows.push({ path: p.path, ...l });
}
w(`## B. Dead / legacy external links (${linkRows.length} flagged across ${rollup.withDeadLinks} pages)`);
w('');
w('| Page | href | Anchor | Reason | Recommendation |');
w('|---|---|---|---|---|');
for (const r of linkRows) {
  w(`| \`${r.path.replace('doc/doc/', '')}\` | ${cell(r.href)} | ${cell(r.anchorText)} | ${cell(r.reason)} | ${cell(r.recommendation)} |`);
}
w('');

// ---- C. Obsolete tech references ----
const byKind = {};
const refRows = [];
for (const p of pages) for (const o of (p.obsoleteRefs || [])) {
  byKind[o.kind] = byKind[o.kind] || { keep: 0, reword: 0, remove: 0, total: 0 };
  byKind[o.kind].total++;
  if (o.recommendation === 'keep-historical') byKind[o.kind].keep++;
  else if (o.recommendation === 'reword') byKind[o.kind].reword++;
  else if (o.recommendation === 'remove') byKind[o.kind].remove++;
  refRows.push({ path: p.path, ...o });
}
w(`## C. Obsolete technology references (${refRows.length} across ${rollup.withObsoleteRefs} pages)`);
w('');
w('### By kind');
w('');
w('| Kind | Total | keep-historical | reword | remove |');
w('|---|---|---|---|---|');
for (const k of Object.keys(byKind).sort((a, b) => byKind[b].total - byKind[a].total)) {
  const v = byKind[k];
  w(`| ${k} | ${v.total} | ${v.keep} | ${v.reword} | ${v.remove} |`);
}
w('');
w('### Detail (rec = remove or reword first)');
w('');
w('| Page | Kind | Rec | Snippet |');
w('|---|---|---|---|');
const recOrder = { remove: 0, reword: 1, 'keep-historical': 2 };
for (const r of refRows.sort((a, b) => (recOrder[a.recommendation] ?? 9) - (recOrder[b.recommendation] ?? 9))) {
  w(`| \`${r.path.replace('doc/doc/', '')}\` | ${r.kind} | ${r.recommendation} | ${cell(r.text).slice(0, 120)} |`);
}
w('');

// ---- D. Typos ----
const typoMap = new Map(); // wrong(lower) -> {wrong, correct, pages:Set}
for (const p of pages) for (const t of (p.typos || [])) {
  const key = (t.wrong || '').toLowerCase() + '=>' + (t.correct || '').toLowerCase();
  if (!typoMap.has(key)) typoMap.set(key, { wrong: t.wrong, correct: t.correct, pages: new Set() });
  typoMap.get(key).pages.add(p.path.replace('doc/doc/', '').replace('doc/tutorial/', 'tut/'));
}
const typos = [...typoMap.values()].sort((a, b) => b.pages.size - a.pages.size);
w(`## D. Typos — ${typos.length} unique misspellings (${rollup.totalTypos} total occurrences)`);
w('');
w('| wrong | correct | # pages | pages |');
w('|---|---|---|---|');
for (const t of typos) {
  const pl = [...t.pages];
  const shown = pl.slice(0, 8).join(', ') + (pl.length > 8 ? `, +${pl.length - 8}` : '');
  w(`| ${cell(t.wrong)} | ${cell(t.correct)} | ${t.pages.size} | ${cell(shown)} |`);
}
w('');

// ---- E. Titles ----
const titleFix = pages.filter(p => ['weak', 'generic', 'missing'].includes(p.titleQuality));
w(`## E. Title quality — ${titleFix.length} pages need a hand-written title`);
w('');
w('| Page | Current | Quality | Suggested |');
w('|---|---|---|---|');
for (const p of titleFix) {
  w(`| \`${p.path.replace('doc/doc/', '').replace('doc/tutorial/', 'tut/')}\` | ${cell(p.title)} | ${p.titleQuality} | ${cell(p.suggestedTitle)} |`);
}
w('');

// ---- F. Descriptions (high+medium only, to keep it actionable) ----
const descFix = pages.filter(p => ['weak', 'auto-generated', 'missing'].includes(p.descQuality) && p.priority !== 'low');
w(`## F. Meta descriptions — ${rollup.weakOrAutoDesc} weak/auto total; ${descFix.length} on high/medium pages (shown)`);
w('');
w('| Page | Pri | Quality | Suggested |');
w('|---|---|---|---|');
for (const p of descFix.sort((a, b) => (a.priority === 'high' ? 0 : 1) - (b.priority === 'high' ? 0 : 1))) {
  w(`| \`${p.path.replace('doc/doc/', '').replace('doc/tutorial/', 'tut/')}\` | ${p.priority} | ${p.descQuality} | ${cell(p.suggestedDesc)} |`);
}
w('');

// ---- G. Content staleness ----
const stale = pages.filter(p => (p.contentStaleness || []).length);
w(`## G. Content staleness notes (${stale.length} pages)`);
w('');
for (const p of stale.sort((a, b) => (a.priority === 'high' ? 0 : a.priority === 'medium' ? 1 : 2) - (b.priority === 'high' ? 0 : b.priority === 'medium' ? 1 : 2))) {
  w(`### \`${p.path}\` — ${cell(p.title)} _(priority: ${p.priority})_`);
  for (const s of p.contentStaleness) w(`- ${cell(s)}`);
  w('');
}

// ---- H. High-priority index ----
w('## H. High-priority pages');
w('');
for (const p of pages.filter(p => p.priority === 'high')) {
  const flags = [];
  if (p.mojibake) flags.push('mojibake');
  if ((p.typos || []).length) flags.push(`${p.typos.length} typos`);
  if ((p.obsoleteRefs || []).length) flags.push(`${p.obsoleteRefs.length} obsolete`);
  if ((p.deadOrLegacyLinks || []).length) flags.push(`${p.deadOrLegacyLinks.length} links`);
  if ((p.contentStaleness || []).length) flags.push(`${p.contentStaleness.length} stale`);
  w(`- \`${p.path}\` — ${flags.join(', ') || 'clean'}`);
}
w('');

fs.writeFileSync(outFile, out.join('\n'), 'utf8');

// ---- console summary ----
console.log(`Wrote ${outFile} (${out.length} lines).`);
console.log(`Mojibake pages: ${moji.map(p => p.path.replace('doc/doc/', '')).join(', ')}`);
console.log(`Unique typos: ${typos.length}; top: ${typos.slice(0, 12).map(t => t.wrong + '->' + t.correct).join(', ')}`);
console.log(`Obsolete kinds: ${Object.keys(byKind).sort((a, b) => byKind[b].total - byKind[a].total).map(k => k + '(' + byKind[k].total + ')').join(', ')}`);
console.log(`Dead/legacy links: ${linkRows.length}`);
console.log(`Titles to fix: ${titleFix.length}; descriptions weak/auto: ${rollup.weakOrAutoDesc}`);
