{*******************************************************}
{                                                       }
{       Report Manager Designer - LCL                   }
{                                                       }
{       rpmdfsampledatalcl                              }
{       Show data of a unidirectional query             }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}

unit rpmdfsampledatalcl;

{ Port of rpmdfsampledatavcl (TFRpShowSampledataVCL, "Show data" of the
  dataset configuration). The VCL form shows one record at a time (First /
  Next); this one shows the records in a grid, read forward only (the
  datasets may be unidirectional) in batches of BatchSize records: "More
  records" reads the next batch. The WebRTC transport chip of the VCL (Hub
  datasets, Windows/Delphi only) is not ported. }

{$mode delphi}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  Grids, DB, rpmdconsts;

const
  RP_SAMPLE_DATA_BATCH = 1000;

type
  { TFRpShowSampleDataLCL }

  TFRpShowSampleDataLCL = class(TForm)
  private
    FDataset: TDataset;
    FBatchSize: Integer;
    FAllLoaded: Boolean;
    FGrid: TStringGrid;
    PTop: TPanel;
    BMore: TButton;
    BClose: TButton;
    LCount: TLabel;
    procedure BMoreClick(Sender: TObject);
    procedure BCloseClick(Sender: TObject);
    procedure UpdateState;
  public
    constructor Create(AOwner: TComponent); override;
    // Shows the fields of the dataset and its first batch of records (from
    // the current one)
    procedure SetDataset(ADataset: TDataset);
    // Reads the next batch of records
    procedure LoadMore;
    // Records shown
    function RecordCount: Integer;
    property Dataset: TDataset read FDataset;
    property Grid: TStringGrid read FGrid;
    property BatchSize: Integer read FBatchSize write FBatchSize;
    // True when the last record was read
    property AllLoaded: Boolean read FAllLoaded;
    property MoreButton: TButton read BMore;
  end;

// Shows the records of an open dataset (modal)
procedure ShowDataset(Data: TDataset);

// Fills a grid with the fields of a dataset: row 0 the field names, column 0
// the record numbers. Reads up to AMaxRows records from the current one
// (forward only); with AAppend the rows are added to the ones in the grid.
// Returns True when the end of the dataset was reached.
function FillGridFromDataset(AGrid: TStringGrid; ADataset: TDataset;
  AMaxRows: Integer; AAppend: Boolean): Boolean;

// The text of a field for the grid (first line of memos, (BLOB) for binary)
function SampleFieldText(AField: TField): string;

implementation

uses
  rpdbxconfiglcl;

const
  MAX_CELL_TEXT = 250;
  MAX_COLUMN_WIDTH = 300;

function SampleFieldText(AField: TField): string;
var
  P: Integer;
begin
  if AField.IsNull then
    Exit('');
  case AField.DataType of
    ftBlob, ftGraphic, ftTypedBinary, ftBytes, ftVarBytes, ftParadoxOle,
    ftDBaseOle:
      Result := '(BLOB)';
    ftMemo, ftWideMemo, ftFmtMemo:
      Result := AField.AsString;
  else
    Result := AField.DisplayText;
  end;
  P := Pos(#10, Result);
  if P > 0 then
    Result := TrimRight(Copy(Result, 1, P - 1)) + '...';
  P := Pos(#13, Result);
  if P > 0 then
    Result := Copy(Result, 1, P - 1) + '...';
  if Length(Result) > MAX_CELL_TEXT then
    Result := Copy(Result, 1, MAX_CELL_TEXT) + '...';
end;

function FillGridFromDataset(AGrid: TStringGrid; ADataset: TDataset;
  AMaxRows: Integer; AAppend: Boolean): Boolean;
var
  i, LRow, LRead: Integer;
begin
  Result := True;
  AGrid.BeginUpdate;
  try
    if not AAppend then
    begin
      AGrid.RowCount := 1;
      AGrid.FixedRows := 1;
      AGrid.FixedCols := 1;
      if (ADataset <> nil) and ADataset.Active then
        AGrid.ColCount := ADataset.FieldCount + 1
      else
        AGrid.ColCount := 1;
      AGrid.Cells[0, 0] := '';
      if (ADataset <> nil) and ADataset.Active then
        for i := 0 to ADataset.FieldCount - 1 do
          AGrid.Cells[i + 1, 0] := ADataset.Fields[i].FieldName;
    end;
    if (ADataset = nil) or (not ADataset.Active) then
      Exit;
    LRead := 0;
    while (not ADataset.Eof) and (LRead < AMaxRows) do
    begin
      LRow := AGrid.RowCount;
      AGrid.RowCount := LRow + 1;
      AGrid.Cells[0, LRow] := IntToStr(LRow);
      for i := 0 to ADataset.FieldCount - 1 do
        AGrid.Cells[i + 1, LRow] := SampleFieldText(ADataset.Fields[i]);
      Inc(LRead);
      ADataset.Next;
    end;
    Result := ADataset.Eof;
  finally
    AGrid.EndUpdate;
  end;
end;

procedure ShowDataset(Data: TDataset);
var
  dia: TFRpShowSampleDataLCL;
begin
  dia := TFRpShowSampleDataLCL.Create(Application);
  try
    dia.SetDataset(Data);
    dia.ShowModal;
  finally
    dia.Free;
  end;
end;

{ TFRpShowSampleDataLCL }

constructor TFRpShowSampleDataLCL.Create(AOwner: TComponent);
var
  LWidth: Integer;
begin
  inherited CreateNew(AOwner);
  FBatchSize := RP_SAMPLE_DATA_BATCH;
  Caption := TranslateStr(735, 'Data');
  Position := poScreenCenter;
  ShowHint := True;
  // Fits a 800x600 screen
  Width := Min(Scale96ToScreen(780), Screen.WorkAreaWidth - 20);
  Height := Min(Scale96ToScreen(540), Screen.WorkAreaHeight - 20);

  PTop := TPanel.Create(Self);
  PTop.Parent := Self;
  PTop.Align := alTop;
  PTop.BevelOuter := bvNone;
  PTop.Height := Scale96ToScreen(36);

  BClose := TButton.Create(Self);
  BClose.Parent := PTop;
  // VCL BExit
  BClose.Caption := TranslateStr(44, 'Exit');
  BClose.Hint := TranslateStr(212, 'Closes the window');
  BClose.Cancel := True;
  BClose.OnClick := BCloseClick;
  LWidth := RpCaptionWidth(BClose, [BClose.Caption]);
  BClose.SetBounds(PTop.Width - LWidth - Scale96ToScreen(6), Scale96ToScreen(5), LWidth,
    Scale96ToScreen(26));
  BClose.AnchorParallel(akRight, Scale96ToScreen(6), PTop);
  BClose.Anchors := [akTop, akRight];

  BMore := TButton.Create(Self);
  BMore.Parent := PTop;
  BMore.Caption := TranslateStr(1681, 'More records');
  BMore.OnClick := BMoreClick;
  BMore.SetBounds(Scale96ToScreen(6), Scale96ToScreen(5), RpCaptionWidth(BMore, [BMore.Caption]),
    Scale96ToScreen(26));

  LCount := TLabel.Create(Self);
  LCount.Parent := PTop;
  LCount.Left := BMore.Left + BMore.Width + Scale96ToScreen(10);
  LCount.Top := Scale96ToScreen(11);

  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.Options := FGrid.Options + [goColSizing, goThumbTracking] - [goEditing, goRangeSelect];
  FGrid.RowCount := 1;
  FGrid.ColCount := 1;
  FGrid.FixedRows := 1;
  FGrid.FixedCols := 1;
  FGrid.DefaultColWidth := Scale96ToScreen(100);
  FGrid.DefaultRowHeight := Scale96ToScreen(22);
end;

procedure TFRpShowSampleDataLCL.UpdateState;
begin
  BMore.Enabled := (FDataset <> nil) and FDataset.Active and (not FAllLoaded);
  LCount.Caption := TranslateStr(684, 'Record count') + ': ' + IntToStr(RecordCount);
  if BMore.Enabled then
    LCount.Caption := LCount.Caption + '+';
end;

function TFRpShowSampleDataLCL.RecordCount: Integer;
begin
  Result := FGrid.RowCount - FGrid.FixedRows;
end;

procedure TFRpShowSampleDataLCL.SetDataset(ADataset: TDataset);
var
  i: Integer;
begin
  FDataset := ADataset;
  FAllLoaded := FillGridFromDataset(FGrid, FDataset, FBatchSize, False);
  // Column widths from the names and the first records
  FGrid.AutoSizeColumns;
  FGrid.ColWidths[0] := Max(Scale96ToScreen(40), FGrid.ColWidths[0]);
  for i := 1 to FGrid.ColCount - 1 do
    FGrid.ColWidths[i] := Min(Max(FGrid.ColWidths[i], Scale96ToScreen(50)),
      Scale96ToScreen(MAX_COLUMN_WIDTH));
  UpdateState;
end;

procedure TFRpShowSampleDataLCL.LoadMore;
begin
  if (FDataset = nil) or FAllLoaded then
    Exit;
  FAllLoaded := FillGridFromDataset(FGrid, FDataset, FBatchSize, True);
  UpdateState;
end;

procedure TFRpShowSampleDataLCL.BMoreClick(Sender: TObject);
begin
  LoadMore;
end;

procedure TFRpShowSampleDataLCL.BCloseClick(Sender: TObject);
begin
  Close;
end;

end.
