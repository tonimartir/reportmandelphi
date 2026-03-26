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
  private
    FAISelection: TFRpAISelectionVCL;
    FSQL: string;
    FSchema: string;
    FOnContentChanged: TNotifyEvent;
    FAppDataPath: string;
    FEditorReady: Boolean;
    procedure ProcessWebMessage(const LMessage: string);
    procedure SetSQL(const Value: string);
    procedure HandleAICompletionRequest(const ARequest: TJSONObject);
    procedure SendAICompletions(const ACompletions: TJSONArray; const ARequestId: string);
    procedure UpdateAuthUI;
  protected
    procedure CreateWnd; override;
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
  FEditorReady := False;

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

procedure TFRpMonacoEditorVCL.EdgeCreateWebViewCompleted(
  Sender: TCustomEdgeBrowser; AResult: HRESULT);
var
  LDestPath, LURL: string;
begin
  if Succeeded(AResult) then
  begin
    // Ensure Edge events are hooked up
    Edge.OnWebMessageReceived := EdgeWebMessageReceived;
    LDestPath := TPath.Combine(FAppDataPath, 'Reportman\Monaco\MonacoEditor');

    LURL := 'file:///' + LDestPath.Replace('\', '/');
    if not LURL.EndsWith('/') then
      LURL := LURL + '/';
    LURL := LURL + 'index.html';

    Edge.Navigate(LURL);
  end;
end;

procedure TFRpMonacoEditorVCL.SetSQL(const Value: string);
var
  LJSON: TJSONString;
  LScript: string;
begin
  FSQL := Value;
  if FEditorReady then
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

procedure TFRpMonacoEditorVCL.SetSchema(const ASchema: string);
begin
  FSchema := ASchema;
end;

procedure TFRpMonacoEditorVCL.EdgeWebMessageReceived(
  Sender: TCustomEdgeBrowser;
  Args: TWebMessageReceivedEventArgs);
var
  LP: PWideChar;
  LMessage: string;
begin
 // if not Supports(Args, ICoreWebView2WebMessageReceivedEventArgs, LArgs) then
 //   Exit;

  LP := nil;

  if Succeeded(Args.ArgsInterface.TryGetWebMessageAsString(LP)) then
  begin
    if LP <> nil then
      LMessage := LP;
  end;
(*

  if Succeeded(LArgs.Get_WebMessageAsJson(LPMessage)) then
  begin
    LMessage := LPMessage;
    CoTaskMemFree(LPMessage);
  end;

  if LMessage = '' then
    Exit;

  TThread.Queue(nil,
    procedure
    begin
      ProcessWebMessage(LMessage);
    end);*)
end;

procedure TFRpMonacoEditorVCL.ProcessWebMessage(const LMessage: string);
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LType: string;
begin
  LVal := TJSONObject.ParseJSONValue(LMessage);
  if LVal = nil then
    Exit;

  try
    if LVal is TJSONString then
    begin
      FSQL := TJSONString(LVal).Value;
      if Assigned(FOnContentChanged) then
        FOnContentChanged(Self);
    end
    else if LVal is TJSONObject then
    begin
      LObj := TJSONObject(LVal);

      if LObj.Values['type'] <> nil then
      begin
        LType := LObj.Values['type'].Value;

        if LType = 'GET_AI_COMPLETIONS' then
          HandleAICompletionRequest(LObj)
        else if LType = 'EDITOR_READY' then
        begin
          FEditorReady := True;
          if FSQL <> '' then
            SetSQL(FSQL);
        end;
      end;
    end;
  finally
    LVal.Free;
  end;
end;

procedure TFRpMonacoEditorVCL.HandleAICompletionRequest(const ARequest: TJSONObject);
var
  LRequestId: string;
  LPrefix, LSuffix: string;
  LCompletions: TJSONArray;
begin
  LRequestId := ARequest.Values['requestId'].Value;
  LPrefix := ARequest.Values['prefix'].Value;
  LSuffix := ARequest.Values['suffix'].Value;

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
end;

end.
