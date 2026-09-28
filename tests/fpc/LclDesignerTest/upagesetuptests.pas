unit upagesetuptests;

{ Phase 8 (page setup parity): behavioural tests of the LCL page setup (PDF
  options, document metadata, embedded files and its undo in the designer),
  the embedded file dialog, the printer configuration (round trip with what
  rptypes reads) and the system information dialog.

  The dialogs are modal: a form visibility handler installed before the
  modal guard of uregressiontests answers the expected ones synchronously
  (as the guard does with its message boxes) and marks them handled, so the
  guard still fails any other modal form. }

{$mode delphi}

interface

procedure RunPageSetupTests;

implementation

uses
  Classes, SysUtils, Variants, Forms, Printers,
  rptypes, rpmunits, rpreport, rpbasereport,
  rpmdundocuelcl, rpmdfmainlcl,
  rppagesetuplcl, rpmdfembeddedfilelcl, rpmdprintconfiglcl, rpmdsysinfolcl,
  rpmdshfolder, umainform;

const
  // uregressiontests (TModalGuard) ignores the modal forms with this tag
  GUARD_HANDLED_TAG = $5EC7;

type
  TDialogAction = procedure(AForm: TCustomForm) of object;

  TExpectedDialog = record
    FormClass: TCustomFormClass;
    Action: TDialogAction;
  end;

  { TPageSetupTests }

  TPageSetupTests = class
  private
    FExpected: array of TExpectedDialog;
    FHandled: Integer;
    FTempDir: string;
    FDataFile: string;
    FDataContent: RawByteString;
    // Values the actions set / check
    FEmbDescription: string;
    FEmbFileName: string;
    FEmbRelation: Integer;
    FPageAuthor: string;
    // Only the embedded files change (no metadata nor PDF options)
    FPageOnlyFiles: Boolean;
    FPageAddFile: Boolean;
    FPageDeleteFirst: Boolean;
    FPageModifyFirst: Boolean;
    FPageAccept: Boolean;
    FPageOpenPrinters: Boolean;
    FSysInfoChecked: Boolean;
    FPrintConfigChecked: Boolean;
    // User printer configuration saved before the test
    FUserConfigFile: string;
    FHadUserConfig: Boolean;
    FUserConfigBytes: RawByteString;
    procedure RestoreUserConfig;
    procedure FormVisibleChanged(Sender: TObject; Form: TCustomForm);
    procedure Expect(AClass: TCustomFormClass; AAction: TDialogAction);
    procedure CheckAllHandled(const Context: string);
    procedure CheckFitsSmallScreen(AForm: TCustomForm);
    // Actions for the modal dialogs
    procedure EmbeddedAccept(AForm: TCustomForm);
    procedure EmbeddedCancel(AForm: TCustomForm);
    procedure PageSetupAction(AForm: TCustomForm);
    procedure PrinterConfigCancel(AForm: TCustomForm);
    procedure SysInfoAction(AForm: TCustomForm);
    // Tests
    procedure TestUndoValue;
    procedure TestEmbeddedFileDialog;
    procedure TestPageSetupDialog;
    procedure TestPageSetupInDesigner;
    procedure DesignerPageSetupSteps;
    procedure TestPrinterConfig;
    procedure TestSysInfo;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
  end;

var
  // Run before halting on a failure: Halt skips the finally blocks, and the
  // printer configuration test must give the user his configuration back
  FailCleanup: procedure of object = nil;

{ Assertions }

procedure Fail(const Msg: string);
var
  LCleanup: procedure of object;
begin
  LogMsg('[TEST_FAILED] ' + Msg);
  LCleanup := FailCleanup;
  FailCleanup := nil;
  if Assigned(LCleanup) then
    try
      LCleanup;
    except
    end;
  Halt(1);
end;

procedure Check(Cond: Boolean; const Msg: string);
begin
  if not Cond then
    Fail(Msg);
end;

procedure CheckInt(Expected, Actual: Integer; const What: string);
begin
  if Expected <> Actual then
    Fail(Format('%s: expected %d, got %d', [What, Expected, Actual]));
end;

procedure CheckStr(const Expected, Actual: string; const What: string);
begin
  if Expected <> Actual then
    Fail(Format('%s: expected "%s", got "%s"', [What, Expected, Actual]));
end;

function StreamText(AStream: TStream): RawByteString;
begin
  Result := '';
  if not Assigned(AStream) or (AStream.Size = 0) then
    Exit;
  SetLength(Result, AStream.Size);
  AStream.Position := 0;
  AStream.ReadBuffer(Result[1], AStream.Size);
  AStream.Position := 0;
end;

procedure WriteBytes(const AFileName: string; const AData: RawByteString);
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(AData) > 0 then
      fs.WriteBuffer(AData[1], Length(AData));
  finally
    fs.Free;
  end;
end;

function ReadBytes(const AFileName: string): RawByteString;
var
  fs: TFileStream;
begin
  Result := '';
  fs := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, fs.Size);
    if fs.Size > 0 then
      fs.ReadBuffer(Result[1], fs.Size);
  finally
    fs.Free;
  end;
end;

// Printers of the system; 0 when the printing system is missing (a Linux
// without CUPS raises)
function InstalledPrinterCount: Integer;
begin
  try
    Result := Printer.Printers.Count;
  except
    Result := 0;
  end;
end;

function NewEmbeddedFile(const AName, AMime, ADescription: string;
  const AData: RawByteString): TEmbeddedFile;
begin
  Result := TEmbeddedFile.Create;
  Result.FileName := AName;
  Result.MimeType := AMime;
  Result.Description := ADescription;
  Result.AFRelationShip := PDF_AF_Source;
  Result.CreationDate := '2026-09-28T10:00:00Z';
  Result.ModificationDate := '2026-09-28T11:00:00Z';
  Result.Stream := TMemoryStream.Create;
  if Length(AData) > 0 then
    Result.Stream.WriteBuffer(AData[1], Length(AData));
  Result.Stream.Position := 0;
end;

procedure AddReportFile(ARep: TRpBaseReport; AFile: TEmbeddedFile);
begin
  SetLength(ARep.EmbeddedFiles, Length(ARep.EmbeddedFiles) + 1);
  ARep.EmbeddedFiles[Length(ARep.EmbeddedFiles) - 1] := AFile;
end;

function NewTestReport: TRpReport;
begin
  Result := TRpReport.Create(nil);
  Result.AddSubReport;
end;

function SaveAndLoad(ARep: TRpReport; AFormat: TRpStreamFormat): TRpReport;
var
  ms: TMemoryStream;
begin
  ms := TMemoryStream.Create;
  try
    ARep.StreamFormat := AFormat;
    ARep.SaveToStream(ms);
    ms.Position := 0;
    Result := TRpReport.Create(nil);
    try
      Result.LoadFromStream(ms);
    except
      Result.Free;
      raise;
    end;
  finally
    ms.Free;
  end;
end;

{ TPageSetupTests }

constructor TPageSetupTests.Create;
begin
  inherited Create;
  FTempDir := IncludeTrailingPathDelimiter(GetTempDir) + 'rp_pagesetup_' +
    IntToStr(GetProcessID);
  ForceDirectories(FTempDir);
  FDataFile := IncludeTrailingPathDelimiter(FTempDir) + 'factur-x.xml';
  // Binary content: the embedded files are not text
  FDataContent := '<?xml version="1.0"?><inv>' + #$C3#$B1 + '</inv>' + #0#1#2#255#13#10;
  WriteBytes(FDataFile, FDataContent);
  // Before the modal guard of uregressiontests: the expected dialogs are
  // answered here (the screen calls the handlers from the last one added)
  Screen.AddHandlerFormVisibleChanged(FormVisibleChanged, False);
end;

destructor TPageSetupTests.Destroy;
begin
  Screen.RemoveHandlerFormVisibleChanged(FormVisibleChanged);
  DeleteFile(FDataFile);
  RemoveDir(FTempDir);
  inherited Destroy;
end;

procedure TPageSetupTests.Expect(AClass: TCustomFormClass; AAction: TDialogAction);
begin
  SetLength(FExpected, Length(FExpected) + 1);
  FExpected[High(FExpected)].FormClass := AClass;
  FExpected[High(FExpected)].Action := AAction;
end;

procedure TPageSetupTests.CheckAllHandled(const Context: string);
begin
  if Length(FExpected) > 0 then
    Fail(Context + ': expected dialog ' + FExpected[0].FormClass.ClassName +
      ' was not shown');
end;

procedure TPageSetupTests.FormVisibleChanged(Sender: TObject; Form: TCustomForm);
var
  LAction: TDialogAction;
  I: Integer;
begin
  if not Assigned(Form) or not Form.Visible or not (fsModal in Form.FormState) then
    Exit;
  if Form.Tag = GUARD_HANDLED_TAG then
    Exit;
  if (Length(FExpected) = 0) or not (Form is FExpected[0].FormClass) then
    Exit;
  LAction := FExpected[0].Action;
  for I := 1 to High(FExpected) do
    FExpected[I - 1] := FExpected[I];
  SetLength(FExpected, Length(FExpected) - 1);
  Form.Tag := GUARD_HANDLED_TAG;
  Inc(FHandled);
  LogMsg('PageSetupTests: answering ' + Form.ClassName);
  try
    LAction(Form);
  except
    on E: Exception do
      Fail('Action for ' + Form.ClassName + ' raised ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TPageSetupTests.CheckFitsSmallScreen(AForm: TCustomForm);
begin
  // The dialogs must fit an 800x600 screen (title bar and task bar included)
  Check(AForm.Width <= Round(800 * Screen.PixelsPerInch / 96),
    Format('%s is %d pixels wide: does not fit 800x600', [AForm.ClassName, AForm.Width]));
  Check(AForm.Height <= Round(530 * Screen.PixelsPerInch / 96),
    Format('%s is %d pixels high: does not fit 800x600', [AForm.ClassName, AForm.Height]));
end;

procedure TPageSetupTests.EmbeddedAccept(AForm: TCustomForm);
var
  dia: TFRpEmbeddedFileLCL;
begin
  dia := AForm as TFRpEmbeddedFileLCL;
  CheckFitsSmallScreen(dia);
  CheckInt(5, dia.ComboRelationShip.Items.Count, 'Embedded file dialog: relationships');
  Check(dia.ComboMimeType.Items.Count > 5, 'Embedded file dialog: common mime types');
  dia.textDescription.Text := FEmbDescription;
  if FEmbFileName <> '' then
    dia.textFilename.Text := FEmbFileName;
  dia.ComboRelationShip.ItemIndex := FEmbRelation;
  dia.textCreationDate.Text := '2026-09-01T08:00:00Z';
  dia.textModificationDate.Text := '2026-09-02T09:00:00Z';
  dia.BOK.Click;
end;

procedure TPageSetupTests.EmbeddedCancel(AForm: TCustomForm);
var
  dia: TFRpEmbeddedFileLCL;
begin
  dia := AForm as TFRpEmbeddedFileLCL;
  dia.textDescription.Text := 'CANCELLED';
  dia.BCancel.Click;
end;

procedure TPageSetupTests.PrinterConfigCancel(AForm: TCustomForm);
var
  dia: TFRpPrinterConfigLCL;
  drivers: TStringList;
begin
  dia := AForm as TFRpPrinterConfigLCL;
  CheckFitsSmallScreen(dia);
  CheckInt(68, dia.LSelPrinter.Items.Count, 'Printer configuration: logical printers');
  CheckInt(InstalledPrinterCount + 1, dia.ComboPrinters.Items.Count,
    'Printer configuration: default printer and the installed ones');
  drivers := TStringList.Create;
  try
    GetTextOnlyPrintDrivers(drivers);
    CheckInt(drivers.Count, dia.ComboTextOnly.Items.Count, 'Printer configuration: text drivers');
  finally
    drivers.Free;
  end;
  FPrintConfigChecked := True;
  dia.BCancel.Click;
end;

procedure TPageSetupTests.PageSetupAction(AForm: TCustomForm);
var
  dia: TFRpPageSetupVCL;
begin
  dia := AForm as TFRpPageSetupVCL;
  CheckFitsSmallScreen(dia);
  if FPageOpenPrinters then
  begin
    Expect(TFRpPrinterConfigLCL, PrinterConfigCancel);
    dia.BConfigureClick(dia.BConfigure);
  end;
  if not FPageOnlyFiles then
  begin
    dia.textDocAuthor.Text := FPageAuthor;
    dia.textDocTitle.Text := 'Designer title';
    dia.ComboBoxPDFConformance.ItemIndex := 1;
    dia.CheckBoxPDFCompressed.Checked := not dia.CheckBoxPDFCompressed.Checked;
    dia.TextXMPContent.Text := '<x:xmpmeta xmlns:x="adobe:ns:meta/">' + LineEnding + '</x:xmpmeta>';
  end;
  if FPageDeleteFirst then
    dia.DeleteEmbeddedFile(0);
  if FPageModifyFirst then
  begin
    Expect(TFRpEmbeddedFileLCL, EmbeddedAccept);
    Check(dia.ModifyEmbeddedFile(0), 'Page setup: modify the first embedded file');
  end;
  if FPageAddFile then
  begin
    // A modal dialog inside the modal page setup
    Expect(TFRpEmbeddedFileLCL, EmbeddedAccept);
    Check(dia.AddEmbeddedFile(FDataFile), 'Page setup: add an embedded file');
  end;
  if FPageAccept then
    dia.BOKClick(dia.BOK)
  else
    dia.BCancelClick(dia.BCancel);
end;

procedure TPageSetupTests.SysInfoAction(AForm: TCustomForm);
var
  dia: TFRpSysInfoLCL;
begin
  dia := AForm as TFRpSysInfoLCL;
  CheckFitsSmallScreen(dia);
  LogMsg('SysInfo: OS "' + dia.EOS.Text + '", version "' + dia.EVersion.Text +
    '", processors ' + dia.EProcessors.Text + ', display "' + dia.EDisplay.Text +
    '", widgetset ' + dia.EWidgetset.Text + ', OEM/arch "' + dia.EOEMID.Text + '"');
  LogMsg('SysInfo: printer "' + dia.EPrinterName.Text + '", status "' + dia.EStatus.Text +
    '", driver "' + dia.EDriver.Text + '", port "' + dia.EPort.Text + '", resolution "' +
    dia.EResolution.Text + '", paper "' + dia.EFormName.Text + '" ' + dia.EPageSize.Text +
    ', sources ' + IntToStr(dia.ComboSource.Items.Count) + ', copies ' + dia.EMaxCopies.Text +
    ', duplex ' + dia.EDuplex.Text + ', type ' + dia.EPrinterType.Text);
  Check(dia.EOS.Text <> '', 'SysInfo: operating system');
  Check(dia.EVersion.Text <> '', 'SysInfo: version');
  Check(StrToIntDef(dia.EProcessors.Text, 0) >= 1, 'SysInfo: processors');
{$IFDEF MSWINDOWS}
  CheckStr(IntToStr(GetCPUCount), dia.EProcessors.Text, 'SysInfo: processors (Windows)');
{$ENDIF}
  Check(Pos(' x ', dia.EDisplay.Text) > 0, 'SysInfo: display size');
  Check(dia.EWidgetset.Text <> '', 'SysInfo: widgetset');
  CheckInt(4, dia.ComboSeparators.Items.Count, 'SysInfo: separators');
  Check(Pos(DefaultFormatSettings.DecimalSeparator, dia.ComboSeparators.Items[2]) > 0,
    'SysInfo: decimal separator');
  if InstalledPrinterCount > 0 then
  begin
    Check(dia.EPrinterName.Text <> '', 'SysInfo: printer name');
    Check(dia.EStatus.Text <> '', 'SysInfo: printer status');
    Check(dia.EResolution.Text <> '', 'SysInfo: printer resolution');
{$IFDEF MSWINDOWS}
    Check(dia.EDriver.Text <> '', 'SysInfo: printer driver (WinSpool)');
    Check(dia.ETechnology.Text <> '', 'SysInfo: printer technology (device caps)');
    Check(dia.CTextCaps.Items.Count > 0, 'SysInfo: text capabilities');
{$ENDIF}
  end
  else
    LogMsg('SysInfo: no printer installed');
  FSysInfoChecked := True;
  dia.BOK.Click;
end;

{ Embedded files of a report as text (to compare them) and mime types }

function FilesText(ARep: TRpBaseReport): string;
var
  i: Integer;
begin
  Result := IntToStr(Length(ARep.EmbeddedFiles));
  for i := 0 to Length(ARep.EmbeddedFiles) - 1 do
    Result := Result + '|' + ARep.EmbeddedFiles[i].FileName + ';' +
      ARep.EmbeddedFiles[i].Description + ';' +
      IntToStr(Ord(ARep.EmbeddedFiles[i].AFRelationShip)) + ';' +
      StreamText(ARep.EmbeddedFiles[i].Stream);
end;

procedure TPageSetupTests.TestUndoValue;
begin
  LogMsg('Phase 8: mime types of the embedded files');
  Check(RpMimeTypeFromFileName('INVOICE.XML') = 'application/xml', 'mime of an XML file');
  Check(RpMimeTypeFromFileName('a.jpg') = 'image/jpeg', 'mime of a JPEG file');
  Check(RpMimeTypeFromFileName('a.png') = 'image/png', 'mime of a PNG file');
  Check(RpMimeTypeFromFileName('a.zzz') = 'application/octet-stream', 'mime of other files');
  LogMsg('Mime types verified');
end;

{ Embedded file dialog }

procedure TPageSetupTests.TestEmbeddedFileDialog;
var
  efile: TEmbeddedFile;
begin
  LogMsg('Phase 8: embedded file dialog (AskEmbeddedFileData)');
  efile := NewEmbeddedFile('old.xml', 'application/xml', 'Old', 'x');
  try
    FEmbDescription := 'New description';
    FEmbFileName := 'new.xml';
    FEmbRelation := Ord(PDF_AF_Data);
    Expect(TFRpEmbeddedFileLCL, EmbeddedAccept);
    Check(AskEmbeddedFileData(efile), 'OK returns True');
    CheckAllHandled('Embedded file dialog');
    CheckStr('New description', efile.Description, 'description');
    CheckStr('new.xml', efile.FileName, 'file name');
    Check(efile.AFRelationShip = PDF_AF_Data, 'relationship');
    CheckStr('2026-09-01T08:00:00Z', efile.CreationDate, 'creation date');
    CheckStr('2026-09-02T09:00:00Z', efile.ModificationDate, 'modification date');
    CheckStr('x', StreamText(efile.Stream), 'the content does not change');
    Expect(TFRpEmbeddedFileLCL, EmbeddedCancel);
    Check(not AskEmbeddedFileData(efile), 'Cancel returns False');
    CheckAllHandled('Embedded file dialog (cancel)');
    CheckStr('New description', efile.Description, 'Cancel keeps the description');
  finally
    efile.Free;
  end;
  LogMsg('Embedded file dialog verified');
end;

{ Page setup dialog (not modal: its methods are called directly) }

procedure TPageSetupTests.TestPageSetupDialog;
var
  rep, rep2: TRpReport;
  dia: TFRpPageSetupVCL;
  value: string;

  procedure EditAll(ADia: TFRpPageSetupVCL);
  begin
    ADia.textDocAuthor.Text := 'Autor ' + #$C3#$B1;
    ADia.textDocTitle.Text := 'Title';
    ADia.textDocSubject.Text := 'Subject';
    ADia.textDocKeywords.Text := 'k1, k2';
    ADia.textDocCreator.Text := 'Creator';
    ADia.textDocProducer.Text := 'Producer';
    ADia.textDocCreationDate.Text := 'D:20260928100000';
    ADia.textDocModDate.Text := 'D:20260928110000';
    ADia.TextXMPContent.Text := '<x:xmpmeta>' + LineEnding + '</x:xmpmeta>';
    ADia.ComboBoxPDFConformance.ItemIndex := 1;
    ADia.CheckBoxPDFCompressed.Checked := False;
    // Modify the existing file, add a new one and cancel another addition
    FEmbDescription := 'Modified';
    FEmbFileName := '';
    FEmbRelation := Ord(PDF_AF_Alternative);
    Expect(TFRpEmbeddedFileLCL, EmbeddedAccept);
    Check(ADia.ModifyEmbeddedFile(0), 'modify the embedded file');
    CheckStr('Modified', ADia.ListViewEmbedded.Items[0].SubItems[3], 'list shows the new description');
    FEmbDescription := 'Invoice data';
    FEmbRelation := Ord(PDF_AF_Data);
    Expect(TFRpEmbeddedFileLCL, EmbeddedAccept);
    Check(ADia.AddEmbeddedFile(FDataFile), 'add an embedded file');
    Expect(TFRpEmbeddedFileLCL, EmbeddedCancel);
    Check(not ADia.AddEmbeddedFile(FDataFile), 'cancelled addition');
    CheckAllHandled('Page setup embedded files');
    CheckInt(2, ADia.EmbeddedFileCount, 'dialog files');
    CheckInt(2, ADia.ListViewEmbedded.Items.Count, 'list items');
    CheckStr('factur-x.xml', ADia.ListViewEmbedded.Items[1].Caption, 'list file name');
    CheckStr('application/xml', ADia.ListViewEmbedded.Items[1].SubItems[0], 'list mime type');
    CheckStr('Data', ADia.ListViewEmbedded.Items[1].SubItems[2], 'list relationship');
  end;

begin
  LogMsg('Phase 8: page setup dialog (PDF options, metadata, embedded files)');
  rep := NewTestReport;
  try
    rep.DocAuthor := 'A0';
    rep.PDFConformance := PDF_1_4;
    rep.PDFCompressed := True;
    AddReportFile(rep, NewEmbeddedFile('first.txt', 'text/plain', 'First', 'first content'));
    value := FilesText(rep);

    // The dialog shows the report
    dia := TFRpPageSetupVCL.Create(nil);
    try
      dia.Report := rep;
      CheckStr('A0', dia.textDocAuthor.Text, 'author shown');
      CheckInt(0, dia.ComboBoxPDFConformance.ItemIndex, 'PDF 1.4 shown');
      Check(dia.CheckBoxPDFCompressed.Checked, 'compressed shown');
      CheckInt(1, dia.EmbeddedFileCount, 'embedded files shown');
      CheckStr('first.txt', dia.ListViewEmbedded.Items[0].Caption, 'embedded file in the list');
      CheckInt(4, dia.PControl.PageCount, 'page setup tabs');
      Check(dia.EmbeddedFiles[0] <> rep.EmbeddedFiles[0], 'the dialog works on copies');
      // Cancel: nothing changes
      EditAll(dia);
      CheckStr(value, FilesText(rep), 'the report keeps its files until OK');
      CheckStr('A0', rep.DocAuthor, 'the report keeps its author until OK');
      dia.BCancelClick(dia.BCancel);
      Check(not dia.Accepted, 'Cancel does not accept');
    finally
      dia.Free;
    end;
    CheckStr(value, FilesText(rep), 'Cancel: embedded files unchanged');
    CheckStr('A0', rep.DocAuthor, 'Cancel: author unchanged');
    Check(rep.PDFConformance = PDF_1_4, 'Cancel: conformance unchanged');
    Check(rep.PDFCompressed, 'Cancel: compression unchanged');

    // OK: everything is applied
    dia := TFRpPageSetupVCL.Create(nil);
    try
      dia.Report := rep;
      EditAll(dia);
      dia.BOKClick(dia.BOK);
      Check(dia.Accepted, 'OK accepts');
    finally
      dia.Free;
    end;
    CheckStr('Autor ' + #$C3#$B1, rep.DocAuthor, 'OK: author');
    CheckStr('Title', rep.DocTitle, 'OK: title');
    CheckStr('Subject', rep.DocSubject, 'OK: subject');
    CheckStr('k1, k2', rep.DocKeywords, 'OK: keywords');
    CheckStr('Creator', rep.DocCreator, 'OK: creator');
    CheckStr('Producer', rep.DocProducer, 'OK: producer');
    CheckStr('D:20260928100000', rep.DocCreationDate, 'OK: creation date');
    CheckStr('D:20260928110000', rep.DocModificationDate, 'OK: modification date');
    Check(Pos('</x:xmpmeta>', rep.DocXMPContent) > 0, 'OK: XMP content');
    Check(rep.PDFConformance = PDF_A_3, 'OK: PDF/A-3');
    Check(not rep.PDFCompressed, 'OK: not compressed');
    CheckInt(2, Length(rep.EmbeddedFiles), 'OK: embedded files');
    CheckStr('Modified', rep.EmbeddedFiles[0].Description, 'OK: modified file');
    Check(rep.EmbeddedFiles[0].AFRelationShip = PDF_AF_Alternative, 'OK: modified relationship');
    CheckStr('first content', StreamText(rep.EmbeddedFiles[0].Stream), 'OK: first content');
    CheckStr('factur-x.xml', rep.EmbeddedFiles[1].FileName, 'OK: added file name');
    CheckStr('application/xml', rep.EmbeddedFiles[1].MimeType, 'OK: added mime type');
    CheckStr('Invoice data', rep.EmbeddedFiles[1].Description, 'OK: added description');
    Check(StreamText(rep.EmbeddedFiles[1].Stream) = FDataContent, 'OK: added content');

    // Delete: only on OK
    dia := TFRpPageSetupVCL.Create(nil);
    try
      dia.Report := rep;
      dia.DeleteEmbeddedFile(0);
      CheckInt(1, dia.EmbeddedFileCount, 'deleted in the dialog');
      CheckInt(2, Length(rep.EmbeddedFiles), 'not deleted from the report before OK');
      dia.BOKClick(dia.BOK);
    finally
      dia.Free;
    end;
    CheckInt(1, Length(rep.EmbeddedFiles), 'OK: file deleted');
    CheckStr('factur-x.xml', rep.EmbeddedFiles[0].FileName, 'OK: the other file is kept');

    // Saved and loaded with the report (XML and text formats)
    rep2 := SaveAndLoad(rep, rpStreamXML);
    try
      CheckInt(1, Length(rep2.EmbeddedFiles), 'XML: embedded files');
      Check(StreamText(rep2.EmbeddedFiles[0].Stream) = FDataContent, 'XML: content');
      CheckStr('Invoice data', rep2.EmbeddedFiles[0].Description, 'XML: description');
      CheckStr('Autor ' + #$C3#$B1, rep2.DocAuthor, 'XML: author');
      Check(rep2.PDFConformance = PDF_A_3, 'XML: conformance');
      Check(not rep2.PDFCompressed, 'XML: compression');
      Check(Pos('</x:xmpmeta>', rep2.DocXMPContent) > 0, 'XML: XMP');
    finally
      rep2.Free;
    end;
    rep2 := SaveAndLoad(rep, rpStreamBinary);
    try
      CheckInt(1, Length(rep2.EmbeddedFiles), 'binary: embedded files');
      Check(StreamText(rep2.EmbeddedFiles[0].Stream) = FDataContent, 'binary: content');
      CheckStr('Autor ' + #$C3#$B1, rep2.DocAuthor, 'binary: author');
      Check(rep2.PDFConformance = PDF_A_3, 'binary: conformance');
    finally
      rep2.Free;
    end;
    // Text format (the default). Known FPC issue, not of the page setup: the
    // text format writes the UTF-8 bytes of the string (AnsiString)
    // properties as #nnn codes and reads them back as characters, so "ñ"
    // comes back as "Ã±" (the XML and binary formats keep it). ASCII here.
    rep.DocAuthor := 'Text author';
    rep2 := SaveAndLoad(rep, rpStreamText);
    try
      CheckInt(1, Length(rep2.EmbeddedFiles), 'text: embedded files');
      Check(StreamText(rep2.EmbeddedFiles[0].Stream) = FDataContent, 'text: content');
      CheckStr('Invoice data', rep2.EmbeddedFiles[0].Description, 'text: description');
      CheckStr('Text author', rep2.DocAuthor, 'text: author');
      Check(rep2.PDFConformance = PDF_A_3, 'text: conformance');
    finally
      rep2.Free;
    end;

    // Configure printers button (modal printer configuration, cancelled)
    dia := TFRpPageSetupVCL.Create(nil);
    try
      dia.Report := rep;
      FPrintConfigChecked := False;
      Expect(TFRpPrinterConfigLCL, PrinterConfigCancel);
      dia.BConfigureClick(dia.BConfigure);
      CheckAllHandled('Configure printers');
      Check(FPrintConfigChecked, 'the printer configuration was shown');
    finally
      dia.Free;
    end;
  finally
    rep.Free;
  end;
  LogMsg('Page setup dialog verified');
end;

{ Page setup in the designer: modal dialog, undo, redo, save and load }

procedure TPageSetupTests.TestPageSetupInDesigner;
var
  oldConfig: string;
begin
  LogMsg('Phase 8: page setup in the designer (undo, redo, save and load)');
  // The designer windows of this test start with the AI panel hidden: no
  // Hub worker is left running when the test program ends right after
  oldConfig := RpDesignerLCLConfigFile;
  RpDesignerLCLConfigFile := IncludeTrailingPathDelimiter(FTempDir) + 'designer.ini';
  WriteBytes(RpDesignerLCLConfigFile, '[Preferences]' + LineEnding + 'ShowAIChat=0' + LineEnding);
  try
    DesignerPageSetupSteps;
  finally
    DeleteFile(RpDesignerLCLConfigFile);
    RpDesignerLCLConfigFile := oldConfig;
  end;
  LogMsg('Page setup in the designer verified');
end;

procedure TPageSetupTests.DesignerPageSetupSteps;
var
  mf: TFRpMainFLCL;
  cue: TUndoCue;
  tmp, filesAfter: string;
  opCount: Integer;
  op: TChangeObjectOperation;
  i: Integer;
  hasFiles, hasAuthor: Boolean;
begin
  tmp := IncludeTrailingPathDelimiter(FTempDir) + 'pagesetup_test.rep';
  mf := TFRpMainFLCL.Create(nil);
  try
    Check(not mf.ShowAIChat, 'designer without the AI panel');
    mf.NewReport;
    cue := TUndoCue(mf.Report.UndoCue);
    Check(not mf.Report.Modified, 'new report unmodified');
    opCount := cue.UndoOperations.Count;

    // Cancel: no change, nothing recorded
    FPageAuthor := 'Cancelled author';
    FPageAddFile := True;
    FPageDeleteFirst := False;
    FPageModifyFirst := False;
    FPageAccept := False;
    FPageOpenPrinters := False;
    FEmbDescription := 'Cancelled file';
    FEmbFileName := '';
    FEmbRelation := Ord(PDF_AF_Data);
    Expect(TFRpPageSetupVCL, PageSetupAction);
    mf.BtnPageSetup.Click;
    CheckAllHandled('Page setup cancelled');
    CheckInt(opCount, cue.UndoOperations.Count, 'Cancel records nothing');
    CheckStr('', mf.Report.DocAuthor, 'Cancel: author unchanged');
    CheckInt(0, Length(mf.Report.EmbeddedFiles), 'Cancel: no embedded file');
    Check(not mf.Report.Modified, 'Cancel: report unmodified');

    // OK: one operation with the metadata and PDF options; the embedded
    // files are not in the history (the Delphi and C# undo engines do not
    // know them), they mark the report modified
    FPageAuthor := 'Designer author';
    FPageAccept := True;
    FPageOpenPrinters := True;
    FEmbDescription := 'Invoice data';
    Expect(TFRpPageSetupVCL, PageSetupAction);
    mf.BtnPageSetup.Click;
    CheckAllHandled('Page setup accepted');
    CheckInt(opCount + 1, cue.UndoOperations.Count, 'OK records one operation');
    op := cue.UndoOperations[cue.UndoOperations.Count - 1];
    CheckStr('REPORT', op.componentName, 'operation on the report');
    hasFiles := False;
    hasAuthor := False;
    for i := 0 to op.properties.Count - 1 do
    begin
      if SameText(op.properties[i].propertyName, 'embeddedFiles') then
        hasFiles := True;
      if op.properties[i].propertyName = 'DocAuthor' then
        hasAuthor := True;
    end;
    Check(not hasFiles, 'the embedded files are not in the operation');
    Check(hasAuthor, 'the operation records the author');
    Check(mf.Report.Modified, 'OK: report modified');
    CheckStr('Designer author', mf.Report.DocAuthor, 'OK: author');
    CheckStr('Designer title', mf.Report.DocTitle, 'OK: title');
    Check(mf.Report.PDFConformance = PDF_A_3, 'OK: conformance');
    CheckInt(1, Length(mf.Report.EmbeddedFiles), 'OK: embedded file');
    Check(StreamText(mf.Report.EmbeddedFiles[0].Stream) = FDataContent, 'OK: embedded content');
    filesAfter := FilesText(mf.Report);

    // Undo and redo
    mf.DoUndo;
    CheckStr('', mf.Report.DocAuthor, 'undo: author');
    CheckStr('', mf.Report.DocTitle, 'undo: title');
    Check(mf.Report.PDFConformance = PDF_1_4, 'undo: conformance');
    CheckStr(filesAfter, FilesText(mf.Report), 'undo keeps the embedded files');
    Check(mf.Report.Modified, 'undo: still modified (the embedded file)');
    mf.DoRedo;
    CheckStr('Designer author', mf.Report.DocAuthor, 'redo: author');
    Check(mf.Report.PDFConformance = PDF_A_3, 'redo: conformance');
    CheckStr(filesAfter, FilesText(mf.Report), 'redo: embedded files');
    Check(mf.Report.Modified, 'redo: modified');

    // Only the embedded files change: not recorded, modified
    TUndoCue(mf.Report.UndoCue).MarkClean;
    FPageOnlyFiles := True;
    FPageAuthor := 'Designer author';
    FPageAddFile := False;
    FPageModifyFirst := True;
    FPageOpenPrinters := False;
    FEmbDescription := 'Only the description';
    FEmbRelation := Ord(PDF_AF_Supplement);
    Expect(TFRpPageSetupVCL, PageSetupAction);
    mf.BtnPageSetup.Click;
    CheckAllHandled('Page setup, embedded file modified');
    CheckInt(opCount + 1, cue.UndoOperations.Count, 'embedded file change not recorded');
    CheckStr('Only the description', mf.Report.EmbeddedFiles[0].Description,
      'modified description applied');
    Check(mf.Report.Modified, 'embedded file change: report modified');
    FPageOnlyFiles := False;

    // Saved as XML: the files and the history go with the report
    mf.Report.StreamFormat := rpStreamXML;
    mf.SaveReportFile(tmp);
    Check(not mf.Report.Modified, 'saved: unmodified');
    mf.OpenReportFile(tmp);
    cue := TUndoCue(mf.Report.UndoCue);
    CheckInt(opCount + 1, cue.UndoOperations.Count, 'history loaded with the report');
    CheckInt(1, Length(mf.Report.EmbeddedFiles), 'loaded: embedded file');
    Check(StreamText(mf.Report.EmbeddedFiles[0].Stream) = FDataContent, 'loaded: content');
    CheckStr('Only the description', mf.Report.EmbeddedFiles[0].Description, 'loaded: description');
    CheckStr('Designer author', mf.Report.DocAuthor, 'loaded: author');
    mf.DoUndo;
    CheckStr('', mf.Report.DocAuthor, 'loaded history: undo of the author');
    CheckStr('Only the description', mf.Report.EmbeddedFiles[0].Description,
      'loaded history: the embedded file stays');
    mf.DoRedo;
    CheckStr('Designer author', mf.Report.DocAuthor, 'loaded history: redo');

    // Delete through the page setup
    FPageModifyFirst := False;
    FPageDeleteFirst := True;
    Expect(TFRpPageSetupVCL, PageSetupAction);
    mf.BtnPageSetup.Click;
    CheckAllHandled('Page setup, embedded file deleted');
    CheckInt(0, Length(mf.Report.EmbeddedFiles), 'delete applied');
    Check(mf.Report.Modified, 'delete: report modified');
    // No save question for the next report
    TUndoCue(mf.Report.UndoCue).MarkClean;
  finally
    mf.Free;
    DeleteFile(tmp);
  end;
end;

{ Printer configuration: the values round trip with rptypes }

procedure TPageSetupTests.RestoreUserConfig;
begin
  if FHadUserConfig then
    WriteBytes(FUserConfigFile, FUserConfigBytes)
  else
    DeleteFile(FUserConfigFile);
  ReloadPrinterConfig;
end;

procedure TPageSetupTests.TestPrinterConfig;
const
  TEST_PRINTER = pRpPrinter50;
var
  dia: TFRpPrinterConfigLCL;
  userFile, systemFile, printerName: string;
  hadUserFile: Boolean;
  saved: RawByteString;
  offset: TPoint;
  idx: Integer;
begin
  LogMsg('Phase 8: printer configuration (round trip with rptypes)');
  systemFile := Obtainininamecommonconfig('', '', 'reportman');
  userFile := Obtainininamelocalconfig('', '', 'reportman');
  LogMsg('Printer configuration: system file ' + systemFile + ', user file ' + userFile +
    ', engine reads ' + RpPrinterConfigFileName);
  if FileExists(systemFile) then
  begin
    LogMsg('SKIP: a system printer configuration exists, the engine would not read the user file');
    Exit;
  end;
  hadUserFile := FileExists(userFile);
  FUserConfigFile := userFile;
  FHadUserConfig := hadUserFile;
  FUserConfigBytes := '';
  if hadUserFile then
    FUserConfigBytes := ReadBytes(userFile);
  FailCleanup := RestoreUserConfig;
  try
    dia := TFRpPrinterConfigLCL.Create(nil);
    try
      CheckInt(68, dia.LSelPrinter.Items.Count, 'logical printers');
      Check(dia.RadioUser.Checked, 'user configuration without a system file');
      CheckStr(userFile, dia.EConfigFile.Text, 'user configuration file');
      dia.SelectLogicalPrinter(Ord(TEST_PRINTER));
      if not hadUserFile then
        Check(not dia.ConfigIniFile.ValueExists('PrinterOffsetX', 'Printer' +
          IntToStr(Ord(TEST_PRINTER))), 'showing a printer writes nothing');
      printerName := '';
      if dia.ComboPrinters.Items.Count > 1 then
      begin
        dia.ComboPrinters.ItemIndex := 1;
        dia.ComboPrintersChange(dia.ComboPrinters);
        printerName := dia.ComboPrinters.Items[1];
      end;
      dia.ELeftMargin.Text := gettextfromtwips(720);
      dia.ETopMargin.Text := gettextfromtwips(1440);
      dia.CheckPrinterFonts.Checked := True;
      dia.CheckCutPaper.Checked := True;
      dia.ECutPaper.Text := '#27#105';
      dia.CheckOpenDrawer.Checked := True;
      dia.EOpenDrawer.Text := '#27#112#48#40#200#4';
      idx := dia.ComboTextOnly.Items.IndexOf('EPSON');
      Check(idx > 0, 'EPSON text driver listed');
      dia.ComboTextOnly.ItemIndex := idx;
      dia.ComboTextOnlyChange(dia.ComboTextOnly);
      dia.CheckOem.Checked := False;
      // Another printer and back: the values are kept
      dia.SelectLogicalPrinter(1);
      if not hadUserFile then
        Check(not dia.ConfigIniFile.ValueExists('PrinterOffsetX', 'Printer1'),
          'showing another printer writes nothing');
      dia.SelectLogicalPrinter(Ord(TEST_PRINTER));
      CheckStr(gettextfromtwips(720), dia.ELeftMargin.Text, 'left offset shown again');
      Check(dia.CheckCutPaper.Checked, 'cut paper shown again');
      CheckStr('EPSON', dia.ComboTextOnly.Text, 'text driver shown again');
      Check(not dia.CheckOem.Checked, 'OEM conversion shown again');
      dia.BOKClick(dia.BOK);
    finally
      dia.Free;
    end;
    Check(FileExists(userFile), 'the user configuration file was written');
    // rptypes reads the saved values (ReloadPrinterConfig after the save)
    offset := GetPrinterOffset(TEST_PRINTER);
    Check(Abs(offset.X - 720) <= 1, Format('engine left offset %d', [offset.X]));
    Check(Abs(offset.Y - 1440) <= 1, Format('engine top offset %d', [offset.Y]));
    Check(GetDeviceFontsOption(TEST_PRINTER), 'engine printer fonts');
    Check(PrinterRawOpEnabled(TEST_PRINTER, rawopcutpaper), 'engine cut paper enabled');
    CheckStr(#27'i', GetPrinterRawOp(TEST_PRINTER, rawopcutpaper), 'engine cut paper codes');
    Check(PrinterRawOpEnabled(TEST_PRINTER, rawopopendrawer), 'engine open drawer enabled');
    CheckStr(#27#112#48#40#200#4, GetPrinterRawOp(TEST_PRINTER, rawopopendrawer),
      'engine open drawer codes');
    CheckStr('EPSON', GetPrinterEscapeStyleDriver(TEST_PRINTER), 'engine text driver');
    Check(GetPrinterEscapeStyleOption(TEST_PRINTER) = rpPrinterDatabase, 'engine escape style');
    Check(not GetPrinterEscapeOem(TEST_PRINTER), 'engine OEM conversion');
    CheckStr(printerName, GetPrinterConfigName(TEST_PRINTER), 'engine physical printer');
    // Other printers keep the defaults
    offset := GetPrinterOffset(pRpUserPrinter9);
    Check((offset.X = 0) or hadUserFile, 'other printers keep their offset');

    // Shown again from the file
    dia := TFRpPrinterConfigLCL.Create(nil);
    try
      dia.SelectLogicalPrinter(Ord(TEST_PRINTER));
      CheckStr(gettextfromtwips(1440), dia.ETopMargin.Text, 'top offset read from the file');
      Check(dia.CheckPrinterFonts.Checked, 'printer fonts read from the file');
      CheckStr('#27#105', dia.ECutPaper.Text, 'cut paper read from the file');
      if printerName <> '' then
        CheckStr(printerName, dia.ComboPrinters.Text, 'physical printer read from the file');
      // Changed and not accepted: the file does not change
      saved := ReadBytes(userFile);
      dia.ELeftMargin.Text := gettextfromtwips(2880);
    finally
      dia.Free;
    end;
    Check(ReadBytes(userFile) = saved, 'Cancel: the configuration file does not change');
    ReloadPrinterConfig;
    offset := GetPrinterOffset(TEST_PRINTER);
    Check(Abs(offset.X - 720) <= 1, 'Cancel: the engine keeps the saved offset');
  finally
    // The configuration of the user is restored
    FailCleanup := nil;
    RestoreUserConfig;
  end;
  offset := GetPrinterOffset(TEST_PRINTER);
  Check(hadUserFile or (offset.X = 0), 'configuration restored');
  LogMsg('Printer configuration verified');
end;

{ System information }

procedure TPageSetupTests.TestSysInfo;
begin
  LogMsg('Phase 8: system information dialog (ShowSysInfo)');
  FSysInfoChecked := False;
  Expect(TFRpSysInfoLCL, SysInfoAction);
  ShowSysInfo;
  CheckAllHandled('ShowSysInfo');
  Check(FSysInfoChecked, 'the system information was shown');
  LogMsg('System information dialog verified');
end;

procedure TPageSetupTests.Run;
begin
  TestUndoValue;
  TestEmbeddedFileDialog;
  TestPageSetupDialog;
  TestPageSetupInDesigner;
  TestPrinterConfig;
  TestSysInfo;
  CheckAllHandled('Page setup tests');
  LogMsg(Format('Phase 8 page setup tests: %d dialogs answered', [FHandled]));
end;

procedure RunPageSetupTests;
var
  t: TPageSetupTests;
begin
  LogMsg('Testing Phase 8: page setup, printer configuration and system information');
  t := TPageSetupTests.Create;
  try
    t.Run;
  finally
    t.Free;
  end;
  LogMsg('Phase 8 page setup tests completed successfully');
end;

end.
