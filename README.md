# Report Manager

Reporting tool with Delphi/Lazarus runtime, Windows VCL designer/preview, and
multiplatform reporting engines (PDF, PNG, SVG, HTML, plain text, GDI/print,
metafile). The project home and downloads remain at <https://reportman.es>.

This file documents the **two recent additions** that connect the classic
Delphi product to the newer **Reportman.AI** suite. The historical reference
is in `doc/readme.txt`.

## What's new

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Report Manager (Delphi)                            │
│                                                                          │
│   ┌────────────────────┐         ┌────────────────────────────────┐     │
│   │  Reporting engine  │         │       Designer (Windows)       │     │
│   │  (RTL — Win+Linux) │         │                                │     │
│   │                    │         │   AI Chat: SQL                 │     │
│   │  ┌──────────────┐  │         │   AI Chat: Expressions         │     │
│   │  │ rpdbHttp     │  │         │   AI Chat: Full report design  │     │
│   │  │ "Reportman   │  │         │   Monaco SQL autocomplete      │     │
│   │  │  Agent"      │  │         │                                │     │
│   │  │  driver      │  │         └─────────────┬──────────────────┘     │
│   │  └──────┬───────┘  │                       │                         │
│   └─────────┼──────────┘                       │                         │
│             │                                   │                         │
└─────────────┼───────────────────────────────────┼─────────────────────────┘
              │                                   │
              ▼                                   ▼
   ┌───────────────────────────────────────────────────────────────┐
   │                    Reportman.AI                                │
   │                                                                │
   │  Hub + Agents (host the data)        AI Services (host the     │
   │                                       prompts and schemas)     │
   │  Schemas defined at app.reportman.es ─────────────────────────►│
   └───────────────────────────────────────────────────────────────┘
```

Two completely separate roles. The engine sends and receives data; the
Designer asks the AI to generate or modify reports. They share nothing except
the user's identity at `app.reportman.es`.

## 1. Reportman Agent driver (engine — runtime)

The runtime (RTL package) ships a new data driver, `rpdbHttp`, that talks to
a remote **Reportman DB Agent** instead of a local database connection. The
engine is unchanged — `TRpDatabaseInfoItem.Driver = rpdbHttp` is just one more
choice next to the existing BDE / DBExpress / FireDAC / Zeos / IBX drivers.

What it gives you:

- **Reach any database, from anywhere.** The Agent runs on-premises in the
  customer site and the engine connects to it through the public Hub at
  `api.reportman.es`. No VPN. No port forwarding. The Agent dials *outbound*
  to the Hub and the Hub brokers everything.
- **Drop-in for every Reportman binary that runs reports.** Designer,
  `printreptopdf`, `repwebexe`, classic ActiveX (`reportman.dpr`),
  command-line `printrep`… any executable that uses the report engine inherits
  this driver because it is wired into `rpdatainfo.pas`.
- **Direct P2P data plane when possible.** On Windows, an optional WebRTC
  DataChannel is negotiated through the Hub and the SQL/result rows flow
  client↔Agent directly (DTLS encryption, no proxy on the data plane). When
  the channel can't open (corporate firewall, UDP filtered, …) the driver
  silently falls back to HTTP through the Hub with the exact same semantics.
  See **DataDirect** in the `ReportmanAI/README.md` for the full picture.
- **Linux / FPC stay HTTP-only.** All the WebRTC machinery is wrapped in
  `{$IFDEF MSWINDOWS}`. Cross-platform binaries (the Linux build of
  `printreptopdf`, the Apache `repweb.so`) keep working unchanged.

Relevant source files:

| Unit | Role |
|---|---|
| `rpdatahttp.pas` | The `TRpDatabaseHttp` / `TRpDatasetHttp` classes. Pure HTTP path, multiplatform. |
| `rpdcintegration.pas` | Installs the optional Direct Channel hook. Windows-only; brought in transparently by `rpdatainfo.pas`. |
| `rpdatadirect.pas` | Pascal binding around `libdatachannel` (SCTP-over-DTLS-over-UDP peer). |
| `rpdchub.pas` | Hub signaling client (HTTP + WebSocket) and per-SQL session lifecycle. |
| `rpdcpool.pas` | Per-database session cache so subsequent SQLs reuse the warm channel. |
| `rplibdatachannel.pas` | `libdatachannel.dll` LoadLibrary binding. The DLL is embedded as RC resource and extracted on first use. |

## 2. AI assistance in the Designer

The Designer (Windows, `repmandxp.dpr`) has gained four AI-assisted authoring
features. None of them ships local models — the Designer talks to
`api.reportman.es` and inherits whichever provider that API chose for the
user (Vertex / Gemini / Groq / cloud quantized). The user signs in once with
their `app.reportman.es` account.

### Schemas live in `app.reportman.es`

Every AI feature needs to know which tables / columns / relations exist in
the target database. The Designer does **not** describe a schema by itself.
Instead, the user (or an admin) defines schemas under their account on
`app.reportman.es`. Each schema is bound to one or more Hub databases
(`HubDatabaseId`). The Designer:

1. Logs in with the user's `app.reportman.es` credentials (or an API key
   for headless runs).
2. Fetches the schema available for the current connection's
   `HubDatabaseId`.
3. Feeds that schema as context to the AI for SQL, expressions and
   full-design chat.

This means the AI **already knows** the table names, column types, foreign
keys and any human-written notes the user added on the web — no
per-conversation `CREATE TABLE` dump, no per-query schema discovery.

### The four features

| Feature | What it does | Backed by |
|---|---|---|
| **SQL AI Chat** | Conversational SQL generation and refinement against the active connection's schema. Drop SQL into the dataset definition with one click. | `rpfrmchatvcl.pas` |
| **Expression AI Chat** | Generates Reportman expressions for printable fields, totals, conditional sections, etc., aware of the report's dataset structure. | `rpfrmchatvcl.pas` |
| **Full-design AI Chat** | "Make me a sales-by-region report grouped by quarter" — the AI proposes a complete report (datasets, sections, fields, totals) and applies it to the active document. Round-trips a serialized report to the API for deterministic edits. | `designer-ai-chat-plan.md` documents the architecture; the in-process consumer is the chat unit above. |
| **SQL autocomplete (Monaco)** | Inline autocomplete in the SQL editor while you type, powered by the same schema. Smart suggestions for table names, columns and joins as you write. | `rpfrmmonacoeditorvcl.pas` |

## How Designer and Reportman.AI relate

The two products are independent but they share one user identity (the
`app.reportman.es` account) and one runtime (this repository's engine).
Concretely:

1. **The engine knows the new driver.** The `rpdbHttp` driver above lets
   reports run against any Hub-registered database from any platform. This is
   what makes `Reportman.AI.Desktop`, `Reportman.Web`, `Reportman.Android`
   able to ask the same Agent to execute a SQL with the same wire protocol
   the Delphi tools use.

2. **The Designer consumes AI assistance.** The four chat / autocomplete
   features above all reach `Reportman.AI.Api` for prompt routing and use
   the schemas the user defined on `app.reportman.es`. The Designer never
   talks to a model provider directly — it goes through the API the rest of
   the AI suite already uses.

Nothing else is shared. The Designer is still a stand-alone tool you can use
fully offline against local databases. Reportman.AI is still a stand-alone
suite that does not require the Delphi Designer. The two doors above are the
only crossings.

## See also

- `doc/readme.txt` — historical project description.
- `c:\desarrollo\ReportmanAI\README.md` — Reportman.AI architecture and the
  full DataDirect specification.
- `designer-ai-chat-plan.md` — the design plan for the full-report AI chat.
- `new-report-wizard-plan.md` — the new-report wizard that integrates the
  Agent driver.
