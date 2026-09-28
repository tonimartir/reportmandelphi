unit udialoglayouttests;

{ Layout of the dialogs of the LCL designer and preview: every page of each
  dialog as the user opens it, with no control cut by the client area of its
  parent nor covering another one, and the dialog inside an 800x600 screen
  (the positions of several lfm files were made for other fonts: see
  rppagesetuplcl). The dialogs are opened with their public functions; a
  form visibility handler, called before the modal guard of
  uregressiontests, checks them inside their modal loop (while they are
  being shown the LCL has not laid them out) and cancels them. All the
  problems are listed before failing. LclDesignerTest --layout runs only
  these tests.

  RP_LAYOUT_SHOTS=<dir> saves a screenshot of each page;
  RP_LAYOUT_CASES=<case>,<case> checks only those dialogs (Designer measures
  the designer). The log gives the size of each dialog and of the parts of
  the designer: from a run at 96 ppi to one at 144 (Xvfb -dpi 144) they grow
  1.5 times, and 2.25 times the parts the LCL scaled twice (see
  rplcllayout.RpBuiltInScreenPixels). }

{$mode delphi}

interface

uses
  Forms;

procedure RunDialogLayoutTests;
// The problems of the layout of a shown form (its active pages), empty
// when there are none
function DialogLayoutProblems(AForm: TCustomForm): string;

implementation

uses
  {$IFDEF MSWINDOWS}Windows,{$ENDIF}
  Classes, SysUtils, Types, Variants, Controls, Graphics, StdCtrls,
  ExtCtrls, ComCtrls, DB, memds,
  rptypes, rpreport, rpparams, rpdatainfo, rpbasereport,
  rpgraphutilslcl, rplcldriver, rpmdprintconfiglcl, rpmdfembeddedfilelcl,
  rppagesetuplcl, rprflclparams,
  rpmdfdinfolcl, rpmdfparamslcl, rpexpredlglcl, rpmdfgridlcl, rpmdfextseclcl,
  rpmdfwizardlcl, rpmdfopenliblcl, rpdbxconfiglcl, rpeditconnlcl,
  rpmdfdatatextlcl, rpfrmloginlcl, rpfrmaireportlcl, rpmdfaboutlcl,
  rpmdsysinfolcl, rpmdfmainlcl, rpmdundocuelcl, rpmdfnewreportwizardlcl,
  rpmdfsampledatalcl,
  umainform, uregressiontests;

const
  // uregressiontests (TModalGuard) ignores the modal forms with this tag
  GUARD_HANDLED_TAG = $5EC7;

type
  TOpenProc = procedure;

  TDialogLayoutTests = class
  private
    FIssues: TStringList;
    FCase: string;
    FShown: Integer;
    FShotsDir: string;
    FShotCount: Integer;
    procedure Issue(const AText: string);
    procedure FormVisibleChanged(Sender: TObject; Form: TCustomForm);
    procedure InspectAsync(Data: PtrInt);
    procedure CloseTimer(Sender: TObject);
    procedure Inspect(AForm: TCustomForm);
    procedure CheckControls(AParent: TWinControl; const APath: string);
    procedure Shot(AForm: TCustomForm; const AName: string);
    procedure Open(const ACase: string; AOpen: TOpenProc);
    procedure MeasureDesigner;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
  end;

var
  Tests: TDialogLayoutTests;
  // Report of the cases
  CaseReport: TRpReport;

procedure Pump;
var
  i: Integer;
begin
  for i := 1 to 10 do
  begin
    Application.ProcessMessages;
    Sleep(10);
  end;
end;

{ TDialogLayoutTests }

constructor TDialogLayoutTests.Create;
begin
  inherited Create;
  FIssues := TStringList.Create;
  FIssues.Sorted := True;
  FIssues.Duplicates := dupIgnore;
  FShotsDir := GetEnvironmentVariable('RP_LAYOUT_SHOTS');
  if FShotsDir <> '' then
    FShotsDir := IncludeTrailingPathDelimiter(FShotsDir);
  Screen.AddHandlerFormVisibleChanged(FormVisibleChanged, False);
end;

destructor TDialogLayoutTests.Destroy;
begin
  Screen.RemoveHandlerFormVisibleChanged(FormVisibleChanged);
  FIssues.Free;
  inherited Destroy;
end;

procedure TDialogLayoutTests.Issue(const AText: string);
begin
  FIssues.Add(FCase + ': ' + AText);
end;

procedure TDialogLayoutTests.Shot(AForm: TCustomForm; const AName: string);
var
  LBitmap: TBitmap;
  LPng: TPortableNetworkGraphic;
  R: TRect;
begin
  if FShotsDir = '' then
    Exit;
  LBitmap := TBitmap.Create;
  LPng := TPortableNetworkGraphic.Create;
  try
    R := Rect(0, 0, AForm.Width, AForm.Height);
{$IFDEF MSWINDOWS}
    GetWindowRect(AForm.Handle, R);
    R := Rect(0, 0, R.Right - R.Left, R.Bottom - R.Top);
{$ENDIF}
    LBitmap.SetSize(R.Right, R.Bottom);
    LBitmap.Canvas.Brush.Color := clWhite;
    LBitmap.Canvas.FillRect(R);
    // On win32 PaintTo leaves out the labels of some pages (they are there)
    AForm.PaintTo(LBitmap.Canvas, 0, 0);
    LPng.Assign(LBitmap);
    ForceDirectories(FShotsDir);
    Inc(FShotCount);
    LPng.SaveToFile(FShotsDir + Format('%.2d_%s.png', [FShotCount, AName]));
  finally
    LPng.Free;
    LBitmap.Free;
  end;
end;

// No visible control is cut by the client area of its parent nor covers a
// sibling. Only the active page of a page control is laid out; the LCL
// places the contents of radio groups, lists, grids and combo boxes, and a
// scroll box scrolls its contents.
procedure CollectLayoutProblems(AParent: TWinControl; const APath: string;
  AIssues: TStrings);
var
  i, j: Integer;
  c, d: TControl;
  r, x: TRect;
begin
  if AParent is TPageControl then
  begin
    if Assigned(TPageControl(AParent).ActivePage) then
      CollectLayoutProblems(TPageControl(AParent).ActivePage,
        APath + '.' + TPageControl(AParent).ActivePage.Name, AIssues);
    Exit;
  end;
  r := AParent.ClientRect;
  x := Rect(0, 0, 0, 0);
  for i := 0 to AParent.ControlCount - 1 do
  begin
    c := AParent.Controls[i];
    if not c.Visible or (c.Width <= 0) or (c.Height <= 0) then
      Continue;
    if not (AParent is TScrollBox) and ((c.Left < 0) or (c.Top < 0) or
      (c.Left + c.Width > r.Right) or (c.Top + c.Height > r.Bottom)) then
      AIssues.Add(Format('%s.%s (%d,%d %dx%d) does not fit in %dx%d', [APath, c.Name,
        c.Left, c.Top, c.Width, c.Height, r.Right, r.Bottom]));
    for j := i + 1 to AParent.ControlCount - 1 do
    begin
      d := AParent.Controls[j];
      // Up to 2 pixels do not show (the box of a label over the editor below
      // it with the bigger labels of GTK2)
      if d.Visible and (d.Width > 0) and (d.Height > 0) and
        IntersectRect(x, c.BoundsRect, d.BoundsRect) and
        (x.Right - x.Left > 2) and (x.Bottom - x.Top > 2) then
        AIssues.Add(Format('%s: %s (%d,%d %dx%d) and %s (%d,%d %dx%d) overlap', [APath,
          c.Name, c.Left, c.Top, c.Width, c.Height, d.Name, d.Left, d.Top,
          d.Width, d.Height]));
    end;
    if (c is TWinControl) and not (c is TCustomRadioGroup) and
      not (c is TCustomCheckGroup) and not (c is TCustomListView) and
      not (c is TCustomTreeView) and not (c is TCustomComboBox) and
      not (c is TCustomMemo) then
      CollectLayoutProblems(TWinControl(c), APath + '.' + c.Name, AIssues);
  end;
end;

function DialogLayoutProblems(AForm: TCustomForm): string;
var
  issues: TStringList;
begin
  Pump;
  issues := TStringList.Create;
  try
    CollectLayoutProblems(AForm, AForm.ClassName, issues);
    Result := Trim(issues.Text);
  finally
    issues.Free;
  end;
end;

procedure TDialogLayoutTests.CheckControls(AParent: TWinControl; const APath: string);
var
  issues: TStringList;
  i: Integer;
begin
  issues := TStringList.Create;
  try
    CollectLayoutProblems(AParent, APath, issues);
    for i := 0 to issues.Count - 1 do
      Issue(issues[i]);
  finally
    issues.Free;
  end;
end;

// Every page of the dialog (nested page controls too) is shown and checked
procedure TDialogLayoutTests.Inspect(AForm: TCustomForm);
var
  pages: TList;
  i: Integer;
  sheet: TTabSheet;
  c: TWinControl;

  procedure CollectPages(AParent: TWinControl);
  var
    k: Integer;
  begin
    for k := 0 to AParent.ControlCount - 1 do
      if AParent.Controls[k] is TWinControl then
      begin
        if (AParent.Controls[k] is TTabSheet) and TTabSheet(AParent.Controls[k]).TabVisible then
          pages.Add(AParent.Controls[k]);
        CollectPages(TWinControl(AParent.Controls[k]));
      end;
  end;

begin
  Pump;
  // The dialogs fit an 800x600 screen; the windows the user resizes (data
  // configuration, expression, preview) are as big as in the VCL and fit
  // the screen
  if AForm.BorderStyle in [bsSizeable, bsSizeToolWin] then
  begin
    if (AForm.Width > Screen.WorkAreaWidth) or (AForm.Height > Screen.WorkAreaHeight) then
      Issue(Format('%s is %dx%d: bigger than the screen', [AForm.ClassName,
        AForm.Width, AForm.Height]));
  end
  else
  if (AForm.Width > AForm.Scale96ToScreen(800)) or
    (AForm.Height > AForm.Scale96ToScreen(530)) then
    Issue(Format('%s is %dx%d: does not fit 800x600', [AForm.ClassName,
      AForm.Width, AForm.Height]));
  pages := TList.Create;
  try
    CollectPages(AForm);
    if pages.Count = 0 then
    begin
      CheckControls(AForm, AForm.ClassName);
      Shot(AForm, FCase);
    end
    else
      for i := 0 to pages.Count - 1 do
      begin
        sheet := TTabSheet(pages[i]);
        // The page and the pages that hold it
        c := sheet;
        while Assigned(c) and (c <> AForm) do
        begin
          if (c is TTabSheet) and (c.Parent is TPageControl) then
            TPageControl(c.Parent).ActivePage := TTabSheet(c);
          c := c.Parent;
        end;
        Pump;
        CheckControls(AForm, AForm.ClassName);
        Shot(AForm, FCase + '_' + sheet.Name);
      end;
  finally
    pages.Free;
  end;
end;

procedure TDialogLayoutTests.FormVisibleChanged(Sender: TObject; Form: TCustomForm);
begin
  if not Assigned(Form) or not Form.Visible or not (fsModal in Form.FormState) then
    Exit;
  if (Form.Tag = GUARD_HANDLED_TAG) or (FCase = '') then
    Exit;
  Form.Tag := GUARD_HANDLED_TAG;
  Inc(FShown);
  LogMsg('Dialog layout: ' + FCase + ' shows ' + Form.ClassName);
  // Checked inside its modal loop: while it is being shown the LCL has not
  // laid it out yet
  ModalGuardIgnore := Form;
  Application.QueueAsyncCall(InspectAsync, PtrInt(Form));
end;

procedure TDialogLayoutTests.InspectAsync(Data: PtrInt);
var
  form: TCustomForm;
  timer: TTimer;
begin
  form := TCustomForm(Data);
  try
    Inspect(form);
    // Compared between runs at different ppi: a dialog scaled twice grows
    // with the square of the ratio
    LogMsg(Format('Dialog layout: %s size %dx%d', [FCase, form.Width, form.Height]));
  except
    on E: Exception do
      Issue('checking raised ' + E.ClassName + ': ' + E.Message);
  end;
  // This runs in the idle of the modal loop, which then waits for an event:
  // under Xvfb there may be none (Qt6, or a GTK2 dialog with no blinking
  // caret), and a posted message does not wake it (the GTK2 of Lazarus 3.0
  // does not wake its loop for the messages posted by the main thread).
  // A timer of the dialog closes it and goes with it.
  timer := TTimer.Create(form);
  timer.Interval := 10;
  timer.OnTimer := CloseTimer;
  timer.Enabled := True;
end;

procedure TDialogLayoutTests.CloseTimer(Sender: TObject);
begin
  TTimer(Sender).Enabled := False;
  TCustomForm(TTimer(Sender).Owner).ModalResult := mrCancel;
end;

procedure TDialogLayoutTests.Open(const ACase: string; AOpen: TOpenProc);
var
  shown: Integer;
  cases: string;
begin
  // RP_LAYOUT_CASES=<case>,<case>: only those dialogs
  cases := GetEnvironmentVariable('RP_LAYOUT_CASES');
  if (cases <> '') and (Pos(',' + ACase + ',', ',' + cases + ',') = 0) then
    Exit;
  FCase := ACase;
  shown := FShown;
  LogMsg('Dialog layout: opening ' + ACase);
  try
    AOpen;
  except
    on E: Exception do
      Issue('opening raised ' + E.ClassName + ': ' + E.Message);
  end;
  if FShown = shown then
    Issue('no modal dialog was shown');
  LogMsg('Dialog layout: ' + ACase + ' closed');
  FCase := '';
  ModalGuardIgnore := nil;
end;

{ Cases }

function NewCaseReport: TRpReport;
var
  p: TRpParam;
begin
  Result := TRpReport.Create(nil);
  Result.CreateNew;
  p := Result.Params.Add('PSTRING');
  p.Description := 'Customer name or part of the name';
  p.ParamType := rpParamString;
  p.Value := 'ACME';
  p := Result.Params.Add('PINTEGER');
  p.Description := 'Minimum number of units';
  p.ParamType := rpParamInteger;
  p.Value := 10;
  p := Result.Params.Add('PDATE');
  p.Description := 'First date of the period';
  p.ParamType := rpParamDate;
  p.Value := VarFromDateTime(EncodeDate(2026, 9, 1));
  p := Result.Params.Add('PBOOL');
  p.Description := 'Only the active customers';
  p.ParamType := rpParamBool;
  p.Value := True;
  p := Result.Params.Add('PLIST');
  p.Description := 'Order of the report';
  p.ParamType := rpParamList;
  p.Items.Add('By name');
  p.Items.Add('By date');
  p.Values.Add('NAME');
  p.Values.Add('DATE');
  p.Value := 'NAME';
end;

procedure OpenDataConfig;
begin
  ShowDataConfig(CaseReport);
end;

procedure OpenParamDef;
begin
  ShowParamDef(CaseReport.Params, CaseReport.DataInfo, CaseReport);
end;

procedure OpenUserParams;
begin
  ShowUserParams(CaseReport.Params);
end;

procedure OpenExpression;
begin
  ChangeExpression('1+1', nil);
end;

procedure OpenGrid;
begin
  ModifyGridProperties(CaseReport);
end;

procedure OpenExtSection;
begin
  ChangeExternalSectionProps(CaseReport,
    CaseReport.SubReports[0].SubReport.Sections[0].Section);
end;

procedure OpenWizard;
var
  rep: TRpReport;
begin
  rep := TRpReport.Create(nil);
  try
    rep.CreateNew;
    NewReportWizard(rep, False);
  finally
    rep.Free;
  end;
end;

procedure OpenConnections;
var
  list: TRpDatabaseInfoList;
begin
  list := TRpDatabaseInfoList.Create(nil);
  try
    list.Add('CUSTOMERS');
    ShowModifyConnections(list);
  finally
    list.Free;
  end;
end;

procedure OpenDBXConfig;
begin
  ShowDBXConfig(IncludeTrailingPathDelimiter(GetTempDir) + 'rp_layout_dbxconnections.conf');
end;

procedure OpenDataText;
begin
  ShowDataTextConfig(IncludeTrailingPathDelimiter(GetTempDir) + 'rp_layout_datatext.txt', '');
end;

procedure OpenLogin;
begin
  ShowLoginDialog(nil);
end;

procedure OpenAIReport;
begin
  ExecuteAIReportDialog(nil, '# Sales report' + LineEnding + LineEnding +
    'A report of the sales by customer.', '', '', '');
end;

procedure OpenAbout;
begin
  ShowAbout;
end;

procedure OpenPrintRange;
var
  allpages, collate: Boolean;
  frompage, topage, copies: Integer;
begin
  allpages := True;
  collate := False;
  frompage := 1;
  topage := 10;
  copies := 1;
  DoShowPrintDialog(allpages, frompage, topage, copies, collate, True);
end;

procedure OpenBitmapProps;
var
  horz, vert: Integer;
  mono: Boolean;
begin
  horz := 100;
  vert := 100;
  mono := False;
  AskBitmapProps(horz, vert, mono);
end;

procedure OpenProgress;
var
  dia: TFRpVCLProgress;
begin
  dia := TFRpVCLProgress.Create(nil);
  try
    dia.LTittle.Caption := 'Sales by customer';
    dia.LRecordCount.Caption := 'Page: 12';
    dia.ShowModal;
  finally
    dia.Free;
  end;
end;

procedure OpenPrinterConfig;
begin
  ShowPrintersConfiguration;
end;

procedure OpenEmbeddedFile;
var
  efile: TEmbeddedFile;
begin
  efile := TEmbeddedFile.Create;
  try
    efile.FileName := 'factur-x.xml';
    efile.MimeType := 'application/xml';
    efile.Description := 'Invoice data';
    AskEmbeddedFileData(efile);
  finally
    efile.Free;
  end;
end;

procedure OpenSysInfo;
begin
  ShowSysInfo;
end;

procedure OpenPageSetup;
begin
  ExecutePageSetup(CaseReport);
end;

procedure OpenMessageBox;
begin
  RpMessageBox('The report could not be opened because a connection of the data ' +
    'access configuration does not exist. Check the connections and try again.',
    'Report Manager');
end;

procedure OpenInputBox;
begin
  RpInputBox('Report Manager', 'Name of the new subreport', 'SUBREPORT1');
end;

procedure OpenPreview;
var
  mf: TFRpMainFLCL;
begin
  mf := TFRpMainFLCL.Create(nil);
  try
    mf.NewReport;
    mf.BtnPreview.Click;
    TUndoCue(mf.Report.UndoCue).MarkClean;
  finally
    mf.Free;
  end;
end;

procedure OpenNewReportWizard;
var
  rep: TRpReport;
  prompt, apikey: string;
  dbid, schemaid: Int64;
begin
  rep := TRpReport.Create(nil);
  try
    rep.CreateNew;
    NewModernReportWizard(rep, prompt, dbid, schemaid, apikey);
  finally
    rep.Free;
  end;
end;

procedure OpenSampleData;
var
  ds: TMemDataset;
  i: Integer;
begin
  ds := TMemDataset.Create(nil);
  try
    ds.FieldDefs.Add('ID', ftInteger);
    ds.FieldDefs.Add('CUSTOMER', ftString, 40);
    ds.FieldDefs.Add('AMOUNT', ftFloat);
    ds.CreateTable;
    ds.Open;
    for i := 1 to 20 do
      ds.AppendRecord([i, 'Customer ' + IntToStr(i), i * 12.5]);
    ds.First;
    ShowDataset(ds);
  finally
    ds.Free;
  end;
end;

// The designer is not modal: its parts are measured shown (the toolbar, the
// inspector, the structure and the AI chat, built in code) and compared
// between runs at different ppi as the dialogs
procedure TDialogLayoutTests.MeasureDesigner;
var
  mf: TFRpMainFLCL;
  i, buttons: Integer;

  procedure LogSize(const AName: string; AControl: TControl);
  begin
    LogMsg(Format('Dialog layout: Designer.%s size %dx%d', [AName, AControl.Width,
      AControl.Height]));
  end;

  procedure LogButtons(AParent: TWinControl);
  var
    k: Integer;
  begin
    for k := 0 to AParent.ControlCount - 1 do
      if AParent.Controls[k].Visible then
      begin
        if AParent.Controls[k] is TButton then
        begin
          Inc(buttons);
          LogSize('ChatButton' + IntToStr(buttons), AParent.Controls[k]);
        end
        else
        if AParent.Controls[k] is TWinControl then
          LogButtons(TWinControl(AParent.Controls[k]));
      end;
  end;

begin
  LogMsg('Dialog layout: measuring the designer');
  mf := TFRpMainFLCL.Create(nil);
  try
    mf.NewReport;
    mf.ShowAIChat := True;
    mf.Show;
    Pump;
    LogSize('Form', mf);
    for i := 0 to mf.ControlCount - 1 do
      if mf.Controls[i] is TToolBar then
        LogSize('ToolBar', mf.Controls[i]);
    LogSize('ObjInsp', mf.ObjInsp);
    LogSize('Structure', mf.Structure);
    LogSize('AIChatPanel', mf.AIChatPanel);
    // The buttons of the chat (Send, Refresh...)
    buttons := 0;
    LogButtons(mf.ChatFrame);
    Shot(mf, 'Designer');
    TUndoCue(mf.Report.UndoCue).MarkClean;
  finally
    mf.Free;
  end;
end;

procedure TDialogLayoutTests.Run;
var
  i: Integer;
begin
  CaseReport := NewCaseReport;
  try
    Open('DataConfig', OpenDataConfig);
    Open('ParamDef', OpenParamDef);
    Open('UserParams', OpenUserParams);
    Open('Expression', OpenExpression);
    Open('Grid', OpenGrid);
    Open('ExtSection', OpenExtSection);
    Open('Wizard', OpenWizard);
    // The library dialog needs a library: ulibrarytests checks it
    Open('Connections', OpenConnections);
    Open('DBXConfig', OpenDBXConfig);
    Open('DataText', OpenDataText);
    Open('Login', OpenLogin);
    Open('AIReport', OpenAIReport);
    Open('About', OpenAbout);
    Open('PrintRange', OpenPrintRange);
    Open('BitmapProps', OpenBitmapProps);
    Open('Progress', OpenProgress);
    Open('PrinterConfig', OpenPrinterConfig);
    Open('EmbeddedFile', OpenEmbeddedFile);
    Open('SysInfo', OpenSysInfo);
    Open('PageSetup', OpenPageSetup);
    Open('MessageBox', OpenMessageBox);
    Open('InputBox', OpenInputBox);
    Open('Preview', OpenPreview);
    Open('NewReportWizard', OpenNewReportWizard);
    Open('SampleData', OpenSampleData);
    if (GetEnvironmentVariable('RP_LAYOUT_CASES') = '') or
      (Pos(',Designer,', ',' + GetEnvironmentVariable('RP_LAYOUT_CASES') + ',') > 0) then
      MeasureDesigner;
  finally
    FreeAndNil(CaseReport);
  end;
  LogMsg(Format('Dialog layout: %d dialogs checked, %d problems', [FShown, FIssues.Count]));
  for i := 0 to FIssues.Count - 1 do
    LogMsg('  LAYOUT ' + FIssues[i]);
  if FIssues.Count > 0 then
  begin
    LogMsg(Format('[TEST_FAILED] Dialog layout: %d problems', [FIssues.Count]));
    Halt(1);
  end;
end;

procedure RunDialogLayoutTests;
begin
  LogMsg(Format('Testing the layout of the dialogs (every page, no control cut or covered), %d ppi',
    [Screen.PixelsPerInch]));
  Tests := TDialogLayoutTests.Create;
  try
    Tests.Run;
  finally
    FreeAndNil(Tests);
  end;
  LogMsg('Dialog layout tests completed successfully');
end;

end.
