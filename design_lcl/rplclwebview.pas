{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rplclwebview.pas                                }
{       LCL Visual Control for Microsoft WebView2       }
{       Compatibility unit for Free Pascal / LCL        }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rplclwebview;

{$mode delphi}

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
    procedure DetachHandlers;
    procedure UpdateWebViewBounds;
    procedure DoEnvironmentCreated(errorCode: HResult; const AEnv: ICoreWebView2Environment);
    procedure DoControllerCreated(errorCode: HResult; const AController: ICoreWebView2Controller);
    procedure DoNavigationCompleted(const ASender: ICoreWebView2; const AArgs: ICoreWebView2NavigationCompletedEventArgs);
    procedure DoWebMessageReceived(const ASender: ICoreWebView2; const AArgs: ICoreWebView2WebMessageReceivedEventArgs);
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

    function CreateWebView: Boolean;
    procedure CloseWebView;
    function Navigate(const AUrl: string): Boolean;
    function NavigateToString(const AHtml: string): Boolean;
    function ExecuteScript(const AScript: string): Boolean;
    function PostWebMessageAsString(const AMessage: string): Boolean;
    function PostWebMessageAsJson(const AJson: string): Boolean;
    // PNG of what the page shows (ICoreWebView2.CapturePreview), waiting up
    // to ATimeoutMs while processing messages. Works without a visible
    // desktop (tests, screenshots); False where there is no WebView2.
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
  if (not FWebViewCreated) and (not FWebViewCreating) and (FPendingUrl <> '') then
    CreateWebView;
{$ENDIF}
end;

procedure TRpLCLWebView.DestroyWnd;
begin
{$IFDEF MSWINDOWS}
  // If window handle is destroyed while creating, reset state
  if FWebViewCreating and (not FWebViewCreated) then
    FWebViewCreating := False;
{$ENDIF}
  inherited DestroyWnd;
end;

procedure TRpLCLWebView.Resize;
begin
  inherited Resize;
{$IFDEF MSWINDOWS}
  UpdateWebViewBounds;
{$ENDIF}
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
begin
  Result := False;
  if FWebViewCreated or FWebViewCreating or FIsDestroying then
    Exit(True);

{$IFDEF MSWINDOWS}
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
{$ELSE}
  if Assigned(FOnCreateWebViewCompleted) then
    FOnCreateWebViewCompleted(Self, E_NOTIMPL);
{$ENDIF}
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
{$ENDIF}
  FWebViewCreated := False;
  FWebViewCreating := False;
end;

function TRpLCLWebView.Navigate(const AUrl: string): Boolean;
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
end;

function TRpLCLWebView.NavigateToString(const AHtml: string): Boolean;
begin
  Result := False;
{$IFDEF MSWINDOWS}
  if FWebView <> nil then
    Result := Succeeded(FWebView.NavigateToString(PWideChar(WideString(AHtml))));
{$ENDIF}
end;

function TRpLCLWebView.ExecuteScript(const AScript: string): Boolean;
begin
  Result := False;
{$IFDEF MSWINDOWS}
  if FWebView <> nil then
    Result := Succeeded(FWebView.ExecuteScript(PWideChar(WideString(AScript)), nil));
{$ENDIF}
end;

function TRpLCLWebView.PostWebMessageAsString(const AMessage: string): Boolean;
begin
  Result := False;
{$IFDEF MSWINDOWS}
  if FWebView <> nil then
    Result := Succeeded(FWebView.PostWebMessageAsString(PWideChar(WideString(AMessage))));
{$ENDIF}
end;

function TRpLCLWebView.PostWebMessageAsJson(const AJson: string): Boolean;
begin
  Result := False;
{$IFDEF MSWINDOWS}
  if FWebView <> nil then
    Result := Succeeded(FWebView.PostWebMessageAsJson(PWideChar(WideString(AJson))));
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
end;

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

end.
