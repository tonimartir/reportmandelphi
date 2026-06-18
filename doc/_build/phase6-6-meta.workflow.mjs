export const meta = {
  name: 'doc-meta-phase6-6',
  description: 'Phase 6.6: write SEO title/description for every built doc page',
  phases: [{ title: 'Prose pages' }, { title: 'Unit reference' }],
}

const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    pages: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        properties: {
          path: { type: 'string' },
          desc: { type: 'string' },
          title: { type: 'string' },
        },
        required: ['path', 'desc'],
      },
    },
  },
  required: ['pages'],
}

const D = 'doc/doc/', U = 'doc/doc/units/', T = 'doc/tutorial/'
const PROSE = [
  ['intro', [D+'index.html', D+'requirements.html', D+'features.html', D+'howitwork.html', D+'interoperability.html', D+'success.html']],
  ['install-core', [D+'installwin.html', D+'delphicomp.html', D+'buildercomp.html', D+'axtivexcomp.html', D+'compileropts.html', D+'deploy.html']],
  ['install-other', [D+'installlin.html', D+'linuxcomp.html', D+'linuxprintreptopdf.html', D+'otherlang.html', D+'visualnetcomp.html', D+'delphinetcomp.html', D+'kylixcomp.html', D+'installwebreport.html', D+'installserver.html', D+'dotnetport.html']],
  ['bindings', [D+'gnuc.html', D+'php.html', D+'python.html', D+'python_bind.html', D+'javascript.html']],
  ['tcp-server', [D+'serverintro.html', D+'serverserver.html', D+'serverclient.html', D+'serverclientcustom.html', D+'serverconfig.html', D+'serversmp.html']],
  ['web-server', [D+'webserverintro.html', D+'webserverinstall.html', D+'webserveroperations.html']],
  ['basic-design', [D+'openingdata.html', D+'droppingfields.html', D+'pageheader.html', D+'reportheader.html', D+'groupheader.html', D+'pagesetup.html', D+'reportgrid.html', D+'preferences.html', D+'usingcompo.html', D+'commandline.html', D+'replibraries.html']],
  ['adv-1', [D+'repparams.html', D+'linkedquerys.html', D+'childsubreports.html', D+'labels.html', D+'externalsec.html', D+'exevaluator.html', D+'barcodes.html', D+'teechart.html']],
  ['adv-2', [D+'internatsupport.html', D+'bidi_behavior.html', D+'htmlformat.html', D+'htmloutput.html', D+'compsiterep.html', D+'dotmatrix.html', D+'openingdatatrouble.html', D+'formfilling.html', D+'customoutput.html', D+'inmemorydata.html', D+'parallel.html', D+'drawfunctions.html']],
  ['comp-ref', [D+'refcommon.html', D+'refcommontext.html', D+'refsubreport.html', D+'refsection.html', D+'reflabel.html', D+'refexpression.html', D+'refdraw.html', D+'refimage.html', D+'refchart.html', D+'refbarcode.html', D+'refdatabaseinfo.html', D+'refdatainfo.html', D+'refparameters.html', D+'refreport.html']],
  ['developer', [D+'licensequestions.html', D+'translation.html', D+'building.html', D+'devdriver.html', D+'pdfoutput.html', D+'units.html', D+'devnotes.html', D+'license.html', D+'left2.html']],
  ['release', [D+'whatisnew.html', D+'faq.html', D+'knownissues.html', D+'mfeatures.html']],
  ['tutorial', [T+'index.html', T+'dropping.html', T+'testing.html', T+'integrating.html']],
]
const UNITS = ['rpactivexreport','rpalias','rpaxreportimp','rpclxreport','rpcompobase','rpdatainfo','rpdataset','rpdrawitem','rpeval','rpevalfunc','rpexpredlg','rpexpredlgvcl','rpgdidriver','rpgdifonts','rpgraphutils','rpgraphutilsvcl','rplabelitem','rplastsav','rpmdbarcode','rpmdchart','rpmdconsts','rpmdshfolder','rpmetafile','rpmreg','rpmunits','rppagesetup','rppagesetupvcl','rpparams','rpparser','rppdfdriver','rppdffile','rppdfreport','rppreview','rpprintitem','rpqtdriver','rpreport','rprfparams','rprfvparams','rpruler','rprulervcl','rpsection','rpsecutil','rpsubreport','rptranslator','rptypes','rptypeval','rpvclreport','rpvgraphutils','rpvpreview','rpwriter'].map(n => U+n+'.html')
const UNIT_BATCHES = [['units-1', UNITS.slice(0,17)], ['units-2', UNITS.slice(17,33)], ['units-3', UNITS.slice(33)]]

function prompt(files, isUnit) {
  return `You write SEO metadata for Report Manager documentation pages. For EACH file listed below, use the Read tool, then look at the current <title> and the <main class="doc-main"> content, and produce:
 - path: exactly as given.
 - desc: a meta description, MAXIMUM 155 characters, plain English, no surrounding quotes. Summarize specifically what THIS page covers so it reads well as a Google search snippet. Do NOT use boilerplate like "Report Manager documentation:" - start with the substance and name the concrete feature, component or task. Never exceed 155 characters.
 - title: OPTIONAL. The page heading is shown as "<title> - Report Manager Docs". Only include a title when the current one (ignoring the " - Report Manager Docs" suffix) is vague, generic, duplicated or unclear; then give a concise, specific, UNIQUE title (max 60 characters; no need to repeat "Report Manager"). If the current title is already clear and specific, OMIT the title field entirely.
${isUnit ? 'These are source-unit reference pages; describe what the unit/class provides. Keep the existing unit-name title (omit title) unless it is empty.' : ''}
Ignore the shared header, sidebar and footer chrome. Be accurate to the page content; never invent features.

Files (${files.length}):
${files.map(f => '  - ' + f).join('\n')}`
}

const prose = await parallel(PROSE.map(([label, files]) => () =>
  agent(prompt(files, false), { label: 'meta:' + label, phase: 'Prose pages', schema: SCHEMA })))
const units = await parallel(UNIT_BATCHES.map(([label, files]) => () =>
  agent(prompt(files, true), { label: 'meta:' + label, phase: 'Unit reference', schema: SCHEMA })))

const pages = [...prose, ...units].filter(Boolean).flatMap(r => r.pages || [])
log('Generated metadata for ' + pages.length + ' pages')
return { pages }
