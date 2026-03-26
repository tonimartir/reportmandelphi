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
  Dialogs, ExtCtrls, StdCtrls, Winapi.WebView2, Winapi.ActiveX, Vcl.Edge,
  rpauthmanager, rpfrmaiselectionvcl, rpfrmloginvcl, System.JSON, rpdatahttp,
  System.Zip, System.IOUtils;

type
  TFRpMonacoEditorVCL = class(TFrame)
    PTop: TPanel;
    ComboSchema: TComboBox;
    Edge: TEdgeBrowser;
    BLogin: TButton;
    procedure EdgeCreateWebViewCompleted(Sender: TCustomEdgeBrowser;
      AResult: HRESULT);
    procedure EdgeWebMessageReceived(Sender: TCustomEdgeBrowser;
      Args: TWebMessageReceivedEventArgs);
    procedure TimerInitTimer(Sender: TObject);
  private
    FAISelection: TFRpAISelectionVCL;
    FSQL: string;
    FIsReady: Boolean;
    FSchema: string;
    FOnContentChanged: TNotifyEvent;
    FTimer: TTimer;
    FAppDataPath: string;
    procedure SetSQL(const Value: string);
    procedure HandleAICompletionRequest(const ARequest: TJSONObject);
    procedure SendAICompletions(const ACompletions: TJSONArray; const ARequestId: string);
    procedure UpdateAuthUI;
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadSQL(const ASQL: string);
    procedure SetSchema(const ASchema: string);
    property SQL: string read FSQL write SetSQL;
    property OnContentChanged: TNotifyEvent read FOnContentChanged write FOnContentChanged;
  end;

implementation

{$R *.dfm}
{$R MonacoEditorAssets.res}

constructor TFRpMonacoEditorVCL.Create(AOwner: TComponent);
var
  LResStream: TResourceStream;
  LZip: TZipFile;
  LDestPath: string;
  LDllPath: string;
begin
  inherited Create(AOwner);
  FIsReady := False;

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

  // Create AI Selection Frame
  FAISelection := TFRpAISelectionVCL.Create(Self);
  FAISelection.Parent := PTop;
  FAISelection.Align := alRight;
  FAISelection.Width := 320;

  // Initialize Timer for delayed Edge creation
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 2000;
  FTimer.OnTimer := TimerInitTimer;
  FTimer.Enabled := True;

  // Ensure Edge events are hooked up
  Edge.OnWebMessageReceived := EdgeWebMessageReceived;
end;

procedure TFRpMonacoEditorVCL.TimerInitTimer(Sender: TObject);
var
  LDestPath: string;
begin
  FTimer.Enabled := False;
  
  if not Edge.WebViewCreated then
  begin
    LDestPath := TPath.Combine(FAppDataPath, 'Reportman\Monaco');
    Edge.UserDataFolder := TPath.Combine(LDestPath, 'EdgeData');
    Edge.CreateWebView;
  end;
end;

procedure TFRpMonacoEditorVCL.EdgeCreateWebViewCompleted(
  Sender: TCustomEdgeBrowser; AResult: HRESULT);
var
  LDestPath, LURL: string;
begin
  if Succeeded(AResult) then
  begin
    FIsReady := True;
    
    LDestPath := TPath.Combine(FAppDataPath, 'Reportman\Monaco\MonacoEditor');
    
    LURL := 'file:///' + LDestPath.Replace('\', '/');
    if not LURL.EndsWith('/') then LURL := LURL + '/';
    LURL := LURL + 'index.html';
    
    Edge.Navigate(LURL);

    if FSQL <> '' then
      SetSQL(FSQL);
  end;
end;

procedure TFRpMonacoEditorVCL.SetSQL(const Value: string);
var
  LEscapedSQL: string;
begin
  FSQL := Value;
  if FIsReady then
  begin
    // Simple escape for JS string
    LEscapedSQL := StringReplace(FSQL, '\', '\\', [rfReplaceAll]);
    LEscapedSQL := StringReplace(LEscapedSQL, '''', '\''', [rfReplaceAll]);
    LEscapedSQL := StringReplace(LEscapedSQL, #13, '\r', [rfReplaceAll]);
    LEscapedSQL := StringReplace(LEscapedSQL, #10, '\n', [rfReplaceAll]);
    Edge.ExecuteScript('window.editor.setValue(''' + LEscapedSQL + ''');');
  end;
end;

procedure TFRpMonacoEditorVCL.LoadSQL(const ASQL: string);
begin
  SetSQL(ASQL);
end;

procedure TFRpMonacoEditorVCL.SetSchema(const ASchema: string);
begin
  FSchema := ASchema;
end;

procedure TFRpMonacoEditorVCL.EdgeWebMessageReceived(Sender: TCustomEdgeBrowser;
  Args: TWebMessageReceivedEventArgs);
var
  LArgs: ICoreWebView2WebMessageReceivedEventArgs;
  LPMessage: PWideChar;
  LMessage: string;
  LObj: TJSONObject;
  LType: string;
begin
  if not Supports(Args, ICoreWebView2WebMessageReceivedEventArgs, LArgs) then
    Exit;

  if Succeeded(LArgs.Get_WebMessageAsJson(LPMessage)) then
  begin
    LMessage := LPMessage;
    CoTaskMemFree(LPMessage);
  end;
  
  if LMessage = '' then Exit;
  LObj := TJSONObject.ParseJSONValue(LMessage) as TJSONObject;
  try
    if (LObj <> nil) and (LObj.Values['type'] <> nil) then
    begin
      LType := LObj.Values['type'].Value;
      
      if LType = 'GET_AI_COMPLETIONS' then
        HandleAICompletionRequest(LObj)
      else if LType = 'CONTENT_CHANGED' then
      begin
        if LObj.Values['content'] <> nil then
        begin
          FSQL := LObj.Values['content'].Value;
          if Assigned(FOnContentChanged) then
            FOnContentChanged(Self);
        end;
      end;
    end;
  finally
    LObj.Free;
  end;
end;

procedure TFRpMonacoEditorVCL.HandleAICompletionRequest(const ARequest: TJSONObject);
var
  LRequestId: string;
  LPrefix, LSuffix: string;
  LCompletions: TJSONArray;
  LPresenter: TRpDatabaseHttp;
begin
  LRequestId := ARequest.Values['requestId'].Value;
  LPrefix := ARequest.Values['prefix'].Value;
  LSuffix := ARequest.Values['suffix'].Value;

  // We need a reference to the active database
  // For now, I'll use a hack or assume it's set
  // This should probably be passed during initialization
  // LPresenter := ...
  
  // Dummy implementation for now, using the Hub driver if available
  // In a real scenario, this would call TRpDatabaseHttp.SuggestSql
  
  LCompletions := TJSONArray.Create;
  SendAICompletions(LCompletions, LRequestId);
end;

procedure TFRpMonacoEditorVCL.SendAICompletions(const ACompletions: TJSONArray; const ARequestId: string);
var
  LResponse: TJSONObject;
  LScript: string;
begin
  LResponse := TJSONObject.Create;
  try
    LResponse.AddPair('type', 'AI_COMPLETIONS_RESPONSE');
    LResponse.AddPair('requestId', ARequestId);
    LResponse.AddPair('completions', ACompletions.Clone as TJSONArray);
    
    LScript := 'window.receiveAICompletions(' + LResponse.ToJSON + ');';
    Edge.ExecuteScript(LScript);
  finally
    LResponse.Free;
  end;
end;

procedure TFRpMonacoEditorVCL.UpdateAuthUI;
begin
  // Update FAISelection and BLogin state
end;

end.
