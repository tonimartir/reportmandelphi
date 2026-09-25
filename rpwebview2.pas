{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpwebview2.pas                                  }
{       Direct COM interfaces for Microsoft WebView2    }
{       Compatibility unit for Free Pascal / Windows    }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpwebview2;

{$mode delphi}

interface

{$IFDEF MSWINDOWS}
uses
  Windows, SysUtils, ActiveX;

const
  IID_ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler: TGUID = '{4E8A3389-C7D8-407A-A086-C40383687360}';
  IID_ICoreWebView2CreateCoreWebView2ControllerCompletedHandler: TGUID = '{6C4819F3-C9B7-4260-8127-C9F5BDE7F68C}';
  IID_ICoreWebView2Environment: TGUID = '{B96D755E-0319-4E92-A296-23436F46A1FC}';
  IID_ICoreWebView2Controller: TGUID = '{4D00C0D1-9434-4EB6-8078-8697A560334F}';
  IID_ICoreWebView2: TGUID = '{76ECEACB-0462-4D94-AC83-423A6793775E}';
  IID_ICoreWebView2Settings: TGUID = '{E562E4F0-D7FA-43AC-8D77-2FB5072D1E62}';
  IID_ICoreWebView2NavigationCompletedEventHandler: TGUID = '{D33A35BF-1C49-4F98-93AB-006E0533FE1C}';
  IID_ICoreWebView2NavigationCompletedEventArgs: TGUID = '{30D68B7D-20D9-4752-A9CA-EC8448FBB5C1}';
  IID_ICoreWebView2WebMessageReceivedEventHandler: TGUID = '{57213F19-00E6-49FA-8E07-898EA01ECBD2}';
  IID_ICoreWebView2WebMessageReceivedEventArgs: TGUID = '{0F99A40C-E962-4207-9E92-E3D542EFF849}';
  IID_ICoreWebView2ExecuteScriptCompletedHandler: TGUID = '{49511172-CC67-4BCA-9923-137112F4C4CC}';

type
  EventRegistrationToken = record
    value: Int64;
  end;

  ICoreWebView2Environment = interface;
  ICoreWebView2Controller = interface;
  ICoreWebView2 = interface;
  ICoreWebView2Settings = interface;
  ICoreWebView2NavigationCompletedEventArgs = interface;
  ICoreWebView2WebMessageReceivedEventArgs = interface;

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler = interface(IUnknown)
    ['{4E8A3389-C7D8-407A-A086-C40383687360}']
    function Invoke(errorCode: HResult; const created_environment: ICoreWebView2Environment): HResult; stdcall;
  end;

  ICoreWebView2CreateCoreWebView2ControllerCompletedHandler = interface(IUnknown)
    ['{6C4819F3-C9B7-4260-8127-C9F5BDE7F68C}']
    function Invoke(errorCode: HResult; const createdController: ICoreWebView2Controller): HResult; stdcall;
  end;

  ICoreWebView2NavigationCompletedEventHandler = interface(IUnknown)
    ['{D33A35BF-1C49-4F98-93AB-006E0533FE1C}']
    function Invoke(const sender: ICoreWebView2; const args: ICoreWebView2NavigationCompletedEventArgs): HResult; stdcall;
  end;

  ICoreWebView2WebMessageReceivedEventHandler = interface(IUnknown)
    ['{57213F19-00E6-49FA-8E07-898EA01ECBD2}']
    function Invoke(const sender: ICoreWebView2; const args: ICoreWebView2WebMessageReceivedEventArgs): HResult; stdcall;
  end;

  ICoreWebView2ExecuteScriptCompletedHandler = interface(IUnknown)
    ['{49511172-CC67-4BCA-9923-137112F4C4CC}']
    function Invoke(errorCode: HResult; resultObjectAsJson: PWideChar): HResult; stdcall;
  end;

  // ---------------------------------------------------------------------------
  // EventArgs
  // ---------------------------------------------------------------------------

  ICoreWebView2NavigationCompletedEventArgs = interface(IUnknown)
    ['{30D68B7D-20D9-4752-A9CA-EC8448FBB5C1}']
    function Get_IsSuccess(out isSuccess: Integer): HResult; stdcall;
    function Get_WebErrorStatus(out webErrorStatus: Integer): HResult; stdcall;
    function Get_NavigationId(out navigationId: UInt64): HResult; stdcall;
  end;

  ICoreWebView2WebMessageReceivedEventArgs = interface(IUnknown)
    ['{0F99A40C-E962-4207-9E92-E3D542EFF849}']
    function Get_Source(out value: PWideChar): HResult; stdcall;
    function Get_webMessageAsJson(out value: PWideChar): HResult; stdcall;
    function TryGetWebMessageAsString(out value: PWideChar): HResult; stdcall;
  end;

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  ICoreWebView2Settings = interface(IUnknown)
    ['{E562E4F0-D7FA-43AC-8D77-2FB5072D1E62}']
    function Get_IsScriptEnabled(out isScriptEnabled: Integer): HResult; stdcall;
    function Put_IsScriptEnabled(isScriptEnabled: Integer): HResult; stdcall;
    function Get_IsWebMessageEnabled(out isWebMessageEnabled: Integer): HResult; stdcall;
    function Put_IsWebMessageEnabled(isWebMessageEnabled: Integer): HResult; stdcall;
    function Get_AreDefaultScriptDialogsEnabled(out areDefaultScriptDialogsEnabled: Integer): HResult; stdcall;
    function Put_AreDefaultScriptDialogsEnabled(areDefaultScriptDialogsEnabled: Integer): HResult; stdcall;
    function Get_IsStatusBarEnabled(out isStatusBarEnabled: Integer): HResult; stdcall;
    function Put_IsStatusBarEnabled(isStatusBarEnabled: Integer): HResult; stdcall;
    function Get_AreDevToolsEnabled(out areDevToolsEnabled: Integer): HResult; stdcall;
    function Put_AreDevToolsEnabled(areDevToolsEnabled: Integer): HResult; stdcall;
    function Get_AreDefaultContextMenusEnabled(out enabled: Integer): HResult; stdcall;
    function Put_AreDefaultContextMenusEnabled(enabled: Integer): HResult; stdcall;
    function Get_AreHostObjectsAllowed(out allowed: Integer): HResult; stdcall;
    function Put_AreHostObjectsAllowed(allowed: Integer): HResult; stdcall;
    function Get_IsZoomControlEnabled(out enabled: Integer): HResult; stdcall;
    function Put_IsZoomControlEnabled(enabled: Integer): HResult; stdcall;
    function Get_IsBuiltInErrorPageEnabled(out enabled: Integer): HResult; stdcall;
    function Put_IsBuiltInErrorPageEnabled(enabled: Integer): HResult; stdcall;
  end;

  // ---------------------------------------------------------------------------
  // CoreWebView2
  // ---------------------------------------------------------------------------

  ICoreWebView2 = interface(IUnknown)
    ['{76ECEACB-0462-4D94-AC83-423A6793775E}']
    function Get_Settings(out Settings: ICoreWebView2Settings): HResult; stdcall;
    function Get_Source(out uri: PWideChar): HResult; stdcall;
    function Navigate(uri: PWideChar): HResult; stdcall;
    function NavigateToString(htmlContent: PWideChar): HResult; stdcall;
    function add_NavigationStarting(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_NavigationStarting(token: EventRegistrationToken): HResult; stdcall;
    function add_ContentLoading(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_ContentLoading(token: EventRegistrationToken): HResult; stdcall;
    function add_SourceChanged(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_SourceChanged(token: EventRegistrationToken): HResult; stdcall;
    function add_HistoryChanged(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_HistoryChanged(token: EventRegistrationToken): HResult; stdcall;
    function add_NavigationCompleted(const eventHandler: ICoreWebView2NavigationCompletedEventHandler; out token: EventRegistrationToken): HResult; stdcall;
    function remove_NavigationCompleted(token: EventRegistrationToken): HResult; stdcall;
    function add_FrameNavigationStarting(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_FrameNavigationStarting(token: EventRegistrationToken): HResult; stdcall;
    function add_FrameNavigationCompleted(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_FrameNavigationCompleted(token: EventRegistrationToken): HResult; stdcall;
    function add_ScriptDialogOpening(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_ScriptDialogOpening(token: EventRegistrationToken): HResult; stdcall;
    function add_PermissionRequested(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_PermissionRequested(token: EventRegistrationToken): HResult; stdcall;
    function add_ProcessFailed(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_ProcessFailed(token: EventRegistrationToken): HResult; stdcall;
    function AddScriptToExecuteOnDocumentCreated(javaScript: PWideChar; const handler: IUnknown): HResult; stdcall;
    function RemoveScriptToExecuteOnDocumentCreated(id: PWideChar): HResult; stdcall;
    function ExecuteScript(javaScript: PWideChar; const handler: ICoreWebView2ExecuteScriptCompletedHandler): HResult; stdcall;
    function CapturePreview(imageFormat: Integer; const imageStream: IStream; const handler: IUnknown): HResult; stdcall;
    function Reload: HResult; stdcall;
    function PostWebMessageAsJson(webMessageAsJson: PWideChar): HResult; stdcall;
    function PostWebMessageAsString(webMessageAsString: PWideChar): HResult; stdcall;
    function add_WebMessageReceived(const handler: ICoreWebView2WebMessageReceivedEventHandler; out token: EventRegistrationToken): HResult; stdcall;
    function remove_WebMessageReceived(token: EventRegistrationToken): HResult; stdcall;
    function CallDevToolsProtocolMethod(methodName: PWideChar; parametersAsJson: PWideChar; const handler: IUnknown): HResult; stdcall;
    function Get_BrowserProcessId(out value: Cardinal): HResult; stdcall;
    function Get_CanGoBack(out CanGoBack: Integer): HResult; stdcall;
    function Get_CanGoForward(out CanGoForward: Integer): HResult; stdcall;
    function GoBack: HResult; stdcall;
    function GoForward: HResult; stdcall;
    function GetDevToolsProtocolEventReceiver(eventName: PWideChar; out receiver: IUnknown): HResult; stdcall;
    function Stop: HResult; stdcall;
    function add_NewWindowRequested(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_NewWindowRequested(token: EventRegistrationToken): HResult; stdcall;
    function add_DocumentTitleChanged(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_DocumentTitleChanged(token: EventRegistrationToken): HResult; stdcall;
    function Get_DocumentTitle(out title: PWideChar): HResult; stdcall;
    function AddHostObjectToScript(name: PWideChar; const object_: OleVariant): HResult; stdcall;
    function RemoveHostObjectFromScript(name: PWideChar): HResult; stdcall;
    function OpenDevToolsWindow: HResult; stdcall;
    function add_ContainsFullScreenElementChanged(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_ContainsFullScreenElementChanged(token: EventRegistrationToken): HResult; stdcall;
    function Get_ContainsFullScreenElement(out containsFullScreenElement: Integer): HResult; stdcall;
    function add_WebResourceRequested(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_WebResourceRequested(token: EventRegistrationToken): HResult; stdcall;
    function AddWebResourceRequestedFilter(const const_uri: PWideChar; resourceContext: Integer): HResult; stdcall;
    function RemoveWebResourceRequestedFilter(const const_uri: PWideChar; resourceContext: Integer): HResult; stdcall;
    function add_WindowCloseRequested(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function remove_WindowCloseRequested(token: EventRegistrationToken): HResult; stdcall;
  end;

  // ---------------------------------------------------------------------------
  // Controller
  // ---------------------------------------------------------------------------

  ICoreWebView2Controller = interface(IUnknown)
    ['{4D00C0D1-9434-4EB6-8078-8697A560334F}']
    function Get_IsVisible(out isVisible: Integer): HResult; stdcall;
    function Put_IsVisible(isVisible: Integer): HResult; stdcall;
    function Get_Bounds(out bounds: TRect): HResult; stdcall;
    function Put_Bounds(bounds: TRect): HResult; stdcall;
    function Get_ZoomFactor(out zoomFactor: Double): HResult; stdcall;
    function Put_ZoomFactor(zoomFactor: Double): HResult; stdcall;
    function Add_ZoomFactorChanged(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function Remove_ZoomFactorChanged(token: EventRegistrationToken): HResult; stdcall;
    function SetBoundsAndZoomFactor(bounds: TRect; zoomFactor: Double): HResult; stdcall;
    function MoveFocus(reason: Integer): HResult; stdcall;
    function Add_MoveFocusRequested(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function Remove_MoveFocusRequested(token: EventRegistrationToken): HResult; stdcall;
    function Add_GotFocus(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function Remove_GotFocus(token: EventRegistrationToken): HResult; stdcall;
    function Add_LostFocus(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function Remove_LostFocus(token: EventRegistrationToken): HResult; stdcall;
    function Add_AcceleratorKeyPressed(const eventHandler: IUnknown; out token: EventRegistrationToken): HResult; stdcall;
    function Remove_AcceleratorKeyPressed(token: EventRegistrationToken): HResult; stdcall;
    function Get_ParentWindow(out topLevelWindow: HWND): HResult; stdcall;
    function Put_ParentWindow(topLevelWindow: HWND): HResult; stdcall;
    function NotifyParentWindowPositionChanged: HResult; stdcall;
    function Close: HResult; stdcall;
    function Get_CoreWebView2(out coreWebView2: ICoreWebView2): HResult; stdcall;
  end;

  // ---------------------------------------------------------------------------
  // Environment
  // ---------------------------------------------------------------------------

  ICoreWebView2Environment = interface(IUnknown)
    ['{B96D755E-0319-4E92-A296-23436F46A1FC}']
    function CreateCoreWebView2Controller(
      parentWindow: HWND;
      const handler: ICoreWebView2CreateCoreWebView2ControllerCompletedHandler
    ): HResult; stdcall;
    function CreateWebResourceResponse(
      const content: IStream;
      statusCode: Integer;
      reasonPhrase: PWideChar;
      headers: PWideChar;
      out response: IUnknown
    ): HResult; stdcall;
    function Get_BrowserVersionString(out versionInfo: PWideChar): HResult; stdcall;
    function Add_NewBrowserVersionAvailable(
      const eventHandler: IUnknown;
      out token: EventRegistrationToken
    ): HResult; stdcall;
    function Remove_NewBrowserVersionAvailable(token: EventRegistrationToken): HResult; stdcall;
  end;

type
  TCreateCoreWebView2EnvironmentWithOptions = function(
    browserExecutableFolder: LPCWSTR;
    userDataFolder: LPCWSTR;
    environmentOptions: IUnknown;
    const environment_created_handler: ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler
  ): HResult; stdcall;

  TGetAvailableCoreWebView2BrowserVersionString = function(
    browserExecutableFolder: LPCWSTR;
    out versionInfo: LPWSTR
  ): HResult; stdcall;

var
  CreateCoreWebView2EnvironmentWithOptionsFunc: TCreateCoreWebView2EnvironmentWithOptions = nil;
  GetAvailableCoreWebView2BrowserVersionStringFunc: TGetAvailableCoreWebView2BrowserVersionString = nil;

function InitWebView2Loader(const ADllPath: string = ''): Boolean;
function IsWebView2Available: Boolean;

{$ENDIF} // MSWINDOWS

implementation

{$IFDEF MSWINDOWS}
var
  FLoaderHandle: HMODULE = 0;

function InitWebView2Loader(const ADllPath: string = ''): Boolean;
var
  LPath: string;
begin
  if FLoaderHandle <> 0 then
    Exit(True);

  LPath := ADllPath;
  if (LPath <> '') and FileExists(LPath) then
    FLoaderHandle := LoadLibraryW(PWideChar(WideString(LPath)))
  else
    FLoaderHandle := LoadLibraryW('WebView2Loader.dll');

  if FLoaderHandle <> 0 then
  begin
    @CreateCoreWebView2EnvironmentWithOptionsFunc :=
      GetProcAddress(FLoaderHandle, 'CreateCoreWebView2EnvironmentWithOptions');
    @GetAvailableCoreWebView2BrowserVersionStringFunc :=
      GetProcAddress(FLoaderHandle, 'GetAvailableCoreWebView2BrowserVersionString');
    Result := Assigned(CreateCoreWebView2EnvironmentWithOptionsFunc);
  end
  else
    Result := False;
end;

function IsWebView2Available: Boolean;
var
  LVersion: LPWSTR;
  hr: HResult;
begin
  Result := False;
  if not Assigned(GetAvailableCoreWebView2BrowserVersionStringFunc) then
  begin
    if not InitWebView2Loader then
      Exit(False);
  end;
  if Assigned(GetAvailableCoreWebView2BrowserVersionStringFunc) then
  begin
    LVersion := nil;
    hr := GetAvailableCoreWebView2BrowserVersionStringFunc(nil, LVersion);
    Result := Succeeded(hr) and (LVersion <> nil);
    if LVersion <> nil then
      CoTaskMemFree(LVersion);
  end;
end;

initialization

finalization
  if FLoaderHandle <> 0 then
  begin
    FreeLibrary(FLoaderHandle);
    FLoaderHandle := 0;
  end;
{$ENDIF} // MSWINDOWS

end.
