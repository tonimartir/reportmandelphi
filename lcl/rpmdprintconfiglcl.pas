{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpmdprintconfiglcl                              }
{                                                       }
{       Configuration dialog for user printers          }
{       it stores all info in config files              }
{       (LCL port of rpmdprintconfigvcl)                }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}

unit rpmdprintconfiglcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Math, Graphics, Controls, Forms, StdCtrls,
  Printers, IniFiles,
  rpmdconsts, rpmdshfolder, rptypes, rpmunits;

type
  { TFRpPrinterConfigLCL: maps the logical printers of the reports (report
    printer, ticket printer...) to physical printers, with their position
    adjustment, printer fonts, text driver and the escape codes sent after
    printing. Same configuration file and keys as the VCL dialog and as
    rptypes reads them. Built in code (no form resource). }

  TFRpPrinterConfigLCL = class(TForm)
  private
    FLoading: Boolean;
    FConfigIniFile: TMemIniFile;
    FUserConfigFileName: string;
    FSystemConfigFileName: string;
    FUserConfig: Boolean;
    procedure BuildControls;
    procedure ReadPrintersConfig;
    function PrinterKey: string;
    procedure DoSave;
    procedure DiscardConfig;
    procedure FormCloseEvent(Sender: TObject; var CloseAction: TCloseAction);
    procedure LSelPrinterSelectionChange(Sender: TObject; User: Boolean);
  public
    LSelPrinter: TListBox;
    LSelectPrinter: TLabel;
    ComboPrinters: TComboBox;
    CheckPrinterFonts: TCheckBox;
    LTextDriver: TLabel;
    ComboTextOnly: TComboBox;
    CheckOem: TCheckBox;
    GPageMargins: TGroupBox;
    LLeft: TLabel;
    LTop: TLabel;
    LMetrics3: TLabel;
    LMetrics4: TLabel;
    ELeftMargin: TEdit;
    ETopMargin: TEdit;
    LOperations: TLabel;
    LExample: TLabel;
    LExample2: TLabel;
    CheckCutPaper: TCheckBox;
    ECutPaper: TEdit;
    CheckOpenDrawer: TCheckBox;
    EOpenDrawer: TEdit;
    GConfigFile: TGroupBox;
    RadioUser: TRadioButton;
    RadioSystem: TRadioButton;
    EConfigFile: TEdit;
    BOK: TButton;
    BCancel: TButton;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Shows the configuration of a logical printer (index of LSelPrinter,
    // that is, a TRpPrinterSelect value)
    procedure SelectLogicalPrinter(AIndex: Integer);
    procedure LSelPrinterClick(Sender: TObject);
    procedure RadioUserClick(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure CheckPrinterFontsChange(Sender: TObject);
    procedure ComboPrintersChange(Sender: TObject);
    procedure ELeftMarginChange(Sender: TObject);
    procedure ECutPaperChange(Sender: TObject);
    procedure CheckCutPaperChange(Sender: TObject);
    procedure ComboTextOnlyChange(Sender: TObject);
    procedure CheckOemChange(Sender: TObject);
    // The configuration being edited (saved on OK)
    property ConfigIniFile: TMemIniFile read FConfigIniFile;
    property UserConfigFileName: string read FUserConfigFileName;
    property SystemConfigFileName: string read FSystemConfigFileName;
  end;

procedure ShowPrintersConfiguration;

// The file the report engine reads the printer configuration from, with the
// same rules as rptypes (CheckLoadedPrinterConfig): the system file if it
// exists, else the user file if it exists, else the legacy user file
// (roaming application data in Windows, ~/.reportman in Linux)
function RpPrinterConfigFileName: string;

implementation

function RpPrinterConfigFileName: string;
begin
  Result := Obtainininamecommonconfig('', '', 'reportman');
  if FileExists(Result) then
    Exit;
  Result := Obtainininamelocalconfig('', '', 'reportman');
  if FileExists(Result) then
    Exit;
  Result := Obtainininameuserconfig('', '', 'reportman');
end;

procedure ShowPrintersConfiguration;
var
  dia: TFRpPrinterConfigLCL;
begin
  dia := TFRpPrinterConfigLCL.Create(Application);
  try
    dia.ShowModal;
  finally
    dia.Free;
  end;
end;

{ TFRpPrinterConfigLCL }

constructor TFRpPrinterConfigLCL.Create(AOwner: TComponent);
var
  j: Integer;
begin
  inherited CreateNew(AOwner);
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  ShowHint := True;
  OnClose := FormCloseEvent;
  FLoading := True;
  try
    BuildControls;
    ReadPrintersConfig;
    GetTextOnlyPrintDrivers(ComboTextOnly.Items);
    BOK.Caption := TranslateStr(93, BOK.Caption);
    BCancel.Caption := TranslateStr(94, BCancel.Caption);
    CheckPrinterFonts.Caption := TranslateStr(113, CheckPrinterFonts.Caption);
    LSelectPrinter.Caption := TranslateStr(741, LSelectPrinter.Caption);
    GConfigFile.Caption := TranslateStr(743, GConfigFile.Caption);
    RadioUser.Caption := TranslateStr(744, RadioUser.Caption);
    RadioSystem.Caption := TranslateStr(745, RadioSystem.Caption);
    Caption := TranslateStr(742, Caption);
    GPageMargins.Caption := TranslateStr(746, GPageMargins.Caption);
    LLeft.Caption := TranslateStr(100, LLeft.Caption);
    LTop.Caption := TranslateStr(102, LTop.Caption);
    LMetrics3.Caption := rpunitlabels[defaultunit];
    LMetrics4.Caption := LMetrics3.Caption;
    LOperations.Caption := TranslateStr(763, LOperations.Caption);
    LExample.Caption := TranslateStr(764, LExample.Caption);
    LExample2.Caption := TranslateStr(765, LExample2.Caption);
    CheckCutPaper.Caption := TranslateStr(766, CheckCutPaper.Caption);
    CheckOpenDrawer.Caption := TranslateStr(767, CheckOpenDrawer.Caption);
    LTextDriver.Caption := TranslateStr(1058, LTextDriver.Caption);
    with LSelPrinter.Items do
    begin
      Add(SRpDefaultPrinter);
      Add(SRpReportPrinter);
      Add(SRpTicketPrinter);
      Add(SRpGraphicprinter);
      Add(SRpCharacterprinter);
      Add(SRpReportPrinter2);
      Add(SRpTicketPrinter2);
      Add(SRpUserPrinter1);
      Add(SRpUserPrinter2);
      Add(SRpUserPrinter3);
      Add(SRpUserPrinter4);
      Add(SRpUserPrinter5);
      Add(SRpUserPrinter6);
      Add(SRpUserPrinter7);
      Add(SRpUserPrinter8);
      Add(SRpUserPrinter9);
      Add(SRpPlainPrinter);
      Add(SRpPlainFullPrinter);
      // pRpPrinter1..pRpPrinter50 (keys Printer18..Printer67)
      for j := 1 to 50 do
        Add('Printer' + IntToStr(j));
    end;
    // The physical printers: CUPS or the system may be missing (Linux)
    try
      ComboPrinters.Items.Assign(Printer.Printers);
    except
      ComboPrinters.Items.Clear;
    end;
    ComboPrinters.Items.Insert(0, SRpDefaultPrinter);
    RadioSystem.Checked := not FUserConfig;
    RadioUser.Checked := FUserConfig;
    RadioUserClick(Self);
  finally
    FLoading := False;
  end;
  SelectLogicalPrinter(0);
end;

destructor TFRpPrinterConfigLCL.Destroy;
begin
  DiscardConfig;
  inherited Destroy;
end;

procedure TFRpPrinterConfigLCL.DiscardConfig;
begin
  if not Assigned(FConfigIniFile) then
    Exit;
  // FPC TMemIniFile (unlike Delphi) writes its pending changes to the file
  // when it is freed: without a file name nothing is written (Cancel)
  FConfigIniFile.Rename('', False);
  FreeAndNil(FConfigIniFile);
end;

procedure TFRpPrinterConfigLCL.BuildControls;
var
  LBitmap: TBitmap;
  LMargin, LRight, LRightWidth, LButtonWidth, LButtonHeight, LEditHeight: Integer;
  LLabelWidth, LOemWidth: Integer;

  function NewLabel(AParent: TWinControl; const ACaption: string): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := AParent;
    Result.Caption := ACaption;
  end;

  function NewEdit(AParent: TWinControl; AChange: TNotifyEvent): TEdit;
  begin
    Result := TEdit.Create(Self);
    Result.Parent := AParent;
    Result.OnChange := AChange;
  end;

  function NewCheck(AParent: TWinControl; const ACaption: string;
    AChange: TNotifyEvent): TCheckBox;
  begin
    Result := TCheckBox.Create(Self);
    Result.Parent := AParent;
    Result.Caption := ACaption;
    Result.OnChange := AChange;
  end;

  function NewButton(const ACaption: string): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Self;
    Result.Caption := ACaption;
  end;

begin
  LMargin := Scale96ToScreen(8);
  ClientWidth := Scale96ToScreen(560);
  LRight := Scale96ToScreen(214);
  LRightWidth := ClientWidth - LRight - LMargin;
  LEditHeight := Scale96ToScreen(24);
  LButtonHeight := Scale96ToScreen(30);

  LSelPrinter := TListBox.Create(Self);
  LSelPrinter.Parent := Self;
  LSelPrinter.SetBounds(Scale96ToScreen(4), Scale96ToScreen(4), Scale96ToScreen(202),
    Scale96ToScreen(328));
  // Mouse and keyboard
  LSelPrinter.OnSelectionChange := LSelPrinterSelectionChange;

  LSelectPrinter := NewLabel(Self, 'Select Printer');
  LSelectPrinter.SetBounds(LRight, Scale96ToScreen(4), LRightWidth, Scale96ToScreen(18));
  ComboPrinters := TComboBox.Create(Self);
  ComboPrinters.Parent := Self;
  ComboPrinters.Style := csDropDownList;
  ComboPrinters.SetBounds(LRight, Scale96ToScreen(22), LRightWidth, LEditHeight);
  ComboPrinters.Anchors := [akLeft, akTop, akRight];
  ComboPrinters.OnChange := ComboPrintersChange;

  CheckPrinterFonts := NewCheck(Self, 'Printer Fonts (Windows GDI Only)', CheckPrinterFontsChange);
  CheckPrinterFonts.SetBounds(LRight, Scale96ToScreen(56), LRightWidth, Scale96ToScreen(22));

  LTextDriver := NewLabel(Self, 'Text only driver');
  CheckOem := NewCheck(Self, 'Oem', CheckOemChange);
  ComboTextOnly := TComboBox.Create(Self);
  ComboTextOnly.Parent := Self;
  ComboTextOnly.Style := csDropDownList;
  ComboTextOnly.OnChange := ComboTextOnlyChange;
  LBitmap := TBitmap.Create;
  try
    LBitmap.Canvas.Font := Font;
    LLabelWidth := LBitmap.Canvas.TextWidth(TranslateStr(1058, LTextDriver.Caption)) +
      Scale96ToScreen(8);
    LOemWidth := LBitmap.Canvas.TextWidth(CheckOem.Caption) + Scale96ToScreen(28);
    LButtonWidth := Max(Scale96ToScreen(90),
      Max(LBitmap.Canvas.TextWidth(TranslateStr(93, 'OK')),
        LBitmap.Canvas.TextWidth(TranslateStr(94, 'Cancel'))) + Scale96ToScreen(24));
  finally
    LBitmap.Free;
  end;
  LLabelWidth := Min(LLabelWidth, LRightWidth div 2);
  LTextDriver.SetBounds(LRight, Scale96ToScreen(92), LLabelWidth, Scale96ToScreen(18));
  CheckOem.SetBounds(ClientWidth - LMargin - LOemWidth, Scale96ToScreen(88), LOemWidth,
    Scale96ToScreen(22));
  CheckOem.Anchors := [akTop, akRight];
  ComboTextOnly.SetBounds(LRight + LLabelWidth, Scale96ToScreen(88),
    LRightWidth - LLabelWidth - LOemWidth - Scale96ToScreen(4), LEditHeight);
  ComboTextOnly.Anchors := [akLeft, akTop, akRight];

  GPageMargins := TGroupBox.Create(Self);
  GPageMargins.Parent := Self;
  GPageMargins.Caption := 'Position adjustment';
  GPageMargins.SetBounds(LRight, Scale96ToScreen(120), LRightWidth, Scale96ToScreen(88));
  GPageMargins.Anchors := [akLeft, akTop, akRight];
  LLeft := NewLabel(GPageMargins, 'Left');
  LLeft.SetBounds(Scale96ToScreen(12), Scale96ToScreen(8), Scale96ToScreen(80), Scale96ToScreen(18));
  ELeftMargin := NewEdit(GPageMargins, ELeftMarginChange);
  ELeftMargin.SetBounds(Scale96ToScreen(96), Scale96ToScreen(4), Scale96ToScreen(90), LEditHeight);
  LMetrics3 := NewLabel(GPageMargins, 'inch.');
  LMetrics3.SetBounds(Scale96ToScreen(194), Scale96ToScreen(8), Scale96ToScreen(60), Scale96ToScreen(18));
  LTop := NewLabel(GPageMargins, 'Top');
  LTop.SetBounds(Scale96ToScreen(12), Scale96ToScreen(38), Scale96ToScreen(80), Scale96ToScreen(18));
  ETopMargin := NewEdit(GPageMargins, ELeftMarginChange);
  ETopMargin.SetBounds(Scale96ToScreen(96), Scale96ToScreen(34), Scale96ToScreen(90), LEditHeight);
  LMetrics4 := NewLabel(GPageMargins, 'inch.');
  LMetrics4.SetBounds(Scale96ToScreen(194), Scale96ToScreen(38), Scale96ToScreen(60), Scale96ToScreen(18));

  LOperations := NewLabel(Self, 'Operations after print');
  LOperations.SetBounds(LRight, Scale96ToScreen(214), LRightWidth, Scale96ToScreen(18));
  LExample := NewLabel(Self, 'Example, TM200 Open Drawer: #27#112#48#160#160#4');
  LExample.SetBounds(LRight, Scale96ToScreen(234), LRightWidth, Scale96ToScreen(18));
  LExample2 := NewLabel(Self, 'Example, TM88 Open Drawer: #27#112#48#40#200#4');
  LExample2.SetBounds(LRight, Scale96ToScreen(252), LRightWidth, Scale96ToScreen(18));

  CheckCutPaper := NewCheck(Self, 'Cut paper', CheckCutPaperChange);
  CheckCutPaper.SetBounds(LRight, Scale96ToScreen(276), Scale96ToScreen(150), Scale96ToScreen(22));
  ECutPaper := NewEdit(Self, ECutPaperChange);
  ECutPaper.SetBounds(LRight + Scale96ToScreen(156), Scale96ToScreen(274),
    LRightWidth - Scale96ToScreen(156), LEditHeight);
  ECutPaper.Anchors := [akLeft, akTop, akRight];
  CheckOpenDrawer := NewCheck(Self, 'Open drawer', CheckCutPaperChange);
  CheckOpenDrawer.SetBounds(LRight, Scale96ToScreen(306), Scale96ToScreen(150), Scale96ToScreen(22));
  EOpenDrawer := NewEdit(Self, ECutPaperChange);
  EOpenDrawer.SetBounds(LRight + Scale96ToScreen(156), Scale96ToScreen(304),
    LRightWidth - Scale96ToScreen(156), LEditHeight);
  EOpenDrawer.Anchors := [akLeft, akTop, akRight];

  GConfigFile := TGroupBox.Create(Self);
  GConfigFile.Parent := Self;
  GConfigFile.Caption := 'Configuration file';
  GConfigFile.SetBounds(Scale96ToScreen(4), Scale96ToScreen(340),
    ClientWidth - Scale96ToScreen(4) - LMargin, Scale96ToScreen(104));
  GConfigFile.Anchors := [akLeft, akTop, akRight];
  RadioUser := TRadioButton.Create(Self);
  RadioUser.Parent := GConfigFile;
  RadioUser.Caption := 'User configuration';
  RadioUser.SetBounds(Scale96ToScreen(8), Scale96ToScreen(2), Scale96ToScreen(400), Scale96ToScreen(22));
  RadioUser.OnClick := RadioUserClick;
  RadioSystem := TRadioButton.Create(Self);
  RadioSystem.Parent := GConfigFile;
  RadioSystem.Caption := 'System configuration';
  RadioSystem.SetBounds(Scale96ToScreen(8), Scale96ToScreen(26), Scale96ToScreen(400), Scale96ToScreen(22));
  RadioSystem.OnClick := RadioUserClick;
  EConfigFile := TEdit.Create(Self);
  EConfigFile.Parent := GConfigFile;
  EConfigFile.SetBounds(Scale96ToScreen(8), Scale96ToScreen(52),
    GConfigFile.ClientWidth - Scale96ToScreen(16), LEditHeight);
  EConfigFile.Anchors := [akLeft, akTop, akRight];
  EConfigFile.Color := clBtnFace;

  BOK := NewButton('OK');
  BOK.Default := True;
  BOK.OnClick := BOKClick;
  BOK.SetBounds(LMargin, Scale96ToScreen(452), LButtonWidth, LButtonHeight);
  BCancel := NewButton('Cancel');
  BCancel.Cancel := True;
  BCancel.ModalResult := mrCancel;
  BCancel.SetBounds(LMargin + LButtonWidth + Scale96ToScreen(16), Scale96ToScreen(452),
    LButtonWidth, LButtonHeight);
  ClientHeight := Scale96ToScreen(452) + LButtonHeight + LMargin;
end;

procedure TFRpPrinterConfigLCL.ReadPrintersConfig;
begin
  FSystemConfigFileName := Obtainininamecommonconfig('', '', 'reportman');
  FUserConfigFileName := Obtainininamelocalconfig('', '', 'reportman');
  FUserConfig := not FileExists(FSystemConfigFileName);
  DiscardConfig;
  // The values the engine uses now: also those of a legacy user file when
  // there is no other one (saved to the chosen file on OK)
  FConfigIniFile := TMemIniFile.Create(RpPrinterConfigFileName);
end;

function TFRpPrinterConfigLCL.PrinterKey: string;
begin
  Result := 'Printer' + IntToStr(LSelPrinter.ItemIndex);
end;

procedure TFRpPrinterConfigLCL.SelectLogicalPrinter(AIndex: Integer);
begin
  LSelPrinter.ItemIndex := AIndex;
  LSelPrinterClick(LSelPrinter);
end;

procedure TFRpPrinterConfigLCL.LSelPrinterSelectionChange(Sender: TObject; User: Boolean);
begin
  LSelPrinterClick(Sender);
end;

procedure TFRpPrinterConfigLCL.LSelPrinterClick(Sender: TObject);
var
  index: Integer;
  defdriver: string;
begin
  if LSelPrinter.ItemIndex < 0 then
    Exit;
  // Showing the values of a printer does not write them
  FLoading := True;
  try
    if LSelPrinter.ItemIndex = 0 then
    begin
      LSelectPrinter.Visible := False;
      ComboPrinters.ItemIndex := 0;
      ComboPrinters.Visible := False;
      CheckPrinterFonts.Checked := FConfigIniFile.ReadBool('PrinterFonts', 'Default', False);
    end
    else
    begin
      LSelectPrinter.Visible := True;
      ComboPrinters.Visible := True;
      CheckPrinterFonts.Checked := FConfigIniFile.ReadBool('PrinterFonts', PrinterKey, False);
      ComboPrinters.ItemIndex := ComboPrinters.Items.IndexOf(
        FConfigIniFile.ReadString('PrinterNames', PrinterKey, ''));
      // Not configured, or a printer that is not installed here
      if ComboPrinters.ItemIndex < 0 then
        ComboPrinters.ItemIndex := 0;
    end;
    ELeftMargin.Text := gettextfromtwips(FConfigIniFile.ReadInteger('PrinterOffsetX', PrinterKey, 0));
    ETopMargin.Text := gettextfromtwips(FConfigIniFile.ReadInteger('PrinterOffsetY', PrinterKey, 0));
    CheckCutPaper.Checked := FConfigIniFile.ReadBool('CutPaperOn', PrinterKey, False);
    ECutPaper.Text := FConfigIniFile.ReadString('CutPaper', PrinterKey, '');
    CheckOpenDrawer.Checked := FConfigIniFile.ReadBool('OpenDrawerOn', PrinterKey, False);
    EOpenDrawer.Text := FConfigIniFile.ReadString('OpenDrawer', PrinterKey, '#27#112#0#100#100');
    defdriver := ' ';
    if LSelPrinter.ItemIndex = Integer(pRpCharacterprinter) then
      defdriver := 'EPSON';
    defdriver := FConfigIniFile.ReadString('PrinterDriver', PrinterKey, defdriver);
    if Length(defdriver) < 1 then
      defdriver := ' ';
    index := ComboTextOnly.Items.IndexOf(defdriver);
    // An unknown driver shows nothing instead of the one of the previous printer
    ComboTextOnly.ItemIndex := index;
    CheckOem.Checked := FConfigIniFile.ReadBool('PrinterEscapeOem', PrinterKey, True);
  finally
    FLoading := False;
  end;
end;

procedure TFRpPrinterConfigLCL.RadioUserClick(Sender: TObject);
begin
  // Sets the filename
  if RadioSystem.Checked then
    EConfigFile.Text := FSystemConfigFileName
  else
    EConfigFile.Text := FUserConfigFileName;
end;

procedure TFRpPrinterConfigLCL.BOKClick(Sender: TObject);
begin
  DoSave;
  if fsModal in FormState then
    ModalResult := mrOk
  else
    Close;
end;

procedure TFRpPrinterConfigLCL.DoSave;
var
  LFileName, LDir: string;
begin
  LFileName := Trim(EConfigFile.Text);
  if LFileName = '' then
    raise Exception.Create(SRpFileNameRequired);
  if FConfigIniFile.FileName <> LFileName then
    FConfigIniFile.Rename(LFileName, False);
  LDir := ExtractFileDir(LFileName);
  if (LDir <> '') and not DirectoryExists(LDir) then
    ForceDirectories(LDir);
  FConfigIniFile.UpdateFile;
  // The engine reads the new values from now on
  ReloadPrinterConfig;
end;

procedure TFRpPrinterConfigLCL.FormCloseEvent(Sender: TObject; var CloseAction: TCloseAction);
begin
  // As the VCL dialog: the engine always leaves with the saved configuration
  ReloadPrinterConfig;
end;

procedure TFRpPrinterConfigLCL.CheckPrinterFontsChange(Sender: TObject);
begin
  if FLoading or (LSelPrinter.ItemIndex < 0) then
    Exit;
  if LSelPrinter.ItemIndex = 0 then
    FConfigIniFile.WriteBool('PrinterFonts', 'Default', CheckPrinterFonts.Checked)
  else
    FConfigIniFile.WriteBool('PrinterFonts', PrinterKey, CheckPrinterFonts.Checked);
end;

procedure TFRpPrinterConfigLCL.ComboPrintersChange(Sender: TObject);
var
  printername: string;
begin
  if FLoading or (LSelPrinter.ItemIndex < 0) then
    Exit;
  // The first item is the default printer: no physical printer
  if (LSelPrinter.ItemIndex = 0) or (ComboPrinters.ItemIndex <= 0) then
    printername := ''
  else
    printername := ComboPrinters.Items[ComboPrinters.ItemIndex];
  FConfigIniFile.WriteString('PrinterNames', PrinterKey, printername);
end;

procedure TFRpPrinterConfigLCL.ELeftMarginChange(Sender: TObject);
var
  margin: Integer;
begin
  if FLoading or (LSelPrinter.ItemIndex < 0) then
    Exit;
  try
    margin := gettwipsfromtext(TEdit(Sender).Text);
  except
    margin := 0;
  end;
  if Sender = ELeftMargin then
    FConfigIniFile.WriteInteger('PrinterOffsetX', PrinterKey, margin)
  else
    FConfigIniFile.WriteInteger('PrinterOffsetY', PrinterKey, margin);
end;

procedure TFRpPrinterConfigLCL.ECutPaperChange(Sender: TObject);
var
  Operation: string;
begin
  if FLoading or (LSelPrinter.ItemIndex < 0) then
    Exit;
  if Sender = ECutPaper then
    Operation := 'CutPaper'
  else
    Operation := 'OpenDrawer';
  FConfigIniFile.WriteString(Operation, PrinterKey, TEdit(Sender).Text);
end;

procedure TFRpPrinterConfigLCL.CheckCutPaperChange(Sender: TObject);
var
  Operation: string;
begin
  if FLoading or (LSelPrinter.ItemIndex < 0) then
    Exit;
  if Sender = CheckCutPaper then
    Operation := 'CutPaper'
  else
    Operation := 'OpenDrawer';
  FConfigIniFile.WriteBool(Operation + 'On', PrinterKey, TCheckBox(Sender).Checked);
end;

procedure TFRpPrinterConfigLCL.ComboTextOnlyChange(Sender: TObject);
var
  drivername: string;
begin
  if FLoading or (LSelPrinter.ItemIndex < 0) or (ComboTextOnly.ItemIndex < 0) then
    Exit;
  drivername := UpperCase(Trim(ComboTextOnly.Items[ComboTextOnly.ItemIndex]));
  if Length(drivername) > 0 then
  begin
    FConfigIniFile.WriteInteger('PrinterEscapeStyle', PrinterKey, Integer(rpPrinterDatabase));
    FConfigIniFile.WriteString('PrinterDriver', PrinterKey, drivername);
  end
  else
  begin
    FConfigIniFile.WriteInteger('PrinterEscapeStyle', PrinterKey, Integer(rpPrinterDefault));
    FConfigIniFile.WriteString('PrinterDriver', PrinterKey, ' ');
  end;
end;

procedure TFRpPrinterConfigLCL.CheckOemChange(Sender: TObject);
begin
  if FLoading or (LSelPrinter.ItemIndex < 0) then
    Exit;
  FConfigIniFile.WriteBool('PrinterEscapeOem', PrinterKey, CheckOem.Checked);
end;

end.
