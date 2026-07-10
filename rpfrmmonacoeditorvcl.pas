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
  System.Zip, System.IOUtils, System.Threading, rpmdshfolder;

type
  IEditorGuard = interface
    function IsCancelled: Boolean;
    procedure Invalidate;
  end;

  TAuditSqlEvent = procedure(Sender: TObject) of object;
  TInferenceLogEvent = procedure(Sender: TObject; const ASource,
    AText: string; AAppendLineBreak: Boolean) of object;

  TAIToggleButton = class(TSpeedButton)
  protected
    procedure Paint; override;
  end;

  TSchemaComboItem = class
  public
    ApiKey: string;
    HubDatabaseId: Int64;
    HubSchemaId: Int64;
    constructor Create(AHubDatabaseId, AHubSchemaId: Int64;
      const AApiKey: string = '');
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
    FLoadingSchemas: Boolean;
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
    FOnInferenceLog: TInferenceLogEvent;
    procedure AIToggleClick(Sender: TObject);
    procedure SchemaConfigClick(Sender: TObject);
    procedure ComboSchemaChange(Sender: TObject);
    procedure ClearSchemaItems;
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
    procedure SelectCurrentSchema;
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
    property OnInferenceLog: TInferenceLogEvent read FOnInferenceLog write FOnInferenceLog;
  end;

implementation

{$R *.dfm}
{$R MonacoEditorAssets.res}

uses
  rptypes, rpdatainfo, rpgraphutilsvcl, Vcl.ToolWin, Vcl.ActnList,
  rpchatmodernstyle, System.Generics.Collections;

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

constructor TSchemaComboItem.Create(AHubDatabaseId, AHubSchemaId: Int64;
  const AApiKey: string);
begin
  inherited Create;
  ApiKey := Trim(AApiKey);
  HubDatabaseId := AHubDatabaseId;
  HubSchemaId := AHubSchemaId;
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
  FSchemaConfigButton.Hint := 'Open schema configuration on the web';
  FSchemaConfigButton.ShowHint := True;
  FSchemaConfigButton.Cursor := crHandPoint;
  FSchemaConfigButton.OnClick := SchemaConfigClick;

  ComboSchema.OnChange := ComboSchemaChange;

  // Create AI Selection Frame
  FAISelection := TFRpAISelectionVCL.Create(Self);
  PAISelectionHost.Height := FAISelection.PreferredHeight;
  PTop.Height := FAISelection.PreferredHeight;
  FAISelection.Parent := PAISelectionHost;
  FAISelection.Align := alTop;
  FAISelection.ShowGauge := False;

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
  ClearSchemaItems;
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

procedure TFRpMonacoEditorVCL.ClearSchemaItems;
var
  I: Integer;
begin
  for I := 0 to ComboSchema.Items.Count - 1 do
    ComboSchema.Items.Objects[I].Free;
  ComboSchema.Clear;
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

procedure TFRpMonacoEditorVCL.AddMergedSchemas(ASource, ADest,
  ASeenKeys: TStrings; const ADefaultApiKey: string);
var
  I: Integer;
  LDisplayName: string;
  LValue: string;
  LSchemaKey: string;
begin
  for I := 0 to ASource.Count - 1 do
  begin
    LDisplayName := ASource.Names[I];
    LValue := ASource.ValueFromIndex[I];
    LSchemaKey := LValue;
    if ASeenKeys.IndexOf(LSchemaKey) >= 0 then
      Continue;
    ASeenKeys.Add(LSchemaKey);
    ADest.Add(LDisplayName + '=' + LValue + '|' + ADefaultApiKey);
  end;
end;

procedure TFRpMonacoEditorVCL.ApplyUserSchemas(AList: TStrings);
var
  I: Integer;
  LSchemaName: string;
  LSchemaValue: string;
  LParts: TStringList;
  LHubDatabaseId: Int64;
  LSchemaId: Int64;
  LApiKey: string;
begin
  if FLoadingSchemas then
    Exit;

  FLoadingSchemas := True;
  ComboSchema.Items.BeginUpdate;
  LParts := TStringList.Create;
  try
    LParts.Delimiter := '|';
    LParts.StrictDelimiter := True;
    ClearSchemaItems;
    ComboSchema.Items.Add('');
    for I := 0 to AList.Count - 1 do
    begin
      LSchemaName := AList.Names[I];
      LSchemaValue := AList.ValueFromIndex[I];
      LParts.DelimitedText := LSchemaValue;
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
      ComboSchema.Items.AddObject(LSchemaName,
        TSchemaComboItem.Create(LHubDatabaseId, LSchemaId, LApiKey));
    end;

    SelectCurrentSchema;
  finally
    LParts.Free;
    ComboSchema.Items.EndUpdate;
    FLoadingSchemas := False;
  end;
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
  LIndex: Integer;
begin
  FSchema := ASchema;
  LIndex := ComboSchema.Items.IndexOf(ASchema);
  if LIndex >= 0 then
    ComboSchema.ItemIndex := LIndex;
end;

procedure TFRpMonacoEditorVCL.SetHubContext(AHubDatabaseId,
  AHubSchemaId: Int64; const ASchemaApiKey: string);
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
    UpdateAuthUI
  end
  else if (ComboSchema.Items.Count = 0) and TRpAuthManager.Instance.IsLoggedIn then
    UpdateAuthUI
  else
    SelectCurrentSchema;
end;

procedure TFRpMonacoEditorVCL.SetHubDatabaseId(const Value: Int64);
begin
  FBaseHubDatabaseId := Value;
  if FHubDatabaseId = Value then
  begin
    if ComboSchema.Items.Count > 0 then
      SelectCurrentSchema;
    Exit;
  end;

  FHubDatabaseId := Value;
  if (ComboSchema.Items.Count = 0) and TRpAuthManager.Instance.IsLoggedIn then
    UpdateAuthUI;
  if ComboSchema.Items.Count > 0 then
    SelectCurrentSchema;
end;

procedure TFRpMonacoEditorVCL.SetHubSchemaId(const Value: Int64);
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
end;

procedure TFRpMonacoEditorVCL.SelectCurrentSchema;
var
  I: Integer;
  LItem: TSchemaComboItem;
  LFound: Boolean;
begin
  if ComboSchema.Items.Count = 0 then
    Exit;

  ComboSchema.ItemIndex := 0;
  FSchema := '';
  LFound := False;

  if FHubSchemaId <> 0 then
  begin
    for I := 1 to ComboSchema.Items.Count - 1 do
    begin
      LItem := TSchemaComboItem(ComboSchema.Items.Objects[I]);
      if (LItem <> nil) and (LItem.HubSchemaId = FHubSchemaId) then
      begin
        ComboSchema.ItemIndex := I;
        FSchema := ComboSchema.Items[I];
        FHubDatabaseId := LItem.HubDatabaseId;
        FSchemaApiKey := LItem.ApiKey;
        LFound := True;
        Break;
      end;
    end;
  end;

  if (not LFound) and (FBaseHubDatabaseId <> 0) then
  begin
    for I := 1 to ComboSchema.Items.Count - 1 do
    begin
      LItem := TSchemaComboItem(ComboSchema.Items.Objects[I]);
      if (LItem <> nil) and (LItem.HubDatabaseId = FBaseHubDatabaseId) then
      begin
        ComboSchema.ItemIndex := I;
        FSchema := ComboSchema.Items[I];
        FHubDatabaseId := LItem.HubDatabaseId;
        FHubSchemaId := LItem.HubSchemaId;
        FSchemaApiKey := LItem.ApiKey;
        LFound := True;
        Break;
      end;
    end;
  end;

  if (not LFound) and (ComboSchema.Items.Count > 1) then
  begin
    ComboSchema.ItemIndex := 1;
    LItem := TSchemaComboItem(ComboSchema.Items.Objects[1]);
    FSchema := ComboSchema.Items[1];
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
end;

procedure TFRpMonacoEditorVCL.ComboSchemaChange(Sender: TObject);
var
  LItem: TSchemaComboItem;
begin
  if FLoadingSchemas then
    Exit;

  if ComboSchema.ItemIndex > 0 then
  begin
    LItem := TSchemaComboItem(ComboSchema.Items.Objects[ComboSchema.ItemIndex]);
    FSchema := ComboSchema.Items[ComboSchema.ItemIndex];
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

  if Assigned(FOnSchemaChanged) then
    FOnSchemaChanged(Self);
end;

function TFRpMonacoEditorVCL.GetSchemaApiKey: string;
var
  LItem: TSchemaComboItem;
begin
  if ComboSchema.ItemIndex > 0 then
  begin
    LItem := TSchemaComboItem(ComboSchema.Items.Objects[ComboSchema.ItemIndex]);
    if LItem <> nil then
      Exit(LItem.ApiKey);
  end;
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

procedure TFRpMonacoEditorVCL.SchemaConfigClick(Sender: TObject);
begin
  TRpAuthManager.Instance.OpenUrl('https://app.reportman.es/database-config');
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

  FLastAutoCompleteSql := LStartSql;
  FActiveInferenceRequestId := LStartRequestId;
  FInferenceRunning := True;
  FRestartPendingInference := False;
  LGuard := FGuard;

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
        LHttp.ApiKey := GetSchemaApiKey;
        LHttp.Token := TRpAuthManager.Instance.Token;
        LHttp.InstallId := TRpAuthManager.Instance.InstallId;
        LHttp.HubDatabaseId := FHubDatabaseId;
        LHttp.HubSchemaId := FHubSchemaId;
        LHttp.RuntimeDb := FRuntimeDb;
        LHttp.AITier := FAISelection.AITier;
        LHttp.AgentSecret := FAISelection.AgentSecret;
        LHttp.AgentAiId := FAISelection.AgentAiId;
        LUAIMode := FAISelection.AIMode;

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

  ComboSchema.Enabled := LLoggedIn;
  if not LLoggedIn then
  begin
    ClearSchemaItems;
    FSchema := '';
    FHubDatabaseId := 0;
    FHubSchemaId := 0;
    FSchemaApiKey := '';
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

  if ComboSchema.Items.Count > 0 then
    SelectCurrentSchema;

  LNeedsSchemas := ComboSchema.Items.Count = 0;
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
