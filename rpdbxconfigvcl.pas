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
    procedure WMHubDiscoveryComplete(var Message: TMessage); message WM_USER + 220;
    procedure FreeParamsControls;
    procedure CreateParamsControls;
    procedure Edit1Change(Sender:TObject);
    procedure BSelectHubConnectionClick(Sender: TObject);
    procedure HubConnectionMenuItemClick(Sender: TObject);
  public
    { Public declarations }
    ConnectionsFile:string;
  end;

procedure ShowDBXConfig(ConnectionsFile:string='');

implementation

{$R *.dfm}

uses System.JSON, rpreport, rpdatahttp, rpauthmanager;

const
  HTTP_TEST_CONNECTION_TIMEOUT_MS = 10000;

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

function ExecuteHttpConnectionTest(AParams: TStrings): Boolean;
var
 LDatabase: TRpDatabaseHttp;
 LRequestBody: TJSONObject;
 LResponseStream: TMemoryStream;
begin
 Result:=False;
 LDatabase:=TRpDatabaseHttp.Create;
 try
  LDatabase.ApiKey:=AParams.Values['ApiKey'];
  LDatabase.HubDatabaseId:=StrToInt64Def(AParams.Values['HubDatabaseId'],0);
  if (LDatabase.ApiKey='') and (TRpAuthManager.Instance.Token<>'') then
   LDatabase.Token:=TRpAuthManager.Instance.Token;
  LRequestBody:=TJSONObject.Create;
  try
   LRequestBody.AddPair('hubDatabaseId',TJSONNumber.Create(LDatabase.HubDatabaseId));
   LResponseStream:=TMemoryStream.Create;
   try
    Result:=LDatabase.InternalRequest('api/agent/testconnection',
      LRequestBody,LResponseStream,HTTP_TEST_CONNECTION_TIMEOUT_MS);
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
begin
 // Load the connections
 if Not Assigned(ConAdmin) then
  exit;
 drivername:=ComboDrivers.Text;
 if drivername=SRpAllDriver then
  drivername:='';
 ConAdmin.GetConnectionNames(LConnections.items,drivername);
 if LConnections.Items.Count>0 then
  LConnections.ItemIndex:=0
 else
  LConnections.ItemIndex:=-1;
 LConnectionsClick(Self);
end;


procedure TFRpDBXConfigVCL.FreeParamsControls;
var
 i:integer;
begin
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
 finally
  alist.free;
 end;
end;

procedure TFRpDBXConfigVCL.LConnectionsClick(Sender: TObject);
begin
 if LConnections.ItemIndex<0 then
 begin
  ScrollParams.Visible:=false;
  exit;
 end;
 ScrollParams.Visible:=true;
 connectionname:=LConnections.Items.strings[LConnections.ItemIndex];
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
 conname:=LConnections.Items.Strings[LConnections.ItemIndex];
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
 ConAdmin.config.UpdateFile;
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
 ConAdmin.config.UpdateFile;
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
 conname:=LConnections.Items.Strings[LConnections.ItemIndex];
 if smbOk=RpMessageBox(SRpSureDropConnection+conname,SRpDropConnection,[smbok,smbCancel],smsWarning,smbCancel) then
 begin
  ConAdmin.DeleteConnection(conname);
  ConAdmin.Config.UpdateFile;
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
begin
 if Not Assigned(ConAdmin) then
  exit;
 if LConnections.ItemIndex<0 then
  Raise Exception.Create(SRpSelectConnectionFirst);
 conname:=LConnections.Items.strings[Lconnections.itemindex];
 alist:=TStringList.Create;
 try
  ConAdmin.GetConnectionParams(conname,alist);
  drivername:=Trim(alist.Values['DriverName']);
    if SameText(drivername,'Reportman AI Agent') then
    begin
     if ExecuteHttpConnectionTest(alist) then
      RpShowMessage(SRpConnectionOk);
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
   ConAdmin.Config.UpdateFile;
//  UpdateConAdmin;
 except
  on E:Exception do
  begin
   RpMessageBox(E.MEssage);
  end;
 end;
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

  if Length(LApiKey) < 5 then
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
      LMenuItem.Hint := LPayload.Databases.ValueFromIndex[I];
      LMenuItem.Tag := StrToIntDef(LPayload.Databases.ValueFromIndex[I], 0);
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

end.
