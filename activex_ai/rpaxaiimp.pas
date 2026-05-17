unit rpaxaiimp;

interface

uses
  Winapi.Windows, WinApi.ActiveX, System.SysUtils, System.Classes, VCl.Controls, VCL.Graphics,
  VCL.Menus, VCL.Forms,System.Win.ComObj,
  System.Win.ComServ, VCl.StdCtrls, VCL.AXCtrls, activex_ai_TLB, rpaiactivexcontrol;

type
  TReportmanAIActiveX = class(TActiveXControl, IReportmanAIActiveX)
  private
    FDelphiControl: TRpAIActiveXControl;
    FEvents: IReportmanAIActiveXEvents;
    procedure DoNavigationStarting(Sender: TObject; const AUrl: WideString);
    procedure DoNavigationCompleted(Sender: TObject; const AUrl: WideString);
    procedure DoMessageReceived(Sender: TObject; const AMessage: WideString);
    procedure DoHostError(Sender: TObject; const AMessage: WideString);
  protected
    procedure DefinePropertyPages(DefinePropertyPage: TDefinePropertyPage); override;
    procedure EventSinkChanged(const EventSink: IUnknown); override;
    procedure InitializeControl; override;
    function Get_Url: WideString; safecall;
    procedure Set_Url(const Value: WideString); safecall;
    function Get_ProfileName: WideString; safecall;
    procedure Set_ProfileName(const Value: WideString); safecall;
    function Get_CanGoBack: WordBool; safecall;
    function Get_CanGoForward: WordBool; safecall;
    function Get_Version: WideString; safecall;
    procedure Navigate(const url: WideString); safecall;
    procedure Reload; safecall;
    procedure GoBack; safecall;
    procedure GoForward; safecall;
    procedure ExecuteScript(const script: WideString); safecall;
    procedure RetryInitialize; safecall;
  end;

implementation

procedure TReportmanAIActiveX.DefinePropertyPages(
  DefinePropertyPage: TDefinePropertyPage);
begin
end;

procedure TReportmanAIActiveX.EventSinkChanged(const EventSink: IUnknown);
begin
  FEvents := EventSink as IReportmanAIActiveXEvents;
end;

procedure TReportmanAIActiveX.InitializeControl;
begin
  FDelphiControl := Control as TRpAIActiveXControl;
  FDelphiControl.OnNavigationStarting := DoNavigationStarting;
  FDelphiControl.OnNavigationCompleted := DoNavigationCompleted;
  FDelphiControl.OnMessageReceived := DoMessageReceived;
  FDelphiControl.OnHostError := DoHostError;
end;

function TReportmanAIActiveX.Get_Url: WideString;
begin
  Result := WideString(FDelphiControl.Url);
end;

procedure TReportmanAIActiveX.Set_Url(const Value: WideString);
begin
  FDelphiControl.Url := string(Value);
end;

function TReportmanAIActiveX.Get_ProfileName: WideString;
begin
  Result := WideString(FDelphiControl.ProfileName);
end;

procedure TReportmanAIActiveX.Set_ProfileName(const Value: WideString);
begin
  FDelphiControl.ProfileName := string(Value);
end;

function TReportmanAIActiveX.Get_CanGoBack: WordBool;
begin
  Result := FDelphiControl.CanGoBack;
end;

function TReportmanAIActiveX.Get_CanGoForward: WordBool;
begin
  Result := FDelphiControl.CanGoForward;
end;

function TReportmanAIActiveX.Get_Version: WideString;
begin
  Result := WideString(FDelphiControl.Version);
end;

procedure TReportmanAIActiveX.Navigate(const url: WideString);
begin
  FDelphiControl.Navigate(string(url));
end;

procedure TReportmanAIActiveX.Reload;
begin
  FDelphiControl.Reload;
end;

procedure TReportmanAIActiveX.GoBack;
begin
  FDelphiControl.GoBack;
end;

procedure TReportmanAIActiveX.GoForward;
begin
  FDelphiControl.GoForward;
end;

procedure TReportmanAIActiveX.ExecuteScript(const script: WideString);
begin
  FDelphiControl.ExecuteScript(string(script));
end;

procedure TReportmanAIActiveX.RetryInitialize;
begin
  FDelphiControl.RetryInitialize;
end;

procedure TReportmanAIActiveX.DoNavigationStarting(Sender: TObject;
  const AUrl: WideString);
begin
  if FEvents <> nil then
    FEvents.NavigationStarting(AUrl);
end;

procedure TReportmanAIActiveX.DoNavigationCompleted(Sender: TObject;
  const AUrl: WideString);
begin
  if FEvents <> nil then
    FEvents.NavigationCompleted(AUrl);
end;

procedure TReportmanAIActiveX.DoMessageReceived(Sender: TObject;
  const AMessage: WideString);
begin
  if FEvents <> nil then
    FEvents.MessageReceived(AMessage);
end;

procedure TReportmanAIActiveX.DoHostError(Sender: TObject;
  const AMessage: WideString);
begin
  if FEvents <> nil then
    FEvents.HostError(AMessage);
end;

initialization
  TActiveXControlFactory.Create(
    ComServer,
    TReportmanAIActiveX,
    TRpAIActiveXControl,
    CLASS_ReportmanAIActiveX,
    1,
    '',
    0,
    tmSingle);

end.