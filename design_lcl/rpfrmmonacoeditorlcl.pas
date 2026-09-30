{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpfrmmonacoeditorlcl.pas                        }
{       Monaco SQL Editor Control for LCL               }
{       (LCL port of rpfrmmonacoeditorvcl)              }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpfrmmonacoeditorlcl;

{ The SQL editor of the dataset configuration, with the API of the VCL
  TFRpMonacoEditorVCL (schema selector, AI toggle and model selection,
  "Audit" page, AI completion bridge), plus the LCL editor API used since
  Phase 4 (TryCreateWebView, SetTheme, OnWebMessage...).

  - Windows: the Monaco page of MonacoEditorAssets.res (the same zip as the
    VCL) in the WebView2 of rplclwebview. Page messages:
      00:  editor ready        01:<sql>  content changed
      02:<id>:<offset>\n<sql>  AI completion request (as the VCL: SuggestSql
           in a worker, answered with window.receiveAICompletions)
      03:<id>:<offset>:<explicit>\n<sql>  schema completion request: sent by
           a completion provider this unit installs in the page with
           ExecuteScript when it is ready (the page is not modified); it is
           answered with the tables and columns of the Hub schema through
           window.rpReceiveSchemaCompletions.
    The messages are handled after the WebView2 callback returns (the VCL
    uses TThread.ForceQueue); ProcessWebMessage handles one directly (tests).
  - Linux, Windows without WebView2 or RPM_FORCE_WEBVIEW_FALLBACK: a SynEdit
    with the SQL highlighter and a TSynCompletion that completes the tables
    and columns of the Hub schema and SQL keywords (Ctrl+Space, and on its
    own after "." and after FROM/JOIN). It also has the AI inline completion
    of Monaco (the VCL falls back to a TMemo without it): after an edit of
    the keyboard (not undo, redo or the accepted suggestion) the text and the
    caret offset go to SuggestSql as a '02:' message would (a comment in
    natural language becomes the SQL that implements it), and the
    first inline item is painted as ghost text at the caret; Tab inserts it
    (one undo step), Esc, typing or moving the caret dismiss it.
  - The tables and columns come from GET api/agent/databases (schemaTables of
    every schema, the list the user edits on app.reportman.es), loaded in a
    TRpAsyncWorker when the schema changes and kept per schema.
  - Threads: TRpAsyncWorker and a TRpAsyncMailbox instead of the VCL
    anonymous threads, TTask and TThread.Queue; the stream cancel is an
    IRpAsyncCancel instead of reading fields of the frame from the thread. }

{$mode delphi}

interface

uses
  Classes, SysUtils, Controls, Graphics, Forms, StdCtrls, ExtCtrls, ComCtrls,
  Buttons, LCLType, Generics.Collections,
  SynEdit, SynEditTypes, SynEditKeyCmds, SynHighlighterSQL, SynCompletion,
  rpjsonfpc, rpauthmanager, rpdatahttp, rpaithreadslcl, rpchatmodernstylelcl,
  rpfrmaiselectionlcl, rplclwebview, rpmdshfolder
  {$IFDEF MSWINDOWS}
  , Windows
  {$ENDIF}
  ;

const
  MonacoAssetsVersion = '3';

type
  TStatusLogEvent = procedure(Sender: TObject; const AStatus: string) of object;
  TAuditSqlEvent = procedure(Sender: TObject) of object;
  TInferenceLogEvent = procedure(Sender: TObject; const ASource,
    AText: string; AAppendLineBreak: Boolean) of object;
  TRpEditorScriptEvent = procedure(Sender: TObject; const AScript: string) of object;

  TRpSqlCompletionKind = (rsckColumn, rsckTable, rsckKeyword);

  TRpSqlCompletionItem = record
    Text: string;
    Detail: string;
    Kind: TRpSqlCompletionKind;
  end;

  TRpSqlCompletionItems = array of TRpSqlCompletionItem;

  TRpSqlSchemaColumn = class(TObject)
  public
    Name: string;
    DataType: string;
    Context: string;
    IsPrimaryKey: Boolean;
  end;

  TRpSqlSchemaTable = class(TObject)
  private
    FColumns: TObjectList<TRpSqlSchemaColumn>;
  public
    Name: string;
    Context: string;
    constructor Create;
    destructor Destroy; override;
    function AddColumn(const AName, ADataType: string): TRpSqlSchemaColumn;
    function ColumnCount: Integer;
    function Column(AIndex: Integer): TRpSqlSchemaColumn;
  end;

  { Tables and columns of a Hub schema }
  TRpSqlSchema = class(TObject)
  private
    FTables: TObjectList<TRpSqlSchemaTable>;
  public
    HubSchemaId: Int64;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Assign(ASource: TRpSqlSchema);
    // schemaTables of GET api/agent/databases:
    // [{"name", "context", "columns":[{"name", "dataType", "isPrimaryKey"...}]}]
    procedure LoadFromJson(ATables: TJSONArray);
    function AddTable(const AName: string): TRpSqlSchemaTable;
    // Case insensitive; also "SCHEMA.TABLE" by its last part
    function FindTable(const AName: string): TRpSqlSchemaTable;
    function TableCount: Integer;
    function Table(AIndex: Integer): TRpSqlSchemaTable;
    procedure GetTableNames(AList: TStrings);
  end;

  { TFRpMonacoEditorLCL }

  TFRpMonacoEditorLCL = class(TCustomControl)
  private
    // Header (VCL GridTopHeader): schema, schema configuration, AI, model
    FPTop: TPanel;
    FComboSchema: TComboBox;
    FPSchemaConfigHost: TPanel;
    FSchemaConfigButton: TRpChatIconButton;
    FAIButton: TSpeedButton;
    FPAISelectionHost: TPanel;
    FAISelection: TFRpAISelectionLCL;
    // Pages
    FPControl: TPageControl;
    FTabSQL: TTabSheet;
    FTabAudit: TTabSheet;
    FPAuditTop: TPanel;
    FBAuditSQL: TButton;
    FMemoAudit: TMemo;
    // Editors
    FWebView: TRpLCLWebView;
    FFallbackEditor: TSynEdit;
    FSqlHighlighter: TSynSQLSyn;
    FCompletion: TSynCompletion;
    FCompletionItems: TRpSqlCompletionItems;
    FCompletionAuto: Boolean;
    FUseFallback: Boolean;
    FEditorReady: Boolean;
    FUpdatingFromBrowser: Boolean;
    FSQL: string;
    FTheme: string;
    FLanguage: string;
    FAssetRootPath: string;
    FNavRetryCount: Integer;
    FLastNavUrl: string;
    FRetryTimer: TTimer;
    FPendingWebMessages: TStringList;
    FWebMessagesQueued: Boolean;
    // Hub context (VCL fields)
    FSchema: string;
    FAuditText: string;
    FBaseHubDatabaseId: Int64;
    FBaseApiKey: string;
    FHubDatabaseId: Int64;
    FHubSchemaId: Int64;
    FSchemaApiKey: string;
    FRuntimeDb: string;
    FLoadingSchemas: Boolean;
    FAuthUIUpdateVersion: Integer;
    FAuthListenerRegistered: Boolean;
    FAuthToken: string;
    FMailbox: TRpAsyncMailbox;
    FMailboxRef: IRpAsyncMailbox;
    // AI completion (02:)
    FDebounceTimer: TTimer;
    FPendingRequestId: string;
    FPendingSql: string;
    FPendingPos: Integer;
    FInferenceRunning: Boolean;
    FActiveInferenceRequestId: string;
    FRestartPendingInference: Boolean;
    FLastAutoCompleteSql: string;
    FInferenceCancel: IRpAsyncCancel;
    FAICompletionCount: Integer;
    // AI inline completion of the fallback editor: FAISuggestion is inserted
    // at FAISuggestionCaret (logical position) when accepted
    FAISuggestion: string;
    FAISuggestionCaret: TPoint;
    FAIRequestSeq: Integer;
    FCommandChangeStamp: Int64;
    // Tables of the schemas
    FSqlSchema: TRpSqlSchema;
    FSchemaCache: TObjectList<TRpSqlSchema>;
    FLoadedSchemaTablesId: Int64;
    FSchemaTablesRequestedId: Int64;
    FSchemaTablesVersion: Integer;
    // Events
    FOnContentChanged: TNotifyEvent;
    FOnWebMessage: TWebMessageReceivedEvent;
    FOnStatusLog: TStatusLogEvent;
    FOnSchemaChanged: TNotifyEvent;
    FOnAuditSql: TAuditSqlEvent;
    FOnStopRequest: TNotifyEvent;
    FOnInferenceLog: TInferenceLogEvent;
    FOnScript: TRpEditorScriptEvent;
    FOnSchemaTablesLoaded: TNotifyEvent;

    procedure BuildControls;
    procedure LogStatus(const AText: string);
    function FindMonacoActualRoot(const ABasePath: string): string;
    function EnsureMonacoAssetsExtracted: string;
    procedure AsyncInitWebView(Data: PtrInt);
    procedure WebViewCreateCompleted(Sender: TObject; AResult: HResult);
    procedure WebViewNavigationCompleted(Sender: TObject; IsSuccess: Boolean);
    procedure WebViewMessageReceived(Sender: TObject; const AMessage: string);
    procedure DeliverWebMessages(Data: PtrInt);
    procedure FallbackEditorChange(Sender: TObject);
    procedure RetryTimerTick(Sender: TObject);
    procedure SetSQL(const Value: string);
    function GetSQL: string;
    procedure SetAuditText(const Value: string);
    procedure SetHubDatabaseId(const Value: Int64);
    procedure SetHubSchemaId(const Value: Int64);
    procedure EmitInferenceLog(const ASource, AText: string;
      AAppendLineBreak: Boolean);
    procedure RunScript(const AScript: string);
    procedure InstallSchemaBridge;
    procedure ApplyFallbackTheme;
    // Header
    procedure LayoutTopControls;
    procedure AIToggleClick(Sender: TObject);
    procedure AISelectionStopRequest(Sender: TObject);
    procedure SchemaConfigClick(Sender: TObject);
    procedure BAuditSQLClick(Sender: TObject);
    procedure ComboSchemaChange(Sender: TObject);
    procedure ClearSchemaItems;
    procedure SelectCurrentSchema;
    procedure ApplyUserSchemas(AList: TStrings);
    procedure ApplyUserAgents(AList: TStrings; const ASelectedTier: string;
      ASelectedAgentAiId: Int64);
    procedure UpdateAuthUI;
    procedure AuthChanged(ASuccess: Boolean);
    procedure HandleAsyncMessage(AMessage: TRpAsyncMessage);
    // AI completion bridge
    procedure HandleAICompletionRequest(const APayload: string);
    procedure QueueAICompletion(const ARequestId, ASql: string; APos: Integer);
    procedure SendAICompletions(const AInlineItemsJson, ACompletionItemsJson,
      ARequestId: string);
    procedure OnDebounceTimer(Sender: TObject);
    procedure StartPendingInference;
    procedure HandleSuggestProgress(AMessage: TRpAsyncMessage);
    procedure HandleSuggestResult(AMessage: TRpAsyncMessage);
    // Schema completion
    procedure HandleSchemaCompletionRequest(const APayload: string);
    procedure UpdateSchemaTables;
    procedure ApplySchemaTables;
    function FindCachedSchema(AHubSchemaId: Int64): TRpSqlSchema;
    procedure HandleSchemaTables(AMessage: TRpAsyncMessage);
    // Fallback completion
    function FallbackTextAndCursor(AForCompletion: Boolean;
      out ACursor: Integer): string;
    procedure FilterCompletionItems;
    procedure CompletionExecute(Sender: TObject);
    procedure CompletionSearchPosition(var APosition: Integer);
    function CompletionPaintItem(const AKey: string; ACanvas: TCanvas;
      X, Y: Integer; Selected: Boolean; Index: Integer): Boolean;
    procedure FallbackCommandHandler(Sender: TObject; AfterProcessing: Boolean;
      var Handled: Boolean; var Command: TSynEditorCommand;
      var AChar: TUTF8Char; Data: Pointer; HandlerData: Pointer);
    procedure AsyncAutoComplete(Data: PtrInt);
    // AI inline completion of the fallback editor
    procedure RequestFallbackAICompletion;
    procedure ShowFallbackAISuggestion(const AInlineItemsJson: string);
    procedure FallbackAfterPaint(Sender: TObject; EventType: TSynPaintEvent;
      const rcClip: TRect);
    procedure FallbackBeforeKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FallbackStatusChanged(Sender: TObject; Changes: TSynStatusChanges);
  protected
    procedure CreateWnd; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure TryCreateWebView;
    procedure LoadSQL(const ASQL: string);
    // Replaces the SQL as an edit the user can undo in the editor (Ctrl+Z);
    // SQL/LoadSQL reset the editor instead
    procedure ApplySQL(const ASQL: string);
    procedure SetTheme(const ATheme: string);
    procedure SetLanguage(const ALang: string);
    procedure ActivateFallback(const AReason: string);
    // VCL API
    procedure SetHubContext(AHubDatabaseId, AHubSchemaId: Int64;
      const ASchemaApiKey: string = '');
    procedure SetSchema(const ASchema: string);
    procedure ClearLog;
    procedure AppendLog(const AText: string);
    procedure ActivateAuditTab;
    procedure SetAuditBusy(AValue: Boolean);
    procedure UpdateAITokens(AInTokens, AOutTokens: Integer;
      const AProgressId: string = ''; APrefillPercent: Integer = 0);
    function GetAITier: string;
    function GetAIMode: string;
    function GetAgentSecret: string;
    function GetAgentAiId: Int64;
    function GetSchemaApiKey: string;
    // LCL additions (hosts and tests)
    // Handles a message of the Monaco page now (normally queued)
    procedure ProcessWebMessage(const AMessage: string);
    // Opens the completion of the fallback editor at the caret
    procedure ExecuteFallbackCompletion(AExplicit: Boolean = True);
    // Loads the schema tables again from the Hub
    procedure ReloadSchemaTables;
    // AI inline completion of the fallback editor (Tab and Esc call them)
    function AISuggestionShown: Boolean;
    function AcceptAISuggestion: Boolean;
    procedure HideAISuggestion;

    property SQL: string read GetSQL write SetSQL;
    property Theme: string read FTheme write SetTheme;
    property Language: string read FLanguage write SetLanguage;
    property EditorReady: Boolean read FEditorReady;
    property UseFallback: Boolean read FUseFallback;
    property AssetRootPath: string read FAssetRootPath;
    property WebView: TRpLCLWebView read FWebView;
    property FallbackEditor: TSynEdit read FFallbackEditor;
    property Completion: TSynCompletion read FCompletion;
    property AuditText: string read FAuditText write SetAuditText;
    property HubDatabaseId: Int64 read FHubDatabaseId write SetHubDatabaseId;
    property HubSchemaId: Int64 read FHubSchemaId write SetHubSchemaId;
    property RuntimeDb: string read FRuntimeDb write FRuntimeDb;
    property AITier: string read GetAITier;
    property AIMode: string read GetAIMode;
    property AgentSecret: string read GetAgentSecret;
    property AgentAiId: Int64 read GetAgentAiId;
    property Schema: string read FSchema;
    // Tables and columns of the selected schema (empty until loaded)
    property SqlSchema: TRpSqlSchema read FSqlSchema;
    property LoadedSchemaTablesId: Int64 read FLoadedSchemaTablesId;
    property ComboSchema: TComboBox read FComboSchema;
    property AISelection: TFRpAISelectionLCL read FAISelection;
    property AIButton: TSpeedButton read FAIButton;
    property SchemaConfigButton: TRpChatIconButton read FSchemaConfigButton;
    property PageControl: TPageControl read FPControl;
    property TabSQL: TTabSheet read FTabSQL;
    property TabAudit: TTabSheet read FTabAudit;
    property AuditButton: TButton read FBAuditSQL;
    property MemoAudit: TMemo read FMemoAudit;
    property InferenceRunning: Boolean read FInferenceRunning;
    // AI completion answers sent to the page (or to the fallback editor)
    property AICompletionCount: Integer read FAICompletionCount;
    // Ghost text of the fallback editor ('' when there is none)
    property AISuggestion: string read FAISuggestion;
    // Delay before an AI completion request (VCL: 1 s)
    property DebounceTimer: TTimer read FDebounceTimer;

    property OnContentChanged: TNotifyEvent read FOnContentChanged write FOnContentChanged;
    property OnWebMessage: TWebMessageReceivedEvent read FOnWebMessage write FOnWebMessage;
    property OnStatusLog: TStatusLogEvent read FOnStatusLog write FOnStatusLog;
    property OnSchemaChanged: TNotifyEvent read FOnSchemaChanged write FOnSchemaChanged;
    property OnAuditSql: TAuditSqlEvent read FOnAuditSql write FOnAuditSql;
    // Stop of the model selection: the host stops what it runs (the audit)
    property OnStopRequest: TNotifyEvent read FOnStopRequest write FOnStopRequest;
    property OnInferenceLog: TInferenceLogEvent read FOnInferenceLog write FOnInferenceLog;
    // Every script run in the page (also without WebView2: tests)
    property OnScript: TRpEditorScriptEvent read FOnScript write FOnScript;
    property OnSchemaTablesLoaded: TNotifyEvent read FOnSchemaTablesLoaded write FOnSchemaTablesLoaded;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
    property TabStop;
    property TabOrder;
  end;

function EscapeJsonString(const S: string): string;

// Completion candidates at ACursor (0 based byte offset in ASql): the columns
// after "alias." or "TABLE.", the tables after FROM/JOIN/INTO/UPDATE (and
// after a comma of a FROM list). Elsewhere, only when AExplicit: the columns
// of the tables of the statement, the tables and, with AKeywords, SQL
// keywords. Not filtered by the identifier being typed. ASchema may be nil.
function RpSqlCompletionItems(ASchema: TRpSqlSchema; const ASql: string;
  ACursor: Integer; AExplicit, AKeywords: Boolean): TRpSqlCompletionItems;
// The identifier being typed before ACursor
function RpSqlCompletionPrefix(const ASql: string; ACursor: Integer): string;
// Monaco offsets count UTF-16 code units; the strings are UTF-8
function RpUtf16OffsetToByteOffset(const S: string; AOffset: Integer): Integer;
function RpByteOffsetToUtf16Offset(const S: string; AByteOffset: Integer): Integer;

implementation

uses
  zipper, StrUtils, Types, rpmdconsts;

{$IFDEF MSWINDOWS}
// Monaco editor assets embedded as the MONACO_ZIP RCDATA resource, the same
// resource used by the VCL editor (MonacoEditorAssets.rc at the repository
// root). The path is relative to this unit, with the exact case of the file
// (cross compiling for Windows from Linux the file system is case sensitive).
{$R ../MonacoEditorAssets.RES}
{$ENDIF}

const
  CMonacoAISelectionWidth = 384;
  CMonacoAIButtonWidth = 46;
  CAICompletionDelayMs = 1000;

  // Completion provider of the schema, installed in the Monaco page when it
  // is ready (the page itself is the one of the VCL, not modified)
  CSchemaBridgeScript =
    '(function () {' +
    ' if (window.rpSchemaBridge) { return; }' +
    ' window.rpSchemaBridge = true;' +
    ' window.rpSchemaRequests = {};' +
    ' window.rpReceiveSchemaCompletions = function (id, items) {' +
    '  var cb = window.rpSchemaRequests[id];' +
    '  if (cb) { delete window.rpSchemaRequests[id]; cb(items || []); }' +
    ' };' +
    ' if (!(window.monaco && window.chrome && window.chrome.webview)) { return; }' +
    ' var K = monaco.languages.CompletionItemKind;' +
    ' var kinds = { column: K.Field, table: K.Struct, keyword: K.Keyword };' +
    ' var order = { column: "1", table: "2", keyword: "3" };' +
    ' ["sql", "pgsql", "mysql"].forEach(function (lang) {' +
    '  monaco.languages.registerCompletionItemProvider(lang, {' +
    '   triggerCharacters: [".", " "],' +
    '   provideCompletionItems: function (model, position, context) {' +
    '    var id = "sc_" + Date.now() + "_" + Math.random().toString(36).substr(2, 6);' +
    '    var explicit = (context && context.triggerKind === 1) ? 0 : 1;' +
    '    var word = model.getWordUntilPosition(position);' +
    '    var range = { startLineNumber: position.lineNumber, endLineNumber: position.lineNumber,' +
    '     startColumn: word.startColumn, endColumn: word.endColumn };' +
    '    return new Promise(function (resolve) {' +
    '     var timer = setTimeout(function () {' +
    '      delete window.rpSchemaRequests[id]; resolve({ suggestions: [] }); }, 3000);' +
    '     window.rpSchemaRequests[id] = function (items) {' +
    '      clearTimeout(timer);' +
    '      resolve({ suggestions: items.map(function (it, i) {' +
    '       return { label: it.label, kind: kinds[it.kind] || K.Text, insertText: it.label,' +
    '        detail: it.detail || "", range: range,' +
    '        sortText: (order[it.kind] || "4") + ("00000" + i).slice(-5) }; }) });' +
    '     };' +
    '     window.chrome.webview.postMessage("03:" + id + ":" + model.getOffsetAt(position) +' +
    '      ":" + explicit + "\n" + model.getValue());' +
    '    });' +
    '   }' +
    '  });' +
    ' });' +
    '})();';

  CSqlKeywords: array[0..39] of string = (
    'SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'NOT', 'IN', 'IS', 'NULL',
    'LIKE', 'BETWEEN', 'EXISTS', 'JOIN', 'INNER', 'LEFT', 'RIGHT', 'OUTER',
    'ON', 'AS', 'GROUP', 'ORDER', 'BY', 'HAVING', 'DISTINCT', 'UNION', 'ALL',
    'CASE', 'WHEN', 'THEN', 'ELSE', 'END', 'ASC', 'DESC', 'COUNT', 'SUM',
    'AVG', 'MIN', 'MAX', 'COALESCE', 'CAST');

type
  TRpMonacoSchemaItem = class(TObject)
  public
    ApiKey: string;
    HubDatabaseId: Int64;
    HubSchemaId: Int64;
    constructor Create(AHubDatabaseId, AHubSchemaId: Int64; const AApiKey: string);
  end;

  // Schemas and agents (VCL TMonacoAuthRefreshPayload)
  TRpMonacoAuthPayload = class(TRpAsyncMessage)
  public
    RequestVersion: Integer;
    SelectedTier: string;
    SelectedAgentAiId: Int64;
    NeedsSchemas: Boolean;
    NeedsAgents: Boolean;
    Schemas: TStringList;
    Agents: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

  TRpMonacoAuthWorker = class(TRpAsyncWorker)
  public
    Token: string;
    InstallId: string;
    BaseApiKey: string;
    RequestVersion: Integer;
    SelectedTier: string;
    SelectedAgentAiId: Int64;
    NeedsSchemas: Boolean;
    NeedsAgents: Boolean;
  protected
    procedure Run; override;
  end;

  TRpMonacoSuggestProgress = class(TRpAsyncMessage)
  public
    RequestId: string;
    Actor: string;
    Stage: string;
    ChunkType: string;
    Chunk: string;
    ProgressId: string;
    InputTokens: Integer;
    OutputTokens: Integer;
    PrefillPercent: Integer;
  end;

  TRpMonacoSuggestResult = class(TRpAsyncMessage)
  public
    RequestId: string;
    InlineItemsJson: string;
    CompletionItemsJson: string;
    UserProfileJson: string;
    InputTokens: Integer;
    OutputTokens: Integer;
  end;

  // SuggestSql (the VCL TTask of StartPendingInference)
  TRpMonacoSuggestWorker = class(TRpAsyncWorker)
  public
    RequestId: string;
    Sql: string;
    CursorPos: Integer;
    ApiKey: string;
    Token: string;
    InstallId: string;
    HubDatabaseId: Int64;
    HubSchemaId: Int64;
    RuntimeDb: string;
    AITier: string;
    AIMode: string;
    AgentSecret: string;
    AgentAiId: Int64;
    Cancel: IRpAsyncCancel;
  protected
    procedure Run; override;
    procedure StreamProgress(Sender: TObject; const AActor, AStage,
      AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
      const AProgressId: string; APrefillPercent: Integer);
    function StreamCancelRequested(Sender: TObject): Boolean;
  end;

  TRpMonacoSchemaTablesPayload = class(TRpAsyncMessage)
  public
    Version: Integer;
    RequestedId: Int64;
    Schemas: TObjectList<TRpSqlSchema>;
    constructor Create;
    destructor Destroy; override;
  end;

  // GET api/agent/databases: schemaTables of every schema of the answer
  TRpMonacoSchemaTablesWorker = class(TRpAsyncWorker)
  public
    Token: string;
    InstallId: string;
    ApiKey: string;
    RequestedId: Int64;
    Version: Integer;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
  end;

  TRpSqlTokenKind = (rstIdent, rstQuoted, rstString, rstNumber, rstSymbol);

  TRpSqlToken = record
    Kind: TRpSqlTokenKind;
    Text: string;
    StartPos: Integer; // 1 based
    EndPos: Integer;   // 1 based, inclusive
  end;

  TRpSqlTableRef = record
    TableName: string;
    Alias: string;
  end;

function EscapeJsonString(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '"';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #8: Result := Result + '\b';
      #9: Result := Result + '\t';
      #10: Result := Result + '\n';
      #12: Result := Result + '\f';
      #13: Result := Result + '\r';
      else
        if Ord(C) < 32 then
          Result := Result + '\u' + IntToHex(Ord(C), 4)
        else
          Result := Result + C;
    end;
  end;
  Result := Result + '"';
end;

function NormalizeLineBreaks(const S: string): string;
begin
  // The same line breaks whichever editor produced the text (VCL '01:')
  Result := StringReplace(S, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #10, #13#10, [rfReplaceAll]);
end;

function JsonText(AObject: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if AObject = nil then
    Exit;
  LValue := AObject.GetValue(AName);
  if (LValue <> nil) and not (LValue is TJSONNull) then
    Result := LValue.Value;
end;

{ SQL completion engine }

function IsSqlIdentChar(C: Char): Boolean; inline;
begin
  Result := (C in ['A'..'Z', 'a'..'z', '0'..'9', '_', '$', '#']) or (Ord(C) >= 128);
end;

procedure TokenizeSql(const ASql: string; AMaxPos: Integer; out ATokens: TArray<TRpSqlToken>);
var
  I, N, LStart, LCount: Integer;
  C, LClose: Char;
  LToken: TRpSqlToken;

  procedure Push(AKind: TRpSqlTokenKind; const AText: string; AStart, AEnd: Integer);
  begin
    LToken.Kind := AKind;
    LToken.Text := AText;
    LToken.StartPos := AStart;
    LToken.EndPos := AEnd;
    if LCount >= Length(ATokens) then
      SetLength(ATokens, LCount * 2 + 16);
    ATokens[LCount] := LToken;
    Inc(LCount);
  end;

begin
  SetLength(ATokens, 0);
  LCount := 0;
  N := Length(ASql);
  if (AMaxPos >= 0) and (AMaxPos < N) then
    N := AMaxPos;
  I := 1;
  while I <= N do
  begin
    C := ASql[I];
    if C <= ' ' then
      Inc(I)
    else if (C = '-') and (I < N) and (ASql[I + 1] = '-') then
    begin
      while (I <= N) and not (ASql[I] in [#10, #13]) do
        Inc(I);
    end
    else if (C = '/') and (I < N) and (ASql[I + 1] = '*') then
    begin
      Inc(I, 2);
      while (I < N) and not ((ASql[I] = '*') and (ASql[I + 1] = '/')) do
        Inc(I);
      Inc(I, 2);
    end
    else if C = '''' then
    begin
      LStart := I;
      Inc(I);
      while I <= N do
      begin
        if ASql[I] = '''' then
        begin
          if (I < N) and (ASql[I + 1] = '''') then
            Inc(I, 2)
          else
            Break;
        end
        else
          Inc(I);
      end;
      Push(rstString, Copy(ASql, LStart, I - LStart + 1), LStart, I);
      Inc(I);
    end
    else if C in ['"', '[', '`'] then
    begin
      if C = '[' then
        LClose := ']'
      else
        LClose := C;
      LStart := I;
      Inc(I);
      while (I <= N) and (ASql[I] <> LClose) do
        Inc(I);
      Push(rstQuoted, Copy(ASql, LStart + 1, I - LStart - 1), LStart, I);
      Inc(I);
    end
    else if IsSqlIdentChar(C) then
    begin
      LStart := I;
      while (I <= N) and IsSqlIdentChar(ASql[I]) do
        Inc(I);
      if C in ['0'..'9'] then
        Push(rstNumber, Copy(ASql, LStart, I - LStart), LStart, I - 1)
      else
        Push(rstIdent, Copy(ASql, LStart, I - LStart), LStart, I - 1);
    end
    else
    begin
      Push(rstSymbol, C, I, I);
      Inc(I);
    end;
  end;
  SetLength(ATokens, LCount);
end;

function IsTableContextKeyword(const AUpper: string): Boolean;
begin
  Result := (AUpper = 'FROM') or (AUpper = 'JOIN') or (AUpper = 'INTO') or
    (AUpper = 'UPDATE') or (AUpper = 'TABLE');
end;

function IsReservedAfterTable(const AUpper: string): Boolean;
const
  CWords: array[0..33] of string = ('WHERE', 'GROUP', 'ORDER', 'HAVING', 'ON',
    'JOIN', 'INNER', 'LEFT', 'RIGHT', 'FULL', 'OUTER', 'CROSS', 'NATURAL',
    'UNION', 'EXCEPT', 'INTERSECT', 'MINUS', 'LIMIT', 'OFFSET', 'FETCH', 'SET',
    'VALUES', 'USING', 'WINDOW', 'FOR', 'SELECT', 'FROM', 'INTO', 'AS', 'WITH',
    'ROWS', 'PLAN', 'RETURNING', 'STRAIGHT_JOIN');
var
  I: Integer;
begin
  for I := Low(CWords) to High(CWords) do
    if AUpper = CWords[I] then
      Exit(True);
  Result := False;
end;

function IsClauseKeyword(const AUpper: string): Boolean;
begin
  Result := (AUpper = 'SELECT') or (AUpper = 'FROM') or (AUpper = 'WHERE') or
    (AUpper = 'GROUP') or (AUpper = 'ORDER') or (AUpper = 'HAVING') or
    (AUpper = 'SET') or (AUpper = 'ON') or (AUpper = 'JOIN') or
    (AUpper = 'VALUES') or (AUpper = 'INTO') or (AUpper = 'UPDATE') or
    (AUpper = 'BY');
end;

// Tables of the FROM/JOIN/INTO/UPDATE clauses with their aliases
procedure CollectTableRefs(const ATokens: TArray<TRpSqlToken>; out ARefs: TArray<TRpSqlTableRef>);
var
  I, J, LDepth, LCount: Integer;
  LUpper, LName, LAlias: string;
  LList: Boolean;

  procedure AddRef(const ATable, AAlias: string);
  begin
    SetLength(ARefs, LCount + 1);
    ARefs[LCount].TableName := ATable;
    ARefs[LCount].Alias := AAlias;
    Inc(LCount);
  end;

  function IsName(AIndex: Integer): Boolean;
  begin
    Result := (AIndex < Length(ATokens)) and
      ((ATokens[AIndex].Kind = rstQuoted) or
      ((ATokens[AIndex].Kind = rstIdent) and
      not IsReservedAfterTable(UpperCase(ATokens[AIndex].Text))));
  end;

  function IsSymbol(AIndex: Integer; C: Char): Boolean;
  begin
    Result := (AIndex < Length(ATokens)) and (ATokens[AIndex].Kind = rstSymbol) and
      (ATokens[AIndex].Text = C);
  end;

begin
  SetLength(ARefs, 0);
  LCount := 0;
  I := 0;
  while I < Length(ATokens) do
  begin
    if ATokens[I].Kind <> rstIdent then
    begin
      Inc(I);
      Continue;
    end;
    LUpper := UpperCase(ATokens[I].Text);
    if not IsTableContextKeyword(LUpper) then
    begin
      Inc(I);
      Continue;
    end;
    LList := LUpper = 'FROM';
    J := I + 1;
    while J < Length(ATokens) do
    begin
      if IsSymbol(J, '(') then
      begin
        // Derived table: skip it, and its alias (its columns are unknown)
        LDepth := 0;
        while J < Length(ATokens) do
        begin
          if IsSymbol(J, '(') then
            Inc(LDepth)
          else if IsSymbol(J, ')') then
          begin
            Dec(LDepth);
            if LDepth = 0 then
              Break;
          end;
          Inc(J);
        end;
        Inc(J);
        if (J < Length(ATokens)) and (ATokens[J].Kind = rstIdent) and
          SameText(ATokens[J].Text, 'AS') then
          Inc(J);
        if IsName(J) then
          Inc(J);
      end
      else if IsName(J) then
      begin
        LName := ATokens[J].Text;
        Inc(J);
        while IsSymbol(J, '.') and (J + 1 < Length(ATokens)) and
          (ATokens[J + 1].Kind in [rstIdent, rstQuoted]) do
        begin
          LName := LName + '.' + ATokens[J + 1].Text;
          Inc(J, 2);
        end;
        LAlias := '';
        if (J < Length(ATokens)) and (ATokens[J].Kind = rstIdent) and
          SameText(ATokens[J].Text, 'AS') then
          Inc(J);
        if IsName(J) then
        begin
          LAlias := ATokens[J].Text;
          Inc(J);
        end;
        AddRef(LName, LAlias);
      end
      else
        Break;
      if LList and IsSymbol(J, ',') then
      begin
        Inc(J);
        Continue;
      end;
      Break;
    end;
    I := J;
  end;
end;

function RpSqlCompletionPrefix(const ASql: string; ACursor: Integer): string;
var
  I: Integer;
begin
  if ACursor > Length(ASql) then
    ACursor := Length(ASql);
  I := ACursor;
  while (I >= 1) and IsSqlIdentChar(ASql[I]) do
    Dec(I);
  Result := Copy(ASql, I + 1, ACursor - I);
end;

function RpSqlCompletionItems(ASchema: TRpSqlSchema; const ASql: string;
  ACursor: Integer; AExplicit, AKeywords: Boolean): TRpSqlCompletionItems;
var
  LCount, LPrefixStart, LQEnd, LQStart, I, J, K: Integer;
  LQualifier, LUpper: string;
  LTokens, LBefore: TArray<TRpSqlToken>;
  LRefs: TArray<TRpSqlTableRef>;
  LTable: TRpSqlSchemaTable;
  LSeen: TStringList;
  LTablesContext: Boolean;
  LLast: TRpSqlToken;

  procedure Add(const AText, ADetail: string; AKind: TRpSqlCompletionKind);
  begin
    if LSeen.IndexOf(AText) >= 0 then
      Exit;
    LSeen.Add(AText);
    SetLength(Result, LCount + 1);
    Result[LCount].Text := AText;
    Result[LCount].Detail := ADetail;
    Result[LCount].Kind := AKind;
    Inc(LCount);
  end;

  procedure AddColumns(ATable: TRpSqlSchemaTable);
  var
    C: Integer;
    LDetail: string;
  begin
    for C := 0 to ATable.ColumnCount - 1 do
    begin
      LDetail := ATable.Name;
      if ATable.Column(C).DataType <> '' then
        LDetail := LDetail + ' ' + ATable.Column(C).DataType;
      Add(ATable.Column(C).Name, LDetail, rsckColumn);
    end;
  end;

  procedure AddTables;
  var
    T: Integer;
  begin
    for T := 0 to ASchema.TableCount - 1 do
      Add(ASchema.Table(T).Name, 'table', rsckTable);
  end;

  function ResolveTable(const AName: string): TRpSqlSchemaTable;
  var
    R: Integer;
  begin
    Result := nil;
    for R := 0 to High(LRefs) do
      if (LRefs[R].Alias <> '') and SameText(LRefs[R].Alias, AName) then
      begin
        Result := ASchema.FindTable(LRefs[R].TableName);
        if Result <> nil then
          Exit;
      end;
    Result := ASchema.FindTable(AName);
  end;

begin
  SetLength(Result, 0);
  LCount := 0;
  if ACursor < 0 then
    ACursor := 0;
  if ACursor > Length(ASql) then
    ACursor := Length(ASql);
  LSeen := TStringList.Create;
  try
    LSeen.CaseSensitive := False;
    LSeen.Sorted := True;
    LPrefixStart := ACursor - Length(RpSqlCompletionPrefix(ASql, ACursor));
    // 1. "qualifier." : columns of that table or alias
    if (LPrefixStart >= 1) and (ASql[LPrefixStart] = '.') then
    begin
      if ASchema = nil then
        Exit;
      LQEnd := LPrefixStart - 1;
      if (LQEnd >= 1) and (ASql[LQEnd] in ['"', ']', '`']) then
      begin
        LQStart := LQEnd - 1;
        while (LQStart >= 1) and not (ASql[LQStart] in ['"', '[', '`']) do
          Dec(LQStart);
        LQualifier := Copy(ASql, LQStart + 1, LQEnd - LQStart - 1);
      end
      else
      begin
        LQStart := LQEnd;
        while (LQStart >= 1) and IsSqlIdentChar(ASql[LQStart]) do
          Dec(LQStart);
        LQualifier := Copy(ASql, LQStart + 1, LQEnd - LQStart);
      end;
      if LQualifier = '' then
        Exit;
      TokenizeSql(ASql, -1, LTokens);
      CollectTableRefs(LTokens, LRefs);
      LTable := ResolveTable(LQualifier);
      if LTable <> nil then
        AddColumns(LTable);
      Exit;
    end;

    // 2. After FROM/JOIN/INTO/UPDATE or a comma of a FROM list: tables
    TokenizeSql(ASql, LPrefixStart, LBefore);
    LTablesContext := False;
    if Length(LBefore) > 0 then
    begin
      LLast := LBefore[High(LBefore)];
      if LLast.Kind = rstIdent then
        LTablesContext := IsTableContextKeyword(UpperCase(LLast.Text))
      else if (LLast.Kind = rstSymbol) and (LLast.Text = ',') then
      begin
        K := 0;
        for I := High(LBefore) downto 0 do
        begin
          if LBefore[I].Kind = rstSymbol then
          begin
            if LBefore[I].Text = ')' then
              Inc(K)
            else if LBefore[I].Text = '(' then
            begin
              if K = 0 then
                Break;
              Dec(K);
            end;
            Continue;
          end;
          if (K = 0) and (LBefore[I].Kind = rstIdent) then
          begin
            LUpper := UpperCase(LBefore[I].Text);
            if IsClauseKeyword(LUpper) then
            begin
              LTablesContext := LUpper = 'FROM';
              Break;
            end;
          end;
        end;
      end;
    end;
    if LTablesContext then
    begin
      if ASchema <> nil then
        AddTables;
      Exit;
    end;

    // 3. Anywhere else, only when asked
    if not AExplicit then
      Exit;
    if ASchema <> nil then
    begin
      TokenizeSql(ASql, -1, LTokens);
      CollectTableRefs(LTokens, LRefs);
      for I := 0 to High(LRefs) do
      begin
        LTable := ASchema.FindTable(LRefs[I].TableName);
        if LTable <> nil then
          AddColumns(LTable);
      end;
      AddTables;
    end;
    if AKeywords then
      for J := Low(CSqlKeywords) to High(CSqlKeywords) do
        Add(CSqlKeywords[J], 'keyword', rsckKeyword);
  finally
    LSeen.Free;
  end;
end;

function RpUtf16OffsetToByteOffset(const S: string; AOffset: Integer): Integer;
var
  I, LUnits, LLen: Integer;
  B: Byte;
begin
  I := 1;
  LUnits := 0;
  while (I <= Length(S)) and (LUnits < AOffset) do
  begin
    B := Ord(S[I]);
    if B < $80 then
      LLen := 1
    else if B < $E0 then
      LLen := 2
    else if B < $F0 then
      LLen := 3
    else
      LLen := 4;
    // Characters out of the BMP are a surrogate pair in UTF-16
    if LLen = 4 then
      Inc(LUnits, 2)
    else
      Inc(LUnits);
    Inc(I, LLen);
  end;
  if I > Length(S) + 1 then
    I := Length(S) + 1;
  Result := I - 1;
end;

function RpByteOffsetToUtf16Offset(const S: string; AByteOffset: Integer): Integer;
begin
  if AByteOffset > Length(S) then
    AByteOffset := Length(S);
  if AByteOffset <= 0 then
    Result := 0
  else
    Result := Length(UTF8Decode(Copy(S, 1, AByteOffset)));
end;

{ TRpSqlSchemaTable }

constructor TRpSqlSchemaTable.Create;
begin
  inherited Create;
  FColumns := TObjectList<TRpSqlSchemaColumn>.Create(True);
end;

destructor TRpSqlSchemaTable.Destroy;
begin
  FColumns.Free;
  inherited Destroy;
end;

function TRpSqlSchemaTable.AddColumn(const AName, ADataType: string): TRpSqlSchemaColumn;
begin
  Result := TRpSqlSchemaColumn.Create;
  Result.Name := AName;
  Result.DataType := ADataType;
  FColumns.Add(Result);
end;

function TRpSqlSchemaTable.ColumnCount: Integer;
begin
  Result := FColumns.Count;
end;

function TRpSqlSchemaTable.Column(AIndex: Integer): TRpSqlSchemaColumn;
begin
  Result := FColumns[AIndex];
end;

{ TRpSqlSchema }

constructor TRpSqlSchema.Create;
begin
  inherited Create;
  FTables := TObjectList<TRpSqlSchemaTable>.Create(True);
end;

destructor TRpSqlSchema.Destroy;
begin
  FTables.Free;
  inherited Destroy;
end;

procedure TRpSqlSchema.Clear;
begin
  FTables.Clear;
  HubSchemaId := 0;
end;

procedure TRpSqlSchema.Assign(ASource: TRpSqlSchema);
var
  I, J: Integer;
  LTable, LSource: TRpSqlSchemaTable;
  LColumn: TRpSqlSchemaColumn;
begin
  Clear;
  if ASource = nil then
    Exit;
  HubSchemaId := ASource.HubSchemaId;
  for I := 0 to ASource.TableCount - 1 do
  begin
    LSource := ASource.Table(I);
    LTable := AddTable(LSource.Name);
    LTable.Context := LSource.Context;
    for J := 0 to LSource.ColumnCount - 1 do
    begin
      LColumn := LTable.AddColumn(LSource.Column(J).Name, LSource.Column(J).DataType);
      LColumn.Context := LSource.Column(J).Context;
      LColumn.IsPrimaryKey := LSource.Column(J).IsPrimaryKey;
    end;
  end;
end;

procedure TRpSqlSchema.LoadFromJson(ATables: TJSONArray);
var
  I, J: Integer;
  LTableJson, LColumnJson: TJSONObject;
  LColumns, LValue: TJSONValue;
  LTable: TRpSqlSchemaTable;
  LColumn: TRpSqlSchemaColumn;
  LType: string;
begin
  FTables.Clear;
  if ATables = nil then
    Exit;
  for I := 0 to ATables.Count - 1 do
  begin
    if not (ATables.Items[I] is TJSONObject) then
      Continue;
    LTableJson := TJSONObject(ATables.Items[I]);
    if Trim(JsonText(LTableJson, 'name')) = '' then
      Continue;
    LTable := AddTable(Trim(JsonText(LTableJson, 'name')));
    LTable.Context := JsonText(LTableJson, 'context');
    LColumns := LTableJson.GetValue('columns');
    if not (LColumns is TJSONArray) then
      Continue;
    for J := 0 to TJSONArray(LColumns).Count - 1 do
    begin
      if not (TJSONArray(LColumns).Items[J] is TJSONObject) then
        Continue;
      LColumnJson := TJSONObject(TJSONArray(LColumns).Items[J]);
      if Trim(JsonText(LColumnJson, 'name')) = '' then
        Continue;
      // dataType is the type the user chose (an enum name, or its number in
      // old answers); detectedType the .NET type seen in the database
      LType := JsonText(LColumnJson, 'dataType');
      if (LType = '') or (LType[1] in ['0'..'9']) then
        LType := JsonText(LColumnJson, 'detectedType');
      if SameText(LType, 'None') then
        LType := '';
      LColumn := LTable.AddColumn(Trim(JsonText(LColumnJson, 'name')), LType);
      LColumn.Context := JsonText(LColumnJson, 'context');
      LValue := LColumnJson.GetValue('isPrimaryKey');
      LColumn.IsPrimaryKey := (LValue is TJSONBool) and TJSONBool(LValue).AsBoolean;
    end;
  end;
end;

function TRpSqlSchema.AddTable(const AName: string): TRpSqlSchemaTable;
begin
  Result := TRpSqlSchemaTable.Create;
  Result.Name := AName;
  FTables.Add(Result);
end;

function TRpSqlSchema.FindTable(const AName: string): TRpSqlSchemaTable;
var
  I, LDot: Integer;
  LShort: string;
begin
  for I := 0 to FTables.Count - 1 do
    if SameText(FTables[I].Name, AName) then
      Exit(FTables[I]);
  // "SCHEMA.TABLE" in the SQL, "TABLE" in the schema (or the other way)
  LDot := LastDelimiter('.', AName);
  LShort := Copy(AName, LDot + 1, MaxInt);
  for I := 0 to FTables.Count - 1 do
  begin
    if SameText(FTables[I].Name, LShort) then
      Exit(FTables[I]);
    LDot := LastDelimiter('.', FTables[I].Name);
    if (LDot > 0) and SameText(Copy(FTables[I].Name, LDot + 1, MaxInt), LShort) then
      Exit(FTables[I]);
  end;
  Result := nil;
end;

function TRpSqlSchema.TableCount: Integer;
begin
  Result := FTables.Count;
end;

function TRpSqlSchema.Table(AIndex: Integer): TRpSqlSchemaTable;
begin
  Result := FTables[AIndex];
end;

procedure TRpSqlSchema.GetTableNames(AList: TStrings);
var
  I: Integer;
begin
  AList.BeginUpdate;
  try
    AList.Clear;
    for I := 0 to FTables.Count - 1 do
      AList.Add(FTables[I].Name);
  finally
    AList.EndUpdate;
  end;
end;

{ TRpMonacoSchemaItem }

constructor TRpMonacoSchemaItem.Create(AHubDatabaseId, AHubSchemaId: Int64;
  const AApiKey: string);
begin
  inherited Create;
  ApiKey := Trim(AApiKey);
  HubDatabaseId := AHubDatabaseId;
  HubSchemaId := AHubSchemaId;
end;

{ Payloads and workers }

constructor TRpMonacoAuthPayload.Create;
begin
  inherited Create;
  Schemas := TStringList.Create;
  Agents := TStringList.Create;
end;

destructor TRpMonacoAuthPayload.Destroy;
begin
  Agents.Free;
  Schemas.Free;
  inherited Destroy;
end;

procedure AddMergedSchemas(ASource, ADest, ASeenKeys: TStrings; const ADefaultApiKey: string);
var
  I: Integer;
  LValue: string;
begin
  for I := 0 to ASource.Count - 1 do
  begin
    LValue := ASource.ValueFromIndex[I];
    if ASeenKeys.IndexOf(LValue) >= 0 then
      Continue;
    ASeenKeys.Add(LValue);
    ADest.Add(ASource.Names[I] + '=' + LValue + '|' + ADefaultApiKey);
  end;
end;

procedure TRpMonacoAuthWorker.Run;
var
  LPayload: TRpMonacoAuthPayload;
  LUserSchemas, LApiKeySchemas, LSeenKeys: TStringList;
  LHttp: TRpDatabaseHttp;
begin
  LPayload := TRpMonacoAuthPayload.Create;
  LUserSchemas := TStringList.Create;
  LApiKeySchemas := TStringList.Create;
  LSeenKeys := TStringList.Create;
  try
    LSeenKeys.Sorted := True;
    LSeenKeys.Duplicates := dupIgnore;
    LPayload.RequestVersion := RequestVersion;
    LPayload.SelectedTier := SelectedTier;
    LPayload.SelectedAgentAiId := SelectedAgentAiId;
    LPayload.NeedsSchemas := NeedsSchemas;
    LPayload.NeedsAgents := NeedsAgents;
    if NeedsSchemas then
    begin
      // The schemas of the API key of the connection first, then the ones
      // of the account (VCL LoadApiKeySchemas + LoadUserSchemas)
      if Trim(BaseApiKey) <> '' then
      begin
        LHttp := TRpDatabaseHttp.Create;
        try
          try
            LHttp.ApiKey := Trim(BaseApiKey);
            LHttp.Token := Token;
            LHttp.InstallId := InstallId;
            if not LHttp.GetUserSchemas(LApiKeySchemas) then
              LApiKeySchemas.Clear;
          except
            LApiKeySchemas.Clear;
          end;
        finally
          LHttp.Free;
        end;
      end;
      if Token <> '' then
      begin
        LHttp := TRpDatabaseHttp.Create;
        try
          try
            LHttp.Token := Token;
            LHttp.InstallId := InstallId;
            if not LHttp.GetUserSchemas(LUserSchemas) then
              LUserSchemas.Clear;
          except
            LUserSchemas.Clear;
          end;
        finally
          LHttp.Free;
        end;
      end;
      AddMergedSchemas(LApiKeySchemas, LPayload.Schemas, LSeenKeys, BaseApiKey);
      AddMergedSchemas(LUserSchemas, LPayload.Schemas, LSeenKeys, '');
    end;
    if NeedsAgents and (Token <> '') then
    begin
      LHttp := TRpDatabaseHttp.Create;
      try
        try
          LHttp.Token := Token;
          LHttp.InstallId := InstallId;
          if not LHttp.GetUserAgents(LPayload.Agents) then
            LPayload.Agents.Clear;
        except
          LPayload.Agents.Clear;
        end;
      finally
        LHttp.Free;
      end;
    end;
    Post(LPayload);
    LPayload := nil;
  finally
    LSeenKeys.Free;
    LApiKeySchemas.Free;
    LUserSchemas.Free;
    LPayload.Free;
  end;
end;

procedure TRpMonacoSuggestWorker.StreamProgress(Sender: TObject; const AActor,
  AStage, AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer);
var
  LMsg: TRpMonacoSuggestProgress;
begin
  if StreamCancelRequested(Sender) then
    Exit;
  LMsg := TRpMonacoSuggestProgress.Create;
  LMsg.RequestId := RequestId;
  LMsg.Actor := AActor;
  LMsg.Stage := AStage;
  LMsg.ChunkType := AChunkType;
  LMsg.Chunk := AChunk;
  LMsg.ProgressId := AProgressId;
  LMsg.InputTokens := AInputTokens;
  LMsg.OutputTokens := AOutputTokens;
  LMsg.PrefillPercent := APrefillPercent;
  Post(LMsg);
end;

function TRpMonacoSuggestWorker.StreamCancelRequested(Sender: TObject): Boolean;
begin
  Result := OwnerGone or ((Cancel <> nil) and Cancel.Cancelled);
end;

function JsonTokenCount(AValue: TJSONValue): Integer;
begin
  Result := 0;
  if (AValue = nil) or (AValue is TJSONNull) then
    Exit;
  if AValue is TJSONNumber then
    Result := TJSONNumber(AValue).AsInt
  else
    Result := StrToIntDef(AValue.Value, 0);
end;

procedure TRpMonacoSuggestWorker.Run;
var
  LHttp: TRpDatabaseHttp;
  LResponse, LResult, LAutoComplete, LItem, LTokenUsage: TJSONObject;
  LInlineItems, LCompletionItems: TJSONArray;
  LVal: TJSONValue;
  LMsg: TRpMonacoSuggestResult;
  I: Integer;
begin
  LResponse := nil;
  LMsg := TRpMonacoSuggestResult.Create;
  LInlineItems := TJSONArray.Create;
  LCompletionItems := TJSONArray.Create;
  LHttp := TRpDatabaseHttp.Create;
  try
    LMsg.RequestId := RequestId;
    LHttp.ApiKey := ApiKey;
    LHttp.Token := Token;
    LHttp.InstallId := InstallId;
    LHttp.HubDatabaseId := HubDatabaseId;
    LHttp.HubSchemaId := HubSchemaId;
    LHttp.RuntimeDb := RuntimeDb;
    LHttp.AITier := AITier;
    LHttp.AgentSecret := AgentSecret;
    LHttp.AgentAiId := AgentAiId;
    try
      LResponse := LHttp.SuggestSql(Sql, CursorPos, AIMode, Self,
        StreamProgress, StreamCancelRequested);
    except
      on E: Exception do
      begin
        TRpAuthManager.Instance.Log('SuggestSql Error: ' + E.Message);
        LResponse := nil;
      end;
    end;
    // Monaco answer: { inlineItems: [...], completionItems: [...] }
    if LResponse <> nil then
    begin
      LVal := LResponse.GetValue('result');
      if LVal is TJSONObject then
      begin
        LResult := TJSONObject(LVal);
        LVal := LResult.GetValue('autoComplete');
        if LVal is TJSONObject then
        begin
          LAutoComplete := TJSONObject(LVal);
          // inlineCompletions: ghost text
          LVal := LAutoComplete.GetValue('inlineCompletions');
          if LVal is TJSONArray then
            for I := 0 to TJSONArray(LVal).Count - 1 do
            begin
              LItem := TJSONObject.Create;
              LItem.AddPair('insertText', TJSONArray(LVal).Items[I].Value);
              LInlineItems.AddElement(LItem);
            end;
          // listCompletions: dropdown
          LVal := LAutoComplete.GetValue('listCompletions');
          if LVal is TJSONArray then
            for I := 0 to TJSONArray(LVal).Count - 1 do
            begin
              LItem := TJSONObject.Create;
              LItem.AddPair('label', TJSONArray(LVal).Items[I].Value);
              LItem.AddPair('insertText', TJSONArray(LVal).Items[I].Value);
              LItem.AddPair('detail', 'AI');
              LCompletionItems.AddElement(LItem);
            end;
        end;
      end;
      LVal := LResponse.GetValue('userProfile');
      if LVal is TJSONObject then
        LMsg.UserProfileJson := LVal.ToJSON;
      LVal := LResponse.GetValue('tokenUsage');
      if LVal = nil then
      begin
        LVal := LResponse.GetValue('result');
        if LVal is TJSONObject then
          LVal := TJSONObject(LVal).GetValue('tokenUsage')
        else
          LVal := nil;
      end;
      if LVal is TJSONObject then
      begin
        LTokenUsage := TJSONObject(LVal);
        LMsg.InputTokens := JsonTokenCount(LTokenUsage.GetValue('inputTokens'));
        LMsg.OutputTokens := JsonTokenCount(LTokenUsage.GetValue('outputTokens'));
      end;
    end;
    LMsg.InlineItemsJson := LInlineItems.ToJSON;
    LMsg.CompletionItemsJson := LCompletionItems.ToJSON;
    Post(LMsg);
    LMsg := nil;
  finally
    LHttp.Free;
    LResponse.Free;
    LCompletionItems.Free;
    LInlineItems.Free;
    LMsg.Free;
  end;
end;

constructor TRpMonacoSchemaTablesPayload.Create;
begin
  inherited Create;
  Schemas := TObjectList<TRpSqlSchema>.Create(True);
end;

destructor TRpMonacoSchemaTablesPayload.Destroy;
begin
  Schemas.Free;
  inherited Destroy;
end;

procedure TRpMonacoSchemaTablesWorker.Run;
var
  LHttp: TRpDatabaseHttp;
  LStream: TStringStream;
  LJson: TJSONValue;
  LDatabases, LTables: TJSONValue;
  LItem: TJSONObject;
  LPayload: TRpMonacoSchemaTablesPayload;
  LSchema: TRpSqlSchema;
  LSchemaId: Int64;
  I: Integer;
begin
  LPayload := TRpMonacoSchemaTablesPayload.Create;
  LHttp := TRpDatabaseHttp.Create;
  LStream := TStringStream.Create('');
  LJson := nil;
  try
    LPayload.Version := Version;
    LPayload.RequestedId := RequestedId;
    LHttp.ApiKey := ApiKey;
    LHttp.Token := Token;
    LHttp.InstallId := InstallId;
    // The same GET the schema list uses; its schemaTables are the tables
    // and columns the user defined for each schema
    if LHttp.InternalGetRequest('api/agent/databases', LStream) then
    begin
      LJson := TJSONObject.ParseJSONValue(LStream.DataString);
      if LJson is TJSONObject then
      begin
        LDatabases := TJSONObject(LJson).GetValue('databases');
        if LDatabases is TJSONArray then
          for I := 0 to TJSONArray(LDatabases).Count - 1 do
          begin
            if not (TJSONArray(LDatabases).Items[I] is TJSONObject) then
              Continue;
            LItem := TJSONObject(TJSONArray(LDatabases).Items[I]);
            LSchemaId := StrToInt64Def(JsonText(LItem, 'hubSchemaId'), 0);
            LTables := LItem.GetValue('schemaTables');
            if (LSchemaId = 0) or not (LTables is TJSONArray) then
              Continue;
            LSchema := TRpSqlSchema.Create;
            LPayload.Schemas.Add(LSchema);
            LSchema.HubSchemaId := LSchemaId;
            LSchema.LoadFromJson(TJSONArray(LTables));
          end;
      end;
    end;
    Post(LPayload);
    LPayload := nil;
  finally
    LJson.Free;
    LStream.Free;
    LHttp.Free;
    LPayload.Free;
  end;
end;

procedure TRpMonacoSchemaTablesWorker.HandleError(E: Exception);
var
  LPayload: TRpMonacoSchemaTablesPayload;
begin
  TRpAuthManager.Instance.Log('Schema tables: ' + E.Message);
  LPayload := TRpMonacoSchemaTablesPayload.Create;
  LPayload.Version := Version;
  LPayload.RequestedId := RequestedId;
  Post(LPayload);
end;

{ TFRpMonacoEditorLCL }

constructor TFRpMonacoEditorLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEditorReady := False;
  FUseFallback := False;
  FUpdatingFromBrowser := False;
  FSQL := '';
  FTheme := 'vs';
  FLanguage := 'sql';
  FNavRetryCount := 0;
  FLastNavUrl := '';
  FPendingWebMessages := TStringList.Create;
  FSqlSchema := TRpSqlSchema.Create;
  FSchemaCache := TObjectList<TRpSqlSchema>.Create(True);
  FMailbox := TRpAsyncMailbox.Create(HandleAsyncMessage);
  FMailboxRef := FMailbox;

  BuildControls;

  // Retry timer
  FRetryTimer := TTimer.Create(Self);
  FRetryTimer.Enabled := False;
  FRetryTimer.Interval := 500;
  FRetryTimer.OnTimer := RetryTimerTick;

  // AI completion debounce (VCL: 1 s)
  FDebounceTimer := TTimer.Create(Self);
  FDebounceTimer.Enabled := False;
  FDebounceTimer.Interval := CAICompletionDelayMs;
  FDebounceTimer.OnTimer := OnDebounceTimer;

  Width := 400;
  Height := 300;

  FAuthToken := TRpAuthManager.Instance.Token;
  RpAuthEvents.AddAuthListener(AuthChanged);
  FAuthListenerRegistered := True;
  UpdateAuthUI;
end;

destructor TFRpMonacoEditorLCL.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  // Workers still running drop their results; the AI stream stops
  FMailbox.Detach;
  if FInferenceCancel <> nil then
    FInferenceCancel.Cancel;
  FInferenceCancel := nil;
  if FAuthListenerRegistered then
    RpAuthEvents.RemoveAuthListener(AuthChanged);
  FAuthListenerRegistered := False;
  if FRetryTimer <> nil then
    FRetryTimer.Enabled := False;
  if FDebounceTimer <> nil then
    FDebounceTimer.Enabled := False;
  if FCompletion <> nil then
    FCompletion.Deactivate;
  if FFallbackEditor <> nil then
  begin
    FFallbackEditor.UnRegisterPaintEventHandler(FallbackAfterPaint);
    FFallbackEditor.UnregisterBeforeKeyDownHandler(FallbackBeforeKeyDown);
    FFallbackEditor.UnRegisterStatusChangedHandler(FallbackStatusChanged);
  end;
  ClearSchemaItems;
  inherited Destroy;
  FSchemaCache.Free;
  FSqlSchema.Free;
  FPendingWebMessages.Free;
  FMailboxRef := nil;
end;

procedure TFRpMonacoEditorLCL.BuildControls;

  function NewPanel(AParent: TWinControl; AAlign: TAlign): TPanel;
  begin
    Result := TPanel.Create(Self);
    Result.Parent := AParent;
    Result.BevelOuter := bvNone;
    Result.Caption := '';
    Result.Align := AAlign;
  end;

begin
  // Header: schema | schema configuration | AI | model selection
  FPTop := NewPanel(Self, alTop);
  FPTop.Height := Scale(40);

  FComboSchema := TComboBox.Create(Self);
  FComboSchema.Parent := FPTop;
  FComboSchema.Style := csDropDownList;
  FComboSchema.OnChange := ComboSchemaChange;
  FComboSchema.Hint := TranslateStr(1528, 'Schema');
  FComboSchema.ShowHint := True;

  FPSchemaConfigHost := NewPanel(FPTop, alNone);
  FSchemaConfigButton := TRpChatIconButton.Create(Self);
  FSchemaConfigButton.Parent := FPSchemaConfigHost;
  FSchemaConfigButton.Align := alClient;
  FSchemaConfigButton.Kind := rpikCog;
  FSchemaConfigButton.Hint := TranslateStr(1496, 'Configure DB Schemas');
  FSchemaConfigButton.ShowHint := True;
  FSchemaConfigButton.OnClick := SchemaConfigClick;

  FAIButton := TSpeedButton.Create(Self);
  FAIButton.Parent := FPTop;
  FAIButton.AllowAllUp := True;
  FAIButton.GroupIndex := 1;
  FAIButton.Caption := 'AI';
  FAIButton.Font.Style := [fsBold];
  FAIButton.Hint := TranslateStr(1555, 'Enable or disable the AI inference');
  FAIButton.ShowHint := True;
  FAIButton.OnClick := AIToggleClick;

  FPAISelectionHost := NewPanel(FPTop, alNone);
  FAISelection := TFRpAISelectionLCL.Create(Self);
  FAISelection.Parent := FPAISelectionHost;
  FAISelection.Align := alNone;
  FAISelection.ShowGauge := False;
  FAISelection.OnStopRequest := AISelectionStopRequest;

  // Pages: SQL editor and audit
  FPControl := TPageControl.Create(Self);
  FPControl.Parent := Self;
  FPControl.Align := alClient;

  FTabSQL := TTabSheet.Create(FPControl);
  FTabSQL.PageControl := FPControl;
  FTabSQL.Caption := TranslateStr(1552, 'SQL editor');

  FTabAudit := TTabSheet.Create(FPControl);
  FTabAudit.PageControl := FPControl;
  FTabAudit.Caption := TranslateStr(1553, 'Audit');

  FPAuditTop := NewPanel(FTabAudit, alTop);
  FPAuditTop.Height := Scale(34);
  FPAuditTop.BorderSpacing.Around := Scale(2);
  FBAuditSQL := TButton.Create(Self);
  FBAuditSQL.Parent := FPAuditTop;
  FBAuditSQL.Align := alLeft;
  FBAuditSQL.AutoSize := True;
  FBAuditSQL.Caption := TranslateStr(1554, 'Audit SQL');
  FBAuditSQL.OnClick := BAuditSQLClick;

  FMemoAudit := TMemo.Create(Self);
  FMemoAudit.Parent := FTabAudit;
  FMemoAudit.Align := alClient;
  FMemoAudit.ReadOnly := True;
  FMemoAudit.WordWrap := True;
  FMemoAudit.ScrollBars := ssAutoVertical;

  // Fallback editor (hidden until ActivateFallback): SynEdit with the SQL
  // highlighter and the schema completion
  FSqlHighlighter := TSynSQLSyn.Create(Self);
  FSqlHighlighter.SQLDialect := sqlStandard;

  FFallbackEditor := TSynEdit.Create(Self);
  FFallbackEditor.Parent := FTabSQL;
  FFallbackEditor.Align := alClient;
  FFallbackEditor.Visible := False;
  FFallbackEditor.Highlighter := FSqlHighlighter;
{$IFDEF MSWINDOWS}
  FFallbackEditor.Font.Name := 'Consolas';
{$ELSE}
  FFallbackEditor.Font.Name := 'Monospace';
{$ENDIF}
  FFallbackEditor.Font.Size := 10;
  // SynEdit defaults to fqNonAntialiased (SynDefaultFontQuality): with Qt6
  // the text comes out aliased and cramped; follow the desktop setting as
  // the rest of the controls do
  FFallbackEditor.Font.Quality := fqDefault;
  FFallbackEditor.Options := FFallbackEditor.Options + [eoTabsToSpaces] -
    [eoScrollPastEol, eoSmartTabs];
  FFallbackEditor.TabWidth := 2;
  FFallbackEditor.RightEdge := -1;
  FFallbackEditor.OnChange := FallbackEditorChange;
  FFallbackEditor.RegisterCommandHandler(FallbackCommandHandler, nil,
    [hcfPreExec, hcfPostExec]);
  // AI inline completion: ghost text painted over the editor, Tab/Esc
  FFallbackEditor.RegisterPaintEventHandler(FallbackAfterPaint, [peAfterPaint]);
  FFallbackEditor.RegisterBeforeKeyDownHandler(FallbackBeforeKeyDown);
  FFallbackEditor.RegisterStatusChangedHandler(FallbackStatusChanged,
    [scCaretX, scCaretY, scFocus, scTopLine, scLeftChar]);

  FCompletion := TSynCompletion.Create(Self);
  FCompletion.Editor := FFallbackEditor;
  FCompletion.OnExecute := CompletionExecute;
  FCompletion.OnSearchPosition := CompletionSearchPosition;
  FCompletion.OnPaintItem := CompletionPaintItem;
  FCompletion.EndOfTokenChr := '()[].,;=<>+-*/''"';
  FCompletion.Width := Scale(360);
  FCompletion.LinesInWindow := 10;

  // WebView2 (Monaco)
  FWebView := TRpLCLWebView.Create(Self);
  FWebView.Parent := FTabSQL;
  FWebView.Align := alClient;
  FWebView.Visible := True;
  FWebView.OnCreateWebViewCompleted := WebViewCreateCompleted;
  FWebView.OnNavigationCompleted := WebViewNavigationCompleted;
  FWebView.OnWebMessageReceived := WebViewMessageReceived;

  FPControl.ActivePage := FTabSQL;
  LayoutTopControls;
end;

procedure TFRpMonacoEditorLCL.LogStatus(const AText: string);
begin
  if Assigned(FOnStatusLog) then
    FOnStatusLog(Self, AText);
{$IFDEF MSWINDOWS}
  OutputDebugString(PChar('MonacoLCL: ' + AText));
{$ENDIF}
end;

function TFRpMonacoEditorLCL.FindMonacoActualRoot(const ABasePath: string): string;
begin
  if FileExists(ABasePath + DirectorySeparator + 'index.html') or
     FileExists(ABasePath + DirectorySeparator + 'Index.html') then
    Result := ABasePath
  else if FileExists(ABasePath + DirectorySeparator + 'MonacoEditor' + DirectorySeparator + 'index.html') or
          FileExists(ABasePath + DirectorySeparator + 'MonacoEditor' + DirectorySeparator + 'Index.html') then
    Result := ABasePath + DirectorySeparator + 'MonacoEditor'
  else
    Result := '';
end;

function TFRpMonacoEditorLCL.EnsureMonacoAssetsExtracted: string;
var
  LBasePath, LVersionPath, LActualRoot: string;
  LZipCandidates: array[0..1] of string;
  LZipFound: string;
  LTempZip: string;
  I: Integer;
  LUnZipper: TUnZipper;
  LVerStr: string;
  LStrList: TStringList;
{$IFDEF MSWINDOWS}
  LResStream: TResourceStream;
  LFileStream: TFileStream;
{$ENDIF}
begin
  LBasePath := ObtainFolderLocalUserConfig('Reportman', 'Monaco', 'MonacoEditor');
  LVersionPath := LBasePath + DirectorySeparator + 'assets.version';

  LActualRoot := FindMonacoActualRoot(LBasePath);
  if (LActualRoot <> '') and FileExists(LVersionPath) then
  begin
    LStrList := TStringList.Create;
    try
      LStrList.LoadFromFile(LVersionPath);
      LVerStr := Trim(LStrList.Text);
      if SameText(LVerStr, MonacoAssetsVersion) then
      begin
        Result := LActualRoot;
        Exit;
      end;
    finally
      LStrList.Free;
    end;
  end;

  LZipFound := '';
  LTempZip := '';
{$IFDEF MSWINDOWS}
  // 1. Embedded resource, like rpfrmmonacoeditorvcl
  if FindResource(HInstance, 'MONACO_ZIP', Windows.RT_RCDATA) <> 0 then
  begin
    ForceDirectories(LBasePath);
    LTempZip := LBasePath + DirectorySeparator + 'MonacoEditor.zip.tmp';
    LResStream := TResourceStream.Create(HInstance, 'MONACO_ZIP', Windows.RT_RCDATA);
    try
      LFileStream := TFileStream.Create(LTempZip, fmCreate);
      try
        LFileStream.CopyFrom(LResStream, 0);
      finally
        LFileStream.Free;
      end;
    finally
      LResStream.Free;
    end;
    LZipFound := LTempZip;
  end;
{$ENDIF}

  // 2. MonacoEditor.zip shipped next to the executable
  if LZipFound = '' then
  begin
    LZipCandidates[0] := ExtractFilePath(ParamStr(0)) + 'MonacoEditor.zip';
    LZipCandidates[1] := ExtractFilePath(ParamStr(0)) + 'MonacoEditor' + DirectorySeparator + 'MonacoEditor.zip';
    for I := 0 to High(LZipCandidates) do
    begin
      if FileExists(LZipCandidates[I]) then
      begin
        LZipFound := LZipCandidates[I];
        Break;
      end;
    end;
  end;
  if LZipFound = '' then
    LogStatus('Monaco assets not found (no MONACO_ZIP resource nor MonacoEditor.zip next to the executable)');

  if LZipFound <> '' then
  begin
    LogStatus('Extracting Monaco assets from ' + LZipFound + ' to ' + LBasePath);
    ForceDirectories(LBasePath);
    LUnZipper := TUnZipper.Create;
    try
      LUnZipper.FileName := LZipFound;
      LUnZipper.OutputPath := LBasePath;
      LUnZipper.Examine;
      LUnZipper.UnZipAllFiles;
    finally
      LUnZipper.Free;
      if (LTempZip <> '') and FileExists(LTempZip) then
        SysUtils.DeleteFile(LTempZip);
    end;

    LStrList := TStringList.Create;
    try
      LStrList.Text := MonacoAssetsVersion;
      LStrList.SaveToFile(LVersionPath);
    finally
      LStrList.Free;
    end;
  end;

  LActualRoot := FindMonacoActualRoot(LBasePath);
  if LActualRoot = '' then
    LActualRoot := LBasePath;

  Result := LActualRoot;
end;

procedure TFRpMonacoEditorLCL.TryCreateWebView;
var
  LDestPath: string;
  LDllCandidate: string;
begin
  if FUseFallback or FWebView.WebViewCreated or FWebView.WebViewCreating then
    Exit;

  try
    if FAssetRootPath = '' then
      FAssetRootPath := EnsureMonacoAssetsExtracted;

    LDestPath := ObtainFolderLocalUserConfig('Reportman', 'Monaco', '');
    FWebView.UserDataFolder := LDestPath + DirectorySeparator + 'EdgeData';

    // Locate WebView2Loader.dll
{$IFDEF CPU64}
    LDllCandidate := FAssetRootPath + DirectorySeparator + 'x64' + DirectorySeparator + 'WebView2Loader.dll';
{$ELSE}
    LDllCandidate := FAssetRootPath + DirectorySeparator + 'x86' + DirectorySeparator + 'WebView2Loader.dll';
{$ENDIF}

    if FileExists(LDllCandidate) then
      FWebView.LoaderDllPath := LDllCandidate;

    LogStatus('Initializing WebView2 from ' + FWebView.LoaderDllPath);
    if not FWebView.CreateWebView then
      ActivateFallback('WebView2 initialization failed');
  except
    on E: Exception do
      ActivateFallback('TryCreateWebView exception: ' + E.Message);
  end;
end;

procedure TFRpMonacoEditorLCL.AsyncInitWebView(Data: PtrInt);
begin
  if not (csDestroying in ComponentState) then
    TryCreateWebView;
end;

procedure TFRpMonacoEditorLCL.CreateWnd;
begin
  inherited CreateWnd;

  if FUseFallback then
    Exit;

{$IFDEF MSWINDOWS}
  if SysUtils.GetEnvironmentVariable('RPM_FORCE_WEBVIEW_FALLBACK') <> '' then
  begin
    ActivateFallback('Forced by RPM_FORCE_WEBVIEW_FALLBACK');
    Exit;
  end;

  Application.QueueAsyncCall(AsyncInitWebView, 0);
{$ELSE}
  // No WebView2 out of Windows: the SynEdit editor is the editor
  ActivateFallback('WebView2 is only available on Windows');
{$ENDIF}
end;

procedure TFRpMonacoEditorLCL.Resize;
begin
  inherited Resize;
  LayoutTopControls;
end;

procedure TFRpMonacoEditorLCL.LayoutTopControls;
var
  LHeaderHeight, LComboHeight, LButtonSize, LAIWidth, LRight, LTop, LComboWidth: Integer;
begin
  if (FPTop = nil) or (FAISelection = nil) or (csDestroying in ComponentState) then
    Exit;
  LComboHeight := FComboSchema.Height;
  if LComboHeight <= 0 then
    LComboHeight := Scale(24);
  LHeaderHeight := LComboHeight + Scale(10);
  if FAISelection.Visible and (FAISelection.PreferredHeight > LHeaderHeight) then
    LHeaderHeight := FAISelection.PreferredHeight;
  if FPTop.Height <> LHeaderHeight then
    FPTop.Height := LHeaderHeight;

  LRight := FPTop.ClientWidth;
  if LRight <= 0 then
    Exit;
  // Model selection at the right (VCL: 384 px column)
  if FAISelection.Visible then
  begin
    LAIWidth := Scale(CMonacoAISelectionWidth);
    if LAIWidth > LRight div 2 then
      LAIWidth := LRight div 2;
    FPAISelectionHost.Visible := True;
    FPAISelectionHost.SetBounds(LRight - LAIWidth, 0, LAIWidth, LHeaderHeight);
    FAISelection.SetBounds(0, 0, LAIWidth - Scale(4), LHeaderHeight);
    FAISelection.RefreshLayout;
    Dec(LRight, LAIWidth + Scale(4));
  end
  else
    FPAISelectionHost.Visible := False;

  // AI toggle
  LButtonSize := LComboHeight + Scale(4);
  LTop := (LHeaderHeight - LButtonSize) div 2;
  FAIButton.SetBounds(LRight - Scale(CMonacoAIButtonWidth), LTop,
    Scale(CMonacoAIButtonWidth), LButtonSize);
  Dec(LRight, Scale(CMonacoAIButtonWidth) + Scale(4));

  // Schema configuration button
  FPSchemaConfigHost.SetBounds(LRight - LButtonSize, LTop, LButtonSize, LButtonSize);
  Dec(LRight, LButtonSize + Scale(4));

  // Schema combo takes the rest
  LComboWidth := LRight - Scale(4);
  if LComboWidth < Scale(40) then
    LComboWidth := Scale(40);
  FComboSchema.SetBounds(Scale(4), (LHeaderHeight - LComboHeight) div 2,
    LComboWidth, LComboHeight);
end;

procedure TFRpMonacoEditorLCL.WebViewCreateCompleted(Sender: TObject; AResult: HResult);
var
  LURL: string;
begin
  // Succeeded() lives in the Windows unit; HResult success is simply >= 0
  if AResult >= 0 then
  begin
    LogStatus('WebView2 created successfully.');
    if FAssetRootPath = '' then
      FAssetRootPath := EnsureMonacoAssetsExtracted;

    LURL := 'file:///' + StringReplace(FAssetRootPath, '\', '/', [rfReplaceAll]);
    if not (LURL[Length(LURL)] in ['/', '\']) then
      LURL := LURL + '/';
    LURL := LURL + 'Index.html';

    FLastNavUrl := LURL;
    FNavRetryCount := 0;
    LogStatus('Navigating to ' + LURL);
    FWebView.Navigate(LURL);
  end
  else
  begin
    LogStatus('WebView2 creation failed (HRESULT ' + IntToHex(AResult, 8) + ')');
    ActivateFallback('WebView2 create failed: ' + IntToHex(AResult, 8));
  end;
end;

procedure TFRpMonacoEditorLCL.WebViewNavigationCompleted(Sender: TObject; IsSuccess: Boolean);
begin
  if IsSuccess then
  begin
    LogStatus('Monaco Index.html navigation completed successfully.');
    FNavRetryCount := 0;
  end
  else
  begin
    LogStatus('Monaco navigation failed (retry ' + IntToStr(FNavRetryCount) + ')');
    if FNavRetryCount < 3 then
    begin
      Inc(FNavRetryCount);
      FRetryTimer.Enabled := False;
      FRetryTimer.Interval := 300 * FNavRetryCount;
      FRetryTimer.Enabled := True;
    end
    else
      ActivateFallback('Navigation failed permanently.');
  end;
end;

procedure TFRpMonacoEditorLCL.RetryTimerTick(Sender: TObject);
begin
  FRetryTimer.Enabled := False;
  if FUseFallback then
    Exit;
  if not FWebView.WebViewCreated then
    TryCreateWebView
  else if FLastNavUrl <> '' then
    FWebView.Navigate(FLastNavUrl);
end;

procedure TFRpMonacoEditorLCL.WebViewMessageReceived(Sender: TObject; const AMessage: string);
begin
  // Handled once the WebView2 callback has returned (the VCL uses
  // TThread.ForceQueue): the handlers run scripts and host events
  FPendingWebMessages.Add(AMessage);
  if not FWebMessagesQueued then
  begin
    FWebMessagesQueued := True;
    Application.QueueAsyncCall(DeliverWebMessages, 0);
  end;
end;

procedure TFRpMonacoEditorLCL.DeliverWebMessages(Data: PtrInt);
var
  LMessages: TStringList;
  I: Integer;
begin
  FWebMessagesQueued := False;
  LMessages := TStringList.Create;
  try
    LMessages.Assign(FPendingWebMessages);
    FPendingWebMessages.Clear;
    for I := 0 to LMessages.Count - 1 do
    begin
      if csDestroying in ComponentState then
        Exit;
      ProcessWebMessage(LMessages[I]);
    end;
  finally
    LMessages.Free;
  end;
end;

procedure TFRpMonacoEditorLCL.ProcessWebMessage(const AMessage: string);
var
  LNewSQL, LPrefix: string;
begin
  LogStatus('Message from Monaco: ' + Copy(AMessage, 1, 60));

  if Assigned(FOnWebMessage) then
    FOnWebMessage(Self, AMessage);

  if FUpdatingFromBrowser then
    Exit;

  LPrefix := Copy(AMessage, 1, 3);
  if LPrefix = '00:' then
  begin
    // Monaco editor initialized and ready
    FEditorReady := True;
    LogStatus('Monaco Editor ready signal (00:) received. Pushing SQL...');
    InstallSchemaBridge;
    SetSQL(FSQL);
    if FTheme <> 'vs' then
      SetTheme(FTheme);
    if FLanguage <> 'sql' then
      SetLanguage(FLanguage);
    Exit;
  end;

  if LPrefix = '02:' then
  begin
    HandleAICompletionRequest(Copy(AMessage, 4, MaxInt));
    Exit;
  end;

  if LPrefix = '03:' then
  begin
    HandleSchemaCompletionRequest(Copy(AMessage, 4, MaxInt));
    Exit;
  end;

  if LPrefix <> '01:' then
    Exit;

  // Content changed in Monaco; JS uses \n, the SQL of the reports \r\n
  LNewSQL := NormalizeLineBreaks(Copy(AMessage, 4, MaxInt));
  if FSQL <> LNewSQL then
  begin
    FUpdatingFromBrowser := True;
    try
      FSQL := LNewSQL;
      if Assigned(FOnContentChanged) then
        FOnContentChanged(Self);
    finally
      FUpdatingFromBrowser := False;
    end;
  end;
end;

procedure TFRpMonacoEditorLCL.RunScript(const AScript: string);
begin
  if Assigned(FOnScript) then
    FOnScript(Self, AScript);
  if (FWebView <> nil) and FWebView.WebViewCreated then
    FWebView.ExecuteScript(AScript);
end;

procedure TFRpMonacoEditorLCL.InstallSchemaBridge;
begin
  RunScript(CSchemaBridgeScript);
end;

procedure TFRpMonacoEditorLCL.FallbackEditorChange(Sender: TObject);
var
  LNewSQL: string;
  LCursor: Integer;
begin
  if (not FUseFallback) or FUpdatingFromBrowser then
    Exit;
  HideAISuggestion;
  // \r\n as the text typed in Monaco ('01:')
  LNewSQL := FallbackTextAndCursor(False, LCursor);
  if FSQL <> LNewSQL then
  begin
    FUpdatingFromBrowser := True;
    try
      FSQL := LNewSQL;
      if Assigned(FOnContentChanged) then
        FOnContentChanged(Self);
    finally
      FUpdatingFromBrowser := False;
    end;
  end;
end;

procedure TFRpMonacoEditorLCL.SetSQL(const Value: string);
begin
  if FUpdatingFromBrowser then
    Exit;

  FSQL := Value;

  if FUseFallback then
  begin
    FUpdatingFromBrowser := True;
    try
      FFallbackEditor.Text := FSQL;
    finally
      FUpdatingFromBrowser := False;
    end;
    Exit;
  end;

  if FEditorReady then
    RunScript('if (window.editor) { window.editor.setValue(' + EscapeJsonString(FSQL) + '); }');
end;

procedure TFRpMonacoEditorLCL.ApplySQL(const ASQL: string);
var
  LEnd: TPoint;
begin
  if FUpdatingFromBrowser then
    Exit;
  FSQL := NormalizeLineBreaks(ASQL);
  if FUseFallback then
  begin
    // One undoable edit of the whole text
    FUpdatingFromBrowser := True;
    try
      FFallbackEditor.BeginUndoBlock;
      try
        if FFallbackEditor.Lines.Count = 0 then
          LEnd := Types.Point(1, 1)
        else
          LEnd := Types.Point(Length(FFallbackEditor.Lines[FFallbackEditor.Lines.Count - 1]) + 1,
            FFallbackEditor.Lines.Count);
        FFallbackEditor.TextBetweenPointsEx[Types.Point(1, 1), LEnd, scamEnd] :=
          StringReplace(FSQL, #13#10, LineEnding, [rfReplaceAll]);
      finally
        FFallbackEditor.EndUndoBlock;
      end;
    finally
      FUpdatingFromBrowser := False;
    end;
    Exit;
  end;
  // executeEdits keeps the undo stack of Monaco (setValue clears it)
  if FEditorReady then
    RunScript('if (window.editor) { var m = window.editor.getModel();' +
      ' window.editor.pushUndoStop();' +
      ' window.editor.executeEdits("reportman-ai", [{ range: m.getFullModelRange(), text: ' +
      EscapeJsonString(FSQL) + ', forceMoveMarkers: true }]);' +
      ' window.editor.pushUndoStop(); }');
end;

function TFRpMonacoEditorLCL.GetSQL: string;
begin
  Result := FSQL;
end;

procedure TFRpMonacoEditorLCL.LoadSQL(const ASQL: string);
begin
  SetSQL(ASQL);
end;

procedure TFRpMonacoEditorLCL.SetTheme(const ATheme: string);
begin
  FTheme := ATheme;
  ApplyFallbackTheme;
  if FEditorReady then
    RunScript('if (window.setEditorTheme) { window.setEditorTheme(' + EscapeJsonString(FTheme) + '); }');
end;

procedure TFRpMonacoEditorLCL.ApplyFallbackTheme;
var
  LDark: Boolean;
begin
  if FFallbackEditor = nil then
    Exit;
  // The colors of the Monaco themes (vs, vs-dark)
  LDark := Pos('dark', LowerCase(FTheme)) > 0;
  if LDark then
  begin
    FFallbackEditor.Color := $1E1E1E;
    FFallbackEditor.Font.Color := $D4D4D4;
    FFallbackEditor.Gutter.Color := $252526;
    FFallbackEditor.SelectedColor.Background := $4F2626;
    FSqlHighlighter.KeyAttri.Foreground := $D69C56;
    FSqlHighlighter.StringAttri.Foreground := $7891CE;
    FSqlHighlighter.NumberAttri.Foreground := $A8CEB5;
    FSqlHighlighter.CommentAttri.Foreground := $55996A;
    FSqlHighlighter.TableNameAttri.Foreground := $B0C94E;
    FSqlHighlighter.FunctionAttri.Foreground := $AADCDC;
    FSqlHighlighter.DataTypeAttri.Foreground := $D69C56;
    FSqlHighlighter.IdentifierAttri.Foreground := $FEDC9C;
    FSqlHighlighter.SymbolAttri.Foreground := $D4D4D4;
  end
  else
  begin
    FFallbackEditor.Color := clWhite;
    FFallbackEditor.Font.Color := clBlack;
    FFallbackEditor.Gutter.Color := $F0F0F0;
    FFallbackEditor.SelectedColor.Background := $FFD6AD;
    FSqlHighlighter.KeyAttri.Foreground := $FF0000;
    FSqlHighlighter.StringAttri.Foreground := $1515A3;
    FSqlHighlighter.NumberAttri.Foreground := $588609;
    FSqlHighlighter.CommentAttri.Foreground := $008000;
    FSqlHighlighter.TableNameAttri.Foreground := $997F26;
    FSqlHighlighter.FunctionAttri.Foreground := $265E79;
    FSqlHighlighter.DataTypeAttri.Foreground := $FF0000;
    FSqlHighlighter.IdentifierAttri.Foreground := clBlack;
    FSqlHighlighter.SymbolAttri.Foreground := clBlack;
  end;
  FFallbackEditor.SelectedColor.Foreground := clNone;
end;

procedure TFRpMonacoEditorLCL.SetLanguage(const ALang: string);
begin
  FLanguage := ALang;
  if FEditorReady then
    RunScript('if (window.setEditorLanguage) { window.setEditorLanguage(' + EscapeJsonString(FLanguage) + '); }');
end;

procedure TFRpMonacoEditorLCL.ActivateFallback(const AReason: string);
begin
  if FUseFallback then
    Exit;
  LogStatus('Activating the fallback editor: ' + AReason);
  FUseFallback := True;
  FEditorReady := False;
  FDebounceTimer.Enabled := False;

  FUpdatingFromBrowser := True;
  try
    FFallbackEditor.Text := FSQL;
  finally
    FUpdatingFromBrowser := False;
  end;
  ApplyFallbackTheme;

  FWebView.Visible := False;
  FFallbackEditor.Visible := True;
  FFallbackEditor.BringToFront;
{$IFDEF MSWINDOWS}
  // As the VCL: the reason and a hint through the log channel (the chat);
  // out of Windows the SynEdit editor is the normal one
  EmitInferenceLog('System', 'Fallback activated due to WebView failure: ' + AReason, True);
  EmitInferenceLog('System', TranslateStr(1560, 'The advanced SQL editor needs the ' +
    'Microsoft Edge WebView2 runtime, which could not be loaded. Install it from ' +
    'https://developer.microsoft.com/microsoft-edge/webview2/ to get the full editor. ' +
    'Meanwhile you can edit the SQL as text, with completion of the tables and ' +
    'columns of the schema (Ctrl+Space), and apply the suggestions of the chat.'), True);
{$ENDIF}
end;

procedure TFRpMonacoEditorLCL.SetAuditText(const Value: string);
begin
  FAuditText := Value;
  if FMemoAudit <> nil then
    FMemoAudit.Lines.Text := Value;
end;

procedure TFRpMonacoEditorLCL.ClearLog;
begin
  // As the VCL: the log is the one of the chat
end;

procedure TFRpMonacoEditorLCL.AppendLog(const AText: string);
begin
  EmitInferenceLog('Audit', AText, True);
end;

procedure TFRpMonacoEditorLCL.EmitInferenceLog(const ASource, AText: string;
  AAppendLineBreak: Boolean);
begin
  if Assigned(FOnInferenceLog) then
    FOnInferenceLog(Self, ASource, AText, AAppendLineBreak);
end;

procedure TFRpMonacoEditorLCL.ActivateAuditTab;
begin
  if FPControl <> nil then
    FPControl.ActivePage := FTabAudit;
end;

procedure TFRpMonacoEditorLCL.SetAuditBusy(AValue: Boolean);
begin
  if FBAuditSQL <> nil then
    FBAuditSQL.Enabled := not AValue;
  if FAISelection <> nil then
    FAISelection.SetInferenceProgress(AValue);
  LayoutTopControls;
end;

procedure TFRpMonacoEditorLCL.UpdateAITokens(AInTokens, AOutTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer);
begin
  if FAISelection <> nil then
    FAISelection.UpdateTokens(AInTokens, AOutTokens, AProgressId, APrefillPercent);
  // A row per stream: the header grows with the model selection
  LayoutTopControls;
end;

procedure TFRpMonacoEditorLCL.AISelectionStopRequest(Sender: TObject);
begin
  // Stop of the model selection: the AI completion running (the result is
  // an empty answer to the page) and, through the host, the audit
  if FInferenceRunning and (FInferenceCancel <> nil) then
    FInferenceCancel.Cancel;
  if Assigned(FOnStopRequest) then
    FOnStopRequest(Self);
end;

function TFRpMonacoEditorLCL.GetAITier: string;
begin
  if FAISelection <> nil then
    Result := FAISelection.AITier
  else
    Result := 'Standard';
end;

function TFRpMonacoEditorLCL.GetAIMode: string;
begin
  if FAISelection <> nil then
    Result := FAISelection.AIMode
  else
    Result := 'Fast';
end;

function TFRpMonacoEditorLCL.GetAgentSecret: string;
begin
  if FAISelection <> nil then
    Result := FAISelection.AgentSecret
  else
    Result := '';
end;

function TFRpMonacoEditorLCL.GetAgentAiId: Int64;
begin
  if FAISelection <> nil then
    Result := FAISelection.AgentAiId
  else
    Result := 0;
end;

procedure TFRpMonacoEditorLCL.BAuditSQLClick(Sender: TObject);
begin
  ActivateAuditTab;
  if Assigned(FOnAuditSql) then
    FOnAuditSql(Self);
end;

procedure TFRpMonacoEditorLCL.AIToggleClick(Sender: TObject);
begin
  if not FAIButton.Down then
    HideAISuggestion;
  TRpAuthManager.Instance.AIEnabled := FAIButton.Down;
  UpdateAuthUI;
end;

procedure TFRpMonacoEditorLCL.SchemaConfigClick(Sender: TObject);
begin
  TRpAuthManager.Instance.OpenUrl('https://app.reportman.es/database-config');
end;

{ Schemas }

procedure TFRpMonacoEditorLCL.ClearSchemaItems;
var
  I: Integer;
begin
  if FComboSchema = nil then
    Exit;
  for I := 0 to FComboSchema.Items.Count - 1 do
    FComboSchema.Items.Objects[I].Free;
  FComboSchema.Clear;
end;

procedure TFRpMonacoEditorLCL.ApplyUserSchemas(AList: TStrings);
var
  I: Integer;
  LParts: TStringList;
  LHubDatabaseId, LSchemaId: Int64;
  LApiKey: string;
begin
  if FLoadingSchemas then
    Exit;
  FLoadingSchemas := True;
  FComboSchema.Items.BeginUpdate;
  LParts := TStringList.Create;
  try
    LParts.Delimiter := '|';
    LParts.StrictDelimiter := True;
    ClearSchemaItems;
    FComboSchema.Items.Add('');
    for I := 0 to AList.Count - 1 do
    begin
      LParts.DelimitedText := AList.ValueFromIndex[I];
      if LParts.Count >= 2 then
      begin
        LHubDatabaseId := StrToInt64Def(LParts[0], 0);
        LSchemaId := StrToInt64Def(LParts[1], 0);
      end
      else
      begin
        LHubDatabaseId := 0;
        LSchemaId := 0;
      end;
      if LParts.Count >= 3 then
        LApiKey := LParts[2]
      else
        LApiKey := '';
      FComboSchema.Items.AddObject(AList.Names[I],
        TRpMonacoSchemaItem.Create(LHubDatabaseId, LSchemaId, LApiKey));
    end;
    SelectCurrentSchema;
  finally
    LParts.Free;
    FComboSchema.Items.EndUpdate;
    FLoadingSchemas := False;
  end;
end;

procedure TFRpMonacoEditorLCL.ApplyUserAgents(AList: TStrings;
  const ASelectedTier: string; ASelectedAgentAiId: Int64);
var
  I: Integer;
  LParts: TStringList;
begin
  FAISelection.ClearAgentEndpoints;
  LParts := TStringList.Create;
  try
    LParts.Delimiter := '|';
    LParts.StrictDelimiter := True;
    for I := 0 to AList.Count - 1 do
    begin
      LParts.DelimitedText := AList.ValueFromIndex[I];
      // Only the online agents can answer
      if (LParts.Count >= 3) and (LParts[2] = '1') then
        FAISelection.AddAgentEndpoint(StrToInt64Def(LParts[0], 0), LParts[1],
          AList.Names[I], True);
    end;
  finally
    LParts.Free;
  end;
  FAISelection.RestoreProviderSelection(ASelectedTier, ASelectedAgentAiId);
end;

procedure TFRpMonacoEditorLCL.SetSchema(const ASchema: string);
var
  LIndex: Integer;
begin
  FSchema := ASchema;
  LIndex := FComboSchema.Items.IndexOf(ASchema);
  if LIndex >= 0 then
    FComboSchema.ItemIndex := LIndex;
end;

procedure TFRpMonacoEditorLCL.SetHubContext(AHubDatabaseId, AHubSchemaId: Int64;
  const ASchemaApiKey: string);
var
  LBaseApiKey: string;
  LNeedsSchemaReload: Boolean;
begin
  LBaseApiKey := Trim(ASchemaApiKey);
  LNeedsSchemaReload := (FBaseHubDatabaseId <> AHubDatabaseId) or
    (FBaseApiKey <> LBaseApiKey);
  FBaseHubDatabaseId := AHubDatabaseId;
  FBaseApiKey := LBaseApiKey;
  FHubDatabaseId := AHubDatabaseId;
  FHubSchemaId := AHubSchemaId;
  FSchemaApiKey := LBaseApiKey;
  if LNeedsSchemaReload and TRpAuthManager.Instance.IsLoggedIn then
  begin
    ClearSchemaItems;
    UpdateAuthUI;
  end
  else if (FComboSchema.Items.Count = 0) and TRpAuthManager.Instance.IsLoggedIn then
    UpdateAuthUI
  else
    SelectCurrentSchema;
  UpdateSchemaTables;
end;

procedure TFRpMonacoEditorLCL.SetHubDatabaseId(const Value: Int64);
begin
  FBaseHubDatabaseId := Value;
  if FHubDatabaseId = Value then
  begin
    if FComboSchema.Items.Count > 0 then
      SelectCurrentSchema;
    Exit;
  end;
  FHubDatabaseId := Value;
  if (FComboSchema.Items.Count = 0) and TRpAuthManager.Instance.IsLoggedIn then
    UpdateAuthUI;
  if FComboSchema.Items.Count > 0 then
    SelectCurrentSchema;
end;

procedure TFRpMonacoEditorLCL.SetHubSchemaId(const Value: Int64);
begin
  if FHubSchemaId = Value then
  begin
    SelectCurrentSchema;
    Exit;
  end;
  FHubSchemaId := Value;
  if FHubSchemaId = 0 then
  begin
    FHubDatabaseId := FBaseHubDatabaseId;
    FSchemaApiKey := FBaseApiKey;
  end;
  SelectCurrentSchema;
  UpdateSchemaTables;
end;

procedure TFRpMonacoEditorLCL.SelectCurrentSchema;
var
  I: Integer;
  LItem: TRpMonacoSchemaItem;
  LFound: Boolean;
begin
  if FComboSchema.Items.Count = 0 then
    Exit;
  FComboSchema.ItemIndex := 0;
  FSchema := '';
  LFound := False;

  if FHubSchemaId <> 0 then
    for I := 1 to FComboSchema.Items.Count - 1 do
    begin
      LItem := TRpMonacoSchemaItem(FComboSchema.Items.Objects[I]);
      if (LItem <> nil) and (LItem.HubSchemaId = FHubSchemaId) then
      begin
        FComboSchema.ItemIndex := I;
        FSchema := FComboSchema.Items[I];
        FHubDatabaseId := LItem.HubDatabaseId;
        FSchemaApiKey := LItem.ApiKey;
        LFound := True;
        Break;
      end;
    end;

  if (not LFound) and (FBaseHubDatabaseId <> 0) then
    for I := 1 to FComboSchema.Items.Count - 1 do
    begin
      LItem := TRpMonacoSchemaItem(FComboSchema.Items.Objects[I]);
      if (LItem <> nil) and (LItem.HubDatabaseId = FBaseHubDatabaseId) then
      begin
        FComboSchema.ItemIndex := I;
        FSchema := FComboSchema.Items[I];
        FHubDatabaseId := LItem.HubDatabaseId;
        FHubSchemaId := LItem.HubSchemaId;
        FSchemaApiKey := LItem.ApiKey;
        LFound := True;
        Break;
      end;
    end;

  if (not LFound) and (FComboSchema.Items.Count > 1) then
  begin
    FComboSchema.ItemIndex := 1;
    LItem := TRpMonacoSchemaItem(FComboSchema.Items.Objects[1]);
    FSchema := FComboSchema.Items[1];
    if LItem <> nil then
    begin
      FHubDatabaseId := LItem.HubDatabaseId;
      FHubSchemaId := LItem.HubSchemaId;
      FSchemaApiKey := LItem.ApiKey;
    end;
    LFound := True;
  end;

  if not LFound then
  begin
    FSchema := '';
    FHubDatabaseId := FBaseHubDatabaseId;
    FHubSchemaId := 0;
    FSchemaApiKey := FBaseApiKey;
  end;
  UpdateSchemaTables;
end;

procedure TFRpMonacoEditorLCL.ComboSchemaChange(Sender: TObject);
var
  LItem: TRpMonacoSchemaItem;
begin
  if FLoadingSchemas then
    Exit;
  if FComboSchema.ItemIndex > 0 then
  begin
    LItem := TRpMonacoSchemaItem(FComboSchema.Items.Objects[FComboSchema.ItemIndex]);
    FSchema := FComboSchema.Items[FComboSchema.ItemIndex];
    if LItem <> nil then
    begin
      FHubDatabaseId := LItem.HubDatabaseId;
      FHubSchemaId := LItem.HubSchemaId;
      FSchemaApiKey := LItem.ApiKey;
    end;
  end
  else
  begin
    FSchema := '';
    FHubDatabaseId := FBaseHubDatabaseId;
    FHubSchemaId := 0;
    FSchemaApiKey := FBaseApiKey;
  end;
  UpdateSchemaTables;
  if Assigned(FOnSchemaChanged) then
    FOnSchemaChanged(Self);
end;

function TFRpMonacoEditorLCL.GetSchemaApiKey: string;
var
  LItem: TRpMonacoSchemaItem;
begin
  if FComboSchema.ItemIndex > 0 then
  begin
    LItem := TRpMonacoSchemaItem(FComboSchema.Items.Objects[FComboSchema.ItemIndex]);
    if LItem <> nil then
      Exit(LItem.ApiKey);
  end;
  Result := FSchemaApiKey;
end;

procedure TFRpMonacoEditorLCL.UpdateAuthUI;
var
  LLoggedIn, LAIEnabled, LNeedsSchemas, LNeedsAgents: Boolean;
  LWorker: TRpMonacoAuthWorker;
begin
  Inc(FAuthUIUpdateVersion);
  LLoggedIn := TRpAuthManager.Instance.IsLoggedIn;
  LAIEnabled := TRpAuthManager.Instance.AIEnabled;

  FAIButton.Down := LAIEnabled;
  FComboSchema.Enabled := LLoggedIn;
  if not LLoggedIn then
  begin
    ClearSchemaItems;
    FSchema := '';
    FHubDatabaseId := 0;
    FHubSchemaId := 0;
    FSchemaApiKey := '';
    FAISelection.ClearAgentEndpoints;
    FAISelection.Visible := LAIEnabled;
    if not FAISelection.Visible then
      FAISelection.SetInferenceProgress(False);
    FAISelection.RefreshState;
    LayoutTopControls;
    UpdateSchemaTables;
    Exit;
  end;

  if FComboSchema.Items.Count > 0 then
    SelectCurrentSchema;

  LNeedsSchemas := FComboSchema.Items.Count = 0;
  LNeedsAgents := FAISelection.AgentEndpointCount = 0;

  FAISelection.Visible := LAIEnabled;
  if not FAISelection.Visible then
    FAISelection.SetInferenceProgress(False);
  FAISelection.RefreshState;
  LayoutTopControls;

  if not (LNeedsSchemas or LNeedsAgents) then
    Exit;

  LWorker := TRpMonacoAuthWorker.Create(FMailboxRef);
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.InstallId := TRpAuthManager.Instance.InstallId;
  LWorker.BaseApiKey := FBaseApiKey;
  LWorker.RequestVersion := FAuthUIUpdateVersion;
  LWorker.SelectedTier := FAISelection.AITier;
  LWorker.SelectedAgentAiId := FAISelection.AgentAiId;
  LWorker.NeedsSchemas := LNeedsSchemas;
  LWorker.NeedsAgents := LNeedsAgents;
  LWorker.Start;
end;

procedure TFRpMonacoEditorLCL.AuthChanged(ASuccess: Boolean);
begin
  // Another user: the tables of the schemas are loaded again (a status
  // check of the same session keeps them)
  if TRpAuthManager.Instance.Token <> FAuthToken then
  begin
    FAuthToken := TRpAuthManager.Instance.Token;
    FSchemaCache.Clear;
    FLoadedSchemaTablesId := -1;
  end;
  UpdateAuthUI;
  UpdateSchemaTables;
end;

procedure TFRpMonacoEditorLCL.HandleAsyncMessage(AMessage: TRpAsyncMessage);
var
  LPayload: TRpMonacoAuthPayload;
begin
  if AMessage is TRpMonacoSuggestProgress then
    HandleSuggestProgress(AMessage)
  else if AMessage is TRpMonacoSuggestResult then
    HandleSuggestResult(AMessage)
  else if AMessage is TRpMonacoSchemaTablesPayload then
    HandleSchemaTables(AMessage)
  else if AMessage is TRpMonacoAuthPayload then
  begin
    LPayload := TRpMonacoAuthPayload(AMessage);
    if LPayload.RequestVersion <> FAuthUIUpdateVersion then
      Exit;
    if LPayload.NeedsSchemas then
    begin
      // A new list: the tables are loaded again
      FSchemaCache.Clear;
      FLoadedSchemaTablesId := -1;
      ApplyUserSchemas(LPayload.Schemas);
    end;
    if LPayload.NeedsAgents then
      ApplyUserAgents(LPayload.Agents, LPayload.SelectedTier,
        LPayload.SelectedAgentAiId);
    FAISelection.Visible := TRpAuthManager.Instance.AIEnabled;
    if not FAISelection.Visible then
      FAISelection.SetInferenceProgress(False);
    FAISelection.RefreshState;
    LayoutTopControls;
    UpdateSchemaTables;
  end;
end;

{ AI completion (02:) }

procedure TFRpMonacoEditorLCL.HandleAICompletionRequest(const APayload: string);
var
  LHeaderEnd, LOffsetSeparator: Integer;
  LHeader: string;
begin
  if FUseFallback then
    Exit; // the fallback editor asks itself (RequestFallbackAICompletion)
  FDebounceTimer.Enabled := False;

  FPendingRequestId := '';
  FPendingSql := '';
  FPendingPos := 0;

  LHeaderEnd := Pos(#10, APayload);
  if LHeaderEnd <= 0 then
    Exit;
  LHeader := StringReplace(Copy(APayload, 1, LHeaderEnd - 1), #13, '', [rfReplaceAll]);
  LOffsetSeparator := LastDelimiter(':', LHeader);
  if LOffsetSeparator <= 1 then
    Exit;

  QueueAICompletion(Copy(LHeader, 1, LOffsetSeparator - 1),
    Copy(APayload, LHeaderEnd + 1, MaxInt),
    StrToIntDef(Copy(LHeader, LOffsetSeparator + 1, MaxInt), 0));
end;

// ASql and APos (UTF-16 offset of the caret) as a '02:' message of the page
procedure TFRpMonacoEditorLCL.QueueAICompletion(const ARequestId, ASql: string;
  APos: Integer);
begin
  FDebounceTimer.Enabled := False;
  FPendingRequestId := ARequestId;
  FPendingSql := ASql;
  FPendingPos := APos;
  if FPendingRequestId = '' then
    Exit;

  // A running inference for other text is not wanted any more
  if FInferenceRunning and (FActiveInferenceRequestId <> FPendingRequestId) and
    (FInferenceCancel <> nil) then
    FInferenceCancel.Cancel;

  // The same text (only the cursor moved): empty answer, as the VCL
  if FPendingSql = FLastAutoCompleteSql then
  begin
    SendAICompletions('[]', '[]', FPendingRequestId);
    Exit;
  end;

  if not TRpAuthManager.Instance.AIEnabled then
  begin
    SendAICompletions('[]', '[]', FPendingRequestId);
    Exit;
  end;

  if FInferenceRunning then
    FRestartPendingInference := True
  else
    FDebounceTimer.Enabled := True;
end;

procedure TFRpMonacoEditorLCL.OnDebounceTimer(Sender: TObject);
begin
  FDebounceTimer.Enabled := False;
  if not TRpAuthManager.Instance.AIEnabled then
    Exit;
  if FInferenceRunning then
  begin
    FRestartPendingInference := True;
    Exit;
  end;
  StartPendingInference;
end;

procedure TFRpMonacoEditorLCL.StartPendingInference;
var
  LWorker: TRpMonacoSuggestWorker;
begin
  if FInferenceRunning then
    Exit;
  if not TRpAuthManager.Instance.AIEnabled then
    Exit;
  if FPendingRequestId = '' then
    Exit;

  FLastAutoCompleteSql := FPendingSql;
  FActiveInferenceRequestId := FPendingRequestId;
  FInferenceRunning := True;
  FRestartPendingInference := False;
  FInferenceCancel := TRpAsyncCancel.Create;

  FAISelection.SetInferenceProgress(True);
  LayoutTopControls;
  EmitInferenceLog('Autocomplete', 'Actor: Assistant', True);

  LWorker := TRpMonacoSuggestWorker.Create(FMailboxRef);
  LWorker.RequestId := FPendingRequestId;
  LWorker.Sql := FPendingSql;
  LWorker.CursorPos := FPendingPos;
  LWorker.ApiKey := GetSchemaApiKey;
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.InstallId := TRpAuthManager.Instance.InstallId;
  LWorker.HubDatabaseId := FHubDatabaseId;
  LWorker.HubSchemaId := FHubSchemaId;
  LWorker.RuntimeDb := FRuntimeDb;
  LWorker.AITier := FAISelection.AITier;
  LWorker.AIMode := FAISelection.AIMode;
  LWorker.AgentSecret := FAISelection.AgentSecret;
  LWorker.AgentAiId := FAISelection.AgentAiId;
  LWorker.Cancel := FInferenceCancel;
  LWorker.Start;
end;

procedure TFRpMonacoEditorLCL.HandleSuggestProgress(AMessage: TRpAsyncMessage);
var
  LMsg: TRpMonacoSuggestProgress;
begin
  LMsg := TRpMonacoSuggestProgress(AMessage);
  if SameText(LMsg.Actor, 'AI') and (Trim(LMsg.ProgressId) <> '') then
    FAISelection.TouchProgressToken(LMsg.ProgressId);
  if SameText(LMsg.Actor, 'AI') then
    FAISelection.UpdateTokens(LMsg.InputTokens, LMsg.OutputTokens, LMsg.ProgressId,
      LMsg.PrefillPercent);
  if SameText(LMsg.Actor, 'AI') and
    (SameText(LMsg.ChunkType, 'End') or SameText(LMsg.ChunkType, 'Full')) then
    FAISelection.FinishProgressToken(LMsg.ProgressId);
  LayoutTopControls;
  if not SameText(FActiveInferenceRequestId, FPendingRequestId) then
    Exit;
  if not SameText(LMsg.Stage, 'ReceivingResponse') then
    Exit;
  if LMsg.Chunk = '' then
    Exit;
  EmitInferenceLog(LMsg.Actor, LMsg.Chunk, SameText(LMsg.ChunkType, 'End'));
end;

procedure TFRpMonacoEditorLCL.HandleSuggestResult(AMessage: TRpAsyncMessage);
var
  LMsg: TRpMonacoSuggestResult;
  LProfile: TJSONValue;
  LShouldRestart: Boolean;
begin
  LMsg := TRpMonacoSuggestResult(AMessage);
  if LMsg.UserProfileJson <> '' then
  begin
    LProfile := TJSONObject.ParseJSONValue(LMsg.UserProfileJson);
    try
      if LProfile is TJSONObject then
        TRpAuthManager.Instance.UpdateProfileFromJson(TJSONObject(LProfile));
    finally
      LProfile.Free;
    end;
  end;

  if LMsg.RequestId <> FPendingRequestId then
  begin
    // Superseded while it ran: start the pending request if there is one
    FAISelection.SetInferenceProgress(False);
    LayoutTopControls;
    FInferenceRunning := False;
    FInferenceCancel := nil;
    if FActiveInferenceRequestId = LMsg.RequestId then
      FActiveInferenceRequestId := '';
    LShouldRestart := FRestartPendingInference;
    FRestartPendingInference := False;
    if LShouldRestart then
      StartPendingInference;
    Exit;
  end;

  FAISelection.UpdateTokens(LMsg.InputTokens, LMsg.OutputTokens, LMsg.RequestId);
  if LMsg.InputTokens > 0 then
    EmitInferenceLog('Autocomplete', 'Inference complete. Input Tokens: ' +
      IntToStr(LMsg.InputTokens) + ' Output Tokens: ' + IntToStr(LMsg.OutputTokens), True)
  else
    EmitInferenceLog('Autocomplete', 'Inference complete.', True);

  SendAICompletions(LMsg.InlineItemsJson, LMsg.CompletionItemsJson, LMsg.RequestId);
  FAISelection.SetInferenceProgress(False);
  LayoutTopControls;
  LShouldRestart := FRestartPendingInference and (FPendingRequestId <> LMsg.RequestId);
  FInferenceRunning := False;
  FInferenceCancel := nil;
  if FActiveInferenceRequestId = LMsg.RequestId then
    FActiveInferenceRequestId := '';
  FRestartPendingInference := False;
  if LShouldRestart then
    StartPendingInference;
end;

procedure TFRpMonacoEditorLCL.SendAICompletions(const AInlineItemsJson,
  ACompletionItemsJson, ARequestId: string);
begin
  Inc(FAICompletionCount);
  if FUseFallback then
  begin
    // Only the inline items: the list of the dropdown is the schema one
    if ARequestId = FPendingRequestId then
      ShowFallbackAISuggestion(AInlineItemsJson);
    Exit;
  end;
  // As the VCL: receiveAICompletions(requestId, response)
  RunScript('window.receiveAICompletions(' + EscapeJsonString(ARequestId) +
    ', {"inlineItems":' + AInlineItemsJson + ',"completionItems":' +
    ACompletionItemsJson + '});');
end;

{ Schema completion }

procedure TFRpMonacoEditorLCL.HandleSchemaCompletionRequest(const APayload: string);
var
  LHeaderEnd, LSep: Integer;
  LHeader, LId, LSql: string;
  LOffset: Integer;
  LExplicit: Boolean;
  LItems: TRpSqlCompletionItems;
  LArray: TJSONArray;
  LItem: TJSONObject;
  I: Integer;
const
  CKinds: array[TRpSqlCompletionKind] of string = ('column', 'table', 'keyword');
begin
  // <id>:<utf16 offset>:<explicit>\n<sql>
  LHeaderEnd := Pos(#10, APayload);
  if LHeaderEnd <= 0 then
    Exit;
  LHeader := StringReplace(Copy(APayload, 1, LHeaderEnd - 1), #13, '', [rfReplaceAll]);
  LSql := Copy(APayload, LHeaderEnd + 1, MaxInt);
  LSep := LastDelimiter(':', LHeader);
  if LSep <= 1 then
    Exit;
  LExplicit := Copy(LHeader, LSep + 1, MaxInt) <> '0';
  LHeader := Copy(LHeader, 1, LSep - 1);
  LSep := LastDelimiter(':', LHeader);
  if LSep <= 1 then
    Exit;
  LOffset := StrToIntDef(Copy(LHeader, LSep + 1, MaxInt), 0);
  LId := Copy(LHeader, 1, LSep - 1);
  LItems := RpSqlCompletionItems(FSqlSchema, LSql,
    RpUtf16OffsetToByteOffset(LSql, LOffset), LExplicit, False);
  LArray := TJSONArray.Create;
  try
    for I := 0 to High(LItems) do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('label', LItems[I].Text);
      LItem.AddPair('kind', CKinds[LItems[I].Kind]);
      LItem.AddPair('detail', LItems[I].Detail);
      LArray.AddElement(LItem);
    end;
    RunScript('if (window.rpReceiveSchemaCompletions) { window.rpReceiveSchemaCompletions(' +
      EscapeJsonString(LId) + ', ' + LArray.ToJSON + '); }');
  finally
    LArray.Free;
  end;
end;

function TFRpMonacoEditorLCL.FindCachedSchema(AHubSchemaId: Int64): TRpSqlSchema;
var
  I: Integer;
begin
  for I := 0 to FSchemaCache.Count - 1 do
    if FSchemaCache[I].HubSchemaId = AHubSchemaId then
      Exit(FSchemaCache[I]);
  Result := nil;
end;

procedure TFRpMonacoEditorLCL.UpdateSchemaTables;
var
  LCached: TRpSqlSchema;
  LWorker: TRpMonacoSchemaTablesWorker;
  LApiKey: string;
begin
  if FSqlSchema = nil then
    Exit;
  if FHubSchemaId = FLoadedSchemaTablesId then
    Exit;
  if FHubSchemaId = 0 then
  begin
    FSqlSchema.Clear;
    FLoadedSchemaTablesId := 0;
    FSchemaTablesRequestedId := 0;
    ApplySchemaTables;
    Exit;
  end;
  LCached := FindCachedSchema(FHubSchemaId);
  if LCached <> nil then
  begin
    FSqlSchema.Assign(LCached);
    FLoadedSchemaTablesId := FHubSchemaId;
    ApplySchemaTables;
    Exit;
  end;
  if FSchemaTablesRequestedId = FHubSchemaId then
    Exit;
  LApiKey := GetSchemaApiKey;
  if (TRpAuthManager.Instance.Token = '') and (LApiKey = '') then
    Exit;
  FSchemaTablesRequestedId := FHubSchemaId;
  Inc(FSchemaTablesVersion);
  LWorker := TRpMonacoSchemaTablesWorker.Create(FMailboxRef);
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.InstallId := TRpAuthManager.Instance.InstallId;
  LWorker.ApiKey := LApiKey;
  LWorker.RequestedId := FHubSchemaId;
  LWorker.Version := FSchemaTablesVersion;
  LWorker.Start;
end;

procedure TFRpMonacoEditorLCL.ReloadSchemaTables;
begin
  FSchemaCache.Clear;
  FLoadedSchemaTablesId := -1;
  FSchemaTablesRequestedId := 0;
  UpdateSchemaTables;
end;

procedure TFRpMonacoEditorLCL.HandleSchemaTables(AMessage: TRpAsyncMessage);
var
  LPayload: TRpMonacoSchemaTablesPayload;
  LSchema, LOld: TRpSqlSchema;
begin
  LPayload := TRpMonacoSchemaTablesPayload(AMessage);
  if LPayload.Version = FSchemaTablesVersion then
    FSchemaTablesRequestedId := 0;
  // Every schema of the answer goes to the cache
  while LPayload.Schemas.Count > 0 do
  begin
    LSchema := LPayload.Schemas.Extract(LPayload.Schemas[0]);
    LOld := FindCachedSchema(LSchema.HubSchemaId);
    if LOld <> nil then
      FSchemaCache.Remove(LOld);
    FSchemaCache.Add(LSchema);
  end;
  if (FHubSchemaId <> 0) and (FHubSchemaId <> FLoadedSchemaTablesId) and
    (FindCachedSchema(FHubSchemaId) <> nil) then
  begin
    FSqlSchema.Assign(FindCachedSchema(FHubSchemaId));
    FLoadedSchemaTablesId := FHubSchemaId;
    ApplySchemaTables;
  end
  else if (LPayload.Version = FSchemaTablesVersion) and
    (LPayload.RequestedId = FHubSchemaId) and (FHubSchemaId <> FLoadedSchemaTablesId) then
  begin
    // The schema is not in the answer (no tables defined, or no access)
    FSqlSchema.Clear;
    FSqlSchema.HubSchemaId := FHubSchemaId;
    FLoadedSchemaTablesId := FHubSchemaId;
    ApplySchemaTables;
  end;
end;

procedure TFRpMonacoEditorLCL.ApplySchemaTables;
begin
  if FSqlHighlighter <> nil then
    FSqlSchema.GetTableNames(FSqlHighlighter.TableNames);
  if Assigned(FOnSchemaTablesLoaded) then
    FOnSchemaTablesLoaded(Self);
end;

{ Completion of the fallback editor }

function TFRpMonacoEditorLCL.FallbackTextAndCursor(AForCompletion: Boolean;
  out ACursor: Integer): string;
var
  I, LLineStart: Integer;
  LCaret: TPoint;
begin
  // The lines joined without a line break at the end (TStrings.Text adds
  // one the editor does not show): #13#10 for the SQL (as Monaco '01:'),
  // #10 for the completion; ACursor is the 0 based offset of the caret
  Result := '';
  ACursor := 0;
  LCaret := FFallbackEditor.LogicalCaretXY;
  for I := 0 to FFallbackEditor.Lines.Count - 1 do
  begin
    if I > 0 then
    begin
      if AForCompletion then
        Result := Result + #10
      else
        Result := Result + #13#10;
    end;
    LLineStart := Length(Result);
    Result := Result + FFallbackEditor.Lines[I];
    if I = LCaret.Y - 1 then
    begin
      ACursor := LLineStart + LCaret.X - 1;
      // SynEdit trims the trailing spaces of the lines (the space just typed
      // after FROM): they count for the completion context
      if AForCompletion and (ACursor > Length(Result)) then
        Result := Result + StringOfChar(' ', ACursor - Length(Result));
      if ACursor > Length(Result) then
        ACursor := Length(Result);
    end;
  end;
end;

procedure TFRpMonacoEditorLCL.FilterCompletionItems;
var
  I: Integer;
  LPrefix: string;
begin
  LPrefix := FCompletion.CurrentString;
  FCompletion.ItemList.BeginUpdate;
  try
    FCompletion.ItemList.Clear;
    for I := 0 to High(FCompletionItems) do
      if (LPrefix = '') or AnsiStartsText(LPrefix, FCompletionItems[I].Text) then
        FCompletion.ItemList.AddObject(FCompletionItems[I].Text, TObject(PtrInt(I)));
  finally
    FCompletion.ItemList.EndUpdate;
  end;
end;

procedure TFRpMonacoEditorLCL.CompletionExecute(Sender: TObject);
var
  LSql: string;
  LCursor: Integer;
begin
  LSql := FallbackTextAndCursor(True, LCursor);
  FCompletionItems := RpSqlCompletionItems(FSqlSchema, LSql, LCursor,
    not FCompletionAuto, True);
  FilterCompletionItems;
  if FCompletion.ItemList.Count > 0 then
    FCompletion.Position := 0;
end;

procedure TFRpMonacoEditorLCL.CompletionSearchPosition(var APosition: Integer);
begin
  FilterCompletionItems;
  if FCompletion.ItemList.Count > 0 then
    APosition := 0
  else
    APosition := -1;
end;

function TFRpMonacoEditorLCL.CompletionPaintItem(const AKey: string;
  ACanvas: TCanvas; X, Y: Integer; Selected: Boolean; Index: Integer): Boolean;
var
  LIndex, LDetailX: Integer;
  LDetail: string;
  LColor: TColor;
begin
  Result := False;
  if (Index < 0) or (Index >= FCompletion.ItemList.Count) then
    Exit;
  LIndex := PtrInt(FCompletion.ItemList.Objects[Index]);
  if (LIndex < 0) or (LIndex > High(FCompletionItems)) then
    Exit;
  ACanvas.TextOut(X + 2, Y, AKey);
  LDetail := FCompletionItems[LIndex].Detail;
  if LDetail <> '' then
  begin
    LColor := ACanvas.Font.Color;
    if not Selected then
      ACanvas.Font.Color := clGrayText;
    LDetailX := X + 2 + ACanvas.TextWidth(AKey) + Scale(12);
    ACanvas.TextOut(LDetailX, Y, LDetail);
    ACanvas.Font.Color := LColor;
  end;
  Result := True;
end;

procedure TFRpMonacoEditorLCL.ExecuteFallbackCompletion(AExplicit: Boolean);
var
  LLine, LToken: string;
  I: Integer;
  P: TPoint;
begin
  if (FFallbackEditor = nil) or FFallbackEditor.ReadOnly then
    Exit;
  // The identifier before the caret (TSynCompletion.GetPreviousToken)
  LLine := FFallbackEditor.LineText;
  I := FFallbackEditor.LogicalCaretXY.X - 1;
  if I > Length(LLine) then
    I := Length(LLine);
  LToken := '';
  if I >= 0 then
  begin
    while (I > 0) and (LLine[I] > ' ') and (Pos(LLine[I], FCompletion.EndOfTokenChr) = 0) do
      Dec(I);
    LToken := Copy(LLine, I + 1, FFallbackEditor.LogicalCaretXY.X - I - 1);
  end;
  if FFallbackEditor.HandleAllocated then
    P := FFallbackEditor.ClientToScreen(Types.Point(FFallbackEditor.CaretXPix,
      FFallbackEditor.CaretYPix + FFallbackEditor.LineHeight + 1))
  else
    P := Types.Point(0, 0);
  FCompletionAuto := not AExplicit;
  try
    FCompletion.Editor := FFallbackEditor;
    FCompletion.Execute(LToken, P.X, P.Y);
  finally
    FCompletionAuto := False;
  end;
end;

procedure TFRpMonacoEditorLCL.FallbackCommandHandler(Sender: TObject;
  AfterProcessing: Boolean; var Handled: Boolean; var Command: TSynEditorCommand;
  var AChar: TUTF8Char; Data: Pointer; HandlerData: Pointer);
begin
  if not AfterProcessing then
  begin
    FCommandChangeStamp := FFallbackEditor.ChangeStamp;
    Exit;
  end;
  // As Monaco while the user types: the AI inline completion after an edit
  // of the keyboard (undo, redo and the accepted suggestion are no commands
  // of this list)
  if (FFallbackEditor.ChangeStamp <> FCommandChangeStamp) and
    (not FFallbackEditor.ReadOnly) then
    case Command of
      ecChar, ecLineBreak, ecInsertLine, ecDeleteLastChar, ecDeleteChar,
      ecDeleteWord, ecDeleteLastWord, ecDeleteBOL, ecDeleteEOL, ecDeleteLine,
      ecTab, ecShiftTab, ecCut, ecPaste:
        RequestFallbackAICompletion;
    end;
  // As Monaco: the completion opens on its own after "." and after the
  // keywords followed by tables (the text decides it in AsyncAutoComplete)
  if Command <> ecChar then
    Exit;
  if (AChar = '.') or (AChar = ' ') then
    Application.QueueAsyncCall(AsyncAutoComplete, 0);
end;

procedure TFRpMonacoEditorLCL.AsyncAutoComplete(Data: PtrInt);
var
  LSql: string;
  LCursor: Integer;
begin
  if (csDestroying in ComponentState) or (not FUseFallback) or
    (FFallbackEditor = nil) or (not FFallbackEditor.Focused) or FCompletion.IsActive then
    Exit;
  LSql := FallbackTextAndCursor(True, LCursor);
  if Length(RpSqlCompletionItems(FSqlSchema, LSql, LCursor, False, False)) = 0 then
    Exit;
  ExecuteFallbackCompletion(False);
end;

{ AI inline completion of the fallback editor }

procedure TFRpMonacoEditorLCL.RequestFallbackAICompletion;
var
  LSql: string;
  LCursor: Integer;
begin
  // What the page sends in '02:<id>:<offset>\n<text>': the text with CRLF and
  // the offset of the caret in UTF-16 code units
  LSql := FallbackTextAndCursor(False, LCursor);
  Inc(FAIRequestSeq);
  QueueAICompletion('se_' + IntToStr(FAIRequestSeq), LSql,
    RpByteOffsetToUtf16Offset(LSql, LCursor));
end;

procedure TFRpMonacoEditorLCL.ShowFallbackAISuggestion(const AInlineItemsJson: string);
var
  LItems: TJSONValue;
  LText, LSql: string;
  LCursor: Integer;
begin
  HideAISuggestion;
  if (FFallbackEditor = nil) or FFallbackEditor.ReadOnly then
    Exit;
  // The first inline item, as the ghost text Monaco shows
  LText := '';
  LItems := TJSONObject.ParseJSONValue(AInlineItemsJson);
  try
    if (LItems is TJSONArray) and (TJSONArray(LItems).Count > 0) and
      (TJSONArray(LItems).Items[0] is TJSONObject) then
      LText := JsonText(TJSONObject(TJSONArray(LItems).Items[0]), 'insertText');
  finally
    LItems.Free;
  end;
  if Trim(LText) = '' then
    Exit;
  // Only for the text and the caret it was asked for
  LSql := FallbackTextAndCursor(False, LCursor);
  if (LSql <> FPendingSql) or (RpByteOffsetToUtf16Offset(LSql, LCursor) <> FPendingPos) then
    Exit;
  FAISuggestion := StringReplace(StringReplace(LText, #13#10, #10, [rfReplaceAll]),
    #10, LineEnding, [rfReplaceAll]);
  FAISuggestionCaret := FFallbackEditor.LogicalCaretXY;
  FFallbackEditor.Invalidate;
end;

function TFRpMonacoEditorLCL.AISuggestionShown: Boolean;
var
  LCaret: TPoint;
begin
  Result := False;
  if (FAISuggestion = '') or (not FUseFallback) or (FFallbackEditor = nil) then
    Exit;
  LCaret := FFallbackEditor.LogicalCaretXY;
  Result := (LCaret.X = FAISuggestionCaret.X) and (LCaret.Y = FAISuggestionCaret.Y);
end;

function TFRpMonacoEditorLCL.AcceptAISuggestion: Boolean;
var
  LText: string;
begin
  Result := AISuggestionShown and (not FFallbackEditor.ReadOnly);
  LText := FAISuggestion;
  HideAISuggestion;
  if not Result then
    Exit;
  // One undo step, the caret after the text (no command: no new request)
  FFallbackEditor.InsertTextAtCaret(LText, scamEnd);
end;

procedure TFRpMonacoEditorLCL.HideAISuggestion;
begin
  if FAISuggestion = '' then
    Exit;
  FAISuggestion := '';
  if FFallbackEditor <> nil then
    FFallbackEditor.Invalidate;
end;

procedure TFRpMonacoEditorLCL.FallbackBeforeKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if FAISuggestion = '' then
    Exit;
  case Key of
    VK_TAB:
      if (Shift = []) and AISuggestionShown then
      begin
        AcceptAISuggestion;
        Key := 0;
      end
      else
        HideAISuggestion;
    VK_ESCAPE:
      begin
        HideAISuggestion;
        Key := 0;
      end;
    VK_SHIFT, VK_CONTROL, VK_MENU, VK_LSHIFT, VK_RSHIFT, VK_LCONTROL,
    VK_RCONTROL, VK_LMENU, VK_RMENU, VK_LWIN, VK_RWIN:
      ;
  else
    HideAISuggestion;
  end;
end;

procedure TFRpMonacoEditorLCL.FallbackStatusChanged(Sender: TObject;
  Changes: TSynStatusChanges);
begin
  if FAISuggestion = '' then
    Exit;
  if ((scFocus in Changes) and (not FFallbackEditor.Focused)) or
    (((Changes * [scCaretX, scCaretY]) <> []) and (not AISuggestionShown)) then
    HideAISuggestion
  else if (Changes * [scTopLine, scLeftChar]) <> [] then
    FFallbackEditor.Invalidate;
end;

procedure TFRpMonacoEditorLCL.FallbackAfterPaint(Sender: TObject;
  EventType: TSynPaintEvent; const rcClip: TRect);
var
  LCanvas: TCanvas;
  LLines: TStringList;
  LOldFont: TFont;
  LOldBrush: TBrush;
  LStyle: TTextStyle;
  LDark: Boolean;
  LTextLeft, LColumn1X, LRight, LLineHeight, X, Y, I: Integer;
  LRect: TRect;
  LHint: string;
begin
  if (EventType <> peAfterPaint) or (not AISuggestionShown) then
    Exit;
  LCanvas := FFallbackEditor.Canvas;
  LLineHeight := FFallbackEditor.LineHeight;
  LRight := FFallbackEditor.ClientWidth;
  // The first visible column and column 1 (left of it when scrolled)
  LTextLeft := FFallbackEditor.ScreenXYToPixels(Types.Point(FFallbackEditor.LeftChar, 1)).X;
  LColumn1X := FFallbackEditor.ScreenXYToPixels(Types.Point(1, 1)).X;
  LDark := Pos('dark', LowerCase(FTheme)) > 0;
  LLines := TStringList.Create;
  LOldFont := TFont.Create;
  LOldBrush := TBrush.Create;
  try
    LOldFont.Assign(LCanvas.Font);
    LOldBrush.Assign(LCanvas.Brush);
    LLines.Text := StringReplace(FAISuggestion, #9,
      StringOfChar(' ', FFallbackEditor.TabWidth), [rfReplaceAll]);
    LStyle := LCanvas.TextStyle;
    LStyle.Alignment := taLeftJustify;
    LStyle.Layout := tlTop;
    LStyle.SingleLine := True;
    LStyle.Clipping := True;
    LStyle.Opaque := False;
    LStyle.ExpandTabs := False;
    LCanvas.Font.Assign(FFallbackEditor.Font);
    LCanvas.Font.Style := [fsItalic];
    // The first line at the caret, the next ones from column 1 below it
    X := FFallbackEditor.CaretXPix;
    Y := FFallbackEditor.CaretYPix;
    for I := 0 to LLines.Count - 1 do
    begin
      if I > 0 then
      begin
        X := LColumn1X;
        Inc(Y, LLineHeight);
      end;
      if Y >= FFallbackEditor.ClientHeight then
        Break;
      // The ghost text covers the rest of the row (Monaco moves it down)
      if X > LTextLeft then
        LRect := Types.Rect(X, Y, LRight, Y + LLineHeight)
      else
        LRect := Types.Rect(LTextLeft, Y, LRight, Y + LLineHeight);
      LCanvas.Brush.Style := bsSolid;
      LCanvas.Brush.Color := FFallbackEditor.Color;
      LCanvas.FillRect(LRect);
      if LDark then
        LCanvas.Font.Color := $8A8A8A
      else
        LCanvas.Font.Color := $8C8C8C;
      LCanvas.TextRect(LRect, X, Y, LLines[I], LStyle);
    end;
    // How to accept it, after the last line
    if (LLines.Count > 0) and (Y < FFallbackEditor.ClientHeight) then
    begin
      LHint := string(TranslateStr(1561, 'Tab to accept, Esc to dismiss'));
      X := X + LCanvas.TextWidth(LLines[LLines.Count - 1]) + 2 * FFallbackEditor.CharWidth;
      LCanvas.Font.Style := [];
      if LDark then
        LCanvas.Font.Color := $5A5A5A
      else
        LCanvas.Font.Color := $B4B4B4;
      if X + LCanvas.TextWidth(LHint) <= LRight then
        LCanvas.TextRect(Types.Rect(X, Y, LRight, Y + LLineHeight), X, Y, LHint, LStyle);
    end;
  finally
    LCanvas.Font.Assign(LOldFont);
    LCanvas.Brush.Assign(LOldBrush);
    LOldBrush.Free;
    LOldFont.Free;
    LLines.Free;
  end;
end;

end.
