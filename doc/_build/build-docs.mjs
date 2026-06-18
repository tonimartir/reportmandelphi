// Report Manager - documentation builder (bake-in-build, no iframes).
// Single source of truth for the sidebar = the NAV array below.
// Edit NAV (or the template) and re-run:  node doc/_build/build-docs.mjs
// Idempotent: re-running re-reads each page's own content from <main>, so it
// never double-wraps. It rewraps every legacy page in doc/doc/ (and
// doc/doc/units/) into a self-contained page: modern <head> + shared header +
// baked sidebar + breadcrumb + the original content + footer. Content is
// preserved; only frame targets are stripped, the reportman.es host is made
// root-relative, and missing <img alt> are filled from page context.

import fs from 'node:fs';
import path from 'node:path';

const WEBROOT = path.resolve(import.meta.dirname, '..'); // the served doc/ folder
const DOCDIR = path.join(WEBROOT, 'doc');                // /doc/
const UNITSDIR = path.join(DOCDIR, 'units');             // /doc/units/

const NAV = [
  ['Introduction', [
    ['Application description', '/doc/index.html'],
    ['Hardware and software requirements', '/doc/requirements.html'],
    ['Features', '/doc/features.html'],
    ['.NET library', '/docnet/index.html'],
    ['Engine overview', '/doc/howitwork.html'],
    ['Interoperability and standards', '/doc/interoperability.html'],
    ['Quick tutorial', '/tutorial/index.html'],
    ['Successful projects', '/doc/success.html'],
  ]],
  ['Installation', [
    ['Microsoft Windows', '/doc/installwin.html'],
    ['Linux', '/doc/installlin.html'],
    ['Compilation options', '/doc/compileropts.html'],
    ['Delphi', '/doc/delphicomp.html'],
    ['C++Builder', '/doc/buildercomp.html'],
    ['ActiveX', '/doc/axtivexcomp.html'],
    ['Other languages', '/doc/otherlang.html'],
    ['Linux printreptopdf', '/doc/linuxcomp.html'],
    ['Visual Studio .NET', '/doc/visualnetcomp.html'],
    ['Delphi for .NET (deprecated)', '/doc/delphinetcomp.html'],
    ['Kylix (deprecated)', '/doc/kylixcomp.html'],
    ['ActiveX IE plugin (deprecated)', '/doc/installwebreport.html'],
    ['Deploying Report Manager', '/doc/deploy.html'],
    ['Report Manager Server', '/doc/installserver.html'],
    ['.NET library setup', '/doc/dotnetport.html'],
  ]],
  ['TCP Report Server', [
    ['Introduction', '/doc/serverintro.html'],
    ['Report server', '/doc/serverserver.html'],
    ['Report client', '/doc/serverclient.html'],
    ['Configuration', '/doc/serverconfig.html'],
    ['Multiprocessor support', '/doc/serversmp.html'],
  ]],
  ['Web Report Server', [
    ['Introduction', '/doc/webserverintro.html'],
    ['Installation', '/doc/webserverinstall.html'],
    ['Operations', '/doc/webserveroperations.html'],
  ]],
  ['Basic report design', [
    ['Opening the dataset', '/doc/openingdata.html'],
    ['Dropping fields', '/doc/droppingfields.html'],
    ['Page header and footer', '/doc/pageheader.html'],
    ['Subreport header and summary', '/doc/reportheader.html'],
    ['Group header and footer', '/doc/groupheader.html'],
    ['Page setup and print options', '/doc/pagesetup.html'],
    ['Report grid', '/doc/reportgrid.html'],
    ['Designer preferences', '/doc/preferences.html'],
    ['Components in Delphi/Kylix/Builder', '/doc/usingcompo.html'],
    ['Command line tools', '/doc/commandline.html'],
    ['Report libraries', '/doc/replibraries.html'],
  ]],
  ['Advanced report design', [
    ['Using report parameters', '/doc/repparams.html'],
    ['Linked queries', '/doc/linkedquerys.html'],
    ['Child subreports', '/doc/childsubreports.html'],
    ['Printing labels', '/doc/labels.html'],
    ['Report files sharing sections', '/doc/externalsec.html'],
    ['Expression evaluator', '/doc/exevaluator.html'],
    ['Barcode printing', '/doc/barcodes.html'],
    ['TeeChart support', '/doc/teechart.html'],
    ['International support', '/doc/internatsupport.html'],
    ['Composite reports', '/doc/compsiterep.html'],
    ['Dot matrix and POS devices', '/doc/dotmatrix.html'],
    ['Database access information', '/doc/openingdatatrouble.html'],
    ['Form filling', '/doc/formfilling.html'],
    ['Custom text output', '/doc/customoutput.html'],
    ['In memory datasets', '/doc/inmemorydata.html'],
    ['Parallel unions', '/doc/parallel.html'],
  ]],
  ['Component reference', [
    ['Common properties', '/doc/refcommon.html'],
    ['Text components', '/doc/refcommontext.html'],
    ['TRpSubReport', '/doc/refsubreport.html'],
    ['TRpSection', '/doc/refsection.html'],
    ['TRpLabel', '/doc/reflabel.html'],
    ['TRpExpression', '/doc/refexpression.html'],
    ['TRpShape', '/doc/refdraw.html'],
    ['TRpImage', '/doc/refimage.html'],
    ['TRpChart', '/doc/refchart.html'],
    ['TRpBarcode', '/doc/refbarcode.html'],
    ['Database connections', '/doc/refdatabaseinfo.html'],
  ]],
  ['Developer', [
    ['License questions', '/doc/licensequestions.html'],
    ['Translating Report Manager', '/doc/translation.html'],
    ['Building binaries and tools', '/doc/building.html'],
    ['Driver architecture', '/doc/devdriver.html'],
    ['PDF output implementation', '/doc/pdfoutput.html'],
    ['Source code units', '/doc/units.html'],
    ['Developer notes', '/doc/devnotes.html'],
  ]],
  ['Release notes', [
    ['What is new', '/doc/whatisnew.html'],
    ['F.A.Q.', '/doc/faq.html'],
    ['Known issues and workarounds', '/doc/knownissues.html'],
    ['Missing features (to-do)', '/doc/mfeatures.html'],
  ]],
];

const TUT_NAV = [
  ['Quick tutorial', [
    ['Defining data access', '/tutorial/index.html'],
    ['Dropping fields', '/tutorial/dropping.html'],
    ['Testing the report', '/tutorial/testing.html'],
    ['Integrating into Delphi/C++Builder', '/tutorial/integrating.html'],
  ]],
];

const escAttr = s => String(s).replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
const escText = s => String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');

function decode(buf){
  const head = buf.toString('latin1', 0, 1024).toLowerCase();
  let enc = 'windows-1252';
  if (head.includes('charset=utf-8')) enc = 'utf-8';
  try { return new TextDecoder(enc).decode(buf); }
  catch { return buf.toString('utf-8'); }
}

function navHtmlFrom(sections, currentPath, menuLabel){
  let h = `<div class="doc-nav-wrap">\n<input type="checkbox" id="docnav" class="doc-nav-cb">\n<label for="docnav" class="doc-nav-btn">${escText(menuLabel)}</label>\n<nav class="doc-nav" aria-label="${escText(menuLabel)}">\n`;
  for (const [section, items] of sections){
    h += `<h4>${escText(section)}</h4>\n<ul>\n`;
    for (const [label, href] of items){
      const cur = href === currentPath ? ' class="current" aria-current="page"' : '';
      h += `<li><a href="${href}"${cur}>${escText(label)}</a></li>\n`;
    }
    h += '</ul>\n';
  }
  h += '</nav>\n</div>';
  return h;
}

function extractTitle(html, fallback){
  const m = html.match(/<title>([\s\S]*?)<\/title>/i);
  let t = m ? m[1].replace(/\s+/g,' ').trim() : '';
  t = t.replace(/\s*-\s*Report Manager Docs\s*$/i, ''); // drop our own suffix on re-runs
  return t || fallback;
}

function extractLdJson(html){
  const out = [];
  const re = /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let m;
  while ((m = re.exec(html))) out.push(m[1].trim());
  return out.filter(s => !/"BreadcrumbList"/.test(s)); // breadcrumb is regenerated
}

function extractDescription(html){
  const m = html.match(/<meta\s+name=["']description["']\s+content=["']([^"']*)["']/i);
  return m ? m[1] : '';
}

// Returns {title, content} from either an original legacy page or an
// already-built page (idempotent re-run).
function parsePage(html, fallbackTitle){
  if (/<main class="doc-main">/i.test(html)){
    const h1 = html.match(/<h1>([\s\S]*?)<\/h1>/i);
    const title = h1 ? h1[1].replace(/\s+/g,' ').trim() : extractTitle(html, fallbackTitle);
    const mm = html.match(/<main class="doc-main">([\s\S]*?)<\/main>/i);
    let inner = mm ? mm[1] : '';
    inner = inner.replace(/<nav class="doc-crumb"[\s\S]*?<\/nav>/i, '');
    inner = inner.replace(/<h1>[\s\S]*?<\/h1>/i, '');
    return {title, content: inner.trim()};
  }
  const title = extractTitle(html, fallbackTitle);
  let body;
  const m = html.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
  if (m) body = m[1];
  else {
    body = html.replace(/<head[\s\S]*?<\/head>/i, '').replace(/<!doctype[^>]*>/i,'').replace(/<\/?html[^>]*>/gi,'');
  }
  body = body.replace(/<script[^>]*type=["']application\/ld\+json["'][^>]*>[\s\S]*?<\/script>/gi,'');
  body = body.replace(/<\/?body[^>]*>/gi,'');
  return {title, content: body.trim()};
}

function transformContent(body, title){
  // the template owns the single <h1>; never let content carry one
  body = body.replace(/<h1\b[^>]*>[\s\S]*?<\/h1>/gi, '');
  // drop empty headings carried from the legacy markup
  body = body.replace(/<h[2-6]\b[^>]*>\s*<\/h[2-6]>/gi, '');
  body = body.replace(/\s+target=["']?(mainFrame|leftFrame|_parent)["']?/gi, '');
  body = body.replace(/https?:\/\/(www\.)?reportman\.es\//gi, '/');
  body = body.replace(/https?:\/\/(www\.)?reportman\.es(?=["'])/gi, '/');
  // images: fill alt from context, lazy-load below-fold, async decode (idempotent)
  let n = 0;
  body = body.replace(/<img\b[^>]*>/gi, (tag) => {
    let out = tag;
    if (!/\balt\s*=/i.test(out)){
      const srcM = out.match(/\bsrc\s*=\s*["']?([^"'>\s]+)/i);
      const src = srcM ? srcM[1] : '';
      let alt;
      if (/(arrow|spacer|bullet|pixel|blank|\bline)\b/i.test(src)) alt = '';
      else { n++; alt = `${title} (screenshot ${n})`; }
      out = out.replace(/\s*\/?>\s*$/, ` alt="${escAttr(alt)}">`);
    }
    if (!/\bloading\s*=/i.test(out)) out = out.replace(/\s*\/?>\s*$/, ' loading="lazy">');
    if (!/\bdecoding\s*=/i.test(out)) out = out.replace(/\s*\/?>\s*$/, ' decoding="async">');
    return out;
  });
  // links opening a new tab: add rel="noopener" if no rel is present (idempotent)
  body = body.replace(/<a\b[^>]*\btarget=["']?_blank["']?[^>]*>/gi, (tag) =>
    /\brel\s*=/i.test(tag) ? tag : tag.replace(/\s*>$/, ' rel="noopener">'));
  return body;
}

function makeDescription(existing, body, title){
  if (existing) return existing;
  const text = body.replace(/<[^>]+>/g,' ').replace(/&nbsp;/g,' ').replace(/\s+/g,' ').trim();
  let d = text.slice(0, 200);
  if (d.length > 155){ d = d.slice(0,155); d = d.slice(0, d.lastIndexOf(' ')); }
  d = d.trim();
  return d || `Report Manager documentation: ${title}.`;
}

function render({title, desc, canonicalPath, nav, crumbs, content, extraLd}){
  const crumb = `<nav class="doc-crumb" aria-label="Breadcrumb">` +
    crumbs.map((c,i)=> (i===crumbs.length-1 || !c.href) ? `<span>${escText(c.name)}</span>` : `<a href="${c.href}">${escText(c.name)}</a>`).join(' &rsaquo; ') +
    `</nav>`;
  const breadcrumbLd = {
    "@context":"https://schema.org","@type":"BreadcrumbList",
    "itemListElement": crumbs.map((c,i)=>{ const li={"@type":"ListItem","position":i+1,"name":c.name}; if (c.item) li.item=c.item; return li; })
  };
  let ld = `<script type="application/ld+json">\n${JSON.stringify(breadcrumbLd, null, 2)}\n</script>`;
  for (const e of extraLd) ld += `\n<script type="application/ld+json">\n${e}\n</script>`;
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${escText(title)} - Report Manager Docs</title>
<meta name="description" content="${escAttr(desc)}">
<link rel="canonical" href="https://reportman.es${canonicalPath}">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="icon" href="/favicon.ico" sizes="any">
<link rel="stylesheet" href="/doc/docs.css">
${ld}
</head>
<body class="doc">
<header class="doc-top">
<a class="doc-brand" href="/">Report Manager</a>
<a class="doc-back" href="/">&larr; Back to site</a>
</header>
<div class="doc-layout">
${nav}
<main class="doc-main">
${crumb}
<h1>${escText(title)}</h1>
${content}
</main>
</div>
<footer class="doc-foot">&copy; 1994&ndash;2026 Toni Martir &middot; <a href="/doc/license.html">MPL License</a> &middot; <a href="/">reportman.es</a></footer>
</body>
</html>
`;
}

function buildPage(absFile, webPath, opts){
  const html = decode(fs.readFileSync(absFile));
  const base = path.basename(absFile, '.html');
  const {title, content: raw} = parsePage(html, base);
  const content = transformContent(raw, title);
  const desc = makeDescription(extractDescription(html), content, title);
  const extraLd = extractLdJson(html);
  const nav = navHtmlFrom(opts.sections, webPath, opts.menuLabel);
  const crumbs = opts.crumbs(title, webPath);
  fs.writeFileSync(absFile, render({title, desc, canonicalPath: webPath, nav, crumbs, content, extraLd}), 'utf-8');
  return {file: webPath, title, bodyLen: content.length, extraLd: extraLd.length};
}

// Rebuild a section index from its old frameset right.html (first run) or its
// own already-built content (re-run); then delete the frame helper files.
function buildIndex(dirAbs, webPath, title, desc, opts){
  const idxAbs = path.join(dirAbs, 'index.html');
  const rightAbs = path.join(dirAbs, 'right.html');
  const src = decode(fs.readFileSync(fs.existsSync(rightAbs) ? rightAbs : idxAbs));
  const content = transformContent(parsePage(src, title).content, title);
  const nav = navHtmlFrom(opts.sections, webPath, opts.menuLabel);
  const crumbs = opts.crumbs(title, webPath);
  fs.writeFileSync(idxAbs, render({title, desc, canonicalPath: webPath, nav, crumbs, content, extraLd: []}), 'utf-8');
  for (const dead of ['left.html','right.html']){
    const p = path.join(dirAbs, dead);
    if (fs.existsSync(p)) fs.unlinkSync(p);
  }
  return {file: webPath, title, bodyLen: content.length, extraLd: 0};
}

// ---- run ----
const TUTDIR = path.join(WEBROOT, 'tutorial'); // /tutorial/

const A = p => 'https://reportman.es' + p;
const DOCS_OPTS = {
  sections: NAV, menuLabel: 'Documentation menu',
  crumbs: (title, webPath) => [
    {name:'Home', href:'/', item:A('/')},
    {name:'Documentation', href:'/doc/index.html', item:A('/doc/index.html')},
    {name:title, item:A(webPath)},
  ],
};
const TUT_OPTS = {
  sections: TUT_NAV, menuLabel: 'Tutorial menu',
  crumbs: (title, webPath) => [
    {name:'Home', href:'/', item:A('/')},
    {name:'Documentation', href:'/doc/index.html', item:A('/doc/index.html')},
    {name:'Quick tutorial', href:'/tutorial/index.html', item:A('/tutorial/index.html')},
    {name:title, item:A(webPath)},
  ],
};

const skip = new Set(['index.html','left.html','right.html']);
const results = [];
const warnings = [];

function runDir(dirAbs, webPrefix, opts){
  if (!fs.existsSync(dirAbs)) return;
  for (const f of fs.readdirSync(dirAbs)){
    if (!f.endsWith('.html') || skip.has(f)) continue;
    const r = buildPage(path.join(dirAbs, f), `${webPrefix}${f}`, opts);
    if (!r.bodyLen) warnings.push(`empty body: ${webPrefix}${f}`);
    results.push(r);
  }
}

runDir(DOCDIR, '/doc/', DOCS_OPTS);
runDir(UNITSDIR, '/doc/units/', DOCS_OPTS);
runDir(TUTDIR, '/tutorial/', TUT_OPTS);

const idesc = 'Report Manager documentation: open-source reporting engine and visual designer for .NET, Delphi, C++Builder and Linux, with PDF/SVG/HTML output, a web/TCP report server and an AI Copilot.';
results.push(buildIndex(DOCDIR, '/doc/index.html', 'Report Manager documentation', idesc, DOCS_OPTS));
if (fs.existsSync(TUTDIR)){
  const tdesc = 'Step-by-step Report Manager Designer tutorial: define data access, drop fields, preview the report and integrate it into a Delphi or C++Builder application.';
  results.push(buildIndex(TUTDIR, '/tutorial/index.html', 'Report Manager tutorial: defining data access', tdesc, TUT_OPTS));
}

console.log(`Built ${results.length} pages. Warnings: ${warnings.length}`);
for (const w of warnings) console.log('  ! ' + w);
const carried = results.filter(r => r.extraLd > 0).map(r => r.file);
console.log('Carried-over JSON-LD on: ' + (carried.join(', ') || '(none)'));
