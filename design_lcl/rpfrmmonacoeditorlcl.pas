{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpfrmmonacoeditorlcl.pas                        }
{       Monaco SQL Editor Control for LCL               }
{       Compatibility unit for Free Pascal / LCL        }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpfrmmonacoeditorlcl;

{$mode delphi}

interface

uses
  Classes, SysUtils, Controls, Graphics, Forms, StdCtrls, ExtCtrls,
  rplclwebview, rpmdshfolder
  {$IFDEF MSWINDOWS}
  , Windows
  {$ENDIF}
  ;

const
  MonacoAssetsVersion = '3';

type
  TStatusLogEvent = procedure(Sender: TObject; const AStatus: string) of object;

  TFRpMonacoEditorLCL = class(TCustomControl)
  private
    FWebView: TRpLCLWebView;
    FMemoFallback: TMemo;
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
    FOnContentChanged: TNotifyEvent;
    FOnWebMessage: TWebMessageReceivedEvent;
    FOnStatusLog: TStatusLogEvent;

    procedure LogStatus(const AText: string);
    function FindMonacoActualRoot(const ABasePath: string): string;
    function EnsureMonacoAssetsExtracted: string;
    procedure AsyncInitWebView(Data: PtrInt);
    procedure WebViewCreateCompleted(Sender: TObject; AResult: HResult);
    procedure WebViewNavigationCompleted(Sender: TObject; IsSuccess: Boolean);
    procedure WebViewMessageReceived(Sender: TObject; const AMessage: string);
    procedure MemoFallbackChange(Sender: TObject);
    procedure RetryTimerTick(Sender: TObject);
    procedure SetSQL(const Value: string);
    function GetSQL: string;
  protected
    procedure CreateWnd; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure TryCreateWebView;
    procedure LoadSQL(const ASQL: string);
    procedure SetTheme(const ATheme: string);
    procedure SetLanguage(const ALang: string);
    procedure ActivateFallback(const AReason: string);

    property SQL: string read GetSQL write SetSQL;
    property Theme: string read FTheme write SetTheme;
    property Language: string read FLanguage write SetLanguage;
    property EditorReady: Boolean read FEditorReady;
    property UseFallback: Boolean read FUseFallback;
    property AssetRootPath: string read FAssetRootPath;
    property WebView: TRpLCLWebView read FWebView;
    property MemoFallback: TMemo read FMemoFallback;

    property OnContentChanged: TNotifyEvent read FOnContentChanged write FOnContentChanged;
    property OnWebMessage: TWebMessageReceivedEvent read FOnWebMessage write FOnWebMessage;
    property OnStatusLog: TStatusLogEvent read FOnStatusLog write FOnStatusLog;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
    property TabStop;
    property TabOrder;
  end;

function EscapeJsonString(const S: string): string;

implementation

uses
  zipper;

{$IFDEF MSWINDOWS}
// Monaco editor assets embedded as the MONACO_ZIP RCDATA resource, the same
// resource used by the VCL editor (MonacoEditorAssets.rc at the repository
// root). The path is relative to this unit.
{$R ../MonacoEditorAssets.res}
{$ENDIF}

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

  // 1. Fallback Memo (hidden by default)
  FMemoFallback := TMemo.Create(Self);
  FMemoFallback.Parent := Self;
  FMemoFallback.Align := alClient;
  FMemoFallback.Visible := False;
  FMemoFallback.ScrollBars := ssBoth;
  FMemoFallback.WordWrap := False;
  FMemoFallback.Font.Name := 'Consolas';
  FMemoFallback.Font.Size := 10;
  FMemoFallback.OnChange := MemoFallbackChange;

  // 2. LCL WebView Control
  FWebView := TRpLCLWebView.Create(Self);
  FWebView.Parent := Self;
  FWebView.Align := alClient;
  FWebView.Visible := True;
  FWebView.OnCreateWebViewCompleted := WebViewCreateCompleted;
  FWebView.OnNavigationCompleted := WebViewNavigationCompleted;
  FWebView.OnWebMessageReceived := WebViewMessageReceived;

  // 3. Retry timer
  FRetryTimer := TTimer.Create(Self);
  FRetryTimer.Enabled := False;
  FRetryTimer.Interval := 500;
  FRetryTimer.OnTimer := RetryTimerTick;

  Width := 400;
  Height := 300;
end;

destructor TFRpMonacoEditorLCL.Destroy;
begin
  if FRetryTimer <> nil then
  begin
    FRetryTimer.Enabled := False;
    FRetryTimer.Free;
    FRetryTimer := nil;
  end;
  inherited Destroy;
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
  if FindResource(HInstance, 'MONACO_ZIP', RT_RCDATA) <> 0 then
  begin
    ForceDirectories(LBasePath);
    LTempZip := LBasePath + DirectorySeparator + 'MonacoEditor.zip.tmp';
    LResStream := TResourceStream.Create(HInstance, 'MONACO_ZIP', RT_RCDATA);
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

  if SysUtils.GetEnvironmentVariable('RPM_FORCE_WEBVIEW_FALLBACK') <> '' then
  begin
    ActivateFallback('Forced by RPM_FORCE_WEBVIEW_FALLBACK');
    Exit;
  end;

  Application.QueueAsyncCall(AsyncInitWebView, 0);
end;

procedure TFRpMonacoEditorLCL.Resize;
begin
  inherited Resize;
  if (FMemoFallback <> nil) and FMemoFallback.Visible then
    FMemoFallback.BoundsRect := ClientRect;
  if (FWebView <> nil) and FWebView.Visible then
    FWebView.BoundsRect := ClientRect;
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
var
  LNewSQL: string;
begin
  LogStatus('Message from Monaco: ' + Copy(AMessage, 1, 60));

  if Assigned(FOnWebMessage) then
    FOnWebMessage(Self, AMessage);

  if Copy(AMessage, 1, 3) = '00:' then
  begin
    // Monaco editor initialized and ready
    FEditorReady := True;
    LogStatus('Monaco Editor ready signal (00:) received. Pushing SQL...');
    SetSQL(FSQL);
    if FTheme <> 'vs' then
      SetTheme(FTheme);
    if FLanguage <> 'sql' then
      SetLanguage(FLanguage);
    Exit;
  end;

  if Copy(AMessage, 1, 3) = '01:' then
  begin
    // Content changed in Monaco
    LNewSQL := Copy(AMessage, 4, MaxInt);
    // Normalize line endings
    LNewSQL := StringReplace(LNewSQL, #13#10, #10, [rfReplaceAll]);
    LNewSQL := StringReplace(LNewSQL, #13, #10, [rfReplaceAll]);
    LNewSQL := StringReplace(LNewSQL, #10, #13#10, [rfReplaceAll]);

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
end;

procedure TFRpMonacoEditorLCL.MemoFallbackChange(Sender: TObject);
var
  LNewSQL: string;
begin
  if (not FUseFallback) or FUpdatingFromBrowser then
    Exit;
  LNewSQL := FMemoFallback.Lines.Text;
  LNewSQL := StringReplace(LNewSQL, #13#10, #10, [rfReplaceAll]);
  LNewSQL := StringReplace(LNewSQL, #13, #10, [rfReplaceAll]);
  LNewSQL := StringReplace(LNewSQL, #10, #13#10, [rfReplaceAll]);

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
var
  LScript: string;
begin
  if FUpdatingFromBrowser then
    Exit;

  FSQL := Value;

  if FUseFallback then
  begin
    FUpdatingFromBrowser := True;
    try
      FMemoFallback.Lines.Text := FSQL;
    finally
      FUpdatingFromBrowser := False;
    end;
    Exit;
  end;

  if FWebView.WebViewCreated and FEditorReady then
  begin
    LScript := 'if (window.editor) { window.editor.setValue(' + EscapeJsonString(FSQL) + '); }';
    FWebView.ExecuteScript(LScript);
  end;
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
var
  LScript: string;
begin
  FTheme := ATheme;
  if FWebView.WebViewCreated and FEditorReady then
  begin
    LScript := 'if (window.setEditorTheme) { window.setEditorTheme(' + EscapeJsonString(FTheme) + '); }';
    FWebView.ExecuteScript(LScript);
  end;
end;

procedure TFRpMonacoEditorLCL.SetLanguage(const ALang: string);
var
  LScript: string;
begin
  FLanguage := ALang;
  if FWebView.WebViewCreated and FEditorReady then
  begin
    LScript := 'if (window.setEditorLanguage) { window.setEditorLanguage(' + EscapeJsonString(FLanguage) + '); }';
    FWebView.ExecuteScript(LScript);
  end;
end;

procedure TFRpMonacoEditorLCL.ActivateFallback(const AReason: string);
begin
  if FUseFallback then
    Exit;
  LogStatus('Activating plain-text fallback: ' + AReason);
  FUseFallback := True;
  FEditorReady := False;

  FUpdatingFromBrowser := True;
  try
    FMemoFallback.Lines.Text := FSQL;
  finally
    FUpdatingFromBrowser := False;
  end;

  FWebView.Visible := False;
  FMemoFallback.Visible := True;
  FMemoFallback.BringToFront;
end;

end.
