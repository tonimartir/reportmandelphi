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
    FIsReady: Boolean;
    FSchema: string;
    FOnContentChanged: TNotifyEvent;
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
begin
  inherited Create(AOwner);
  FIsReady := False;
  
  LDestPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'MonacoEditor');

  // Auto-extract if main file missing
  if not FileExists(TPath.Combine(LDestPath, 'index.html')) then
  begin
    if FindResource(HInstance, 'MONACO_ZIP', RT_RCDATA) <> 0 then
    begin
      LResStream := TResourceStream.Create(HInstance, 'MONACO_ZIP', RT_RCDATA);
      try
        LZip := TZipFile.Create;
        try
          LZip.Open(LResStream, zmRead);
          LZip.ExtractAll(ExtractFilePath(ParamStr(0)));
        finally
          LZip.Free;
        end;
      finally
        LResStream.Free;
      end;
    end;
  end;

  // Create AI Selection Frame
  FAISelection := TFRpAISelectionVCL.Create(Self);
  FAISelection.Parent := PTop;
  FAISelection.Align := alRight;
  FAISelection.Width := 320;

  // Initialize Edge
  Edge.UserDataFolder := TPath.Combine(ExtractFilePath(ParamStr(0)), 'EdgeData');
  Edge.Navigate('file:///' + TPath.Combine(LDestPath, 'index.html'));
end;

procedure TFRpMonacoEditorVCL.EdgeCreateWebViewCompleted(
  Sender: TCustomEdgeBrowser; AResult: HRESULT);
begin
  if Succeeded(AResult) then
  begin
    FIsReady := True;
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
  // Notify JS if needed
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
    if LObj = nil then Exit;
    LType := LObj.Values['type'].Value;
    
    if LType = 'GET_AI_COMPLETIONS' then
      HandleAICompletionRequest(LObj)
    else if LType = 'CONTENT_CHANGED' then
    begin
      FSQL := LObj.Values['content'].Value;
      if Assigned(FOnContentChanged) then
        FOnContentChanged(Self);
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
