// Phase 6.3: rewrite bidi_behavior.html (stale Delphi-VCL BiDiMode table w/ mojibake)
// into an accurate page about DirectWrite (Windows) + ICU/HarfBuzz (Linux) shaping.
import fs from 'node:fs';
import path from 'node:path';
const ROOT = path.resolve(import.meta.dirname, '..', '..');
const file = path.join(ROOT, 'doc/doc/bidi_behavior.html');

const TITLE = 'Bidirectional text and complex script shaping';
const BODY = `<h2>Advanced report design</h2>
<h3>Bidirectional text and complex script shaping</h3>
<p>Report Manager renders Unicode text with proper <b>complex-script shaping</b> (ligatures, contextual forms and combining marks) and the Unicode <b>bidirectional (BiDi) algorithm</b>, so right-to-left scripts such as Hebrew and Arabic, and complex scripts such as the Indic languages, are laid out correctly in the preview, on the printer and in exported PDF.</p>

<h3>How shaping is done on each platform</h3>
<p>Shaping and bidi reordering are handled by the native text stack of each platform; the engine then places the resulting glyph runs:</p>
<table border="1">
  <tr><th>Platform / output</th><th>Text engine</th></tr>
  <tr><td>Windows (preview and GDI printing)</td><td>DirectWrite &ndash; shaping, font fallback and the Unicode bidi algorithm.</td></tr>
  <tr><td>Linux</td><td>ICU (Unicode bidi algorithm and normalization) with HarfBuzz (glyph shaping) and FreeType (font handling).</td></tr>
  <tr><td>PDF output (all platforms)</td><td>Uses the same shaping engine and embeds the shaped glyphs with font fallback, so the PDF matches the on-screen layout.</td></tr>
</table>
<p>Complex shaping and bidirectional support are available since version 3.9.15.</p>

<h3>The Bidi Mode property</h3>
<p>Bidirectional behaviour is controlled per component by the <b>Bidi Mode</b> property, available on every text component (labels and expressions). Together with the component <b>horizontal alignment</b> it gives three modes:</p>
<table border="1">
  <tr><th>Bidi Mode</th><th>Reading order and shaping</th><th>Horizontal alignment</th></tr>
  <tr><td><b>No Bidi</b></td><td>No bidi processing and no complex shaping; text is laid out left-to-right exactly as stored. Best for plain Latin text (fastest).</td><td>As set</td></tr>
  <tr><td><b>Partial Bidi</b></td><td>Complex shaping and the Unicode bidi algorithm are enabled, so right-to-left runs are reordered and shaped correctly.</td><td>Kept as you set it</td></tr>
  <tr><td><b>Full Bidi</b></td><td>Same shaping and reordering as Partial Bidi.</td><td>Mirrored &ndash; a left-aligned field becomes right-aligned, matching a right-to-left document.</td></tr>
</table>
<p>Set Bidi Mode to <b>Partial Bidi</b> or <b>Full Bidi</b> on any component that must display Hebrew, Arabic or another complex script; choose <b>Full Bidi</b> when the whole field should follow right-to-left alignment.</p>

<h3>Notes</h3>
<ul>
  <li>The component must use a font that contains the required glyphs; when a glyph is missing, font fallback selects another installed font automatically.</li>
  <li>Mixed text (for example Latin digits inside an Arabic sentence) is ordered by the Unicode bidi algorithm, producing the same result in the preview, on the printer and in PDF.</li>
</ul>
<p>See also <a href="internatsupport.html">International support</a> and the <a href="refcommontext.html">common text component properties</a> for the Bidi Mode and alignment settings.</p>`;

let html = fs.readFileSync(file, 'utf8');
const m = html.match(/<main class="doc-main">[\s\S]*?<\/main>/i);
if (!m) { console.error('no <main> found'); process.exit(1); }
html = html.replace(m[0], `<main class="doc-main">\n<h1>${TITLE}</h1>\n${BODY}\n</main>`);
fs.writeFileSync(file, html, 'utf8');
console.log('rewrote bidi_behavior.html (title + body replaced)');
