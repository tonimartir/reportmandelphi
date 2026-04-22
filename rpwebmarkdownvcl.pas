{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpwebmarkdownvcl                                }
{       WebView2 Markdown Viewer - Shared Component     }
{                                                       }
{       Copyright (c) 1994-2025 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpwebmarkdownvcl;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  Winapi.WebView2, Winapi.ActiveX, Vcl.Edge,
  System.Zip, System.IOUtils, System.JSON, rpmdshfolder;

    const AssetsVersion = '2';

type
  TRpWebMarkdownView = class(TPanel)
  private
    FEdge: TEdgeBrowser;
    FMemoFallback: TMemo;
    FReady: Boolean;
    FWebViewFailed: Boolean;
    FPendingCalls: TStringList;
    FAssetRootPath: string;
    FUseFallback: Boolean;

    procedure EdgeCreateWebViewCompleted(Sender: TCustomEdgeBrowser; AResult: HRESULT);
    procedure EdgeNavigationCompleted(Sender: TCustomEdgeBrowser;
      IsSuccess: Boolean; WebErrorStatus: TOleEnum);
    procedure EdgeWebMessageReceived(Sender: TCustomEdgeBrowser;
      Args: TWebMessageReceivedEventArgs);

    function EnsureAssetsExtracted: string;
    procedure TryPreloadWebView2Loader;
    procedure ExecuteOrQueue(const AScript: string);
    procedure FlushPendingCalls;
    procedure ActivateFallback;
    procedure FallbackAppend(const AText: string);
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>Append a chat-style message with role icon (role: 'user', 'assistant', 'system')</summary>
    procedure AppendMessage(const ARole, AMarkdown: string);
    /// <summary>Append a streaming chunk to the current streaming message</summary>
    procedure AppendStreamingChunk(const ARole, AChunk: string; APrefillPercent: Integer);
    /// <summary>Finish the current streaming message (removes cursor animation)</summary>
    procedure FinishStreaming;
    /// <summary>Append a single log line</summary>
    procedure AppendLogLine(const AText: string);
    /// <summary>Append a raw chunk (streaming append without newline)</summary>
    procedure AppendLogChunk(const AChunk: string);
    /// <summary>End the current log chunk block</summary>
    procedure EndLogChunk;
    /// <summary>Clear all messages</summary>
    procedure ClearAll;
    /// <summary>Scroll to bottom</summary>
    procedure ScrollToEnd;
    /// <summary>Whether the WebView is ready to accept commands</summary>
    property Ready: Boolean read FReady;
  end;

implementation

{$R WebMarkdownAssets.res}

function EscapeJSString(const S: string): string;
var
  I: Integer;
  Ch: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    Ch := S[I];
    case Ch of
      '\': Result := Result + '\\';
      '''': Result := Result + '\''';
      #10: Result := Result + '\n';
      #13: ; // skip CR
      #9: Result := Result + '\t';
      #8: Result := Result + '\b';
      #12: Result := Result + '\f';
    else
      if (Ord(Ch) < 32) then
        Result := Result + '\u' + IntToHex(Ord(Ch), 4)
      else
        Result := Result + Ch;
    end;
  end;
end;

constructor TRpWebMarkdownView.Create(AOwner: TComponent);
var
  LDllPath: string;
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FReady := False;
  FWebViewFailed := False;
  FUseFallback := False;
  FPendingCalls := TStringList.Create;

  // 1. Determine safe extraction path in %LOCALAPPDATA% using rpmdshfolder
  FAssetRootPath := EnsureAssetsExtracted;

  // Try to preload WebView2Loader.dll (shared with MonacoEditor)
  TryPreloadWebView2Loader;

  // Create the Edge browser
  FEdge := TEdgeBrowser.Create(Self);
  FEdge.Parent := Self;
  FEdge.Align := alClient;
  FEdge.Visible := True;
  FEdge.OnCreateWebViewCompleted := EdgeCreateWebViewCompleted;
  FEdge.OnNavigationCompleted := EdgeNavigationCompleted;
  FEdge.OnWebMessageReceived := EdgeWebMessageReceived;

  // Create fallback memo (hidden initially)
  FMemoFallback := TMemo.Create(Self);
  FMemoFallback.Parent := Self;
  FMemoFallback.Align := alClient;
  FMemoFallback.Visible := False;
  FMemoFallback.ReadOnly := True;
  FMemoFallback.ScrollBars := ssVertical;
  FMemoFallback.WordWrap := True;
  FMemoFallback.Color := clBlack;
  FMemoFallback.Font.Color := clLime;
  FMemoFallback.Font.Name := 'Consolas';
  FMemoFallback.Font.Size := 9;
end;

destructor TRpWebMarkdownView.Destroy;
begin
  if (FEdge <> nil) and FEdge.WebViewCreated then
  begin
    try
      FEdge.CloseWebView;
    except
      // Ignore
    end;
  end;
  FPendingCalls.Free;
  inherited Destroy;
end;

procedure TRpWebMarkdownView.TryPreloadWebView2Loader;
var
  LCandidates: array[0..2] of string;
  I: Integer;
  LMonacoPath: string;
begin
  // Try MonacoEditor's already-extracted DLL first
  LMonacoPath := ObtainFolderLocalUserConfig('Reportman', 'Monaco', 'MonacoEditor');
  if SizeOf(Pointer) = 8 then
  begin
    LCandidates[0] := TPath.Combine(LMonacoPath, 'x64\WebView2Loader.dll');
    LCandidates[1] := TPath.Combine(FAssetRootPath, 'x64\WebView2Loader.dll');
  end
  else
  begin
    LCandidates[0] := TPath.Combine(LMonacoPath, 'x86\WebView2Loader.dll');
    LCandidates[1] := TPath.Combine(FAssetRootPath, 'x86\WebView2Loader.dll');
  end;
  LCandidates[2] := '';

  for I := Low(LCandidates) to High(LCandidates) do
  begin
    if (LCandidates[I] <> '') and TFile.Exists(LCandidates[I]) then
    begin
      LoadLibrary(PChar(LCandidates[I]));
      Exit;
    end;
  end;
end;

procedure TRpWebMarkdownView.CreateWnd;
var
  LDestPath: string;
begin
  inherited;

  if FUseFallback or FWebViewFailed then
    Exit;

  if not FEdge.WebViewCreated then
  begin
    try
      FEdge.HandleNeeded;

    LDestPath := ObtainFolderLocalUserConfig('Reportman', 'WebMarkdown', '');
    FEdge.UserDataFolder := TPath.Combine(LDestPath, 'EdgeData');

      FEdge.CreateWebView;
    except
      ActivateFallback;
    end;
  end;
end;

function TRpWebMarkdownView.EnsureAssetsExtracted: string;
var
  LBasePath: string;
  LVersionPath: string;
  LResStream: TResourceStream;
  LZip: TZipFile;
begin
  LBasePath := ObtainFolderLocalUserConfig('Reportman', 'WebMarkdown', 'WebMarkdown');
  LVersionPath := TPath.Combine(LBasePath, 'assets.version');
  if TFile.Exists(TPath.Combine(LBasePath, 'index.html')) and
    TFile.Exists(LVersionPath) and
    SameText(Trim(TFile.ReadAllText(LVersionPath, TEncoding.UTF8)), AssetsVersion) then
  begin
    Result := LBasePath;
    Exit;
  end;

  if TDirectory.Exists(LBasePath) then
    TDirectory.Delete(LBasePath, True);
  TDirectory.CreateDirectory(LBasePath);
  LResStream := TResourceStream.Create(HInstance, 'WEBMARKDOWN_ZIP', RT_RCDATA);
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

  TFile.WriteAllText(LVersionPath, AssetsVersion, TEncoding.UTF8);

  Result := LBasePath;
end;

procedure TRpWebMarkdownView.EdgeCreateWebViewCompleted(
  Sender: TCustomEdgeBrowser; AResult: HRESULT);
var
  LURL: string;
begin
  if Succeeded(AResult) then
  begin
    if FAssetRootPath = '' then
      FAssetRootPath := EnsureAssetsExtracted;

    LURL := 'file:///' + FAssetRootPath.Replace('\', '/');
    if not LURL.EndsWith('/') then
      LURL := LURL + '/';
    LURL := LURL + 'index.html';

    FEdge.Navigate(LURL);
  end
  else
    ActivateFallback;
end;

procedure TRpWebMarkdownView.EdgeNavigationCompleted(
  Sender: TCustomEdgeBrowser; IsSuccess: Boolean; WebErrorStatus: TOleEnum);
begin
  if IsSuccess then
  begin
    FReady := True;
    FlushPendingCalls;
  end
  else
    ActivateFallback;
end;

procedure TRpWebMarkdownView.EdgeWebMessageReceived(
  Sender: TCustomEdgeBrowser; Args: TWebMessageReceivedEventArgs);
var
  LP: PWideChar;
  LMsg: string;
begin
  try
    LP := nil;
    Args.ArgsInterface.TryGetWebMessageAsString(LP);
    if LP <> nil then
    begin
      LMsg := LP;
      CoTaskMemFree(LP);
      // We can handle messages from the web page here if needed
      // Currently only WEBMARKDOWN_READY is sent, which we handle
      // by noting FReady = True in EdgeNavigationCompleted
    end;
  except
    // Ignore errors in message handling
  end;
end;

procedure TRpWebMarkdownView.ActivateFallback;
begin
  FWebViewFailed := True;
  FUseFallback := True;
  FReady := False;

  if FEdge <> nil then
    FEdge.Visible := False;
  if FMemoFallback <> nil then
    FMemoFallback.Visible := True;

  // Flush pending calls as fallback text
  FlushPendingCalls;
end;

procedure TRpWebMarkdownView.FallbackAppend(const AText: string);
begin
  if FMemoFallback <> nil then
  begin
    FMemoFallback.Lines.Add(AText);
    FMemoFallback.SelLength := 0;
    FMemoFallback.SelStart := Length(FMemoFallback.Text);
    FMemoFallback.Perform(EM_SCROLLCARET, 0, 0);
  end;
end;

procedure TRpWebMarkdownView.ExecuteOrQueue(const AScript: string);
begin
  if FUseFallback then
    Exit;

  if FReady and FEdge.WebViewCreated then
    FEdge.ExecuteScript(AScript)
  else
    FPendingCalls.Add(AScript);
end;

procedure TRpWebMarkdownView.FlushPendingCalls;
var
  I: Integer;
begin
  if FUseFallback then
  begin
    // For fallback, we can't execute JS, just clear pending
    FPendingCalls.Clear;
    Exit;
  end;

  if FReady and FEdge.WebViewCreated then
  begin
    for I := 0 to FPendingCalls.Count - 1 do
      FEdge.ExecuteScript(FPendingCalls[I]);
    FPendingCalls.Clear;
  end;
end;

// ============================================================
// Public API
// ============================================================

procedure TRpWebMarkdownView.AppendMessage(const ARole, AMarkdown: string);
var
  LScript: string;
begin
  if FUseFallback then
  begin
    FallbackAppend('[' + ARole + '] ' + AMarkdown);
    Exit;
  end;

  LScript := 'window.appendMessage(''' + EscapeJSString(ARole) + ''', ''' +
    EscapeJSString(AMarkdown) + ''');';
  ExecuteOrQueue(LScript);
end;

procedure TRpWebMarkdownView.AppendStreamingChunk(const ARole, AChunk: string;
  APrefillPercent: Integer);
var
  LScript: string;
begin
  if FUseFallback then
  begin
    FallbackAppend(AChunk);
    Exit;
  end;

  LScript := 'window.appendStreamingChunk(''' + EscapeJSString(ARole) + ''', ''' +
    EscapeJSString(AChunk) + ''', ' + IntToStr(APrefillPercent) + ');';
  ExecuteOrQueue(LScript);
end;

procedure TRpWebMarkdownView.FinishStreaming;
begin
  if FUseFallback then
    Exit;

  ExecuteOrQueue('window.finishStreaming();');
end;

procedure TRpWebMarkdownView.AppendLogLine(const AText: string);
var
  LScript: string;
begin
  if FUseFallback then
  begin
    FallbackAppend(AText);
    Exit;
  end;

  LScript := 'window.appendLogLine(''' + EscapeJSString(AText) + ''');';
  ExecuteOrQueue(LScript);
end;

procedure TRpWebMarkdownView.AppendLogChunk(const AChunk: string);
var
  LScript: string;
begin
  if FUseFallback then
  begin
    if FMemoFallback <> nil then
    begin
      FMemoFallback.HandleNeeded;
      SendMessage(FMemoFallback.Handle, EM_SETSEL, WPARAM(MAXINT), LPARAM(MAXINT));
      SendMessage(FMemoFallback.Handle, EM_REPLACESEL, 0, NativeInt(PChar(AChunk)));
    end;
    Exit;
  end;

  LScript := 'window.appendLogChunk(''' + EscapeJSString(AChunk) + ''');';
  ExecuteOrQueue(LScript);
end;

procedure TRpWebMarkdownView.EndLogChunk;
begin
  if FUseFallback then
  begin
    FallbackAppend('');
    Exit;
  end;

  ExecuteOrQueue('window.endLogChunk();');
end;

procedure TRpWebMarkdownView.ClearAll;
begin
  if FUseFallback then
  begin
    if FMemoFallback <> nil then
      FMemoFallback.Clear;
    Exit;
  end;

  ExecuteOrQueue('window.clearAll();');
end;

procedure TRpWebMarkdownView.ScrollToEnd;
begin
  if FUseFallback then
  begin
    if FMemoFallback <> nil then
    begin
      FMemoFallback.SelLength := 0;
      FMemoFallback.SelStart := Length(FMemoFallback.Text);
      FMemoFallback.Perform(EM_SCROLLCARET, 0, 0);
    end;
    Exit;
  end;

  ExecuteOrQueue('window.scrollToEnd();');
end;

end.
