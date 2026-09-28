unit uvclparitytests;

{ Commands of the VCL designer ported to the LCL one after phase 7: menus
  of rpmdfmainvcl (hide/show all, select all text, move, align, align
  height 1/n, add sections, preferences, recent files, documentation,
  printer setup), fields of the data tree in new items and dropped on a
  section, the source of a report error selected, and the preview save
  formats. }

{$mode delphi}

interface

procedure RunVCLParityTests(const ASamplePath: string);

implementation

uses
  Classes, SysUtils, Types, Forms, Controls, ComCtrls, Menus, LCLType,
  rptypes, rpmunits, rpmdconsts, rpreport, rpsubreport, rpsection,
  rpprintitem, rplabelitem, rpmdbarcode,
  rpmdundocuelcl, rpmdfdesignlcl, rpmdfsectionintlcl, rpmdobinsintlcl,
  rpmdfmainlcl, rpmdimageslcl, rplclpreview, rplclreport,
  umainform;

procedure Fail(const Msg: string);
begin
  LogMsg('[TEST_FAILED] ' + Msg);
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

function FindSectionOfType(sub: TRpSubReport; st: TRpSectionType): TRpSection;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to sub.Sections.Count - 1 do
    if sub.Sections[i].Section.SectionType = st then
    begin
      Result := sub.Sections[i].Section;
      Exit;
    end;
end;

function SecIntOf(frame: TFRpDesignFrameLCL; sec: TObject): TRpSectionInterface;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to frame.secinterfaces.Count - 1 do
    if TRpSectionInterface(frame.secinterfaces[i]).printitem = sec then
    begin
      Result := TRpSectionInterface(frame.secinterfaces[i]);
      Exit;
    end;
end;

function ChildOf(secint: TRpSectionInterface; AItem: TObject): TRpSizePosInterface;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to secint.childlist.Count - 1 do
    if TRpSizePosInterface(secint.childlist[i]).printitem = AItem then
    begin
      Result := TRpSizePosInterface(secint.childlist[i]);
      Exit;
    end;
end;

function FindCaption(AItem: TMenuItem; const ACaption: string): TMenuItem;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to AItem.Count - 1 do
    if Pos(ACaption, AItem.Items[i].Caption) = 1 then
    begin
      Result := AItem.Items[i];
      Exit;
    end;
end;

function FindTreeNode(ATree: TTreeView; const AText: string): TTreeNode;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to ATree.Items.Count - 1 do
    if ATree.Items[i].Text = AText then
    begin
      Result := ATree.Items[i];
      Exit;
    end;
end;

// A new blank report without asking to save the previous one
procedure FreshReport(mf: TFRpMainFLCL);
begin
  if Assigned(mf.Report) then
    TUndoCue(mf.Report.UndoCue).MarkClean;
  mf.NewReport;
end;

procedure TestMenus(mf: TFRpMainFLCL);
var
  item: TMenuItem;
begin
  LogMsg('VCL parity: menus of rpmdfmainvcl in the LCL designer');
  Check(Assigned(FindCaption(mf.FileMenu, TranslateStr(56, 'Printer setup...'))),
    'File > Printer setup');
  Check(Assigned(FindCaption(mf.EditMenu, TranslateStr(117, 'All text'))), 'Edit > All text');
  item := FindCaption(mf.EditMenu, TranslateStr(22, 'Move'));
  Check(Assigned(item) and (item.Count = 4), 'Edit > Move with 4 commands');
  item := FindCaption(mf.EditMenu, TranslateStr(31, 'Align'));
  Check(Assigned(item) and (item.Count = 6), 'Edit > Align with 6 commands');
  Check(Assigned(FindCaption(mf.EditMenu, TranslateStr(15, 'Hide'))), 'Edit > Hide');
  Check(Assigned(FindCaption(mf.EditMenu, TranslateStr(17, 'Show all'))), 'Edit > Show all');
  Check(Assigned(FindCaption(mf.EditMenu, TranslateStr(1059, 'Adjust height to 1/n inch'))),
    'Edit > Adjust height to 1/n inch');
  item := FindCaption(mf.ReportMenu, TranslateStr(149, 'Add'));
  Check(Assigned(item) and (item.Count = 5), 'Report > Add with 5 commands');
  Check(Assigned(FindCaption(mf.ReportMenu, TranslateStr(127, 'Delete section/subreport'))),
    'Report > Delete section/subreport');
  Check(Assigned(mf.PreferencesMenu) and (mf.PreferencesMenu.Count = 4),
    'Preferences menu with 4 commands');
  Check(Assigned(FindCaption(mf.HelpMenu, TranslateStr(60, 'Documentation'))),
    'Help > Documentation');
  Check(Assigned(FindCaption(mf.HelpMenu, SRpSsysInfo)), 'Help > System information');
  Check(Assigned(mf.BtnAIChat) and (mf.BtnAIChat.Down = mf.ShowAIChat),
    'AI chat toolbar button following View > AI chat');
  mf.BtnAIChat.Click;
  Check(mf.ShowAIChat = mf.BtnAIChat.Down, 'AI chat button toggles the panel');
  mf.BtnAIChat.Click;
end;

procedure TestHideSelectAllText(mf: TFRpMainFLCL);
var
  rep: TRpReport;
  detail: TRpSection;
  secint: TRpSectionInterface;
  lab, expr, shp: TRpSizePosInterface;
  labItem: TRpCommonPosComponent;
  i: Integer;
begin
  LogMsg('VCL parity: hide, show all and select all text');
  FreshReport(mf);
  rep := mf.Report;
  detail := FindSectionOfType(rep.SubReports[0].SubReport, rpsecdetail);
  secint := SecIntOf(mf.DesignerFrame, detail);
  Check(Assigned(secint), 'Detail interface');
  lab := secint.CreateNewComponent(dtLabel, 10, 5, 0, 0);
  expr := secint.CreateNewComponent(dtExpression, 150, 5, 0, 0);
  shp := secint.CreateNewComponent(dtShape, 300, 5, 0, 0);
  labItem := TRpCommonPosComponent(lab.printitem);
  TUndoCue(rep.UndoCue).MarkClean;

  mf.SelectAllText;
  CheckInt(2, mf.ObjInsp.SelectedItems.Count, 'All text selects label and expression');
  for i := 0 to mf.ObjInsp.SelectedItems.Count - 1 do
    Check(mf.ObjInsp.SelectedItems.Objects[i] <> shp, 'The shape is not a text');

  mf.DesignerFrame.SelectComponent(lab, False);
  mf.HideSelection;
  Check(not lab.Visible and not lab.printitem.Visible, 'Hidden label');
  Check(expr.Visible and shp.Visible, 'The rest stays visible');
  Check(not rep.Modified, 'Hiding is a design time flag: report not modified');
  // The interfaces are recreated hidden (lab, expr and shp are freed)
  mf.RefreshInterface;
  secint := SecIntOf(mf.DesignerFrame, detail);
  Check(not ChildOf(secint, labItem).Visible, 'Hidden after refreshing the designer');
  mf.ShowAllHidden;
  secint := SecIntOf(mf.DesignerFrame, detail);
  Check(ChildOf(secint, labItem).Visible and labItem.Visible,
    'Show all shows the hidden label');
  Check(not rep.Modified, 'Show all does not modify the report');
end;

procedure TestAlignHeights(mf: TFRpMainFLCL);
var
  rep: TRpReport;
  detail: TRpSection;
  cue: TUndoCue;
begin
  LogMsg('VCL parity: adjust heights to 1/n inch, one undo step');
  FreshReport(mf);
  rep := mf.Report;
  cue := TUndoCue(rep.UndoCue);
  detail := FindSectionOfType(rep.SubReports[0].SubReport, rpsecdetail);
  rep.LinesPerInch := 600;
  detail.Height := 1000;
  rep.TopMargin := 500;
  cue.MarkClean;
  mf.AlignSectionsToLines;
  // 6 lines per inch: multiples of 240 twips
  CheckInt(960, detail.Height, 'Detail height to 1/6 inch');
  CheckInt(480, rep.TopMargin, 'Top margin to 1/6 inch');
  Check(rep.Modified and cue.CanUndo, 'Adjusting the heights is recorded');
  mf.DoUndo;
  CheckInt(1000, detail.Height, 'Undo restores the detail height');
  CheckInt(500, rep.TopMargin, 'Undo restores the top margin');
  Check(not cue.CanUndo, 'A single undo step');
  mf.DoRedo;
  CheckInt(960, detail.Height, 'Redo');
end;

procedure TestReportAdd(mf: TFRpMainFLCL);
var
  rep: TRpReport;
  sub: TRpSubReport;
  item: TMenuItem;
  n: Integer;
begin
  LogMsg('VCL parity: Report > Add');
  FreshReport(mf);
  rep := mf.Report;
  sub := rep.SubReports[0].SubReport;
  n := sub.Sections.Count;
  mf.Structure.SelectDataItem(sub);
  item := FindCaption(mf.ReportMenu, TranslateStr(149, 'Add'));
  // Detail (Tag 5)
  item.Items[4].Click;
  CheckInt(n + 1, sub.Sections.Count, 'Report > Add > Detail');
  mf.DoUndo;
  CheckInt(n, sub.Sections.Count, 'Undo of Report > Add > Detail');
  // Subreport (Tag 4)
  item.Items[3].Click;
  CheckInt(2, rep.SubReports.Count, 'Report > Add > Subreport');
  mf.DoUndo;
  CheckInt(1, rep.SubReports.Count, 'Undo of Report > Add > Subreport');
end;

procedure TestPreferences;
var
  mf: TFRpMainFLCL;
  oldConfig, config: string;
  oldUnit: TRpmUnits;
begin
  LogMsg('VCL parity: preferences saved in the designer configuration');
  oldConfig := RpDesignerLCLConfigFile;
  oldUnit := rpmunits.defaultunit;
  config := IncludeTrailingPathDelimiter(GetTempDir) + 'rp_vclparity_' +
    IntToStr(GetProcessID) + '.ini';
  DeleteFile(config);
  RpDesignerLCLConfigFile := config;
  try
    mf := TFRpMainFLCL.Create(nil);
    try
      Check(mf.UnitsCmMenuItem.Checked and mf.StatusBarMenuItem.Checked and
        mf.TypeInfoMenuItem.Checked and mf.PrintDialogMenuItem.Checked,
        'Default preferences');
      mf.UnitsInchesMenuItem.Click;
      Check(rpmunits.defaultunit = rpUnitInchess, 'Inches applied');
      mf.StatusBarMenuItem.Click;
      Check(not mf.StatusBarControl.Visible, 'Status bar hidden');
      mf.TypeInfoMenuItem.Click;
      Check(not mf.Structure.browser.ShowDataTypes, 'Data types hidden in the data tree');
      mf.PrintDialogMenuItem.Click;
    finally
      mf.Free;
    end;
    mf := TFRpMainFLCL.Create(nil);
    try
      Check(mf.UnitsInchesMenuItem.Checked and not mf.UnitsCmMenuItem.Checked,
        'Inches read from the preferences');
      Check(not mf.StatusBarMenuItem.Checked and not mf.StatusBarControl.Visible,
        'Status bar preference read');
      Check(not mf.TypeInfoMenuItem.Checked and not mf.Structure.browser.ShowDataTypes,
        'Data type preference read');
      Check(not mf.PrintDialogMenuItem.Checked, 'Print dialog preference read');
      mf.UnitsCmMenuItem.Click;
      Check(rpmunits.defaultunit = rpUnitCms, 'Back to cm');
    finally
      mf.Free;
    end;
  finally
    RpDesignerLCLConfigFile := oldConfig;
    rpmunits.defaultunit := oldUnit;
    DeleteFile(config);
  end;
end;

function RecentItems(mf: TFRpMainFLCL): TStringList;
var
  i: Integer;
begin
  Result := TStringList.Create;
  for i := 0 to mf.FileMenu.Count - 1 do
    if Assigned(mf.FileMenu.Items[i].OnClick) and (mf.FileMenu.Items[i].Hint <> '') and
      FileExists(mf.FileMenu.Items[i].Hint) then
      Result.AddObject(mf.FileMenu.Items[i].Hint, mf.FileMenu.Items[i]);
end;

procedure TestRecentFiles;
var
  mf: TFRpMainFLCL;
  oldConfig, config, f1, f2: string;
  items: TStringList;
begin
  LogMsg('VCL parity: last used files in the File menu');
  oldConfig := RpDesignerLCLConfigFile;
  config := IncludeTrailingPathDelimiter(GetTempDir) + 'rp_vclrecent_' +
    IntToStr(GetProcessID) + '.ini';
  f1 := IncludeTrailingPathDelimiter(GetTempDir) + 'rp_recent1_' + IntToStr(GetProcessID) + '.rep';
  f2 := IncludeTrailingPathDelimiter(GetTempDir) + 'rp_recent2_' + IntToStr(GetProcessID) + '.rep';
  DeleteFile(config);
  RpDesignerLCLConfigFile := config;
  try
    mf := TFRpMainFLCL.Create(nil);
    try
      mf.SaveReportFile(f1);
      mf.NewReport;
      mf.SaveReportFile(f2);
      items := RecentItems(mf);
      try
        CheckInt(2, items.Count, 'Two recent files');
        CheckStr(f2, items[0], 'Last saved first');
        CheckStr(f1, items[1], 'Then the previous one');
        TMenuItem(items.Objects[1]).Click;
        CheckStr(f1, mf.FileName, 'The recent file opens');
      finally
        items.Free;
      end;
      mf.HostedMode := True;
      items := RecentItems(mf);
      try
        CheckInt(0, items.Count, 'No recent files in hosted mode');
      finally
        items.Free;
      end;
    finally
      mf.Free;
    end;
    // Saved in the configuration: a new designer lists them
    mf := TFRpMainFLCL.Create(nil);
    try
      items := RecentItems(mf);
      try
        CheckInt(2, items.Count, 'Recent files read from the configuration');
        CheckStr(f1, items[0], 'Opened file first');
      finally
        items.Free;
      end;
    finally
      mf.Free;
    end;
  finally
    RpDesignerLCLConfigFile := oldConfig;
    DeleteFile(config);
    DeleteFile(f1);
    DeleteFile(f2);
  end;
end;

procedure TestDataTreeFields(mf: TFRpMainFLCL);
var
  rep: TRpReport;
  detail: TRpSection;
  secint: TRpSectionInterface;
  anode: TTreeNode;
  aint: TRpSizePosInterface;
  n: Integer;
begin
  LogMsg('VCL parity: fields of the data tree in new items and dropped on sections');
  FreshReport(mf);
  rep := mf.Report;
  detail := FindSectionOfType(rep.SubReports[0].SubReport, rpsecdetail);
  secint := SecIntOf(mf.DesignerFrame, detail);
  mf.Structure.browser.Report := rep;
  anode := FindTreeNode(mf.Structure.browser.ATree, 'PAGECOUNT');
  Check(Assigned(anode), 'PAGECOUNT in the data tree');

  // No field selected: the sample expression
  mf.Structure.browser.ATree.Selected := nil;
  CheckStr('', secint.SelectedDataField, 'No selected field');
  aint := secint.CreateNewComponent(dtExpression, 10, 5, 0, 0);
  CheckStr(QuotedStr(SRpSampleTextToLabels), TRpExpression(aint.printitem).Expression,
    'Sample expression without a selected field');
  // A selected field: its name
  mf.Structure.browser.ATree.Selected := anode;
  CheckStr('PAGECOUNT', secint.SelectedDataField, 'Selected field');
  aint := secint.CreateNewComponent(dtExpression, 10, 30, 0, 0);
  CheckStr('PAGECOUNT', TRpExpression(aint.printitem).Expression, 'Expression of the selected field');
  aint := secint.CreateNewComponent(dtBarcode, 10, 60, 0, 0);
  CheckStr('PAGECOUNT', TRpBarcode(aint.printitem).Expression, 'Barcode of the selected field');

  // Dropped: an expression with the field, TwoPass for the page count, one
  // undo step
  CheckStr('', secint.DraggedDataField(mf), 'Only the data tree drags fields');
  CheckStr('PAGECOUNT', secint.DraggedDataField(mf.Structure.browser.ATree), 'Dragged field');
  rep.TwoPass := False;
  n := detail.ReportComponents.Count;
  aint := secint.DropDataField(mf.Structure.browser.ATree, 40, 20);
  Check(Assigned(aint), 'Dropped field item');
  CheckInt(n + 1, detail.ReportComponents.Count, 'Dropped expression added');
  CheckStr('PAGECOUNT', TRpExpression(aint.printitem).Expression, 'Dropped expression');
  Check(aint.printitem.Width > 0, 'Dropped item width');
  Check(rep.TwoPass, 'The page count needs two passes');
  mf.DoUndo;
  CheckInt(n, detail.ReportComponents.Count, 'Undo removes the dropped item');
  Check(not rep.TwoPass, 'Undo restores TwoPass');
  mf.DoRedo;
  CheckInt(n + 1, detail.ReportComponents.Count, 'Redo of the drop');
  Check(rep.TwoPass, 'Redo sets TwoPass');
  mf.Structure.browser.ATree.Selected := nil;
end;

procedure TestReportException(mf: TFRpMainFLCL);
var
  rep: TRpReport;
  detail: TRpSection;
  secint: TRpSectionInterface;
  lab: TRpSizePosInterface;
  E: TRpReportException;
begin
  LogMsg('VCL parity: the source of a report error is selected');
  FreshReport(mf);
  rep := mf.Report;
  detail := FindSectionOfType(rep.SubReports[0].SubReport, rpsecdetail);
  secint := SecIntOf(mf.DesignerFrame, detail);
  secint.CreateNewComponent(dtLabel, 10, 5, 0, 0);
  lab := secint.CreateNewComponent(dtExpression, 150, 5, 0, 0);
  mf.DesignerFrame.ClearSelection;
  E := TRpReportException.Create('error', lab.printitem, 'Expression');
  try
    Check(mf.SelectReportExceptionSource(E), 'Item of the error found');
  finally
    E.Free;
  end;
  CheckInt(1, mf.ObjInsp.SelectedItems.Count, 'One selected item');
  secint := SecIntOf(mf.DesignerFrame, detail);
  Check(mf.ObjInsp.SelectedItems.Objects[0] = ChildOf(secint, lab.printitem),
    'The item of the error is selected');
  E := TRpReportException.Create('error', detail, '');
  try
    Check(mf.SelectReportExceptionSource(E), 'Section of the error found');
  finally
    E.Free;
  end;
  E := TRpReportException.Create('error', nil, '');
  try
    Check(not mf.SelectReportExceptionSource(E), 'No component: nothing selected');
  finally
    E.Free;
  end;
end;

procedure TestCtrlArrows(mf: TFRpMainFLCL);
var
  rep: TRpReport;
  detail: TRpSection;
  secint: TRpSectionInterface;
  lab: TRpSizePosInterface;
  key: Word;
  oldX: Integer;
begin
  LogMsg('VCL parity: Ctrl+arrows move the selection');
  FreshReport(mf);
  rep := mf.Report;
  detail := FindSectionOfType(rep.SubReports[0].SubReport, rpsecdetail);
  secint := SecIntOf(mf.DesignerFrame, detail);
  lab := secint.CreateNewComponent(dtLabel, 100, 5, 0, 0);
  mf.Show;
  Application.ProcessMessages;
  if secint.SectionControl.CanFocus then
    secint.SectionControl.SetFocus;
  Application.ProcessMessages;
  // Focusing the section clears the selection, as a click on it
  mf.DesignerFrame.SelectComponent(lab, False);
  CheckInt(1, mf.ObjInsp.SelectedItems.Count, 'Selected label');
  oldX := TRpCommonPosComponent(lab.printitem).PosX;
  key := VK_RIGHT;
  mf.OnKeyDown(mf, key, [ssCtrl]);
  CheckInt(0, key, 'Ctrl+Right handled');
  Check(TRpCommonPosComponent(lab.printitem).PosX > oldX, 'Ctrl+Right moves to the right');
  mf.Hide;
end;

function FindToolBar(mf: TFRpMainFLCL): TToolBar;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to mf.ControlCount - 1 do
    if mf.Controls[i] is TToolBar then
      Exit(TToolBar(mf.Controls[i]));
end;

procedure PumpMessages;
var
  i: Integer;
begin
  for i := 1 to 10 do
  begin
    Application.ProcessMessages;
    Sleep(10);
  end;
end;

// The controls of the toolbar as it shows them: by row and position
function ToolBarOrder(bar: TToolBar): TList;
var
  i, j: Integer;
  a, b: TControl;

  function Before(c1, c2: TControl): Boolean;
  var
    r1, r2: Integer;
  begin
    r1 := (c1.Top + bar.ButtonHeight div 2) div bar.ButtonHeight;
    r2 := (c2.Top + bar.ButtonHeight div 2) div bar.ButtonHeight;
    Result := (r1 < r2) or ((r1 = r2) and (c1.Left < c2.Left));
  end;

begin
  Result := TList.Create;
  for i := 0 to bar.ControlCount - 1 do
    Result.Add(bar.Controls[i]);
  for i := 1 to Result.Count - 1 do
    for j := i downto 1 do
    begin
      a := TControl(Result[j - 1]);
      b := TControl(Result[j]);
      if Before(b, a) then
        Result.Exchange(j - 1, j)
      else
        Break;
    end;
end;

// The buttons and groups of the VCL toolbar (nil: a separator), the image of
// each one, no image twice, and every button visible when the window is
// narrow (the toolbar takes the height of its rows)
procedure TestToolbar(mf: TFRpMainFLCL);
var
  bar: TToolBar;
  order: TList;
  i, j, oldWidth: Integer;
  c, d: TControl;
  r: TRect;

  procedure CheckOrder(const AExpected: array of TControl);
  var
    k: Integer;
  begin
    CheckInt(Length(AExpected), order.Count, 'Controls of the toolbar');
    for k := 0 to High(AExpected) do
      if AExpected[k] = nil then
        Check((TControl(order[k]) is TToolButton) and
          (TToolButton(order[k]).Style = tbsSeparator),
          Format('Toolbar control %d is a separator', [k]))
      else
        Check(order[k] = Pointer(AExpected[k]),
          Format('Toolbar control %d: expected "%s", got "%s"', [k,
            AExpected[k].Hint, TControl(order[k]).Hint]));
  end;

  procedure CheckImage(AButton: TToolButton; AImage: Integer);
  begin
    CheckInt(AImage, AButton.ImageIndex, 'Image of "' + AButton.Hint + '"');
  end;

begin
  LogMsg('VCL parity: toolbar buttons, images and rows');
  bar := FindToolBar(mf);
  Check(Assigned(bar), 'Main toolbar');
  mf.Show;
  PumpMessages;
  order := ToolBarOrder(bar);
  try
    CheckOrder([mf.BtnNew, mf.BtnOpen, nil, mf.BtnSave, mf.BtnDataConfig, nil,
      mf.BtnPrint, mf.BtnPreview, mf.BtnUndo, mf.BtnRedo, nil,
      mf.BtnToolArrow, mf.BtnToolLabel, mf.BtnToolExpr, mf.BtnToolShape,
      mf.BtnToolImage, mf.BtnToolChart, mf.BtnToolBarcode, nil,
      mf.ComboScale, mf.BtnDelete, mf.BtnCut, mf.BtnCopy, mf.BtnPaste, nil,
      mf.BtnNudgeLeft, mf.BtnNudgeRight, mf.BtnNudgeUp, mf.BtnNudgeDown, nil,
      mf.BtnAlignLeft, mf.BtnAlignRight, mf.BtnAlignUp, mf.BtnAlignDown,
      mf.BtnAlignHorz, mf.BtnAlignVert, mf.BtnAIChat]);
  finally
    order.Free;
  end;
  CheckImage(mf.BtnNew, IMG_NEW);
  CheckImage(mf.BtnOpen, IMG_OPEN);
  CheckImage(mf.BtnSave, IMG_SAVE);
  CheckImage(mf.BtnDataConfig, IMG_DATACONFIG);
  CheckImage(mf.BtnPrint, IMG_PRINT);
  CheckImage(mf.BtnPreview, IMG_PREVIEW);
  CheckImage(mf.BtnUndo, IMG_UNDO);
  CheckImage(mf.BtnRedo, IMG_REDO);
  CheckImage(mf.BtnToolArrow, IMG_ARROW);
  CheckImage(mf.BtnToolLabel, IMG_LABEL);
  CheckImage(mf.BtnToolExpr, IMG_EXPRESSION);
  CheckImage(mf.BtnToolShape, IMG_SHAPE);
  CheckImage(mf.BtnToolImage, IMG_IMAGE);
  CheckImage(mf.BtnToolChart, IMG_CHART);
  CheckImage(mf.BtnToolBarcode, IMG_BARCODE);
  CheckImage(mf.BtnDelete, IMG_DELETE);
  CheckImage(mf.BtnCut, IMG_CUT);
  CheckImage(mf.BtnCopy, IMG_COPY);
  CheckImage(mf.BtnPaste, IMG_PASTE);
  CheckImage(mf.BtnNudgeLeft, IMG_NAV_LEFT);
  CheckImage(mf.BtnNudgeRight, IMG_NAV_RIGHT);
  CheckImage(mf.BtnNudgeUp, IMG_NAV_UP);
  CheckImage(mf.BtnNudgeDown, IMG_NAV_DOWN);
  CheckImage(mf.BtnAlignLeft, IMG_ALIGN_LEFT);
  CheckImage(mf.BtnAlignRight, IMG_ALIGN_RIGHT);
  CheckImage(mf.BtnAlignUp, IMG_ALIGN_TOP);
  CheckImage(mf.BtnAlignDown, IMG_ALIGN_BOTTOM);
  // The image with the horizontal arrow distributes the horizontal space
  CheckImage(mf.BtnAlignHorz, IMG_SPACE_HORZ);
  CheckImage(mf.BtnAlignVert, IMG_SPACE_VERT);
  CheckImage(mf.BtnAIChat, IMG_CHAT_IA);
  for i := 0 to bar.ButtonCount - 1 do
    for j := i + 1 to bar.ButtonCount - 1 do
      if bar.Buttons[i].Style <> tbsSeparator then
        Check(bar.Buttons[i].ImageIndex <> bar.Buttons[j].ImageIndex,
          Format('"%s" and "%s" have the same image', [bar.Buttons[i].Hint,
            bar.Buttons[j].Hint]));

  // A narrow window: two or more rows, no button outside the toolbar
  oldWidth := mf.Width;
  try
    mf.Width := mf.Scale96ToScreen(560);
    PumpMessages;
    r := bar.ClientRect;
    for i := 0 to bar.ControlCount - 1 do
    begin
      c := bar.Controls[i];
      Check((c.Left >= 0) and (c.Top >= 0) and (c.Left + c.Width <= r.Right) and
        (c.Top + c.Height <= r.Bottom),
        Format('Toolbar control "%s" (%d,%d %dx%d) outside the toolbar %dx%d',
          [c.Hint, c.Left, c.Top, c.Width, c.Height, r.Right, r.Bottom]));
      for j := i + 1 to bar.ControlCount - 1 do
      begin
        d := bar.Controls[j];
        Check((c.Left + c.Width <= d.Left) or (d.Left + d.Width <= c.Left) or
          (c.Top + c.Height <= d.Top) or (d.Top + d.Height <= c.Top),
          Format('Toolbar controls "%s" and "%s" overlap', [c.Hint, d.Hint]));
      end;
    end;
    Check(bar.Height >= 2 * bar.ButtonHeight, 'The narrow toolbar has two rows');
    LogMsg(Format('Toolbar at %d pixels: %d pixels high', [mf.Width, bar.Height]));
  finally
    mf.Width := oldWidth;
    PumpMessages;
  end;
end;

// Each command does what its image shows: move, align and distribute the
// selection in the direction of the arrow
procedure TestToolbarCommands(mf: TFRpMainFLCL);
var
  rep: TRpReport;
  detail: TRpSection;
  secint: TRpSectionInterface;
  items: array[0..2] of TRpCommonPosComponent;
  oldX, oldY: array[0..2] of Integer;
  i: Integer;

  procedure Select3;
  begin
    mf.SelectAllText;
    CheckInt(3, mf.ObjInsp.SelectedItems.Count, 'Three selected labels');
  end;

  procedure Remember;
  var
    k: Integer;
  begin
    for k := 0 to 2 do
    begin
      oldX[k] := items[k].PosX;
      oldY[k] := items[k].PosY;
    end;
  end;

  // Gap between the items in the order of the axis
  procedure CheckEvenGaps(AHorz: Boolean; const AWhat: string);
  var
    gap1, gap2: Integer;
  begin
    if AHorz then
    begin
      gap1 := items[1].PosX - (items[0].PosX + items[0].Width);
      gap2 := items[2].PosX - (items[1].PosX + items[1].Width);
    end
    else
    begin
      gap1 := items[1].PosY - (items[0].PosY + items[0].Height);
      gap2 := items[2].PosY - (items[1].PosY + items[1].Height);
    end;
    Check(Abs(gap1 - gap2) <= 1, Format('%s: gaps %d and %d', [AWhat, gap1, gap2]));
  end;

begin
  LogMsg('VCL parity: toolbar commands move and align as their images show');
  FreshReport(mf);
  rep := mf.Report;
  detail := FindSectionOfType(rep.SubReports[0].SubReport, rpsecdetail);
  secint := SecIntOf(mf.DesignerFrame, detail);
  Check(Assigned(secint), 'Detail interface');
  items[0] := TRpCommonPosComponent(secint.CreateNewComponent(dtLabel, 10, 2, 0, 0).printitem);
  items[1] := TRpCommonPosComponent(secint.CreateNewComponent(dtLabel, 120, 10, 0, 0).printitem);
  items[2] := TRpCommonPosComponent(secint.CreateNewComponent(dtLabel, 400, 40, 0, 0).printitem);
  // Different sizes: the distribution keeps them
  items[1].Width := items[1].Width * 2;
  items[2].Height := items[2].Height * 2;
  Select3;

  // Distribute: the horizontal arrow moves only along X, the vertical one
  // only along Y; the first and the last items stay
  Remember;
  mf.BtnAlignHorz.Click;
  for i := 0 to 2 do
    CheckInt(oldY[i], items[i].PosY, 'Horizontal space keeps Y');
  CheckInt(oldX[0], items[0].PosX, 'Horizontal space keeps the first item');
  CheckInt(oldX[2], items[2].PosX, 'Horizontal space keeps the last item');
  CheckEvenGaps(True, 'Horizontal space');
  Remember;
  mf.BtnAlignVert.Click;
  for i := 0 to 2 do
    CheckInt(oldX[i], items[i].PosX, 'Vertical space keeps X');
  CheckEvenGaps(False, 'Vertical space');

  // Align to a side
  mf.BtnAlignLeft.Click;
  for i := 1 to 2 do
    CheckInt(items[0].PosX, items[i].PosX, 'Align left');
  mf.BtnAlignRight.Click;
  for i := 1 to 2 do
    CheckInt(items[0].PosX + items[0].Width, items[i].PosX + items[i].Width, 'Align right');
  mf.BtnAlignUp.Click;
  for i := 1 to 2 do
    CheckInt(items[0].PosY, items[i].PosY, 'Align up');
  mf.BtnAlignDown.Click;
  for i := 1 to 2 do
    CheckInt(items[0].PosY + items[0].Height, items[i].PosY + items[i].Height, 'Align down');

  // Move
  Remember;
  mf.BtnNudgeRight.Click;
  Check((items[0].PosX > oldX[0]) and (items[0].PosY = oldY[0]), 'Move right');
  Remember;
  mf.BtnNudgeLeft.Click;
  Check((items[0].PosX < oldX[0]) and (items[0].PosY = oldY[0]), 'Move left');
  Remember;
  mf.BtnNudgeDown.Click;
  Check((items[0].PosY > oldY[0]) and (items[0].PosX = oldX[0]), 'Move down');
  Remember;
  mf.BtnNudgeUp.Click;
  Check((items[0].PosY < oldY[0]) and (items[0].PosX = oldX[0]), 'Move up');
end;

procedure TestPreviewFormats;
var
  dia: TFRpVPreview;
  filter: string;
  n, i: Integer;
  lrep: TLCLReport;
  raised: Boolean;
begin
  LogMsg('VCL parity: save formats of the preview');
  dia := TFRpVPreview.Create(nil);
  try
    filter := dia.SaveDialog1.Filter;
  finally
    dia.Free;
  end;
  n := 0;
  for i := 1 to Length(filter) do
    if filter[i] = '|' then
      Inc(n);
  // 14 formats: description|mask pairs
  CheckInt(14 * 2 - 1, n, 'Save formats of the preview');
  Check(Pos('*.xls', filter) = 0, 'No Excel format (it needs the VCL)');
  Check(Pos('*.exe', filter) = 0, 'No self-executable format');
  lrep := TLCLReport.Create(nil);
  try
    raised := False;
    try
      lrep.SaveToExcel(IncludeTrailingPathDelimiter(GetTempDir) + 'rp_noexcel.xls');
    except
      raised := True;
    end;
    Check(raised, 'TLCLReport.SaveToExcel raises instead of doing nothing');
  finally
    lrep.Free;
  end;
end;

procedure RunVCLParityTests(const ASamplePath: string);
var
  mf: TFRpMainFLCL;
begin
  LogMsg('Testing the commands of the VCL designer ported to the LCL one');
  mf := TFRpMainFLCL.Create(nil);
  try
    mf.Show;
    Application.ProcessMessages;
    TestMenus(mf);
    TestHideSelectAllText(mf);
    TestAlignHeights(mf);
    TestReportAdd(mf);
    TestDataTreeFields(mf);
    TestReportException(mf);
    TestCtrlArrows(mf);
    TestToolbar(mf);
    TestToolbarCommands(mf);
    TUndoCue(mf.Report.UndoCue).MarkClean;
  finally
    mf.Free;
  end;
  TestPreferences;
  TestRecentFiles;
  TestPreviewFormats;
  LogMsg('VCL parity tests completed successfully');
end;

end.
