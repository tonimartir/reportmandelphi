{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rplclwebview.pas                                }
{       LCL Visual Control for Microsoft WebView2       }
{       (Windows) and WKWebView (macOS, LCL Cocoa)      }
{       Compatibility unit for Free Pascal / LCL        }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rplclwebview;

{ One API for the pages of the designer (Monaco) on two browsers:
  - Windows: WebView2, created asynchronously (rpwebview2).
  - macOS with LCL Cocoa (RPWEBKIT): the WKWebView of the system, a subview
    of the control's content view, created synchronously. A user script at
    document start provides window.chrome.webview (postMessage and the
    "message" event) on top of a WebKit script message handler, so the pages
    written for WebView2 run unchanged.
  Elsewhere there is no browser: CreateWebView reports E_NOTIMPL and the
  callers use their native fallback. }

{$mode delphi}
{$IF DEFINED(DARWIN) AND DEFINED(LCLCocoa)}
  {$DEFINE RPWEBKIT}
  {$modeswitch objectivec1}
{$IFEND}

interface

uses
  Classes, SysUtils, Controls, Graphics, Forms, LMessages, LCLType
  {$IFDEF MSWINDOWS}
  , Windows, ActiveX, rpwebview2
  {$ENDIF}
  ;

type
  TCreateWebViewCompletedEvent = procedure(Sender: TObject; AResult: HResult) of object;
  TNavigationCompletedEvent = procedure(Sender: TObject; IsSuccess: Boolean) of object;
  TWebMessageReceivedEvent = procedure(Sender: TObject; const AMessage: string) of object;

  TRpLCLWebView = class(TCustomControl)
  private
    FUserDataFolder: string;
    FLoaderDllPath: string;
    FWebViewCreated: Boolean;
    FWebViewCreating: Boolean;
    FIsDestroying: Boolean;
    FPendingUrl: string;
    FOnCreateWebViewCompleted: TCreateWebViewCompletedEvent;
    FOnNavigationCompleted: TNavigationCompletedEvent;
    FOnWebMessageReceived: TWebMessageReceivedEvent;
{$IFDEF MSWINDOWS}
    FEnvironment: ICoreWebView2Environment;
    FController: ICoreWebView2Controller;
    FWebView: ICoreWebView2;
    FNavCompletedToken: EventRegistrationToken;
    FWebMsgReceivedToken: EventRegistrationToken;
    FEnvHandler: ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler;
    FCtrlHandler: ICoreWebView2CreateCoreWebView2ControllerCompletedHandler;
    FNavCompletedHandler: ICoreWebView2NavigationCompletedEventHandler;
    FWebMsgReceivedHandler: ICoreWebView2WebMessageReceivedEventHandler;
    // Handler objects (not owned); WebView2 may call them after the control
    // is gone, so CloseWebView disconnects them
    FHandlerObjects: TList;
    // The window handle was destroyed with the browser alive: it waits in
    // the parking window until CreateWnd gives it the new handle
    FParked: Boolean;
    procedure DetachHandlers;
    procedure UpdateWebViewBounds;
    procedure DoEnvironmentCreated(errorCode: HResult; const AEnv: ICoreWebView2Environment);
    procedure DoControllerCreated(errorCode: HResult; const AController: ICoreWebView2Controller);
    procedure DoNavigationCompleted(const ASender: ICoreWebView2; const AArgs: ICoreWebView2NavigationCompletedEventArgs);
    procedure DoWebMessageReceived(const ASender: ICoreWebView2; const AArgs: ICoreWebView2WebMessageReceivedEventArgs);
{$ENDIF}
{$IFDEF RPWEBKIT}
    // Objective-C types stay out of the interface: a unit that is not in
    // Objective-C mode and loads one with them stops FPC 3.2.2 with an
    // internal error (200609171)
    FWKView: Pointer;   // WKWebView
    FWKHost: Pointer;   // TRpWKHost: script message handler and navigation delegate
    procedure UpdateWebViewBounds;
{$ENDIF}
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure Resize; override;
    procedure VisibleChanged; override;
    procedure WMWindowPosChanged(var Message: TLMWindowPosChanged); message LM_WINDOWPOSCHANGED;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // False where this build has no browser at all (CreateWebView would only
    // report E_NOTIMPL); True does not mean the runtime is installed
    class function Supported: Boolean;
    function CreateWebView: Boolean;
    procedure CloseWebView;
    function Navigate(const AUrl: string): Boolean;
    function NavigateToString(const AHtml: string): Boolean;
    function ExecuteScript(const AScript: string): Boolean;
    function PostWebMessageAsString(const AMessage: string): Boolean;
    function PostWebMessageAsJson(const AJson: string): Boolean;
    // PNG of what the page shows (ICoreWebView2.CapturePreview, WKWebView
    // takeSnapshot), waiting up to ATimeoutMs while processing messages.
    // Works without a visible desktop (tests, screenshots); False where
    // there is no browser.
    function CapturePreviewPng(AStream: TStream; ATimeoutMs: Cardinal = 10000): Boolean;

    property WebViewCreated: Boolean read FWebViewCreated;
    property WebViewCreating: Boolean read FWebViewCreating;
    property UserDataFolder: string read FUserDataFolder write FUserDataFolder;
    property LoaderDllPath: string read FLoaderDllPath write FLoaderDllPath;
    property OnCreateWebViewCompleted: TCreateWebViewCompletedEvent read FOnCreateWebViewCompleted write FOnCreateWebViewCompleted;
    property OnNavigationCompleted: TNavigationCompletedEvent read FOnNavigationCompleted write FOnNavigationCompleted;
    property OnWebMessageReceived: TWebMessageReceivedEvent read FOnWebMessageReceived write FOnWebMessageReceived;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
    property TabStop;
    property TabOrder;
  end;

implementation

{$IFDEF RPWEBKIT}
uses
  CocoaAll;
{$ENDIF}

{$IFDEF MSWINDOWS}

type
  // WebView2 keeps its references to the handlers and may call them after
  // the control is destroyed (a form closed while WebView2 starts): the
  // control clears FControl in CloseWebView (DetachHandlers)
  TRpWebViewHandler = class(TInterfacedObject)
  public
    FControl: TRpLCLWebView;
    constructor Create(AControl: TRpLCLWebView);
    destructor Destroy; override;
  end;

  TCreateEnvHandler = class(TRpWebViewHandler, ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler)
  public
    function Invoke(errorCode: HResult; const created_environment: ICoreWebView2Environment): HResult; stdcall;
  end;

  TCreateControllerHandler = class(TRpWebViewHandler, ICoreWebView2CreateCoreWebView2ControllerCompletedHandler)
  public
    function Invoke(errorCode: HResult; const createdController: ICoreWebView2Controller): HResult; stdcall;
  end;

  TNavCompletedHandler = class(TRpWebViewHandler, ICoreWebView2NavigationCompletedEventHandler)
  public
    function Invoke(const sender: ICoreWebView2; const args: ICoreWebView2NavigationCompletedEventArgs): HResult; stdcall;
  end;

  TWebMsgReceivedHandler = class(TRpWebViewHandler, ICoreWebView2WebMessageReceivedEventHandler)
  public
    function Invoke(const sender: ICoreWebView2; const args: ICoreWebView2WebMessageReceivedEventArgs): HResult; stdcall;
  end;

  ICoreWebView2CapturePreviewCompletedHandler = interface(IUnknown)
    ['{697E05E9-3D8F-45FA-96F4-8FFE1EDEDAF5}']
    function Invoke(errorCode: HResult): HResult; stdcall;
  end;

  TCapturePreviewHandler = class(TRpWebViewHandler, ICoreWebView2CapturePreviewCompletedHandler)
  public
    Done: Boolean;
    Error: HResult;
    function Invoke(errorCode: HResult): HResult; stdcall;
  end;

{ TCapturePreviewHandler }

function TCapturePreviewHandler.Invoke(errorCode: HResult): HResult; stdcall;
begin
  Result := S_OK;
  Error := errorCode;
  Done := True;
end;

{ TRpWebViewHandler }

var
  GParkingWindow: HWND = 0;

// A hidden window of the process for the browsers whose control has no
// handle for a moment (TRpLCLWebView.DestroyWnd)
function ParkingWindow: HWND;
begin
  if (GParkingWindow = 0) or not IsWindow(GParkingWindow) then
    GParkingWindow := CreateWindowExW(0, 'STATIC', 'RpWebViewParking', WS_POPUP,
      0, 0, 0, 0, 0, 0, HInstance, nil);
  Result := GParkingWindow;
end;

constructor TRpWebViewHandler.Create(AControl: TRpLCLWebView);
begin
  inherited Create;
  FControl := AControl;
  if AControl <> nil then
    AControl.FHandlerObjects.Add(Self);
end;

destructor TRpWebViewHandler.Destroy;
begin
  // Released by WebView2 while the control lives (a replaced handler)
  if FControl <> nil then
    FControl.FHandlerObjects.Remove(Self);
  inherited Destroy;
end;

{ TCreateEnvHandler }

function TCreateEnvHandler.Invoke(errorCode: HResult; const created_environment: ICoreWebView2Environment): HResult; stdcall;
begin
  Result := S_OK;
  if (FControl <> nil) and (not FControl.FIsDestroying) then
    FControl.DoEnvironmentCreated(errorCode, created_environment);
end;

{ TCreateControllerHandler }

function TCreateControllerHandler.Invoke(errorCode: HResult; const createdController: ICoreWebView2Controller): HResult; stdcall;
begin
  Result := S_OK;
  if (FControl <> nil) and (not FControl.FIsDestroying) then
    FControl.DoControllerCreated(errorCode, createdController);
end;

{ TNavCompletedHandler }

function TNavCompletedHandler.Invoke(const sender: ICoreWebView2; const args: ICoreWebView2NavigationCompletedEventArgs): HResult; stdcall;
begin
  Result := S_OK;
  if (FControl <> nil) and (not FControl.FIsDestroying) then
    FControl.DoNavigationCompleted(sender, args);
end;

{ TWebMsgReceivedHandler }

function TWebMsgReceivedHandler.Invoke(const sender: ICoreWebView2; const args: ICoreWebView2WebMessageReceivedEventArgs): HResult; stdcall;
begin
  Result := S_OK;
  if (FControl <> nil) and (not FControl.FIsDestroying) then
    FControl.DoWebMessageReceived(sender, args);
end;

{$ENDIF}

{$IFDEF RPWEBKIT}

{$linkframework WebKit}

const
  WKUserScriptInjectionTimeAtDocumentStart = 0;
  CRpWKHandlerName = 'rpHost';
  NSURLErrorCancelled = -999;

  // window.chrome.webview of WebView2 on top of the WebKit message handler
  CRpWKBridgeScript =
    '(function () {' +
    ' if (window.chrome && window.chrome.webview) { return; }' +
    ' var listeners = [];' +
    ' window.chrome = window.chrome || {};' +
    ' window.chrome.webview = {' +
    '  postMessage: function (m) {' +
    '   window.webkit.messageHandlers.' + CRpWKHandlerName + '.postMessage(' +
    '    typeof m === "string" ? m : JSON.stringify(m)); },' +
    '  addEventListener: function (t, f) { if (t === "message") { listeners.push(f); } },' +
    '  removeEventListener: function (t, f) {' +
    '   var i = listeners.indexOf(f); if (i >= 0) { listeners.splice(i, 1); } }' +
    ' };' +
    ' window.rpWebViewDispatch = function (d) {' +
    '  listeners.slice().forEach(function (f) { try { f({ data: d }); } catch (e) {} });' +
    ' };' +
    '})();';

type
  // The part of WebKit used here, declared here instead of using the whole
  // WebKit unit of FPC's cocoaint
  WKUserScript = objcclass external (NSObject)
  public
    function initWithSource_injectionTime_forMainFrameOnly(source: NSString;
      injectionTime: NSInteger; forMainFrameOnly: ObjCBOOL): id;
      message 'initWithSource:injectionTime:forMainFrameOnly:';
  end;

  WKUserContentController = objcclass external (NSObject)
  public
    procedure addUserScript(userScript: WKUserScript); message 'addUserScript:';
    procedure addScriptMessageHandler_name(scriptMessageHandler: id; name: NSString);
      message 'addScriptMessageHandler:name:';
    procedure removeScriptMessageHandlerForName(name: NSString);
      message 'removeScriptMessageHandlerForName:';
  end;

  WKWebViewConfiguration = objcclass external (NSObject)
  public
    function userContentController: WKUserContentController; message 'userContentController';
    function preferences: NSObject; message 'preferences';
  end;

  WKScriptMessage = objcclass external (NSObject)
  public
    function body: id; message 'body';
  end;

  // A block literal as the Apple ABI lays it out. The one block needed is a
  // global block (no captured variables), simple to build by hand instead of
  // depending on the cblocks support of FPC 3.2.2.
  TRpBlockDescriptor = record
    Reserved: PtrUInt;
    Size: PtrUInt;
  end;

  TRpBlockLiteral = record
    Isa: Pointer;
    Flags: Integer;
    Reserved: Integer;
    Invoke: Pointer;
    Descriptor: ^TRpBlockDescriptor;
  end;

  WKWebView = objcclass external (NSView)
  public
    function initWithFrame_configuration(frame: NSRect;
      configuration: WKWebViewConfiguration): id; message 'initWithFrame:configuration:';
    procedure setNavigationDelegate(navigationDelegate: id); message 'setNavigationDelegate:';
    function loadRequest(request: NSURLRequest): id; message 'loadRequest:';
    function loadFileURL_allowingReadAccessToURL(URL: NSURL; readAccessURL: NSURL): id;
      message 'loadFileURL:allowingReadAccessToURL:';
    function loadHTMLString_baseURL(htmlString: NSString; baseURL: NSURL): id;
      message 'loadHTMLString:baseURL:';
    // The completion handler is a block; nil when the result is not needed
    procedure evaluateJavaScript_completionHandler(javaScriptString: NSString;
      completionHandler: Pointer); message 'evaluateJavaScript:completionHandler:';
    procedure takeSnapshotWithConfiguration_completionHandler(snapshotConfiguration: id;
      completionHandler: Pointer);
      message 'takeSnapshotWithConfiguration:completionHandler:';
    procedure stopLoading; message 'stopLoading';
  end;

  // The edit commands of the keyboard: LCL Cocoa sends Cmd+C/X/V to the
  // first responder only when it is an NSTextView, and the main menu of an
  // LCL application has no native Edit menu, so the page would not get them
  TRpWKWebView = objcclass(WKWebView)
  public
    function performKeyEquivalent(event: NSEvent): ObjCBOOL; override;
  end;

  // Receives the page messages (WKScriptMessageHandler) and the navigation
  // events (WKNavigationDelegate) for one TRpLCLWebView. WebKit retains it
  // as message handler: CloseWebView removes it and clears FControl.
  TRpWKHost = objcclass(NSObject)
  public
    FControl: TRpLCLWebView;
    procedure userContentController_didReceiveScriptMessage(controller: id;
      message_: WKScriptMessage); message 'userContentController:didReceiveScriptMessage:';
    procedure webView_didFinishNavigation(webView: id; navigation: id);
      message 'webView:didFinishNavigation:';
    procedure webView_didFailNavigation_withError(webView: id; navigation: id;
      error: NSError); message 'webView:didFailNavigation:withError:';
    procedure webView_didFailProvisionalNavigation_withError(webView: id;
      navigation: id; error: NSError);
      message 'webView:didFailProvisionalNavigation:withError:';
    procedure webViewWebContentProcessDidTerminate(webView: id);
      message 'webViewWebContentProcessDidTerminate:';
  end;

function RpNSStr(const S: string): NSString;
begin
  Result := NSString.stringWithUTF8String(PAnsiChar(S));
end;

function RpStrFromNS(S: NSString): string;
begin
  if S = nil then
    Result := ''
  else
    Result := string(PAnsiChar(S.UTF8String));
end;

// JavaScript string literal (JSON) of an UTF-8 string
function RpJsString(const S: string): string;
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
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
      #9: Result := Result + '\t';
      #0..#8, #11, #12, #14..#31:
        Result := Result + '\u' + IntToHex(Ord(C), 4);
    else
      Result := Result + C;
    end;
  end;
  // U+2028 and U+2029 end a line in older JavaScript parsers
  Result := StringReplace(Result, #$E2#$80#$A8, '\u2028', [rfReplaceAll]);
  Result := StringReplace(Result, #$E2#$80#$A9, '\u2029', [rfReplaceAll]);
  Result := Result + '"';
end;

// Path of a file: URL as the editors build them (file:///C:/..., or
// file:////Users/... joining 'file:///' and an absolute path)
function RpFileUrlToPath(const AUrl: string): string;
begin
  Result := Copy(AUrl, 6, MaxInt);
  while Copy(Result, 1, 2) = '//' do
    Delete(Result, 1, 1);
  if Pos('%', Result) > 0 then
    Result := RpStrFromNS(RpNSStr(Result).stringByRemovingPercentEncoding);
end;

// The view LCL Cocoa puts the children of a control in: the handle of a
// TCustomControl is a scroll host around it
function RpContentViewOf(AHandle: HWND): NSView;
var
  LSel: SEL;
begin
  Result := NSView(AHandle);
  LSel := objcselector('lclContentView');
  if (Result <> nil) and Result.respondsToSelector(LSel) then
    Result := NSView(Result.performSelector(LSel));
end;

const
  BLOCK_IS_GLOBAL = 1 shl 28;

  // dlsym's handle for "every image loaded in the process"
  RTLD_DEFAULT = Pointer(-2);

function dlsym(AHandle: Pointer; ASymbol: PAnsiChar): Pointer; cdecl; external 'c';

var
  // takeSnapshot answers with a block without captures: one capture at a
  // time, its result in these variables
  GRpSnapshotDone: Boolean;
  GRpSnapshotPng: NSData;
  GRpSnapshotDescriptor: TRpBlockDescriptor;
  GRpSnapshotBlock: TRpBlockLiteral;

// The invoke function of a block receives the block itself first
procedure RpWKSnapshotDone(ABlock: Pointer; image: NSImage; error: NSError); cdecl;
var
  LTiff: NSData;
  LRep: NSBitmapImageRep;
begin
  GRpSnapshotPng := nil;
  if image <> nil then
  begin
    LTiff := image.TIFFRepresentation;
    if LTiff <> nil then
    begin
      LRep := NSBitmapImageRep.imageRepWithData(LTiff);
      if LRep <> nil then
      begin
        GRpSnapshotPng := LRep.representationUsingType_properties(NSPNGFileType, nil);
        if GRpSnapshotPng <> nil then
          GRpSnapshotPng.retain;
      end;
    end;
  end;
  GRpSnapshotDone := True;
end;

// Nil when the runtime has no blocks (it always has them from macOS 10.6)
function RpWKSnapshotBlock: Pointer;
var
  LIsa: Pointer;
begin
  Result := nil;
  // The isa of the blocks that live in static memory
  LIsa := dlsym(RTLD_DEFAULT, '_NSConcreteGlobalBlock');
  if LIsa = nil then
    Exit;
  GRpSnapshotDescriptor.Reserved := 0;
  GRpSnapshotDescriptor.Size := SizeOf(TRpBlockLiteral);
  GRpSnapshotBlock.Isa := LIsa;
  GRpSnapshotBlock.Flags := BLOCK_IS_GLOBAL;
  GRpSnapshotBlock.Reserved := 0;
  GRpSnapshotBlock.Invoke := @RpWKSnapshotDone;
  GRpSnapshotBlock.Descriptor := @GRpSnapshotDescriptor;
  Result := @GRpSnapshotBlock;
end;

{ TRpWKWebView }

function TRpWKWebView.performKeyEquivalent(event: NSEvent): ObjCBOOL;
var
  LKey: string;
  LAction: SEL;
begin
  if (event.type_ = NSKeyDown) and (window <> nil) and
     (window.firstResponder = Self) and
     ((event.modifierFlags and NSDeviceIndependentModifierFlagsMask) = NSCommandKeyMask) then
  begin
    LKey := RpStrFromNS(event.charactersIgnoringModifiers);
    LAction := nil;
    if LKey = 'c' then
      LAction := objcselector('copy:')
    else if LKey = 'x' then
      LAction := objcselector('cut:')
    else if LKey = 'v' then
      LAction := objcselector('paste:');
    // Undo and select all stay with the page (Monaco handles them)
    if LAction <> nil then
      Exit(NSApp.sendAction_to_from(LAction, Self, Self));
  end;
  Result := inherited performKeyEquivalent(event);
end;

{ TRpWKHost }

procedure TRpWKHost.userContentController_didReceiveScriptMessage(controller: id;
  message_: WKScriptMessage);
var
  LBody: id;
  LMsg: string;
begin
  if (FControl = nil) or FControl.FIsDestroying then
    Exit;
  LBody := message_.body;
  if LBody = nil then
    Exit;
  if NSObject(LBody).isKindOfClass(NSString) then
    LMsg := RpStrFromNS(NSString(LBody))
  else
    LMsg := RpStrFromNS(NSObject(LBody).description);
  if Assigned(FControl.FOnWebMessageReceived) then
    FControl.FOnWebMessageReceived(FControl, LMsg);
end;

procedure TRpWKHost.webView_didFinishNavigation(webView: id; navigation: id);
begin
  if (FControl <> nil) and (not FControl.FIsDestroying) and
     Assigned(FControl.FOnNavigationCompleted) then
    FControl.FOnNavigationCompleted(FControl, True);
end;

procedure TRpWKHost.webView_didFailNavigation_withError(webView: id;
  navigation: id; error: NSError);
begin
  // Cancelled: another navigation took its place
  if (error <> nil) and (error.code = NSURLErrorCancelled) then
    Exit;
  if (FControl <> nil) and (not FControl.FIsDestroying) and
     Assigned(FControl.FOnNavigationCompleted) then
    FControl.FOnNavigationCompleted(FControl, False);
end;

procedure TRpWKHost.webView_didFailProvisionalNavigation_withError(webView: id;
  navigation: id; error: NSError);
begin
  webView_didFailNavigation_withError(webView, navigation, error);
end;

procedure TRpWKHost.webViewWebContentProcessDidTerminate(webView: id);
begin
  // The page is gone (as a failed navigation: the editors reload or fall back)
  if (FControl <> nil) and (not FControl.FIsDestroying) and
     Assigned(FControl.FOnNavigationCompleted) then
    FControl.FOnNavigationCompleted(FControl, False);
end;

{$ENDIF}

{ TRpLCLWebView }

constructor TRpLCLWebView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks];
  Width := 300;
  Height := 200;
  FWebViewCreated := False;
  FWebViewCreating := False;
  FIsDestroying := False;
  FPendingUrl := '';
  FUserDataFolder := '';
  FLoaderDllPath := '';
{$IFDEF MSWINDOWS}
  FHandlerObjects := TList.Create;
{$ENDIF}
end;

destructor TRpLCLWebView.Destroy;
begin
  FIsDestroying := True;
  CloseWebView;
{$IFDEF MSWINDOWS}
  FHandlerObjects.Free;
{$ENDIF}
  inherited Destroy;
end;

procedure TRpLCLWebView.CreateWnd;
begin
  inherited CreateWnd;
{$IFDEF MSWINDOWS}
  // The browser of the previous handle (a form shown again modally recreates
  // its windows): back in this one, with its page and its state
  if FParked and (FController <> nil) then
  begin
    FParked := False;
    FController.Put_ParentWindow(Handle);
    UpdateWebViewBounds;
    if Visible then
      FController.Put_IsVisible(1);
    FController.NotifyParentWindowPositionChanged;
  end;
{$ENDIF}
{$IF DEFINED(MSWINDOWS) OR DEFINED(RPWEBKIT)}
  if (not FWebViewCreated) and (not FWebViewCreating) and (FPendingUrl <> '') then
    CreateWebView;
{$IFEND}
end;

procedure TRpLCLWebView.DestroyWnd;
begin
{$IFDEF MSWINDOWS}
  // If window handle is destroyed while creating, reset state
  if FWebViewCreating and (not FWebViewCreated) then
    FWebViewCreating := False;
  // The browser window is a child of this handle and would go with it (the
  // editor stayed grey until the designer was restarted): it waits hidden
  if (FController <> nil) and (not FIsDestroying) then
  begin
    FController.Put_IsVisible(0);
    if Succeeded(FController.Put_ParentWindow(ParkingWindow)) then
      FParked := True;
  end;
{$ENDIF}
{$IFDEF RPWEBKIT}
  // The WKWebView is a subview of the handle that goes away
  CloseWebView;
{$ENDIF}
  inherited DestroyWnd;
end;

procedure TRpLCLWebView.Resize;
begin
  inherited Resize;
{$IF DEFINED(MSWINDOWS) OR DEFINED(RPWEBKIT)}
  UpdateWebViewBounds;
{$IFEND}
end;

procedure TRpLCLWebView.VisibleChanged;
begin
  inherited VisibleChanged;
{$IFDEF MSWINDOWS}
  if FController <> nil then
  begin
    if Visible then
      FController.Put_IsVisible(1)
    else
      FController.Put_IsVisible(0);
  end;
{$ENDIF}
{$IFDEF RPWEBKIT}
  if FWKView <> nil then
    NSView(FWKView).setHidden(not Visible);
{$ENDIF}
end;

class function TRpLCLWebView.Supported: Boolean;
begin
{$IF DEFINED(MSWINDOWS) OR DEFINED(RPWEBKIT)}
  Result := True;
{$ELSE}
  Result := False;
{$IFEND}
end;

procedure TRpLCLWebView.WMWindowPosChanged(var Message: TLMWindowPosChanged);
begin
  inherited;
{$IFDEF MSWINDOWS}
  if FController <> nil then
  begin
    UpdateWebViewBounds;
    FController.NotifyParentWindowPositionChanged;
  end;
{$ENDIF}
end;

function TRpLCLWebView.CreateWebView: Boolean;
{$IFDEF MSWINDOWS}
var
  hr: HResult;
  LUserDataW: WideString;
  PUserData: PWideChar;
{$ENDIF}
{$IFDEF RPWEBKIT}
var
  LConfig: WKWebViewConfiguration;
  LScript: WKUserScript;
  LHost: TRpWKHost;
  LPrefs: NSObject;
  LParent: NSView;
  LWeb: WKWebView;
{$ENDIF}
begin
  Result := False;
  if FWebViewCreated or FWebViewCreating or FIsDestroying then
    Exit(True);

{$IF DEFINED(MSWINDOWS)}
  if not HandleAllocated then
    HandleNeeded;

  if not InitWebView2Loader(FLoaderDllPath) then
  begin
    if Assigned(FOnCreateWebViewCompleted) then
      FOnCreateWebViewCompleted(Self, E_FAIL);
    Exit(False);
  end;

  if not Assigned(CreateCoreWebView2EnvironmentWithOptionsFunc) then
  begin
    if Assigned(FOnCreateWebViewCompleted) then
      FOnCreateWebViewCompleted(Self, E_FAIL);
    Exit(False);
  end;

  FWebViewCreating := True;

  PUserData := nil;
  if FUserDataFolder <> '' then
  begin
    LUserDataW := WideString(FUserDataFolder);
    PUserData := PWideChar(LUserDataW);
  end;

  FEnvHandler := TCreateEnvHandler.Create(Self);
  hr := CreateCoreWebView2EnvironmentWithOptionsFunc(
    nil,
    PUserData,
    nil,
    FEnvHandler
  );

  if Failed(hr) then
  begin
    FWebViewCreating := False;
    if Assigned(FOnCreateWebViewCompleted) then
      FOnCreateWebViewCompleted(Self, hr);
    Exit(False);
  end;

  Result := True;
{$ELSEIF DEFINED(RPWEBKIT)}
  // WKWebView exists from macOS 10.10; the designer needs 10.15
  if NSClassFromString(RpNSStr('WKWebView')) = nil then
  begin
    if Assigned(FOnCreateWebViewCompleted) then
      FOnCreateWebViewCompleted(Self, E_NOTIMPL);
    Exit(False);
  end;
  if not HandleAllocated then
    HandleNeeded;
  LParent := RpContentViewOf(Handle);

  LHost := TRpWKHost.alloc.init;
  LHost.FControl := Self;
  FWKHost := LHost;

  LConfig := WKWebViewConfiguration.alloc.init;
  LScript := WKUserScript.alloc.initWithSource_injectionTime_forMainFrameOnly(
    RpNSStr(CRpWKBridgeScript), WKUserScriptInjectionTimeAtDocumentStart, True);
  LConfig.userContentController.addUserScript(LScript);
  LScript.release;
  LConfig.userContentController.addScriptMessageHandler_name(LHost,
    RpNSStr(CRpWKHandlerName));
  // The pages are local folders (Monaco loads its modules and workers next
  // to index.html); the inspector of Safari helps to debug them. Both are
  // WebKit preferences without public API: set only when they exist.
  LPrefs := LConfig.preferences;
  if LPrefs.respondsToSelector(objcselector('_setAllowFileAccessFromFileURLs:')) then
    LPrefs.setValue_forKey(NSNumber.numberWithBool(True),
      RpNSStr('allowFileAccessFromFileURLs'));
  if LPrefs.respondsToSelector(objcselector('_setDeveloperExtrasEnabled:')) then
    LPrefs.setValue_forKey(NSNumber.numberWithBool(True),
      RpNSStr('developerExtrasEnabled'));

  LWeb := TRpWKWebView.alloc.initWithFrame_configuration(LParent.bounds, LConfig);
  LConfig.release;
  LWeb.setNavigationDelegate(LHost);
  LWeb.setAutoresizingMask(NSViewWidthSizable or NSViewHeightSizable);
  LWeb.setHidden(not Visible);
  LParent.addSubview(LWeb);
  FWKView := LWeb;

  FWebViewCreated := True;
  Result := True;
  if Assigned(FOnCreateWebViewCompleted) then
    FOnCreateWebViewCompleted(Self, S_OK);
  if (FPendingUrl <> '') and (FWKView <> nil) then
    Navigate(FPendingUrl);
{$ELSE}
  if Assigned(FOnCreateWebViewCompleted) then
    FOnCreateWebViewCompleted(Self, E_NOTIMPL);
{$IFEND}
end;

procedure TRpLCLWebView.CloseWebView;
begin
{$IFDEF MSWINDOWS}
  // Before releasing them: this control keeps them alive until then
  DetachHandlers;
  if FController <> nil then
  begin
    FController.Close;
    FController := nil;
  end;
  FWebView := nil;
  FEnvironment := nil;
  FNavCompletedHandler := nil;
  FWebMsgReceivedHandler := nil;
  FCtrlHandler := nil;
  FEnvHandler := nil;
  FParked := False;
{$ENDIF}
{$IFDEF RPWEBKIT}
  if FWKView <> nil then
  begin
    WKWebView(FWKView).stopLoading;
    WKWebView(FWKView).setNavigationDelegate(nil);
    NSView(FWKView).removeFromSuperview;
    NSView(FWKView).release;
    FWKView := nil;
  end;
  if FWKHost <> nil then
  begin
    TRpWKHost(FWKHost).FControl := nil;
    NSObject(FWKHost).release;
    FWKHost := nil;
  end;
{$ENDIF}
  FWebViewCreated := False;
  FWebViewCreating := False;
end;

function TRpLCLWebView.Navigate(const AUrl: string): Boolean;
{$IFDEF RPWEBKIT}
var
  LPath: string;
  LUrl: NSURL;
{$ENDIF}
begin
  Result := False;
{$IFDEF MSWINDOWS}
  if FWebView <> nil then
  begin
    Result := Succeeded(FWebView.Navigate(PWideChar(WideString(AUrl))));
    FPendingUrl := '';
  end
  else
  begin
    FPendingUrl := AUrl;
    if (not FWebViewCreating) and (not FWebViewCreated) then
      CreateWebView;
    Result := True;
  end;
{$ENDIF}
{$IFDEF RPWEBKIT}
  if FWKView = nil then
  begin
    FPendingUrl := AUrl;
    if not FIsDestroying then
      CreateWebView;
    Exit(True);
  end;
  FPendingUrl := '';
  if SameText(Copy(AUrl, 1, 5), 'file:') then
  begin
    // A local page: WebKit needs the folder it may read (its scripts)
    LPath := RpFileUrlToPath(AUrl);
    LUrl := NSURL.fileURLWithPath(RpNSStr(LPath));
    Result := WKWebView(FWKView).loadFileURL_allowingReadAccessToURL(LUrl,
      NSURL.fileURLWithPath_isDirectory(RpNSStr(ExtractFileDir(LPath)), True)) <> nil;
  end
  else
  begin
    LUrl := NSURL.URLWithString(RpNSStr(AUrl));
    if LUrl <> nil then
      Result := WKWebView(FWKView).loadRequest(NSURLRequest.requestWithURL(LUrl)) <> nil;
  end;
{$ENDIF}
end;

function TRpLCLWebView.NavigateToString(const AHtml: string): Boolean;
begin
  Result := False;
{$IFDEF MSWINDOWS}
  if FWebView <> nil then
    Result := Succeeded(FWebView.NavigateToString(PWideChar(WideString(AHtml))));
{$ENDIF}
{$IFDEF RPWEBKIT}
  if FWKView <> nil then
    Result := WKWebView(FWKView).loadHTMLString_baseURL(RpNSStr(AHtml), nil) <> nil;
{$ENDIF}
end;

function TRpLCLWebView.ExecuteScript(const AScript: string): Boolean;
begin
  Result := False;
{$IFDEF MSWINDOWS}
  if FWebView <> nil then
    Result := Succeeded(FWebView.ExecuteScript(PWideChar(WideString(AScript)), nil));
{$ENDIF}
{$IFDEF RPWEBKIT}
  if FWKView <> nil then
  begin
    WKWebView(FWKView).evaluateJavaScript_completionHandler(RpNSStr(AScript), nil);
    Result := True;
  end;
{$ENDIF}
end;

function TRpLCLWebView.PostWebMessageAsString(const AMessage: string): Boolean;
begin
  Result := False;
{$IFDEF MSWINDOWS}
  if FWebView <> nil then
    Result := Succeeded(FWebView.PostWebMessageAsString(PWideChar(WideString(AMessage))));
{$ENDIF}
{$IFDEF RPWEBKIT}
  Result := ExecuteScript('window.rpWebViewDispatch && window.rpWebViewDispatch(' +
    RpJsString(AMessage) + ');');
{$ENDIF}
end;

function TRpLCLWebView.PostWebMessageAsJson(const AJson: string): Boolean;
begin
  Result := False;
{$IFDEF MSWINDOWS}
  if FWebView <> nil then
    Result := Succeeded(FWebView.PostWebMessageAsJson(PWideChar(WideString(AJson))));
{$ENDIF}
{$IFDEF RPWEBKIT}
  Result := ExecuteScript('window.rpWebViewDispatch && window.rpWebViewDispatch(' +
    AJson + ');');
{$ENDIF}
end;

function TRpLCLWebView.CapturePreviewPng(AStream: TStream; ATimeoutMs: Cardinal): Boolean;
{$IFDEF MSWINDOWS}
var
  LHandler: TCapturePreviewHandler;
  LHandlerRef: ICoreWebView2CapturePreviewCompletedHandler;
  LStreamRef: IStream;
  LStart: QWord;
{$ENDIF}
{$IFDEF RPWEBKIT}
var
  LStart: QWord;
{$ENDIF}
begin
  Result := False;
{$IFDEF MSWINDOWS}
  if FWebView = nil then
    Exit;
  LHandler := TCapturePreviewHandler.Create(Self);
  LHandlerRef := LHandler;
  LStreamRef := TStreamAdapter.Create(AStream, soReference);
  // 0 = COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_PNG
  if Failed(FWebView.CapturePreview(0, LStreamRef, LHandlerRef)) then
    Exit;
  LStart := GetTickCount64;
  while (not LHandler.Done) and (not FIsDestroying) and
    (GetTickCount64 - LStart < ATimeoutMs) do
  begin
    Application.ProcessMessages;
    Sleep(5);
  end;
  Result := LHandler.Done and Succeeded(LHandler.Error);
{$ENDIF}
{$IFDEF RPWEBKIT}
  if (FWKView = nil) or (RpWKSnapshotBlock = nil) then
    Exit;
  GRpSnapshotDone := False;
  GRpSnapshotPng := nil;
  WKWebView(FWKView).takeSnapshotWithConfiguration_completionHandler(nil,
    RpWKSnapshotBlock);
  LStart := GetTickCount64;
  while (not GRpSnapshotDone) and (not FIsDestroying) and
    (GetTickCount64 - LStart < ATimeoutMs) do
  begin
    Application.ProcessMessages;
    Sleep(5);
  end;
  if GRpSnapshotDone and (GRpSnapshotPng <> nil) then
  begin
    AStream.WriteBuffer(GRpSnapshotPng.bytes^, GRpSnapshotPng.length);
    GRpSnapshotPng.release;
    GRpSnapshotPng := nil;
    Result := True;
  end;
{$ENDIF}
end;

{$IFDEF RPWEBKIT}

procedure TRpLCLWebView.UpdateWebViewBounds;
var
  LParent: NSView;
begin
  if (FWKView = nil) or (not HandleAllocated) then
    Exit;
  LParent := NSView(FWKView).superview;
  if LParent <> nil then
    NSView(FWKView).setFrame(LParent.bounds);
end;

{$ENDIF}

{$IFDEF MSWINDOWS}

procedure TRpLCLWebView.DetachHandlers;
var
  I: Integer;
begin
  if FHandlerObjects = nil then
    Exit;
  for I := 0 to FHandlerObjects.Count - 1 do
    TRpWebViewHandler(FHandlerObjects[I]).FControl := nil;
  FHandlerObjects.Clear;
end;

procedure TRpLCLWebView.UpdateWebViewBounds;
var
  R: TRect;
begin
  if FController = nil then
    Exit;
  R.Left := 0;
  R.Top := 0;
  R.Right := ClientWidth;
  R.Bottom := ClientHeight;
  FController.Put_Bounds(R);
end;

procedure TRpLCLWebView.DoEnvironmentCreated(errorCode: HResult; const AEnv: ICoreWebView2Environment);
var
  hr: HResult;
begin
  if FIsDestroying then
    Exit;

  if Succeeded(errorCode) and (AEnv <> nil) then
  begin
    FEnvironment := AEnv;
    FCtrlHandler := TCreateControllerHandler.Create(Self);
    hr := FEnvironment.CreateCoreWebView2Controller(
      Self.Handle,
      FCtrlHandler
    );
    if Failed(hr) then
    begin
      FWebViewCreating := False;
      if Assigned(FOnCreateWebViewCompleted) then
        FOnCreateWebViewCompleted(Self, hr);
    end;
  end
  else
  begin
    FWebViewCreating := False;
    if Assigned(FOnCreateWebViewCompleted) then
      FOnCreateWebViewCompleted(Self, errorCode);
  end;
end;

procedure TRpLCLWebView.DoControllerCreated(errorCode: HResult; const AController: ICoreWebView2Controller);
var
  hr: HResult;
  LSettings: ICoreWebView2Settings;
begin
  if FIsDestroying then
    Exit;

  FWebViewCreating := False;

  if Succeeded(errorCode) and (AController <> nil) then
  begin
    FController := AController;
    hr := FController.Get_CoreWebView2(FWebView);
    if Succeeded(hr) and (FWebView <> nil) then
    begin
      FWebViewCreated := True;

      // Enable scripts, web messages, dialogs, dev tools
      if Succeeded(FWebView.Get_Settings(LSettings)) and (LSettings <> nil) then
      begin
        LSettings.Put_IsScriptEnabled(1);
        LSettings.Put_IsWebMessageEnabled(1);
        LSettings.Put_AreDefaultScriptDialogsEnabled(1);
        LSettings.Put_AreDevToolsEnabled(1);
      end;

      // Event handlers
      FNavCompletedHandler := TNavCompletedHandler.Create(Self);
      FWebView.add_NavigationCompleted(FNavCompletedHandler, FNavCompletedToken);
      FWebMsgReceivedHandler := TWebMsgReceivedHandler.Create(Self);
      FWebView.add_WebMessageReceived(FWebMsgReceivedHandler, FWebMsgReceivedToken);

      UpdateWebViewBounds;
      FController.Put_IsVisible(1);

      if Assigned(FOnCreateWebViewCompleted) then
        FOnCreateWebViewCompleted(Self, S_OK);

      if FPendingUrl <> '' then
      begin
        Navigate(FPendingUrl);
        FPendingUrl := '';
      end;
    end
    else
    begin
      if Assigned(FOnCreateWebViewCompleted) then
        FOnCreateWebViewCompleted(Self, hr);
    end;
  end
  else
  begin
    if Assigned(FOnCreateWebViewCompleted) then
      FOnCreateWebViewCompleted(Self, errorCode);
  end;
end;

procedure TRpLCLWebView.DoNavigationCompleted(const ASender: ICoreWebView2; const AArgs: ICoreWebView2NavigationCompletedEventArgs);
var
  LSuccess: Integer;
begin
  if FIsDestroying then
    Exit;

  LSuccess := 0;
  if AArgs <> nil then
    AArgs.Get_IsSuccess(LSuccess);

  if Assigned(FOnNavigationCompleted) then
    FOnNavigationCompleted(Self, LSuccess <> 0);
end;

procedure TRpLCLWebView.DoWebMessageReceived(const ASender: ICoreWebView2; const AArgs: ICoreWebView2WebMessageReceivedEventArgs);
var
  LP: PWideChar;
  LMsg: string;
begin
  if FIsDestroying then
    Exit;

  LP := nil;
  if (AArgs <> nil) and Succeeded(AArgs.TryGetWebMessageAsString(LP)) and (LP <> nil) then
  begin
    LMsg := UTF8Encode(WideString(LP));
    CoTaskMemFree(LP);
    if Assigned(FOnWebMessageReceived) then
      FOnWebMessageReceived(Self, LMsg);
  end;
end;

{$ENDIF}

{$IFDEF MSWINDOWS}
finalization
  if (GParkingWindow <> 0) and IsWindow(GParkingWindow) then
    DestroyWindow(GParkingWindow);
{$ENDIF}
end.
