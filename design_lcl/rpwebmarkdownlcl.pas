{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpwebmarkdownlcl                                }
{       Markdown viewer of the AI chats                 }
{       (LCL port of rpwebmarkdownvcl)                  }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpwebmarkdownlcl;

{ TRpWebMarkdownView with the public API of the VCL one (rpwebmarkdownvcl).

  Windows: the same WebMarkdown page (index.html + markdown-it) as the VCL,
  embedded as the WEBMARKDOWN_ZIP resource (WebMarkdownAssets.res at the
  repository root), extracted to the same folder and shown with the LCL
  WebView2 host (rplclwebview, also used by the Monaco editor).

  Elsewhere (Linux: no WebView2), when WebView2 cannot start, or with
  RpWebMarkdownForceNative (RPM_FORCE_WEBVIEW_FALLBACK): a native renderer,
  the TurboPower IPro HTML panel of Lazarus (pure LCL painting, so it works
  with Qt6, GTK2 and win32) fed with the HTML of rpmarkdownlcl. The VCL
  falls back to a plain black memo instead.

  The view always keeps a model of what was shown (messages, log lines and
  keyed log chunks, with the semantics of the JavaScript functions of
  index.html), so a WebView2 failure at any time switches to the native
  renderer without losing content, and tests can read it (PlainText). The
  native HTML is rebuilt from the model, at most once per message loop
  (Application.QueueAsyncCall). }

{$mode delphi}

interface

uses
  SysUtils, Classes, Controls, Graphics, Forms, ExtCtrls, StdCtrls, Menus, Clipbrd,
  Generics.Collections, IpHtml, IpHtmlTypes, rplclwebview, rpmdshfolder,
  rpmarkdownlcl;

const
  AssetsVersion = '5';
  // Oldest blocks are dropped from the native view beyond this count
  RpMarkdownMaxBlocks = 800;

type
  TRpMarkdownBlockKind = (rmbMessage, rmbLogLine, rmbLogActor, rmbLogChunk);

  TRpMarkdownBlock = class
  public
    Kind: TRpMarkdownBlockKind;
    Role: string;
    Raw: string;
    Key: string;
    Streaming: Boolean;
    PrefillPercent: Integer;
    Html: string;
    Dirty: Boolean;
  end;

  TRpWebMarkdownMessageEvent = procedure(Sender: TObject; const AMessage: string) of object;

  TRpWebMarkdownView = class(TCustomPanel)
  private
    FBlocks: TObjectList<TRpMarkdownBlock>;
    // Open keyed log chunks: key -> block (not owned)
    FOpenChunks: TStringList;
    FNative: TIpHtmlPanel;
    FNativeMenu: TPopupMenu;
    FCopyAllButton: TButton;
    FCopiedTimer: TTimer;
    FWebView: TRpLCLWebView;
    FReady: Boolean;
    FWebViewFailed: Boolean;
    FUseFallback: Boolean;
    FFallbackReason: string;
    FPendingCalls: TStringList;
    FAssetRootPath: string;
    FLastNavUrl: string;
    FNavRetryCount: Integer;
    FRetryTimer: TTimer;
    FRenderQueued: Boolean;
    FNativeDirty: Boolean;
    FForceScroll: Boolean;
    FRenderCount: Integer;
    FOnWebMessage: TRpWebMarkdownMessageEvent;
    // Model
    function AddBlock(AKind: TRpMarkdownBlockKind): TRpMarkdownBlock;
    function LastStreamingBlock(const ARole: string): TRpMarkdownBlock;
    function NormalizeKey(const AKey: string): string;
    procedure ModelChanged(AForceScroll: Boolean);
    function BlockHtml(ABlock: TRpMarkdownBlock): string;
    // Native renderer
    procedure EnsureNative;
    procedure QueueRender;
    procedure AsyncRender(Data: PtrInt);
    procedure AsyncScrollToEnd(Data: PtrInt);
    procedure NativeScrollTo(APos: Integer);
    procedure NativeCopyClick(Sender: TObject);
    procedure NativeCopyAllClick(Sender: TObject);
    procedure CopiedTimerTick(Sender: TObject);
    procedure NativeSelectAllClick(Sender: TObject);
    procedure NativeHotClick(Sender: TObject);
    // WebView2
    function EnsureAssetsExtracted: string;
    procedure AsyncInitWebView(Data: PtrInt);
    procedure TryCreateWebView;
    procedure WebViewCreateCompleted(Sender: TObject; AResult: HResult);
    procedure WebViewNavigationCompleted(Sender: TObject; IsSuccess: Boolean);
    procedure WebViewMessageReceived(Sender: TObject; const AMessage: string);
    procedure RetryTimerTick(Sender: TObject);
    procedure ExecuteOrQueue(const AScript: string);
    procedure FlushPendingCalls;
    function GetUsingWebView: Boolean;
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Same API as the VCL TRpWebMarkdownView
    // Append a chat-style message (role: 'user', 'assistant', 'system')
    procedure AppendMessage(const ARole, AMarkdown: string);
    // Append a streaming chunk to the current streaming message
    procedure AppendStreamingChunk(const ARole, AChunk: string; APrefillPercent: Integer);
    // Finish the current streaming message
    procedure FinishStreaming;
    // Append a single log line ("actor: X" lines are shown as a badge)
    procedure AppendLogLine(const AText: string);
    // Append a raw chunk (streaming append without newline)
    procedure AppendLogChunk(const AChunk: string);
    // Append a raw chunk to a keyed log block (one block per progress id)
    procedure AppendLogChunkKey(const AKey, AChunk: string);
    // End the current log chunk block
    procedure EndLogChunk;
    // End a keyed log chunk block
    procedure EndLogChunkKey(const AKey: string);
    procedure ClearAll;
    procedure ScrollToEnd;
    // WebView ready (always True with the native renderer)
    property Ready: Boolean read FReady;

    // LCL additions
    // Switches to the native renderer (WebView2 failure; tests)
    procedure ActivateFallback(const AReason: string = '');
    // Renders the native view now instead of at the next message loop
    procedure FlushRender;
    // HTML document of the native renderer (built from the model)
    function DocumentHtml: string;
    // Raw text of every block, one per line (the "Copy All" of index.html)
    function PlainText: string;
    function BlockCount: Integer;
    function Block(AIndex: Integer): TRpMarkdownBlock;
    property UsingWebView: Boolean read GetUsingWebView;
    property FallbackReason: string read FFallbackReason;
    property NativeView: TIpHtmlPanel read FNative;
    // The "Copy all" button of index.html, over the native view
    property CopyAllButton: TButton read FCopyAllButton;
    property WebView: TRpLCLWebView read FWebView;
    // Times the native view was rendered (tests: coalescing)
    property RenderCount: Integer read FRenderCount;
    // Messages posted by the page (window.chrome.webview.postMessage)
    property OnWebMessage: TRpWebMarkdownMessageEvent read FOnWebMessage write FOnWebMessage;
  end;

var
  // Always use the native renderer (tests; RPM_FORCE_WEBVIEW_FALLBACK)
  RpWebMarkdownForceNative: Boolean = False;

// JavaScript single quoted string content
function EscapeJSString(const S: string): string;

implementation

uses
  zipper, LCLIntf, LCLType, LazUTF8, rpmdconsts
{$IFDEF MSWINDOWS}
  , Windows
{$ENDIF}
  ;

{$IFDEF MSWINDOWS}
// WebMarkdown page (index.html, markdown-it, WebView2Loader.dll) as the
// WEBMARKDOWN_ZIP RCDATA resource, the one used by the VCL viewer
// (WebMarkdownAssets.rc at the repository root). Relative to this unit, with
// the exact case of the file (a case-sensitive file system needs it).
{$R ../WebMarkdownAssets.RES}
{$ENDIF}

function HtmlColor(const AHex: string): TColor;
var
  V: LongInt;
begin
  // '#rrggbb' -> TColor (BGR)
  V := StrToIntDef('$' + Copy(AHex, 2, 6), 0);
  Result := TColor(((V and $FF) shl 16) or (V and $FF00) or ((V shr 16) and $FF));
end;

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
      #13: ;
      #9: Result := Result + '\t';
      #8: Result := Result + '\b';
      #12: Result := Result + '\f';
    else
      if Ord(Ch) < 32 then
        Result := Result + '\u' + IntToHex(Ord(Ch), 4)
      else
        Result := Result + Ch;
    end;
  end;
  // U+2028/U+2029 (UTF-8) end a line inside older JavaScript strings
  Result := StringReplace(Result, #$E2#$80#$A8, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #$E2#$80#$A9, ' ', [rfReplaceAll]);
end;

{ TRpWebMarkdownView }

constructor TRpWebMarkdownView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  Color := HtmlColor(MdClrBody);
  ParentColor := False;
  ParentBackground := False;
  FBlocks := TObjectList<TRpMarkdownBlock>.Create(True);
  FOpenChunks := TStringList.Create;
  FOpenChunks.CaseSensitive := True;
  FPendingCalls := TStringList.Create;
  FReady := False;
{$IFDEF MSWINDOWS}
  FUseFallback := RpWebMarkdownForceNative;
{$ELSE}
  FUseFallback := True;
{$ENDIF}
  if FUseFallback then
  begin
{$IFDEF MSWINDOWS}
    FFallbackReason := 'Native renderer forced';
{$ELSE}
    FFallbackReason := 'WebView2 is only available on Windows';
{$ENDIF}
    FReady := True;
    EnsureNative;
  end
  else
  begin
    FWebView := TRpLCLWebView.Create(Self);
    FWebView.Parent := Self;
    FWebView.Align := alClient;
    FWebView.OnCreateWebViewCompleted := WebViewCreateCompleted;
    FWebView.OnNavigationCompleted := WebViewNavigationCompleted;
    FWebView.OnWebMessageReceived := WebViewMessageReceived;
  end;
end;

destructor TRpWebMarkdownView.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  if FRetryTimer <> nil then
    FRetryTimer.Enabled := False;
  FOpenChunks.Free;
  FBlocks.Free;
  FPendingCalls.Free;
  inherited Destroy;
end;

function TRpWebMarkdownView.GetUsingWebView: Boolean;
begin
  Result := not FUseFallback;
end;

function TRpWebMarkdownView.BlockCount: Integer;
begin
  Result := FBlocks.Count;
end;

function TRpWebMarkdownView.Block(AIndex: Integer): TRpMarkdownBlock;
begin
  Result := FBlocks[AIndex];
end;

{ Model }

function TRpWebMarkdownView.AddBlock(AKind: TRpMarkdownBlockKind): TRpMarkdownBlock;
var
  LIndex: Integer;
begin
  // Keep the native document bounded (the Net Log grows for ever)
  while FBlocks.Count >= RpMarkdownMaxBlocks do
  begin
    LIndex := FOpenChunks.IndexOfObject(FBlocks[0]);
    if LIndex >= 0 then
      FOpenChunks.Delete(LIndex);
    FBlocks.Delete(0);
  end;
  Result := TRpMarkdownBlock.Create;
  Result.Kind := AKind;
  Result.Dirty := True;
  FBlocks.Add(Result);
end;

function TRpWebMarkdownView.LastStreamingBlock(const ARole: string): TRpMarkdownBlock;
begin
  Result := nil;
  if FBlocks.Count = 0 then
    Exit;
  Result := FBlocks[FBlocks.Count - 1];
  if (Result.Kind <> rmbMessage) or (not Result.Streaming) or (Result.Role <> ARole) then
    Result := nil;
end;

function TRpWebMarkdownView.NormalizeKey(const AKey: string): string;
begin
  if AKey = '' then
    Result := '__default__'
  else
    Result := AKey;
end;

procedure TRpWebMarkdownView.ModelChanged(AForceScroll: Boolean);
begin
  if AForceScroll then
    FForceScroll := True;
  if FUseFallback then
    QueueRender;
end;

function TRpWebMarkdownView.BlockHtml(ABlock: TRpMarkdownBlock): string;
var
  LBar, LBg, LTitle, LName, LLower, LPrefill: string;
begin
  case ABlock.Kind of
    rmbMessage:
      begin
        if ABlock.Role = 'user' then
        begin
          LBar := MdClrUser;
          LBg := MdClrSurface;
          LTitle := UTF8UpperCase(TranslateStr(1942, 'You'));
        end
        else if ABlock.Role = 'assistant' then
        begin
          LBar := MdClrAssistant;
          LBg := MdClrBody;
          LTitle := UTF8UpperCase(TranslateStr(1943, 'Assistant'));
        end
        else
        begin
          LBar := MdClrSystem;
          LBg := MdClrDeep;
          // index.html titles every non user message "Assistant"
          LTitle := UTF8UpperCase(TranslateStr(1943, 'Assistant'));
        end;
        LPrefill := '';
        if ABlock.Streaming and (ABlock.PrefillPercent > 0) then
          LPrefill := '<font color="' + MdClrMuted + '"><i>Prefill ' +
            IntToStr(ABlock.PrefillPercent) + '%</i></font><br>';
        // IPro gives the spare width to every cell without a width, and the
        // cells do not inherit the text color: both are explicit
        Result :=
          '<table width="100%" border="0" cellspacing="0" cellpadding="0"><tr>' +
          '<td width="4" bgcolor="' + LBar + '"></td>' +
          '<td width="100%" bgcolor="' + LBg + '">' +
          '<table width="100%" border="0" cellspacing="0" cellpadding="8"><tr><td width="100%">' +
          '<font color="' + LBar + '"><b>' + LTitle + '</b></font><br>' + LPrefill +
          '<font color="' + MdClrText + '">' + RpMarkdownToHtml(ABlock.Raw) + '</font>';
        if ABlock.Streaming then
          Result := Result + '<font color="' + MdClrAssistant + '">&#9611;</font>';
        Result := Result + '</td></tr></table></td></tr></table>' +
          '<table width="100%" border="0" cellspacing="0" cellpadding="0"><tr><td height="8"></td></tr></table>';
      end;
    rmbLogActor:
      begin
        LName := Trim(ABlock.Raw);
        LLower := LowerCase(LName);
        LBar := MdClrSystem;
        if (LLower = 'ai') or (LLower = 'assistant') then
        begin
          LBar := MdClrAssistant;
          LName := 'AI';
        end
        else if (LLower = 'user') or (LLower = 'none') then
        begin
          LBar := MdClrMuted;
          if LLower = 'none' then
            LName := 'Process';
        end;
        Result :=
          '<table border="0" cellspacing="0" cellpadding="0"><tr>' +
          '<td width="3" bgcolor="' + LBar + '"></td>' +
          '<td bgcolor="' + MdClrSurface + '"><table border="0" cellspacing="0" cellpadding="4"><tr><td>' +
          '<font color="' + LBar + '"><b>' + RpHtmlEscape(UpperCase(LName)) + '</b></font>' +
          '</td></tr></table></td></tr></table>';
      end;
  else
    // Log line or log chunk
    Result := '<font color="' + MdClrSubtle + '">' + RpMarkdownToHtml(ABlock.Raw) + '</font>';
  end;
end;

procedure TRpWebMarkdownView.AppendMessage(const ARole, AMarkdown: string);
var
  LBlock: TRpMarkdownBlock;
begin
  LBlock := AddBlock(rmbMessage);
  LBlock.Role := ARole;
  LBlock.Raw := AMarkdown;
  ModelChanged(True);
  if not FUseFallback then
    ExecuteOrQueue('window.appendMessage(''' + EscapeJSString(ARole) + ''', ''' +
      EscapeJSString(AMarkdown) + ''');');
end;

procedure TRpWebMarkdownView.AppendStreamingChunk(const ARole, AChunk: string;
  APrefillPercent: Integer);
var
  LBlock: TRpMarkdownBlock;
begin
  LBlock := LastStreamingBlock(ARole);
  if LBlock = nil then
  begin
    LBlock := AddBlock(rmbMessage);
    LBlock.Role := ARole;
    LBlock.Streaming := True;
  end;
  LBlock.Raw := LBlock.Raw + AChunk;
  if APrefillPercent > 0 then
    LBlock.PrefillPercent := APrefillPercent;
  LBlock.Dirty := True;
  ModelChanged(True);
  // index.html names it appendMessageChunk (the VCL calls a function that
  // does not exist, appendStreamingChunk)
  if not FUseFallback then
    ExecuteOrQueue('window.appendMessageChunk(''' + EscapeJSString(ARole) + ''', ''' +
      EscapeJSString(AChunk) + ''', ' + IntToStr(APrefillPercent) + ');');
end;

procedure TRpWebMarkdownView.FinishStreaming;
var
  LBlock: TRpMarkdownBlock;
begin
  if FBlocks.Count > 0 then
  begin
    LBlock := FBlocks[FBlocks.Count - 1];
    if (LBlock.Kind = rmbMessage) and LBlock.Streaming then
    begin
      LBlock.Streaming := False;
      LBlock.PrefillPercent := 0;
      LBlock.Dirty := True;
      ModelChanged(False);
    end;
  end;
  if not FUseFallback then
    ExecuteOrQueue('window.finishStreaming();');
end;

procedure TRpWebMarkdownView.AppendLogLine(const AText: string);
var
  LBlock: TRpMarkdownBlock;
begin
  if Copy(AText, 1, 7) = 'actor: ' then
  begin
    LBlock := AddBlock(rmbLogActor);
    LBlock.Raw := Trim(Copy(AText, 8, MaxInt));
  end
  else
  begin
    LBlock := AddBlock(rmbLogLine);
    LBlock.Raw := AText;
  end;
  ModelChanged(True);
  if not FUseFallback then
    ExecuteOrQueue('window.appendLogLine(''' + EscapeJSString(AText) + ''');');
end;

procedure TRpWebMarkdownView.AppendLogChunk(const AChunk: string);
begin
  AppendLogChunkKey('', AChunk);
end;

// The same as rpdatahttp.RpReplaceLogKeyPrefix (not used from here: this view
// does not depend on the HTTP unit)
const
  RpReplaceLogKeyPrefix = 'replace:';

procedure TRpWebMarkdownView.AppendLogChunkKey(const AKey, AChunk: string);
var
  LKey: string;
  LBlock: TRpMarkdownBlock;
  LIndex: Integer;
begin
  LKey := NormalizeKey(AKey);
  // A line that is rewritten (the wait in the AI provider's queue): it replaces
  // the last line while that one has the same key, otherwise it is a new line
  if Copy(AKey, 1, Length(RpReplaceLogKeyPrefix)) = RpReplaceLogKeyPrefix then
  begin
    if (FBlocks.Count > 0) and (FBlocks[FBlocks.Count - 1].Kind = rmbLogChunk) and
      (FBlocks[FBlocks.Count - 1].Key = LKey) then
      LBlock := FBlocks[FBlocks.Count - 1]
    else
    begin
      LBlock := AddBlock(rmbLogChunk);
      LBlock.Key := LKey;
    end;
    LBlock.Raw := AChunk;
    LBlock.Dirty := True;
    ModelChanged(True);
    if not FUseFallback then
      ExecuteOrQueue('(function(k,t){var e=messagesEl.lastElementChild;' +
    'if(e&&e.getAttribute(''data-log-key'')===k){e.setAttribute(''data-raw'',t);e.innerHTML=renderMarkdown(t);window.scrollToEnd(true);}' +
    'else{window.appendLogChunkForKey(k,t);window.endLogChunkForKey(k);}})(''' +
    EscapeJSString(AKey) + ''', ''' + EscapeJSString(AChunk) + ''');');
    Exit;
  end;
  LIndex := FOpenChunks.IndexOf(LKey);
  if LIndex >= 0 then
    LBlock := TRpMarkdownBlock(FOpenChunks.Objects[LIndex])
  else
  begin
    LBlock := AddBlock(rmbLogChunk);
    LBlock.Key := LKey;
    FOpenChunks.AddObject(LKey, LBlock);
  end;
  LBlock.Raw := LBlock.Raw + AChunk;
  LBlock.Dirty := True;
  ModelChanged(True);
  if not FUseFallback then
    ExecuteOrQueue('window.appendLogChunkForKey(''' + EscapeJSString(AKey) + ''', ''' +
      EscapeJSString(AChunk) + ''');');
end;

procedure TRpWebMarkdownView.EndLogChunk;
begin
  EndLogChunkKey('');
end;

procedure TRpWebMarkdownView.EndLogChunkKey(const AKey: string);
var
  LIndex: Integer;
begin
  LIndex := FOpenChunks.IndexOf(NormalizeKey(AKey));
  if LIndex >= 0 then
    FOpenChunks.Delete(LIndex);
  if not FUseFallback then
    ExecuteOrQueue('window.endLogChunkForKey(''' + EscapeJSString(AKey) + ''');');
end;

procedure TRpWebMarkdownView.ClearAll;
begin
  FOpenChunks.Clear;
  FBlocks.Clear;
  ModelChanged(False);
  if not FUseFallback then
    ExecuteOrQueue('window.clearAll();');
end;

procedure TRpWebMarkdownView.ScrollToEnd;
begin
  if FUseFallback then
  begin
    FForceScroll := True;
    if FNativeDirty or FRenderQueued then
      Exit;
    NativeScrollTo(MaxInt);
    Exit;
  end;
  ExecuteOrQueue('window.scrollToEnd();');
end;

function TRpWebMarkdownView.PlainText: string;
var
  LBlock: TRpMarkdownBlock;
begin
  Result := '';
  for LBlock in FBlocks do
  begin
    if Result <> '' then
      Result := Result + LineEnding;
    Result := Result + LBlock.Raw;
  end;
end;

{ Native renderer }

procedure TRpWebMarkdownView.EnsureNative;
var
  LItem: TMenuItem;
begin
  if FNative <> nil then
    Exit;
  FNative := TIpHtmlPanel.Create(Self);
  FNative.Parent := Self;
  FNative.Align := alClient;
  FNative.BgColor := HtmlColor(MdClrBody);
  FNative.TextColor := HtmlColor(MdClrText);
  FNative.LinkColor := HtmlColor(MdClrLink);
  FNative.VLinkColor := HtmlColor(MdClrLink);
  FNative.ALinkColor := HtmlColor(MdClrLink);
  FNative.MarginWidth := 8;
  FNative.MarginHeight := 8;
  // A sans serif UI font (IPro defaults to Times New Roman); fontconfig
  // resolves "Sans" and "Monospace" on Linux
{$IFDEF MSWINDOWS}
  FNative.DefaultTypeFace := 'Segoe UI';
  FNative.FixedTypeface := 'Consolas';
{$ELSE}
  FNative.DefaultTypeFace := 'Sans';
  FNative.FixedTypeface := 'Monospace';
{$ENDIF}
  FNative.DefaultFontSize := 10;
  FNative.OnHotClick := NativeHotClick;
  FNativeMenu := TPopupMenu.Create(Self);
  LItem := TMenuItem.Create(FNativeMenu);
  LItem.Caption := TranslateStr(10, 'Copy');
  LItem.OnClick := NativeCopyClick;
  FNativeMenu.Items.Add(LItem);
  LItem := TMenuItem.Create(FNativeMenu);
  LItem.Caption := TranslateStr(1940, 'Copy all');
  LItem.OnClick := NativeCopyAllClick;
  FNativeMenu.Items.Add(LItem);
  LItem := TMenuItem.Create(FNativeMenu);
  LItem.Caption := TranslateStr(1445, 'Select all');
  LItem.OnClick := NativeSelectAllClick;
  FNativeMenu.Items.Add(LItem);
  FNative.PopupMenu := FNativeMenu;
  // The floating button of index.html: top right, clear of the scroll bar
  FCopyAllButton := TButton.Create(Self);
  FCopyAllButton.Caption := TranslateStr(1940, 'Copy all');
  FCopyAllButton.AutoSize := True;
  FCopyAllButton.TabStop := False;
  FCopyAllButton.AnchorSide[akTop].Control := Self;
  FCopyAllButton.AnchorSide[akTop].Side := asrTop;
  FCopyAllButton.AnchorSide[akRight].Control := Self;
  FCopyAllButton.AnchorSide[akRight].Side := asrRight;
  FCopyAllButton.Anchors := [akTop, akRight];
  FCopyAllButton.BorderSpacing.Top := 8;
  FCopyAllButton.BorderSpacing.Right := GetSystemMetrics(SM_CXVSCROLL) + 8;
  FCopyAllButton.OnClick := NativeCopyAllClick;
  FCopyAllButton.Parent := Self;
  FCopyAllButton.BringToFront;
  FCopiedTimer := TTimer.Create(Self);
  FCopiedTimer.Enabled := False;
  FCopiedTimer.Interval := 2000;
  FCopiedTimer.OnTimer := CopiedTimerTick;
  FNativeDirty := True;
  QueueRender;
end;

function TRpWebMarkdownView.DocumentHtml: string;
var
  LBlock: TRpMarkdownBlock;
begin
  Result := '<html><head><meta http-equiv="content-type" content="text/html; charset=utf-8">' +
    RpMarkdownStyleSheet + '</head><body bgcolor="' + MdClrBody + '" text="' + MdClrText +
    '" link="' + MdClrLink + '" vlink="' + MdClrLink + '">';
  for LBlock in FBlocks do
  begin
    if LBlock.Dirty then
    begin
      LBlock.Html := BlockHtml(LBlock);
      LBlock.Dirty := False;
    end;
    Result := Result + LBlock.Html;
  end;
  Result := Result + '</body></html>';
end;

procedure TRpWebMarkdownView.QueueRender;
begin
  FNativeDirty := True;
  if FRenderQueued or (csDestroying in ComponentState) then
    Exit;
  FRenderQueued := True;
  Application.QueueAsyncCall(AsyncRender, 0);
end;

procedure TRpWebMarkdownView.AsyncRender(Data: PtrInt);
begin
  FRenderQueued := False;
  if csDestroying in ComponentState then
    Exit;
  FlushRender;
end;

procedure TRpWebMarkdownView.FlushRender;
var
  LAtEnd: Boolean;
  LPos: Integer;
begin
  if (not FUseFallback) or (FNative = nil) then
    Exit;
  if not FNativeDirty then
    Exit;
  FNativeDirty := False;
  LPos := FNative.VScrollPos;
  LAtEnd := FForceScroll or
    (LPos + FNative.ClientHeight >= FNative.GetContentSize.cy - 100);
  FForceScroll := False;
  FNative.SetHtmlFromStr(DocumentHtml);
  Inc(FRenderCount);
  if LAtEnd then
  begin
    NativeScrollTo(MaxInt);
    // Once more when the scroll bars have settled (the width may change)
    Application.QueueAsyncCall(AsyncScrollToEnd, 0);
  end
  else
    // Reading further up: the same place of the new document
    NativeScrollTo(LPos);
end;

procedure TRpWebMarkdownView.AsyncScrollToEnd(Data: PtrInt);
begin
  if not (csDestroying in ComponentState) then
    NativeScrollTo(MaxInt);
end;

type
  TIpHtmlFrameAccess = class(TIpHtmlFrame);

procedure TRpWebMarkdownView.NativeScrollTo(APos: Integer);
var
  LPanel: TIpHtmlInternalPanel;
  LPageRect: TRect;
begin
  if (FNative = nil) or not FNative.HandleAllocated or (FNative.MasterFrame = nil) then
    Exit;
  LPanel := TIpHtmlFrameAccess(FNative.MasterFrame).HyperPanel;
  if LPanel = nil then
    Exit;
  // SetHtmlFromStr makes a new document, laid out at its first paint: until
  // then it has no height, the scroll range is 0 and the view stays at the
  // top. Its PageRect lays it out now (and sets the scroll range).
  LPageRect := LPanel.PageRect;
  if LPageRect.Bottom > 0 then
    FNative.VScrollPos := APos; // clamped to the range: MaxInt is the end
end;

procedure TRpWebMarkdownView.NativeCopyClick(Sender: TObject);
begin
  if FNative = nil then
    Exit;
  if FNative.HaveSelection then
    FNative.CopyToClipboard
  else
    Clipboard.AsText := PlainText;
end;

procedure TRpWebMarkdownView.NativeCopyAllClick(Sender: TObject);
begin
  // The raw text of every block, as copyLogToClipboard of index.html
  Clipboard.AsText := PlainText;
  if FCopyAllButton <> nil then
  begin
    FCopyAllButton.Caption := TranslateStr(1941, 'Copied!');
    FCopiedTimer.Enabled := False;
    FCopiedTimer.Enabled := True;
  end;
end;

procedure TRpWebMarkdownView.CopiedTimerTick(Sender: TObject);
begin
  FCopiedTimer.Enabled := False;
  if FCopyAllButton <> nil then
    FCopyAllButton.Caption := TranslateStr(1940, 'Copy all');
end;

procedure TRpWebMarkdownView.NativeSelectAllClick(Sender: TObject);
begin
  if FNative <> nil then
    FNative.SelectAll;
end;

procedure TRpWebMarkdownView.NativeHotClick(Sender: TObject);
var
  LUrl: string;
begin
  // Links open in the browser, never inside the viewer
  if FNative = nil then
    Exit;
  LUrl := FNative.HotURL;
  if (Pos('http://', LowerCase(LUrl)) = 1) or (Pos('https://', LowerCase(LUrl)) = 1) or
    (Pos('mailto:', LowerCase(LUrl)) = 1) then
    OpenURL(LUrl);
end;

procedure TRpWebMarkdownView.ActivateFallback(const AReason: string);
begin
  if FUseFallback then
    Exit;
  FUseFallback := True;
  FWebViewFailed := True;
  FFallbackReason := AReason;
  FPendingCalls.Clear;
  if FRetryTimer <> nil then
    FRetryTimer.Enabled := False;
  if FWebView <> nil then
    FWebView.Visible := False;
  FReady := True;
  EnsureNative;
  FNative.BringToFront;
  FForceScroll := True;
  QueueRender;
end;

{ WebView2 }

procedure TRpWebMarkdownView.CreateWnd;
begin
  inherited CreateWnd;
  if FUseFallback or FWebViewFailed then
    Exit;
  Application.QueueAsyncCall(AsyncInitWebView, 0);
end;

procedure TRpWebMarkdownView.AsyncInitWebView(Data: PtrInt);
begin
  if not (csDestroying in ComponentState) then
    TryCreateWebView;
end;

function TRpWebMarkdownView.EnsureAssetsExtracted: string;
var
  LBasePath, LVersionPath, LZipFound, LTempZip: string;
  LList: TStringList;
  LUnZipper: TUnZipper;
{$IFDEF MSWINDOWS}
  LResStream: TResourceStream;
  LFileStream: TFileStream;
{$ENDIF}
begin
  // Same folder and version file as the VCL viewer: both designers share it
  LBasePath := ObtainFolderLocalUserConfig('Reportman', 'WebMarkdown', 'WebMarkdown');
  LVersionPath := LBasePath + DirectorySeparator + 'assets.version';
  if FileExists(LBasePath + DirectorySeparator + 'index.html') and FileExists(LVersionPath) then
  begin
    LList := TStringList.Create;
    try
      LList.LoadFromFile(LVersionPath);
      if SameText(Trim(LList.Text), AssetsVersion) then
        Exit(LBasePath);
    finally
      LList.Free;
    end;
  end;

  LZipFound := '';
  LTempZip := '';
{$IFDEF MSWINDOWS}
  if FindResource(HInstance, 'WEBMARKDOWN_ZIP', RT_RCDATA) <> 0 then
  begin
    ForceDirectories(LBasePath);
    LTempZip := LBasePath + DirectorySeparator + 'WebMarkdown.zip.tmp';
    LResStream := TResourceStream.Create(HInstance, 'WEBMARKDOWN_ZIP', RT_RCDATA);
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
  if (LZipFound = '') and FileExists(ExtractFilePath(ParamStr(0)) + 'WebMarkdown.zip') then
    LZipFound := ExtractFilePath(ParamStr(0)) + 'WebMarkdown.zip';
  if LZipFound = '' then
    raise Exception.Create('WebMarkdown assets not found');

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
  LList := TStringList.Create;
  try
    LList.Text := AssetsVersion;
    LList.SaveToFile(LVersionPath);
  finally
    LList.Free;
  end;
  Result := LBasePath;
end;

procedure TRpWebMarkdownView.TryCreateWebView;
var
  LDll: string;
begin
  if FUseFallback or (FWebView = nil) or FWebView.WebViewCreated or
    FWebView.WebViewCreating then
    Exit;
  try
    if FAssetRootPath = '' then
      FAssetRootPath := EnsureAssetsExtracted;
    FWebView.UserDataFolder := ObtainFolderLocalUserConfig('Reportman', 'WebMarkdown', '') +
      DirectorySeparator + 'EdgeData';
{$IFDEF CPU64}
    LDll := FAssetRootPath + DirectorySeparator + 'x64' + DirectorySeparator + 'WebView2Loader.dll';
{$ELSE}
    LDll := FAssetRootPath + DirectorySeparator + 'x86' + DirectorySeparator + 'WebView2Loader.dll';
{$ENDIF}
    if FileExists(LDll) then
      FWebView.LoaderDllPath := LDll;
    if not FWebView.CreateWebView then
      ActivateFallback('WebView2 initialization failed');
  except
    on E: Exception do
      ActivateFallback('CreateWebView exception: ' + E.Message);
  end;
end;

procedure TRpWebMarkdownView.WebViewCreateCompleted(Sender: TObject; AResult: HResult);
var
  LUrl: string;
begin
  if AResult >= 0 then
  begin
    LUrl := 'file:///' + StringReplace(FAssetRootPath, '\', '/', [rfReplaceAll]);
    if (LUrl <> '') and (LUrl[Length(LUrl)] <> '/') then
      LUrl := LUrl + '/';
    LUrl := LUrl + 'index.html';
    FLastNavUrl := LUrl;
    FNavRetryCount := 0;
    FWebView.Navigate(LUrl);
  end
  else
    ActivateFallback('CreateWebViewCompleted HRESULT: ' + IntToHex(AResult, 8));
end;

// index.html writes its labels in English (the copy button, the message titles
// and the thinking blocks): the script puts the designer's translations in
// their place, also in the messages added later (as the C# designer)
function LocalizationScript: string;

  function Q(const S: string): string;
  begin
    Result := '''' + EscapeJSString(S) + '''';
  end;

begin
  Result :=
    '(function (L) {' +
    ' var btn = document.getElementById(''copy-btn'');' +
    ' if (btn && btn.lastChild) btn.lastChild.textContent = '' '' + L.copyAll;' +
    ' window.showCopySuccess = function (b) {' +
    '  var span = b.querySelector(''span''); var icon = span.textContent;' +
    '  var text = b.lastChild.textContent;' +
    '  span.textContent = ''\u2705''; b.lastChild.textContent = '' '' + L.copied;' +
    '  b.classList.add(''copy-success'');' +
    '  setTimeout(function () { span.textContent = icon;' +
    '   b.lastChild.textContent = text; b.classList.remove(''copy-success''); }, 2000);' +
    ' };' +
    ' function translate(node) {' +
    '  if (!node || node.nodeType !== 1) return;' +
    '  var titles = node.querySelectorAll(''.msg-header > span:last-child'');' +
    '  for (var i = 0; i < titles.length; i++) {' +
    '   var title = titles[i].textContent;' +
    '   if ((title === ''You'' || title === ''Assistant'') && L[title] !== title)' +
    '    titles[i].textContent = L[title];' +
    '  }' +
    '  var thinking = node.querySelectorAll(''details.think-block > summary'');' +
    '  for (var j = 0; j < thinking.length; j++) {' +
    '   var summary = thinking[j].textContent;' +
    '   if (summary.indexOf(''Thinking...'') >= 0 && L.thinking !== ''Thinking...'')' +
    '    thinking[j].textContent = summary.replace(''Thinking...'', L.thinking);' +
    '  }' +
    ' }' +
    ' var messages = document.getElementById(''messages'');' +
    ' if (!messages) return;' +
    ' translate(messages);' +
    ' new MutationObserver(function (records) {' +
    '  for (var r = 0; r < records.length; r++)' +
    '   for (var k = 0; k < records[r].addedNodes.length; k++)' +
    '    translate(records[r].addedNodes[k]);' +
    ' }).observe(messages, { childList: true, subtree: true });' +
    '})({copyAll: ' + Q(TranslateStr(1940, 'Copy all')) +
    ', copied: ' + Q(TranslateStr(1941, 'Copied!')) +
    ', You: ' + Q(TranslateStr(1942, 'You')) +
    ', Assistant: ' + Q(TranslateStr(1943, 'Assistant')) +
    ', thinking: ' + Q(TranslateStr(1944, 'Thinking...')) + '});';
end;

procedure TRpWebMarkdownView.WebViewNavigationCompleted(Sender: TObject; IsSuccess: Boolean);
const
  MaxRetries = 3;
begin
  if FUseFallback then
    Exit;
  if IsSuccess then
  begin
    FReady := True;
    FNavRetryCount := 0;
    FWebView.ExecuteScript(LocalizationScript);
    FlushPendingCalls;
    Exit;
  end;
  // Interrupted navigations (the parent window recreated while loading)
  // are retried, as in the VCL viewer
  if (FNavRetryCount < MaxRetries) and (FLastNavUrl <> '') then
  begin
    Inc(FNavRetryCount);
    if FRetryTimer = nil then
    begin
      FRetryTimer := TTimer.Create(Self);
      FRetryTimer.OnTimer := RetryTimerTick;
    end;
    FRetryTimer.Enabled := False;
    FRetryTimer.Interval := 200 * FNavRetryCount;
    FRetryTimer.Enabled := True;
    Exit;
  end;
  ActivateFallback('Navigation failed');
end;

procedure TRpWebMarkdownView.RetryTimerTick(Sender: TObject);
begin
  FRetryTimer.Enabled := False;
  if FUseFallback then
    Exit;
  if (FWebView <> nil) and FWebView.WebViewCreated and (FLastNavUrl <> '') then
    FWebView.Navigate(FLastNavUrl);
end;

procedure TRpWebMarkdownView.WebViewMessageReceived(Sender: TObject; const AMessage: string);
begin
  if Assigned(FOnWebMessage) then
    FOnWebMessage(Self, AMessage);
end;

procedure TRpWebMarkdownView.ExecuteOrQueue(const AScript: string);
begin
  if FUseFallback then
    Exit;
  if FReady and (FWebView <> nil) and FWebView.WebViewCreated then
    FWebView.ExecuteScript(AScript)
  else
    FPendingCalls.Add(AScript);
end;

procedure TRpWebMarkdownView.FlushPendingCalls;
var
  I: Integer;
begin
  if FUseFallback then
  begin
    FPendingCalls.Clear;
    Exit;
  end;
  if FReady and (FWebView <> nil) and FWebView.WebViewCreated then
  begin
    for I := 0 to FPendingCalls.Count - 1 do
      FWebView.ExecuteScript(FPendingCalls[I]);
    FPendingCalls.Clear;
  end;
end;

initialization
  RpWebMarkdownForceNative := SysUtils.GetEnvironmentVariable('RPM_FORCE_WEBVIEW_FALLBACK') <> '';
end.
