{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpdbxconfigvcl                                  }
{                                                       }
{       Configuration dialog for connections            }
{       it stores all info in config files              }
{                                                       }
{       Copyright (c) 1994-2019 Toni Martir             }
{       toni@reportman.es                                   }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{                                                       }
{*******************************************************}

unit rpdbxconfigvcl;

interface

{$I rpconf.inc}

uses Winapi.Windows, Winapi.Messages,
  SysUtils, Classes, Types,
  Graphics, Forms,ComCtrls, ImgList,
  Buttons, ExtCtrls, Controls, StdCtrls,Dialogs,
  rpgraphutilsvcl,rpdatainfo,
{$IFDEF USESQLEXPRESS}
  SQLExpr,
{$IFNDEF DELPHI2009UP}
  DBXpress,
{$ENDIF}
{$ENDIF}
{$IFDEF USEZEOS}
 ZDbcIntfs,ZConnection,
{$ENDIF}
{$IFDEF USEVARIANTS}
 Variants,
{$ENDIF}
{$IFDEF USEIBX}
{$IFDEF DELPHIXE2UP}
 IBX.IBDatabase,
{$ENDIF}
{$IFNDEF DELPHIXE2UP}
 IBDatabase,
{$ENDIF}
{$ENDIF}
  DB,rpmdconsts, ToolWin, System.ImageList, Vcl.VirtualImageList,
{$IFDEF FIREDAC}
  FireDAC.VCLUI.ConnEdit,FireDAC.Comp.Client,
{$ENDIF}
  Vcl.BaseImageCollection, Vcl.ImageCollection, rpdatahttp, Vcl.Menus;

const
 CONTROL_DISTANCEY=5;
 CONTROL_DISTANCEX=10;
 CONTROL_DISTANCEX2=150;
 CONTROL_WIDTHX=200;
 LABEL_INCY=4;
type
  TRpQueuedHubDiscoveryPayload = class(TObject)
  public
    RequestVersion: Integer;
    PopupPoint: TPoint;
    TriggerControl: TControl;
    Databases: TStringList;
    ErrorMessage: string;
    constructor Create;
    destructor Destroy; override;
  end;

  TFRpDBXConfigVCL = class(TForm)
    Panel1: TPanel;
    LDriversFile: TLabel;
    LConnsFile: TLabel;
    EDriversFile: TEdit;
    EConnectionsFile: TEdit;
    ImageList1: TImageList;
    PanelParent: TPanel;
    PanelLeft: TPanel;
    LConnections: TListBox;
    ToolBar1: TToolBar;
    BAdd: TToolButton;
    BDelete: TToolButton;
    ToolButton1: TToolButton;
    BShowProps: TToolButton;
    ToolButton2: TToolButton;
    BConnect: TToolButton;
    ToolButton3: TToolButton;
    BClose: TToolButton;
    Panel2: TPanel;
    ComboDrivers: TComboBox;
    LShowDriver: TLabel;
    ScrollParams: TScrollBox;
    ImageCollection1: TImageCollection;
    VirtualImageList1: TVirtualImageList;
    ToolButton4: TToolButton;
    procedure FormCreate(Sender: TObject);
    procedure ComboDriversClick(Sender: TObject);
    procedure LConnectionsClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BAddClick(Sender: TObject);
    procedure BDeleteClick(Sender: TObject);
    procedure BShowPropsClick(Sender: TObject);
    procedure BConnectClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure BCloseClick(Sender: TObject);
  private
    { Private declarations }
    DriversFile:string;
    params:TStringList;
    connectionname:string;
    FHubDiscoveryRequestVersion: Integer;
{$IFDEF USESQLEXPRESS}
    SQLConnection1: TSQLConnection;
{$ENDIF}
    conadmin:TRpConnAdmin;
    FAgentInfo: TLabel;
    FAgentLink: TLabel;
    procedure WMHubDiscoveryComplete(var Message: TMessage); message WM_USER + 220;
    procedure FreeParamsControls;
    procedure CreateParamsControls;
    procedure AddAgentInfo(ATop: Integer);
    procedure AgentLinkClick(Sender: TObject);
    procedure Edit1Change(Sender:TObject);
    procedure BSelectHubConnectionClick(Sender: TObject);
    procedure HubConnectionMenuItemClick(Sender: TObject);
    // A connection shared with .NET: what it is and its Delphi parameters
    procedure CreateDotNetControls;
    procedure DotNetParamsClick(Sender: TObject);
    procedure UpdateDotNetControls;
    function SelectedConnection: string;
  private
    FDotNetInfo: TLabel;
    FDotNetValues: TLabel;
  public
    { Public declarations }
    ConnectionsFile:string;
  end;

procedure ShowDBXConfig(ConnectionsFile:string='');
function ResolveDbxConnectionDriver(const ADriverName: string): TRpDbDriver;
// The Delphi parameters of a connection of this computer shared with .NET
// (DriverName=ADO.NET, see rpdbxdotnet): asks for them, proposed from the
// .NET ones while they are not defined, and saves them in its Delphi.* keys
// (a password typed goes, ciphered, to the Secret.Password of the
// connection, the one of every program). True when they were saved
function RpEditDotNetConnection(AConnAdmin: TRpConnAdmin;
  const AAlias: string): Boolean;

implementation

{$R *.dfm}

uses System.JSON, rpreport,  rpauthmanager, Vcl.ValEdit, rpdbxdotnet
{$IFDEF MSWINDOWS}
  , rpdatadirect, rpdcintegration
{$ENDIF}
  ;

const
  HTTP_TEST_CONNECTION_TIMEOUT_MS = 10000;

type
  // The Delphi parameters of a connection shared with .NET (built in code)
  TFRpDotNetConnectionVCL = class(TForm)
  private
    FConAdmin: TRpConnAdmin;
    FAlias: string;
    FPasswordName: string;
    FInfo: TLabel;
    FComboDriver: TComboBox;
    FGrid: TValueListEditor;
    FPassword: TEdit;
    procedure BuildControls(const AInfo: string);
    procedure LoadParams(AParams: TStrings);
    procedure CurrentParams(AParams: TStrings; AWithPassword: Boolean);
    procedure ComboDriverChange(Sender: TObject);
    procedure OKClick(Sender: TObject);
  public
    constructor CreateFor(AOwner: TComponent; AConAdmin: TRpConnAdmin;
      const AAlias: string);
  end;

constructor TFRpDotNetConnectionVCL.CreateFor(AOwner: TComponent;
  AConAdmin: TRpConnAdmin; const AAlias: string);
var
  LParams: TStringList;
  LInfo: string;
begin
  inherited CreateNew(AOwner);
  FConAdmin := AConAdmin;
  FAlias := AAlias;
  LParams := TStringList.Create;
  try
    LInfo := RpDotNetSetupText(AAlias, AConAdmin.GetDotNetDescription(AAlias));
    if AConAdmin.DotNetHasDelphiParams(AAlias) then
    begin
      AConAdmin.GetConnectionParams(AAlias, LParams);
      LInfo := LInfo + sLineBreak + SRpDotNetSetupDefined;
    end
    else if AConAdmin.GetDotNetProposedParams(AAlias, LParams) then
      LInfo := LInfo + sLineBreak + SRpDotNetSetupProposed
    else
      LInfo := LInfo + sLineBreak + SRpDotNetSetupNotClear;
    BuildControls(LInfo);
    LoadParams(LParams);
  finally
    LParams.Free;
  end;
end;

procedure TFRpDotNetConnectionVCL.BuildControls(const AInfo: string);
var
  LPanel, LButtons: TPanel;
  LLabel: TLabel;
  LButton: TButton;
begin
  Caption := Format(SRpDotNetSetupTitle, [FAlias]);
  BorderStyle := bsSizeable;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  Width := ScaleDpi(560);
  Height := ScaleDpi(470);
  Constraints.MinWidth := ScaleDpi(420);
  Constraints.MinHeight := ScaleDpi(340);

  FInfo := TLabel.Create(Self);
  FInfo.Parent := Self;
  FInfo.Align := alTop;
  FInfo.AlignWithMargins := True;
  FInfo.Margins.SetBounds(ScaleDpi(10), ScaleDpi(10), ScaleDpi(10), ScaleDpi(6));
  FInfo.WordWrap := True;
  FInfo.ShowAccelChar := False;
  FInfo.Caption := AInfo;

  LPanel := TPanel.Create(Self);
  LPanel.Parent := Self;
  LPanel.Align := alTop;
  LPanel.Top := FInfo.Top + FInfo.Height + 1;
  LPanel.BevelOuter := bvNone;
  LPanel.Height := ScaleDpi(32);
  LLabel := TLabel.Create(Self);
  LLabel.Parent := LPanel;
  LLabel.Caption := SRpDotNetDriver;
  LLabel.SetBounds(ScaleDpi(10), ScaleDpi(8), ScaleDpi(90), ScaleDpi(16));
  FComboDriver := TComboBox.Create(Self);
  FComboDriver.Parent := LPanel;
  FComboDriver.Style := csDropDownList;
  FComboDriver.SetBounds(ScaleDpi(110), ScaleDpi(4), ScaleDpi(220), ScaleDpi(22));
  FComboDriver.OnChange := ComboDriverChange;

  LButtons := TPanel.Create(Self);
  LButtons.Parent := Self;
  LButtons.Align := alBottom;
  LButtons.BevelOuter := bvNone;
  LButtons.Height := ScaleDpi(44);
  // The lowest of the bottom panels
  LButtons.Top := ScaleDpi(10000);
  LButton := TButton.Create(Self);
  LButton.Parent := LButtons;
  LButton.Caption := SRpCancel;
  LButton.Cancel := True;
  LButton.ModalResult := mrCancel;
  LButton.SetBounds(LButtons.Width - ScaleDpi(95), ScaleDpi(9), ScaleDpi(85), ScaleDpi(26));
  LButton.Anchors := [akTop, akRight];
  LButton := TButton.Create(Self);
  LButton.Parent := LButtons;
  LButton.Caption := SRpOk;
  LButton.Default := True;
  LButton.OnClick := OKClick;
  LButton.SetBounds(LButtons.Width - ScaleDpi(186), ScaleDpi(9), ScaleDpi(85), ScaleDpi(26));
  LButton.Anchors := [akTop, akRight];

  LPanel := TPanel.Create(Self);
  LPanel.Parent := Self;
  LPanel.Align := alBottom;
  LPanel.BevelOuter := bvNone;
  LPanel.Height := ScaleDpi(52);
  LPanel.Top := ScaleDpi(5000);
  LLabel := TLabel.Create(Self);
  LLabel.Parent := LPanel;
  LLabel.Caption := SRpDotNetPassword;
  LLabel.SetBounds(ScaleDpi(10), ScaleDpi(10), ScaleDpi(90), ScaleDpi(16));
  FPassword := TEdit.Create(Self);
  FPassword.Parent := LPanel;
  FPassword.PasswordChar := '*';
  FPassword.SetBounds(ScaleDpi(110), ScaleDpi(6), ScaleDpi(220), ScaleDpi(22));
  LLabel := TLabel.Create(Self);
  LLabel.Parent := LPanel;
  LLabel.ShowAccelChar := False;
  if RpDpapiAvailable then
    LLabel.Caption := SRpDotNetPasswordKept
  else
    LLabel.Caption := SRpDotNetPasswordNotKept;
  LLabel.SetBounds(ScaleDpi(110), ScaleDpi(32), ScaleDpi(420), ScaleDpi(16));

  FGrid := TValueListEditor.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.AlignWithMargins := True;
  FGrid.Margins.SetBounds(ScaleDpi(10), ScaleDpi(4), ScaleDpi(10), ScaleDpi(4));
  FGrid.TitleCaptions[0] := SRpDotNetParameter;
  FGrid.TitleCaptions[1] := SRpDotNetValue;
  FGrid.KeyOptions := [keyEdit, keyAdd, keyDelete, keyUnique];
  FGrid.ColWidths[0] := ScaleDpi(170);
end;

procedure TFRpDotNetConnectionVCL.LoadParams(AParams: TStrings);
var
  I: Integer;
  LName, LDriver: string;
begin
  LDriver := Trim(AParams.Values['DriverName']);
  RpDotNetDelphiDrivers(FConAdmin.drivers, LDriver, FComboDriver.Items);
  FComboDriver.ItemIndex := FComboDriver.Items.IndexOf(LDriver);
  if FComboDriver.ItemIndex < 0 then
    FComboDriver.ItemIndex := 0;
  FGrid.Strings.Clear;
  FPasswordName := '';
  for I := 0 to AParams.Count - 1 do
  begin
    LName := Trim(AParams.Names[I]);
    if (LName = '') or SameText(LName, 'DriverName') then
      Continue;
    if RpIsPasswordParamName(LName) then
    begin
      // The password goes in its own box, hidden
      if FPasswordName = '' then
      begin
        FPasswordName := LName;
        FPassword.Text := AParams.ValueFromIndex[I];
      end;
      Continue;
    end;
    FGrid.Strings.Add(LName + '=' + AParams.ValueFromIndex[I]);
  end;
  if FPasswordName = '' then
    FPasswordName := 'Password';
end;

procedure TFRpDotNetConnectionVCL.CurrentParams(AParams: TStrings;
  AWithPassword: Boolean);
var
  I: Integer;
begin
  AParams.Clear;
  AParams.Add('DriverName=' + FComboDriver.Text);
  for I := 0 to FGrid.Strings.Count - 1 do
    if Trim(FGrid.Strings.Names[I]) <> '' then
      AParams.Add(Trim(FGrid.Strings.Names[I]) + '=' + FGrid.Strings.ValueFromIndex[I]);
  if AWithPassword and (FPassword.Text <> '') then
    AParams.Add(FPasswordName + '=' + FPassword.Text);
end;

procedure TFRpDotNetConnectionVCL.ComboDriverChange(Sender: TObject);
var
  LCurrent, LParams: TStringList;
begin
  // The parameters of the driver chosen, with the values typed of the same
  // names
  LCurrent := TStringList.Create;
  LParams := TStringList.Create;
  try
    CurrentParams(LCurrent, False);
    RpDotNetDriverParams(FConAdmin.drivers, FComboDriver.Text, LCurrent, LParams);
    FGrid.Strings.Clear;
    FGrid.Strings.AddStrings(LParams);
  finally
    LParams.Free;
    LCurrent.Free;
  end;
end;

procedure TFRpDotNetConnectionVCL.OKClick(Sender: TObject);
var
  LParams: TStringList;
begin
  LParams := TStringList.Create;
  try
    CurrentParams(LParams, True);
    FConAdmin.SetDotNetDelphiParams(FAlias, LParams);
  finally
    LParams.Free;
  end;
  ModalResult := mrOk;
end;

function RpEditDotNetConnection(AConnAdmin: TRpConnAdmin;
  const AAlias: string): Boolean;
var
  LDialog: TFRpDotNetConnectionVCL;
begin
  Result := False;
  if (AConnAdmin = nil) or not AConnAdmin.IsDotNetConnection(AAlias) then
    Exit;
  LDialog := TFRpDotNetConnectionVCL.CreateFor(Application, AConnAdmin, AAlias);
  try
    Result := LDialog.ShowModal = mrOk;
  finally
    LDialog.Free;
  end;
end;

// The first use of a connection shared with .NET (TRpDatabaseInfoItem.Connect):
// the dialog, only in the thread of the windows
function DotNetConnectionSetupVCL(AConnAdmin: TRpConnAdmin;
  const AAlias: string): Boolean;
begin
  Result := False;
  if TThread.CurrentThread.ThreadID <> MainThreadID then
    Exit;
  Result := RpEditDotNetConnection(AConnAdmin, AAlias);
end;

function ResolveDbxConnectionDriver(const ADriverName: string): TRpDbDriver;
begin
 if SameText(ADriverName, 'FireDac') then
  Result:=rpfiredac
 else if SameText(ADriverName, 'ZeosLib') then
  Result:=rpdatazeos
 else if SameText(ADriverName, 'Interbase') or SameText(ADriverName, 'Firebird') then
  Result:=rpdataibx
 else if SameText(ADriverName, 'Reportman AI Agent') then
  Result:=rpdbHttp
 else
  Result:=rpdatadbexpress;
end;

function ExtractHttpConnectionTestMessage(const AResponseText: string): string;
var
 LResponseJson: TJSONObject;
 LDataJson: TJSONObject;
 LValue: TJSONValue;
begin
 Result := '';
 if Length(Trim(AResponseText)) = 0 then
  Exit;
 LResponseJson := TJSONObject.ParseJSONValue(AResponseText) as TJSONObject;
 try
  if not Assigned(LResponseJson) then
   Exit;
  LDataJson := LResponseJson.Values['data'] as TJSONObject;
  if Assigned(LDataJson) then
  begin
   LValue := LDataJson.Values['message'];
   if Assigned(LValue) then
    Exit(LValue.Value);
  end;
  LValue := LResponseJson.Values['message'];
  if Assigned(LValue) then
   Result := LValue.Value;
 finally
  LResponseJson.Free;
 end;
end;

function BuildHttpConnectionFailureMessage(const AErrorText: string): string;
begin
 Result := 'Agent Connection: Fail' + sLineBreak +
  'Database Connection: Fail';
 if Length(Trim(AErrorText)) > 0 then
  Result := Result + sLineBreak + 'Error: ' + Trim(AErrorText);
end;

function ExecuteHttpConnectionTest(AParams: TStrings; out AMessageText: string): Boolean;
var
 LDatabase: TRpDatabaseHttp;
 LRequestBody: TJSONObject;
 LResponseStream: TStringStream;
{$IFDEF MSWINDOWS}
 LMode: TRpDcConnectionMode;
 LFallback: Boolean;
 LHubDbId: Int64;
{$ENDIF}
begin
 AMessageText := '';
 LDatabase:=TRpDatabaseHttp.Create;
 try
  LDatabase.ApiKey:=AParams.Values['ApiKey'];
  LDatabase.HubDatabaseId:=StrToInt64Def(AParams.Values['HubDatabaseId'],0);
  if (LDatabase.ApiKey='') and (TRpAuthManager.Instance.Token<>'') then
   LDatabase.Token:=TRpAuthManager.Instance.Token;
  LRequestBody:=TJSONObject.Create;
  try
   LRequestBody.AddPair('hubDatabaseId',TJSONNumber.Create(LDatabase.HubDatabaseId));
   LResponseStream:=TStringStream.Create('', TEncoding.UTF8);
   try
    try
     Result:=LDatabase.InternalRequest('api/agent/testconnection',
       LRequestBody,LResponseStream,HTTP_TEST_CONNECTION_TIMEOUT_MS);
     if Result then
     begin
      AMessageText := ExtractHttpConnectionTestMessage(LResponseStream.DataString);
      if Length(Trim(AMessageText)) = 0 then
       AMessageText := 'Agent Connection: Success' + sLineBreak +
        'Database Connection: Success';

{$IFDEF MSWINDOWS}
      // After a successful HTTP test, probe the Direct Channel so
      // the user knows which transport they would actually get when
      // they start using this database. The SetConnected(True)
      // triggers rpdcintegration's hook which negotiates a session
      // through the pool; PeekConnectionMode then reports the live
      // ICE outcome.
      LHubDbId := LDatabase.HubDatabaseId;
      if LHubDbId > 0 then
      try
       LDatabase.Connected := True;
       LMode := GetLastTransportForDatabase(LHubDbId);
       LFallback := DidFallBackToApiForDatabase(LHubDbId);
       AMessageText := AMessageText + sLineBreak +
                        'Transport: ' + FormatTransportMode(LMode, LFallback);
      except
       on E: Exception do
        AMessageText := AMessageText + sLineBreak +
                         'Transport: API (probe failed: ' + E.Message + ')';
      end;
{$ENDIF}
     end;
    except
     on E: Exception do
     begin
      Result := False;
      AMessageText := BuildHttpConnectionFailureMessage(E.Message);
     end;
    end;
   finally
    LResponseStream.Free;
   end;
  finally
   LRequestBody.Free;
  end;
 finally
  LDatabase.Free;
 end;
end;

constructor TRpQueuedHubDiscoveryPayload.Create;
begin
  inherited Create;
  Databases := TStringList.Create;
end;

destructor TRpQueuedHubDiscoveryPayload.Destroy;
begin
  Databases.Free;
  inherited Destroy;
end;


procedure ShowDBXConfig(ConnectionsFile:string);
var
 dia:TFRpDBXCOnfigVCL;
begin
 dia:=TFRpDBXConfigVCL.Create(Application);
 try
  dia.ConnectionsFile:=Trim(ConnectionsFile);
  dia.showmodal;
 finally
  dia.free;
 end;
end;

procedure TFRpDBXConfigVCL.FormCreate(Sender: TObject);
begin
 //ScaleToolBar(toolbar1);
 ConAdmin:=TRpConnAdmin.Create;
{$IFDEF USESQLEXPRESS}
 SQLConnection1:=TSQLConnection.Create(Self);
{$ENDIF}
 LDriversFile.Caption:=TranslateStr(169,LDriversFile.Caption);
 LConnsFile.Caption:=TranslateStr(170,LConnsFile.Caption);
 LShowDriver.Caption:=TranslateStr(171,LShowDriver.Caption);
 BClose.Hint:=TranslateStr(172,BCLose.Hint);
 BShowProps.Hint:=TranslateStr(173,BShowProps.Hint);
 BConnect.Hint:=TranslateStr(174,BConnect.Hint);
 BDelete.Hint:=TranslateStr(175,BDelete.Hint);
 BAdd.Hint:=TranslateStr(176,BAdd.Hint);
 Caption:=TranslateStr(177,Caption);

 params:=TStringList.Create;
 // Read the drivers file
 DriversFile:=COnAdmin.driverfilename;
 EDriversFile.Text:=DriversFile;
 // Read the connections file
 if Length(ConnectionsFile)<1 then
 begin
  Connectionsfile:=ConAdmin.configfilename;
 end;
 EConnectionsFile.Text:=ConnectionsFile;
 // Read the database connections
 ConAdmin.GetDriverNames(ComboDrivers.Items);
 ComboDrivers.Items.Insert(0,SRpAllDriver);
 ComboDrivers.ItemIndex:=0;
 ComboDriversClick(Self);
end;

procedure TFRpDBXConfigVCL.ComboDriversClick(Sender: TObject);
var
 drivername:string;
 i:integer;
begin
 // Load the connections
 if Not Assigned(ConAdmin) then
  exit;
 drivername:=ComboDrivers.Text;
 if drivername=SRpAllDriver then
  drivername:='';
 ConAdmin.GetConnectionNames(LConnections.items,drivername);
 // The connections shared with .NET, marked
 for i:=0 to LConnections.Items.Count-1 do
  LConnections.Items[i]:=ConAdmin.ConnectionDisplayName(LConnections.Items[i]);
 if LConnections.Items.Count>0 then
  LConnections.ItemIndex:=0
 else
  LConnections.ItemIndex:=-1;
 LConnectionsClick(Self);
end;

function TFRpDBXConfigVCL.SelectedConnection: string;
begin
 Result:='';
 if LConnections.ItemIndex>=0 then
  Result:=RpConnectionNameFromDisplay(LConnections.Items[LConnections.ItemIndex]);
end;

procedure TFRpDBXConfigVCL.FreeParamsControls;
var
 i:integer;
begin
 FAgentInfo:=nil;
 FAgentLink:=nil;
 FDotNetInfo:=nil;
 FDotNetValues:=nil;
 i:=0;
 While  ScrollParams.ControlCount>0 do
 begin
  ScrollParams.Controls[i].Free;
 end;
end;

procedure TFRpDBXConfigVCL.CreateParamsControls;
var
 i:integer;
 index:integer;
 label1:TLabel;
 Edit1:TWinControl;
 top:integer;
 alist:TStringList;
begin
 if Not Assigned(ConAdmin) then
  exit;
 // A connection shared with .NET: its Delphi parameters, in their dialog
 if ConAdmin.IsDotNetConnection(connectionname) then
 begin
  CreateDotNetControls;
  exit;
 end;
 alist:=TStringList.create;
 try
  ConAdmin.Drivers.ReadSections(alist);
  top:=CONTROL_DISTANCEY;
  ConAdmin.GetConnectionParams(connectionname,params);
  for i:=0 to params.Count-1 do
  begin
   label1:=TLabel.Create(Self);
   label1.Parent:=ScrollParams;
   label1.Caption:=params.Names[i];
   label1.Top:=Top+ScaleDPi(LABEL_INCY);
   label1.Left:=ScaleDPi(CONTROL_DISTANCEX);
   // It can be a combo with different options
   index:=alist.indexof(params.Names[i]);
   if index<0 then
   begin
    Edit1:=TEdit.Create(Self);
    Edit1.Parent:=ScrollParams;
    TEdit(Edit1).Text:=params.Values[params.Names[i]];
    if AnsiUpperCase(params.Names[i])='DRIVERNAME' then
    begin
     TEdit(Edit1).ReadOnly:=true;
     TEdit(Edit1).Color:=clBtnFace;
    end
    else
     TEdit(Edit1).OnChange:=Edit1Change;
    if AnsiUpperCase(params.Names[i])='PASSWORD' then
     TEdit(Edit1).PasswordChar:='*';
    // Special discovery button for HubDatabaseId
    if AnsiUpperCase(params.Names[i])='HUBDATABASEID' then
    begin
      with TSpeedButton.Create(Self) do
      begin
        Parent := ScrollParams;
        Caption := 'Select Connection...';
        Width := ScaleDPI(130);
        Top := 0; // Will be set after Edit1.Top
        Left := ScrollParams.Width - Width - ScaleDPI(6);
        Anchors := [akRight, akTop];
        OnClick := BSelectHubConnectionClick;
        Tag := i;
      end;
    end;
   end
   else
   begin
    Edit1:=TComboBox.Create(Self);
    Edit1.Parent:=ScrollParams;
    TComboBox(Edit1).Style:=csDropDownList;
    TComboBox(Edit1).Visible:=False;
    TComboBox(Edit1).Parent:=ScrollParams;
    ConAdmin.Drivers.ReadSection(alist.strings[index],TComboBox(Edit1).Items);
    TComboBox(Edit1).Text:=params.Values[params.Names[i]];
    TComboBox(Edit1).ItemIndex:=TComboBox(Edit1).Items.IndexOf(params.Values[params.Names[i]]);
    TComboBox(Edit1).OnChange:=Edit1Change;
   end;

   Edit1.Tag:=i;
   Edit1.Top:=Top;
   Edit1.Left:=ScaleDPi(CONTROL_DISTANCEX2);
   Edit1.Width := ScrollParams.Width-ScaleDPI(30)-ScaleDPi(CONTROL_DISTANCEX2);
   // Shrink if button exists
   if AnsiUpperCase(params.Names[i])='HUBDATABASEID' then
     Edit1.Width := Edit1.Width - ScaleDPI(136);

   Edit1.Anchors := [akLeft,akTop,akRight];
   Edit1.Visible:=True;

   // Fix button top if created
   for index := 0 to ScrollParams.ControlCount - 1 do
     if (ScrollParams.Controls[index] is TSpeedButton) and (ScrollParams.Controls[index].Tag = i) then
     begin
       ScrollParams.Controls[index].Top := Edit1.Top;
       ScrollParams.Controls[index].Height := Edit1.Height;
     end;

   top:=top+Edit1.Height+ScaleDPi(CONTROL_DISTANCEY);
  end;
  if SameText(params.Values['DriverName'],'Reportman AI Agent') then
   AddAgentInfo(top);
 finally
  alist.free;
 end;
end;

// What the Reportman Agent is and its download page, under the parameters
// of an Agent connection or alone when the Agent driver has none yet
procedure TFRpDBXConfigVCL.AddAgentInfo(ATop: Integer);
begin
 FAgentInfo:=TLabel.Create(Self);
 FAgentInfo.Parent:=ScrollParams;
 FAgentInfo.Left:=ScaleDPi(CONTROL_DISTANCEX);
 FAgentInfo.Top:=ATop+ScaleDPi(8);
 FAgentInfo.Width:=ScrollParams.Width-ScaleDPI(30)-ScaleDPi(CONTROL_DISTANCEX);
 FAgentInfo.Anchors:=[akLeft,akTop,akRight];
 FAgentInfo.WordWrap:=True;
 FAgentInfo.ShowAccelChar:=False;
 FAgentInfo.Caption:=TranslateStr(1823,'The Reportman Agent is installed as a service '+
  'on a Windows or Linux computer that can reach your database and gives the designer '+
  'secure access to it through ai.reportman.es.');

 FAgentLink:=TLabel.Create(Self);
 FAgentLink.Parent:=ScrollParams;
 FAgentLink.Left:=FAgentInfo.Left;
 FAgentLink.Top:=FAgentInfo.Top+FAgentInfo.Height+ScaleDPi(4);
 FAgentLink.ShowAccelChar:=False;
 FAgentLink.Caption:=TranslateStr(1822,'Download Reportman Agent');
 FAgentLink.Cursor:=crHandPoint;
 FAgentLink.ParentFont:=False;
 FAgentLink.Font.Color:=clBlue;
 FAgentLink.Font.Style:=[fsUnderline];
 FAgentLink.OnClick:=AgentLinkClick;
end;

procedure TFRpDBXConfigVCL.AgentLinkClick(Sender: TObject);
begin
 TRpAuthManager.Instance.OpenAgentDownloadPage;
end;

// A connection of this computer shared with .NET: what it is, its Delphi
// parameters (read only here) and the button of their dialog
procedure TFRpDBXConfigVCL.CreateDotNetControls;
var
 LButton:TButton;
begin
 FDotNetInfo:=TLabel.Create(Self);
 FDotNetInfo.Parent:=ScrollParams;
 FDotNetInfo.Left:=ScaleDpi(CONTROL_DISTANCEX);
 FDotNetInfo.Top:=ScaleDpi(CONTROL_DISTANCEY);
 FDotNetInfo.Width:=ScrollParams.Width-ScaleDPI(30)-ScaleDpi(CONTROL_DISTANCEX);
 FDotNetInfo.Anchors:=[akLeft,akTop,akRight];
 FDotNetInfo.WordWrap:=True;
 FDotNetInfo.ShowAccelChar:=False;
 FDotNetInfo.Caption:=RpDotNetSetupText(connectionname,
  ConAdmin.GetDotNetDescription(connectionname));

 LButton:=TButton.Create(Self);
 LButton.Parent:=ScrollParams;
 LButton.Caption:=SRpDotNetParamsButton;
 LButton.Left:=FDotNetInfo.Left;
 LButton.Top:=FDotNetInfo.Top+FDotNetInfo.Height+ScaleDpi(8);
 LButton.Width:=ScaleDpi(160);
 LButton.Height:=ScaleDpi(26);
 LButton.OnClick:=DotNetParamsClick;

 FDotNetValues:=TLabel.Create(Self);
 FDotNetValues.Parent:=ScrollParams;
 FDotNetValues.Left:=FDotNetInfo.Left;
 FDotNetValues.Top:=LButton.Top+LButton.Height+ScaleDpi(8);
 FDotNetValues.Width:=FDotNetInfo.Width;
 FDotNetValues.Anchors:=[akLeft,akTop,akRight];
 FDotNetValues.WordWrap:=True;
 FDotNetValues.ShowAccelChar:=False;
 UpdateDotNetControls;
end;

procedure TFRpDBXConfigVCL.UpdateDotNetControls;
var
 LParams:TStringList;
begin
 if FDotNetValues=nil then
  exit;
 if not ConAdmin.DotNetHasDelphiParams(connectionname) then
 begin
  FDotNetValues.Caption:=SRpDotNetNotDefinedYet;
  exit;
 end;
 LParams:=TStringList.Create;
 try
  ConAdmin.GetConnectionParams(connectionname,LParams);
  FDotNetValues.Caption:=RpDotNetParamsText(LParams);
 finally
  LParams.Free;
 end;
end;

procedure TFRpDBXConfigVCL.DotNetParamsClick(Sender: TObject);
begin
 if RpEditDotNetConnection(ConAdmin,connectionname) then
  UpdateDotNetControls;
end;

procedure TFRpDBXConfigVCL.LConnectionsClick(Sender: TObject);
begin
 if LConnections.ItemIndex<0 then
 begin
  FreeParamsControls;
  // No Agent connection yet: tell where the Agent comes from
  ScrollParams.Visible:=(ComboDrivers.ItemIndex>0) and
   SameText(ComboDrivers.Text,'Reportman AI Agent');
  if ScrollParams.Visible then
   AddAgentInfo(0);
  exit;
 end;
 ScrollParams.Visible:=true;
 connectionname:=SelectedConnection;
 FreeParamsControls;
 CreateParamsControls;
end;



procedure TFRpDBXConfigVCL.FormDestroy(Sender: TObject);
begin
 params.Free;
 ConAdmin.free;
end;

procedure TFRpDBXConfigVCL.Edit1Change(Sender:TObject);
var
 paramvalue:string;
 paramname:string;
 conname:string;
 index:integer;
begin
 if Not Assigned(ConAdmin) then
  exit;
 conname:=SelectedConnection;
 paramname:=params.Names[TEdit(Sender).Tag];
 paramvalue:=TEdit(Sender).Text;
 if Length(paramvalue)=0 then
 begin
  index:=params.IndexOfName(paramname);
  if index>=0 then
  begin
   params.Strings[index]:=paramname+'=';
  end;
 end
 else
  params.Values[paramname]:=paramvalue;
 ConAdmin.config.WriteString(conname,paramname,paramvalue);
 ConAdmin.SaveConfig;
end;

procedure TFRpDBXConfigVCL.BAddClick(Sender: TObject);
var
 newname:string;
begin
 if Not Assigned(ConAdmin) then
  exit;
 if ComboDrivers.ItemIndex=0 then
  Raise Exception.Create(SRpSelectDriver);
 newname:=UpperCase(Trim(RpInputBox(SRpNewConnection,SRpConnectionName,'')));
 if Length(newname)<1 then
  exit;
 ConAdmin.AddConnection(newname,ComboDrivers.Text);
 ConAdmin.SaveConfig;
 ComboDriversClick(Self);
 LConnections.ItemIndex:=LConnections.Items.IndexOf(newname);
 LConnectionsClick(Self);
end;

procedure TFRpDBXConfigVCL.BDeleteClick(Sender: TObject);
var
 conname:string;
begin
 if Not Assigned(ConAdmin) then
  exit;
 if LConnections.ItemIndex<0 then
  exit;
 conname:=SelectedConnection;
 // A connection shared with .NET stays: only its Delphi parameters go
 if ConAdmin.IsDotNetConnection(conname) then
 begin
  if smbOk=RpMessageBox(Format(SRpDotNetForget,[conname]),SRpDropConnection,
   [smbok,smbCancel],smsWarning,smbCancel) then
  begin
   ConAdmin.DeleteConnection(conname);
   UpdateDotNetControls;
  end;
  exit;
 end;
 if smbOk=RpMessageBox(SRpSureDropConnection+conname,SRpDropConnection,[smbok,smbCancel],smsWarning,smbCancel) then
 begin
  ConAdmin.DeleteConnection(conname);
  ConAdmin.SaveConfig;
  ComboDriversCLick(Self);
 end;
end;

procedure TFRpDBXConfigVCL.BShowPropsClick(Sender: TObject);
var
 VendorLib,LibraryName:string;
 {$IFDEF FIREDAC}
 FDConnEditor : TfrmFDGUIxFormsConnEdit;
 FDConnection1: TFDConnection;
{$ENDIF}
begin
 if Not Assigned(ConAdmin) then
  exit;
 if ComboDrivers.ItemIndex=0 then
  Raise Exception.Create(SRpSelectDriver);
 if (ComboDrivers.Text = 'FireDac') then
 begin
 {$IFDEF FIREDAC}
  FDConnection1:= TFDConnection.Create(nil);
  FDConnEditor := TfrmFDGUIxFormsConnEdit.Create(Self);
  try
    FDConnEditor.Execute(FDConnection1,SRpSParamList);
  finally
    FDConnEditor.Free;
    FDConnection1.Free;
  end;
{$ENDIF}
 end
 else
 begin
  ConAdmin.GetDriverLibNames(ComboDrivers.Text,LibraryName,VendorLib);
  RpShowMessage(SRpVendorLib+':'+VendorLib+#10+SRpLibraryName+':'+LibraryName);
 end;
end;

procedure TFRpDBXConfigVCL.BConnectClick(Sender: TObject);
var
 conname:string;
 drivername:string;
 alist:TStringList;
 report:TRpReport;
 dbinfo:TRpDatabaseInfoItem;
 LMessageText: string;
begin
 if Not Assigned(ConAdmin) then
  exit;
 if LConnections.ItemIndex<0 then
  Raise Exception.Create(SRpSelectConnectionFirst);
 conname:=SelectedConnection;
 // A connection shared with .NET is tested with its Delphi parameters: asked
 // here the first time (the test reads the file again)
 if ConAdmin.IsDotNetConnection(conname) and
  (not ConAdmin.DotNetHasDelphiParams(conname)) then
 begin
  if not RpEditDotNetConnection(ConAdmin,conname) then
   exit;
  UpdateDotNetControls;
 end;
 alist:=TStringList.Create;
 try
  ConAdmin.GetConnectionParams(conname,alist);
  drivername:=Trim(alist.Values['DriverName']);
    if SameText(drivername,'Reportman AI Agent') then
    begin
     ExecuteHttpConnectionTest(alist, LMessageText);
     if Length(Trim(LMessageText)) = 0 then
      LMessageText := SRpConnectionOk;
     RpShowMessage(LMessageText);
     exit;
    end;
 finally
  alist.Free;
 end;

 report:=TRpReport.Create(nil);
 try
  if Length(Trim(ConnectionsFile))>0 then
   report.Params.Add('DBXCONNECTIONS').AsString:=Trim(ConnectionsFile);
  if Length(Trim(DriversFile))>0 then
   report.Params.Add('DBXDRIVERS').AsString:=Trim(DriversFile);
  dbinfo:=report.DatabaseInfo.Add(conname);
  dbinfo.Driver:=ResolveDbxConnectionDriver(drivername);
  dbinfo.LoginPrompt:=False;
    dbinfo.Connect(nil);
  try
   RpShowMessage(SRpConnectionOk);
  finally
   dbinfo.DisConnect;
  end;
 finally
  report.Free;
 end;
end;

procedure TFRpDBXConfigVCL.FormClose(Sender: TObject; var Action: TCloseAction);
begin
 try
  if Assigned(ConAdmin) then
   ConAdmin.SaveConfig;
//  UpdateConAdmin;
 except
  on E:Exception do
  begin
   RpMessageBox(E.MEssage);
  end;
 end;
{$IFDEF MSWINDOWS}
 // The user may have changed connection settings (e.g. ApiKey or
 // HubDatabaseId). Invalidate the cached Direct Channel sessions so the next
 // data fetch / report run re-authenticates with the new values instead of
 // reusing a stale pooled channel until the application is restarted.
 try
  ResetHubChannelPool;
 except
  on E:Exception do ; // never let cache cleanup block closing the dialog
 end;
{$ENDIF}
end;


procedure TFRpDBXConfigVCL.BCloseClick(Sender: TObject);
begin
 Close;
end;

procedure TFRpDBXConfigVCL.BSelectHubConnectionClick(Sender: TObject);
var
  LApiKey: string;
  LButton: TSpeedButton;
  LPopupPoint: TPoint;
  LRequestVersion: Integer;
  LWorker: TThread;
  i: Integer;
begin
  LApiKey := '';
  // Find ApiKey value in other edits
  for i := 0 to ScrollParams.ControlCount - 1 do
  begin
    if (ScrollParams.Controls[i] is TEdit) and
       (AnsiUpperCase(params.Names[ScrollParams.Controls[i].Tag]) = 'APIKEY') then
    begin
      LApiKey := TEdit(ScrollParams.Controls[i]).Text;
      break;
    end;
  end;

  // Without a key the Hub lists the example databases, for everybody, and
  // those of the user signed in: only a key too short to be one is refused
  LApiKey := Trim(LApiKey);
  if (LApiKey <> '') and (Length(LApiKey) < 5) then
  begin
    RpShowMessage('Please enter a valid API Key first.');
    Exit;
  end;

  if not (Sender is TSpeedButton) then
    Exit;

  LButton := TSpeedButton(Sender);
  LPopupPoint := LButton.ClientToScreen(Point(0, LButton.Height));
  Inc(FHubDiscoveryRequestVersion);
  LRequestVersion := FHubDiscoveryRequestVersion;

  LButton.Enabled := False;
  LButton.Caption := 'Loading...';

  LWorker := TThread.CreateAnonymousThread(
    procedure
    var
      LPayload: TRpQueuedHubDiscoveryPayload;
    begin
      LPayload := TRpQueuedHubDiscoveryPayload.Create;
      try
        LPayload.RequestVersion := LRequestVersion;
        LPayload.PopupPoint := LPopupPoint;
        LPayload.TriggerControl := LButton;
        try
          if not TRpDatabaseHttp.GetHubDatabases(LApiKey, LPayload.Databases) then
            LPayload.ErrorMessage := 'Failed to connect to Hub for discovery. Check your API Key and internet connection.';
        except
          on E: Exception do
            LPayload.ErrorMessage := E.Message;
        end;

        if HandleAllocated then
        begin
          if not PostMessage(Handle, WM_USER + 220, WPARAM(LPayload), 0) then
            LPayload.Free;
        end
        else
          LPayload.Free;
      except
        LPayload.Free;
      end;
    end);
  LWorker.FreeOnTerminate := True;
  LWorker.Start;
end;

procedure TFRpDBXConfigVCL.WMHubDiscoveryComplete(var Message: TMessage);
var
  LPayload: TRpQueuedHubDiscoveryPayload;
  LPopupMenu: TPopupMenu;
  LMenuItem: TMenuItem;
  I: Integer;
begin
  LPayload := TRpQueuedHubDiscoveryPayload(Message.WParam);
  try
    if LPayload = nil then
      Exit;
    if LPayload.RequestVersion <> FHubDiscoveryRequestVersion then
      Exit;

    if Assigned(LPayload.TriggerControl) and (LPayload.TriggerControl is TSpeedButton) then
    begin
      TSpeedButton(LPayload.TriggerControl).Enabled := True;
      TSpeedButton(LPayload.TriggerControl).Caption := 'Select Connection...';
    end;

    if LPayload.ErrorMessage <> '' then
    begin
      RpShowMessage(LPayload.ErrorMessage);
      Exit;
    end;

    if LPayload.Databases.Count = 0 then
    begin
      RpShowMessage('No databases found for this API Key.');
      Exit;
    end;

    LPopupMenu := TPopupMenu.Create(Self);
    for I := 0 to LPayload.Databases.Count - 1 do
    begin
      LMenuItem := TMenuItem.Create(LPopupMenu);
      LMenuItem.Caption := LPayload.Databases.Names[I];
      // An example database: for everybody, read-only
      if RpHubLineIsExample(LPayload.Databases.ValueFromIndex[I],
        RpHubDatabaseExampleField) then
        LMenuItem.Caption := LMenuItem.Caption + ' (' + RpHubExampleBadge + ')';
      // The id, before the state of the Agent (RpHubDatabaseLine)
      LMenuItem.Hint := RpHubLineField(LPayload.Databases.ValueFromIndex[I], 0);
      LMenuItem.Tag := StrToIntDef(LMenuItem.Hint, 0);
      LMenuItem.OnClick := HubConnectionMenuItemClick;
      LPopupMenu.Items.Add(LMenuItem);
    end;
    LPopupMenu.Popup(LPayload.PopupPoint.X, LPayload.PopupPoint.Y);
  finally
    LPayload.Free;
  end;
end;

procedure TFRpDBXConfigVCL.HubConnectionMenuItemClick(Sender: TObject);
var
  LId: Integer;
  j: Integer;
begin
  LId := TMenuItem(Sender).Tag;
  for j := 0 to ScrollParams.ControlCount - 1 do
  begin
     if (ScrollParams.Controls[j] is TEdit) and
        (AnsiUpperCase(params.Names[ScrollParams.Controls[j].Tag]) = 'HUBDATABASEID') then
     begin
       TEdit(ScrollParams.Controls[j]).Text := IntToStr(LId);
       Edit1Change(ScrollParams.Controls[j]);
       break;
     end;
  end;
end;

initialization
 // The engine asks the designer for the Delphi parameters of a connection
 // shared with .NET used for the first time
 RpDotNetConnectionSetup:=DotNetConnectionSetupVCL;
end.
