{*******************************************************}
{                                                       }
{       Report Manager Designer - LCL                   }
{                                                       }
{       rpmdfdatatextlcl                                }
{       Form for configuration of text file datasets    }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}

unit rpmdfdatatextlcl;

{ Port of rpmdfdatatextvcl (TFRpDataTextVCL): the field definitions file of
  a MyBase dataset read from a text file (position, size and type of each
  field, rpdatatext), with the sample text file and the records read with the
  definitions (Open). The VCL edits the definitions in a TDBGrid over a
  TClientDataSet with lookup fields; here a TStringGrid with pick lists for
  the type and the trim flag (same columns). OK saves the file, Cancel (or
  closing the window, as in the VCL) discards the changes. }

{$mode delphi}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  ComCtrls, Grids, DB, rpmdconsts, rpdatatext, rpdataset;

type
  { TFRpDataTextLCL }

  TFRpDataTextLCL = class(TForm)
  private
    FFileName: string;
    FSampleFile: string;
    FData: TRpMemDataSet;
    FImages: TImageList;
    PTop: TPanel;
    LFieldsFile: TLabel;
    LSampleFile: TLabel;
    FEFileName: TEdit;
    FESampleFile: TEdit;
    PList: TPanel;
    ToolBar1: TToolBar;
    BNewField: TToolButton;
    BDeleteField: TToolButton;
    FGridFields: TStringGrid;
    Splitter1: TSplitter;
    PBottom: TPanel;
    PFieldProps: TPanel;
    Label3: TLabel;
    Label4: TLabel;
    FERecordSeparator: TEdit;
    FEIgnoreAfterRecordSeparator: TEdit;
    BOK: TButton;
    FBTest: TButton;
    BCancel: TButton;
    FPControl: TPageControl;
    FTabSource: TTabSheet;
    FTabData: TTabSheet;
    FMSource: TMemo;
    FGridData: TStringGrid;
    procedure BuildControls;
    procedure ReadFromFile;
    procedure ConvertToFieldList(AList: TStringList);
    procedure SetRowDefaults(ARow: Integer);
    procedure BNewFieldClick(Sender: TObject);
    procedure BDeleteFieldClick(Sender: TObject);
    procedure BOkClick(Sender: TObject);
    procedure BTestClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Reads the definitions and the sample file (VCL FormShow)
    procedure LoadFiles(const AFileName, ASampleFile: string);
    // Operations of the buttons
    procedure AddField;
    procedure DeleteField;
    procedure Save;
    // Saves and reads the sample file with the definitions (VCL BTestClick)
    procedure TestData;
    property FileName: string read FFileName;
    property SampleFile: string read FSampleFile;
    property EFileName: TEdit read FEFileName;
    property ESampleFile: TEdit read FESampleFile;
    property GridFields: TStringGrid read FGridFields;
    property GridData: TStringGrid read FGridData;
    property ERecordSeparator: TEdit read FERecordSeparator;
    property EIgnoreAfterRecordSeparator: TEdit read FEIgnoreAfterRecordSeparator;
    property BTest: TButton read FBTest;
    property MSource: TMemo read FMSource;
    property PControl: TPageControl read FPControl;
    property TabSource: TTabSheet read FTabSource;
    property TabData: TTabSheet read FTabData;
  end;

// Edits the field definitions file of a text file (samplefile: the text
// file, optional)
procedure ShowDataTextConfig(filename, samplefile: string);

// Columns of the definitions grid
const
  DTCOL_FIELDNAME = 0;
  DTCOL_FIELDTYPE = 1;
  DTCOL_FIELDSIZE = 2;
  DTCOL_POSBEGIN = 3;
  DTCOL_TRIM = 4;
  DTCOL_PRECISION = 5;
  DTCOL_POSBEGINPRECISION = 6;
  DTCOL_YEARPOS = 7;
  DTCOL_YEARSIZE = 8;
  DTCOL_MONTHPOS = 9;
  DTCOL_MONTHSIZE = 10;
  DTCOL_DAYPOS = 11;
  DTCOL_DAYSIZE = 12;
  DTCOL_HOURPOS = 13;
  DTCOL_HOURSIZE = 14;
  DTCOL_MINPOS = 15;
  DTCOL_MINSIZE = 16;
  DTCOL_SECPOS = 17;
  DTCOL_SECSIZE = 18;
  DTCOL_COUNT = 19;

// Name of a field type in the grid, and back (the VCL DDataType lookup)
function DataTextTypeName(AType: TFieldType): string;
function DataTextTypeFromName(const AName: string): TFieldType;

implementation

uses
  rpdbxconfiglcl, rpmdfsampledatalcl, rpmdimageslcl, rplcllayout;

const
  // The types of the VCL DDataType lookup
  DATATEXT_TYPES: array[0..7] of TFieldType = (ftInteger, ftString, ftCurrency,
    ftDate, ftTime, ftDateTime, ftBoolean, ftMemo);
  // Titles of the columns (the field names of the VCL DFields dataset)
  DATATEXT_TITLES: array[0..DTCOL_COUNT - 1] of string = ('FIELDNAME',
    'FIELDTYPENAME', 'FIELDSIZE', 'POSBEGIN', 'TRIM', 'PRECISION',
    'POSBEGINPRECISION', 'YEARPOS', 'YEARSIZE', 'MONTHPOS', 'MONTHSIZE',
    'DAYPOS', 'DAYSIZE', 'HOURPOS', 'HOURSIZE', 'MINPOS', 'MINSIZE', 'SECPOS',
    'SECSIZE');

function DataTextTypeName(AType: TFieldType): string;
begin
  case AType of
    ftInteger:
      Result := SRpSInteger;
    ftString:
      Result := SRpSString;
    ftCurrency:
      Result := SRpSCurrency;
    ftDate:
      Result := SRpSDate;
    ftTime:
      Result := SRpSTime;
    ftDateTime:
      Result := SRpSDateTime;
    ftBoolean:
      Result := SRpSBoolean;
    ftMemo:
      Result := SRpSMemo;
  else
    // Another type written by hand in the file: kept by its number
    Result := IntToStr(Ord(AType));
  end;
end;

function DataTextTypeFromName(const AName: string): TFieldType;
var
  i, LCode: Integer;
begin
  for i := Low(DATATEXT_TYPES) to High(DATATEXT_TYPES) do
    if SameText(AName, DataTextTypeName(DATATEXT_TYPES[i])) then
      Exit(DATATEXT_TYPES[i]);
  LCode := StrToIntDef(Trim(AName), -1);
  if (LCode >= Ord(Low(TFieldType))) and (LCode <= Ord(High(TFieldType))) then
    Result := TFieldType(LCode)
  else
    Result := ftString;
end;

procedure ShowDataTextConfig(filename, samplefile: string);
var
  dia: TFRpDataTextLCL;
begin
  if Length(Trim(filename)) < 1 then
    raise Exception.Create(SRpFieldsFileNotDefined);
  dia := TFRpDataTextLCL.Create(Application);
  try
    dia.LoadFiles(filename, samplefile);
    dia.ShowModal;
  finally
    dia.Free;
  end;
end;

{ TFRpDataTextLCL }

constructor TFRpDataTextLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  // Sizes in pixels of the screen: the LCL does not scale it again
  RpBuiltInScreenPixels(Self);
  Caption := TranslateStr(1088, 'Text file to database table configuration');
  Position := poScreenCenter;
  ShowHint := True;
  // Fits a 800x600 screen
  Width := Min(Scale96ToScreen(680), Screen.WorkAreaWidth - 20);
  Height := Min(Scale96ToScreen(500), Screen.WorkAreaHeight - 20);
  FData := TRpMemDataSet.Create(Self);
  BuildControls;
end;

destructor TFRpDataTextLCL.Destroy;
begin
  if FData <> nil then
    FData.Close;
  inherited Destroy;
end;

procedure TFRpDataTextLCL.BuildControls;
var
  LLabelWidth, LButtonWidth, i: Integer;
  LCol: TGridColumn;
begin
  FImages := TImageList.Create(Self);
  LoadDesignerImageList(FImages);

  // Files
  PTop := TPanel.Create(Self);
  PTop.Parent := Self;
  PTop.Align := alTop;
  PTop.BevelOuter := bvNone;
  PTop.Height := Scale96ToScreen(62);

  LFieldsFile := TLabel.Create(Self);
  LFieldsFile.Parent := PTop;
  LFieldsFile.Caption := TranslateStr(1085, 'Fields file');
  LSampleFile := TLabel.Create(Self);
  LSampleFile.Parent := PTop;
  LSampleFile.Caption := TranslateStr(1087, 'Sample file');
  LLabelWidth := RpCaptionWidth(Self, [LFieldsFile.Caption, LSampleFile.Caption], 100);
  LFieldsFile.SetBounds(Scale96ToScreen(8), Scale96ToScreen(9), LLabelWidth, Scale96ToScreen(18));
  LSampleFile.SetBounds(Scale96ToScreen(8), Scale96ToScreen(36), LLabelWidth, Scale96ToScreen(18));

  FEFileName := TEdit.Create(Self);
  FEFileName.Parent := PTop;
  FEFileName.ReadOnly := True;
  FEFileName.Color := clInfoBk;
  FEFileName.Left := Scale96ToScreen(8) + LLabelWidth;
  FEFileName.Top := Scale96ToScreen(5);
  FEFileName.AnchorParallel(akRight, Scale96ToScreen(8), PTop);
  FEFileName.Anchors := [akLeft, akTop, akRight];

  FESampleFile := TEdit.Create(Self);
  FESampleFile.Parent := PTop;
  FESampleFile.ReadOnly := True;
  FESampleFile.Color := clInfoBk;
  FESampleFile.Left := FEFileName.Left;
  FESampleFile.Top := Scale96ToScreen(32);
  FESampleFile.AnchorParallel(akRight, Scale96ToScreen(8), PTop);
  FESampleFile.Anchors := [akLeft, akTop, akRight];

  // Field definitions
  PList := TPanel.Create(Self);
  PList.Parent := Self;
  PList.Align := alTop;
  PList.BevelOuter := bvNone;
  PList.Height := Scale96ToScreen(170);
  PList.Top := PTop.Top + PTop.Height + 1;

  ToolBar1 := TToolBar.Create(Self);
  ToolBar1.Parent := PList;
  ToolBar1.Align := alTop;
  ToolBar1.Images := FImages;
  ToolBar1.ShowHint := True;
  ToolBar1.ButtonWidth := Scale96ToScreen(28);
  ToolBar1.ButtonHeight := Scale96ToScreen(28);
  ToolBar1.Height := Scale96ToScreen(30);

  BNewField := TToolButton.Create(Self);
  BNewField.Parent := ToolBar1;
  BNewField.ImageIndex := IMG_NEW;
  BNewField.Caption := TranslateStr(1091, 'New field');
  BNewField.Hint := TranslateStr(1092, 'Adds a new field definition');
  BNewField.OnClick := BNewFieldClick;

  BDeleteField := TToolButton.Create(Self);
  BDeleteField.Parent := ToolBar1;
  BDeleteField.ImageIndex := IMG_DELETE;
  BDeleteField.Caption := TranslateStr(1093, 'Delete field');
  BDeleteField.Hint := TranslateStr(1094, 'Deletes the selected field definition');
  BDeleteField.OnClick := BDeleteFieldClick;
  BDeleteField.Left := BNewField.Left + BNewField.Width + 1;

  FGridFields := TStringGrid.Create(Self);
  FGridFields.Parent := PList;
  FGridFields.Align := alClient;
  FGridFields.FixedCols := 0;
  FGridFields.RowCount := 1;
  FGridFields.FixedRows := 1;
  FGridFields.Options := FGridFields.Options + [goEditing, goColSizing, goTabs,
    goAlwaysShowEditor] - [goRangeSelect];
  FGridFields.DefaultRowHeight := Scale96ToScreen(22);
  for i := 0 to DTCOL_COUNT - 1 do
  begin
    LCol := FGridFields.Columns.Add;
    LCol.Title.Caption := DATATEXT_TITLES[i];
    if i = DTCOL_FIELDNAME then
      LCol.Width := Scale96ToScreen(130)
    else if i = DTCOL_FIELDTYPE then
      LCol.Width := Scale96ToScreen(110)
    else
      LCol.Width := RpCaptionWidth(Self, [DATATEXT_TITLES[i]], 60);
  end;
  // Type and trim: the lookups of the VCL dataset
  LCol := FGridFields.Columns[DTCOL_FIELDTYPE];
  LCol.ButtonStyle := cbsPickList;
  for i := Low(DATATEXT_TYPES) to High(DATATEXT_TYPES) do
    LCol.PickList.Add(DataTextTypeName(DATATEXT_TYPES[i]));
  LCol := FGridFields.Columns[DTCOL_TRIM];
  LCol.ButtonStyle := cbsPickList;
  LCol.PickList.Add(SRpYes);
  LCol.PickList.Add(SRpNo);

  Splitter1 := TSplitter.Create(Self);
  Splitter1.Parent := Self;
  Splitter1.Align := alTop;
  Splitter1.Height := Scale96ToScreen(6);
  Splitter1.Top := PList.Top + PList.Height + 1;

  PBottom := TPanel.Create(Self);
  PBottom.Parent := Self;
  PBottom.Align := alClient;
  PBottom.BevelOuter := bvNone;

  PFieldProps := TPanel.Create(Self);
  PFieldProps.Parent := PBottom;
  PFieldProps.Align := alTop;
  PFieldProps.BevelOuter := bvNone;
  PFieldProps.Height := Scale96ToScreen(92);

  Label3 := TLabel.Create(Self);
  Label3.Parent := PFieldProps;
  Label3.Caption := TranslateStr(1089, 'Record separator (ASCII code)');
  Label4 := TLabel.Create(Self);
  Label4.Parent := PFieldProps;
  Label4.Caption := TranslateStr(1090, 'Ignore after record separator (ASCII code)');
  LLabelWidth := RpCaptionWidth(Self, [Label3.Caption, Label4.Caption], 150);
  Label3.SetBounds(Scale96ToScreen(8), Scale96ToScreen(8), LLabelWidth, Scale96ToScreen(18));
  Label4.SetBounds(Scale96ToScreen(8), Scale96ToScreen(34), LLabelWidth, Scale96ToScreen(18));

  FERecordSeparator := TEdit.Create(Self);
  FERecordSeparator.Parent := PFieldProps;
  FERecordSeparator.SetBounds(Scale96ToScreen(8) + LLabelWidth, Scale96ToScreen(4),
    Scale96ToScreen(60), Scale96ToScreen(24));

  FEIgnoreAfterRecordSeparator := TEdit.Create(Self);
  FEIgnoreAfterRecordSeparator.Parent := PFieldProps;
  FEIgnoreAfterRecordSeparator.SetBounds(Scale96ToScreen(8) + LLabelWidth, Scale96ToScreen(30),
    Scale96ToScreen(60), Scale96ToScreen(24));

  LButtonWidth := RpCaptionWidth(Self, [TranslateStr(93, 'OK'), TranslateStr(42, 'Open'),
    TranslateStr(94, 'Cancel')], 80);
  BOK := TButton.Create(Self);
  BOK.Parent := PFieldProps;
  BOK.Caption := SRpOk;
  BOK.Default := True;
  BOK.OnClick := BOkClick;
  BOK.SetBounds(Scale96ToScreen(8), Scale96ToScreen(60), LButtonWidth, Scale96ToScreen(28));

  FBTest := TButton.Create(Self);
  FBTest.Parent := PFieldProps;
  FBTest.Caption := TranslateStr(42, 'Open');
  FBTest.OnClick := BTestClick;
  FBTest.SetBounds(BOK.Left + LButtonWidth + Scale96ToScreen(8), Scale96ToScreen(60),
    LButtonWidth, Scale96ToScreen(28));

  BCancel := TButton.Create(Self);
  BCancel.Parent := PFieldProps;
  BCancel.Caption := TranslateStr(94, 'Cancel');
  BCancel.Cancel := True;
  BCancel.OnClick := BCancelClick;
  BCancel.SetBounds(FBTest.Left + LButtonWidth + Scale96ToScreen(8), Scale96ToScreen(60),
    LButtonWidth, Scale96ToScreen(28));

  FPControl := TPageControl.Create(Self);
  FPControl.Parent := PBottom;
  FPControl.Align := alClient;

  FTabSource := TTabSheet.Create(FPControl);
  FTabSource.PageControl := FPControl;
  FTabSource.Caption := TranslateStr(1096, 'Source');

  FMSource := TMemo.Create(Self);
  FMSource.Parent := FTabSource;
  FMSource.Align := alClient;
  FMSource.ReadOnly := True;
  FMSource.Color := clInfoBk;
  FMSource.ScrollBars := ssBoth;
  FMSource.WordWrap := False;
  FMSource.Font.Name := 'Courier New';

  FTabData := TTabSheet.Create(FPControl);
  FTabData.PageControl := FPControl;
  FTabData.Caption := TranslateStr(1095, 'Data');

  FGridData := TStringGrid.Create(Self);
  FGridData.Parent := FTabData;
  FGridData.Align := alClient;
  FGridData.Options := FGridData.Options + [goColSizing] - [goEditing, goRangeSelect];
  FGridData.RowCount := 1;
  FGridData.ColCount := 1;
  FGridData.DefaultRowHeight := Scale96ToScreen(22);
  FPControl.ActivePage := FTabSource;
end;

procedure TFRpDataTextLCL.SetRowDefaults(ARow: Integer);
var
  i: Integer;
begin
  // VCL DFieldsNewRecord
  FGridFields.Cells[DTCOL_FIELDNAME, ARow] := '';
  FGridFields.Cells[DTCOL_FIELDTYPE, ARow] := DataTextTypeName(ftString);
  FGridFields.Cells[DTCOL_POSBEGIN, ARow] := '1';
  FGridFields.Cells[DTCOL_TRIM, ARow] := SRpYes;
  for i := 0 to DTCOL_COUNT - 1 do
    if not (i in [DTCOL_FIELDNAME, DTCOL_FIELDTYPE, DTCOL_POSBEGIN, DTCOL_TRIM]) then
      FGridFields.Cells[i, ARow] := '0';
end;

procedure TFRpDataTextLCL.ReadFromFile;
var
  lfields: TStringList;
  recordseparator, ignoreafterrecordseparator: Char;
  aobj: TRpFieldObj;
  i, LRow: Integer;
begin
  lfields := TStringList.Create;
  try
    FillFieldObjList(FFileName, lfields, recordseparator, ignoreafterrecordseparator);
    FERecordSeparator.Text := IntToStr(Ord(recordseparator));
    FEIgnoreAfterRecordSeparator.Text := IntToStr(Ord(ignoreafterrecordseparator));
    // VCL FillList
    FGridFields.RowCount := 1 + lfields.Count;
    for i := 0 to lfields.Count - 1 do
    begin
      aobj := TRpFieldObj(lfields.Objects[i]);
      LRow := i + 1;
      FGridFields.Cells[DTCOL_FIELDNAME, LRow] := aobj.fieldname;
      FGridFields.Cells[DTCOL_FIELDTYPE, LRow] := DataTextTypeName(aobj.fieldtype);
      FGridFields.Cells[DTCOL_FIELDSIZE, LRow] := IntToStr(aobj.fieldsize);
      FGridFields.Cells[DTCOL_POSBEGIN, LRow] := IntToStr(aobj.posbegin);
      if aobj.fieldtrim then
        FGridFields.Cells[DTCOL_TRIM, LRow] := SRpYes
      else
        FGridFields.Cells[DTCOL_TRIM, LRow] := SRpNo;
      FGridFields.Cells[DTCOL_PRECISION, LRow] := IntToStr(aobj.precision);
      FGridFields.Cells[DTCOL_POSBEGINPRECISION, LRow] := IntToStr(aobj.posbeginprecision);
      FGridFields.Cells[DTCOL_YEARPOS, LRow] := IntToStr(aobj.yearpos);
      FGridFields.Cells[DTCOL_YEARSIZE, LRow] := IntToStr(aobj.yearsize);
      FGridFields.Cells[DTCOL_MONTHPOS, LRow] := IntToStr(aobj.monthpos);
      FGridFields.Cells[DTCOL_MONTHSIZE, LRow] := IntToStr(aobj.monthsize);
      FGridFields.Cells[DTCOL_DAYPOS, LRow] := IntToStr(aobj.daypos);
      FGridFields.Cells[DTCOL_DAYSIZE, LRow] := IntToStr(aobj.daysize);
      FGridFields.Cells[DTCOL_HOURPOS, LRow] := IntToStr(aobj.hourpos);
      FGridFields.Cells[DTCOL_HOURSIZE, LRow] := IntToStr(aobj.hoursize);
      FGridFields.Cells[DTCOL_MINPOS, LRow] := IntToStr(aobj.minpos);
      FGridFields.Cells[DTCOL_MINSIZE, LRow] := IntToStr(aobj.minsize);
      FGridFields.Cells[DTCOL_SECPOS, LRow] := IntToStr(aobj.secpos);
      FGridFields.Cells[DTCOL_SECSIZE, LRow] := IntToStr(aobj.secsize);
    end;
  finally
    FreeFieldObjList(lfields);
    lfields.Free;
  end;
end;

procedure TFRpDataTextLCL.LoadFiles(const AFileName, ASampleFile: string);
begin
  FFileName := AFileName;
  FSampleFile := ASampleFile;
  FEFileName.Text := AFileName;
  FESampleFile.Text := ASampleFile;
  // Open reads the sample file with the definitions
  FBTest.Visible := Length(Trim(ASampleFile)) > 0;
  ReadFromFile;
  FMSource.Clear;
  if FBTest.Visible and FileExists(ASampleFile) then
    FMSource.Lines.LoadFromFile(ASampleFile);
  FPControl.ActivePage := FTabSource;
end;

procedure TFRpDataTextLCL.ConvertToFieldList(AList: TStringList);
var
  aobj: TRpFieldObj;
  LRow: Integer;

  function IntCell(ACol: Integer): Integer;
  begin
    Result := StrToIntDef(Trim(FGridFields.Cells[ACol, LRow]), 0);
  end;

begin
  // A grid cell being edited is in the grid already (goAlwaysShowEditor
  // writes on each change); rows without a name are not definitions
  for LRow := FGridFields.FixedRows to FGridFields.RowCount - 1 do
  begin
    if Trim(FGridFields.Cells[DTCOL_FIELDNAME, LRow]) = '' then
      Continue;
    aobj := TRpFieldObj.Create;
    aobj.fieldname := Trim(FGridFields.Cells[DTCOL_FIELDNAME, LRow]);
    aobj.fieldtype := DataTextTypeFromName(FGridFields.Cells[DTCOL_FIELDTYPE, LRow]);
    aobj.fieldsize := IntCell(DTCOL_FIELDSIZE);
    aobj.posbegin := IntCell(DTCOL_POSBEGIN);
    aobj.fieldtrim := not SameText(Trim(FGridFields.Cells[DTCOL_TRIM, LRow]), SRpNo);
    aobj.precision := IntCell(DTCOL_PRECISION);
    aobj.posbeginprecision := IntCell(DTCOL_POSBEGINPRECISION);
    aobj.yearpos := IntCell(DTCOL_YEARPOS);
    aobj.yearsize := IntCell(DTCOL_YEARSIZE);
    aobj.monthpos := IntCell(DTCOL_MONTHPOS);
    aobj.monthsize := IntCell(DTCOL_MONTHSIZE);
    aobj.daypos := IntCell(DTCOL_DAYPOS);
    aobj.daysize := IntCell(DTCOL_DAYSIZE);
    aobj.hourpos := IntCell(DTCOL_HOURPOS);
    aobj.hoursize := IntCell(DTCOL_HOURSIZE);
    aobj.minpos := IntCell(DTCOL_MINPOS);
    aobj.minsize := IntCell(DTCOL_MINSIZE);
    aobj.secpos := IntCell(DTCOL_SECPOS);
    aobj.secsize := IntCell(DTCOL_SECSIZE);
    AList.AddObject(aobj.fieldname, aobj);
  end;
end;

procedure TFRpDataTextLCL.Save;
var
  lfields: TStringList;
  recordseparator, ignoreafterrecordseparator: Char;
begin
  // VCL DoSave
  if FGridFields.EditorMode then
    FGridFields.EditorMode := False;
  lfields := TStringList.Create;
  try
    ConvertToFieldList(lfields);
    recordseparator := Chr(StrToIntDef(Trim(FERecordSeparator.Text), 13) and $FF);
    ignoreafterrecordseparator :=
      Chr(StrToIntDef(Trim(FEIgnoreAfterRecordSeparator.Text), 10) and $FF);
    SaveFieldObjListToFile(lfields, FFileName, recordseparator, ignoreafterrecordseparator);
  finally
    FreeFieldObjList(lfields);
    lfields.Free;
  end;
end;

procedure TFRpDataTextLCL.AddField;
var
  LRow: Integer;
begin
  // VCL ANewFieldExecute (DFields.Insert at the current record)
  if FGridFields.EditorMode then
    FGridFields.EditorMode := False;
  LRow := FGridFields.Row;
  if LRow < FGridFields.FixedRows then
    LRow := FGridFields.RowCount
  else
    LRow := LRow + 1;
  if LRow > FGridFields.RowCount then
    LRow := FGridFields.RowCount;
  FGridFields.InsertColRow(False, LRow);
  SetRowDefaults(LRow);
  FGridFields.Row := LRow;
  FGridFields.Col := DTCOL_FIELDNAME;
end;

procedure TFRpDataTextLCL.DeleteField;
begin
  if FGridFields.EditorMode then
    FGridFields.EditorMode := False;
  if (FGridFields.Row >= FGridFields.FixedRows) and (FGridFields.Row < FGridFields.RowCount) then
    FGridFields.DeleteRow(FGridFields.Row);
end;

procedure TFRpDataTextLCL.TestData;
begin
  // VCL BTestClick
  Save;
  FData.Close;
  FillClientDatasetFromFile(FData, FFileName, FSampleFile, '');
  FData.First;
  FillGridFromDataset(FGridData, FData, RP_SAMPLE_DATA_BATCH, False);
  FGridData.AutoSizeColumns;
  FPControl.ActivePage := FTabData;
end;

procedure TFRpDataTextLCL.BNewFieldClick(Sender: TObject);
begin
  AddField;
end;

procedure TFRpDataTextLCL.BDeleteFieldClick(Sender: TObject);
begin
  DeleteField;
end;

procedure TFRpDataTextLCL.BOkClick(Sender: TObject);
begin
  Save;
  ModalResult := mrOk;
end;

procedure TFRpDataTextLCL.BTestClick(Sender: TObject);
begin
  TestData;
end;

procedure TFRpDataTextLCL.BCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
