# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Report Manager — a reporting tool with a runtime engine that compiles on both
Delphi (Windows + Linux) and Lazarus/FPC, plus a Windows VCL designer/preview.
The engine renders to PDF, SVG, HTML, PNG, plain text/CSV, GDI/print, and a
native metafile format. Project home: <https://reportman.es>. Historical
reference: `doc/readme.txt`.

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

### Older Delphi / Kylix / FPC

- `Makefile` (legacy, dcc32 via Kylix `make`) and `GNUmakefile` (Kylix) drive
  command-line `dcc` builds of the packages and tools. These target very old
  toolchains; prefer the group project above for current work.
- Lazarus/FPC: `reportman.lpk` (engine) and `reportman_lcl.lpk` (LCL/visual).
- Multiple per-version Delphi project variants exist
  (`repmandxp.dpr`, `repmandxe2.dpr`, `repmandxp2009.dpr`, …) and matching
  `.dpk` packages (`rppack_del.dpk`, `rppack_delxe2.dpk`, …). Match the one for
  the IDE you're targeting; `rppack_del.dpk` is the canonical non-visual RTL
  package and its `contains` list is the authoritative engine unit inventory.

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
of a local DB connection, brokered through the public Hub at `api.reportman.es`
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
`api.reportman.es` (no local models): SQL chat, expression chat, full-report
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

- Repo + IDE comments/instructions are frequently in Spanish; match the
  surrounding language when editing nearby text.
- When adding engine units, register them in the appropriate `.dpk`/`.lpk`
  `contains`/package list, not just on a project's search path.
- Guard any Windows-only API (WebRTC, GDI, ActiveX) behind `{$IFDEF MSWINDOWS}`
  so the cross-platform engine keeps compiling.
