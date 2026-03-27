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
  rpauthmanager, rpfrmaiselectionvcl, rpfrmloginvcl, rpfrmloginframevcl, System.JSON, rpdatahttp,
  System.Zip, System.IOUtils;

type
  TFRpMonacoEditorVCL = class(TFrame)
    PTop: TPanel;
    ComboSchema: TComboBox;
    Edge: TEdgeBrowser;
    PLoginControl: TPanel;

    procedure EdgeCreateWebViewCompleted(Sender: TCustomEdgeBrowser;
      AResult: HRESULT);
    procedure EdgeWebMessageReceived(Sender: TCustomEdgeBrowser;
      Args: TWebMessageReceivedEventArgs);
    procedure EdgeNavigationCompleted(Sender: TCustomEdgeBrowser;
      IsSuccess: Boolean; WebErrorStatus: TOleEnum);
    procedure AuthChanged(ASuccess: Boolean);
  private
    FAISelection: TFRpAISelectionVCL;
    FLoginFrame: TFRpLoginFrameVCL;
    FSQL: string;
    FSchema: string;
    FOnContentChanged: TNotifyEvent;
    FAppDataPath: string;
    FEditorReady: Boolean;
    FUpdatingFromBrowser: Boolean;
    FHubDatabaseId: Int64;
    FHubSchemaId: Int64;
    procedure ProcessWebMessage(const LMessage: string);
    procedure SetSQL(const Value: string);
    procedure HandleAICompletionRequest(const ARequest: TJSONObject);
    procedure SendAICompletions(const AInlineItems, ACompletionItems: TJSONArray; const ARequestId: string);
    procedure UpdateAuthUI;
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadSQL(const ASQL: string);
    procedure SetSchema(const ASchema: string);
    property SQL: string read FSQL write SetSQL;
    property HubDatabaseId: Int64 read FHubDatabaseId write FHubDatabaseId;
    property HubSchemaId: Int64 read FHubSchemaId write FHubSchemaId;
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
  FAISelection.Width := 340;

  // Create Login Frame
  FLoginFrame := TFRpLoginFrameVCL.Create(Self);
  FLoginFrame.Parent := PLoginControl;
  FLoginFrame.Align := alClient;

  TRpAuthManager.Instance.OnAuthChanged := AuthChanged;
  UpdateAuthUI;
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

procedure TFRpMonacoEditorVCL.SetSchema(const ASchema: string);
begin
  FSchema := ASchema;
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

procedure TFRpMonacoEditorVCL.HandleAICompletionRequest(const ARequest: TJSONObject);
var
  LHttp: TRpDatabaseHttp;
  LSql: string;
  LPos: Integer;
  LRequestId: string;
  LResponse: TJSONObject;
  LResult, LAutoComplete: TJSONObject;
  LInlineArr, LListArr: TJSONArray;
  LVal: TJSONValue;
  LInlineItems, LCompletionItems: TJSONArray;
  I: Integer;
  LItem: TJSONObject;
begin
  LRequestId := '';
  LVal := ARequest.Values['requestId'];
  if (LVal <> nil) and (not LVal.Null) then
    LRequestId := LVal.Value;

  LSql := '';
  LVal := ARequest.Values['code'];
  if (LVal <> nil) and (not LVal.Null) then
    LSql := LVal.Value;

  LPos := 0;
  LVal := ARequest.Values['position'];
  if (LVal <> nil) and (not LVal.Null) then
  begin
    if LVal is TJSONNumber then
      LPos := TJSONNumber(LVal).AsInt
    else
      LPos := StrToIntDef(LVal.Value, 0);
  end;

  LHttp := TRpDatabaseHttp.Create;
  try
    LHttp.Token := TRpAuthManager.Instance.Token;
    LHttp.InstallId := TRpAuthManager.Instance.InstallId;
    LHttp.HubDatabaseId := FHubDatabaseId;
    LHttp.HubSchemaId := FHubSchemaId;
    LHttp.AITier := FAISelection.AITier;
    LHttp.AgentSecret := FAISelection.AgentSecret;
    LHttp.AgentAiId := FAISelection.AgentAiId;

    LResponse := nil;
    try
      LResponse := LHttp.SuggestSql(LSql, LPos, FAISelection.AIMode);
    except
      on E: Exception do
        LResponse := nil;
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

      // Update credit gauge from userProfile in the response
      LVal := LResponse.Values['userProfile'];
      if (LVal <> nil) and (LVal is TJSONObject) then
        FAISelection.UpdateFromUserProfile(LVal as TJSONObject);
    finally
      LResponse.Free;
    end;

    SendAICompletions(LInlineItems, LCompletionItems, LRequestId);
  finally
    LHttp.Free;
  end;
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

procedure TFRpMonacoEditorVCL.UpdateAuthUI;
begin
  if FAISelection <> nil then
    FAISelection.RefreshState;
end;

procedure TFRpMonacoEditorVCL.AuthChanged(ASuccess: Boolean);
begin
  UpdateAuthUI;
end;

end.

