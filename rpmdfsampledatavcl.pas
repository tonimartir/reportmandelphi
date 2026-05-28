{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpmdFSampledatavcl                              }
{       Show data of a unidirectional query             }
{                                                       }
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

unit rpmdfsampledatavcl;

interface

uses SysUtils, Classes, Graphics, Forms,
  Buttons, ExtCtrls, Controls, StdCtrls,DB, DBCtrls, Grids, DBGrids,
{$IFDEF DELPHI2009UP}
 System.ImageList,
{$ENDIF}
  ComCtrls, ImgList,rpmdconsts, ToolWin,rpgraphutilsvcl, System.ImageList,
  Vcl.VirtualImageList, Vcl.BaseImageCollection, Vcl.ImageCollection
{$IFDEF MSWINDOWS}
  , rpdctransportchip
{$ENDIF}
  ;

const
 DCONTROL_DISTANCEY=5;
 DCONTROL_DISTANCEX=10;
 DCONTROL_DISTANCEX2=300;
 DCONTROL_WIDTHX=200;
 DCONTROL_GAP=15;
 DBEVEL_GAP=2;
 DLABEL_INCY=1;

type
  TFRpShowSampledataVCL = class(TForm)
    DataSource1: TDataSource;
    ToolBar1: TToolBar;
    DBNavigator1: TDBNavigator;
    ScrollBox1: TScrollBox;
    ImageList1: TImageList;
    BExit: TToolButton;
    ToolButton2: TToolButton;
    VirtualImageList1: TVirtualImageList;
    ImageCollection1: TImageCollection;
    procedure BExitClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    FHubDatabaseId: Int64;
{$IFDEF MSWINDOWS}
    FTransportChip: TPanel;
    procedure CreateTransportChip;
{$ENDIF}
    procedure CreateControls;
    procedure SetHubDatabaseId(const AValue: Int64);
  public
    { Public declarations }
    // Setter repaints the chip immediately - FormCreate has already
    // fired by the time ShowDataset assigns the ID, so a bare field
    // write would leave the chip stuck on the FormCreate value (0,
    // which has no cached transport and reads as "Unknown").
    property HubDatabaseId: Int64 read FHubDatabaseId write SetHubDatabaseId;
  end;

// Original entry point - kept so non-HTTP datasets keep working.
procedure ShowDataset(Data:TDataset); overload;

// Overload used by the HTTP dataset path: passes the hubDatabaseId
// so the form can paint a "Direct P2P / Hole-Punch / Relay / API"
// chip in the toolbar reflecting the live transport.
procedure ShowDataset(Data:TDataset; AHubDatabaseId: Int64); overload;

implementation

{$R *.dfm}

procedure ShowDataset(Data:TDataset);
begin
  ShowDataset(Data, 0);
end;

procedure ShowDataset(Data:TDataset; AHubDatabaseId: Int64);
var
 dia:TFRpShowSampledataVCL;
begin
 dia:=TFRpShowSampledataVCL.Create(Application);
 try
  dia.HubDatabaseId := AHubDatabaseId;
  dia.DataSource1.DataSet:=data;
  dia.CreateControls;
  dia.ShowModal;
 finally
  dia.free;
 end;
end;

procedure TFRpShowSampledataVCL.CreateControls;
var
 i:integer;
 dataset:TDataset;
 label1:TLabel;
 Control:TControl;
 top:integer;
 bevel:TBevel;
begin
 if Not Assigned(Datasource1.dataset) then
  exit;
 if not Datasource1.dataset.active then
  exit;
 dataset:=Datasource1.dataset;
 top:=DCONTROL_DISTANCEY;
 for i:=0 to dataset.FieldCount-1 do
 begin
  label1:=Tlabel.Create(self);
  label1.Top:=top+DLABEL_INCY;
  label1.Left:=DCONTROL_DISTANCEX;
  label1.caption:=Dataset.fields[i].FieldName;
  label1.Parent:=ScrollBox1;

  control:=TDBTExt.Create(self);
  TDBText(control).Font.Style:=[fsBold];
  TDBText(control).Datasource:=datasource1;
  TDBText(control).DataField:=Dataset.fields[i].FieldName;

  control.top:=top;
  control.left:=DCONTROL_DISTANCEX2;
  control.Anchors:=[akLeft,akTop,akRight];
  control.Width:=ScrollBox1.Width-DCONTROL_GAP-control.Left;
  control.Height:=Canvas.TextHeight('Wg');
  control.parent:=SCrollbox1;

  bevel:=TBevel.Create(Self);
  bevel.Top:=top+Control.Height+DBEVEL_GAP;
  bevel.left:=label1.Left;
  bevel.Anchors:=[akLeft,akTop,akRight];
  bevel.Width:=ScrollBox1.Width-DCONTROL_GAP-bevel.Left;
  bevel.Height:=2;
  bevel.parent:=SCrollbox1;


  top:=top+Control.Height+DCONTROL_DISTANCEY;
 end;
end;


procedure TFRpShowSampledataVCL.BExitClick(Sender: TObject);
begin
 Close;
end;

procedure TFRpShowSampledataVCL.FormCreate(Sender: TObject);
begin
  //ScaleToolBar(toolbar1);
  Caption:=TranslateStr(735,Caption);
 BExit.Hint:=TranslateStr(212,BExit.Caption);
 DBNavigator1.Hints.Clear;
 DBNavigator1.Hints.Add(TranslateStr(738,''));
 DBNavigator1.Hints.Add(TranslateStr(736,''));
 DBNavigator1.Hints.Add(TranslateStr(737,''));

{$IFDEF MSWINDOWS}
 // The chip only makes sense for HTTP-driven datasets, which is the
 // path that goes through rpdcintegration. We always create it but
 // ApplyTransportChipForDatabase paints "Unknown" / "API" gracefully
 // when HubDatabaseId is 0 (BDE / FireDAC local datasets reach this
 // form too).
 CreateTransportChip;
 if FTransportChip <> nil then
   ApplyTransportChipForDatabase(FTransportChip, FHubDatabaseId);
{$ENDIF}
end;

{$IFDEF MSWINDOWS}
procedure TFRpShowSampledataVCL.CreateTransportChip;
begin
 FTransportChip := TPanel.Create(Self);
 FTransportChip.Parent := ToolBar1;
 // Anchor to the right of the toolbar so it sits next to BExit.
 FTransportChip.Align := alRight;
 FTransportChip.Width := 170;
 FTransportChip.Height := ToolBar1.ButtonHeight - 4;
 FTransportChip.Margins.Right := 6;
 FTransportChip.AlignWithMargins := True;
 // Caption + colors are set later by ApplyTransportChip.
 FTransportChip.Caption := '';
end;
{$ENDIF}

procedure TFRpShowSampledataVCL.SetHubDatabaseId(const AValue: Int64);
begin
 FHubDatabaseId := AValue;
{$IFDEF MSWINDOWS}
 // ShowDataset assigns HubDatabaseId AFTER Create(), so FormCreate
 // has already painted the chip with FHubDatabaseId=0 (which has no
 // cached transport and falls back to "Unknown"). Repaint now that
 // we know the real id.
 if FTransportChip <> nil then
   ApplyTransportChipForDatabase(FTransportChip, FHubDatabaseId);
{$ENDIF}
end;

end.
