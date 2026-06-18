// Phase 6.2: rewrite the install/compile pages with a newest-first version matrix.
import fs from 'node:fs';
import path from 'node:path';
const ROOT = path.resolve(import.meta.dirname, '..', '..');

// Replace the <main> body (everything between </h1> and </main>) with new HTML,
// keeping the breadcrumb, the <h1> and the closing </main> intact.
function replaceBody(rel, body) {
  const abs = path.join(ROOT, rel);
  let html = fs.readFileSync(abs, 'utf8');
  const m = html.match(/(<\/h1>\r?\n)([\s\S]*?)(\r?\n<\/main>)/i);
  if (!m) { console.log('NO BODY  ', rel); return; }
  html = html.slice(0, m.index) + m[1] + body.trim() + m[3] + html.slice(m.index + m[0].length);
  fs.writeFileSync(abs, html, 'utf8');
  console.log('REWROTE  ', rel);
}

const DELPHI = String.raw`<h2>Installation</h2>
<h3>Compiling Report Manager using Delphi</h3>
<p>Download the components from SourceForge and unpack them to a directory:</p>
<p><a href="https://sourceforge.net/projects/reportman" target="_blank" rel="noopener">https://sourceforge.net/projects/reportman</a></p>
<p>Report Manager ships ready-to-build packages for every Delphi / RAD Studio release. Pick the packages for your version from the tables below, listed newest first.</p>

<h3>RAD Studio 10.3 Rio and later (recommended)</h3>
<p>Modern releases use one project group per version, under the <code>packages</code> folder. Each group contains three packages:</p>
<ul>
  <li><b>reportman_rtl</b> &ndash; runtime, non-visual engine (reporting and PDF), with no IDE dependencies.</li>
  <li><b>reportman_vcl</b> &ndash; runtime VCL components (requires reportman_rtl).</li>
  <li><b>reportman_designvcl</b> &ndash; the design-time package you install into the IDE (requires reportman_rtl and reportman_vcl).</li>
</ul>
<p>Open the project group for your version, build it, then right-click <b>reportman_designvcl</b> and choose <b>Install</b>:</p>
<table border="1">
  <tr><th>Version</th><th>Project group</th></tr>
  <tr><td>RAD Studio 13</td><td>packages\13.0\reportman.groupproj</td></tr>
  <tr><td>RAD Studio 12 Athens</td><td>packages\12.0\reportman.groupproj</td></tr>
  <tr><td>RAD Studio 11.2 Alexandria</td><td>packages\11.2\reportman.groupproj</td></tr>
  <tr><td>RAD Studio 11 Alexandria</td><td>packages\11.0\reportman.groupproj</td></tr>
  <tr><td>RAD Studio 10.4 Sydney</td><td>packages\10.4\reportman.groupproj</td></tr>
  <tr><td>RAD Studio 10.3 Rio</td><td>packages\10.3\reportman.groupproj</td></tr>
</table>

<h3>Legacy Delphi versions</h3>
<p>Older versions install from the individual package files in the components root directory. Install them in the order shown; for the XE family install the runtime package first and then its design-time package.</p>
<table border="1">
  <tr><th>Version</th><th>Packages (install in this order)</th></tr>
  <tr><td>Delphi 10.2 Tokyo</td><td>rppack_delxe10_2.dpk, then rppack_delxe10_2designtime.dpk</td></tr>
  <tr><td>Delphi 10 Seattle</td><td>rppack_delxe10.dpk, then rppack_delxe10_designtime.dpk</td></tr>
  <tr><td>Delphi XE7</td><td>rppack_delxe7.dpk, then rppack_delxe7_designtime.dpk</td></tr>
  <tr><td>Delphi XE4</td><td>rppack_delxe4.dpk, then rppack_delxe4_designtime.dpk</td></tr>
  <tr><td>Delphi XE3</td><td>rppack_delxe3.dpk, then rppack_delxe3_designtime.dpk</td></tr>
  <tr><td>Delphi XE2</td><td>rppack_delxe2.dpk, then rppack_delxe2_designtime.dpk</td></tr>
  <tr><td>Delphi 2009</td><td>rppack_del2009.dpk (all in one)</td></tr>
  <tr><td>Delphi 2007</td><td>rppack_del2007.dpk (all in one)</td></tr>
  <tr><td>Delphi 2005</td><td>rppack_del2005.dpk (all in one)</td></tr>
  <tr><td>Delphi 7 / 6</td><td>rppack_del.dpk (non-visual), rppackvcl_del.dpk (VCL), rppackdesigntime_del.dpk (design editors), rppackdesignvcl_del.dpk (designer). The CLX packages rppackv_del.dpk and rppackdesign_del.dpk are legacy and optional.</td></tr>
  <tr><td>Delphi 5</td><td>rppack_del5.dpk (all in one, VCL only)</td></tr>
  <tr><td>Delphi 4</td><td>rppack_del4.dpk (all in one)</td></tr>
</table>
<p>Versions not listed above (for example XE5, XE6, XE8 or 10.1 Berlin) can usually be compiled by opening the package of the nearest version and letting the IDE upgrade it.</p>

<h3>General notes</h3>
<p>Before installing, remove the packages of any previous Report Manager version to avoid warnings. After a Delphi update, or after updating a related library (FireDAC, IBX, Indy&hellip;), rebuild and reinstall the packages in the same order.</p>
<p>In the IDE choose <b>File &gt; Open</b>, select the package (or the project group) files, click <b>Build</b> and then <b>Install</b> the design-time package, so you can preview reports without compiling your own application first.</p>
<p>You only need the packages your scenario requires: a console application needs only the runtime engine package; VCL applications also need the VCL package; to embed the designer in your own application install the designer package as well.</p>
<p>You can tailor the build through <a href="compileropts.html">rpconf.inc</a>: if you disable an option you can drop its dependency from the package <code>requires</code> clause (for example, remove the ADO dependency if you disable ADO support), or add support for another data layer such as Zeos.</p>
<p>To compile your own projects, add the Report Manager components directory to the IDE library path. If you build with runtime packages, ship the generated .bpl files with your application.</p>
<p><img src="images/installpack.jpg" width="394" height="258" alt="Installing the Report Manager packages in the Delphi IDE" loading="lazy" decoding="async"></p>
<p>If you have problems, see the <a href="compileropts.html">compilation options</a>.</p>`;

const BUILDER = String.raw`<h2>Installation</h2>
<h3>Compiling Report Manager using C++Builder</h3>
<p>Download the components from SourceForge and unpack them to a directory:</p>
<p><a href="https://sourceforge.net/projects/reportman" target="_blank" rel="noopener">https://sourceforge.net/projects/reportman</a></p>

<h3>RAD Studio 10.3 Rio and later (recommended)</h3>
<p>In modern RAD Studio the C++Builder and Delphi personalities share the same packages. Open the project group for your version under the <code>packages</code> folder, build it, then install the design-time package <b>reportman_designvcl</b> (it pulls in <b>reportman_rtl</b> and <b>reportman_vcl</b>). To call the components from C++ code, add the components directory to the project include and library paths.</p>
<table border="1">
  <tr><th>Version</th><th>Project group</th></tr>
  <tr><td>RAD Studio 13</td><td>packages\13.0\reportman.groupproj</td></tr>
  <tr><td>RAD Studio 12 Athens</td><td>packages\12.0\reportman.groupproj</td></tr>
  <tr><td>RAD Studio 11.2 Alexandria</td><td>packages\11.2\reportman.groupproj</td></tr>
  <tr><td>RAD Studio 11 Alexandria</td><td>packages\11.0\reportman.groupproj</td></tr>
  <tr><td>RAD Studio 10.4 Sydney</td><td>packages\10.4\reportman.groupproj</td></tr>
  <tr><td>RAD Studio 10.3 Rio</td><td>packages\10.3\reportman.groupproj</td></tr>
</table>

<h3>Legacy C++Builder versions</h3>
<p>Open the package files from the components root directory in the C++Builder IDE (<b>File &gt; Open</b>), then build and install them in the order shown.</p>
<table border="1">
  <tr><th>Version</th><th>Packages (install in this order)</th></tr>
  <tr><td>C++Builder 2007</td><td>rppack_builder2007 (all in one)</td></tr>
  <tr><td>C++Builder 6</td><td>rppack_builder6.bpk (non-visual), rppackvcl_builder6.bpk (VCL), rppackdesignvcl_builder6.bpk (designer), rppackdesigntime_builder6.bpk (design editors). The CLX packages rppackv_builder6.bpk and rppackdesign_builder6.bpk are legacy and optional.</td></tr>
  <tr><td>C++Builder 4</td><td>rppack_builder4.bpk (all in one, without report design)</td></tr>
</table>
<p>Add the library <b>shlwapi.lib</b> to your C++Builder project. If you build with runtime packages, ship the generated .bpl files with your application.</p>
<p>You can tailor the build through <a href="compileropts.html">rpconf.inc</a>; if you disable an option you can drop its dependency from the package <code>requires</code> clause, or add support for another data layer such as Zeos (enable {$DEFINE USEZEOS} and add the Z*.bpi files to the requires clause).</p>
<p><img src="images/installpack.jpg" width="394" height="258" alt="Installing the Report Manager packages in the C++Builder IDE" loading="lazy" decoding="async"></p>
<p>Thanks to Cristian A. Bugeiro for the help building the first C++Builder 6 packages.</p>
<p>If you have problems, see the <a href="compileropts.html">compilation options</a>.</p>`;

replaceBody('doc/doc/delphicomp.html', DELPHI);
replaceBody('doc/doc/buildercomp.html', BUILDER);
console.log('install pages rewritten');
