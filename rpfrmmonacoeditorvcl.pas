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
  rpauthmanager, rpfrmaiselectionvcl, rpfrmloginvcl, rpfrmloginframevcl, System.JSON, rpdatahttp,
  System.Zip, System.IOUtils, System.Threading;

type
  IEditorGuard = interface
    function IsCancelled: Boolean;
    procedure Invalidate;
  end;

  TAIToggleButton = class(TSpeedButton)
  protected
    procedure Paint; override;
  end;

  TConfigIconButton = class(TSpeedButton)
  protected
    procedure Paint; override;
  end;

  TSchemaComboItem = class
  public
    HubDatabaseId: Int64;
    HubSchemaId: Int64;
    constructor Create(AHubDatabaseId, AHubSchemaId: Int64);
  end;

  TFRpMonacoEditorVCL = class(TFrame)
    PTop: TPanel;
    ComboSchema: TComboBox;
    Edge: TEdgeBrowser;
    PLoginControl: TPanel;
    GridTopHeader: TGridPanel;
    PSchemaConfigHost: TPanel;
    PAIButtonHost: TPanel;
    PAISelectionHost: TPanel;
    PControl: TPageControl;
    TabSQL: TTabSheet;
    TabLog: TTabSheet;
    PLogTop: TPanel;
    BClearLog: TButton;
    MemoLog: TMemo;

    procedure EdgeCreateWebViewCompleted(Sender: TCustomEdgeBrowser;
      AResult: HRESULT);
    procedure EdgeWebMessageReceived(Sender: TCustomEdgeBrowser;
      Args: TWebMessageReceivedEventArgs);
    procedure EdgeNavigationCompleted(Sender: TCustomEdgeBrowser;
      IsSuccess: Boolean; WebErrorStatus: TOleEnum);
    procedure BClearLogClick(Sender: TObject);
    procedure AuthChanged(ASuccess: Boolean);
  private
    FAISelection: TFRpAISelectionVCL;
    FAIButton: TAIToggleButton;
    FSchemaConfigButton: TConfigIconButton;
    FLoginFrame: TFRpLoginFrameVCL;
    FSQL: string;
    FSchema: string;
    FBaseHubDatabaseId: Int64;
    FLoadingSchemas: Boolean;
    FOnContentChanged: TNotifyEvent;
    FAppDataPath: string;
    FEditorReady: Boolean;
    FUpdatingFromBrowser: Boolean;
    FHubDatabaseId: Int64;
    FHubSchemaId: Int64;
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
    procedure AIToggleClick(Sender: TObject);
    procedure SchemaConfigClick(Sender: TObject);
    procedure ComboSchemaChange(Sender: TObject);
    procedure ClearSchemaItems;
    procedure OnDebounceTimer(Sender: TObject);
    procedure ProcessWebMessage(const LMessage: string);
    function LoadUserSchemas(AList: TStrings): Boolean;
    function LoadUserAgents(AList: TStrings): Boolean;
    procedure ApplyUserSchemas(AList: TStrings);
    procedure ApplyUserAgents(AList: TStrings; const ASelectedTier: string;
      ASelectedAgentAiId: Int64);
    procedure SelectCurrentSchema;
    procedure SetSQL(const Value: string);
    procedure SetHubDatabaseId(const Value: Int64);
    procedure SetHubSchemaId(const Value: Int64);
    procedure HandleAICompletionRequest(const ARequest: TJSONObject);
    procedure SendAICompletions(const AInlineItems, ACompletionItems: TJSONArray; const ARequestId: string);
    function SuggestSqlStreamCancelRequested(Sender: TObject): Boolean;
    procedure SuggestSqlStreamProgress(Sender: TObject; const AStage,
      AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer);
    procedure StartPendingInference;
    procedure LayoutTopControls;
    procedure UpdateAuthUI;
  protected
    procedure CreateWnd; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadSQL(const ASQL: string);
    procedure SetSchema(const ASchema: string);
    property SQL: string read FSQL write SetSQL;
    property HubDatabaseId: Int64 read FHubDatabaseId write SetHubDatabaseId;
    property HubSchemaId: Int64 read FHubSchemaId write SetHubSchemaId;
    property OnContentChanged: TNotifyEvent read FOnContentChanged write FOnContentChanged;
  end;

implementation

{$R *.dfm}
{$R MonacoEditorAssets.res}

uses
  rptypes, rpdatainfo, rpgraphutilsvcl, Vcl.ToolWin, Vcl.ActnList;

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

procedure TConfigIconButton.Paint;
var
  R: TRect;
  CX, CY: Integer;
  OuterRadius, InnerRadius, CenterRadius: Integer;
  FontColor: TColor;

  procedure DrawSpoke(const DX1, DY1, DX2, DY2: Integer);
  begin
    Canvas.MoveTo(CX + DX1, CY + DY1);
    Canvas.LineTo(CX + DX2, CY + DY2);
  end;
begin
  R := ClientRect;

  if not Enabled then
    FontColor := clGrayText
  else
    FontColor := clBtnText;

  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(R);
  DrawEdge(Canvas.Handle, R, BDR_RAISEDINNER, BF_RECT);

  CX := (R.Left + R.Right) div 2;
  CY := (R.Top + R.Bottom) div 2;
  if Width < Height then
    OuterRadius := Width div 4
  else
    OuterRadius := Height div 4;
  InnerRadius := OuterRadius - 3;
  CenterRadius := OuterRadius div 2;

  Canvas.Pen.Color := FontColor;
  Canvas.Pen.Width := 2;
  Canvas.Brush.Style := bsClear;

  DrawSpoke(0, -OuterRadius - 2, 0, -InnerRadius);
  DrawSpoke(0, InnerRadius, 0, OuterRadius + 2);
  DrawSpoke(-OuterRadius - 2, 0, -InnerRadius, 0);
  DrawSpoke(InnerRadius, 0, OuterRadius + 2, 0);
  DrawSpoke(-OuterRadius + 1, -OuterRadius + 1, -InnerRadius + 1, -InnerRadius + 1);
  DrawSpoke(InnerRadius - 1, InnerRadius - 1, OuterRadius - 1, OuterRadius - 1);
  DrawSpoke(OuterRadius - 1, -OuterRadius + 1, InnerRadius - 1, -InnerRadius + 1);
  DrawSpoke(-OuterRadius + 1, OuterRadius - 1, -InnerRadius + 1, InnerRadius - 1);

  Canvas.Ellipse(CX - OuterRadius, CY - OuterRadius, CX + OuterRadius, CY + OuterRadius);
  Canvas.Ellipse(CX - CenterRadius, CY - CenterRadius, CX + CenterRadius, CY + CenterRadius);
end;

constructor TSchemaComboItem.Create(AHubDatabaseId, AHubSchemaId: Int64);
begin
  inherited Create;
  HubDatabaseId := AHubDatabaseId;
  HubSchemaId := AHubSchemaId;
end;

constructor TFRpMonacoEditorVCL.Create(AOwner: TComponent);
var
  LResStream: TResourceStream;
  LZip: TZipFile;
  LDestPath: string;
  LDllPath: string;
begin
  inherited Create(AOwner);
  FGuard := TEditorGuard.Create;
  FEditorReady := False;
  FAuthUIUpdateVersion := 0;

  // 1. Determine safe extraction path in %LOCALAPPDATA%
  FAppDataPath := GetEnvironmentVariable('LOCALAPPDATA');
  if FAppDataPath = '' then FAppDataPath := TPath.GetTempPath;
  LDestPath := TPath.Combine(FAppDataPath, 'Reportman\Monaco\MonacoEditor');

  // 2. Extract assets from resource if missing or if folder doesn't exist
  if not TDirectory.Exists(LDestPath) then
  begin
    TDirectory.CreateDirectory(LDestPath);
    LResStream := TResourceStream.Create(HInstance, 'MONACO_ZIP', RT_RCDATA);
    try
      LZip := TZipFile.Create;
      try
        LZip.Open(LResStream, zmRead);
        LZip.ExtractAll(LDestPath);
      finally
        LZip.Free;
      end;
    finally
      LResStream.Free;
    end;
  end;

  // 3. Preload WebView2Loader.dll based on architecture
  if SizeOf(Pointer) = 8 then
    LDllPath := TPath.Combine(LDestPath, 'x64\WebView2Loader.dll')
  else
    LDllPath := TPath.Combine(LDestPath, 'x86\WebView2Loader.dll');

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

  FSchemaConfigButton := TConfigIconButton.Create(Self);
  FSchemaConfigButton.Parent := PSchemaConfigHost;
  FSchemaConfigButton.Align := alClient;
  FSchemaConfigButton.Flat := False;
  FSchemaConfigButton.Hint := 'Open schema configuration on the web';
  FSchemaConfigButton.ShowHint := True;
  FSchemaConfigButton.Cursor := crHandPoint;
  FSchemaConfigButton.OnClick := SchemaConfigClick;

  ComboSchema.OnChange := ComboSchemaChange;

  // Create AI Selection Frame
  FAISelection := TFRpAISelectionVCL.Create(Self);
  FAISelection.Parent := PAISelectionHost;
  FAISelection.Align := alClient;
  FAISelection.Constraints.MinHeight := 63;
  FAISelection.Constraints.MaxHeight := 63;

  // Create Login Frame
  FLoginFrame := TFRpLoginFrameVCL.Create(Self);
  FLoginFrame.Parent := PLoginControl;
  FLoginFrame.Align := alClient;

  TRpAuthManager.Instance.RegisterAuthListener(AuthChanged);
  UpdateAuthUI;

  FDebounceTimer := TTimer.Create(Self);
  FDebounceTimer.Interval := 1000;
  FDebounceTimer.Enabled := False;
  FDebounceTimer.OnTimer := OnDebounceTimer;

  MemoLog.WordWrap := True;
  MemoLog.ScrollBars := ssVertical;
end;

procedure TFRpMonacoEditorVCL.BClearLogClick(Sender: TObject);
begin
  if MemoLog <> nil then
    MemoLog.Clear;
end;

destructor TFRpMonacoEditorVCL.Destroy;
begin
  if FGuard <> nil then
    FGuard.Invalidate;
  if Edge.WebViewCreated then
    Edge.CloseWebView;
  ClearSchemaItems;
  TRpAuthManager.Instance.UnregisterAuthListener(AuthChanged);
  inherited;
end;

procedure TFRpMonacoEditorVCL.CreateWnd;
var
  LDestPath: string;
begin
  inherited;

  if not Edge.WebViewCreated then
  begin
    Edge.HandleNeeded;

    LDestPath := TPath.Combine(FAppDataPath, 'Reportman\Monaco');
    Edge.UserDataFolder := TPath.Combine(LDestPath, 'EdgeData');

    Edge.CreateWebView;
  end;
end;

procedure TFRpMonacoEditorVCL.Resize;
begin
  inherited;
  LayoutTopControls;
end;

procedure TFRpMonacoEditorVCL.EdgeCreateWebViewCompleted(
  Sender: TCustomEdgeBrowser; AResult: HRESULT);
var
  LDestPath, LURL: string;
begin
  if Succeeded(AResult) then
  begin
    // Ensure Edge events are hooked up
    Edge.OnWebMessageReceived := EdgeWebMessageReceived;
    Edge.OnNavigationCompleted := EdgeNavigationCompleted;

    LDestPath := TPath.Combine(FAppDataPath, 'Reportman\Monaco\MonacoEditor');

    LURL := 'file:///' + LDestPath.Replace('\', '/');
    if not LURL.EndsWith('/') then
      LURL := LURL + '/';
    LURL := LURL + 'index.html';

    Edge.Navigate(LURL);
  end;
end;

procedure TFRpMonacoEditorVCL.EdgeNavigationCompleted(Sender: TCustomEdgeBrowser;
  IsSuccess: Boolean; WebErrorStatus: TOleEnum);
begin
  if IsSuccess then
  begin
    if FSQL <> '' then
      SetSQL(FSQL);
  end;
end;

procedure TFRpMonacoEditorVCL.SetSQL(const Value: string);
var
  LJSON: TJSONString;
  LScript: string;
begin
  if FUpdatingFromBrowser then
    Exit;

  FSQL := Value;
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

procedure TFRpMonacoEditorVCL.LoadSQL(const ASQL: string);
begin
  SetSQL(ASQL);
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

procedure TFRpMonacoEditorVCL.ApplyUserSchemas(AList: TStrings);
var
  I: Integer;
  LSchemaName: string;
  LSchemaValue: string;
  LPosSep: Integer;
  LHubDatabaseId: Int64;
  LSchemaId: Int64;
begin
  if FLoadingSchemas then
    Exit;

  FLoadingSchemas := True;
  ComboSchema.Items.BeginUpdate;
  try
    ClearSchemaItems;
    ComboSchema.Items.Add('');
    for I := 0 to AList.Count - 1 do
    begin
      LSchemaName := AList.Names[I];
      LSchemaValue := AList.ValueFromIndex[I];
      LPosSep := Pos('|', LSchemaValue);
      if LPosSep > 0 then
      begin
        LHubDatabaseId := StrToInt64Def(Copy(LSchemaValue, 1, LPosSep - 1), 0);
        LSchemaId := StrToInt64Def(Copy(LSchemaValue, LPosSep + 1, MaxInt), 0);
      end
      else
      begin
        LHubDatabaseId := 0;
        LSchemaId := StrToInt64Def(LSchemaValue, 0);
      end;
      ComboSchema.Items.AddObject(LSchemaName,
        TSchemaComboItem.Create(LHubDatabaseId, LSchemaId));
    end;

    SelectCurrentSchema;
  finally
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

procedure TFRpMonacoEditorVCL.SetHubDatabaseId(const Value: Int64);
begin
  FBaseHubDatabaseId := Value;
  if FHubDatabaseId = Value then
    Exit;

  FHubDatabaseId := Value;
  if (ComboSchema.Items.Count = 0) and TRpAuthManager.Instance.IsLoggedIn then
    UpdateAuthUI;
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
    FHubDatabaseId := FBaseHubDatabaseId;
  SelectCurrentSchema;
end;

procedure TFRpMonacoEditorVCL.SelectCurrentSchema;
var
  I: Integer;
  LItem: TSchemaComboItem;
begin
  if ComboSchema.Items.Count = 0 then
    Exit;

  if FHubSchemaId = 0 then
  begin
    ComboSchema.ItemIndex := 0;
    FSchema := '';
    FHubDatabaseId := FBaseHubDatabaseId;
    Exit;
  end;

  ComboSchema.ItemIndex := 0;
  for I := 1 to ComboSchema.Items.Count - 1 do
  begin
    LItem := TSchemaComboItem(ComboSchema.Items.Objects[I]);
    if (LItem <> nil) and (LItem.HubSchemaId = FHubSchemaId) and
      ((FHubDatabaseId = 0) or (LItem.HubDatabaseId = FHubDatabaseId)) then
    begin
      ComboSchema.ItemIndex := I;
      FSchema := ComboSchema.Items[I];
      FHubDatabaseId := LItem.HubDatabaseId;
      Break;
    end;
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
    end;
  end
  else
  begin
    FSchema := '';
    FHubDatabaseId := FBaseHubDatabaseId;
    FHubSchemaId := 0;
  end;
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
          ShowMessage('Error in Monaco messaging: '+E.Message);
        end);
  end;
end;

procedure TFRpMonacoEditorVCL.ProcessWebMessage(const LMessage: string);
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LType: string;
  LNewSQL: string;
begin
  OutputDebugString(PChar('MonacoWebMessage: ' + LMessage));
  if FUpdatingFromBrowser then 
    Exit;

  LVal := TJSONObject.ParseJSONValue(LMessage);
  try
    LNewSQL := '';
    if (LVal <> nil) and (LVal is TJSONObject) then
    begin
      LObj := TJSONObject(LVal);
      if LObj.Values['type'] <> nil then
      begin
        LType := LObj.Values['type'].Value;

        if LType = 'GET_AI_COMPLETIONS' then
        begin
          HandleAICompletionRequest(LObj);
          Exit;
        end
        else if LType = 'EDITOR_READY' then
        begin
          FEditorReady := True;
          SetSQL(FSQL);
          Exit;
        end;
      end;
      // If it's a JSON object but not a command, it's probably specialized SQL or data
      LNewSQL := LMessage;
    end
    else if (LVal <> nil) and (LVal is TJSONString) then
    begin
      // Extract the unquoted string value
      LNewSQL := TJSONString(LVal).Value;
    end
    else
    begin
      // Raw string
      LNewSQL := LMessage;
    end;

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
  finally
    if LVal <> nil then
      LVal.Free;
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

function CalculateCursorPosition(const ACode: string; ALineNumber, AColumn: Integer): Integer;
var
  LLines: TArray<string>;
  I: Integer;
begin
  // Dividimos estrictamente por #10 igual que .Split('\n') en C#
  LLines := ACode.Split([#10]);
  Result := 0;

  // C# equivalent: for (int i = 0; i < lineNumber - 1 && i < lines.Length; i++)
  for I := 0 to ALineNumber - 2 do
  begin
    if I >= Length(LLines) then
      Break;
    Result := Result + Length(LLines[I]) + 1; // +1 al restituir el salto de línea eliminado
  end;

  Result := Result + AColumn - 1;
  if Result < 0 then
    Result := 0;
end;

procedure TFRpMonacoEditorVCL.HandleAICompletionRequest(const ARequest: TJSONObject);
var
  LVal, LValL, LValC: TJSONValue;
  LEmptyInlineItems, LEmptyCompletionItems: TJSONArray;
  LLineNumber, LColumn: Integer;
begin
  FDebounceTimer.Enabled := False;
  
  FPendingRequestId := '';
  LVal := ARequest.GetValue('requestId');
  if (LVal <> nil) and (not LVal.Null) then
    FPendingRequestId := LVal.Value;

  FPendingSql := '';
  LVal := ARequest.GetValue('code');
  if (LVal <> nil) and (not LVal.Null) then
    FPendingSql := LVal.Value;

  FPendingPos := 0;
  LVal := ARequest.GetValue('position');
  if (LVal <> nil) and (not LVal.Null) then
  begin
    if LVal is TJSONObject then
    begin
      // Recibimos un objeto { lineNumber: X, column: Y } tal cual esperas
      LLineNumber := 1;
      LColumn := 1;
      
      LValL := TJSONObject(LVal).GetValue('lineNumber');
      if (LValL <> nil) and (not LValL.Null) then
        LLineNumber := StrToIntDef(LValL.ToString.Replace('"', ''), 1);

      LValC := TJSONObject(LVal).GetValue('column');
      if (LValC <> nil) and (not LValC.Null) then
        LColumn := StrToIntDef(LValC.ToString.Replace('"', ''), 1);

      // Calculamos el cursor character offset como en tu C# code
      FPendingPos := CalculateCursorPosition(FPendingSql, LLineNumber, LColumn);
    end
    else
    begin
      // Si llegara plano por algún motivo
      FPendingPos := StrToIntDef(LVal.ToString.Replace('"', ''), 0);
    end;
  end;

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
  LCurrentVersion: Integer;
  LStartRequestId: string;
  LStartSql: string;
  LStartPos: Integer;
  LTaskProc: TProc;
begin
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
  LCurrentVersion := FAuthUIUpdateVersion;

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
            if MemoLog.Lines.Count > 0 then
              MemoLog.Lines.Add('');
            MemoLog.Lines.Add('Actor: Assistant');
          end;
        end;
      TThread.Queue(nil, LInnerQueueProc);

      LHttp := TRpDatabaseHttp.Create;
      try
        LHttp.Token := TRpAuthManager.Instance.Token;
        LHttp.InstallId := TRpAuthManager.Instance.InstallId;
        LHttp.HubDatabaseId := FHubDatabaseId;
        LHttp.HubSchemaId := FHubSchemaId;
        LHttp.AITier := FAISelection.AITier;
        LHttp.AgentSecret := FAISelection.AgentSecret;
        LHttp.AgentAiId := FAISelection.AgentAiId;
        LUAIMode := FAISelection.AIMode;

        LResponse := nil;
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

              FAISelection.UpdateTokens(LInT, LOutT);
              if LInT > 0 then
                MemoLog.Lines.Add('Autocomplete inference complete. Input Tokens: ' + IntToStr(LInT) + ' Output Tokens: ' + IntToStr(LOutT))
              else
                MemoLog.Lines.Add('Autocomplete inference complete.');

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
  const AStage, AChunkType, AChunk: string; AInputTokens,
  AOutputTokens: Integer);
var
  LStage: string;
  LChunk: string;
  LChunkType: string;
  LInputTokens: Integer;
  LOutputTokens: Integer;
begin
  LStage := AStage;
  LChunk := AChunk;
  LChunkType := AChunkType;
  LInputTokens := AInputTokens;
  LOutputTokens := AOutputTokens;
  TThread.Queue(nil,
    procedure
    begin
      if FAISelection <> nil then
        FAISelection.UpdateTokens(LInputTokens, LOutputTokens);
      if not SameText(FActiveInferenceRequestId, FPendingRequestId) then
        Exit;
      if not SameText(LStage, 'ReceivingResponse') then
        Exit;
      if LChunk = '' then
        Exit;
      MemoLog.HandleNeeded;
      SendMessage(MemoLog.Handle, EM_SETSEL, WPARAM(MAXINT), LPARAM(MAXINT));
      SendMessage(MemoLog.Handle, EM_REPLACESEL, 0, NativeInt(PChar(LChunk)));
      if SameText(LChunkType, 'End') then
        MemoLog.Lines.Add('');
    end);
end;

procedure TFRpMonacoEditorVCL.SendAICompletions(const AInlineItems, ACompletionItems: TJSONArray; const ARequestId: string);
var
  LResponse: TJSONObject;
  LScript: string;
  LEscapedJson: string;
begin
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
begin
  if FAIButton <> nil then
    FAIButton.Invalidate;
  if FSchemaConfigButton <> nil then
    FSchemaConfigButton.Invalidate;
end;

procedure TFRpMonacoEditorVCL.UpdateAuthUI;
var
  LLoggedIn: Boolean;
  LAIEnabled: Boolean;
  LSelectedTier: string;
  LSelectedAgentAiId: Int64;
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
    ComboSchema.Clear;
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
    begin
      LPayload := TMonacoAuthRefreshPayload.Create;
      LHasQueued := False;
      try
        LPayload.RequestVersion := LRequestVersion;
        LPayload.SelectedTier := LSelectedTier;
        LPayload.SelectedAgentAiId := LSelectedAgentAiId;
        if LNeedsSchemas then
          LoadUserSchemas(LPayload.Schemas);
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
