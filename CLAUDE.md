# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Report Manager — a reporting tool with a runtime engine that compiles on both
Delphi (Windows + Linux) and Lazarus/FPC, plus a Windows VCL designer/preview.
The engine renders to PDF, SVG, HTML, PNG, plain text/CSV, GDI/print, and a
native metafile format. Project home: <https://reportman.es>. Historical
reference: `doc/readme.txt`.

## Two remotes: GitHub **and** SourceForge

This repository lives in **two** places and **every change must be pushed to both**
(Toni, 30-09-2026). SourceForge is not an archive: it is the historical home of the
project and the URL that a decade of links, tarballs and documentation point at.

On the deployment VM this is **not left to memory**: `origin` carries two push URLs, so
one `git push` lands on both. Fetch still comes from GitHub only.

    $ git remote -v
    origin   https://github.com/tonimartir/reportmandelphi.git   (fetch)
    origin   https://github.com/tonimartir/reportmandelphi.git   (push)
    origin   ssh://sf-reportman/p/reportman/delphi               (push)

    git push                       # both, in one command
    git push sourceforge master    # the named remote is still there, for pushing one alone

Set up with `git remote set-url --add --push origin <url>` (twice — the first `--add`
replaces the implicit push URL, so **both** have to be named). To undo it, the single
command is `git remote set-url --delete --push origin <the sourceforge url>`.

The HTTPS form SourceForge shows (`https://tonim@git.code.sf.net/p/reportman/delphi`)
asks for the account password on every push, and a step that asks for a password is a
step that gets skipped — which is exactly how the website ended up three months behind.
So the VM uses **SSH** through the `sf-reportman` alias in `~/.ssh/config` with a
dedicated key (`~/.ssh/id_sf_reportman`, registered in the SourceForge account on
30-09-2026). Read access is anonymous either way, which makes
`git ls-remote https://git.code.sf.net/p/reportman/delphi | head -1` the quickest way to
see whether the mirror has fallen behind.

**A failed push to one of them still succeeded on the other.** Git pushes to the URLs in
order and reports the failure, but it does not roll back — so when a push complains, check
which of the two actually landed before assuming nothing did.

**SourceForge refuses non-fast-forward pushes** (`receive.denyNonFastForwards`), and its
interactive shell closed in 2026, so the setting cannot be changed. Rewriting published
history there means: set another default branch in the SF repository Admin, delete `master`
(`git push <sf> :master`), push it again, and set `master` back as default. Better not to
need it: write the commit message in English the first time (see Conventions).

## Deployment

`reportman.es` is served from the machine that builds it, and **the how lives outside this
repository, in a private one**: this repo is public, and deployment notes are internal network
topology — private addresses, ports, paths and which host still carries the mail. That is nobody
else's business and it is not information a public mirror should carry.

What belongs here is the site itself: the web root is **`doc/`** (`index.html`, `company.html`,
`download.html`, their Spanish twins `indexes.html`, `companyes.html`… and the `doc/`, `docnet/`,
`tutorial/` and `training/` folders). **The HTML in the repository *is* the artefact — nothing is
generated at deploy time.** `doc/_build/build-docs.mjs` is an *authoring* tool: it rewrites the
pages **in place**, inside the repository, when the navigation changes, and it is run by hand.

`doc/robots.txt` marks `/_build/` as «not part of the published site», and the deployment honours
that: it is excluded.

## Source layout (important)

The engine source — ~200 `rp*.pas` units — lives in the **repository root**, not
in `repman/`. The project files (`.dpr` / `.dproj` / `.groupproj` / `.dpk` /
`.lpk`) live in subdirectories and reach the root units through their search
paths. So:

- Edit engine code at the repo root (`rpreport.pas`, `rpsection.pas`,
  `rppdfdriver.pas`, etc.).
- Build/compile from the project subdirectory (`repman/`, `server/...`,
  `tests/...`).
- `reportmand7/` and `getit/Source/...` hold *copies* of some units for other
  IDE versions — don't edit those when changing the engine.

## Building

### Designer (Delphi, Windows) — the canonical build

Do **not** compile `repmandxp.dpr` directly with `dcc32`; that produces false
environment/VCL errors that don't reflect the real build. Always build through
the group project. From `c:\desarrollo\prog\toni\reportman\repman`:

```bat
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
"C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" reportmanxe2.groupproj /t:repmandxp /p:Config=Debug /p:Platform=Win32 /nologo /v:m
```

- Group project: `repman/reportmanxe2.groupproj`; designer subtarget: `repmandxp`.
- Default reproducible config: `Debug`, platform `Win32` (x86).
- The group also builds every shipping binary as named MSBuild targets:
  `printreptopdf`, `reportman` (ActiveX OCX), `compilerep`, `metaviewxp`,
  `printrepxp`, `metaprintxp`, `rptranslate`, `WebReportManX`,
  `reportserverappxp`, `repwebexe`, `repserverconfigxp`, `repwebserver`,
  `repserverservice`, `repserviceinstall`. `/t:Build` builds them all.
- Delphi Linux64 (`printreptopdf`, `repwebexe`): `MSBuild <proj>.dproj
  /p:Config=Release /p:Platform=Linux64 /p:PlatformSDK=rocky8.10.sdk` compiles and
  links on Windows against the Linux64 SDK pulled into RAD Studio 13; no PAServer
  needed. `build/sourceforge/01c-build-linux64.ps1` does both. Release builds use
  the **Rocky 8** SDK on purpose: a binary asks for the newest glibc symbol
  versions of the SDK it was linked against, so a Rocky 9 / Ubuntu 22.04+ SDK
  (glibc 2.34) gives binaries that do not start on Red Hat 8. Do not use the
  older RAD Studio 11 install (BDS 22.0) for this.
- SourceForge release: `build/sourceforge/make-release.ps1` (see its README).
- GetIt package (RAD Studio 13 only): `build/getit/make-getit.ps1` syncs
  `getit/Source/Common` from the root, builds the three packages in a clean
  room (no IDE library path) and zips it for Embarcadero's submission form.
  `getit/Source/Common/rpconf.inc` is GetIt's own configuration and is never
  synced (no BDE, Zeos, IBX, TeeChart, Indy or dbExpress). See its README.

### Older Delphi / Kylix / FPC

- `Makefile` (legacy, dcc32 via Kylix `make`) and `GNUmakefile` (Kylix) drive
  command-line `dcc` builds of the packages and tools. These target very old
  toolchains; prefer the group project above for current work.
- Lazarus/FPC: see "Free Pascal / Lazarus port" below. The root `reportman.lpk`
  is the historic (pre-port) engine package and is not maintained.
- Multiple per-version Delphi project variants exist
  (`repmandxp.dpr`, `repmandxe2.dpr`, `repmandxp2009.dpr`, …) and matching
  `.dpk` packages (`rppack_del.dpk`, `rppack_delxe2.dpk`, …). Match the one for
  the IDE you're targeting; `rppack_del.dpk` is the canonical non-visual RTL
  package and its `contains` list is the authoritative engine unit inventory.

### Free Pascal / Lazarus port

Three packages (Lazarus 4.x / FPC 3.2.2), all `RunAndDesignTime`:

- `packages/fpc/reportman_rtl.lpk` — engine (root units + `rtl_fpc/`); requires Zeos.
- `packages/fpc_lcl/reportman_lcl.lpk` — LCL runtime/preview (`lcl/`).
- `packages/fpc_lcl/reportman_designlcl.lpk` — LCL designer (`design_lcl/`).

Build and test from the repo root:

```bat
packages\fpc\build_fpc.bat
C:\lazarus\lazbuild.exe --ws=win32 --no-write-project tests\fpc\LclDesignerTest\LclDesignerTest.lpi
tests\fpc\LclDesignerTest\LclDesignerTest.exe --selftest
```

On Linux use `packages/fpc/build_fpc.sh` (WSL Ubuntu has Lazarus 3.0/gtk2 with
the packages registered). Each package builds in a single pass, as in the IDE /
Online Package Manager; `clean` rebuilds `reportman_rtl` from scratch. Keep it
that way: with FPC 3.2.2 a `System.*` unit (e.g. `System.NetEncoding`) in the
*implementation* uses of an engine unit hides the interface's `System` unit
symbol (`$hiddenSYSTEM`) after the interface CRC was computed, so the units
compiled meanwhile in a cycle (rpsection → rpsubreport → rpsecutil) keep a stale
checksum and dependent packages fail with "Can't find unit rpsecutil" (or FPC
crashes with "Compilation raised exception internally" on incremental builds).
Put such units in the interface uses under `{$IFDEF FPC}` (see `rpsection.pas`,
`rpdrawitem.pas`); `fpc -vu` shows the problem as "Interface CRC changed for
unit". The test projects take engine units from the packages only (no engine
paths in their `.lpi`).

`--selftest` exits 0 on success and 1 on the first `[TEST_FAILED]`; it appends
to `selftest.log`, so read only the last run.

Other FPC deliverables:

- Standalone LCL designer: `repman/lcl_designer/repmandesigner_lcl.lpi` (own
  folder because `repman\TmSchema.pas` shadows the LCL unit; the exe is written
  to `repman\`). `lazbuild --ws=win32 --bm=Release …` on Windows.
- Linux packages are built in Docker inside WSL by
  `build\linux\build-linux.ps1` (output `build\linux\out\<v>\`, gitignored),
  or without WSL by `.github/workflows/linux.yml` (manual `workflow_dispatch`
  only; the same scripts on an Ubuntu runner, packages and `SHA256SUMS` as an
  artifact):
  `reportman-designer` `.deb` + AppImage with Qt6 (recommended; ships a
  private `libQt6Pas` built in the image) and a transitional
  `reportman-designer-gtk2` `.deb`; both widgetsets must pass
  `--selftest`. See `docs/fase6_plan.md` (6.8) and the user guide
  `docs/linux-install.md`.
- Lazarus Online Package Manager zip: `build\opm\make_opm_package.ps1`
  (`docs/opm.md`); it packs only the files in `build/opm/opm_files.txt`, so
  after adding a unit to a package run it with `-RefreshFileList`, then
  `-Validate`.
- `LclSnapshotTest` compares the LCL preview against the PDF driver (exit 1 on
  failure); `PdfTest` covers the PDF driver.
- macOS (LCL Cocoa, Intel and Apple Silicon): `build/macos/setup-toolchain.sh`
  (FPC 3.2.2 + Lazarus 4.8 for the Mac's architecture + Zeos in `~/dev`, no
  sudo; applies `build/macos/patches` to that Lazarus and, with Xcode 15+
  tools, works around FPC 3.2.2's assembler labels and linker crash in
  `fpc.cfg`) and `build/macos/build-deps.sh` (FreeType/HarfBuzz/fontconfig
  and OpenSSL 3.5 dylibs, macOS 10.15 minimum on x86_64 and 11.0 on arm64;
  ICU is the system `libicucore`); both can be re-run and only redo what
  changed. `build/macos/build-designer.sh` builds
  `repman/repmandesigner_lcl.app` (development: it links the executable),
  `build/macos/make-package.sh` the self-contained `.app` and `.dmg` of the
  Mac's architecture (output `build/macos/out/<v>/`, gitignored),
  `build/macos/make-universal.sh` joins an x86_64 and an arm64 `.app` with
  `lipo` into the universal `.dmg`, and `build/macos/opm-check.sh` builds the
  OPM package from its file list (the `-Validate` of macOS).
  `.github/workflows/macos.yml` (manual `workflow_dispatch` only) does all of
  it on `macos-15` (arm64) and `macos-15-intel` and tests the universal
  `.dmg` on both; the designer's `--check-https` tests TLS with the bundled
  OpenSSL. `rpconf.inc` defines `LINUX` for FPC on Darwin (the non-Windows
  engine path); real macOS differences go under `DARWIN`. See
  `docs/macos.md`.

**Shared units rule:** the root `rp*.pas` units are also the Delphi product.
Any change Delphi can see must be a genuine bug fix; all other port work goes
inside `{$IFDEF FPC}` so Delphi compiles exactly the previous code. Watch for
changes the Win32/Win64 build does not catch: global `{$DEFINE}`s in
`rpconf.inc`, FPC-only units in the `{$ELSE}` of `{$IFDEF MSWINDOWS}` (breaks
Delphi Linux64), and UTF-8 BOMs (Delphi projects set no source codepage, so a
BOM-less file is read as cp1252; FPC treats a BOM as `{$codepage utf8}`).

### Server (Docker / Linux)

`server/docker/` builds the report server and `repweb` for Linux/Apache.

## Package / unit tiers

- **RTL (non-visual) engine** — `rppack_del.dpk`: report model, evaluator,
  data drivers, render drivers, serialization. Compiles cross-platform.
- **VCL (visual)** — `rppackvcl_del.dpk`: Windows designer/preview controls.
- **Design-time** — `rppackdesigntime_del.dpk` / `rppackdesignvcl_del.dpk`:
  IDE component registration.

## Architecture

### Report model and rendering

`TRpReport` (`rpreport.pas`) is the document, built from subreports
(`rpsubreport.pas`) → sections (`rpsection.pas`) → print items
(`rpprintitem.pas`, `rplabelitem.pas`, `rpdrawitem.pas`, `rpmdchart.pas`,
`rpmdbarcode.pas`). Expressions are evaluated by `rpeval.pas` / `rpparser.pas` /
`rpevalfunc.pas`. The report is laid out once into a device-independent
**metafile** (`rpmetafile.pas`), then a render driver paints that metafile:
`rppdfdriver.pas` (PDF), `rpsvgdriver.pas` (SVG), `rphtmldriver.pas` (HTML),
`rpgdidriver.pas` (Windows GDI/print), `rptextdriver.pas` / `rpcsvdriver.pas`
(text). Serialization is via `rpwriter.pas` / `rpxmlstream.pas`; reports are
`.rep` files (samples in `repman/repsamples/`).

### Data drivers

`rpdatainfo.pas` is the data-source registry. `TRpDatabaseInfoItem.Driver`
selects a backend: classic BDE / DBExpress / FireDAC / Zeos / IBX, **or** the
newer `rpdbHttp` driver. All shipping report executables inherit whatever is
wired into `rpdatainfo.pas`.

### Reportman Agent driver + DataDirect (recent addition)

`rpdbHttp` (`rpdatahttp.pas`) talks to a remote **Reportman DB Agent** instead
of a local DB connection, brokered by `aiapi.reportman.es` and the public Hub at `hub.reportman.es`
(outbound-only, no VPN). Layers:

- `rpdatahttp.pas` — `TRpDatabaseHttp` / `TRpDatasetHttp`, the pure-HTTP path.
  **Multiplatform.**
- `rpdcintegration.pas` — installs the optional Direct Channel hook;
  transparently pulled in by `rpdatainfo.pas`. **Windows-only.**
- `rpdatadirect.pas` / `rplibdatachannel.pas` — WebRTC DataChannel
  (SCTP-over-DTLS-over-UDP P2P) binding to `libdatachannel.dll`.
- `rpdchub.pas` — Hub signaling (HTTP + WebSocket), per-SQL session lifecycle.
- `rpdcpool.pas` — per-database warm-channel cache.

When the P2P channel can't open (firewall/UDP filtered) the driver silently
falls back to HTTP-through-Hub with identical semantics. **All WebRTC code is
wrapped in `{$IFDEF MSWINDOWS}`** — Linux/FPC builds stay HTTP-only and compile
unchanged. Keep this discipline when touching DataDirect units.

### AI assistance in the Designer (recent addition, Windows)

Four AI-authoring features in `repmandxp.dpr`, all routed through
`aiapi.reportman.es` (no local models): SQL chat, expression chat, full-report
design chat (`rpfrmchatvcl.pas`), and Monaco-editor SQL autocomplete
(`rpfrmmonacoeditorvcl.pas`). Contracts in `rpaireportcontracts.pas`. Schemas
(tables/columns/relations) are defined by the user on `app.reportman.es` and
bound to a Hub database — the Designer fetches them per connection rather than
dumping `CREATE TABLE` per conversation. Design docs:
`designer-ai-chat-plan.md`, `new-report-wizard-plan.md`.

The Agent driver (engine) and the AI features (designer) are independent roles
that share only the `app.reportman.es` user identity — the engine moves data,
the designer asks the AI to author reports.

### Embedded assets

Large binary dependencies are embedded as RC resources and extracted on first
use, not shipped as loose files: `libdatachannel.dll`
(`LibDataChannelAssets.RES`), the Monaco editor (`MonacoEditorAssets.RES`),
WebMarkdown (`WebMarkdownAssets.RES`), and the main `REPORTMANRES.RES`. The
`.rc` source files sit next to each `.RES`.

## Tests

Standalone Delphi test projects under `tests/` (e.g. `datadirect_test/`,
`dchub_test/`, `libdatachannel_test/`, `fastserializer_test/`,
`activex_ai_test/`). Each is its own `.dpr`; several have a `build.bat`. There
is no unified test runner — build and run the relevant project directly.

## Conventions

- **English for everything that goes into git: commit messages, code comments,
  identifiers** — both remotes are public. This overrides any task brief that
  asks for Spanish. Spanish stays only in the Spanish documentation (`docs/*.md`
  written in Spanish, the `*es.html` pages) and in files already written in
  Spanish (e.g. `build/opm/opm_files.txt`).
- No `Co-Authored-By` or any other attribution in commits or PRs.
- When adding engine units, register them in the appropriate `.dpk`/`.lpk`
  `contains`/package list, not just on a project's search path.
- Guard any Windows-only API (WebRTC, GDI, ActiveX) behind `{$IFDEF MSWINDOWS}`
  so the cross-platform engine keeps compiling.
