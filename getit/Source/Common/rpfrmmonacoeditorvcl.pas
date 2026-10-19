{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpfrmmonacoeditorvcl                            }
{       Monaco SQL Editor Frame with AI Integration     }
{                                                       }
{       Copyright (c) 1994-2025 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpfrmmonacoeditorvcl;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, ComCtrls, Buttons, Winapi.WebView2, Winapi.ActiveX, Vcl.Edge,
  System.ImageList, Vcl.BaseImageCollection, Vcl.ImageCollection,
  Vcl.VirtualImageList,
  rpauthmanager, rpfrmaiselectionvcl, rpfrmloginvcl, System.JSON, rpdatahttp,
  System.Zip, System.IOUtils, System.Threading, rpmdshfolder,
  rpfrmaischemaselectorvcl;

type
  IEditorGuard = interface
    function IsCancelled: Boolean;
    procedure Invalidate;
  end;

  TAuditSqlEvent = procedure(Sender: TObject) of object;
  TInferenceLogEvent = procedure(Sender: TObject; const ASource,
    AText: string; AAppendLineBreak: Boolean) of object;
  // The config of the AI (TRpApiDatabaseConfig JSON) with the subschema AName
  // of the direct connection AAlias inline: the host reads its local schema
  // file (RpResolveLocalSchemaConfig)
  TRpLocalSchemaConfigEvent = function(Sender: TObject;
    const AAlias, AName: string): string of object;

  TAIToggleButton = class(TSpeedButton)
  protected
    procedure Paint; override;
  end;

  TFRpMonacoEditorVCL = class(TFrame)
    PTop: TPanel;
    ComboSchema: TComboBox;
    Edge: TEdgeBrowser;
    GridTopHeader: TGridPanel;
    PSchemaConfigHost: TPanel;
    PAIButtonHost: TPanel;
    PAISelectionHost: TPanel;
    PControl: TPageControl;
    TabSQL: TTabSheet;
    TabAudit: TTabSheet;
    PAuditTop: TPanel;
    BAuditSQL: TButton;
    MemoAudit: TMemo;
    SchemaConfigImageCollection: TImageCollection;
    SchemaConfigImages: TVirtualImageList;

    procedure EdgeCreateWebViewCompleted(Sender: TCustomEdgeBrowser;
      AResult: HRESULT);
    procedure EdgeWebMessageReceived(Sender: TCustomEdgeBrowser;
      Args: TWebMessageReceivedEventArgs);
    procedure EdgeNavigationCompleted(Sender: TCustomEdgeBrowser;
      IsSuccess: Boolean; WebErrorStatus: TOleEnum);
    procedure BAuditSQLClick(Sender: TObject);
    procedure AuthChanged(ASuccess: Boolean);
  private
    FAISelection: TFRpAISelectionVCL;
    FAIButton: TAIToggleButton;
    FSchemaConfigButton: TButton;
    FSQL: string;
    FSchema: string;
    FAuditText: string;
    FBaseHubDatabaseId: Int64;
    FBaseApiKey: string;
    // The list of the combo: the subschemas of the direct connection of the
    // dataset, the cloud schemas and the two actions, with the menu of the
    // gear (the selector of the new report wizard)
    FSchemaList: TRpSchemaListController;
    // A change of the list made by the host (SetHubContext, SetLocalSchemas,
    // SelectLocalSchema) or by a load: not a choice of the user
    FUpdatingSchemaList: Boolean;
    // The config of the AI with the subschema chosen inline, and its key
    FLocalSchemaConfigKey: string;
    FLocalSchemaConfigJson: string;
    FOnLocalSchemaConfig: TRpLocalSchemaConfigEvent;
    FOnConfigureLocalSchemas: TRpConfigureLocalSchemasEvent;
    FOnContentChanged: TNotifyEvent;
    FOnSchemaChanged: TNotifyEvent;
    FAssetRootPath: string;
    FEditorReady: Boolean;
    FUpdatingFromBrowser: Boolean;
    FMemoFallback: TMemo;
    FUseFallback: Boolean;
    // WebView2 creation resilience (mirrors TRpWebMarkdownView): tolerate the
    // transient HWND churn of an Edge hosted on a TTabSheet instead of dropping
    // to the plain-text Memo on the first hiccup.
    FWebViewCreating: Boolean;
    FUserDataFolderSet: Boolean;
    FWebViewCreateRetries: Integer;
    FNavRetryCount: Integer;
    FLastNavUrl: string;
    FRetryTimer: TTimer;
    FHubDatabaseId: Int64;
    FHubSchemaId: Int64;
    FSchemaApiKey: string;
    FRuntimeDb: string;
    FDebounceTimer: TTimer;
    FPendingRequestId, FPendingSql: string;
    FPendingPos: Integer;
    FInferenceTask: ITask;
    FInferenceRunning: Boolean;
    FActiveInferenceRequestId: string;
    FRestartPendingInference: Boolean;
    FLastAutoCompleteSql: string;
    FAuthUIUpdateVersion: Integer;
    FGuard: IEditorGuard;
    FOnAuditSql: TAuditSqlEvent;
    FOnStopRequest: TNotifyEvent;
    FOnInferenceLog: TInferenceLogEvent;
    procedure AIToggleClick(Sender: TObject);
    procedure AISelectionStopRequest(Sender: TObject);
    procedure SchemaConfigClick(Sender: TObject);
    procedure SchemaListChanged(Sender: TObject);
    procedure SchemaListConfigureLocalSchemas(Sender: TObject;
      const AAlias, AName: string; AAddNew: Boolean);
    procedure SyncSchemaFromList;
    function LocalSchemaKey: string;
    procedure OnDebounceTimer(Sender: TObject);
    procedure ProcessWebMessage(const LMessage: string);
    function LoadUserSchemas(AList: TStrings): Boolean;
    function LoadApiKeySchemas(const AApiKey: string; AList: TStrings): Boolean;
    function LoadUserAgents(AList: TStrings): Boolean;
    procedure AddMergedSchemas(ASource, ADest, ASeenKeys: TStrings;
      const ADefaultApiKey: string);
    procedure ApplyUserSchemas(AList: TStrings);
    procedure ApplyUserAgents(AList: TStrings; const ASelectedTier: string;
      ASelectedAgentAiId: Int64);
    procedure SetSQL(const Value: string);
    procedure ActivateFallback(const AReason: string);
    procedure TryCreateWebView;
    procedure ScheduleCreateRetryOrFallback(const AReason: string);
    procedure WebViewRetryTimerTick(Sender: TObject);
    procedure MemoFallbackChange(Sender: TObject);
    procedure SetHubDatabaseId(const Value: Int64);
    procedure SetHubSchemaId(const Value: Int64);
    procedure SetAuditText(const Value: string);
    procedure HandleAICompletionRequest(const APayload: string);
    procedure SendAICompletions(const AInlineItems, ACompletionItems: TJSONArray; const ARequestId: string);
    function SuggestSqlStreamCancelRequested(Sender: TObject): Boolean;
    procedure EmitInferenceLog(const ASource, AText: string;
      AAppendLineBreak: Boolean);
    procedure SuggestSqlStreamProgress(Sender: TObject; const AActor, AStage,
      AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
      const AProgressId: string; APrefillPercent: Integer);
    procedure StartPendingInference;
    procedure LayoutTopControls;
    procedure UpdateAuthUI;
    function EnsureMonacoAssetsExtracted: string;
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadSQL(const ASQL: string);
    // Replaces the SQL as an edit the user can undo in the editor (Ctrl+Z);
    // SQL/LoadSQL reset the editor and its undo history instead
    procedure ApplySQL(const ASQL: string);
    procedure SetHubContext(AHubDatabaseId, AHubSchemaId: Int64;
      const ASchemaApiKey: string = '');
    procedure SetSchema(const ASchema: string);
    // The subschemas of the direct connection of the dataset (AAlias '' =
    // none; ASizes '<tables>,<widest>' per name or nil), listed before the
    // cloud schemas
    procedure SetLocalSchemas(const AAlias: string; ANames, ASizes: TStrings);
    // Chooses one of them ('' = its first one)
    procedure SelectLocalSchema(const AName: string);
    // The direct connection of the subschemas and the subschema chosen ('' =
    // a cloud schema or none)
    function GetLocalSchemaAlias: string;
    function GetLocalSchemaName: string;
    // The config of the AI with the subschema chosen inline ('' = none);
    // OnLocalSchemaConfig builds it, kept until the list changes
    function LocalSchemaConfigJson: string;
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
    property SQL: string read FSQL write SetSQL;
    property AuditText: string read FAuditText write SetAuditText;
    property HubDatabaseId: Int64 read FHubDatabaseId write SetHubDatabaseId;
    property HubSchemaId: Int64 read FHubSchemaId write SetHubSchemaId;
    property RuntimeDb: string read FRuntimeDb write FRuntimeDb;
    property AITier: string read GetAITier;
    property AIMode: string read GetAIMode;
    property AgentSecret: string read GetAgentSecret;
    property AgentAiId: Int64 read GetAgentAiId;
    property OnContentChanged: TNotifyEvent read FOnContentChanged write FOnContentChanged;
    property OnSchemaChanged: TNotifyEvent read FOnSchemaChanged write FOnSchemaChanged;
    property OnAuditSql: TAuditSqlEvent read FOnAuditSql write FOnAuditSql;
    // Stop of the model selection: the host stops what it runs (the audit)
    property OnStopRequest: TNotifyEvent read FOnStopRequest write FOnStopRequest;
    property OnInferenceLog: TInferenceLogEvent read FOnInferenceLog write FOnInferenceLog;
    property SchemaList: TRpSchemaListController read FSchemaList;
    property OnLocalSchemaConfig: TRpLocalSchemaConfigEvent
      read FOnLocalSchemaConfig write FOnLocalSchemaConfig;
    // "Local schemas..." of the gear and "New local schema...": the host
    // opens the local schema utility of the connection, then gives the list
    // again (SetLocalSchemas) and chooses the subschema saved
    property OnConfigureLocalSchemas: TRpConfigureLocalSchemasEvent
      read FOnConfigureLocalSchemas write FOnConfigureLocalSchemas;
  end;

implementation

{$R *.dfm}
{$R MonacoEditorAssets.res}

uses
  rptypes, rpdatainfo, rpgraphutilsvcl, Vcl.ToolWin, Vcl.ActnList,
  rpchatmodernstyle, rpmdconsts, System.Generics.Collections;

const
  MonacoAssetsVersion = '3'; // bump to force re-extraction when asset layout changes
  CMonacoAISelectionWidth = 384;
  CMonacoAIButtonColumnWidth = 54;
  CMonacoAISelectionRightPadding = 6;
  SRpMonacoWebViewFallbackHint =
    'El editor SQL avanzado requiere el runtime de Microsoft Edge WebView2, que no ' +
    'se ha podido cargar (equipo antiguo o sin actualizar). Para recuperar el editor ' +
    'completo instale el runtime desde ' +
    'https://developer.microsoft.com/microsoft-edge/webview2/ . Mientras tanto puede ' +
    'leer y editar el SQL en modo texto y aplicar las sugerencias del chat con normalidad.';

type
  TEditorGuard = class(TInterfacedObject, IEditorGuard)
  private
    FActive: Boolean;
  public
    constructor Create;
    function IsCancelled: Boolean;
    procedure Invalidate;
  end;

  TMonacoAuthRefreshPayload = class
  public
    RequestVersion: Integer;
    SelectedTier: string;
    SelectedAgentAiId: Int64;
    Schemas: TStringList;
    Agents: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

constructor TEditorGuard.Create;
begin
  inherited Create;
  FActive := True;
end;

function TEditorGuard.IsCancelled: Boolean;
begin
  Result := not FActive;
end;

procedure TEditorGuard.Invalidate;
begin
  FActive := False;
end;

constructor TMonacoAuthRefreshPayload.Create;
begin
  inherited Create;
  Schemas := TStringList.Create;
  Agents := TStringList.Create;
end;

destructor TMonacoAuthRefreshPayload.Destroy;
begin
  Agents.Free;
  Schemas.Free;
  inherited Destroy;
end;

procedure TAIToggleButton.Paint;
var
  R: TRect;
  Flags: Longint;
  BackColor: TColor;
  FontColor: TColor;
begin
  R := ClientRect;

  if not Enabled then
  begin
    BackColor := clBtnFace;
    FontColor := clGrayText;
  end
  else if Down then
  begin
    BackColor := clHighlight;
    FontColor := clHighlightText;
  end
  else
  begin
    BackColor := clBtnFace;
    FontColor := clBtnText;
  end;

  Canvas.Brush.Color := BackColor;
  Canvas.FillRect(R);

  if Down then
    DrawEdge(Canvas.Handle, R, BDR_SUNKENOUTER, BF_RECT)
  else
    DrawEdge(Canvas.Handle, R, BDR_RAISEDINNER, BF_RECT);

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Assign(Font);
  Canvas.Font.Color := FontColor;

  if Down then
    OffsetRect(R, 1, 1);

  Flags := DT_CENTER or DT_VCENTER or DT_SINGLELINE;
  DrawText(Canvas.Handle, PChar(Caption), Length(Caption), R, Flags);
end;

constructor TFRpMonacoEditorVCL.Create(AOwner: TComponent);
var
  LDllPath: string;
begin
  inherited Create(AOwner);
  FGuard := TEditorGuard.Create;
  FEditorReady := False;
  FAuthUIUpdateVersion := 0;

  // 1. Determine safe extraction path in %LOCALAPPDATA% using rpmdshfolder
  FAssetRootPath := EnsureMonacoAssetsExtracted;

  // 3. Preload WebView2Loader.dll based on architecture
  if SizeOf(Pointer) = 8 then
    LDllPath := TPath.Combine(FAssetRootPath, 'x64\WebView2Loader.dll')
  else
    LDllPath := TPath.Combine(FAssetRootPath, 'x86\WebView2Loader.dll');

  if TFile.Exists(LDllPath) then
    LoadLibrary(PChar(LDllPath));

  FAIButton := TAIToggleButton.Create(Self);
  FAIButton.Parent := PAIButtonHost;
  FAIButton.Align := alClient;
  FAIButton.Flat := False;
  FAIButton.AllowAllUp := True;
  FAIButton.GroupIndex := 1;
  FAIButton.Caption := 'AI';
  FAIButton.Hint := 'Activar o desactivar inferencia AI';
  FAIButton.ShowHint := True;
  FAIButton.Font.Name := 'Segoe UI Semibold';
  FAIButton.Font.Size := 9;
  FAIButton.Cursor := crHandPoint;
  FAIButton.OnClick := AIToggleClick;

  FSchemaConfigButton := TButton.Create(Self);
  FSchemaConfigButton.Parent := PSchemaConfigHost;
  FSchemaConfigButton.Align := alClient;
  FSchemaConfigButton.Caption := '';
  FSchemaConfigButton.Images := SchemaConfigImages;
  FSchemaConfigButton.ImageIndex := 0;
  FSchemaConfigButton.Hint := string(TranslateStr(1496, 'Configure DB Schemas'));
  FSchemaConfigButton.ShowHint := True;
  FSchemaConfigButton.Cursor := crHandPoint;
  FSchemaConfigButton.OnClick := SchemaConfigClick;

  // Owner drawn by the list (the red dot of an Agent not connected); the
  // first item, none, without text as before
  FSchemaList := TRpSchemaListController.Create(Self, ComboSchema);
  FSchemaList.NoSchemaCaption := '';
  FSchemaList.OnSchemaChanged := SchemaListChanged;
  FSchemaList.OnConfigureLocalSchemas := SchemaListConfigureLocalSchemas;

  // Create AI Selection Frame
  FAISelection := TFRpAISelectionVCL.Create(Self);
  PAISelectionHost.Height := FAISelection.PreferredHeight;
  PTop.Height := FAISelection.PreferredHeight;
  FAISelection.Parent := PAISelectionHost;
  FAISelection.Align := alTop;
  FAISelection.ShowGauge := False;
  FAISelection.OnStopRequest := AISelectionStopRequest;

  TRpAuthManager.Instance.RegisterAuthListener(AuthChanged);
  UpdateAuthUI;

  FDebounceTimer := TTimer.Create(Self);
  FDebounceTimer.Interval := 1000;
  FDebounceTimer.Enabled := False;
  FDebounceTimer.OnTimer := OnDebounceTimer;
  MemoAudit.ReadOnly := True;
  MemoAudit.WordWrap := True;
  MemoAudit.ScrollBars := ssVertical;

  // Plain-text fallback for the SQL editor, used when WebView2 cannot be created
  // (e.g. missing Edge runtime on old machines). Mirrors the proven
  // TRpWebMarkdownView fallback but stays EDITABLE so the user can read/edit SQL
  // and apply chat suggestions. Hidden until ActivateFallback.
  FUseFallback := False;
  FWebViewCreating := False;
  FUserDataFolderSet := False;
  FWebViewCreateRetries := 0;
  FNavRetryCount := 0;
  FMemoFallback := TMemo.Create(Self);
  FMemoFallback.Parent := TabSQL;
  FMemoFallback.Align := alClient;
  FMemoFallback.Visible := False;
  FMemoFallback.ScrollBars := ssBoth;
  FMemoFallback.WordWrap := False;
  FMemoFallback.Font.Name := 'Consolas';
  FMemoFallback.Font.Size := 10;
  FMemoFallback.OnChange := MemoFallbackChange;
end;

procedure TFRpMonacoEditorVCL.BAuditSQLClick(Sender: TObject);
begin
  ActivateAuditTab;
  if Assigned(FOnAuditSql) then
    FOnAuditSql(Self);
end;

destructor TFRpMonacoEditorVCL.Destroy;
begin
  if FGuard <> nil then
    FGuard.Invalidate;
  if FRetryTimer <> nil then
    FRetryTimer.Enabled := False;
  if Edge.WebViewCreated then
    Edge.CloseWebView;
  TRpAuthManager.Instance.UnregisterAuthListener(AuthChanged);
  inherited;
end;

procedure TFRpMonacoEditorVCL.CreateWnd;
begin
  inherited;

  if FUseFallback then
    Exit;

  // Testing/support aid: force the plain-text fallback regardless of WebView2
  // availability by setting the RPM_FORCE_WEBVIEW_FALLBACK environment variable.
  if GetEnvironmentVariable('RPM_FORCE_WEBVIEW_FALLBACK') <> '' then
  begin
    ActivateFallback('Forced by RPM_FORCE_WEBVIEW_FALLBACK');
    Exit;
  end;

  TryCreateWebView;
end;

procedure TFRpMonacoEditorVCL.DestroyWnd;
begin
  // The Edge is hosted on a TTabSheet, whose HWND is destroyed/recreated on tab
  // switches and theme/DPI changes. If that happens while a CreateWebView is in
  // flight, clear the in-flight flag so the next CreateWnd can retry cleanly
  // (otherwise we would stay "creating" forever and end up with a blank control).
  if FWebViewCreating and (Edge <> nil) and (not Edge.WebViewCreated) then
    FWebViewCreating := False;
  inherited;
end;

// Create the WebView2, guarded against re-entrancy. Setting UserDataFolder or
// calling CreateWebView twice (which happens when CreateWnd re-runs during the
// async creation, e.g. tab/HWND churn) raises an exception; that exception was
// the reason the plain-text Memo appeared even on machines where Edge loads fine.
procedure TFRpMonacoEditorVCL.TryCreateWebView;
var
  LDestPath: string;
begin
  if FUseFallback or FWebViewCreating or Edge.WebViewCreated then
    Exit;
  try
    Edge.HandleNeeded;
    if Edge.WebViewCreated then
      Exit;
    // UserDataFolder can only be set once, before the environment exists; setting
    // it again after a previous attempt raises. Do it exactly once.
    if not FUserDataFolderSet then
    begin
      LDestPath := ObtainFolderLocalUserConfig('Reportman', 'Monaco', '');
      Edge.UserDataFolder := TPath.Combine(LDestPath, 'EdgeData');
      FUserDataFolderSet := True;
    end;
    FWebViewCreating := True;
    Edge.CreateWebView;
  except
    on E: Exception do
    begin
      FWebViewCreating := False;
      ScheduleCreateRetryOrFallback('CreateWebView exception: ' + E.Message);
    end;
  end;
end;

// Retry a failed/aborted WebView creation a few times before giving up, instead
// of dropping to the Memo on the first transient failure. Mirrors the retry
// philosophy of TRpWebMarkdownView.
procedure TFRpMonacoEditorVCL.ScheduleCreateRetryOrFallback(const AReason: string);
const
  CMaxWebViewCreateRetries = 3;
begin
  if FUseFallback then
    Exit;
  OutputDebugString(PChar('Monaco WebView create issue: ' + AReason));
  if FWebViewCreateRetries >= CMaxWebViewCreateRetries then
  begin
    ActivateFallback(AReason);
    Exit;
  end;
  Inc(FWebViewCreateRetries);
  if FRetryTimer = nil then
  begin
    FRetryTimer := TTimer.Create(Self);
    FRetryTimer.OnTimer := WebViewRetryTimerTick;
  end;
  FRetryTimer.Enabled := False;
  FRetryTimer.Interval := 300 * FWebViewCreateRetries;
  FRetryTimer.Enabled := True;
end;

// Single retry tick shared by the create and navigation retry paths.
procedure TFRpMonacoEditorVCL.WebViewRetryTimerTick(Sender: TObject);
begin
  if FRetryTimer <> nil then
    FRetryTimer.Enabled := False;
  if FUseFallback then
    Exit;
  if not Edge.WebViewCreated then
    TryCreateWebView
  else if FLastNavUrl <> '' then
  begin
    try
      Edge.Navigate(FLastNavUrl);
    except
      // best-effort navigation retry; a real failure surfaces on the next
      // EdgeNavigationCompleted callback
    end;
  end;
end;

procedure TFRpMonacoEditorVCL.Resize;
begin
  inherited;
  LayoutTopControls;
end;

// Detect the folder that actually contains index.html after extraction.
// Supports two ZIP layouts:
//   flat: files at root (index.html, x64\…, x86\…)
//   nested: files inside a MonacoEditor\ sub-folder (legacy build artefact)
function FindMonacoActualRoot(const ABasePath: string): string;
begin
  if TFile.Exists(TPath.Combine(ABasePath, 'index.html')) or
     TFile.Exists(TPath.Combine(ABasePath, 'Index.html')) then
    Result := ABasePath
  else if TFile.Exists(TPath.Combine(ABasePath, 'MonacoEditor\index.html')) or
          TFile.Exists(TPath.Combine(ABasePath, 'MonacoEditor\Index.html')) then
    Result := TPath.Combine(ABasePath, 'MonacoEditor')
  else
    Result := '';
end;

function TFRpMonacoEditorVCL.EnsureMonacoAssetsExtracted: string;
var
  LBasePath: string;
  LVersionPath: string;
  LActualRoot: string;
  LResStream: TResourceStream;
  LZip: TZipFile;
begin
  LBasePath := ObtainFolderLocalUserConfig('Reportman', 'Monaco', 'MonacoEditor');
  LVersionPath := TPath.Combine(LBasePath, 'assets.version');

  // Return cached assets only when both index.html and a matching version marker exist
  LActualRoot := FindMonacoActualRoot(LBasePath);
  if (LActualRoot <> '') and
     TFile.Exists(LVersionPath) and
     SameText(Trim(TFile.ReadAllText(LVersionPath, TEncoding.UTF8)), MonacoAssetsVersion) then
  begin
    Result := LActualRoot;
    Exit;
  end;

  // Wipe stale/missing extraction and re-extract
  if TDirectory.Exists(LBasePath) then
    TDirectory.Delete(LBasePath, True);
  TDirectory.CreateDirectory(LBasePath);

  LResStream := TResourceStream.Create(HInstance, 'MONACO_ZIP', RT_RCDATA);
  try
    LZip := TZipFile.Create;
    try
      LZip.Open(LResStream, zmRead);
      LZip.ExtractAll(LBasePath);
    finally
      LZip.Free;
    end;
  finally
    LResStream.Free;
  end;

  // Resolve actual root after fresh extraction
  LActualRoot := FindMonacoActualRoot(LBasePath);
  if LActualRoot = '' then
    LActualRoot := LBasePath; // fallback: unknown layout, use base

  TFile.WriteAllText(LVersionPath, MonacoAssetsVersion, TEncoding.UTF8);

  Result := LActualRoot;
end;

procedure TFRpMonacoEditorVCL.EdgeCreateWebViewCompleted(
  Sender: TCustomEdgeBrowser; AResult: HRESULT);
var
  LURL: string;
begin
  FWebViewCreating := False;
  if Succeeded(AResult) then
  begin
    FWebViewCreateRetries := 0;

    // Ensure Edge events are hooked up
    Edge.OnWebMessageReceived := EdgeWebMessageReceived;
    Edge.OnNavigationCompleted := EdgeNavigationCompleted;

    if FAssetRootPath = '' then
      FAssetRootPath := EnsureMonacoAssetsExtracted;

    LURL := 'file:///' + FAssetRootPath.Replace('\', '/');
    if not LURL.EndsWith('/') then
      LURL := LURL + '/';
    LURL := LURL + 'index.html';

    FLastNavUrl := LURL;
    FNavRetryCount := 0;
    Edge.Navigate(LURL);
  end
  else
  begin
    // WebView2 could not be created. This is often transient when the host
    // TTabSheet HWND churns during the async creation, so retry a few times
    // before dropping to the plain-text editor. A genuinely missing runtime
    // (e.g. HRESULT 80070002) simply exhausts the retries and then falls back.
    ScheduleCreateRetryOrFallback('CreateWebViewCompleted HRESULT: ' + IntToHex(AResult, 8));
  end;
end;

procedure TFRpMonacoEditorVCL.EdgeNavigationCompleted(Sender: TCustomEdgeBrowser;
  IsSuccess: Boolean; WebErrorStatus: TOleEnum);
const
  // Transient COREWEBVIEW2_WEB_ERROR_STATUS values seen when navigation is
  // interrupted (HWND recreated/disposed mid-load on tab/theme changes):
  //   0 = Unknown, 9 = ConnectionAborted, 14 = OperationCanceled.
  MaxNavRetries = 3;
var
  LStatus: Integer;
begin
  if IsSuccess then
  begin
    FNavRetryCount := 0;
    SetSQL(FSQL);
    Exit;
  end;

  // Retry transient navigation failures instead of leaving the editor blank,
  // mirroring TRpWebMarkdownView. A genuine failure just stops here: the SQL is
  // still safe in FSQL and reachable through the plain-text fallback if the
  // WebView later fails to create.
  LStatus := Integer(WebErrorStatus);
  if ((LStatus = 0) or (LStatus = 9) or (LStatus = 14)) and
     (FNavRetryCount < MaxNavRetries) and (FLastNavUrl <> '') then
  begin
    Inc(FNavRetryCount);
    if FRetryTimer = nil then
    begin
      FRetryTimer := TTimer.Create(Self);
      FRetryTimer.OnTimer := WebViewRetryTimerTick;
    end;
    FRetryTimer.Enabled := False;
    FRetryTimer.Interval := 200 * FNavRetryCount;
    FRetryTimer.Enabled := True;
  end
  else
    OutputDebugString(PChar('Monaco navigation failed, status ' + IntToStr(LStatus)));
end;

procedure TFRpMonacoEditorVCL.SetSQL(const Value: string);
var
  LJSON: TJSONString;
  LScript: string;
begin
  if FUpdatingFromBrowser then
    Exit;

  FSQL := Value;

  if FUseFallback then
  begin
    if FMemoFallback <> nil then
    begin
      FUpdatingFromBrowser := True;
      try
        FMemoFallback.Lines.Text := FSQL;
      finally
        FUpdatingFromBrowser := False;
      end;
    end;
    Exit;
  end;

  if Edge.WebViewCreated then
  begin
    LJSON := TJSONString.Create(FSQL);
    try
      LScript := 'if (window.editor) { window.editor.setValue(' + LJSON.ToJSON + '); }';
      Edge.ExecuteScript(LScript);
    finally
      LJSON.Free;
    end;
  end;
end;

procedure TFRpMonacoEditorVCL.ApplySQL(const ASQL: string);
var
  LJSON: TJSONString;
begin
  if FUpdatingFromBrowser then
    Exit;
  if FUseFallback then
  begin
    FSQL := ASQL;
    if FMemoFallback <> nil then
    begin
      // Replacing the selection can be undone (Lines.Text can not)
      FUpdatingFromBrowser := True;
      try
        FMemoFallback.SelectAll;
        FMemoFallback.SelText := FSQL;
      finally
        FUpdatingFromBrowser := False;
      end;
    end;
    Exit;
  end;
  if not Edge.WebViewCreated then
  begin
    SetSQL(ASQL);
    Exit;
  end;
  FSQL := ASQL;
  // executeEdits keeps the undo stack of Monaco (setValue clears it)
  LJSON := TJSONString.Create(FSQL);
  try
    Edge.ExecuteScript('if (window.editor) { var m = window.editor.getModel();' +
      ' window.editor.pushUndoStop();' +
      ' window.editor.executeEdits("reportman-ai", [{ range: m.getFullModelRange(), text: ' +
      LJSON.ToJSON + ', forceMoveMarkers: true }]);' +
      ' window.editor.pushUndoStop(); }');
  finally
    LJSON.Free;
  end;
end;

procedure TFRpMonacoEditorVCL.ActivateFallback(const AReason: string);
begin
  if FUseFallback then
    Exit; // idempotent: never double-activate
  // Always surface the reason on a reliable channel: the inference log routes to
  // the chat, which may not exist yet when an early fallback fires.
  OutputDebugString(PChar('Monaco fallback activated: ' + AReason));
  FUseFallback := True;
  FEditorReady := False;

  if Edge <> nil then
    Edge.Visible := False;
  if FMemoFallback <> nil then
  begin
    FUpdatingFromBrowser := True;
    try
      FMemoFallback.Lines.Text := FSQL; // seed with the current SQL
    finally
      FUpdatingFromBrowser := False;
    end;
    FMemoFallback.Visible := True;
    FMemoFallback.BringToFront;
  end;

  // Surface the failure and an actionable hint through the log channel (the chat /
  // AI log already fall back to a plain memo) without polluting the SQL text.
  EmitInferenceLog('System',
    'Fallback activated due to WebView failure: ' + AReason, True);
  EmitInferenceLog('System', SRpMonacoWebViewFallbackHint, True);
end;

procedure TFRpMonacoEditorVCL.MemoFallbackChange(Sender: TObject);
var
  LNewSQL: string;
begin
  if (not FUseFallback) or FUpdatingFromBrowser then
    Exit;
  if FMemoFallback = nil then
    Exit;
  LNewSQL := FMemoFallback.Lines.Text;
  // Normalize line endings exactly like the WebView '01:' path so FSQL is the
  // same regardless of which editor produced it.
  LNewSQL := LNewSQL.Replace(#13#10, #10).Replace(#13, #10).Replace(#10, #13#10);
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

procedure TFRpMonacoEditorVCL.SetAuditText(const Value: string);
begin
  FAuditText := Value;
  if MemoAudit <> nil then
    MemoAudit.Lines.Text := Value;
end;

procedure TFRpMonacoEditorVCL.LoadSQL(const ASQL: string);
begin
  SetSQL(ASQL);
end;

procedure TFRpMonacoEditorVCL.ClearLog;
begin
end;

procedure TFRpMonacoEditorVCL.AppendLog(const AText: string);
begin
  EmitInferenceLog('Audit', AText, True);
end;

procedure TFRpMonacoEditorVCL.EmitInferenceLog(const ASource, AText: string;
  AAppendLineBreak: Boolean);
begin
  if Assigned(FOnInferenceLog) then
    FOnInferenceLog(Self, ASource, AText, AAppendLineBreak);
end;

procedure TFRpMonacoEditorVCL.ActivateAuditTab;
begin
  if PControl <> nil then
    PControl.ActivePage := TabAudit;
end;

procedure TFRpMonacoEditorVCL.SetAuditBusy(AValue: Boolean);
begin
  if BAuditSQL <> nil then
    BAuditSQL.Enabled := not AValue;
  if FAISelection <> nil then
    FAISelection.SetInferenceProgress(AValue);
end;

procedure TFRpMonacoEditorVCL.UpdateAITokens(AInTokens, AOutTokens: Integer;
  const AProgressId: string = ''; APrefillPercent: Integer = 0);
begin
  if FAISelection <> nil then
    FAISelection.UpdateTokens(AInTokens, AOutTokens, AProgressId,
      APrefillPercent);
end;

function TFRpMonacoEditorVCL.GetAITier: string;
begin
  if FAISelection <> nil then
    Result := FAISelection.AITier
  else
    Result := 'Standard';
end;

function TFRpMonacoEditorVCL.GetAIMode: string;
begin
  if FAISelection <> nil then
    Result := FAISelection.AIMode
  else
    Result := 'Fast';
end;

function TFRpMonacoEditorVCL.GetAgentSecret: string;
begin
  if FAISelection <> nil then
    Result := FAISelection.AgentSecret
  else
    Result := '';
end;

function TFRpMonacoEditorVCL.GetAgentAiId: Int64;
begin
  if FAISelection <> nil then
    Result := FAISelection.AgentAiId
  else
    Result := 0;
end;

function TFRpMonacoEditorVCL.LoadUserSchemas(AList: TStrings): Boolean;
var
  LHttp: TRpDatabaseHttp;
begin
  Result := False;
  AList.Clear;
  if TRpAuthManager.Instance.Token = '' then
    Exit;

  LHttp := TRpDatabaseHttp.Create;
  try
    LHttp.Token := TRpAuthManager.Instance.Token;
    LHttp.InstallId := TRpAuthManager.Instance.InstallId;
    Result := LHttp.GetUserSchemas(AList);
  finally
    LHttp.Free;
  end;
end;

function TFRpMonacoEditorVCL.LoadApiKeySchemas(const AApiKey: string;
  AList: TStrings): Boolean;
var
  LHttp: TRpDatabaseHttp;
begin
  Result := False;
  AList.Clear;
  if Trim(AApiKey) = '' then
    Exit;

  LHttp := TRpDatabaseHttp.Create;
  try
    LHttp.ApiKey := Trim(AApiKey);
    LHttp.Token := TRpAuthManager.Instance.Token;
    LHttp.InstallId := TRpAuthManager.Instance.InstallId;
    Result := LHttp.GetUserSchemas(AList);
  finally
    LHttp.Free;
  end;
end;

// 'Name=db|schema|apikey' and the state of the Agent; a schema once, by its
// Hub database and schema
procedure TFRpMonacoEditorVCL.AddMergedSchemas(ASource, ADest,
  ASeenKeys: TStrings; const ADefaultApiKey: string);
var
  I: Integer;
  LSchemaKey: string;
begin
  for I := 0 to ASource.Count - 1 do
  begin
    LSchemaKey := RpHubSchemaKey(ASource.ValueFromIndex[I]);
    if ASeenKeys.IndexOf(LSchemaKey) >= 0 then
      Continue;
    ASeenKeys.Add(LSchemaKey);
    ADest.Add(RpHubSchemaLineWithApiKey(ASource[I], ADefaultApiKey));
  end;
end;

procedure TFRpMonacoEditorVCL.ApplyUserSchemas(AList: TStrings);
begin
  FUpdatingSchemaList := True;
  try
    FSchemaList.SetCloudSchemas(AList, nil);
  finally
    FUpdatingSchemaList := False;
  end;
  SyncSchemaFromList;
end;

function TFRpMonacoEditorVCL.LoadUserAgents(AList: TStrings): Boolean;
var
  LHttp: TRpDatabaseHttp;
begin
  Result := False;
  AList.Clear;
  if TRpAuthManager.Instance.Token = '' then
    Exit;

  LHttp := TRpDatabaseHttp.Create;
  try
    LHttp.Token := TRpAuthManager.Instance.Token;
    LHttp.InstallId := TRpAuthManager.Instance.InstallId;
    Result := LHttp.GetUserAgents(AList);
  finally
    LHttp.Free;
  end;
end;

procedure TFRpMonacoEditorVCL.ApplyUserAgents(AList: TStrings;
  const ASelectedTier: string; ASelectedAgentAiId: Int64);
var
  I: Integer;
  LAgentName: string;
  LAgentValue: string;
  LParts: TStringList;
  LAgentAiId: Int64;
  LAgentSecret: string;
  LAgentOnline: Boolean;
begin
  FAISelection.ClearAgentEndpoints;

  LParts := TStringList.Create;
  try
    LParts.Delimiter := '|';
    LParts.StrictDelimiter := True;
    for I := 0 to AList.Count - 1 do
    begin
      LAgentName := AList.Names[I];
      LAgentValue := AList.ValueFromIndex[I];
      LParts.DelimitedText := LAgentValue;
      if LParts.Count >= 2 then
      begin
        LAgentAiId := StrToInt64Def(LParts[0], 0);
        LAgentSecret := LParts[1];
        LAgentOnline := (LParts.Count >= 3) and (LParts[2] = '1');
        if LAgentOnline then
          FAISelection.AddAgentEndpoint(LAgentAiId, LAgentSecret, LAgentName, True);
      end;
    end;
  finally
    LParts.Free;
  end;

  FAISelection.RestoreProviderSelection(ASelectedTier, ASelectedAgentAiId);
end;

procedure TFRpMonacoEditorVCL.SetSchema(const ASchema: string);
var
  I: Integer;
begin
  // By its text, with or without the icon of the list
  for I := 0 to ComboSchema.Items.Count - 1 do
    if (ComboSchema.Items[I] = ASchema) or ((ASchema <> '') and
      (Copy(ComboSchema.Items[I], Length(ComboSchema.Items[I]) -
      Length(ASchema) + 1, MaxInt) = ASchema)) then
    begin
      ComboSchema.ItemIndex := I;
      FUpdatingSchemaList := True;
      try
        ComboSchema.OnChange(ComboSchema);
      finally
        FUpdatingSchemaList := False;
      end;
      Exit;
    end;
end;

procedure TFRpMonacoEditorVCL.SchemaListConfigureLocalSchemas(Sender: TObject;
  const AAlias, AName: string; AAddNew: Boolean);
begin
  if Assigned(FOnConfigureLocalSchemas) then
    FOnConfigureLocalSchemas(Self, AAlias, AName, AAddNew);
end;

// The schema the AI uses: the subschema or the cloud schema chosen; with none
// the Hub database of the connection; while the cloud list loads, the cloud
// schema of the context
procedure TFRpMonacoEditorVCL.SyncSchemaFromList;
begin
  if FSchemaList.GetLocalSchemaName <> '' then
  begin
    FHubDatabaseId := 0;
    FHubSchemaId := 0;
    FSchemaApiKey := '';
  end
  else if FSchemaList.HasSchema then
  begin
    FHubDatabaseId := FSchemaList.GetHubDatabaseId;
    FHubSchemaId := FSchemaList.GetHubSchemaId;
    FSchemaApiKey := FSchemaList.GetSchemaApiKey;
  end
  else
  begin
    FHubDatabaseId := FSchemaList.GetHubDatabaseId;
    if FHubDatabaseId = 0 then
      FHubDatabaseId := FBaseHubDatabaseId;
    FHubSchemaId := FSchemaList.GetHubSchemaId;
    FSchemaApiKey := FSchemaList.GetSchemaApiKey;
    if FSchemaApiKey = '' then
      FSchemaApiKey := FBaseApiKey;
  end;
  if FSchemaList.HasSchema then
    FSchema := ComboSchema.Text
  else
    FSchema := '';
end;

procedure TFRpMonacoEditorVCL.SchemaListChanged(Sender: TObject);
begin
  SyncSchemaFromList;
  // Only a choice of the user goes to the host (the dataset keeps it)
  if FUpdatingSchemaList or FSchemaList.ChangeFromLoad then
    Exit;
  if Assigned(FOnSchemaChanged) then
    FOnSchemaChanged(Self);
end;

procedure TFRpMonacoEditorVCL.SetHubContext(AHubDatabaseId,
  AHubSchemaId: Int64; const ASchemaApiKey: string);
var
  LBaseApiKey: string;
  LNeedsSchemaReload: Boolean;
begin
  LBaseApiKey := Trim(ASchemaApiKey);
  // The cloud list has the schemas visible with the API key of the
  // connection: another key, another list
  LNeedsSchemaReload := FBaseApiKey <> LBaseApiKey;
  FBaseHubDatabaseId := AHubDatabaseId;
  FBaseApiKey := LBaseApiKey;
  FUpdatingSchemaList := True;
  try
    FSchemaList.SetPreferredConnection(AHubDatabaseId, LBaseApiKey);
    if LNeedsSchemaReload and FSchemaList.CloudLoaded then
      FSchemaList.ClearCloudSchemas;
    FSchemaList.SetHubContext(AHubDatabaseId, AHubSchemaId, LBaseApiKey);
  finally
    FUpdatingSchemaList := False;
  end;
  SyncSchemaFromList;
  if (not FSchemaList.CloudLoaded) and TRpAuthManager.Instance.IsLoggedIn then
    UpdateAuthUI;
end;

procedure TFRpMonacoEditorVCL.SetHubDatabaseId(const Value: Int64);
begin
  SetHubContext(Value, 0, FBaseApiKey);
end;

procedure TFRpMonacoEditorVCL.SetHubSchemaId(const Value: Int64);
begin
  SetHubContext(FBaseHubDatabaseId, Value, FBaseApiKey);
end;

procedure TFRpMonacoEditorVCL.SetLocalSchemas(const AAlias: string;
  ANames, ASizes: TStrings);
begin
  // The file may have changed: its config is read again
  FLocalSchemaConfigKey := '';
  FLocalSchemaConfigJson := '';
  FUpdatingSchemaList := True;
  try
    FSchemaList.SetLocalSchemas(AAlias, ANames, ASizes);
  finally
    FUpdatingSchemaList := False;
  end;
  SyncSchemaFromList;
end;

procedure TFRpMonacoEditorVCL.SelectLocalSchema(const AName: string);
begin
  FUpdatingSchemaList := True;
  try
    FSchemaList.SelectLocalSchema(AName);
  finally
    FUpdatingSchemaList := False;
  end;
end;

function TFRpMonacoEditorVCL.GetLocalSchemaAlias: string;
begin
  Result := FSchemaList.LocalAlias;
end;

function TFRpMonacoEditorVCL.GetLocalSchemaName: string;
begin
  Result := FSchemaList.GetLocalSchemaName;
end;

function TFRpMonacoEditorVCL.LocalSchemaKey: string;
begin
  Result := '';
  if FSchemaList.GetLocalSchemaName <> '' then
    Result := UpperCase(FSchemaList.LocalAlias) + #1 +
      FSchemaList.GetLocalSchemaName;
end;

function TFRpMonacoEditorVCL.LocalSchemaConfigJson: string;
var
  LKey: string;
begin
  Result := '';
  LKey := LocalSchemaKey;
  if (LKey = '') or not Assigned(FOnLocalSchemaConfig) then
    Exit;
  if LKey <> FLocalSchemaConfigKey then
  begin
    FLocalSchemaConfigKey := '';
    FLocalSchemaConfigJson := FOnLocalSchemaConfig(Self, FSchemaList.LocalAlias,
      FSchemaList.GetLocalSchemaName);
    FLocalSchemaConfigKey := LKey;
  end;
  Result := FLocalSchemaConfigJson;
end;

function TFRpMonacoEditorVCL.GetSchemaApiKey: string;
begin
  Result := FSchemaApiKey;
end;

procedure TFRpMonacoEditorVCL.EdgeWebMessageReceived(
  Sender: TCustomEdgeBrowser;
  Args: TWebMessageReceivedEventArgs);
var
  LP: PWideChar;
  LMsg: string;
begin
  try
    LP:=nil;
    // THIS LINE IS THE ONE THE USER SAYS WORKS FOR THEM:
    Args.ArgsInterface.TryGetWebMessageAsString(LP);
    if LP <> nil then
    begin
      LMsg := LP;
      CoTaskMemFree(LP);
      TThread.ForceQueue(nil,
        procedure
        begin
          ProcessWebMessage(LMsg);
        end);
    end;
  except
    on E: Exception do
      TThread.ForceQueue(nil,
        procedure
        begin
          RpMessageBox('Error in Monaco messaging: '+E.Message, '',
            [smbOK], smsCritical, smbOK, smbOK);
        end);
  end;
end;

procedure TFRpMonacoEditorVCL.ProcessWebMessage(const LMessage: string);
var
  LNewSQL: string;
begin
  OutputDebugString(PChar('MonacoWebMessage: ' + LMessage));
  if FUpdatingFromBrowser then 
    Exit;

  if Copy(LMessage, 1, 3) = '00:' then
  begin
    FEditorReady := True;
    SetSQL(FSQL);
    Exit;
  end;

  if Copy(LMessage, 1, 3) = '02:' then
  begin
    HandleAICompletionRequest(Copy(LMessage, 4, MaxInt));
    Exit;
  end;

  if Copy(LMessage, 1, 3) <> '01:' then
    Exit;

  LNewSQL := Copy(LMessage, 4, MaxInt);
  // Normalizing line endings handles the difference between JS (\n) and Delphi (\r\n)
  LNewSQL := LNewSQL.Replace(#13#10, #10).Replace(#13, #10).Replace(#10, #13#10);

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

procedure TFRpMonacoEditorVCL.AIToggleClick(Sender: TObject);
begin
  TRpAuthManager.Instance.AIEnabled := FAIButton.Down;
  UpdateAuthUI;
end;

procedure TFRpMonacoEditorVCL.AISelectionStopRequest(Sender: TObject);
var
  LInlineItems, LCompletionItems: TJSONArray;
  LRequestId: string;
begin
  // Stop of the model selection: the running AI completion stream ends
  // (SuggestSqlStreamCancelRequested) and the page gets an empty answer;
  // the host stops the audit (OnStopRequest)
  FDebounceTimer.Enabled := False;
  LRequestId := FActiveInferenceRequestId;
  FPendingRequestId := '';
  FRestartPendingInference := False;
  if LRequestId <> '' then
  begin
    LInlineItems := TJSONArray.Create;
    LCompletionItems := TJSONArray.Create;
    SendAICompletions(LInlineItems, LCompletionItems, LRequestId);
  end;
  if Assigned(FOnStopRequest) then
    FOnStopRequest(Self);
end;

procedure TFRpMonacoEditorVCL.SchemaConfigClick(Sender: TObject);
begin
  // The local schemas of the connection, the schemas in the cloud, refresh
  FSchemaList.PopupConfigMenu(FSchemaConfigButton);
end;

procedure TFRpMonacoEditorVCL.HandleAICompletionRequest(const APayload: string);
var
  LEmptyInlineItems, LEmptyCompletionItems: TJSONArray;
  LHeaderEnd, LOffsetSeparator: Integer;
  LHeader: string;
begin
  if FUseFallback then
    Exit; // no AI autocomplete in plain-text fallback
  FDebounceTimer.Enabled := False;
  
  FPendingRequestId := '';
  FPendingSql := '';
  FPendingPos := 0;

  LHeaderEnd := Pos(#10, APayload);
  if LHeaderEnd <= 0 then
    Exit;

  LHeader := Copy(APayload, 1, LHeaderEnd - 1).Replace(#13, '');
  LOffsetSeparator := LastDelimiter(':', LHeader);
  if LOffsetSeparator <= 1 then
    Exit;

  FPendingRequestId := Copy(LHeader, 1, LOffsetSeparator - 1);
  FPendingPos := StrToIntDef(Copy(LHeader, LOffsetSeparator + 1, MaxInt), 0);
  FPendingSql := Copy(APayload, LHeaderEnd + 1, MaxInt);

  if FPendingRequestId = '' then
    Exit;

  // Restaurado a petición: cancela la inferencia devolviendo vacío si el texto no ha cambiado (ej: solo movimiento de cursor)
  if FPendingSql = FLastAutoCompleteSql then
  begin
    LEmptyInlineItems := TJSONArray.Create;
    LEmptyCompletionItems := TJSONArray.Create;
    SendAICompletions(LEmptyInlineItems, LEmptyCompletionItems, FPendingRequestId);
    Exit;
  end;

  if not TRpAuthManager.Instance.AIEnabled then
  begin
    LEmptyInlineItems := TJSONArray.Create;
    LEmptyCompletionItems := TJSONArray.Create;
    SendAICompletions(LEmptyInlineItems, LEmptyCompletionItems, FPendingRequestId);
    Exit;
  end;

  if FInferenceRunning then
    FRestartPendingInference := True
  else
    FDebounceTimer.Enabled := True;
end;

procedure TFRpMonacoEditorVCL.OnDebounceTimer(Sender: TObject);
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

procedure TFRpMonacoEditorVCL.StartPendingInference;
var
  LGuard: IEditorGuard;
  LStartRequestId: string;
  LStartSql: string;
  LStartPos: Integer;
  LTaskProc: TProc;
  LApiKey, LToken, LInstallId, LRuntimeDb, LAITier, LAgentSecret, LAIMode: string;
  LInlineConfigJson: string;
  LHubDatabaseId, LHubSchemaId, LAgentAiId: Int64;
begin
  if FUseFallback then
    Exit; // no AI autocomplete in plain-text fallback
  if FInferenceRunning then
    Exit;

  if not TRpAuthManager.Instance.AIEnabled then
    Exit;

  LStartRequestId := FPendingRequestId;
  LStartSql := FPendingSql;
  LStartPos := FPendingPos;
  if LStartRequestId = '' then
    Exit;
  // A subschema of the direct connection goes inline; a direct connection
  // without one is not in the Hub: no AI completion
  LInlineConfigJson := '';
  if GetLocalSchemaName <> '' then
  begin
    try
      LInlineConfigJson := LocalSchemaConfigJson;
    except
      on E: Exception do
        EmitInferenceLog('Autocomplete', E.Message, True);
    end;
    if LInlineConfigJson = '' then
    begin
      SendAICompletions(TJSONArray.Create, TJSONArray.Create, LStartRequestId);
      Exit;
    end;
  end
  else if (GetLocalSchemaAlias <> '') and (FHubDatabaseId = 0) and
    (FHubSchemaId = 0) then
  begin
    SendAICompletions(TJSONArray.Create, TJSONArray.Create, LStartRequestId);
    Exit;
  end;

  FLastAutoCompleteSql := LStartSql;
  FActiveInferenceRequestId := LStartRequestId;
  FInferenceRunning := True;
  FRestartPendingInference := False;
  LGuard := FGuard;
  // Read here, not in the task: the schema combo and the model selection are
  // controls of the main thread (a schema reload frees the combo objects)
  LApiKey := GetSchemaApiKey;
  LToken := TRpAuthManager.Instance.Token;
  LInstallId := TRpAuthManager.Instance.InstallId;
  LHubDatabaseId := FHubDatabaseId;
  LHubSchemaId := FHubSchemaId;
  LRuntimeDb := FRuntimeDb;
  LAITier := FAISelection.AITier;
  LAgentSecret := FAISelection.AgentSecret;
  LAgentAiId := FAISelection.AgentAiId;
  LAIMode := FAISelection.AIMode;

  // Create AI completion task (asynchronous)
  LTaskProc := procedure
    var
      LHttp: TRpDatabaseHttp;
      LRequestId, LSql: string;
      LPos: Integer;
      LResponse: TJSONObject;
      LResult, LAutoComplete: TJSONObject;
      LInlineArr, LListArr: TJSONArray;
      LVal: TJSONValue;
      LTokenUsage: TJSONObject;
      LInT, LOutT: Integer;
      LInlineItems, LCompletionItems: TJSONArray;
      I: Integer;
      LItem: TJSONObject;
      LUAIMode: string;
      LShouldRestart: Boolean;
      LInnerQueueProc: TThreadProcedure;
    begin
      LRequestId := LStartRequestId;
      LSql := LStartSql;
      LPos := LStartPos;
      LInT := 0;
      LOutT := 0;
      
      LInnerQueueProc := procedure
        begin
          if (LGuard <> nil) and (not LGuard.IsCancelled) then
          begin
            FAISelection.SetInferenceProgress(True);
            EmitInferenceLog('Autocomplete', 'Actor: Assistant', True);
          end;
        end;
      TThread.Queue(nil, LInnerQueueProc);

      LHttp := TRpDatabaseHttp.Create;
      try
        LHttp.ApiKey := LApiKey;
        LHttp.Token := LToken;
        LHttp.InstallId := LInstallId;
        LHttp.HubDatabaseId := LHubDatabaseId;
        LHttp.HubSchemaId := LHubSchemaId;
        LHttp.InlineConfigJson := LInlineConfigJson;
        LHttp.RuntimeDb := LRuntimeDb;
        LHttp.AITier := LAITier;
        LHttp.AgentSecret := LAgentSecret;
        LHttp.AgentAiId := LAgentAiId;
        LUAIMode := LAIMode;

        try
          LResponse := LHttp.SuggestSql(LSql, LPos, LUAIMode, Self,
            SuggestSqlStreamProgress, SuggestSqlStreamCancelRequested);
        except
          on E: Exception do
          begin
            TRpAuthManager.Instance.Log('SuggestSql Error: ' + E.Message);
            LResponse := nil;
          end;
        end;

        // Build Monaco-compatible response: { inlineItems: [...], completionItems: [...] }
        LInlineItems := TJSONArray.Create;
        LCompletionItems := TJSONArray.Create;

        if LResponse <> nil then
        try
          // Navigate: response.result.autoComplete
          LVal := LResponse.Values['result'];
          if (LVal <> nil) and (LVal is TJSONObject) then
          begin
            LResult := LVal as TJSONObject;
            LVal := LResult.Values['autoComplete'];
            if (LVal <> nil) and (LVal is TJSONObject) then
            begin
              LAutoComplete := LVal as TJSONObject;

              // Parse inlineCompletions → inlineItems (ghost text)
              LVal := LAutoComplete.Values['inlineCompletions'];
              if (LVal <> nil) and (LVal is TJSONArray) then
              begin
                LInlineArr := LVal as TJSONArray;
                for I := 0 to LInlineArr.Count - 1 do
                begin
                  LItem := TJSONObject.Create;
                  LItem.AddPair('insertText', LInlineArr.Items[I].Value);
                  LInlineItems.AddElement(LItem);
                end;
              end;

              // Parse listCompletions → completionItems (dropdown)
              LVal := LAutoComplete.Values['listCompletions'];
              if (LVal <> nil) and (LVal is TJSONArray) then
              begin
                LListArr := LVal as TJSONArray;
                for I := 0 to LListArr.Count - 1 do
                begin
                  LItem := TJSONObject.Create;
                  LItem.AddPair('label', LListArr.Items[I].Value);
                  LItem.AddPair('insertText', LListArr.Items[I].Value);
                  LItem.AddPair('detail', 'AI');
                  LCompletionItems.AddElement(LItem);
                end;
              end;
            end;
          end;

          // Update credit gauge if available
          LVal := LResponse.Values['userProfile'];
          if (LVal <> nil) and (LVal is TJSONObject) then
          begin
             LItem := LVal.Clone as TJSONObject;
             LInnerQueueProc := procedure
               begin
                 try
                   if (LGuard <> nil) and (not LGuard.IsCancelled) then
                     TRpAuthManager.Instance.UpdateProfileFromJson(LItem);
                 finally
                   LItem.Free;
                 end;
               end;
             TThread.Queue(nil, LInnerQueueProc);
          end;
          // Update token info for UI log & selector
          LVal := LResponse.Values['tokenUsage'];
          if LVal = nil then
          begin
            LVal := LResponse.Values['result'];
            if (LVal <> nil) and (LVal is TJSONObject) then
              LVal := (LVal as TJSONObject).Values['tokenUsage'];
          end;

          if (LVal <> nil) and (LVal is TJSONObject) then
          begin
            LTokenUsage := LVal as TJSONObject;
            LVal := LTokenUsage.Values['inputTokens'];
            if (LVal <> nil) and not (LVal is TJSONNull) then
            begin
              if LVal is TJSONNumber then
                LInT := (LVal as TJSONNumber).AsInt
              else
                LInT := StrToIntDef(LVal.Value, 0);
            end;
            
            LVal := LTokenUsage.Values['outputTokens'];
            if (LVal <> nil) and not (LVal is TJSONNull) then
            begin
              if LVal is TJSONNumber then
                LOutT := (LVal as TJSONNumber).AsInt
              else
                LOutT := StrToIntDef(LVal.Value, 0);
            end;
          end;
        finally
          LResponse.Free;
        end;

        // Dispatch back to main thread for WebView interaction
        LInnerQueueProc := procedure
          begin
            LShouldRestart := False;
            if (LGuard <> nil) and (not LGuard.IsCancelled) then
            begin
              if LRequestId <> FPendingRequestId then
              begin
                LInlineItems.Free;
                LCompletionItems.Free;
                FAISelection.SetInferenceProgress(False);
                FInferenceRunning := False;
                if FActiveInferenceRequestId = LRequestId then
                  FActiveInferenceRequestId := '';
                LShouldRestart := FRestartPendingInference;
                FRestartPendingInference := False;
                if LShouldRestart then
                  StartPendingInference;
                Exit;
              end;

              FAISelection.UpdateTokens(LInT, LOutT, LRequestId);
              if LInT > 0 then
                EmitInferenceLog('Autocomplete', 'Inference complete. Input Tokens: ' + IntToStr(LInT) + ' Output Tokens: ' + IntToStr(LOutT), True)
              else
                EmitInferenceLog('Autocomplete', 'Inference complete.', True);

              SendAICompletions(LInlineItems, LCompletionItems, LRequestId);
              FAISelection.SetInferenceProgress(False);
              LShouldRestart := FRestartPendingInference and (FPendingRequestId <> LRequestId);
              FInferenceRunning := False;
              if FActiveInferenceRequestId = LRequestId then
                FActiveInferenceRequestId := '';
              FRestartPendingInference := False;
              if LShouldRestart then
                StartPendingInference;
            end
            else
            begin
              LInlineItems.Free;
              LCompletionItems.Free;
              FInferenceRunning := False;
              if FActiveInferenceRequestId = LRequestId then
                FActiveInferenceRequestId := '';
              FRestartPendingInference := False;
            end;
          end;
        TThread.Queue(nil, LInnerQueueProc);
      finally
        LHttp.Free;
      end;
    end;
  FInferenceTask := TTask.Run(LTaskProc);
end;

function TFRpMonacoEditorVCL.SuggestSqlStreamCancelRequested(
  Sender: TObject): Boolean;
begin
  Result := (FActiveInferenceRequestId <> '') and
    (FActiveInferenceRequestId <> FPendingRequestId);
end;

procedure TFRpMonacoEditorVCL.SuggestSqlStreamProgress(Sender: TObject;
  const AActor, AStage, AChunkType, AChunk: string; AInputTokens,
  AOutputTokens: Integer; const AProgressId: string; APrefillPercent: Integer);
var
  LAActor: string;
  LStage: string;
  LChunk: string;
  LChunkType: string;
  LProgressId: string;
  LInputTokens: Integer;
  LOutputTokens: Integer;
  LPrefillPercent: Integer;
  LQueueProc: TThreadProcedure;
begin
  LAActor := AActor;
  LStage := AStage;
  LChunk := AChunk;
  LChunkType := AChunkType;
  LProgressId := AProgressId;
  LInputTokens := AInputTokens;
  LOutputTokens := AOutputTokens;
  LPrefillPercent := APrefillPercent;
  LQueueProc := procedure
    begin
      if (FAISelection <> nil) and SameText(LAActor, 'AI') and
        (Trim(LProgressId) <> '') then
        FAISelection.TouchProgressToken(LProgressId);
      if (FAISelection <> nil) and SameText(LAActor, 'AI') then
        FAISelection.UpdateTokens(LInputTokens, LOutputTokens, LProgressId,
          LPrefillPercent);
      if (FAISelection <> nil) and SameText(LAActor, 'AI') and
        (SameText(LChunkType, 'End') or SameText(LChunkType, 'Full')) then
        FAISelection.FinishProgressToken(LProgressId);
      if not SameText(FActiveInferenceRequestId, FPendingRequestId) then
        Exit;
      if not SameText(LStage, 'ReceivingResponse') then
        Exit;
      if LChunk = '' then
        Exit;
      Self.EmitInferenceLog(LAActor, LChunk, SameText(LChunkType, 'End'));
    end;
  TThread.Queue(nil, LQueueProc);
end;

procedure TFRpMonacoEditorVCL.SendAICompletions(const AInlineItems, ACompletionItems: TJSONArray; const ARequestId: string);
var
  LResponse: TJSONObject;
  LScript: string;
  LEscapedJson: string;
begin
  if FUseFallback then
  begin
    // No WebView to push completions to; free the inputs (this method owns them).
    AInlineItems.Free;
    ACompletionItems.Free;
    Exit;
  end;
  // Build { inlineItems: [...], completionItems: [...] }
  LResponse := TJSONObject.Create;
  try
    LResponse.AddPair('inlineItems', AInlineItems.Clone as TJSONArray);
    LResponse.AddPair('completionItems', ACompletionItems.Clone as TJSONArray);

    // Match Desktop: receiveAICompletions(requestId, response)
    LEscapedJson := LResponse.ToJSON;
    LScript := 'window.receiveAICompletions(''' + ARequestId + ''', ' + LEscapedJson + ');';
    Edge.ExecuteScript(LScript);
  finally
    LResponse.Free;
    AInlineItems.Free;
    ACompletionItems.Free;
  end;
end;

procedure TFRpMonacoEditorVCL.LayoutTopControls;
var
  LAISelectionWidth: Integer;
  LBottomMargin: Integer;
  LButtonSize: Integer;
  LChildWidth: Integer;
  LColumnWidth: Integer;
  LComboHeight: Integer;
  LHeaderHeight: Integer;
  LTopMargin: Integer;
begin
  if GridTopHeader <> nil then
  begin
    if GridTopHeader.ColumnCollection.Count > 0 then
    begin
      GridTopHeader.ColumnCollection[0].SizeStyle := ssPercent;
      GridTopHeader.ColumnCollection[0].Value := 100;
    end;

    if GridTopHeader.ColumnCollection.Count > 2 then
    begin
      GridTopHeader.ColumnCollection[2].SizeStyle := ssAbsolute;
      GridTopHeader.ColumnCollection[2].Value := Scale(CMonacoAIButtonColumnWidth);
    end;

    if GridTopHeader.ColumnCollection.Count > 3 then
    begin
      LAISelectionWidth := Scale(CMonacoAISelectionWidth);
      GridTopHeader.ColumnCollection[3].SizeStyle := ssAbsolute;
      GridTopHeader.ColumnCollection[3].Value := LAISelectionWidth;
      if PAISelectionHost <> nil then
      begin
        PAISelectionHost.Margins.Right := 0;
        PAISelectionHost.Padding.Right := Scale(CMonacoAISelectionRightPadding);
        PAISelectionHost.Width := LAISelectionWidth;
      end;
    end;

    LHeaderHeight := GridTopHeader.ClientHeight;
    if (LHeaderHeight <= 0) and (PTop <> nil) then
      LHeaderHeight := PTop.ClientHeight;

    if (ComboSchema <> nil) and (LHeaderHeight > 0) then
    begin
      LComboHeight := ComboSchema.Height;
      if LComboHeight <= 0 then
        LComboHeight := 28;
      LTopMargin := (LHeaderHeight - LComboHeight) div 2;
      if LTopMargin < 0 then
        LTopMargin := 0;
      LBottomMargin := LHeaderHeight - LComboHeight - LTopMargin;
      if LBottomMargin < 0 then
        LBottomMargin := 0;
      ComboSchema.Margins.Top := LTopMargin;
      ComboSchema.Margins.Bottom := LBottomMargin;
    end;

    if (PSchemaConfigHost <> nil) and (LHeaderHeight > 0) then
    begin
      if (ComboSchema <> nil) and (ComboSchema.Height > 0) then
        LButtonSize := MulDiv(ComboSchema.Height, 132, 100)
      else
        LButtonSize := 37;
      if LButtonSize < 1 then
        LButtonSize := 1;
      LTopMargin := (LHeaderHeight - LButtonSize) div 2;
      if LTopMargin < 0 then
        LTopMargin := 0;
      LBottomMargin := LHeaderHeight - LButtonSize - LTopMargin;
      if LBottomMargin < 0 then
        LBottomMargin := 0;
      PSchemaConfigHost.Margins.Top := LTopMargin;
      PSchemaConfigHost.Margins.Bottom := LBottomMargin;
      LColumnWidth := LButtonSize + PSchemaConfigHost.Margins.Left +
        PSchemaConfigHost.Margins.Right + 4;
      if GridTopHeader.ColumnCollection.Count > 1 then
      begin
        GridTopHeader.ColumnCollection[1].SizeStyle := ssAbsolute;
        GridTopHeader.ColumnCollection[1].Value := LColumnWidth;
      end;
    end;
  end;

  if FAIButton <> nil then
    FAIButton.Invalidate;
  if FSchemaConfigButton <> nil then
    FSchemaConfigButton.Invalidate;
  if GridTopHeader <> nil then
    GridTopHeader.Realign;
  if (PAISelectionHost <> nil) and (FAISelection <> nil) then
  begin
    LChildWidth := PAISelectionHost.ClientWidth - PAISelectionHost.Padding.Right;
    if LChildWidth < 0 then
      LChildWidth := 0;
    FAISelection.Align := alNone;
    FAISelection.SetBounds(0, 0, LChildWidth, PAISelectionHost.ClientHeight);
    FAISelection.RefreshLayout;
  end;
end;

procedure TFRpMonacoEditorVCL.UpdateAuthUI;
var
  LLoggedIn: Boolean;
  LAIEnabled: Boolean;
  LSelectedTier: string;
  LSelectedAgentAiId: Int64;
  LBaseApiKey: string;
  LRequestVersion: Integer;
  LNeedsSchemas: Boolean;
  LNeedsAgents: Boolean;
  LWorker: TThread;
  LGuard: IEditorGuard;
  LCurrentVersion: Integer;
  LQueueProc: TThreadProcedure;
begin
  Inc(FAuthUIUpdateVersion);
  LCurrentVersion := FAuthUIUpdateVersion;
  LRequestVersion := FAuthUIUpdateVersion;
  LLoggedIn := TRpAuthManager.Instance.IsLoggedIn;
  LAIEnabled := TRpAuthManager.Instance.AIEnabled;
  LBaseApiKey := FBaseApiKey;
  if FAISelection <> nil then
  begin
    LSelectedTier := FAISelection.AITier;
    LSelectedAgentAiId := FAISelection.AgentAiId;
  end
  else
  begin
    LSelectedTier := '';
    LSelectedAgentAiId := 0;
  end;

  if FAIButton <> nil then
  begin
    FAIButton.Down := LAIEnabled;
    FAIButton.Invalidate;
  end;

  if not LLoggedIn then
  begin
    // The cloud schemas go; the subschemas of the connection stay
    if FSchemaList.CloudLoaded then
    begin
      FUpdatingSchemaList := True;
      try
        FSchemaList.ClearCloudSchemas;
      finally
        FUpdatingSchemaList := False;
      end;
    end;
    SyncSchemaFromList;
    if FAISelection <> nil then
    begin
      FAISelection.ClearAgentEndpoints;
      FAISelection.Visible := LAIEnabled;
      if not FAISelection.Visible then
        FAISelection.SetInferenceProgress(False);
      FAISelection.RefreshState;
    end;
    LayoutTopControls;
    Exit;
  end;

  LNeedsSchemas := not FSchemaList.CloudLoaded;
  LNeedsAgents := (FAISelection <> nil) and (FAISelection.AgentEndpointCount = 0);

  if FAISelection <> nil then
  begin
    FAISelection.Visible := LAIEnabled;
    if not FAISelection.Visible then
      FAISelection.SetInferenceProgress(False);
    FAISelection.RefreshState;
  end;

  LayoutTopControls;

  if not (LNeedsSchemas or LNeedsAgents) then
    Exit;

  LGuard := FGuard;
  LWorker := TThread.CreateAnonymousThread(
    procedure
    var
      LPayload: TMonacoAuthRefreshPayload;
      LHasQueued: Boolean;
      LUserSchemas: TStringList;
      LApiKeySchemas: TStringList;
      LSeenSchemaKeys: TStringList;
    begin
      LPayload := TMonacoAuthRefreshPayload.Create;
      LHasQueued := False;
      LUserSchemas := TStringList.Create;
      LApiKeySchemas := TStringList.Create;
      LSeenSchemaKeys := TStringList.Create;
      try
        LSeenSchemaKeys.Sorted := True;
        LSeenSchemaKeys.Duplicates := dupIgnore;
        LPayload.RequestVersion := LRequestVersion;
        LPayload.SelectedTier := LSelectedTier;
        LPayload.SelectedAgentAiId := LSelectedAgentAiId;
        if LNeedsSchemas then
        begin
          try
            LoadApiKeySchemas(LBaseApiKey, LApiKeySchemas);
          except
            LApiKeySchemas.Clear;
          end;
          try
            LoadUserSchemas(LUserSchemas);
          except
            LUserSchemas.Clear;
          end;
          AddMergedSchemas(LApiKeySchemas, LPayload.Schemas, LSeenSchemaKeys,
            LBaseApiKey);
          AddMergedSchemas(LUserSchemas, LPayload.Schemas, LSeenSchemaKeys, '');
        end;
        if LNeedsAgents then
          LoadUserAgents(LPayload.Agents);

        LQueueProc := procedure
          begin
            try
              if (LGuard = nil) or LGuard.IsCancelled or
                (LPayload.RequestVersion <> LCurrentVersion) then
                Exit;

              if LNeedsSchemas then
                ApplyUserSchemas(LPayload.Schemas);
              if LNeedsAgents then
                ApplyUserAgents(LPayload.Agents, LPayload.SelectedTier,
                  LPayload.SelectedAgentAiId);

              if FAISelection <> nil then
              begin
                FAISelection.Visible := TRpAuthManager.Instance.AIEnabled;
                if not FAISelection.Visible then
                  FAISelection.SetInferenceProgress(False);
                FAISelection.RefreshState;
              end;

              LayoutTopControls;
            finally
              LPayload.Free;
            end;
          end;
        TThread.Queue(nil, LQueueProc);
        LHasQueued := True;
      finally
        LSeenSchemaKeys.Free;
        LApiKeySchemas.Free;
        LUserSchemas.Free;
        if not LHasQueued then
          LPayload.Free;
      end;
    end);
  LWorker.FreeOnTerminate := True;
  LWorker.Start;
end;

procedure TFRpMonacoEditorVCL.AuthChanged(ASuccess: Boolean);
begin
  UpdateAuthUI;
end;

end.
