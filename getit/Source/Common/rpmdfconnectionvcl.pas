{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpmdfconnectionvcl                              }
{                                                       }
{       Connections definition frame                    }
{                                                       }
{       Copyright (c) 1994-2013 Toni Martir             }
{       toni@reportman.es                                   }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{                                                       }
{*******************************************************}

unit rpmdfconnectionvcl;

interface

{$I rpconf.inc}

uses
  Windows, Messages, SysUtils,rptypes,
{$IFDEF USEVARIANTS}
  Variants,
{$ENDIF}
  Classes, Graphics, Controls, Forms,rpreport,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, ToolWin, ActnList, ImgList,
{$IFDEF USEBDE}
  dbtables,
{$ENDIF}
{$IFDEF USEADO}
  Data.Win.adodb,
{$ENDIF}
  rpdatainfo,rpmdconsts,rpparams,
//  DBConnAdmin,
  rpgraphutilsvcl,rpdbxconfigvcl,
  Menus, System.Actions, System.ImageList, Vcl.VirtualImageList,
  Vcl.BaseImageCollection, Vcl.ImageCollection;

type
  TFRpConnectionVCL = class(TFrame)
    ImageList1: TImageList;
    ActionList1: TActionList;
    ANewConnection: TAction;
    ADelete: TAction;
    ToolBar1: TToolBar;
    BNew: TToolButton;
    ToolButton5: TToolButton;
    ToolButton4: TToolButton;
    ToolButton6: TToolButton;
    PParent: TPanel;
    PanelProps: TPanel;
    PopAdd: TPopupMenu;
    MNew: TMenuItem;
    PTop: TPanel;
    GDriver: TListBox;
    PDriver: TPanel;
    MHelp: TMemo;
    Panel1: TPanel;
    BConfig: TButton;
    GAvailable: TGroupBox;
    LConnections: TListBox;
    PConProps: TPanel;
    LConnectionString: TLabel;
    LAvailable: TLabel;
    LDriver: TLabel;
    CheckLoginPrompt: TCheckBox;
    CheckLoadParams: TCheckBox;
    CheckLoadDriverParams: TCheckBox;
    EConnectionString: TEdit;
    ComboAvailable: TComboBox;
    BBuild: TButton;
    ComboDriver: TComboBox;
    BTest: TButton;
    ComboNetDriver: TComboBox;
    LDotNetDriver: TLabel;
    ImageCollection1: TImageCollection;
    VirtualImageList1: TVirtualImageList;
    procedure GDriverClick(Sender: TObject);
    procedure LConnectionsClick(Sender: TObject);
    procedure BNewClick(Sender: TObject);
    procedure MNewClick(Sender: TObject);
    procedure BConfigClick(Sender: TObject);
    procedure BBuildClick(Sender: TObject);
    procedure ANewConnectionExecute(Sender: TObject);
    procedure PopAddPopup(Sender: TObject);
    procedure ADeleteExecute(Sender: TObject);
    procedure ComboDriverClick(Sender: TObject);
    procedure BTestClick(Sender: TObject);
    procedure CheckLoginPromptClick(Sender: TObject);
    procedure EConnectionStringChange(Sender: TObject);
    procedure FrameResize(Sender: TObject);
  private
    { Private declarations }
    conadmin:TRpCOnnAdmin;
    FDatabaseInfo:TRpDatabaseInfoList;
    report:TRpReport;
    FParams:TRpParamList;
    FLoadingControls:Boolean;
    procedure AssertCanModify(const AReason:string);
    procedure SetDatabaseInfo(Value:TRpDatabaseInfoList);
    procedure SetParams(Value:TRpParamList);
    procedure MenuAddClick(Sender:TObject);
    function ResolveAvailableConnectionDriver(const AConnectionName: string;
     ADefaultDriver: TRpDbDriver): TRpDbDriver;
    function FindDatabaseInfoItem:TRpDatabaseInfoItem;
  private
    // Connection wizard: "Add connection" above the toolbar, the same button
    // in the middle while there are no connections, and "Configure with the
    // wizard" for a Reportman AI Agent connection not configured here
    FWandImages: TVirtualImageList;
    FWandImagesLarge: TVirtualImageList;
    PWizard: TPanel;
    BWizard: TButton;
    PEmpty: TPanel;
    BWizardEmpty: TButton;
    LWizardHint: TLabel;
    LAgentProblem: TLabel;
    BWizardConfigure: TButton;
    procedure BuildWizardControls;
    procedure PEmptyResize(Sender: TObject);
    procedure LayoutAgentProblem;
    procedure BWizardClick(Sender: TObject);
    procedure BWizardConfigureClick(Sender: TObject);
    procedure ReloadConnAdmin;
    procedure AddWizardConnection(const AName: string; ADriver: TRpDbDriver;
      const AAdoConnectionString: string);
    procedure UpdateWizardState;
  public
    { Public declarations }
    constructor Create(AOwner:TComponent);override;
    destructor Destroy;override;
    procedure SetBlockChangesSource(AReport:TRpReport);
    property Databaseinfo:TRpDatabaseInfoList read FDatabaseinfo
     write SetDatabaseInfo;
    property Params:TRpParamList read FParams write
     SetParams;
  end;

implementation

uses rpxmlstream, rpbasereport, rpmdfnewreportwizardvcl;

{$R *.dfm}

constructor TFRpConnectionVCL.Create(AOwner:TComponent);
begin
 inherited Create(AOwner);
 // ScaleToolBar(toolbar1);
 //Align := alClient;

 LDotNetDriver.Caption:=SRpDriverDotNet;
  // Translations
 BConfig.Caption:=TranslateStr(143,BConfig.Caption);
 CheckLoginPrompt.Caption:=TranslateStr(144,CheckLoginPrompt.Caption);
 CheckLoadParams.Caption:=TranslateStr(145,CheckLoadParams.Caption);
 CheckLoadDriverParams.Caption:=TranslateStr(146,CheckLoadDriverParams.Caption);
 BTest.Caption:=TranslateStr(753,BTest.Caption);
 BBuild.Caption:=TranslateStr(168,BBuild.Caption);

 GAvailable.Caption:=TranslateStr(1098,GAvailable.Caption);
 LConnectionString.Caption:=TranslateStr(1099,LConnectionString.Caption);
 LAvailable.Caption:=TranslateStr(1100,LAvailable.Caption);
 LDriver.Caption:=TranslateStr(1101,LDriver.Caption);
 MNew.Caption:=TranslateStr(40,MNew.Caption);
 ANewConnection.Caption:=TranslateStr(1102,ANewConnection.Caption);
 ANewConnection.Hint:=TranslateStr(1103,ANewConnection.Hint);
 ADelete.Caption:=TranslateStr(1104,ADelete.Caption);
 ADelete.Hint:=TranslateStr(1105,ADelete.Hint);

 GetRpDatabaseDrivers(GDriver.Items);
 GetRpDatabaseDrivers(ComboDriver.Items);


 ConAdmin:=TRpConnAdmin.Create;

 report:=TRPReport.Create(Self);
 FLoadingControls:=False;
 FDatabaseInfo:=report.databaseinfo;
 FParams:=report.Params;

 GDriver.ItemIndex:=0;
 GDriverClick(Self);
 BuildWizardControls;
end;

destructor TFRpConnectionVCL.Destroy;
begin
 conadmin.free;
 inherited destroy;
end;

procedure TFRpConnectionVCL.SetParams(Value:TRpParamList);
begin
 FParams.Assign(Value);
end;

procedure TFRpConnectionVCL.SetBlockChangesSource(AReport:TRpReport);
begin
 report.BlockChangesSource:=AReport;
end;

procedure TFRpConnectionVCL.AssertCanModify(const AReason:string);
begin
 if Assigned(report) then
  report.AssertCanModify(AReason);
end;

procedure TFRpConnectionVCL.SetDatabaseInfo(Value:TRpDatabaseInfoList);
var
 i:integer;
begin
 ComboDriver.Width:=PConProps.Width-ComboDriver.Left-20;
 ComboNetDriver.Width:=PConProps.Width-ComboNetDriver.Left-20;
 EConnectionString.Width:=PConProps.Width-ECOnnectionString.Left-20;
 ComboAvailable.Width:=PConProps.Width-ComboAvailable.Left-20;
 ComboDriver.Anchors:=[akLeft,akTop,akRight];
 ComboNetDriver.Anchors:=[akLeft,akTop,akRight];
 ComboAvailable.Anchors:=[akLeft,akTop,akRight];
 EConnectionString.Anchors:=[akLeft,akTop,akRight];

 FLoadingControls:=True;
 try
  if Value<>FDatabaseInfo then
   FDatabaseInfo.Assign(Value);
  LConnections.Clear;
  for i:=0 to FDatabaseinfo.Count-1 do
  begin
   LConnections.Items.Add(FDatabaseinfo.Items[i].Alias);
  end;
  if LConnections.Items.Count>0 then
   LConnections.ItemIndex:=0;
  LConnectionsClick(Self);
  GDriverClick(Self);
 finally
  FLoadingControls:=False;
 end;
end;

procedure TFRpConnectionVCL.LConnectionsClick(Sender: TObject);
var
 dbinfo:TRpDatabaseInfoItem;
 index:integer;
 oldloading:Boolean;
begin
 if Not Assigned(FDatabaseInfo) then
  exit;
 UpdateWizardState;
 If LConnections.Items.Count<1 then
 begin
  MHelp.Text:=SRpNewDatabaseInfo;
  CheckLoginPrompt.Visible:=False;
  LDotNetDriver.Visible:=False;
  ComboNetDriver.Visible:=False;
  CheckLoadParams.Visible:=False;
  CheckLoadDriverParams.Visible:=False;
  LConnectionString.Visible:=False;
  EConnectionString.Visible:=false;
  BBuild.Visible:=false;
  BTest.Visible:=false;
  ComboDriver.Visible:=false;
  LDriver.Visible:=false;
  Exit;
 end;
 If LConnections.ItemIndex<0 then
  exit;
 index:=FDatabaseInfo.IndexOf(LConnections.Items[LConnections.ItemIndex]);
 if index<0 then
  exit;
 CheckLoginPrompt.Visible:=True;
 CheckLoadParams.Visible:=True;
 LDotNetDriver.Visible:=true;
 ComboNetDriver.Visible:=true;
 BTest.Visible:=True;
 CheckLoadDriverParams.Visible:=True;
 ComboDriver.Visible:=true;
 LDriver.Visible:=true;
 // Get information about the dabaseinfo
 dbinfo:=FDatabaseinfo.Items[index];
 oldloading:=FLoadingControls;
 FLoadingControls:=True;
 try
  ComboDriver.ItemIndex:=Integer(dbinfo.Driver);
  ComboDriverClick(Self);
  CheckLoginPrompt.Checked:=dbinfo.LoginPrompt;
  if (dbinfo.Driver=rpdataDriver) then
   ComboNetDriver.ItemIndex:=dbinfo.DotNetDriver
  else
  if (dbinfo.Driver=rpdotnet2Driver) then
   ComboNetDriver.Text:=dbinfo.ProviderFactory;
  CheckLoadParams.Checked:=dbinfo.LoadParams;
  CheckLoadDriverParams.Checked:=dbinfo.LoadDriverParams;
  EConnectionString.OnChange:=nil;
  EConnectionString.Text:=EnCodeADOPassword(dbinfo.ADOConnectionString);
  EConnectionString.OnChange:=EConnectionStringChange;
 finally
  FLoadingControls:=oldloading;
 end;
end;

procedure TFRpConnectionVCL.GDriverClick(Sender: TObject);
var
 index:integer;
begin
 if Not Assigned(FDatabaseInfo) then
  exit;
 index := GDriver.ItemIndex;
 if (index = 7) then
  index :=8 ;
 case index of
  0:
   MHelp.Lines.Text:=SRpDBExpressDesc;
  1:
   MHelp.Lines.Text:=SRpMyBaseDesc;
  2:
   MHelp.Lines.Text:=SRpIBXDesc;
  3:
   MHelp.Lines.Text:=SRpBDEDesc;
  4:
   MHelp.Lines.Text:=SRpADODesc;
  5:
   MHelp.Lines.Text:=SRpIBODesc;
  6:
   MHelp.Lines.Text:=SrpDriverZeosDesc;
  8:
   MHelp.Lines.Text:=SRpDriverDotNetDesc;
  9:
   MHelp.Lines.Text:=SRpFireDacDesc;
  10:
   MHelp.Lines.Text:='Executes SQL remotely via Reportman AI Agent bridge. ' +
    'Supports secure, non-interactive queries with API Keys.';
 end;
 // Loads the alias config
 case TrpDbDriver(index) of
  // DBExpress
  rpdatadbexpress:
   begin
    BConfig.Visible:=true;
    if Assigned(ConAdmin) then
    begin
     conadmin.GetConnectionNames(ComboAvailable.Items,'');
    end;
   end;
  // IBX and IBO
  rpdataibx,rpdataibo:
   begin
    BConfig.Visible:=true;
    if Assigned(ConAdmin) then
    begin
     conadmin.GetConnectionNames(ComboAvailable.Items,'Interbase');
    end;
   end;
  // Zeos: the ZeosLib connections of the connections file
  rpdatazeos:
   begin
    BConfig.Visible:=true;
    if Assigned(ConAdmin) then
    begin
     conadmin.GetConnectionNames(ComboAvailable.Items,'ZeosLib');
    end;
   end;
  // FireDac: its connections (the list kept the previous driver ones)
  rpfiredac:
   begin
    BConfig.Visible:=true;
    if Assigned(ConAdmin) then
    begin
     conadmin.GetConnectionNames(ComboAvailable.Items,'FireDac');
    end;
   end;
  // My Base
  rpdatamybase:
   begin
    BConfig.Visible:=true;
    ComboAvailable.Items.Clear;
   end;
  // BDE
  rpdatabde:
   begin
{$IFDEF USEBDE}
    BConfig.Visible:=true;
    Session.GetAliasNames(ComboAvailable.Items);
{$ENDIF}
   end;
  // ADO
  rpdataado:
   begin
{$IFDEF MSWINDOWS}
    BConfig.Visible:=false;
    BBuild.Visible:=false;
    ComboAvailable.Items.Clear;
{$ENDIF}
   end;
  rpdatadriver,rpdotnet2driver:
   begin
    BConfig.Visible:=false;
    BBuild.Visible:=false;
    ComboAvailable.Items.Clear;
   end;
  rpdbHttp:
   begin
    BConfig.Visible:=true;
    BBuild.Visible:=false;
    ComboAvailable.Items.Clear;
   end;
 end;
end;


procedure TFRpConnectionVCL.BNewClick(Sender: TObject);
var
 apoint:TPoint;
begin
 if Not Assigned(FDatabaseInfo) then
  exit;
 apoint.x:=BNew.Left;
 apoint.y:=BNew.Top+BNew.Height;
 apoint:=BNew.Parent.ClientToScreen(apoint);
 BNew.DropDownMenu.Popup(apoint.x,apoint.y);
end;

procedure TFRpConnectionVCL.MNewClick(Sender: TObject);
var
 conname:string;
 item:TRpDatabaseInfoItem;
 index:integer;
begin
 if Not Assigned(FDatabaseInfo) then
  exit;
 conname:=UpperCase(Trim(RpInputBox(SRpNewConnection,SRpConnectionName,'')));
 if Length(conname)<1 then
  exit;
 AssertCanModify('Database connection');
 item:=Fdatabaseinfo.Add(conname);
 EnsureDatabaseInfoItemName(TRpBaseReport(report), item);
 item.Driver:=TRpDbDriver(GDriver.ItemIndex);
 SetDatabaseInfo(Fdatabaseinfo);
 index:=FDatabaseinfo.IndexOf(conname);
 if index>=0 then
 begin
  LConnections.ItemIndex:=index;
  LConnectionsClick(Self);
 end;
end;

procedure TFRpConnectionVCL.BConfigClick(Sender: TObject);
var
 i:integer;
begin
 ShowDBXConfig;
 conadmin.free;
 conadmin:=TRPCOnnAdmin.Create;
 conadmin.GetConnectionNames(ComboAvailable.Items,'');
 // The configuration (dbxconnections) may have been edited inside the dialog.
 // Disconnect each live connection and reload its config so the next data
 // fetch / report run picks up the new values without restarting the app.
 for i:=0 to report.DatabaseInfo.Count-1 do
 begin
  report.DatabaseInfo[i].DisConnect;
  report.DatabaseInfo[i].UpdateConAdmin;
 end;
end;

procedure TFRpConnectionVCL.BBuildClick(Sender: TObject);
{$IFDEF USEADO}
var
 dinfoitem:TRpDatabaseinfoitem;
 newstring:String;
{$ENDIF}
begin
{$IFDEF USEADO}
 dinfoitem:=FindDatabaseInfoItem;
  if LConnections.ItemIndex<0 then
   Raise Exception.Create(SRpSelectAddConnection);
 AssertCanModify('Database connection');
 EConnectionString.OnChange:=nil;
 newstring:=PromptDataSource(0,dinfoitem.ADOConnectionString);
 EConnectionString.Text:=EncodeADOPassword(newstring);
 dinfoitem.ADOConnectionString:=newstring;
 EConnectionString.Onchange:=EConnectionStringChange;
{$ENDIF}
end;

procedure TFRpConnectionVCL.ANewConnectionExecute(Sender: TObject);
var
 apoint:TPoint;
begin
 // Adds a new connection
 // Shows the popupmenu
 apoint.x:=BNew.Left;
 apoint.y:=BNew.Top+BNew.Height;
 apoint:=BNew.Parent.ClientToScreen(apoint);
 BNew.DropDownMenu.Popup(apoint.x,apoint.y);
end;


procedure TFRpConnectionVCL.PopAddPopup(Sender: TObject);
var
 aitem:TMenuItem;
 i:integer;
begin
 // Adds available items
 While PopAdd.Items.Count>1 do
  PopAdd.Items.Delete(1);
 for i:=0 to ComboAvailable.Items.Count-1 do
 begin
  aitem:=TMenuItem.Create(PopAdd);
  aitem.Caption:=ComboAvailable.Items.Strings[i];
  aitem.OnClick:=MenuAddClick;
  PopAdd.Items.Add(aitem);
 end;
end;

procedure TFRpConnectionVCL.ADeleteExecute(Sender: TObject);
var
 index:integer;
begin
 if LConnections.Itemindex<0 then
  exit;
 index:=databaseinfo.IndexOf(LConnections.items.strings[LConnections.Itemindex]);
 if index>=0 then
 begin
  AssertCanModify('Database connection');
  databaseinfo.Delete(index);
  SetDatabaseInfo(databaseinfo);
  LConnectionsClick(Self);
 end;
end;

procedure TFRpConnectionVCL.ComboDriverClick(Sender: TObject);
var
 index:integeR;
begin
 if Not Assigned(FDatabaseInfo) then
  exit;
 if ComboDriver.ItemIndex<0 then
  exit;
 LConnectionString.Visible:=False;
 EConnectionString.Visible:=false;
 LDotNetDriver.Visible:=False;
 ComboNetDriver.Visible:=False;
 EConnectionString.Visible:=false;
 BBuild.Visible:=false;
 BTest.Visible:=true;
 // Loads the alias config
 case TrpDbDriver(ComboDriver.ItemIndex) of
  // DBExpress
  rpdatadbexpress:
   begin
    LConnectionString.Visible:=False;
    EConnectionString.Visible:=False;
    if Assigned(ConAdmin) then
    begin
     conadmin.GetConnectionNames(ComboAvailable.Items,'');
    end;
   end;
  // IBX and IBO
  rpdataibx,rpdataibo:
   begin
    LConnectionString.Visible:=False;
    EConnectionString.Visible:=False;
   end;
  // My Base
  rpdatamybase:
   begin
    LConnectionString.Visible:=False;
    EConnectionString.Visible:=False;
    BTest.Visible:=false;
   end;
  // BDE
  rpdatabde:
   begin
{$IFDEF USEBDE}
    LConnectionString.Visible:=False;
    EConnectionString.Visible:=False;
{$ENDIF}
   end;
  // ADO
  rpdataado:
   begin
{$IFDEF MSWINDOWS}
    LConnectionString.Visible:=True;
    EConnectionString.Visible:=True;
    BBuild.Visible:=true;
{$ENDIF}
   end;
  rpdatadriver:
   begin
    GetDotNetDrivers(ComboNetDriver.Items);
    ComboNetDriver.Style:=csDropDownList;
    LConnectionString.Visible:=True;
    EConnectionString.Visible:=True;
    BBuild.Visible:=true;
    LDotNetDriver.Visible:=true;
    ComboNetDriver.Visible:=true;
   end;
  rpdotnet2driver:
   begin
    ComboNetDriver.Style:=csDropDown;
    ComboNetDriver.Style:=csDropDown;
    try
     GetDotNet2Drivers(ComboNetDriver.Items);
    except
     on E:Exception do
     begin
      RpShowMessage(E.Message);
	ComboNetDriver.Clear;
     end;
    end;
    LConnectionString.Visible:=True;
    EConnectionString.Visible:=True;
    BBuild.Visible:=true;
    LDotNetDriver.Visible:=true;
    ComboNetDriver.Visible:=true;
   end;
 end;
 if LConnections.ItemIndex<0 then
  exit;
 index:=FDatabaseInfo.Indexof(LConnections.Items.Strings[LConnections.ItemIndex]);
 if index<0 then
  exit;
 if FLoadingControls then
  exit;
 AssertCanModify('Database connection');
 FDatabaseInfo.Items[index].Driver:=TRpDbDriver(ComboDriver.ItemIndex);
end;

procedure TFRpConnectionVCL.MenuAddClick(Sender:TObject);
var
 conname:String;
 item:TRpDatabaseInfoItem;
 index:integer;
begin
 if Not Assigned(FDatabaseInfo) then
  exit;
 conname:=UpperCase(Trim(TMenuItem(Sender).Caption));
 if Length(conname)<1 then
  exit;
 AssertCanModify('Database connection');
 item:=Fdatabaseinfo.Add(conname);
 EnsureDatabaseInfoItemName(TRpBaseReport(report), item);
 item.Driver:=ResolveAvailableConnectionDriver(conname,TRpDbDriver(GDriver.ItemIndex));
 SetDatabaseInfo(Fdatabaseinfo);
 index:=FDatabaseinfo.IndexOf(conname);
 if index>=0 then
 begin
  LConnections.ItemIndex:=index;
  LConnectionsClick(Self);
 end;
end;

function TFRpConnectionVCL.ResolveAvailableConnectionDriver(
 const AConnectionName: string; ADefaultDriver: TRpDbDriver): TRpDbDriver;
var
 params:TStringList;
 drivername:string;
begin
 Result:=ADefaultDriver;
 if Not Assigned(ConAdmin) then
  exit;
 params:=TStringList.Create;
 try
  ConAdmin.GetConnectionParams(AConnectionName,params);
  drivername:=Trim(params.Values['DriverName']);
  if Length(drivername)>0 then
   Result:=ResolveDbxConnectionDriver(drivername);
 finally
  params.Free;
 end;
end;


function TFRpConnectionVCL.FindDatabaseInfoItem:TRpDatabaseInfoItem;
var
 index:integer;
begin
 Result:=nil;
 if Not Assigned(FDatabaseInfo) then
  exit;
 If LConnections.Items.Count<1 then
  exit;
 If LConnections.ItemIndex<0 then
  exit;
 index:=FDatabaseInfo.IndexOf(LConnections.Items[LConnections.ItemIndex]);
 if index<0 then
  exit;
 Result:=FDatabaseInfo.Items[index];
end;

const
 // The magic wand of the connection wizard (48x48 RGBA PNG)
 WAND_PNG_HEX =
  '89504E470D0A1A0A0000000D49484452000000300000003008060000005702F987000001D04944415478DAED984D4AC3' +
  '4014C77B84D94E2824B8712504A12A16A15041101739422E50E8BE08BD418F1010576E2A6E74971B3447C8BA6EB20CB8' +
  '19E7C5198C6DD46432CE87CC833F850426BFF7D5793383813367CE8CB1B7170F59EE005EEAFAF05C5206321D699F50E5' +
  '92D62154914AF890AAF8F8304E7A663165EBA48AC0F18A45ACAE1C22481574848FBFAE83635519883E33E0655DC19BE1' +
  '953B81E72CF2A87BCDF3B2F94ED5FB488513CB96D088399CFD0CBEA70CBEF167FB84C8C2AC8FD62D3230317DF3D2DB03' +
  '5DCCF3FC00633FA6BF1115D2FE2FD4C528F86A343A278BC52D99CDE6843A5050853527D6CAF60101F8643ABD22DBED2B' +
  '29CBB2D266937127506D5324C6D57C133C17CB44A475161285074139414FC81E0A95C0C373E809686CE3CE036DE0E13D' +
  '34B6910DEB0787E4EEFEE137F8C458F893F13539BBB8218F4FCFF6C2737127AC84E7827212851719D1A5C2C373782F08' +
  '8FFA9EF4B4C1B37D2161BB736859E461B8DB3DEC5447D8C08AC8D726D45EC7556DF0BB5736D2766895F0D2E7231DF0D2' +
  'E6235DF05647DEC13B78072F061F5B0BCF1C488F4F2FED846737677953F4AD80E7F57F148EED84E77797C3E141014E00' +
  '38949335F075270018CA097AA27EF1E4CCD93FB477F2915D17255630FD0000000049454E44AE426082';

procedure TFRpConnectionVCL.BuildWizardControls;
var
 LBytes:TBytes;
 LStream:TMemoryStream;

 function NewImages(ASize:Integer):TVirtualImageList;
 begin
  Result:=TVirtualImageList.Create(Self);
  Result.ImageCollection:=ImageCollection1;
  Result.Width:=ScaleDpi(ASize);
  Result.Height:=ScaleDpi(ASize);
  Result.Add('Wand','Wand');
 end;

 function NewWandButton(AParent:TWinControl;AImages:TVirtualImageList;
  AClick:TNotifyEvent):TButton;
 begin
  Result:=TButton.Create(Self);
  Result.Parent:=AParent;
  Result.Images:=AImages;
  Result.ImageIndex:=0;
  Result.ImageMargins.Left:=ScaleDpi(6);
  Result.OnClick:=AClick;
 end;

 // The caption and the image fit
 // (a bitmap canvas: the frame has no parent window yet)
 procedure FitWidth(AButton:TButton;AImageSize:Integer);
 var
  LBitmap:TBitmap;
 begin
  LBitmap:=TBitmap.Create;
  try
   LBitmap.Canvas.Font:=AButton.Font;
   AButton.Width:=LBitmap.Canvas.TextWidth(AButton.Caption)+ScaleDpi(AImageSize+40);
  finally
   LBitmap.Free;
  end;
 end;

begin
 SetLength(LBytes,Length(WAND_PNG_HEX) div 2);
 HexToBin(PChar(WAND_PNG_HEX),LBytes[0],Length(LBytes));
 LStream:=TMemoryStream.Create;
 try
  LStream.WriteBuffer(LBytes[0],Length(LBytes));
  LStream.Position:=0;
  ImageCollection1.Add('Wand',LStream);
 finally
  LStream.Free;
 end;
 FWandImages:=NewImages(20);
 FWandImagesLarge:=NewImages(32);

 // "Add connection" above the toolbar
 PWizard:=TPanel.Create(Self);
 PWizard.Parent:=Self;
 PWizard.BevelOuter:=bvNone;
 PWizard.Caption:='';
 PWizard.Align:=alTop;
 PWizard.Top:=0;
 BWizard:=NewWandButton(PWizard,FWandImages,BWizardClick);
 BWizard.Caption:=TranslateStr(1826,'Add connection')+'...';
 BWizard.SetBounds(ScaleDpi(6),ScaleDpi(4),ScaleDpi(160),ScaleDpi(32));
 FitWidth(BWizard,20);
 PWizard.Height:=BWizard.Height+ScaleDpi(8);
 ToolBar1.Top:=PWizard.Top+PWizard.Height+1;

 // No connections: the wizard in the place of the connection properties
 PEmpty:=TPanel.Create(Self);
 PEmpty.Parent:=PConProps;
 PEmpty.BevelOuter:=bvNone;
 PEmpty.Caption:='';
 PEmpty.Align:=alClient;
 PEmpty.Visible:=False;
 PEmpty.OnResize:=PEmptyResize;
 BWizardEmpty:=NewWandButton(PEmpty,FWandImagesLarge,BWizardClick);
 BWizardEmpty.Caption:=BWizard.Caption;
 BWizardEmpty.ParentFont:=False;
 BWizardEmpty.Font.Size:=11;
 BWizardEmpty.Height:=ScaleDpi(48);
 FitWidth(BWizardEmpty,32);
 LWizardHint:=TLabel.Create(Self);
 LWizardHint.Parent:=PEmpty;
 LWizardHint.AutoSize:=False;
 LWizardHint.WordWrap:=True;
 LWizardHint.Alignment:=taCenter;
 LWizardHint.ShowAccelChar:=False;
 LWizardHint.Width:=ScaleDpi(420);
 LWizardHint.Height:=ScaleDpi(54);
 LWizardHint.Font.Color:=clGrayText;
 LWizardHint.Caption:=TranslateStr(1828,'Connect the report to your database: '+
  'through the Reportman Agent, or directly (SQLite, Zeos...).');

 // A Reportman AI Agent connection that can not be opened on this computer
 LAgentProblem:=TLabel.Create(Self);
 LAgentProblem.Parent:=PConProps;
 LAgentProblem.Left:=BTest.Left;
 LAgentProblem.Top:=BTest.Top+BTest.Height+ScaleDpi(10);
 // Its width follows the frame in LayoutAgentProblem
 LAgentProblem.WordWrap:=True;
 LAgentProblem.ShowAccelChar:=False;
 LAgentProblem.Font.Color:=clMaroon;
 LAgentProblem.Visible:=False;
 BWizardConfigure:=NewWandButton(PConProps,FWandImages,BWizardConfigureClick);
 BWizardConfigure.Caption:=TranslateStr(1829,'Configure with the wizard');
 BWizardConfigure.SetBounds(BTest.Left,LAgentProblem.Top,ScaleDpi(160),ScaleDpi(30));
 FitWidth(BWizardConfigure,20);
 BWizardConfigure.Visible:=False;
end;

procedure TFRpConnectionVCL.LayoutAgentProblem;
begin
 if (LAgentProblem=nil) or (not LAgentProblem.Visible) then
  exit;
 // The whole width of the properties, the wizard button below the text
 // (AutoSize again: a new width alone keeps the height of the old one)
 LAgentProblem.AutoSize:=False;
 LAgentProblem.Width:=PConProps.ClientWidth-LAgentProblem.Left-ScaleDpi(20);
 LAgentProblem.AutoSize:=True;
 BWizardConfigure.Top:=LAgentProblem.Top+LAgentProblem.Height+ScaleDpi(6);
end;

procedure TFRpConnectionVCL.PEmptyResize(Sender: TObject);
var
 LTop:Integer;
begin
 // The button and its explanation in the middle
 LTop:=(PEmpty.ClientHeight-BWizardEmpty.Height-LWizardHint.Height-ScaleDpi(10)) div 2;
 if LTop<ScaleDpi(10) then
  LTop:=ScaleDpi(10);
 BWizardEmpty.Left:=(PEmpty.ClientWidth-BWizardEmpty.Width) div 2;
 BWizardEmpty.Top:=LTop;
 LWizardHint.Left:=(PEmpty.ClientWidth-LWizardHint.Width) div 2;
 LWizardHint.Top:=LTop+BWizardEmpty.Height+ScaleDpi(10);
end;

procedure TFRpConnectionVCL.ReloadConnAdmin;
begin
 // The connections file changed (New drop down, Load params)
 conadmin.free;
 conadmin:=TRpConnAdmin.Create;
 conadmin.GetConnectionNames(ComboAvailable.Items,'');
end;

procedure TFRpConnectionVCL.BWizardClick(Sender: TObject);
var
 LName,LAdo:string;
 LDriver:TRpDbDriver;
begin
 if Not Assigned(FDatabaseInfo) then
  exit;
 AssertCanModify('Database connection');
 if RpConnectionWizardFunc('',0,LName,LDriver,LAdo) then
  AddWizardConnection(LName,LDriver,LAdo);
end;

procedure TFRpConnectionVCL.AddWizardConnection(const AName: string;
 ADriver: TRpDbDriver; const AAdoConnectionString: string);
var
 conname:string;
 item:TRpDatabaseInfoItem;
 index:integer;
begin
 conname:=UpperCase(Trim(AName));
 if Length(conname)<1 then
  exit;
 ReloadConnAdmin;
 index:=FDatabaseInfo.IndexOf(conname);
 if index<0 then
 begin
  item:=FDatabaseInfo.Add(conname);
  EnsureDatabaseInfoItemName(TRpBaseReport(report), item);
  item.Driver:=ADriver;
 end
 else
  item:=FDatabaseInfo.Items[index];
 if ADriver=rpdataado then
  item.ADOConnectionString:=AAdoConnectionString;
 // The next Connect reads the connections file again
 item.UpdateConAdmin;
 item.DisConnect;
 SetDatabaseInfo(FDatabaseInfo);
 index:=FDatabaseInfo.IndexOf(conname);
 if index>=0 then
 begin
  LConnections.ItemIndex:=index;
  LConnectionsClick(Self);
 end;
end;

procedure TFRpConnectionVCL.BWizardConfigureClick(Sender: TObject);
var
 LItem:TRpDatabaseInfoItem;
 LName,LAdo:string;
 LDriver:TRpDbDriver;
begin
 LItem:=FindDatabaseInfoItem;
 if LItem=nil then
  exit;
 if RpConnectionWizardFunc(LItem.Alias,0,LName,LDriver,LAdo) then
 begin
  LItem.UpdateConAdmin;
  LItem.DisConnect;
  ReloadConnAdmin;
  UpdateWizardState;
 end;
end;

procedure TFRpConnectionVCL.UpdateWizardState;
var
 LItem:TRpDatabaseInfoItem;
 LMessage:string;
begin
 if PEmpty=nil then
  exit;
 // No connections: the connection wizard instead of the properties
 PEmpty.Visible:=Assigned(FDatabaseInfo) and (FDatabaseInfo.Count=0);
 if PEmpty.Visible then
 begin
  PEmpty.BringToFront;
  PEmptyResize(PEmpty);
 end;
 LItem:=FindDatabaseInfoItem;
 if (LItem<>nil) and (LItem.Driver=rpdbHttp) and
  RpAgentConnectionProblem(LItem,LMessage) then
 begin
  LAgentProblem.Caption:=LMessage;
  LAgentProblem.Visible:=True;
  BWizardConfigure.Visible:=True;
  LayoutAgentProblem;
 end
 else
 begin
  LAgentProblem.Visible:=False;
  BWizardConfigure.Visible:=False;
 end;
end;

procedure TFRpConnectionVCL.FrameResize(Sender: TObject);
begin
 toolbar1.ButtonWidth:=ScaleDpi(26);
 toolbar1.ButtonHeight:=ScaleDpi(26);
 LayoutAgentProblem;
end;

procedure TFRpConnectionVCL.BTestClick(Sender: TObject);
var
 dbinfo:TRpDatabaseInfoItem;
 startinfo:TStartupinfo;
 linecount:string;
 FExename,FCommandLine,astring:string;
 procesinfo:TProcessInformation;
begin
 dbinfo:=FindDatabaseInfoItem;
 if Not Assigned(dbinfo) then
  exit;
 if dbinfo.Driver in [rpdatadriver,rpdotnet2driver] then
 begin
  astring:=RpTempFileName;
  report.StreamFormat:=rpStreamXML;
  report.SaveToFile(astring);
  linecount:='';
  with startinfo do
  begin
   cb:=sizeof(startinfo);
   lpReserved:=nil;
   lpDesktop:=nil;
   lpTitle:=PChar('Report manager');
   dwX:=0;
   dwY:=0;
   dwXSize:=400;
   dwYSize:=400;
   dwXCountChars:=80;
   dwYCountChars:=25;
   dwFillAttribute:=FOREGROUND_RED or BACKGROUND_RED or BACKGROUND_GREEN or BACKGROUND_BLUe;
   dwFlags:=STARTF_USECOUNTCHARS or STARTF_USESHOWWINDOW;
   cbReserved2:=0;
   lpreserved2:=nil;
  end;
  if dbinfo.Driver=rpdatadriver then
   FExename:=ExtractFilePath(ParamStr(0))+'net\printreport.exe'
  else
   FExename:=ExtractFilePath(ParamStr(0))+'net2\printreport.exe';
  if (not FileExists(Fexename)) then
  begin
   raise Exception.Create('File not found '+FExename);
  end;

  FCommandLine:=' -deletereport -testconnection '+dbinfo.Alias+' "'+
   astring+'"';
  if Not CreateProcess(Pchar(FExename),Pchar(Fcommandline),nil,nil,True,NORMAL_PRIORITY_CLASS or CREATE_NEW_PROCESS_GROUP,nil,nil,
     startinfo,procesinfo) then
      RaiseLastOSError;
 end
 else
 begin
  dbinfo.Connect(report.Params);
  try
   RpShowMessage(SRpConnectionOk);
  finally
   dbinfo.DisConnect;
  end;
 end;
 PParent.Align := alClient;
end;



procedure TFRpConnectionVCL.CheckLoginPromptClick(Sender: TObject);
var
 dinfoitem:TRpDatabaseinfoitem;
begin
 if FLoadingControls then
  Exit;
 dinfoitem:=FindDatabaseInfoItem;
 if Not Assigned(dinfoitem) then
  exit;
 AssertCanModify('Database connection');
 if Sender=CheckLoginPrompt then
 begin
  dinfoitem.LoginPrompt:=CheckLoginPrompt.Checked;
 end
 else
 if Sender=CheckLoadParams then
 begin
  dinfoitem.LoadParams:=CheckLoadParams.Checked;
 end
 else
 if Sender=ComboNetDriver then
 begin
  if dinfoitem.Driver=rpdatadriver then
   dinfoitem.DotNetDriver:=ComboNetDriver.ItemIndex
  else
   dinfoitem.ProviderFactory:=ComboNetDriver.Text;
 end
 else
 begin
  dinfoitem.LoadDriverParams:=CheckLoadDriverParams.Checked;
 end;
end;

procedure TFRpConnectionVCL.EConnectionStringChange(Sender: TObject);
var
 dinfoitem:TRpDatabaseinfoitem;
begin
 if FLoadingControls then
  Exit;
 dinfoitem:=FindDatabaseInfoItem;
 if Not Assigned(dinfoitem) then
  exit;
 AssertCanModify('Database connection');
 // The edit shows the password masked: editing another part saved the '*'
 dinfoitem.ADOConnectionString:=RestoreADOPassword(EConnectionString.Text,
  dinfoitem.ADOConnectionString);
end;

end.
