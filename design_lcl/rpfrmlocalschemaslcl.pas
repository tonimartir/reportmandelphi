{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpfrmlocalschemaslcl                            }
{                                                       }
{       The local schema of a direct connection for     }
{       the AI: its dictionary, its subschemas and      }
{       what the AI understands of them                 }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpfrmlocalschemaslcl;

{$mode delphi}

{ The local schema screens of the AI chat (docs/esquemas-locales-pantalla-
  plan.md 5.5.1), on the schema file of a direct connection (rplocalschemas,
  dbxschemas/<ALIAS>.json):

  - Left: "All the tables" (the dictionary: every table is described, none
    is chosen) and the subschemas, with Add, Duplicate, Rename, Delete,
    Export and Import (the file of the Reportman AI web, 5.6: what travels
    of the subschema goes out, a new subschema comes in) and the
    description of the subschema.
  - Tabs: Connection (read only, "Refresh from the database" reads the
    catalog again and keeps what people wrote), Tables (a table enters with
    its primary key), Columns (the columns that travel, their description
    and allowed values in the dictionary, "Also in", a preview of 5 rows),
    Relations (the ones that travel, the suggested ones and the ones the
    database does not declare) and Validation ("Analyze with AI").
  - The counters of the plan warn, never block. Nothing is saved until Save;
    closing with changes asks.

  Built in code, no form file; rpfrmlocalschemasvcl is the VCL twin.
  Where the plan says nothing: Save and Close are at the bottom of every
  tab; Save keeps the screen open; the link mark of a column whose relation
  does not travel says "(does not travel)" instead of being dimmed; a
  relation by hand goes from a table of the subschema to any table and is
  completed as a suggested one; Export and Import say what they did in the
  line at the bottom, and what was not imported in a message too. }

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, CheckLst,
  ComCtrls, Grids, Dialogs, Contnrs, DB, rpjsonfpc,
  rpreport, rpdatainfo, rplocalschemas, rpdatahttp, rpfrmchatlcl;

// The local schema of the connection AAlias of the report. ASchemaName is
// the subschema to show and, when something was saved, the one selected
// at the end ('' = all the tables). With AAddNew it starts adding a
// subschema (its name first; cancelling it shows nothing). AChat gives the
// AI of "Analyze with AI" (its provider and mode; Standard without one).
// True when the file was saved
function RpShowLocalSchemasDialog(AReport: TRpReport; const AAlias: string;
  var ASchemaName: string; AAddNew: Boolean = False;
  AChat: TFRpChatFrame = nil): Boolean;

implementation

uses
  rpmdconsts, rpauthmanager, rpreportdesignercontracts, rpwebmarkdownlcl, rpgraphutilslcl;

const
  CKey = ' '#$F0#$9F#$94#$91;
  CLink = ' '#$F0#$9F#$94#$97' ';
  CArrow = ' '#$E2#$86#$92' ';
  CLeftArrow = #$E2#$86#$90' ';
  CPreviewRows = 5;

type
  TFRpLocalSchemasLCL = class(TForm)
  private
    FAnalysis: IRpSchemaAnalysis;
    FAnalysisTimer: TTimer;
    FChat: TFRpChatFrame;
    FDatabase: TRpDatabaseInfoItem;
    FDatabases: TRpDatabaseInfoList;
    FFile: TRpLocalSchemaFile;
    FFileName: string;
    FReport: TRpReport;
    FUpdating: Boolean;
    FModified: Boolean;
    FSaved: Boolean;
    FStackTop: Integer;
    // The table of the Tables tab whose description is shown, the table and
    // the column of the Columns tab
    FTablesTable: string;
    FColumnsTable: string;
    FColumn: string;
    // The column names of CheckColumns (its texts carry the marks)
    FShownColumns: TStringList;
    FRelations: TObjectList;
    FSuggestions: TObjectList;
    FPairSource: TStringList;
    FPairTarget: TStringList;
    // Left
    ListSchemas: TListBox;
    BAdd: TButton;
    BDuplicate: TButton;
    BRename: TButton;
    BDelete: TButton;
    BExport: TButton;
    BImport: TButton;
    MemoDescription: TMemo;
    // Bottom
    StatusInfo: TStatusBar;
    LTablesCounter: TLabel;
    LColumnsCounter: TLabel;
    LPlanWarning: TLabel;
    BSave: TButton;
    BClose: TButton;
    Pages: TPageControl;
    LAllInfo: TLabel;
    // Connection
    LConnection: TLabel;
    BRefresh: TButton;
    // Tables
    EFilterAvailable: TEdit;
    ListAvailable: TListBox;
    EFilterChosen: TEdit;
    ListChosen: TListBox;
    BAddTable: TButton;
    BRemoveTable: TButton;
    LTableContext: TLabel;
    MemoTableContext: TMemo;
    // Columns
    ListColumnTables: TListBox;
    EFilterColumns: TEdit;
    CheckColumns: TCheckListBox;
    BAddAll: TButton;
    BClearColumns: TButton;
    EColumnName: TEdit;
    EColumnType: TEdit;
    MemoColumnContext: TMemo;
    LAlsoIn: TLabel;
    GridValues: TStringGrid;
    BAddValue: TButton;
    BDeleteValue: TButton;
    BPreview: TButton;
    GridPreview: TStringGrid;
    // Relations
    LabelRelations: TLabel;
    ListRelations: TListBox;
    MemoRelationContext: TMemo;
    BDeleteRelation: TButton;
    ListSuggestions: TListBox;
    BComplete: TButton;
    ComboSource: TComboBox;
    ComboTarget: TComboBox;
    ComboSourceColumn: TComboBox;
    ComboTargetColumn: TComboBox;
    BAddPair: TButton;
    ListPairs: TListBox;
    BRemovePair: TButton;
    ENewContext: TEdit;
    BAddRelation: TButton;
    // Validation
    BAnalyze: TButton;
    BStop: TButton;
    LStatus: TLabel;
    FWebResult: TRpWebMarkdownView;
    function S(AValue: Integer): Integer;
    function NewPanel(AParent: TWinControl; AAlign: TAlign;
      ASize: Integer): TPanel;
    function NewLabel(AParent: TWinControl; const ACaption: string): TLabel;
    function NewButton(AParent: TWinControl; const ACaption: string;
      AOnClick: TNotifyEvent; AWidth: Integer): TButton;
    function NewEdit(AParent: TWinControl; AOnChange: TNotifyEvent): TEdit;
    function NewMemo(AParent: TWinControl; AHeight: Integer;
      AOnChange: TNotifyEvent): TMemo;
    procedure StackTop(AControl: TControl);
    procedure BuildControls;
    procedure BuildConnectionTab(ATab: TTabSheet);
    procedure BuildTablesTab(ATab: TTabSheet);
    procedure BuildColumnsTab(ATab: TTabSheet);
    procedure BuildRelationsTab(ATab: TTabSheet);
    procedure BuildValidationTab(ATab: TTabSheet);
    procedure LoadFile(ARefresh: Boolean);
    function SelectedSchema: TRpLocalSubSchema;
    function SchemaTables: TStringList;
    function PlanApplies: Boolean;
    procedure Changed;
    procedure FillSchemas(const ASelected: string);
    procedure FillAll;
    procedure FillConnection;
    procedure FillTables;
    procedure FillTableContext;
    procedure FillColumnTables;
    function ColumnCaption(const AColumn: string): string;
    procedure FillColumns;
    procedure RefreshColumnChecks;
    procedure FillColumnDetails;
    procedure FillRelations;
    procedure FillRelationTables;
    procedure UpdateCounters;
    procedure SaveAllowedValues;
    procedure ClearPreview;
    // Asks the name of a new subschema and selects it; False when cancelled
    function AddNewSchema: Boolean;
    procedure SaveFile;
    procedure StopAnalysis;
    // The line at the bottom (what Export and Import did)
    procedure ShowInfo(const AText: string);
    procedure ListSchemasClick(Sender: TObject);
    procedure BAddClick(Sender: TObject);
    procedure BDuplicateClick(Sender: TObject);
    procedure BRenameClick(Sender: TObject);
    procedure BDeleteClick(Sender: TObject);
    procedure BExportClick(Sender: TObject);
    procedure BImportClick(Sender: TObject);
    procedure MemoDescriptionChange(Sender: TObject);
    procedure BRefreshClick(Sender: TObject);
    procedure FilterTablesChange(Sender: TObject);
    procedure BAddTableClick(Sender: TObject);
    procedure BRemoveTableClick(Sender: TObject);
    procedure ListTablesClick(Sender: TObject);
    procedure MemoTableContextChange(Sender: TObject);
    procedure ListColumnTablesClick(Sender: TObject);
    procedure FilterColumnsChange(Sender: TObject);
    procedure CheckColumnsClickCheck(Sender: TObject);
    procedure CheckColumnsClick(Sender: TObject);
    procedure BAddAllClick(Sender: TObject);
    procedure BClearColumnsClick(Sender: TObject);
    procedure MemoColumnContextChange(Sender: TObject);
    procedure GridValuesSetEditText(Sender: TObject; ACol, ARow: Integer;
      const Value: string);
    procedure BAddValueClick(Sender: TObject);
    procedure BDeleteValueClick(Sender: TObject);
    procedure BPreviewClick(Sender: TObject);
    procedure ListRelationsClick(Sender: TObject);
    procedure MemoRelationContextChange(Sender: TObject);
    procedure BDeleteRelationClick(Sender: TObject);
    procedure BCompleteClick(Sender: TObject);
    procedure ComboSourceChange(Sender: TObject);
    procedure ComboTargetChange(Sender: TObject);
    procedure BAddPairClick(Sender: TObject);
    procedure BRemovePairClick(Sender: TObject);
    procedure BAddRelationClick(Sender: TObject);
    procedure BAnalyzeClick(Sender: TObject);
    procedure BStopClick(Sender: TObject);
    procedure AnalysisTimerTick(Sender: TObject);
    procedure BSaveClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  public
    constructor CreateFor(AOwner: TComponent; AReport: TRpReport;
      const AAlias: string; AChat: TFRpChatFrame);
    destructor Destroy; override;
  end;

// 'n / max' ('n' without a limit)
function CounterText(AValue, AMax: Integer): string;
begin
  Result := IntToStr(AValue);
  if AMax > 0 then
    Result := Result + ' / ' + IntToStr(AMax);
end;

function MatchesFilter(const AText, AFilter: string): Boolean;
begin
  Result := (Trim(AFilter) = '') or
    (Pos(LowerCase(Trim(AFilter)), LowerCase(AText)) > 0);
end;

function JsonText(AObject: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if AObject = nil then
    Exit;
  LValue := AObject.Values[AName];
  if (LValue <> nil) and not (LValue is TJSONNull) then
    Result := LValue.Value;
end;

function RelationCaption(ARelation: TRpLocalRelation): string;
begin
  Result := ARelation.SourceTable + ' (' + ARelation.SourceColumnsText + ')' +
    CArrow + ARelation.TargetTable + ' (' + ARelation.TargetColumnsText + ')';
  if ARelation.IsManual then
    Result := Result + ' - ' + string(TranslateStr(1875, 'by hand'));
end;

{ TFRpLocalSchemasLCL }

function TFRpLocalSchemasLCL.S(AValue: Integer): Integer;
begin
  Result := (AValue * Screen.PixelsPerInch) div 96;
end;

constructor TFRpLocalSchemasLCL.CreateFor(AOwner: TComponent;
  AReport: TRpReport; const AAlias: string; AChat: TFRpChatFrame);
var
  LIndex: Integer;
begin
  inherited CreateNew(AOwner);
  FReport := AReport;
  FChat := AChat;
  FFile := TRpLocalSchemaFile.Create;
  FShownColumns := TStringList.Create;
  FRelations := TObjectList.Create(True);
  FSuggestions := TObjectList.Create(True);
  FPairSource := TStringList.Create;
  FPairTarget := TStringList.Create;
  LIndex := AReport.DatabaseInfo.IndexOf(AAlias);
  if LIndex < 0 then
    raise Exception.Create('The report has no connection ' + AAlias);
  // A copy: the designer may be opening the datasets of the report
  FDatabases := RpCopyDatabaseInfo(AReport.DatabaseInfo.Items[LIndex]);
  FDatabase := FDatabases.Items[0];
  FFileName := RpLocalSchemaFileName(FDatabase);
  Caption := Format(TranslateStr(1845, 'Local schema of %s'), [FDatabase.Alias]);
  Position := poScreenCenter;
  BorderIcons := [biSystemMenu, biMaximize];
  Width := S(1000);
  Height := S(660);
  Constraints.MinWidth := S(820);
  Constraints.MinHeight := S(540);
  OnCloseQuery := FormCloseQuery;
  FAnalysisTimer := TTimer.Create(Self);
  FAnalysisTimer.Enabled := False;
  FAnalysisTimer.Interval := 200;
  FAnalysisTimer.OnTimer := AnalysisTimerTick;
  BuildControls;
end;

destructor TFRpLocalSchemasLCL.Destroy;
begin
  // No event of a control being destroyed touches the file
  FUpdating := True;
  StopAnalysis;
  FRelations.Free;
  FSuggestions.Free;
  FPairSource.Free;
  FPairTarget.Free;
  FShownColumns.Free;
  FFile.Free;
  FDatabases.Free;
  inherited Destroy;
end;

{ Building }

function TFRpLocalSchemasLCL.NewPanel(AParent: TWinControl; AAlign: TAlign;
  ASize: Integer): TPanel;
begin
  Result := TPanel.Create(Self);
  Result.BevelOuter := bvNone;
  Result.Caption := '';
  // In the order they are made: each one below (alTop) or to the right
  // (alLeft) of the previous one, in the VCL and in the LCL
  if AAlign = alTop then
    Result.Top := FStackTop
  else if AAlign = alLeft then
    Result.Left := FStackTop;
  Inc(FStackTop, S(1000));
  Result.Parent := AParent;
  Result.Align := AAlign;
  if AAlign in [alTop, alBottom] then
    Result.Height := S(ASize)
  else if AAlign in [alLeft, alRight] then
    Result.Width := S(ASize);
end;

procedure TFRpLocalSchemasLCL.StackTop(AControl: TControl);
begin
  // alTop in the order they are made: each one below the previous one
  AControl.Top := FStackTop;
  Inc(FStackTop, S(1000));
  AControl.Align := alTop;
end;

function TFRpLocalSchemasLCL.NewLabel(AParent: TWinControl;
  const ACaption: string): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.WordWrap := True;
  StackTop(Result);
end;

function TFRpLocalSchemasLCL.NewButton(AParent: TWinControl;
  const ACaption: string; AOnClick: TNotifyEvent; AWidth: Integer): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.OnClick := AOnClick;
  Result.Width := S(AWidth);
  Result.Height := S(26);
end;

function TFRpLocalSchemasLCL.NewEdit(AParent: TWinControl;
  AOnChange: TNotifyEvent): TEdit;
begin
  Result := TEdit.Create(Self);
  Result.Parent := AParent;
  Result.OnChange := AOnChange;
  StackTop(Result);
end;

function TFRpLocalSchemasLCL.NewMemo(AParent: TWinControl; AHeight: Integer;
  AOnChange: TNotifyEvent): TMemo;
begin
  Result := TMemo.Create(Self);
  Result.Parent := AParent;
  Result.Height := S(AHeight);
  Result.ScrollBars := ssVertical;
  Result.WantReturns := True;
  Result.OnChange := AOnChange;
  StackTop(Result);
end;

procedure TFRpLocalSchemasLCL.BuildControls;
var
  LBottom, LButtons, LCounters, LLeft, LLeftBottom: TPanel;
  LTab: TTabSheet;
begin
  FStackTop := 0;
  // The line at the very bottom, below the counters
  StatusInfo := TStatusBar.Create(Self);
  StatusInfo.Parent := Self;
  StatusInfo.SimplePanel := True;
  StatusInfo.ShowHint := True;
  StatusInfo.Top := S(9000);
  StatusInfo.Align := alBottom;
  // Bottom: the counters of the plan, Save and Close
  LBottom := NewPanel(Self, alBottom, 52);
  LButtons := NewPanel(LBottom, alRight, 230);
  BSave := NewButton(LButtons, TranslateStr(46, 'Save'), BSaveClick, 100);
  BSave.SetBounds(S(10), S(13), S(100), S(26));
  BClose := NewButton(LButtons, TranslateStr(1891, 'Close'), nil, 100);
  BClose.SetBounds(S(120), S(13), S(100), S(26));
  BClose.ModalResult := mrCancel;
  BClose.Cancel := True;
  LCounters := NewPanel(LBottom, alClient, 0);
  LCounters.BorderWidth := S(6);
  LTablesCounter := TLabel.Create(Self);
  LTablesCounter.Parent := LCounters;
  LTablesCounter.Left := S(6);
  LTablesCounter.Top := S(4);
  LColumnsCounter := TLabel.Create(Self);
  LColumnsCounter.Parent := LCounters;
  LColumnsCounter.Left := S(220);
  LColumnsCounter.Top := S(4);
  LPlanWarning := TLabel.Create(Self);
  LPlanWarning.Parent := LCounters;
  LPlanWarning.Left := S(6);
  LPlanWarning.Top := S(24);
  LPlanWarning.Font.Color := clRed;
  LPlanWarning.Caption := TranslateStr(1885, 'This schema can only run with ' +
    'a higher plan or with the AI on your Agent.');
  LPlanWarning.Visible := False;

  // Left: all the tables and the subschemas; below, the description of the
  // subschema and its buttons
  LLeft := NewPanel(Self, alLeft, 230);
  LLeft.BorderWidth := S(6);
  NewLabel(LLeft, TranslateStr(1846, 'Subschemas'));
  LLeftBottom := NewPanel(LLeft, alBottom, 190);
  NewLabel(LLeftBottom, TranslateStr(197, 'Description'));
  MemoDescription := NewMemo(LLeftBottom, 70, MemoDescriptionChange);
  LButtons := NewPanel(LLeftBottom, alClient, 0);
  BAdd := NewButton(LButtons, TranslateStr(149, 'Add') + '...', BAddClick, 104);
  BAdd.SetBounds(0, S(4), S(104), S(26));
  BDuplicate := NewButton(LButtons, TranslateStr(1847, 'Duplicate...'),
    BDuplicateClick, 104);
  BDuplicate.SetBounds(S(110), S(4), S(104), S(26));
  BRename := NewButton(LButtons, TranslateStr(151, 'Rename') + '...',
    BRenameClick, 104);
  BRename.SetBounds(0, S(34), S(104), S(26));
  BDelete := NewButton(LButtons, TranslateStr(150, 'Delete'), BDeleteClick, 104);
  BDelete.SetBounds(S(110), S(34), S(104), S(26));
  // With the Reportman AI web (Export works with all the tables too)
  BExport := NewButton(LButtons, string(TranslateStr(1931, 'Export...')),
    BExportClick, 104);
  BExport.SetBounds(0, S(64), S(104), S(26));
  BExport.Hint := string(TranslateStr(1933, 'Saves what travels of the ' +
    'subschema in the format the Reportman AI web imports'));
  BExport.ShowHint := True;
  BImport := NewButton(LButtons, string(TranslateStr(1932, 'Import...')),
    BImportClick, 104);
  BImport.SetBounds(S(110), S(64), S(104), S(26));
  BImport.Hint := string(TranslateStr(1934, 'Creates a subschema from a ' +
    'schema exported by the Reportman AI web or by another local schema'));
  BImport.ShowHint := True;
  ListSchemas := TListBox.Create(Self);
  ListSchemas.Parent := LLeft;
  ListSchemas.Align := alClient;
  ListSchemas.OnClick := ListSchemasClick;

  // Right: the tabs
  Pages := TPageControl.Create(Self);
  Pages.Parent := Self;
  Pages.Align := alClient;
  LTab := TTabSheet.Create(Self);
  LTab.PageControl := Pages;
  LTab.Caption := TranslateStr(154, 'Connection');
  BuildConnectionTab(LTab);
  LTab := TTabSheet.Create(Self);
  LTab.PageControl := Pages;
  LTab.Caption := TranslateStr(1848, 'Tables');
  BuildTablesTab(LTab);
  LTab := TTabSheet.Create(Self);
  LTab.PageControl := Pages;
  LTab.Caption := TranslateStr(1849, 'Columns');
  BuildColumnsTab(LTab);
  LTab := TTabSheet.Create(Self);
  LTab.PageControl := Pages;
  LTab.Caption := TranslateStr(1850, 'Relations');
  BuildRelationsTab(LTab);
  LTab := TTabSheet.Create(Self);
  LTab.PageControl := Pages;
  LTab.Caption := TranslateStr(1401, 'Validation');
  BuildValidationTab(LTab);
  Pages.ActivePageIndex := 0;
end;

procedure TFRpLocalSchemasLCL.BuildConnectionTab(ATab: TTabSheet);
var
  LPanel, LRow: TPanel;
begin
  LPanel := NewPanel(ATab, alClient, 0);
  LPanel.BorderWidth := S(8);
  LConnection := NewLabel(LPanel, '');
  LRow := NewPanel(LPanel, alTop, 44);
  BRefresh := NewButton(LRow, TranslateStr(1851, 'Refresh from the database'),
    BRefreshClick, 240);
  BRefresh.SetBounds(0, S(12), S(240), S(26));
end;

procedure TFRpLocalSchemasLCL.BuildTablesTab(ATab: TTabSheet);
var
  LPanel, LAvailable, LChosen, LArrows, LContext: TPanel;
begin
  LPanel := NewPanel(ATab, alClient, 0);
  LPanel.BorderWidth := S(6);
  LAllInfo := NewLabel(LPanel, TranslateStr(1890, 'All the tables: every ' +
    'table and column travels. Here they are described, not chosen.'));
  LAllInfo.Font.Style := [fsItalic];
  // The description of the table, below
  LContext := NewPanel(LPanel, alBottom, 100);
  LTableContext := NewLabel(LContext, TranslateStr(1860,
    'Description of the table (the same in every subschema)'));
  MemoTableContext := TMemo.Create(Self);
  MemoTableContext.Parent := LContext;
  MemoTableContext.ScrollBars := ssVertical;
  MemoTableContext.OnChange := MemoTableContextChange;
  MemoTableContext.Align := alClient;
  // Available | arrows | chosen
  LAvailable := NewPanel(LPanel, alLeft, 300);
  NewLabel(LAvailable, TranslateStr(1857, 'Available tables'));
  EFilterAvailable := NewEdit(LAvailable, FilterTablesChange);
  EFilterAvailable.TextHint := TranslateStr(1859, 'Filter');
  ListAvailable := TListBox.Create(Self);
  ListAvailable.Parent := LAvailable;
  ListAvailable.Align := alClient;
  ListAvailable.MultiSelect := True;
  ListAvailable.OnClick := ListTablesClick;
  ListAvailable.OnDblClick := BAddTableClick;
  LArrows := NewPanel(LPanel, alLeft, 110);
  BAddTable := NewButton(LArrows, string(TranslateStr(149, 'Add')) + CArrow, BAddTableClick, 98);
  BAddTable.SetBounds(S(6), S(60), S(98), S(26));
  BRemoveTable := NewButton(LArrows, CLeftArrow + string(TranslateStr(1892, 'Remove')),
    BRemoveTableClick, 98);
  BRemoveTable.SetBounds(S(6), S(94), S(98), S(26));
  LChosen := NewPanel(LPanel, alClient, 0);
  NewLabel(LChosen, TranslateStr(1858, 'Tables of the subschema'));
  EFilterChosen := NewEdit(LChosen, FilterTablesChange);
  EFilterChosen.TextHint := TranslateStr(1859, 'Filter');
  ListChosen := TListBox.Create(Self);
  ListChosen.Parent := LChosen;
  ListChosen.Align := alClient;
  ListChosen.MultiSelect := True;
  ListChosen.OnClick := ListTablesClick;
  ListChosen.OnDblClick := BRemoveTableClick;
end;

procedure TFRpLocalSchemasLCL.BuildColumnsTab(ATab: TTabSheet);
var
  LPanel, LTables, LColumns, LButtons, LDetails, LValues, LValueButtons,
    LPreview: TPanel;
begin
  LPanel := NewPanel(ATab, alClient, 0);
  LPanel.BorderWidth := S(6);
  // The tables
  LTables := NewPanel(LPanel, alLeft, 170);
  NewLabel(LTables, TranslateStr(1848, 'Tables'));
  ListColumnTables := TListBox.Create(Self);
  ListColumnTables.Parent := LTables;
  ListColumnTables.Align := alClient;
  ListColumnTables.OnClick := ListColumnTablesClick;
  // The columns of the table
  LColumns := NewPanel(LPanel, alLeft, 250);
  LColumns.BorderWidth := S(4);
  NewLabel(LColumns, TranslateStr(1849, 'Columns'));
  EFilterColumns := NewEdit(LColumns, FilterColumnsChange);
  EFilterColumns.TextHint := TranslateStr(1859, 'Filter');
  LButtons := NewPanel(LColumns, alBottom, 34);
  BAddAll := NewButton(LButtons, TranslateStr(1861, 'Add all'), BAddAllClick, 110);
  BAddAll.SetBounds(0, S(6), S(110), S(26));
  BClearColumns := NewButton(LButtons, TranslateStr(1532, 'Clear'),
    BClearColumnsClick, 110);
  BClearColumns.SetBounds(S(116), S(6), S(110), S(26));
  CheckColumns := TCheckListBox.Create(Self);
  CheckColumns.Parent := LColumns;
  CheckColumns.Align := alClient;
  CheckColumns.OnClickCheck := CheckColumnsClickCheck;
  CheckColumns.OnClick := CheckColumnsClick;
  // The column: name, type, description, allowed values; the preview below
  LDetails := NewPanel(LPanel, alClient, 0);
  LDetails.BorderWidth := S(4);
  NewLabel(LDetails, TranslateStr(544, 'Name'));
  EColumnName := NewEdit(LDetails, nil);
  EColumnName.ReadOnly := True;
  EColumnName.Color := clBtnFace;
  NewLabel(LDetails, TranslateStr(193, 'Data type'));
  EColumnType := NewEdit(LDetails, nil);
  EColumnType.ReadOnly := True;
  EColumnType.Color := clBtnFace;
  NewLabel(LDetails, TranslateStr(1862, 'Description (the same in every subschema)'));
  MemoColumnContext := NewMemo(LDetails, 56, MemoColumnContextChange);
  LAlsoIn := NewLabel(LDetails, '');
  LAlsoIn.Font.Style := [fsItalic];
  NewLabel(LDetails, TranslateStr(1864, 'Allowed values'));
  LValues := NewPanel(LDetails, alTop, 104);
  LValueButtons := NewPanel(LValues, alRight, 40);
  BAddValue := NewButton(LValueButtons, '+', BAddValueClick, 32);
  BAddValue.SetBounds(S(6), 0, S(32), S(26));
  BDeleteValue := NewButton(LValueButtons, '-', BDeleteValueClick, 32);
  BDeleteValue.SetBounds(S(6), S(30), S(32), S(26));
  GridValues := TStringGrid.Create(Self);
  GridValues.Parent := LValues;
  GridValues.Align := alClient;
  GridValues.ColCount := 2;
  GridValues.FixedCols := 0;
  GridValues.RowCount := 2;
  GridValues.FixedRows := 1;
  GridValues.DefaultRowHeight := S(20);
  GridValues.Options := [goFixedVertLine, goFixedHorzLine, goVertLine,
    goHorzLine, goEditing, goTabs];
  GridValues.ColWidths[0] := S(90);
  GridValues.ColWidths[1] := S(220);
  GridValues.Cells[0, 0] := TranslateStr(1896, 'Value');
  GridValues.Cells[1, 0] := TranslateStr(1897, 'Label');
  GridValues.OnSetEditText := GridValuesSetEditText;
  LPreview := NewPanel(LDetails, alTop, 34);
  BPreview := NewButton(LPreview, TranslateStr(1865, 'Show 5 rows'),
    BPreviewClick, 150);
  BPreview.SetBounds(0, S(6), S(150), S(26));
  GridPreview := TStringGrid.Create(Self);
  GridPreview.Parent := LDetails;
  GridPreview.Align := alClient;
  GridPreview.FixedCols := 0;
  GridPreview.ColCount := 1;
  GridPreview.RowCount := 1;
  GridPreview.DefaultRowHeight := S(20);
  GridPreview.Options := [goFixedVertLine, goFixedHorzLine, goVertLine,
    goHorzLine, goColSizing];
end;

procedure TFRpLocalSchemasLCL.BuildRelationsTab(ATab: TTabSheet);
var
  LPanel, LTop, LList, LContext, LSuggested, LNew, LRow, LPairs: TPanel;
begin
  LPanel := NewPanel(ATab, alClient, 0);
  LPanel.BorderWidth := S(6);
  // The relations that travel and their description
  LTop := NewPanel(LPanel, alTop, 200);
  LList := NewPanel(LTop, alClient, 0);
  LabelRelations := NewLabel(LList, TranslateStr(1893, 'Relations of the subschema'));
  ListRelations := TListBox.Create(Self);
  ListRelations.Parent := LList;
  ListRelations.Align := alClient;
  ListRelations.OnClick := ListRelationsClick;
  LContext := NewPanel(LTop, alRight, 300);
  LContext.BorderWidth := S(4);
  NewLabel(LContext, TranslateStr(1894,
    'Description of the relation (the same in every subschema)'));
  BDeleteRelation := NewButton(LContext, TranslateStr(150, 'Delete'),
    BDeleteRelationClick, 100);
  BDeleteRelation.Top := S(9000);
  BDeleteRelation.Align := alBottom;
  MemoRelationContext := TMemo.Create(Self);
  MemoRelationContext.Parent := LContext;
  MemoRelationContext.Align := alClient;
  MemoRelationContext.ScrollBars := ssVertical;
  MemoRelationContext.OnChange := MemoRelationContextChange;
  // The suggested ones
  LSuggested := NewPanel(LPanel, alTop, 120);
  NewLabel(LSuggested, TranslateStr(1866, 'Suggested relations: they do ' +
    'not travel yet (a table or a column of one end is not chosen). Complete ' +
    'adds what they need.'));
  LRow := NewPanel(LSuggested, alRight, 110);
  BComplete := NewButton(LRow, TranslateStr(1867, 'Complete'), BCompleteClick, 100);
  BComplete.SetBounds(S(6), S(4), S(100), S(26));
  ListSuggestions := TListBox.Create(Self);
  ListSuggestions.Parent := LSuggested;
  ListSuggestions.Align := alClient;
  ListSuggestions.OnDblClick := BCompleteClick;
  // A relation the database does not declare
  LNew := NewPanel(LPanel, alClient, 0);
  NewLabel(LNew, TranslateStr(1868, 'New relation (one the database does not declare)'));
  LRow := NewPanel(LNew, alTop, 50);
  with TLabel.Create(Self) do
  begin
    Parent := LRow;
    Caption := TranslateStr(1869, 'Source table');
    SetBounds(0, S(4), S(200), S(16));
  end;
  ComboSource := TComboBox.Create(Self);
  ComboSource.Parent := LRow;
  ComboSource.Style := csDropDownList;
  ComboSource.SetBounds(0, S(22), S(200), S(24));
  ComboSource.OnChange := ComboSourceChange;
  with TLabel.Create(Self) do
  begin
    Parent := LRow;
    Caption := TranslateStr(1870, 'Target table');
    SetBounds(S(210), S(4), S(200), S(16));
  end;
  ComboTarget := TComboBox.Create(Self);
  ComboTarget.Parent := LRow;
  ComboTarget.Style := csDropDownList;
  ComboTarget.SetBounds(S(210), S(22), S(200), S(24));
  ComboTarget.OnChange := ComboTargetChange;
  LRow := NewPanel(LNew, alTop, 50);
  with TLabel.Create(Self) do
  begin
    Parent := LRow;
    Caption := TranslateStr(1871, 'Source column');
    SetBounds(0, S(4), S(200), S(16));
  end;
  ComboSourceColumn := TComboBox.Create(Self);
  ComboSourceColumn.Parent := LRow;
  ComboSourceColumn.Style := csDropDownList;
  ComboSourceColumn.SetBounds(0, S(22), S(200), S(24));
  with TLabel.Create(Self) do
  begin
    Parent := LRow;
    Caption := TranslateStr(1872, 'Target column');
    SetBounds(S(210), S(4), S(200), S(16));
  end;
  ComboTargetColumn := TComboBox.Create(Self);
  ComboTargetColumn.Parent := LRow;
  ComboTargetColumn.Style := csDropDownList;
  ComboTargetColumn.SetBounds(S(210), S(22), S(200), S(24));
  BAddPair := NewButton(LRow, TranslateStr(1873, 'Add pair'), BAddPairClick, 120);
  BAddPair.SetBounds(S(420), S(21), S(120), S(26));
  LPairs := NewPanel(LNew, alClient, 0);
  LRow := NewPanel(LPairs, alBottom, 34);
  with TLabel.Create(Self) do
  begin
    Parent := LRow;
    Caption := TranslateStr(197, 'Description');
    SetBounds(0, S(10), S(90), S(16));
  end;
  ENewContext := TEdit.Create(Self);
  ENewContext.Parent := LRow;
  ENewContext.SetBounds(S(94), S(6), S(316), S(24));
  BAddRelation := NewButton(LRow, TranslateStr(1874, 'Add relation'),
    BAddRelationClick, 120);
  BAddRelation.SetBounds(S(420), S(5), S(120), S(26));
  LRow := NewPanel(LPairs, alRight, 130);
  BRemovePair := NewButton(LRow, TranslateStr(1892, 'Remove'), BRemovePairClick, 120);
  BRemovePair.SetBounds(S(6), S(4), S(120), S(26));
  ListPairs := TListBox.Create(Self);
  ListPairs.Parent := LPairs;
  ListPairs.Align := alClient;
end;

procedure TFRpLocalSchemasLCL.BuildValidationTab(ATab: TTabSheet);
var
  LPanel, LButtons: TPanel;
begin
  LPanel := NewPanel(ATab, alClient, 0);
  LPanel.BorderWidth := S(6);
  NewLabel(LPanel, TranslateStr(1877, 'The AI reads the schema as the copilot ' +
    'sends it and says what it does not understand: describe the tables and ' +
    'columns it marks.'));
  LButtons := NewPanel(LPanel, alTop, 38);
  BAnalyze := NewButton(LButtons, TranslateStr(1876, 'Analyze with AI'),
    BAnalyzeClick, 170);
  BAnalyze.SetBounds(0, S(6), S(170), S(26));
  BStop := NewButton(LButtons, TranslateStr(1522, 'Stop'), BStopClick, 100);
  BStop.SetBounds(S(176), S(6), S(100), S(26));
  BStop.Enabled := False;
  LStatus := TLabel.Create(Self);
  LStatus.Parent := LButtons;
  LStatus.SetBounds(S(290), S(11), S(400), S(16));
  FWebResult := TRpWebMarkdownView.Create(Self);
  FWebResult.Parent := LPanel;
  FWebResult.Align := alClient;
end;

{ The file }

procedure TFRpLocalSchemasLCL.LoadFile(ARefresh: Boolean);
var
  LCursor: TCursor;
  LDialect: string;
  LLoaded: TRpLocalSchemaFile;
  LTables: TJSONArray;
begin
  LCursor := Screen.Cursor;
  Screen.Cursor := crHourGlass;
  try
    try
      if ARefresh then
      begin
        // In memory, with what is being edited: Save writes it
        LTables := RpReadLocalSchemaCatalog(FDatabase, FReport.Params, LDialect);
        // The relations point to the tables read before
        FRelations.Clear;
        FSuggestions.Clear;
        FFile.SetCatalog(LTables, LDialect);
        if FFile.Alias = '' then
          FFile.Alias := UpperCase(FDatabase.Alias);
      end
      else
      begin
        // Generated (and saved) the first time
        LLoaded := RpLoadLocalSchema(FDatabase, FReport.Params, True, False);
        FFile.Free;
        FFile := LLoaded;
      end;
    finally
      FDatabase.DisConnect;
    end;
  finally
    Screen.Cursor := LCursor;
  end;
end;

procedure TFRpLocalSchemasLCL.SaveFile;
begin
  if FFile.Alias = '' then
    FFile.Alias := UpperCase(FDatabase.Alias);
  FFile.SaveToFile(FFileName);
  FModified := False;
  FSaved := True;
end;

procedure TFRpLocalSchemasLCL.ShowInfo(const AText: string);
begin
  StatusInfo.SimpleText := AText;
  StatusInfo.Hint := AText;
end;

procedure TFRpLocalSchemasLCL.Changed;
begin
  FModified := True;
  UpdateCounters;
end;

function TFRpLocalSchemasLCL.SelectedSchema: TRpLocalSubSchema;
begin
  Result := nil;
  if (ListSchemas.ItemIndex > 0) and (ListSchemas.ItemIndex <= FFile.SchemaCount) then
    Result := FFile.Schemas[ListSchemas.ItemIndex - 1];
end;

// The tables of the subschema (all of them without one); the caller frees it
function TFRpLocalSchemasLCL.SchemaTables: TStringList;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  if SelectedSchema <> nil then
    Result.Assign(SelectedSchema.Tables)
  else
    FFile.GetTableNames(Result);
end;

// The plan of the account, not with the AI of an Agent
function TFRpLocalSchemasLCL.PlanApplies: Boolean;
begin
  Result := (FChat = nil) or not SameText(FChat.GetAITier, 'LocalAgent');
end;

{ Filling }

procedure TFRpLocalSchemasLCL.FillSchemas(const ASelected: string);
var
  I: Integer;
begin
  FUpdating := True;
  try
    ListSchemas.Items.BeginUpdate;
    try
      ListSchemas.Items.Clear;
      ListSchemas.Items.Add(TranslateStr(1843, 'All the tables'));
      for I := 0 to FFile.SchemaCount - 1 do
        ListSchemas.Items.Add(FFile.Schemas[I].Name);
    finally
      ListSchemas.Items.EndUpdate;
    end;
    ListSchemas.ItemIndex := FFile.IndexOfSchema(ASelected) + 1;
  finally
    FUpdating := False;
  end;
  FillAll;
end;

procedure TFRpLocalSchemasLCL.FillAll;
var
  LSchema: TRpLocalSubSchema;
begin
  LSchema := SelectedSchema;
  FUpdating := True;
  try
    BDuplicate.Enabled := LSchema <> nil;
    BRename.Enabled := LSchema <> nil;
    BDelete.Enabled := LSchema <> nil;
    MemoDescription.Enabled := LSchema <> nil;
    if LSchema <> nil then
      MemoDescription.Text := LSchema.Description
    else
      MemoDescription.Text := '';
    LAllInfo.Visible := LSchema = nil;
    BAddTable.Enabled := LSchema <> nil;
    BRemoveTable.Enabled := LSchema <> nil;
    BAddAll.Enabled := LSchema <> nil;
    BClearColumns.Enabled := LSchema <> nil;
    if LSchema <> nil then
      LabelRelations.Caption := TranslateStr(1893, 'Relations of the subschema')
    else
      LabelRelations.Caption := TranslateStr(1850, 'Relations');
  finally
    FUpdating := False;
  end;
  FillConnection;
  FillTables;
  FillColumnTables;
  FillRelations;
  FillRelationTables;
  UpdateCounters;
end;

procedure TFRpLocalSchemasLCL.FillConnection;
begin
  LConnection.Caption :=
    TranslateStr(1852, 'Alias') + ': ' + FDatabase.Alias + sLineBreak +
    TranslateStr(1853, 'Dialect') + ': ' + FFile.CloudDialect + sLineBreak +
    TranslateStr(1854, 'Read from the database') + ': ' + FFile.GeneratedUtc + sLineBreak +
    TranslateStr(1855, 'Tables in the catalog') + ': ' + IntToStr(FFile.TableCount) + sLineBreak +
    TranslateStr(1856, 'Schema file') + ': ' + FFileName;
end;

procedure TFRpLocalSchemasLCL.FillTables;
var
  I: Integer;
  LNames, LChosen: TStringList;
begin
  LNames := TStringList.Create;
  LChosen := SchemaTables;
  FUpdating := True;
  try
    FFile.GetTableNames(LNames);
    ListAvailable.Items.BeginUpdate;
    try
      ListAvailable.Items.Clear;
      if SelectedSchema <> nil then
        for I := 0 to LNames.Count - 1 do
          if (LChosen.IndexOf(LNames[I]) < 0) and
            MatchesFilter(LNames[I], EFilterAvailable.Text) then
            ListAvailable.Items.Add(LNames[I]);
    finally
      ListAvailable.Items.EndUpdate;
    end;
    ListChosen.Items.BeginUpdate;
    try
      ListChosen.Items.Clear;
      for I := 0 to LChosen.Count - 1 do
        if MatchesFilter(LChosen[I], EFilterChosen.Text) then
          ListChosen.Items.Add(LChosen[I]);
    finally
      ListChosen.Items.EndUpdate;
    end;
  finally
    FUpdating := False;
    LChosen.Free;
    LNames.Free;
  end;
  FillTableContext;
end;

procedure TFRpLocalSchemasLCL.FillTableContext;
var
  LTable: TJSONObject;
begin
  LTable := FFile.FindTable(FTablesTable);
  FUpdating := True;
  try
    MemoTableContext.Enabled := LTable <> nil;
    MemoTableContext.Text := JsonText(LTable, 'context');
    if LTable <> nil then
      LTableContext.Caption := TranslateStr(1860,
        'Description of the table (the same in every subschema)') + ': ' +
        JsonText(LTable, 'name')
    else
      LTableContext.Caption := TranslateStr(1860,
        'Description of the table (the same in every subschema)');
  finally
    FUpdating := False;
  end;
end;

procedure TFRpLocalSchemasLCL.FillColumnTables;
var
  LTables: TStringList;
begin
  LTables := SchemaTables;
  FUpdating := True;
  try
    ListColumnTables.Items.Assign(LTables);
    if LTables.IndexOf(FColumnsTable) < 0 then
    begin
      if LTables.Count > 0 then
        FColumnsTable := LTables[0]
      else
        FColumnsTable := '';
      FColumn := '';
      ClearPreview;
    end;
    ListColumnTables.ItemIndex := LTables.IndexOf(FColumnsTable);
  finally
    FUpdating := False;
    LTables.Free;
  end;
  FillColumns;
end;

// The text of a column of the Columns tab: the key mark and, for each
// relation it is a source of, the link mark, its target and whether it does
// not travel (the dimmed mark of the plan)
function TFRpLocalSchemasLCL.ColumnCaption(const AColumn: string): string;
var
  J, K: Integer;
  LForeignKey: TJSONObject;
  LForeignKeys, LSources: TJSONArray;
begin
  Result := AColumn;
  if SameText(JsonText(FFile.FindColumn(FColumnsTable, AColumn), 'isPrimaryKey'), 'true') then
    Result := Result + CKey;
  LForeignKeys := nil;
  if FFile.FindTable(FColumnsTable) <> nil then
    LForeignKeys := FFile.FindTable(FColumnsTable).Values['foreignKeys'] as TJSONArray;
  if LForeignKeys = nil then
    Exit;
  for J := 0 to LForeignKeys.Count - 1 do
    if LForeignKeys.Items[J] is TJSONObject then
    begin
      LForeignKey := TJSONObject(LForeignKeys.Items[J]);
      LSources := LForeignKey.Values['sourceColumns'] as TJSONArray;
      if LSources = nil then
        Continue;
      for K := 0 to LSources.Count - 1 do
        if SameText(LSources.Items[K].Value, AColumn) then
        begin
          Result := Result + CLink + JsonText(LForeignKey, 'targetTable');
          if not FFile.ForeignKeyTravels(SelectedSchema, FColumnsTable, LForeignKey) then
            Result := Result + ' (' + string(TranslateStr(1895, 'does not travel')) + ')';
          Break;
        end;
    end;
end;

procedure TFRpLocalSchemasLCL.FillColumns;
var
  I, LIndex: Integer;
  LNames: TStringList;
begin
  LNames := TStringList.Create;
  FUpdating := True;
  try
    FFile.GetColumnNames(FColumnsTable, LNames);
    FShownColumns.Clear;
    CheckColumns.Items.BeginUpdate;
    try
      CheckColumns.Items.Clear;
      for I := 0 to LNames.Count - 1 do
      begin
        if not MatchesFilter(LNames[I], EFilterColumns.Text) then
          Continue;
        LIndex := CheckColumns.Items.Add(ColumnCaption(LNames[I]));
        FShownColumns.Add(LNames[I]);
        CheckColumns.Checked[LIndex] := FFile.ColumnTravels(SelectedSchema,
          FColumnsTable, LNames[I]);
      end;
    finally
      CheckColumns.Items.EndUpdate;
    end;
    if FShownColumns.IndexOf(FColumn) < 0 then
      FColumn := '';
    CheckColumns.ItemIndex := FShownColumns.IndexOf(FColumn);
  finally
    FUpdating := False;
    LNames.Free;
  end;
  FillColumnDetails;
end;

// After a column is chosen or left: the checks and the marks in place (the
// list is not made again inside its own event)
procedure TFRpLocalSchemasLCL.RefreshColumnChecks;
var
  I: Integer;
  LText: string;
begin
  FUpdating := True;
  try
    for I := 0 to FShownColumns.Count - 1 do
    begin
      LText := ColumnCaption(FShownColumns[I]);
      if CheckColumns.Items[I] <> LText then
        CheckColumns.Items[I] := LText;
      CheckColumns.Checked[I] := FFile.ColumnTravels(SelectedSchema,
        FColumnsTable, FShownColumns[I]);
    end;
  finally
    FUpdating := False;
  end;
end;

procedure TFRpLocalSchemasLCL.FillColumnDetails;
var
  I: Integer;
  LColumn: TJSONObject;
  LLabels, LSchemas, LValues: TStringList;
  LType: string;
begin
  LColumn := FFile.FindColumn(FColumnsTable, FColumn);
  LValues := TStringList.Create;
  LLabels := TStringList.Create;
  LSchemas := TStringList.Create;
  FUpdating := True;
  try
    // The editor of a cell would keep the text of the column shown before
    GridValues.EditorMode := False;
    EColumnName.Text := JsonText(LColumn, 'name');
    LType := JsonText(LColumn, 'dataType');
    if JsonText(LColumn, 'detectedType') <> '' then
      LType := LType + ' (' + JsonText(LColumn, 'detectedType') + ')';
    EColumnType.Text := LType;
    MemoColumnContext.Enabled := LColumn <> nil;
    MemoColumnContext.Text := JsonText(LColumn, 'context');
    GridValues.Enabled := LColumn <> nil;
    BAddValue.Enabled := LColumn <> nil;
    BDeleteValue.Enabled := LColumn <> nil;
    if LColumn <> nil then
    begin
      FFile.GetAllowedValues(FColumnsTable, FColumn, LValues, LLabels);
      FFile.GetSchemasWithColumn(FColumnsTable, FColumn, SelectedSchema, LSchemas);
    end;
    if LSchemas.Count > 0 then
    begin
      LType := '';
      for I := 0 to LSchemas.Count - 1 do
      begin
        if LType <> '' then
          LType := LType + ', ';
        LType := LType + LSchemas[I];
      end;
      LAlsoIn.Caption := Format(TranslateStr(1863, 'Also in: %s'), [LType]);
    end
    else
      LAlsoIn.Caption := '';
    GridValues.RowCount := LValues.Count + 2;
    for I := 0 to LValues.Count - 1 do
    begin
      GridValues.Cells[0, I + 1] := LValues[I];
      GridValues.Cells[1, I + 1] := LLabels[I];
    end;
    GridValues.Cells[0, LValues.Count + 1] := '';
    GridValues.Cells[1, LValues.Count + 1] := '';
    BPreview.Enabled := FColumnsTable <> '';
  finally
    FUpdating := False;
    LSchemas.Free;
    LLabels.Free;
    LValues.Free;
  end;
end;

procedure TFRpLocalSchemasLCL.FillRelations;
var
  I: Integer;
begin
  FRelations.Clear;
  FSuggestions.Clear;
  FFile.GetRelations(SelectedSchema, FRelations);
  FFile.GetSuggestedRelations(SelectedSchema, FSuggestions);
  FUpdating := True;
  try
    ListRelations.Items.BeginUpdate;
    try
      ListRelations.Items.Clear;
      for I := 0 to FRelations.Count - 1 do
        ListRelations.Items.Add(RelationCaption(TRpLocalRelation(FRelations[I])));
    finally
      ListRelations.Items.EndUpdate;
    end;
    ListSuggestions.Items.BeginUpdate;
    try
      ListSuggestions.Items.Clear;
      for I := 0 to FSuggestions.Count - 1 do
        ListSuggestions.Items.Add(RelationCaption(TRpLocalRelation(FSuggestions[I])));
    finally
      ListSuggestions.Items.EndUpdate;
    end;
    BComplete.Enabled := FSuggestions.Count > 0;
    MemoRelationContext.Text := '';
    MemoRelationContext.Enabled := False;
    BDeleteRelation.Enabled := False;
  finally
    FUpdating := False;
  end;
end;

procedure TFRpLocalSchemasLCL.FillRelationTables;
var
  LTables: TStringList;
begin
  // From a table of the subschema to any table of the dictionary (Add
  // relation brings the target, as Complete does)
  LTables := SchemaTables;
  try
    LTables.Sort;
    ComboSource.Items.Assign(LTables);
    FFile.GetTableNames(LTables);
    LTables.Sort;
    ComboTarget.Items.Assign(LTables);
    ComboSourceColumn.Items.Clear;
    ComboTargetColumn.Items.Clear;
    FPairSource.Clear;
    FPairTarget.Clear;
    ListPairs.Items.Clear;
  finally
    LTables.Free;
  end;
end;

procedure TFRpLocalSchemasLCL.UpdateCounters;
var
  LTables, LWidest, LMaxTables, LMaxColumns: Integer;
  LTablesOver, LColumnsOver: Boolean;
begin
  if SelectedSchema <> nil then
    FFile.GetSchemaSize(SelectedSchema.Name, LTables, LWidest)
  else
    FFile.GetSchemaSize('', LTables, LWidest);
  LMaxTables := 0;
  LMaxColumns := 0;
  // No limit with the AI of an Agent
  if PlanApplies then
    TRpAuthManager.Instance.GetSchemaLimits(LMaxTables, LMaxColumns);
  LTablesOver := (LMaxTables > 0) and (LTables > LMaxTables);
  LColumnsOver := (LMaxColumns > 0) and (LWidest > LMaxColumns);
  LTablesCounter.Caption := Format(TranslateStr(1883, 'Tables: %s'),
    [CounterText(LTables, LMaxTables)]);
  LColumnsCounter.Caption := Format(TranslateStr(1884,
    'Columns of the widest table: %s'), [CounterText(LWidest, LMaxColumns)]);
  if LTablesOver then
    LTablesCounter.Font.Color := clRed
  else
    LTablesCounter.Font.Color := clWindowText;
  if LColumnsOver then
    LColumnsCounter.Font.Color := clRed
  else
    LColumnsCounter.Font.Color := clWindowText;
  LPlanWarning.Visible := LTablesOver or LColumnsOver;
end;

{ Left: the subschemas }

procedure TFRpLocalSchemasLCL.ListSchemasClick(Sender: TObject);
begin
  if FUpdating then
    Exit;
  // What the last import or export said is about another subschema
  ShowInfo('');
  if ListSchemas.ItemIndex < 0 then
    ListSchemas.ItemIndex := 0;
  FillAll;
end;

function TFRpLocalSchemasLCL.AddNewSchema: Boolean;
var
  LName: string;
begin
  Result := False;
  ShowInfo('');
  LName := '';
  LName := RpInputBox(TranslateStr(1887, 'New subschema'), TranslateStr(544, 'Name'), LName);
  if LName = '' then
    Exit;
  LName := Trim(LName);
  if LName = '' then
    Exit;
  FFile.AddSchema(LName);
  FModified := True;
  FillSchemas(LName);
  Pages.ActivePageIndex := 1;
  Result := True;
end;

procedure TFRpLocalSchemasLCL.BAddClick(Sender: TObject);
begin
  AddNewSchema;
end;

procedure TFRpLocalSchemasLCL.BDuplicateClick(Sender: TObject);
var
  LName: string;
begin
  ShowInfo('');
  if SelectedSchema = nil then
    Exit;
  LName := SelectedSchema.Name + ' (2)';
  LName := RpInputBox(TranslateStr(1847, 'Duplicate...'), TranslateStr(544, 'Name'), LName);
  if LName = '' then
    Exit;
  LName := Trim(LName);
  if LName = '' then
    Exit;
  FFile.DuplicateSchema(ListSchemas.ItemIndex - 1, LName);
  FModified := True;
  FillSchemas(LName);
end;

procedure TFRpLocalSchemasLCL.BRenameClick(Sender: TObject);
var
  LName: string;
begin
  ShowInfo('');
  if SelectedSchema = nil then
    Exit;
  LName := SelectedSchema.Name;
  LName := RpInputBox(TranslateStr(151, 'Rename'), TranslateStr(544, 'Name'), LName);
  if LName = '' then
    Exit;
  LName := Trim(LName);
  if (LName = '') or (LName = SelectedSchema.Name) then
    Exit;
  FFile.RenameSchema(ListSchemas.ItemIndex - 1, LName);
  FModified := True;
  FillSchemas(LName);
end;

procedure TFRpLocalSchemasLCL.BDeleteClick(Sender: TObject);
begin
  ShowInfo('');
  if SelectedSchema = nil then
    Exit;
  if RpMessageBox(Format(TranslateStr(1888, 'Delete the subschema %s?'),
    [SelectedSchema.Name]), '', [smbYes, smbNo], smsWarning, smbNo, smbNo) <> smbYes then
    Exit;
  FFile.DeleteSchema(ListSchemas.ItemIndex - 1);
  FModified := True;
  FillSchemas('');
end;

function SchemaFileFilter: string;
begin
  Result := string(TranslateStr(1939, 'Schema files')) + ' (*.json)|*.json';
end;

// The dialog is titled as the button that opens it, without its dots
function DialogTitle(const ACaption: string): string;
begin
  Result := Trim(StringReplace(ACaption, '...', '', [rfReplaceAll]));
end;

procedure TFRpLocalSchemasLCL.BExportClick(Sender: TObject);
var
  LDialog: TSaveDialog;
  LSchemaName: string;
begin
  // What travels, as it is on screen (saved or not); all the tables are
  // named after the alias
  LSchemaName := '';
  if SelectedSchema <> nil then
    LSchemaName := SelectedSchema.Name;
  if FFile.Alias = '' then
    FFile.Alias := UpperCase(FDatabase.Alias);
  LDialog := TSaveDialog.Create(Self);
  try
    LDialog.Title := DialogTitle(BExport.Caption);
    LDialog.Filter := SchemaFileFilter;
    LDialog.DefaultExt := 'json';
    LDialog.FileName := RpExportSchemaFileName(FFile, LSchemaName);
    LDialog.Options := LDialog.Options + [ofOverwritePrompt, ofPathMustExist];
    if not LDialog.Execute then
      Exit;
    RpExportSchemaToFile(FFile, LSchemaName, LDialog.FileName);
    ShowInfo(Format(string(TranslateStr(1935, 'Exported to %s.')),
      [LDialog.FileName]));
  finally
    LDialog.Free;
  end;
end;

procedure TFRpLocalSchemasLCL.BImportClick(Sender: TObject);
var
  LCount: Integer;
  LDialog: TOpenDialog;
  LName, LText: string;
  LSkipped: TStringList;
begin
  LDialog := TOpenDialog.Create(Self);
  LSkipped := TStringList.Create;
  try
    LDialog.Title := DialogTitle(BImport.Caption);
    LDialog.Filter := SchemaFileFilter;
    LDialog.DefaultExt := 'json';
    LDialog.Options := LDialog.Options + [ofFileMustExist];
    if not LDialog.Execute then
      Exit;
    LCount := RpImportSchemaFile(FFile, LDialog.FileName, LName, LSkipped);
    if LCount < 0 then
    begin
      RpMessageBox(string(TranslateStr(1938,
        'The file is not a schema exported by Reportman AI.')), '', [smbOK], smsCritical);
      Exit;
    end;
    // A new subschema, chosen and not saved: Save writes it, closing asks
    FModified := True;
    FillSchemas(LName);
    Pages.ActivePageIndex := 1;
    LText := Format(string(TranslateStr(1936,
      'Imported as %s: %s tables. Save to keep it.')), [LName, IntToStr(LCount)]);
    if LSkipped.Count > 0 then
    begin
      LText := LText + ' ' + Format(string(TranslateStr(1937,
        'Not in the database, not imported: %s')), [RpShortNameList(LSkipped, 8)]);
      ShowInfo(LText);
      RpMessageBox(LText);
    end
    else
      ShowInfo(LText);
  finally
    LSkipped.Free;
    LDialog.Free;
  end;
end;

procedure TFRpLocalSchemasLCL.MemoDescriptionChange(Sender: TObject);
begin
  if FUpdating or (SelectedSchema = nil) then
    Exit;
  SelectedSchema.Description := MemoDescription.Text;
  FModified := True;
end;

{ Connection }

procedure TFRpLocalSchemasLCL.BRefreshClick(Sender: TObject);
var
  LSelected: string;
begin
  LSelected := '';
  if SelectedSchema <> nil then
    LSelected := SelectedSchema.Name;
  LoadFile(True);
  FModified := True;
  FillSchemas(LSelected);
end;

{ Tables }

procedure TFRpLocalSchemasLCL.FilterTablesChange(Sender: TObject);
begin
  if not FUpdating then
    FillTables;
end;

procedure TFRpLocalSchemasLCL.BAddTableClick(Sender: TObject);
var
  I: Integer;
begin
  if SelectedSchema = nil then
    Exit;
  for I := 0 to ListAvailable.Items.Count - 1 do
    if ListAvailable.Selected[I] then
      FFile.AddSchemaTable(SelectedSchema, ListAvailable.Items[I]);
  Changed;
  FillTables;
  FillColumnTables;
  FillRelations;
  FillRelationTables;
end;

procedure TFRpLocalSchemasLCL.BRemoveTableClick(Sender: TObject);
var
  I: Integer;
begin
  if SelectedSchema = nil then
    Exit;
  for I := 0 to ListChosen.Items.Count - 1 do
    if ListChosen.Selected[I] then
      FFile.RemoveSchemaTable(SelectedSchema, ListChosen.Items[I]);
  Changed;
  FillTables;
  FillColumnTables;
  FillRelations;
  FillRelationTables;
end;

procedure TFRpLocalSchemasLCL.ListTablesClick(Sender: TObject);
var
  LList: TListBox;
begin
  if FUpdating then
    Exit;
  LList := TListBox(Sender);
  if LList.ItemIndex < 0 then
    Exit;
  FTablesTable := LList.Items[LList.ItemIndex];
  FillTableContext;
end;

procedure TFRpLocalSchemasLCL.MemoTableContextChange(Sender: TObject);
begin
  if FUpdating or (FTablesTable = '') then
    Exit;
  FFile.SetTableContext(FTablesTable, MemoTableContext.Text);
  FModified := True;
end;

{ Columns }

procedure TFRpLocalSchemasLCL.ListColumnTablesClick(Sender: TObject);
begin
  if FUpdating or (ListColumnTables.ItemIndex < 0) then
    Exit;
  FColumnsTable := ListColumnTables.Items[ListColumnTables.ItemIndex];
  FColumn := '';
  ClearPreview;
  FillColumns;
end;

procedure TFRpLocalSchemasLCL.FilterColumnsChange(Sender: TObject);
begin
  if not FUpdating then
    FillColumns;
end;

procedure TFRpLocalSchemasLCL.CheckColumnsClickCheck(Sender: TObject);
var
  I: Integer;
begin
  if FUpdating then
    Exit;
  // "All the tables" chooses nothing: every column travels
  if SelectedSchema <> nil then
  begin
    for I := 0 to FShownColumns.Count - 1 do
      if CheckColumns.Checked[I] <> FFile.ColumnTravels(SelectedSchema,
        FColumnsTable, FShownColumns[I]) then
        FFile.SetColumnChosen(SelectedSchema, FColumnsTable, FShownColumns[I],
          CheckColumns.Checked[I]);
    Changed;
    FillRelations;
  end;
  // An empty list is the primary key again
  RefreshColumnChecks;
  if CheckColumns.ItemIndex >= 0 then
  begin
    FColumn := FShownColumns[CheckColumns.ItemIndex];
    FillColumnDetails;
  end;
end;

procedure TFRpLocalSchemasLCL.CheckColumnsClick(Sender: TObject);
begin
  if FUpdating or (CheckColumns.ItemIndex < 0) then
    Exit;
  FColumn := FShownColumns[CheckColumns.ItemIndex];
  FillColumnDetails;
end;

procedure TFRpLocalSchemasLCL.BAddAllClick(Sender: TObject);
var
  I: Integer;
begin
  if SelectedSchema = nil then
    Exit;
  for I := 0 to FShownColumns.Count - 1 do
    FFile.SetColumnChosen(SelectedSchema, FColumnsTable, FShownColumns[I], True);
  Changed;
  FillColumns;
  FillRelations;
end;

procedure TFRpLocalSchemasLCL.BClearColumnsClick(Sender: TObject);
var
  I: Integer;
begin
  // The descriptions and allowed values stay in the dictionary: nothing to ask
  if SelectedSchema = nil then
    Exit;
  for I := 0 to FShownColumns.Count - 1 do
    FFile.SetColumnChosen(SelectedSchema, FColumnsTable, FShownColumns[I], False);
  Changed;
  FillColumns;
  FillRelations;
end;

procedure TFRpLocalSchemasLCL.MemoColumnContextChange(Sender: TObject);
begin
  if FUpdating or (FColumn = '') then
    Exit;
  FFile.SetColumnContext(FColumnsTable, FColumn, MemoColumnContext.Text);
  FModified := True;
end;

procedure TFRpLocalSchemasLCL.SaveAllowedValues;
var
  I: Integer;
  LLabels, LValues: TStringList;
begin
  if FColumn = '' then
    Exit;
  LValues := TStringList.Create;
  LLabels := TStringList.Create;
  try
    for I := 1 to GridValues.RowCount - 1 do
    begin
      LValues.Add(GridValues.Cells[0, I]);
      LLabels.Add(GridValues.Cells[1, I]);
    end;
    FFile.SetAllowedValues(FColumnsTable, FColumn, LValues, LLabels);
    FModified := True;
  finally
    LLabels.Free;
    LValues.Free;
  end;
end;

procedure TFRpLocalSchemasLCL.GridValuesSetEditText(Sender: TObject; ACol,
  ARow: Integer; const Value: string);
begin
  if FUpdating then
    Exit;
  GridValues.Cells[ACol, ARow] := Value;
  SaveAllowedValues;
end;

procedure TFRpLocalSchemasLCL.BAddValueClick(Sender: TObject);
begin
  GridValues.RowCount := GridValues.RowCount + 1;
  GridValues.Cells[0, GridValues.RowCount - 1] := '';
  GridValues.Cells[1, GridValues.RowCount - 1] := '';
  GridValues.Row := GridValues.RowCount - 1;
  GridValues.Col := 0;
  GridValues.SetFocus;
end;

procedure TFRpLocalSchemasLCL.BDeleteValueClick(Sender: TObject);
var
  I: Integer;
begin
  if (GridValues.Row < 1) or (GridValues.Row >= GridValues.RowCount) then
    Exit;
  for I := GridValues.Row to GridValues.RowCount - 2 do
  begin
    GridValues.Cells[0, I] := GridValues.Cells[0, I + 1];
    GridValues.Cells[1, I] := GridValues.Cells[1, I + 1];
  end;
  if GridValues.RowCount > 2 then
    GridValues.RowCount := GridValues.RowCount - 1
  else
  begin
    GridValues.Cells[0, 1] := '';
    GridValues.Cells[1, 1] := '';
  end;
  SaveAllowedValues;
end;

procedure TFRpLocalSchemasLCL.ClearPreview;
begin
  GridPreview.FixedRows := 0;
  GridPreview.RowCount := 1;
  GridPreview.ColCount := 1;
  GridPreview.Cells[0, 0] := '';
end;

procedure TFRpLocalSchemasLCL.BPreviewClick(Sender: TObject);
var
  I, LRow: Integer;
  LCursor: TCursor;
  LData: TDataSet;
begin
  if FColumnsTable = '' then
    Exit;
  ClearPreview;
  LCursor := Screen.Cursor;
  Screen.Cursor := crHourGlass;
  try
    try
      LData := FDatabase.OpenDatasetFromSQL(RpLocalSchemaPreviewSql(
        FFile.Dialect, FColumnsTable, CPreviewRows), nil, False, FReport.Params);
      try
        if LData.FieldCount > 0 then
          GridPreview.ColCount := LData.FieldCount;
        for I := 0 to LData.FieldCount - 1 do
        begin
          GridPreview.Cells[I, 0] := LData.Fields[I].FieldName;
          GridPreview.ColWidths[I] := S(110);
        end;
        LRow := 0;
        while (not LData.Eof) and (LRow < CPreviewRows) do
        begin
          Inc(LRow);
          GridPreview.RowCount := LRow + 1;
          for I := 0 to LData.FieldCount - 1 do
            if LData.Fields[I].IsBlob and not (LData.Fields[I].DataType in
              [ftMemo, ftWideMemo, ftFmtMemo]) then
              GridPreview.Cells[I, LRow] := '(BLOB)'
            else
              GridPreview.Cells[I, LRow] := LData.Fields[I].DisplayText;
          LData.Next;
        end;
        if GridPreview.RowCount > 1 then
          GridPreview.FixedRows := 1;
      finally
        LData.Free;
      end;
    finally
      FDatabase.DisConnect;
    end;
  finally
    Screen.Cursor := LCursor;
  end;
end;

{ Relations }

procedure TFRpLocalSchemasLCL.ListRelationsClick(Sender: TObject);
var
  LRelation: TRpLocalRelation;
begin
  if FUpdating or (ListRelations.ItemIndex < 0) then
    Exit;
  LRelation := TRpLocalRelation(FRelations[ListRelations.ItemIndex]);
  FUpdating := True;
  try
    MemoRelationContext.Enabled := True;
    MemoRelationContext.Text := LRelation.Context;
    BDeleteRelation.Enabled := LRelation.IsManual;
  finally
    FUpdating := False;
  end;
end;

procedure TFRpLocalSchemasLCL.MemoRelationContextChange(Sender: TObject);
begin
  if FUpdating or (ListRelations.ItemIndex < 0) then
    Exit;
  TRpLocalRelation(FRelations[ListRelations.ItemIndex]).SetContext(
    MemoRelationContext.Text);
  FModified := True;
end;

procedure TFRpLocalSchemasLCL.BDeleteRelationClick(Sender: TObject);
begin
  if ListRelations.ItemIndex < 0 then
    Exit;
  FFile.DeleteRelation(TRpLocalRelation(FRelations[ListRelations.ItemIndex]));
  Changed;
  FillRelations;
  FillColumns;
end;

procedure TFRpLocalSchemasLCL.BCompleteClick(Sender: TObject);
begin
  if (SelectedSchema = nil) or (ListSuggestions.ItemIndex < 0) then
    Exit;
  FFile.CompleteRelation(SelectedSchema,
    TRpLocalRelation(FSuggestions[ListSuggestions.ItemIndex]));
  Changed;
  FillTables;
  FillColumnTables;
  FillRelations;
  FillRelationTables;
end;

procedure TFRpLocalSchemasLCL.ComboSourceChange(Sender: TObject);
begin
  FFile.GetColumnNames(ComboSource.Text, ComboSourceColumn.Items);
  FPairSource.Clear;
  FPairTarget.Clear;
  ListPairs.Items.Clear;
end;

procedure TFRpLocalSchemasLCL.ComboTargetChange(Sender: TObject);
begin
  FFile.GetColumnNames(ComboTarget.Text, ComboTargetColumn.Items);
  FPairSource.Clear;
  FPairTarget.Clear;
  ListPairs.Items.Clear;
end;

procedure TFRpLocalSchemasLCL.BAddPairClick(Sender: TObject);
begin
  if (ComboSourceColumn.ItemIndex < 0) or (ComboTargetColumn.ItemIndex < 0) then
    Exit;
  FPairSource.Add(ComboSourceColumn.Text);
  FPairTarget.Add(ComboTargetColumn.Text);
  ListPairs.Items.Add(ComboSourceColumn.Text + CArrow + ComboTargetColumn.Text);
end;

procedure TFRpLocalSchemasLCL.BRemovePairClick(Sender: TObject);
var
  LIndex: Integer;
begin
  LIndex := ListPairs.ItemIndex;
  if LIndex < 0 then
    Exit;
  FPairSource.Delete(LIndex);
  FPairTarget.Delete(LIndex);
  ListPairs.Items.Delete(LIndex);
end;

procedure TFRpLocalSchemasLCL.BAddRelationClick(Sender: TObject);
var
  LRelation: TRpLocalRelation;
begin
  if (ComboSource.ItemIndex < 0) or (ComboTarget.ItemIndex < 0) or
    (FPairSource.Count = 0) then
  begin
    RpMessageBox(TranslateStr(1889, 'Choose the two tables and at least one ' +
      'pair of columns.'));
    Exit;
  end;
  LRelation := TRpLocalRelation.Create;
  try
    LRelation.SourceTable := ComboSource.Text;
    LRelation.ForeignKey := FFile.AddRelation(ComboSource.Text,
      ComboTarget.Text, FPairSource, FPairTarget, ENewContext.Text);
    // In a subschema it travels: completed as a suggested one
    FFile.CompleteRelation(SelectedSchema, LRelation);
  finally
    LRelation.Free;
  end;
  ENewContext.Text := '';
  Changed;
  FillTables;
  FillColumnTables;
  FillRelations;
  FillRelationTables;
end;

{ Validation }

procedure TFRpLocalSchemasLCL.BAnalyzeClick(Sender: TObject);
var
  LConfig: TRpApiDatabaseConfig;
  LTier, LMode, LSecret, LSchemaName: string;
  LAgentAiId: Int64;
begin
  if FAnalysis <> nil then
    Exit;
  FWebResult.ClearAll;
  if Trim(TRpAuthManager.Instance.Token) = '' then
  begin
    LStatus.Caption := '';
    FWebResult.AppendMessage('system', TranslateStr(1882,
      'Sign in to Reportman AI to analyze the schema.'));
    Exit;
  end;
  LTier := 'Standard';
  LMode := 'Fast';
  LSecret := '';
  LAgentAiId := 0;
  if FChat <> nil then
  begin
    LTier := FChat.GetAITier;
    LMode := FChat.GetAIMode;
    LSecret := FChat.GetAgentSecret;
    LAgentAiId := FChat.GetAgentAiId;
  end;
  LSchemaName := '';
  if SelectedSchema <> nil then
    LSchemaName := SelectedSchema.Name;
  // What the copilot would send of the subschema, as it is now on screen
  LConfig := TRpApiDatabaseConfig.Create;
  try
    LConfig.Name := FDatabase.Alias;
    LConfig.Dialect := FFile.CloudDialect;
    LConfig.SchemaTablesJson := FFile.SchemaTablesJson(LSchemaName);
    LConfig.SchemaName := FFile.SchemaNameOf(LSchemaName);
    FAnalysis := RpStartSchemaAnalysis(LConfig, LTier, LMode, LSecret, LAgentAiId);
  finally
    LConfig.Free;
  end;
  LStatus.Caption := TranslateStr(1878,
    'Analyzing the schema... (this may take a while)');
  BAnalyze.Enabled := False;
  BStop.Enabled := True;
  FAnalysisTimer.Enabled := True;
end;

procedure TFRpLocalSchemasLCL.StopAnalysis;
begin
  if FAnalysisTimer <> nil then
    FAnalysisTimer.Enabled := False;
  if FAnalysis <> nil then
    FAnalysis.Cancel;
  FAnalysis := nil;
end;

procedure TFRpLocalSchemasLCL.BStopClick(Sender: TObject);
begin
  StopAnalysis;
  LStatus.Caption := TranslateStr(1881, 'Analysis cancelled.');
  BAnalyze.Enabled := True;
  BStop.Enabled := False;
end;

procedure TFRpLocalSchemasLCL.AnalysisTimerTick(Sender: TObject);
var
  LJson: TJSONValue;
  LProfile, LResult: TJSONValue;
  LState: TRpSchemaAnalysisState;
  LMessage: string;
begin
  if FAnalysis = nil then
  begin
    FAnalysisTimer.Enabled := False;
    Exit;
  end;
  LState := FAnalysis.GetState;
  if not LState.Finished then
  begin
    if (LState.InputTokens > 0) or (LState.OutputTokens > 0) then
      LStatus.Caption := Format(TranslateStr(1879,
        'Analyzing... Tokens: %d in, %d out'), [LState.InputTokens,
        LState.OutputTokens]);
    Exit;
  end;
  FAnalysisTimer.Enabled := False;
  FAnalysis := nil;
  BAnalyze.Enabled := True;
  BStop.Enabled := False;
  if LState.Cancelled then
  begin
    LStatus.Caption := TranslateStr(1881, 'Analysis cancelled.');
    Exit;
  end;
  if LState.ErrorMessage <> '' then
  begin
    LStatus.Caption := '';
    FWebResult.AppendMessage('system', LState.ErrorMessage);
    Exit;
  end;
  LJson := TJSONObject.ParseJSONValue(LState.ResultJson);
  try
    if not (LJson is TJSONObject) then
    begin
      LStatus.Caption := '';
      Exit;
    end;
    // The credits of the account, as the chat refreshes them
    LProfile := TJSONObject(LJson).Values['userProfile'];
    if LProfile is TJSONObject then
      TRpAuthManager.Instance.UpdateProfileFromJson(TJSONObject(LProfile));
    LMessage := JsonText(TJSONObject(LJson), 'errorMessage');
    if Trim(LMessage) <> '' then
    begin
      // The plan error as the cloud says it: its numbers and the way out
      LStatus.Caption := '';
      FWebResult.AppendMessage('system', RpComposeApiErrorMessage(LMessage,
        JsonText(TJSONObject(LJson), 'errorCode'), ''));
      Exit;
    end;
    LResult := TJSONObject(LJson).Values['result'];
    if LResult is TJSONObject then
      FWebResult.AppendMessage('assistant',
        JsonText(TJSONObject(LResult), 'explanation'));
    LStatus.Caption := TranslateStr(1880, 'Analysis completed.');
  finally
    LJson.Free;
  end;
  UpdateCounters;
end;

{ Closing }

procedure TFRpLocalSchemasLCL.BSaveClick(Sender: TObject);
begin
  SaveFile;
end;

procedure TFRpLocalSchemasLCL.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  if not FModified then
    Exit;
  case RpMessageBox(TranslateStr(1886, 'The schema has changed. Save the changes?'),
    '', [smbYes, smbNo, smbCancel], smsWarning, smbYes, smbCancel) of
    smbYes:
      SaveFile;
    smbNo:
      ;
  else
    CanClose := False;
  end;
end;

function RpShowLocalSchemasDialog(AReport: TRpReport; const AAlias: string;
  var ASchemaName: string; AAddNew: Boolean; AChat: TFRpChatFrame): Boolean;
var
  LForm: TFRpLocalSchemasLCL;
begin
  Result := False;
  LForm := TFRpLocalSchemasLCL.CreateFor(Application, AReport, AAlias, AChat);
  try
    LForm.LoadFile(False);
    LForm.FillSchemas(ASchemaName);
    if AAddNew and not LForm.AddNewSchema then
      Exit;
    LForm.ShowModal;
    Result := LForm.FSaved;
    if Result then
    begin
      if LForm.SelectedSchema <> nil then
        ASchemaName := LForm.SelectedSchema.Name
      else
        ASchemaName := '';
    end;
  finally
    LForm.Free;
  end;
end;

end.
