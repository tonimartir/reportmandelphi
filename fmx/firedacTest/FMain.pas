unit FMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  System.Math.Vectors, System.Rtti, FMX.Grid.Style, FireDAC.Stan.Intf,
  FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.Phys.ODBC, FireDAC.Phys.ODBCDef, FireDAC.FMXUI.Wait,
  FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt,
  FMX.Memo.Types, FMX.Memo, FMX.StdCtrls, Data.DB, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client, FMX.ScrollBox, FMX.Grid, FMX.Controls3D, FMX.Layers3D,
  FMX.TabControl, FMX.Controls.Presentation, Datasnap.Provider,
  Datasnap.DBClient, Fmx.Bind.Grid, System.Bindings.Outputs, Fmx.Bind.Editors,
  Data.Bind.EngExt, Fmx.Bind.DBEngExt, Data.Bind.Components, Data.Bind.Grid,
  Data.Bind.DBScope, FMX.ListBox, FireDAC.FMXUI.Login, FireDAC.FMXUI.Error,
  FireDAC.Comp.UI,
  FireDAC.Phys.MySQLDef,
  FireDAC.Phys.ADSDef, FireDAC.Phys.FBDef, FireDAC.Phys.PGDef,
  FireDAC.Phys.IBDef, FireDAC.Stan.ExprFuncs, FireDAC.Phys.SQLiteWrapper.Stat,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Phys.OracleDef, FireDAC.Phys.DB2Def, FireDAC.Phys.InfxDef,
  FireDAC.Phys.MSSQLDef, FireDAC.Phys.TDataDef, FireDAC.Phys.ASADef,
  FireDAC.Phys.MongoDBDef, FireDAC.Phys.MongoDB, FireDAC.Phys.ASA,
  FireDAC.Phys.TData, FireDAC.Phys.MSSQL, FireDAC.Phys.Infx, FireDAC.Phys.DB2,
  FireDAC.Phys.Oracle,
  FireDAC.Phys.SQLite, FireDAC.Phys.IB, FireDAC.Phys.PG,
  FireDAC.Phys.IBBase, FireDAC.Phys.FB, FireDAC.Phys.ADS, FireDAC.Phys.MySQL,
  FireDAC.Phys.ODBCBase, ZAbstractDataset, ZMemTable, ZDataset,
  ZAbstractRODataset, ZAbstractConnection, ZTransaction, ZConnection, ZDatasetUtils,
  ZDbcIntfs;
type
  TForm1 = class(TForm)
    Label1: TLabel;
    FDConnection1: TFDConnection;
    FDTransaction1: TFDTransaction;
    FDQuery1: TFDQuery;
    DataSource1: TDataSource;
    TabControl1: TTabControl;
    TabItem1: TTabItem;
    Layout3D1: TLayout3D;
    ButtonConnect: TButton;
    Panel1: TPanel;
    ComboDriver: TComboBox;
    Label2: TLabel;
    TabItem2: TTabItem;
    Button1: TButton;
    MemoSQL: TMemo;
    TabItem3: TTabItem;
    Grid1: TGrid;
    BindSourceDB1: TBindSourceDB;
    LinkGridToDataSourceBindSourceDB1: TLinkGridToDataSource;
    BindingsList1: TBindingsList;
    MemoParams: TMemo;
    Panel2: TPanel;
    CheckCreateParams: TCheckBox;
    CheckCreateMacros: TCheckBox;
    CheckExpandParams: TCheckBox;
    CheckExpandMacros: TCheckBox;
    CheckExpandEscapes: TCheckBox;
    CheckUnifyParams: TCheckBox;
    FDMemTable1: TFDMemTable;
    Label3: TLabel;
    CheckLoginPrompt: TCheckBox;
    ZConnection1: TZConnection;
    ZTransaction1: TZTransaction;
    ZReadOnlyQuery1: TZReadOnlyQuery;
    ZMemTable1: TZMemTable;
    LabelZeosProtocol: TLabel;
    Label5: TLabel;
    ComboZeosProtocol: TComboBox;
    Panel3: TPanel;
    ButtonDisconnect: TButton;
    procedure ButtonConnectClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ComboDriverChange(Sender: TObject);
    procedure ButtonDisconnectClick(Sender: TObject);
  private
    { Private declarations }
    isZeosLib: boolean;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure TForm1.Button1Click(Sender: TObject);
var nombreCliente:string;
begin
 if (isZeosLib) then
 begin
   if (not ZConnection1.Connected) then
   begin
     raise Exception.Create('Go to Connection tab and connect database before opening the dataset.');
   end;
   ZReadOnlyQuery1.Close;
   ZReadOnlyQuery1.SQL.Text := '';
   ZReadOnlyQuery1.Params.Clear;
   //ZReadOnlyQuery1.ResourceOptions.EscapeExpand :=   CheckExpandParams.IsChecked;
   ZReadOnlyQuery1.ParamCheck :=   CheckCreateParams.IsChecked;
   //ZReadOnlyQuery1.ResourceOptions.ParamExpand :=   CheckExpandParams.IsChecked;
   //ZReadOnlyQuery1.ResourceOptions.UnifyParams :=   CheckUnifyParams.IsChecked;
   //ZReadOnlyQuery1.ResourceOptions.MacroCreate :=   CheckCreateMacros.IsChecked;
   //ZReadOnlyQuery1.ResourceOptions.MacroExpand :=   CheckExpandMacros.IsChecked;
   ZReadOnlyQuery1.SQL.Text := MemoSQL.Text;
   ZReadOnlyQuery1.Active:=true;
   // ZMemTable convierte las columnas widestring a string perdiendo información
(*   try
    ZMemTable1.CloneDataFrom(ZReadOnlyQuery1, true);
    
          
   finally
    ZReadOnlyQuery1.Active:=false;
   end;*)
   DataSource1.DataSet:=ZReadOnlyQuery1;
 end
 else
 begin
   DataSource1.DataSet:=nil;
   if (not FDConnection1.Connected) then
   begin
     raise Exception.Create('Go to Connection tab and connect database before opening the dataset.');
   end;
   FDQuery1.Close;
   FDQuery1.SQL.Text := '';
   FDQuery1.Params.Clear;
   FDQuery1.ResourceOptions.EscapeExpand :=   CheckExpandParams.IsChecked;
   FDQuery1.ResourceOptions.ParamCreate :=   CheckCreateParams.IsChecked;
   FDQuery1.ResourceOptions.ParamExpand :=   CheckExpandParams.IsChecked;
   FDQuery1.ResourceOptions.UnifyParams :=   CheckUnifyParams.IsChecked;
   FDQuery1.ResourceOptions.MacroCreate :=   CheckCreateMacros.IsChecked;
   FDQuery1.ResourceOptions.MacroExpand :=   CheckExpandMacros.IsChecked;
   FDQuery1.SQL.Text := MemoSQL.Text;
   //FDquery1.FetchOptions.Mode:=TFDFetchMode.fmAll;
   FDQuery1.Active:=true;
   try
    //FDQuery1.Last;
    //FDMemTable1.CloneCursor(FDQuery1, False, False);    
   finally
    //FDQuery1.Active:=false;
   end;
  // DataSource1.DataSet:=FDMemTable1;
   DataSource1.DataSet:=FDQuery1;
 end;
 TabControl1.ActiveTab := TabItem3;
end;

procedure TForm1.ButtonConnectClick(Sender: TObject);
var
 driverName:string;
 param:String;
begin
 driverName:=ComboDriver.Items[ComboDriver.ItemIndex];
 if (driverName = 'Zeos') then
 begin
  isZeosLib:=true;
  ZConnection1.Protocol:=ComboZeosProtocol.Items[ComboZeosProtocol.ItemIndex];
  ZConnection1.Database:=MemoParams.Lines.Values['Database'];
  if (ZConnection1.Database = '') then
  begin
   ZConnection1.Database:=MemoParams.Lines.Values['DataSource'];
  end;
  ZConnection1.User:=MemoParams.Lines.Values['User_Name'];
  ZConnection1.Password:=MemoParams.Lines.Values['Password'];
  //ZConnection1.Properties.Clear;
  //ZConnection1.Properties.Add('codepage=utf8');
  //ZConnection1.ControlsCodePage:=cCP_UTF16;
  //ZConnection1.RawCharacterTransliterateOptions.Params:=true;
  //ZConnection1.RawCharacterTransliterateOptions.Encoding:=encUTF8;
  //ZConnection1.ClientCodepage:=;
  ZConnection1.Connect;
 end
 else
 begin
  isZeosLib:=false;
  FDConnection1.DriverName:=ComboDriver.Items[ComboDriver.ItemIndex];
  FDConnection1.Params.Text := MemoParams.Text;
  FDConnection1.LoginPrompt := CheckLoginPrompt.IsChecked;
  FDConnection1.Params.AddPair('DriverId',driverName);
  FDConnection1.Close;
  FDConnection1.Open;
 end;
 ButtonConnect.Enabled:=false;
 ButtonDisconnect.Enabled:=true;

 TabControl1.ActiveTab := TabItem2;
end;

procedure TForm1.ButtonDisconnectClick(Sender: TObject);
begin
 if (isZeosLib) then
 begin
  ZConnection1.Disconnect;
 end
 else
 begin
   FDConnection1.Close;
 end;
 ButtonConnect.Enabled:=true;
 BUttonDisconnect.Enabled:=false;
end;

procedure TForm1.ComboDriverChange(Sender: TObject);
var
 driverName:String;
begin
 driverName:=ComboDriver.Items[ComboDriver.ItemIndex];
 if (driverName = 'Zeos') then
 begin
   LabelZeosProtocol.Enabled:=true;
   ComboZeosProtocol.Enabled:=true;
 end
 else
 begin
   LabelZeosProtocol.Enabled:=false;
   ComboZeosProtocol.Enabled:=false;
 end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
 TabControl1.ActiveTab:=TabControl1.Tabs[0];
 ComboDriver.ItemIndex := 12;
 MemoParams.Text := FDConnection1.Params.Text;
 ComboZeosProtocol.ItemIndex:=ComboZeosProtocol.Items.IndexOf('odbc_w');
end;

end.
