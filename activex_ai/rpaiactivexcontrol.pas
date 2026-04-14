unit rpaiactivexcontrol;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ActiveX, Winapi.WebView2, Winapi.ShellAPI,
  System.SysUtils, System.Classes, System.IOUtils,
  Vcl.Controls, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Edge, Vcl.Graphics;

const
  WM_RPAI_INITIALIZE_BROWSER = WM_USER + 410;
  RPAI_INIT_RETRY_TIMER_ID = 410;
  RPAI_INIT_RETRY_DELAY_MS = 250;
  RPAI_INIT_MAX_ATTEMPTS = 8;

type
  TRpAIUrlEvent = procedure(Sender: TObject; const AUrl: WideString) of object;
  TRpAIMessageEvent = procedure(Sender: TObject; const AMessage: WideString) of object;

  TRpAIActiveXControl = class(TCustomControl)
  private const
    DefaultUrl = 'https://app.reportman.es';
    RuntimeDownloadUrl = 'https://developer.microsoft.com/microsoft-edge/webview2/';
  private
    FEdge: TEdgeBrowser;
    FFallbackPanel: TPanel;
    FFallbackLabel: TLabel;
    FFallbackButton: TButton;
    FLogMemo: TMemo;
    FUrl: string;
    FProfileName: string;
    FInitialized: Boolean;
    FInitQueued: Boolean;
    FInitAttempts: Integer;
    FLastInitResult: HRESULT;
    FNavigationStarting: TRpAIUrlEvent;
    FNavigationCompleted: TRpAIUrlEvent;
    FMessageReceived: TRpAIMessageEvent;
    FHostError: TRpAIMessageEvent;
    procedure AppendLog(const AMessage: string);
    function DecodeHResultMessage(AResult: HRESULT): string;
    procedure EdgeCreateWebViewCompleted(Sender: TCustomEdgeBrowser;
      AResult: HRESULT);
    procedure EdgeNavigationStarting(Sender: TCustomEdgeBrowser;
      Args: TNavigationStartingEventArgs);
    procedure EdgeNavigationCompleted(Sender: TCustomEdgeBrowser;
      IsSuccess: Boolean; WebErrorStatus: TOleEnum);
    procedure EdgeWebMessageReceived(Sender: TCustomEdgeBrowser;
      Args: TWebMessageReceivedEventArgs);
    procedure OpenRuntimeDownload(Sender: TObject);
    procedure RaiseHostError(const AMessage: string);
    procedure SetProfileName(const Value: string);
    procedure SetUrl(const Value: string);
    function GetCanGoBack: Boolean;
    function GetCanGoForward: Boolean;
    function GetVersion: string;
    function GetAppDataRoot: string;
    function GetArchitectureFolder: string;
    function GetEffectiveProfileName: string;
    function GetHostExecutableProfileName: string;
    function GetModuleDirectory: string;
    function GetUserDataFolder: string;
    function HasUsableParentWindow: Boolean;
    procedure QueueInitializeBrowser;
    procedure EnsureBrowserCreated;
    function SanitizeProfileName(const Value: string): string;
    procedure ShowFallback(const AMessage: string);
    procedure ShowBrowser;
    function TryPreloadWebView2Loader: Boolean;
  protected
    procedure CreateWnd; override;
    procedure Loaded; override;
    procedure WMInitializeBrowser(var Message: TMessage); message WM_RPAI_INITIALIZE_BROWSER;
    procedure WMTimer(var Message: TWMTimer); message WM_TIMER;
    procedure CMShowingChanged(var Message: TMessage); message CM_SHOWINGCHANGED;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Navigate(const AUrl: string);
    procedure Reload;
    procedure GoBack;
    procedure GoForward;
    procedure ExecuteScript(const AScript: string);
    procedure RetryInitialize;
    property Url: string read FUrl write SetUrl;
    property ProfileName: string read FProfileName write SetProfileName;
    property CanGoBack: Boolean read GetCanGoBack;
    property CanGoForward: Boolean read GetCanGoForward;
    property Version: string read GetVersion;
    property OnNavigationStarting: TRpAIUrlEvent read FNavigationStarting write FNavigationStarting;
    property OnNavigationCompleted: TRpAIUrlEvent read FNavigationCompleted write FNavigationCompleted;
    property OnMessageReceived: TRpAIMessageEvent read FMessageReceived write FMessageReceived;
    property OnHostError: TRpAIMessageEvent read FHostError write FHostError;
  end;

implementation

function HResultFromWin32Code(AError: DWORD): HRESULT;
begin
  if AError <= 0 then
    Result := HRESULT(AError)
  else
    Result := HRESULT((AError and $0000FFFF) or (7 shl 16) or $80000000);
end;

constructor TRpAIActiveXControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 360;
  Height := 240;
  Color := clWhite;
  ParentBackground := False;
  FUrl := DefaultUrl;
  FInitialized := False;
  FInitQueued := False;
  FInitAttempts := 0;
  FLastInitResult := S_OK;

  FEdge := TEdgeBrowser.Create(Self);
  FEdge.Parent := Self;
  FEdge.Align := alClient;
  FEdge.Visible := False;
  FEdge.OnCreateWebViewCompleted := EdgeCreateWebViewCompleted;
  FEdge.OnNavigationStarting := EdgeNavigationStarting;
  FEdge.OnNavigationCompleted := EdgeNavigationCompleted;
  FEdge.OnWebMessageReceived := EdgeWebMessageReceived;

  FFallbackPanel := TPanel.Create(Self);
  FFallbackPanel.Parent := Self;
  FFallbackPanel.Align := alClient;
  FFallbackPanel.BevelOuter := bvNone;
  FFallbackPanel.Caption := '';
  FFallbackPanel.Color := clBtnFace;

  FFallbackLabel := TLabel.Create(Self);
  FFallbackLabel.Parent := FFallbackPanel;
  FFallbackLabel.AlignWithMargins := True;
  FFallbackLabel.Align := alTop;
  FFallbackLabel.Margins.Left := 16;
  FFallbackLabel.Margins.Top := 16;
  FFallbackLabel.Margins.Right := 16;
  FFallbackLabel.Margins.Bottom := 8;
  FFallbackLabel.WordWrap := True;
  FFallbackLabel.Caption := 'Initializing Reportman AI browser...';

  FFallbackButton := TButton.Create(Self);
  FFallbackButton.Parent := FFallbackPanel;
  FFallbackButton.AlignWithMargins := True;
  FFallbackButton.Align := alTop;
  FFallbackButton.Margins.Left := 16;
  FFallbackButton.Margins.Top := 8;
  FFallbackButton.Margins.Right := 16;
  FFallbackButton.Margins.Bottom := 16;
  FFallbackButton.Caption := 'Download WebView2 Runtime';
  FFallbackButton.Height := 28;
  FFallbackButton.OnClick := OpenRuntimeDownload;

  FLogMemo := TMemo.Create(Self);
  FLogMemo.Parent := FFallbackPanel;
  FLogMemo.AlignWithMargins := True;
  FLogMemo.Align := alClient;
  FLogMemo.Margins.Left := 16;
  FLogMemo.Margins.Top := 0;
  FLogMemo.Margins.Right := 16;
  FLogMemo.Margins.Bottom := 16;
  FLogMemo.ReadOnly := True;
  FLogMemo.ScrollBars := ssVertical;
  FLogMemo.WordWrap := False;
  FLogMemo.Color := clWindow;
  FLogMemo.Visible := True;

  AppendLog('Control created.');
  AppendLog('Process architecture: ' + GetArchitectureFolder);
  AppendLog('Module directory: ' + GetModuleDirectory);
  AppendLog('Effective profile: ' + GetEffectiveProfileName);
  AppendLog('User data folder: ' + GetUserDataFolder);
end;

destructor TRpAIActiveXControl.Destroy;
begin
  KillTimer(Handle, RPAI_INIT_RETRY_TIMER_ID);
  if FEdge.WebViewCreated then
    FEdge.CloseWebView;
  inherited Destroy;
end;

procedure TRpAIActiveXControl.CreateWnd;
begin
  inherited CreateWnd;
  AppendLog('CreateWnd completed. Handle=' + IntToHex(Handle, 8));
  QueueInitializeBrowser;
end;

procedure TRpAIActiveXControl.Loaded;
begin
  inherited Loaded;
  QueueInitializeBrowser;
end;

procedure TRpAIActiveXControl.CMShowingChanged(var Message: TMessage);
begin
  inherited;
  if Showing then
  begin
    AppendLog('Showing changed to visible.');
    QueueInitializeBrowser;
  end;
end;

procedure TRpAIActiveXControl.WMInitializeBrowser(var Message: TMessage);
begin
  FInitQueued := False;
  EnsureBrowserCreated;
end;

procedure TRpAIActiveXControl.WMTimer(var Message: TWMTimer);
begin
  inherited;
  if Message.TimerID = RPAI_INIT_RETRY_TIMER_ID then
  begin
    KillTimer(Handle, RPAI_INIT_RETRY_TIMER_ID);
    AppendLog('Retry timer fired.');
    QueueInitializeBrowser;
  end;
end;

procedure TRpAIActiveXControl.QueueInitializeBrowser;
begin
  if csDesigning in ComponentState then
    Exit;

  if not HandleAllocated then
    Exit;

  if FInitQueued then
    Exit;

  FInitQueued := True;
  PostMessage(Handle, WM_RPAI_INITIALIZE_BROWSER, 0, 0);
end;

function TRpAIActiveXControl.HasUsableParentWindow: Boolean;
begin
  Result := HandleAllocated and (GetParent(Handle) <> 0);
end;

procedure TRpAIActiveXControl.EnsureBrowserCreated;
begin
  if csDesigning in ComponentState then
    Exit;

  if FEdge.WebViewCreated or FInitialized then
    Exit;

  if not HasUsableParentWindow then
  begin
    AppendLog('Initialization deferred: parent window not ready.');
    QueueInitializeBrowser;
    Exit;
  end;

  AppendLog('Attempting WebView2 initialization.');
  Inc(FInitAttempts);
  AppendLog('Initialization attempt #' + IntToStr(FInitAttempts) + '.');
  AppendLog('Parent window=' + IntToHex(GetParent(Handle), 8));

  TryPreloadWebView2Loader;

  if not FEdge.WebViewCreated then
  begin
    FEdge.HandleNeeded;
    ForceDirectories(GetUserDataFolder);
    FEdge.UserDataFolder := GetUserDataFolder;
    AppendLog('Using profile: ' + GetEffectiveProfileName);
    AppendLog('Using user data folder: ' + FEdge.UserDataFolder);
    try
      AppendLog('Calling CreateWebView.');
      FEdge.CreateWebView;
    except
      on E: Exception do
      begin
        FInitialized := False;
        FLastInitResult := E_FAIL;
        AppendLog('CreateWebView raised exception: ' + E.ClassName + ': ' + E.Message);
        ShowFallback('Unable to initialize WebView2.' + sLineBreak + sLineBreak + E.Message);
        RaiseHostError(E.Message);
      end;
    end;
  end;
end;

procedure TRpAIActiveXControl.AppendLog(const AMessage: string);
begin
  if FLogMemo <> nil then
    FLogMemo.Lines.Add(FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + AMessage);
end;

function TRpAIActiveXControl.DecodeHResultMessage(AResult: HRESULT): string;
begin
  case AResult of
    S_OK:
      Result := 'Success.';
    E_FAIL:
      Result := 'Generic failure returned by WebView2.';
    E_ACCESSDENIED:
      Result := 'Access denied while creating the WebView2 environment. Check permissions on the user data folder.';
    E_INVALIDARG:
      Result := 'Invalid argument passed to WebView2 initialization.';
    E_POINTER:
      Result := 'Invalid pointer used during WebView2 initialization.';
    RPC_E_CHANGED_MODE:
      Result := 'COM apartment mode was changed earlier in the process.';
    HRESULT($80070002):
      Result := 'A required file was not found. This can mean loader or runtime mismatch.';
    HRESULT($80070006):
      Result := 'Invalid handle. In an ActiveX host this usually means the container window is not stable yet.';
    HRESULT($8007000E):
      Result := 'Not enough memory.';
    HRESULT($80070032):
      Result := 'Operation not supported in the current host configuration.';
    HRESULT($80070578):
      Result := 'Invalid window handle. This is a strong indicator of host timing issues.';
  else
    if AResult = HResultFromWin32Code(ERROR_INVALID_WINDOW_HANDLE) then
      Result := 'Invalid window handle. This usually means VB6 created the ActiveX window but it is not ready yet.'
    else if AResult = HResultFromWin32Code(ERROR_MOD_NOT_FOUND) then
      Result := 'WebView2 loader DLL or one of its dependencies could not be loaded.'
    else
      Result := SysErrorMessage(AResult and $FFFF);
  end;
end;

procedure TRpAIActiveXControl.EdgeCreateWebViewCompleted(
  Sender: TCustomEdgeBrowser; AResult: HRESULT);
var
  LDecoded: string;
begin
  FLastInitResult := AResult;
  if Succeeded(AResult) then
  begin
    FInitialized := True;
    FInitAttempts := 0;
    AppendLog('CreateWebView completed successfully.');
    ShowBrowser;
    Navigate(FUrl);
  end
  else
  begin
    FInitialized := False;
    LDecoded := DecodeHResultMessage(AResult);
    AppendLog('CreateWebView failed. HRESULT=0x' + IntToHex(Cardinal(AResult), 8));
    AppendLog('Details: ' + LDecoded);
    if (AResult = HResultFromWin32Code(ERROR_INVALID_WINDOW_HANDLE)) and
      (FInitAttempts < RPAI_INIT_MAX_ATTEMPTS) then
    begin
      AppendLog('Scheduling automatic retry because the host window handle is not stable yet.');
      SetTimer(Handle, RPAI_INIT_RETRY_TIMER_ID, RPAI_INIT_RETRY_DELAY_MS, nil);
      Exit;
    end;
    ShowFallback('WebView2 initialization failed.' + sLineBreak + sLineBreak +
      'HRESULT: 0x' + IntToHex(Cardinal(AResult), 8) + sLineBreak +
      LDecoded + sLineBreak + sLineBreak +
      'If this happens only in VB6, the container window may not be ready yet. Use RetryInitialize after the form is shown.');
    RaiseHostError('WebView2 initialization failed. HRESULT=0x' + IntToHex(Cardinal(AResult), 8) + '. ' + LDecoded);
  end;
end;

procedure TRpAIActiveXControl.EdgeNavigationStarting(Sender: TCustomEdgeBrowser;
  Args: TNavigationStartingEventArgs);
var
  PUri: PWideChar;
  StrUri: string;
begin
  // 1. Pedimos la URI a la interfaz nativa (ICoreWebView2NavigationStartingEventArgs)
  if Args.ArgsInterface.Get_uri(PUri) = S_OK then
  begin
    try
      // 2. Convertimos el puntero PWideChar a un string nativo de Delphi
      StrUri := PUri;

      // 3. Disparamos tu evento pas�ndole el string ya seguro
      if Assigned(FNavigationStarting) then
        FNavigationStarting(Self, StrUri);
      AppendLog('Navigation starting: ' + StrUri);

    finally
      // 4. �CR�TICO! Liberar la memoria asignada por WebView2 para evitar fugas (Memory Leaks)
      CoTaskMemFree(PUri);
    end;
  end;
end;

procedure TRpAIActiveXControl.EdgeNavigationCompleted(Sender: TCustomEdgeBrowser;
  IsSuccess: Boolean; WebErrorStatus: TOleEnum);
var
  LMessage: string;
begin
  if IsSuccess then
  begin
    AppendLog('Navigation completed successfully: ' + FUrl);
    if Assigned(FNavigationCompleted) then
      FNavigationCompleted(Self, FUrl);
  end
  else
  begin
    LMessage := 'Navigation failed with status ' + IntToStr(WebErrorStatus) + '.';
    AppendLog(LMessage);
    ShowFallback(LMessage);
    RaiseHostError(LMessage);
  end;
end;

procedure TRpAIActiveXControl.EdgeWebMessageReceived(Sender: TCustomEdgeBrowser;
  Args: TWebMessageReceivedEventArgs);
var
  LP: PWideChar;
  LMessage: string;
begin
  LP := nil;
  Args.ArgsInterface.TryGetWebMessageAsString(LP);
  if LP = nil then
    Exit;
  try
    LMessage := LP;
  finally
    CoTaskMemFree(LP);
  end;

  AppendLog('Message received: ' + LMessage);

  if Assigned(FMessageReceived) then
    FMessageReceived(Self, LMessage);
end;

procedure TRpAIActiveXControl.Navigate(const AUrl: string);
begin
  if Trim(AUrl) = '' then
    FUrl := DefaultUrl
  else
    FUrl := Trim(AUrl);

  AppendLog('Navigate requested: ' + FUrl);

  if FInitialized then
    FEdge.Navigate(FUrl);
end;

procedure TRpAIActiveXControl.Reload;
begin
  if FInitialized then
  begin
    AppendLog('Reload requested.');
    FEdge.Refresh;
  end;
end;

procedure TRpAIActiveXControl.GoBack;
begin
  if CanGoBack then
  begin
    AppendLog('GoBack requested.');
    FEdge.GoBack;
  end;
end;

procedure TRpAIActiveXControl.GoForward;
begin
  if CanGoForward then
  begin
    AppendLog('GoForward requested.');
    FEdge.GoForward;
  end;
end;

procedure TRpAIActiveXControl.ExecuteScript(const AScript: string);
begin
  if FInitialized and (Trim(AScript) <> '') then
  begin
    AppendLog('ExecuteScript requested.');
    FEdge.ExecuteScript(AScript);
  end;
end;

procedure TRpAIActiveXControl.RetryInitialize;
begin
  AppendLog('RetryInitialize requested.');
  FInitialized := False;
  if FEdge.WebViewCreated then
    FEdge.CloseWebView;
  QueueInitializeBrowser;
end;

procedure TRpAIActiveXControl.OpenRuntimeDownload(Sender: TObject);
begin
  AppendLog('Opening WebView2 runtime download page.');
  ShellExecute(Handle, 'open', PChar(RuntimeDownloadUrl), nil, nil, SW_SHOWNORMAL);
end;

procedure TRpAIActiveXControl.RaiseHostError(const AMessage: string);
begin
  AppendLog('Host error: ' + AMessage);
  if Assigned(FHostError) then
    FHostError(Self, AMessage);
end;

procedure TRpAIActiveXControl.SetProfileName(const Value: string);
var
  LNewProfileName: string;
begin
  LNewProfileName := Trim(Value);
  if SameText(FProfileName, LNewProfileName) then
    Exit;

  FProfileName := LNewProfileName;
  AppendLog('ProfileName changed to "' + FProfileName + '".');
  AppendLog('Effective profile: ' + GetEffectiveProfileName);
  AppendLog('User data folder: ' + GetUserDataFolder);

  if not (csDesigning in ComponentState) and (FEdge.WebViewCreated or FInitialized) then
    RetryInitialize;
end;

procedure TRpAIActiveXControl.SetUrl(const Value: string);
begin
  Navigate(Value);
end;

function TRpAIActiveXControl.GetCanGoBack: Boolean;
begin
  Result := FInitialized and FEdge.CanGoBack;
end;

function TRpAIActiveXControl.GetCanGoForward: Boolean;
begin
  Result := FInitialized and FEdge.CanGoForward;
end;

function TRpAIActiveXControl.GetVersion: string;
begin
  Result := '1.0.0.0';
end;

function TRpAIActiveXControl.GetAppDataRoot: string;
var
  LBasePath: string;
begin
  LBasePath := GetEnvironmentVariable('LOCALAPPDATA');
  if LBasePath = '' then
    LBasePath := TPath.GetTempPath;
  Result := TPath.Combine(LBasePath, 'Reportman\AIActiveX');
end;

function TRpAIActiveXControl.GetEffectiveProfileName: string;
begin
  if Trim(FProfileName) <> '' then
    Result := SanitizeProfileName(FProfileName)
  else
    Result := SanitizeProfileName(GetHostExecutableProfileName);
end;

function TRpAIActiveXControl.GetArchitectureFolder: string;
begin
  if SizeOf(Pointer) = 8 then
    Result := 'x64'
  else
    Result := 'x86';
end;

function TRpAIActiveXControl.GetHostExecutableProfileName: string;
begin
  Result := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
  if Trim(Result) = '' then
    Result := 'default';
end;

function TRpAIActiveXControl.GetModuleDirectory: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(GetModuleName(HInstance)));
end;

function TRpAIActiveXControl.GetUserDataFolder: string;
begin
  Result := TPath.Combine(
    TPath.Combine(GetAppDataRoot, 'Profiles'),
    TPath.Combine(GetEffectiveProfileName, 'EdgeData'));
end;

procedure TRpAIActiveXControl.ShowFallback(const AMessage: string);
begin
  FFallbackLabel.Caption := AMessage;
  FFallbackPanel.Visible := True;
  FFallbackPanel.BringToFront;
  FEdge.Visible := False;
end;

procedure TRpAIActiveXControl.ShowBrowser;
begin
  FFallbackPanel.Visible := False;
  FEdge.Visible := True;
  FEdge.BringToFront;
end;

function TRpAIActiveXControl.TryPreloadWebView2Loader: Boolean;
var
  LCandidates: array[0..3] of string;
  I: Integer;
  LLocalAppData: string;
  LHandle: HMODULE;
begin
  Result := False;
  LLocalAppData := GetEnvironmentVariable('LOCALAPPDATA');

  LCandidates[0] := TPath.Combine(GetModuleDirectory, GetArchitectureFolder + '\WebView2Loader.dll');
  LCandidates[1] := TPath.Combine(GetModuleDirectory, 'WebView2Loader.dll');
  LCandidates[2] := TPath.Combine(LLocalAppData,
    'Reportman\Monaco\MonacoEditor\' + GetArchitectureFolder + '\WebView2Loader.dll');
  LCandidates[3] := TPath.Combine(LLocalAppData,
    'Reportman.AI\Runtime\WebView2\' + GetArchitectureFolder + '\WebView2Loader.dll');

  for I := Low(LCandidates) to High(LCandidates) do
  begin
    if TFile.Exists(LCandidates[I]) then
    begin
      AppendLog('Trying loader: ' + LCandidates[I]);
      LHandle := LoadLibrary(PChar(LCandidates[I]));
      if LHandle <> 0 then
      begin
        AppendLog('Loaded WebView2Loader.dll from: ' + LCandidates[I]);
        Result := True;
        Exit;
      end;
      AppendLog('LoadLibrary failed for ' + LCandidates[I] + ' with Win32 error ' + IntToStr(GetLastError) + '.');
    end;
  end;

  AppendLog('No candidate WebView2Loader.dll could be preloaded.');
end;

function TRpAIActiveXControl.SanitizeProfileName(const Value: string): string;
var
  LChar: Char;
begin
  Result := Trim(Value);
  for LChar in ['\', '/', ':', '*', '?', '"', '<', '>', '|'] do
    Result := Result.Replace(LChar, '_');
  if Result = '' then
    Result := 'default';
end;

end.