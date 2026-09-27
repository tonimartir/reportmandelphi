{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdfsearchlcl                                  }
{       Search dialog for parameters (LCL version)      }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfsearchlcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, DB, DBGrids,
  rpmdconsts, rpdatainfo, rpparams, rpreport;

type
  { TFRpSearchParamLCL }

  TFRpSearchParamLCL = class(TForm)
  private
    param: TRpParam;
    params: TRpParamList;
    searchparam: TRpParam;
    databaseinfo: TRpDatabaseInfoList;
    datainfo: TRpDataInfoList;
    dinfo: TRpDataInfoItem;
    report: TRpReport;

    procedure BuildControls;
    procedure ESearchChange(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure BSearchClick(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure GridDataDblClick(Sender: TObject);
  public
    PTop: TPanel;
    LSearch: TLabel;
    ESearch: TEdit;
    BSearch: TButton;
    BOK: TButton;
    BCancel: TButton;
    GridData: TDBGrid;
    DataSource1: TDataSource;
    Timer1: TTimer;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

procedure ParamValueSearch(aparam: TRpParam; report: TRpReport);

implementation

uses
  rprflclparams;

procedure ParamValueSearch(aparam: TRpParam; report: TRpReport);
var
  dia: TFRpSearchParamLCL;
begin
  if not Assigned(aparam) or not Assigned(report) then Exit;

  dia := TFRpSearchParamLCL.Create(Application);
  try
    dia.param := aparam;
    dia.params := TRpParamList(aparam.Collection);
    dia.report := report;
    dia.databaseinfo := dia.report.DatabaseInfo;
    if Length(aparam.SearchParam) > 0 then
      dia.searchparam := dia.params.ParamByName(aparam.SearchParam);
    dia.datainfo := dia.report.DataInfo;

    dia.LSearch.Visible := Assigned(dia.searchparam);
    dia.ESearch.Visible := Assigned(dia.searchparam);
    dia.BSearch.Visible := Assigned(dia.searchparam);

    dia.dinfo := dia.datainfo.ItemByName(aparam.SearchDataset);
    if not Assigned(dia.dinfo) then
      Raise Exception.Create(SRpNotFound + ': ' + aparam.SearchDataset);

    try
      if not Assigned(dia.searchparam) then
      begin
        dia.BSearch.Visible := False;
        dia.Timer1Timer(dia);
      end;
      dia.ShowModal;
    finally
      dia.dinfo.Disconnect;
    end;
  finally
    dia.Free;
  end;
end;

{ TFRpSearchParamLCL }

constructor TFRpSearchParamLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  Caption := SRpSearchValue;
  Position := poScreenCenter;
  Width := 620;
  Height := 420;

  DataSource1 := TDataSource.Create(Self);

  Timer1 := TTimer.Create(Self);
  Timer1.Interval := 500;
  Timer1.Enabled := False;
  Timer1.OnTimer := Timer1Timer;

  BuildControls;
end;

destructor TFRpSearchParamLCL.Destroy;
begin
  inherited Destroy;
end;

procedure TFRpSearchParamLCL.BuildControls;
begin
  PTop := TPanel.Create(Self);
  PTop.Parent := Self;
  PTop.Align := alTop;
  PTop.Height := 46;
  PTop.BevelOuter := bvNone;

  LSearch := TLabel.Create(Self);
  LSearch.Parent := PTop;
  LSearch.Left := 10;
  LSearch.Top := 15;
  LSearch.Caption := SRpSearchValue + ':';

  ESearch := TEdit.Create(Self);
  ESearch.Parent := PTop;
  ESearch.Left := 100;
  ESearch.Top := 11;
  ESearch.Width := 200;
  ESearch.OnChange := ESearchChange;

  BSearch := TButton.Create(Self);
  BSearch.Parent := PTop;
  BSearch.Left := 310;
  BSearch.Top := 9;
  BSearch.Width := 80;
  BSearch.Height := 27;
  BSearch.Caption := SRpSearch;
  BSearch.OnClick := BSearchClick;

  BOK := TButton.Create(Self);
  BOK.Parent := PTop;
  BOK.Left := 400;
  BOK.Top := 9;
  BOK.Width := 80;
  BOK.Height := 27;
  BOK.Caption := TranslateStr(93, 'OK');
  BOK.Default := True;
  BOK.OnClick := BOKClick;

  BCancel := TButton.Create(Self);
  BCancel.Parent := PTop;
  BCancel.Left := 490;
  BCancel.Top := 9;
  BCancel.Width := 80;
  BCancel.Height := 27;
  BCancel.Caption := TranslateStr(94, 'Cancel');
  BCancel.Cancel := True;
  BCancel.OnClick := BCancelClick;

  GridData := TDBGrid.Create(Self);
  GridData.Parent := Self;
  GridData.Align := alClient;
  GridData.DataSource := DataSource1;
  GridData.ReadOnly := True;
  GridData.Options := GridData.Options + [dgRowSelect, dgAlwaysShowSelection];
  GridData.OnDblClick := GridDataDblClick;
end;

procedure TFRpSearchParamLCL.ESearchChange(Sender: TObject);
begin
  Timer1.Enabled := False;
  Timer1.Enabled := True;
end;

procedure TFRpSearchParamLCL.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := False;
  if not Assigned(dinfo) then Exit;

  try
    dinfo.Disconnect;
    if Assigned(searchparam) then
      searchparam.Value := ESearch.Text;
    dinfo.Connect(databaseinfo, params);

    if Assigned(dinfo.Dataset) then
    begin
      DataSource1.DataSet := dinfo.Dataset;
      if not dinfo.Dataset.Active then
        dinfo.Dataset.Open;
      BOK.Enabled := not dinfo.Dataset.EOF;
      GridData.Visible := True;
    end
    else
    begin
      BOK.Enabled := False;
      GridData.Visible := False;
    end;
  except
    GridData.Visible := False;
    BOK.Enabled := False;
    raise;
  end;
end;

procedure TFRpSearchParamLCL.BSearchClick(Sender: TObject);
begin
  Timer1Timer(Self);
end;

procedure TFRpSearchParamLCL.BOKClick(Sender: TObject);
begin
  if Assigned(DataSource1.DataSet) and DataSource1.DataSet.Active and
     (not DataSource1.DataSet.EOF) and (DataSource1.DataSet.FieldCount > 0) then
  begin
    param.Value := DataSource1.DataSet.Fields[0].AsVariant;
    ModalResult := mrOk;
  end
  else
    ModalResult := mrCancel;
end;

procedure TFRpSearchParamLCL.BCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFRpSearchParamLCL.GridDataDblClick(Sender: TObject);
begin
  if BOK.Enabled then
    BOKClick(BOK);
end;

procedure ParamValueSearchWrapper(aparam: TRpParam; report: TComponent);
begin
  if report is TRpReport then
    ParamValueSearch(aparam, TRpReport(report));
end;

initialization
  rprflclparams.GlobalParamValueSearch := ParamValueSearchWrapper;

finalization
  rprflclparams.GlobalParamValueSearch := nil;

end.
