unit uregressiontests;

{ Subphase 5.5 regression tests for the LCL designer: undo engine, design
  surface, inspector, main form, dialogs and the hosted designer component.

  Every test drives the product code directly (no user interaction). The
  few product paths that always ask for confirmation through a modal
  TFRpMessageDlgVCL (deleting a node of the structure tree) or show the
  designer modally (TRpDesignerLCL.Execute) are answered automatically by
  the modal guard installed for the whole suite. The guard also turns any
  unexpected LCL modal form into an immediate [TEST_FAILED] instead of a
  hang. }

{$mode delphi}

interface

// Installs the modal guard (answers the expected modal forms, fails fast on
// any other one). Call it before running any test.
procedure InstallModalGuard;
procedure RunRegressionTests(const ASamplePath: string);
// For the other test units: the next message box is expected and answered
// with OK; the caption and the text of the last message box answered
procedure GuardExpectOkMessageBox;
function GuardMessageBoxesAnswered: Integer;
function GuardLastMessageBoxCaption: string;
function GuardLastMessageBoxText: string;

var
  // A modal form the guard leaves alone: udialoglayouttests checks it once
  // it is laid out and closes it
  ModalGuardIgnore: TObject = nil;

implementation

uses
  Classes, SysUtils, Variants, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls,
  Graphics, Menus, Generics.Collections, sqldb, sqlite3conn,
  rptypes, rpmunits, rpmdconsts, rpreport, rpsubreport, rpsection,
  rpprintitem, rplabelitem, rpmdchart, rpmdcharttypes, rpparams, rpdatainfo, rpgraphutilslcl,
  rpdrawitem, rpmdbarcode, rptranslator,
  rpmdundocuelcl, rpmdfdesignlcl, rpmdfsectionintlcl, rpmdobinsintlcl,
  rpmdflabelintlcl, rpmdfdrawintlcl, rpmdfchartintlcl, rpmdfbarcodeintlcl,
  rpmdobjinsplcl, rpmdfmainlcl, rpmdfparamslcl, rpmdfdinfolcl,
  rpmdfopenliblcl, rprflclparams, rpmdesignerlcl, rpfrmchatlcl,
  rplocalschemas, umainform;

const
  GUARD_HANDLED_TAG = $5EC7;

type
  TGuardFormAction = procedure(AForm: TCustomForm) of object;

  { TModalGuard }

  TModalGuard = class
  public
    // Message boxes (TFRpMessageDlgVCL) still expected and the answer
    ExpectMsgBoxes: Integer;
    MsgBoxAnswer: TMessageButton;
    MsgBoxesAnswered: Integer;
    LastMsgBoxText: string;
    LastMsgBoxCaption: string;
    // The next ones are answered with OK instead (GuardExpectOkMessageBox)
    OkAnswers: Integer;
    // Designer form (TFRpMainFLCL) shown modally by TRpDesignerLCL.Execute
    ExpectDesigner: Boolean;
    DesignerAction: TGuardFormAction;
    DesignersHandled: Integer;
    procedure HandleForm(AForm: TCustomForm);
    procedure FormVisibleChanged(Sender: TObject; Form: TCustomForm);
    procedure AppIdle(Sender: TObject; var Done: Boolean);
  end;

  { TRegressionTests }

  TRegressionTests = class
  private
    FChangeCount: Integer;
    FSaveCalls: Integer;
    FSavedReportHasParam: Boolean;
    procedure CueChanged(Sender: TObject);
    procedure ExecOnSave(var Stream: TStream; report: TRpReport; var handled: Boolean);
    procedure DesignerCheckHostedAction(AForm: TCustomForm);
    procedure DesignerModifyAction(AForm: TCustomForm);
    // L1: undo engine
    procedure TestUndoCap;
    procedure TestDirtyState;
    procedure TestFailingOperation;
    procedure TestDeleteRestoresAll;
    // L1 + L2: designer (TFRpMainFLCL)
    procedure TestDesigner(const ASamplePath: string);
    // Parity with the VCL designer: item properties, context menu, painting
    procedure TestItemInterfaces;
    // L2: dialogs
    procedure TestParamsDialog;
    procedure TestDataConfig;
    procedure TestLibraryTree;
    procedure TestUserParams;
    procedure TestDesignerExecute(const ASamplePath: string);
  end;

var
  Guard: TModalGuard = nil;
  FakeSearchCalls: Integer = 0;

{ Assertions }

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

{ Model / design surface helpers }

function CompNames(sec: TRpSection): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to sec.ReportComponents.Count - 1 do
  begin
    if i > 0 then
      Result := Result + ',';
    if Assigned(sec.ReportComponents[i].Component) then
      Result := Result + sec.ReportComponents[i].Component.Name
    else
      Result := Result + '<nil>';
  end;
end;

function Join4(const A, B, C, D: string): string;
begin
  Result := A + ',' + B + ',' + C + ',' + D;
end;

function FindSectionOfType(sub: TRpSubReport; st: TRpSectionType): TRpSection;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to sub.Sections.Count - 1 do
  begin
    if sub.Sections[i].Section.SectionType = st then
    begin
      Result := sub.Sections[i].Section;
      Exit;
    end;
  end;
end;

function SecIntOf(frame: TFRpDesignFrameLCL; sec: TObject): TRpSectionInterface;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to frame.secinterfaces.Count - 1 do
  begin
    if TRpSectionInterface(frame.secinterfaces[i]).printitem = sec then
    begin
      Result := TRpSectionInterface(frame.secinterfaces[i]);
      Exit;
    end;
  end;
end;

function ChildInt(frame: TFRpDesignFrameLCL; const AName: string): TRpSizePosInterface;
var
  i, j: Integer;
  secint: TRpSectionInterface;
begin
  Result := nil;
  for i := 0 to frame.secinterfaces.Count - 1 do
  begin
    secint := TRpSectionInterface(frame.secinterfaces[i]);
    for j := 0 to secint.childlist.Count - 1 do
    begin
      if SameText(TRpSizePosInterface(secint.childlist[j]).printitem.Name, AName) then
      begin
        Result := TRpSizePosInterface(secint.childlist[j]);
        Exit;
      end;
    end;
  end;
  if Result = nil then
    Fail('No design interface found for component ' + AName);
end;

function FindItem(rep: TRpReport; const AName: string): TObject;
begin
  Result := rep.FindReporItemByName(AName);
end;

// The design frame must show exactly the sections and components of its
// subreport (no interface of a freed or missing item)
procedure CheckFrameInSync(frame: TFRpDesignFrameLCL; const Context: string);
var
  sub: TRpSubReport;
  sec: TRpSection;
  secint: TRpSectionInterface;
  i, j, n: Integer;
begin
  Application.ProcessMessages;
  sub := frame.CurrentSubreport;
  Check(Assigned(sub), Context + ': the design frame shows no subreport');
  Check(frame.Report.SubReports.IndexOf(sub) >= 0,
    Context + ': the displayed subreport is not in the report');
  CheckInt(sub.Sections.Count, frame.secinterfaces.Count, Context + ': section interfaces');
  CheckInt(sub.Sections.Count, frame.leftrulers.Count, Context + ': left rulers');
  CheckInt(sub.Sections.Count, frame.righttitles.Count, Context + ': right handles');
  for i := 0 to sub.Sections.Count - 1 do
  begin
    sec := sub.Sections[i].Section;
    secint := TRpSectionInterface(frame.secinterfaces[i]);
    Check(secint.printitem = sec, Format('%s: section interface %d does not show section %s',
      [Context, i, sec.Name]));
    n := 0;
    for j := 0 to sec.ReportComponents.Count - 1 do
      if sec.ReportComponents[j].Component is TRpCommonPosComponent then
        Inc(n);
    CheckInt(n, secint.childlist.Count, Format('%s: component interfaces of section %s',
      [Context, sec.Name]));
    for j := 0 to secint.childlist.Count - 1 do
      Check(sec.ReportComponents.IndexOf(TRpSizePosInterface(secint.childlist[j]).printitem) >= 0,
        Format('%s: interface %d of section %s shows a component that is not in the section',
          [Context, j, sec.Name]));
  end;
end;

procedure CheckLastOpsGroup(cue: TUndoCue; ACount: Integer; AOperation: TOperationType;
  const Context: string);
var
  i, gid: Integer;
begin
  Check(cue.UndoOperations.Count >= ACount, Context + ': not enough undo operations');
  gid := cue.UndoOperations[cue.UndoOperations.Count - ACount].groupId;
  for i := cue.UndoOperations.Count - ACount to cue.UndoOperations.Count - 1 do
  begin
    Check(cue.UndoOperations[i].groupId = gid, Context + ': operations are not in one undo group');
    Check(cue.UndoOperations[i].operation = AOperation,
      Format('%s: operation %d expected type %d, got %d', [Context, i, Ord(AOperation),
        Ord(cue.UndoOperations[i].operation)]));
  end;
  if cue.UndoOperations.Count > ACount then
    Check(cue.UndoOperations[cue.UndoOperations.Count - ACount - 1].groupId <> gid,
      Context + ': the group contains more operations than expected');
end;

function FileBytes(const AFileName: string): TMemoryStream;
begin
  Result := TMemoryStream.Create;
  Result.LoadFromFile(AFileName);
end;

procedure CheckFileUnchanged(const AFileName: string; Original: TMemoryStream; const Context: string);
var
  cur: TMemoryStream;
begin
  cur := FileBytes(AFileName);
  try
    Check((cur.Size = Original.Size) and CompareMem(cur.Memory, Original.Memory, cur.Size),
      Context + ': the report file was modified');
  finally
    cur.Free;
  end;
end;

procedure CopyFileBytes(const Source, Dest: string);
var
  ms: TMemoryStream;
begin
  ms := FileBytes(Source);
  try
    ms.SaveToFile(Dest);
  finally
    ms.Free;
  end;
end;

procedure WriteTextFile(const AFileName, AText: string);
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  try
    sl.Text := AText;
    sl.SaveToFile(AFileName);
  finally
    sl.Free;
  end;
end;

{ Engine report helpers }

function NewEngineReport(out sec: TRpSection): TRpReport;
var
  sub: TRpSubReport;
begin
  Result := TRpReport.Create(nil);
  sub := Result.AddSubReport;
  sec := sub.Sections[sub.FirstDetail].Section;
  Result.UndoCue := TUndoCue.Create(Result);
end;

function AddEngineLabel(rep: TRpReport; sec: TRpSection; const AName: string): TRpLabel;
begin
  Result := TRpLabel.Create(rep);
  Result.Name := AName;
  sec.ReportComponents.Add.Component := Result;
end;

// Applies PosX := ANewX to the label and returns the operation recording it
function NewPosXOp(gid: Integer; lab: TRpLabel; sec: TRpSection; ANewX: Integer): TChangeObjectOperation;
begin
  Result := TChangeObjectOperation.Create(otModify, gid);
  Result.componentName := lab.Name;
  Result.componentClass := 'TRPLABEL';
  Result.parentName := sec.Name;
  Result.AddProperty('posX', ptInteger, lab.PosX, ANewX);
  lab.PosX := ANewX;
end;

{ TModalGuard }

procedure TModalGuard.HandleForm(AForm: TCustomForm);
var
  dlg: TFRpMessageDlgVCL;
  btn: TButton;
begin
  if not Assigned(AForm) or not AForm.Visible or not (fsModal in AForm.FormState) then
    Exit;
  if AForm = ModalGuardIgnore then
    Exit;
  if AForm.Tag = GUARD_HANDLED_TAG then
    Exit;
  AForm.Tag := GUARD_HANDLED_TAG;

  if AForm is TFRpMessageDlgVCL then
  begin
    dlg := TFRpMessageDlgVCL(AForm);
    if ExpectMsgBoxes <= 0 then
      Fail('Unexpected modal message box: "' + dlg.LMessage.Caption + '"');
    Dec(ExpectMsgBoxes);
    Inc(MsgBoxesAnswered);
    LastMsgBoxText := dlg.LMessage.Caption;
    LastMsgBoxCaption := dlg.Caption;
    if OkAnswers > 0 then
    begin
      Dec(OkAnswers);
      btn := dlg.BOk;
    end
    else
    case MsgBoxAnswer of
      smbYes: btn := dlg.BYes;
      smbNo: btn := dlg.BNo;
      smbCancel: btn := dlg.BCancel;
    else
      btn := dlg.BOk;
    end;
    if not btn.Visible then
      Fail('Message box "' + dlg.LMessage.Caption + '" has no button for the planned answer');
    LogMsg('ModalGuard: answering "' + dlg.LMessage.Caption + '" with ' + btn.Caption);
    dlg.BYesClick(btn);
    Exit;
  end;

  if (AForm is TFRpMainFLCL) and ExpectDesigner then
  begin
    ExpectDesigner := False;
    Inc(DesignersHandled);
    LogMsg('ModalGuard: closing the modal designer form');
    if Assigned(DesignerAction) then
      DesignerAction(AForm);
    AForm.Close;
    Exit;
  end;

  Fail('Unexpected modal dialog ' + AForm.ClassName + ' "' + AForm.Caption + '"');
end;

procedure TModalGuard.FormVisibleChanged(Sender: TObject; Form: TCustomForm);
begin
  HandleForm(Form);
end;

procedure TModalGuard.AppIdle(Sender: TObject; var Done: Boolean);
var
  i: Integer;
  f: TCustomForm;
begin
  // Idle only runs inside modal loops here: a modal form still open at this
  // point was not answered (or refused to close)
  for i := 0 to Screen.CustomFormCount - 1 do
  begin
    f := Screen.CustomForms[i];
    if f = ModalGuardIgnore then
      Continue;
    if f.Visible and (fsModal in f.FormState) then
    begin
      if f.Tag = GUARD_HANDLED_TAG then
        Fail('Modal dialog ' + f.ClassName + ' "' + f.Caption +
          '" did not close after the automatic answer');
      HandleForm(f);
      Done := False;
      Exit;
    end;
  end;
end;

procedure InstallModalGuard;
begin
  if Assigned(Guard) then
    Exit;
  Guard := TModalGuard.Create;
  Guard.MsgBoxAnswer := smbCancel;
  Screen.AddHandlerFormVisibleChanged(Guard.FormVisibleChanged);
  Application.AddOnIdleHandler(Guard.AppIdle);
end;

procedure GuardExpectOkMessageBox;
begin
  InstallModalGuard;
  Inc(Guard.ExpectMsgBoxes);
  Inc(Guard.OkAnswers);
end;

function GuardMessageBoxesAnswered: Integer;
begin
  InstallModalGuard;
  Result := Guard.MsgBoxesAnswered;
end;

function GuardLastMessageBoxCaption: string;
begin
  InstallModalGuard;
  Result := Guard.LastMsgBoxCaption;
end;

function GuardLastMessageBoxText: string;
begin
  InstallModalGuard;
  Result := Guard.LastMsgBoxText;
end;

procedure FakeParamValueSearch(aparam: TRpParam; report: TComponent);
begin
  Inc(FakeSearchCalls);
  aparam.Value := 'PICKED';
end;

{ TRegressionTests }

procedure TRegressionTests.CueChanged(Sender: TObject);
begin
  Inc(FChangeCount);
end;

procedure TRegressionTests.ExecOnSave(var Stream: TStream; report: TRpReport;
  var handled: Boolean);
begin
  Inc(FSaveCalls);
  FSavedReportHasParam := report.Params.IndexOf('EXEC_TEST_PARAM') >= 0;
  handled := True;
end;

procedure TRegressionTests.DesignerCheckHostedAction(AForm: TCustomForm);
var
  f: TFRpMainFLCL;
begin
  f := TFRpMainFLCL(AForm);
  Check(f.HostedMode, 'TRpDesignerLCL.Execute must show the designer in hosted mode');
  Check(not f.BtnSave.Visible and not f.BtnOpen.Visible and not f.BtnNew.Visible,
    'Hosted designer must hide New/Open/Save');
  Check(not f.Report.Modified, 'Hosted designer: freshly loaded report must be unmodified');
end;

procedure TRegressionTests.DesignerModifyAction(AForm: TCustomForm);
var
  f: TFRpMainFLCL;
begin
  DesignerCheckHostedAction(AForm);
  f := TFRpMainFLCL(AForm);
  f.Report.Params.Add('EXEC_TEST_PARAM');
  f.MarkExternalChange;
  Check(f.Report.Modified, 'MarkExternalChange must mark the hosted report modified');
end;

{ L1: undo engine }

procedure TRegressionTests.TestUndoCap;
var
  rep: TRpReport;
  sec: TRpSection;
  lab: TRpLabel;
  cue: TUndoCue;
  gA, gB, i: Integer;
begin
  LogMsg('5.5 L1: undo history cap (MaxOperations)');

  // Default: unlimited (VCL parity)
  rep := NewEngineReport(sec);
  try
    cue := TUndoCue(rep.UndoCue);
    CheckInt(0, cue.MaxOperations, 'Default TUndoCue.MaxOperations (0 = unlimited)');
    lab := AddEngineLabel(rep, sec, 'CAP_LAB0');
    for i := 1 to 150 do
      cue.AddOperation(NewPosXOp(cue.GetGroupId, lab, sec, i));
    CheckInt(150, cue.UndoOperations.Count, 'Unlimited cue: operations kept');
  finally
    rep.Free;
  end;

  // Clean point at the start, lost when its group is trimmed: -1
  rep := NewEngineReport(sec);
  try
    cue := TUndoCue(rep.UndoCue);
    cue.MaxOperations := 10;
    lab := AddEngineLabel(rep, sec, 'CAP_LAB1');
    cue.MarkClean;
    gA := cue.GetGroupId;
    for i := 1 to 5 do
      cue.AddOperation(NewPosXOp(gA, lab, sec, i * 10));
    CheckInt(5, cue.UndoOperations.Count, 'Cap: group A kept');
    CheckInt(0, cue.CleanOpIndex, 'Cap: clean point before trimming');
    gB := cue.GetGroupId;
    Check(gB <> gA, 'Cap: GetGroupId must start a new group');
    for i := 1 to 8 do
      cue.AddOperation(NewPosXOp(gB, lab, sec, 1000 + i));
    CheckInt(8, cue.UndoOperations.Count, 'Cap 10, groups of 5 then 8: operations kept');
    for i := 0 to cue.UndoOperations.Count - 1 do
      CheckInt(gB, cue.UndoOperations[i].groupId, 'Cap: only the whole newest group is kept');
    CheckInt(-1, cue.CleanOpIndex, 'Cap: clean point inside the trimmed group is forgotten');
    Check(cue.IsDirty and rep.Modified, 'Cap: report must be dirty after trimming the clean point');
    cue.Undo.Free;
    CheckInt(0, cue.UndoOperations.Count, 'Cap: undo takes the whole group B');
    CheckInt(8, cue.RedoOperations.Count, 'Cap: redo holds the whole group B');
    CheckInt(50, lab.PosX, 'Cap: undo of group B restores the state after group A');
    Check(cue.IsDirty and rep.Modified,
      'Cap: the saved state (before group A) is unreachable, the report stays dirty');
  finally
    rep.Free;
  end;

  // Clean point after group A: shifted to 0 when A is trimmed
  rep := NewEngineReport(sec);
  try
    cue := TUndoCue(rep.UndoCue);
    cue.MaxOperations := 10;
    lab := AddEngineLabel(rep, sec, 'CAP_LAB2');
    gA := cue.GetGroupId;
    for i := 1 to 5 do
      cue.AddOperation(NewPosXOp(gA, lab, sec, i * 10));
    cue.MarkClean;
    CheckInt(5, cue.CleanOpIndex, 'Cap: clean point after group A');
    gB := cue.GetGroupId;
    for i := 1 to 8 do
      cue.AddOperation(NewPosXOp(gB, lab, sec, 1000 + i));
    CheckInt(8, cue.UndoOperations.Count, 'Cap (clean after A): operations kept');
    CheckInt(0, cue.CleanOpIndex, 'Cap: clean point shifted by the trimmed operations');
    Check(cue.IsDirty and rep.Modified, 'Cap: group B pending, report dirty');
    cue.Undo.Free;
    CheckInt(50, lab.PosX, 'Cap: undo of group B');
    Check(not cue.IsDirty and not rep.Modified,
      'Cap: undoing group B returns to the saved state (clean point 0)');
    cue.Redo.Free;
    CheckInt(1008, lab.PosX, 'Cap: redo of group B');
    Check(cue.IsDirty and rep.Modified, 'Cap: redo makes the report dirty again');
  finally
    rep.Free;
  end;

  // A single group bigger than the cap is never split
  rep := NewEngineReport(sec);
  try
    cue := TUndoCue(rep.UndoCue);
    cue.MaxOperations := 10;
    lab := AddEngineLabel(rep, sec, 'CAP_LAB3');
    gA := cue.GetGroupId;
    for i := 1 to 15 do
      cue.AddOperation(NewPosXOp(gA, lab, sec, i));
    CheckInt(15, cue.UndoOperations.Count, 'Cap 10, single group of 15: kept whole');
    cue.Undo.Free;
    CheckInt(0, cue.UndoOperations.Count, 'Cap: single big group undone at once');
    CheckInt(15, cue.RedoOperations.Count, 'Cap: single big group in redo');
    CheckInt(0, lab.PosX, 'Cap: single big group fully undone');
  finally
    rep.Free;
  end;
  LogMsg('Undo cap verified');
end;

procedure TRegressionTests.TestDirtyState;
var
  rep: TRpReport;
  sec: TRpSection;
  lab: TRpLabel;
  cue: TUndoCue;
  gid: Integer;
begin
  LogMsg('5.5 L1: dirty state and OnChange contract');
  rep := NewEngineReport(sec);
  try
    cue := TUndoCue(rep.UndoCue);
    lab := AddEngineLabel(rep, sec, 'DIRTY_LAB');
    cue.OnChange := CueChanged;
    FChangeCount := 0;

    cue.AddOperation(NewPosXOp(cue.GetGroupId, lab, sec, 100));
    CheckInt(1, FChangeCount, 'OnChange calls after AddOperation');
    Check(cue.IsDirty and rep.Modified, 'Dirty after the first edit');
    cue.MarkClean;
    CheckInt(2, FChangeCount, 'OnChange calls after MarkClean');
    Check(not cue.IsDirty and not rep.Modified, 'Clean after MarkClean');
    CheckInt(1, cue.CleanOpIndex, 'Clean point after one operation');

    // Original data-loss bug: save, undo, new edit -> must be dirty
    cue.Undo.Free;
    CheckInt(3, FChangeCount, 'OnChange calls after Undo');
    CheckInt(0, lab.PosX, 'Undo restored PosX');
    Check(cue.IsDirty and rep.Modified, 'Dirty after undoing past the save point');
    cue.AddOperation(NewPosXOp(cue.GetGroupId, lab, sec, 200));
    CheckInt(4, FChangeCount, 'OnChange calls after the new edit');
    Check(cue.IsDirty, 'Save point -> undo -> new edit: IsDirty must be True');
    Check(rep.Modified, 'Save point -> undo -> new edit: Report.Modified must be True');
    CheckInt(-1, cue.CleanOpIndex, 'The saved state lay in the discarded redo branch');
    CheckInt(0, cue.RedoOperations.Count, 'A new edit discards the redo branch');
    cue.Undo.Free;
    Check(cue.IsDirty and rep.Modified,
      'The discarded saved state can not be reached again: still dirty after undo');
    cue.Redo.Free;

    // MarkExternalChange survives Undo/Redo/Clear until MarkClean
    cue.MarkClean;
    Check(not cue.IsDirty and not rep.Modified, 'Clean before the external change');
    FChangeCount := 0;
    cue.MarkExternalChange;
    CheckInt(1, FChangeCount, 'OnChange calls after MarkExternalChange');
    Check(cue.IsDirty and rep.Modified, 'MarkExternalChange marks the report dirty');
    cue.Undo.Free;
    Check(cue.IsDirty and rep.Modified, 'External change survives Undo');
    cue.Redo.Free;
    Check(cue.IsDirty and rep.Modified,
      'External change survives Redo (back at the clean point of the history)');
    cue.Clear;
    CheckInt(4, FChangeCount, 'OnChange calls after Undo, Redo and Clear');
    CheckInt(0, cue.UndoOperations.Count + cue.RedoOperations.Count, 'Clear empties the history');
    Check(cue.IsDirty and rep.Modified, 'External change survives Clear');
    cue.MarkClean;
    Check(not cue.IsDirty and not rep.Modified, 'Only MarkClean resets the external change');

    // Clear keeps unsaved (recorded) changes as dirty
    cue.AddOperation(NewPosXOp(cue.GetGroupId, lab, sec, 300));
    cue.Clear;
    Check(cue.IsDirty and rep.Modified, 'Clear must not hide unsaved changes');
    cue.MarkClean;

    // BeginUpdate/EndUpdate: one notification for a multi-operation action
    FChangeCount := 0;
    cue.BeginUpdate;
    try
      gid := cue.GetGroupId;
      cue.AddOperation(NewPosXOp(gid, lab, sec, 400));
      cue.AddOperation(NewPosXOp(gid, lab, sec, 500));
      cue.AddOperation(NewPosXOp(gid, lab, sec, 600));
      CheckInt(0, FChangeCount, 'No OnChange inside BeginUpdate/EndUpdate');
    finally
      cue.EndUpdate;
    end;
    CheckInt(1, FChangeCount, 'One OnChange for the grouped action');
    cue.OnChange := nil;
  finally
    rep.Free;
  end;
  LogMsg('Dirty state verified');
end;

procedure TRegressionTests.TestFailingOperation;
var
  rep: TRpReport;
  sec: TRpSection;
  labA, labB, labC: TRpLabel;
  cue: TUndoCue;
  gid: Integer;
  raised: Boolean;
  msg: string;
begin
  LogMsg('5.5 L1: failing operation in the middle of an undo group');
  rep := NewEngineReport(sec);
  try
    cue := TUndoCue(rep.UndoCue);
    labA := AddEngineLabel(rep, sec, 'FAIL_A');
    labB := AddEngineLabel(rep, sec, 'FAIL_B');
    labC := AddEngineLabel(rep, sec, 'FAIL_C');
    gid := cue.GetGroupId;
    cue.AddOperation(NewPosXOp(gid, labA, sec, 10));
    cue.AddOperation(NewPosXOp(gid, labB, sec, 20));
    cue.AddOperation(NewPosXOp(gid, labC, sec, 30));
    cue.MarkClean;

    // The middle operation can not find its component
    labB.Name := 'FAIL_B_RENAMED';
    raised := False;
    msg := '';
    try
      cue.Undo.Free;
    except
      on E: Exception do
      begin
        raised := True;
        msg := E.Message;
      end;
    end;
    Check(raised, 'Undo of a group with a failing operation must raise');
    Check(Pos('undo of', msg) > 0, 'Undo failure message must name the operation: ' + msg);
    CheckInt(2, cue.UndoOperations.Count, 'Failed undo: the failing op and the rest stay in undo');
    CheckInt(1, cue.RedoOperations.Count, 'Failed undo: the undone op is in redo');
    Check(cue.RedoOperations[0].componentName = 'FAIL_C', 'Failed undo: C was undone first');
    CheckInt(0, labC.PosX, 'Failed undo: C restored');
    CheckInt(20, labB.PosX, 'Failed undo: B untouched');
    CheckInt(10, labA.PosX, 'Failed undo: A untouched');
    Check(cue.IsDirty and rep.Modified, 'Failed undo changed the report: dirty');

    // Redo recovers the partially undone group
    cue.Redo.Free;
    CheckInt(3, cue.UndoOperations.Count, 'Redo after a failed undo: whole group back in undo');
    CheckInt(0, cue.RedoOperations.Count, 'Redo after a failed undo: redo empty');
    CheckInt(30, labC.PosX, 'Redo after a failed undo: C re-applied');
    Check(not cue.IsDirty and not rep.Modified, 'Redo recovered the saved state');

    // Once the cause is fixed the whole group undoes and redoes
    labB.Name := 'FAIL_B';
    cue.Undo.Free;
    CheckInt(0, cue.UndoOperations.Count, 'Undo after the fix: whole group undone');
    Check((labA.PosX = 0) and (labB.PosX = 0) and (labC.PosX = 0), 'Undo after the fix: all restored');
    cue.Redo.Free;
    Check((labA.PosX = 10) and (labB.PosX = 20) and (labC.PosX = 30), 'Redo after the fix: all re-applied');
  finally
    rep.Free;
  end;
  LogMsg('Failing operation handling verified');
end;

// Undo of a delete must bring back everything the report saves: the chart
// expressions and series colors, and the BidiModes of every language
procedure TRegressionTests.TestDeleteRestoresAll;
var
  rep: TRpReport;
  sec: TRpSection;
  lab: TRpLabel;
  chart: TRpChart;
  cue: TUndoCue;
  gid: Integer;

  procedure RecordRemove(comp: TRpCommonPosComponent);
  var
    op: TChangeObjectOperation;
  begin
    op := TChangeObjectOperation.Create(otRemove, gid);
    op.componentName := comp.Name;
    op.componentClass := UpperCase(comp.ClassName);
    op.parentName := sec.Name;
    op.oldItemIndex := sec.ReportComponents.IndexOf(comp);
    cue.AddAllComponentProperties(comp, op);
    cue.AddOperation(op);
    sec.ReportComponents.Delete(op.oldItemIndex);
    comp.Free;
  end;

  procedure CheckChartRangeSaved(arep: TRpReport; aformat: TRpStreamFormat);
  var
    ms: TMemoryStream;
    rep2: TRpReport;
    c2: TRpChart;
    what: string;
  begin
    if aformat = rpStreamXML then
      what := 'XML'
    else
      what := 'DFM text';
    ms := TMemoryStream.Create;
    rep2 := TRpReport.Create(nil);
    try
      arep.StreamFormat := aformat;
      arep.SaveToStream(ms);
      ms.Position := 0;
      rep2.LoadFromStream(ms);
      c2 := TRpChart(FindItem(rep2, 'UNDO_CHART'));
      Check(Assigned(c2), 'Chart loaded back from ' + what);
      if Assigned(c2) then
      begin
        CheckInt(Ord(rpAutoRangeNone), Ord(c2.AutoRange), 'Chart Y axis auto range saved in ' + what);
        Check(c2.YMin = -3.5, 'Chart Y min saved in ' + what);
        Check(c2.YMax = 12.25, 'Chart Y max saved in ' + what);
      end;
    finally
      rep2.Free;
      ms.Free;
    end;
  end;

begin
  LogMsg('5.5: undo of a delete restores chart expressions, series colors and BidiModes');
  rep := NewEngineReport(sec);
  try
    cue := TUndoCue(rep.UndoCue);
    lab := AddEngineLabel(rep, sec, 'BIDI_LABEL');
    lab.BidiModes.Text := 'BidiNo' + LineEnding + 'BidiFull';
    chart := TRpChart.Create(rep);
    chart.Name := 'UNDO_CHART';
    sec.ReportComponents.Add.Component := chart;
    chart.GetValueCondition := 'COND';
    chart.ValueExpression := 'VAL';
    chart.ValueXExpression := 'VALX';
    chart.ChangeSerieExpression := 'CHANGE';
    chart.CaptionExpression := 'CAPTION';
    chart.SerieCaption := 'SERIECAPTION';
    chart.ClearExpression := 'CLEAR';
    chart.ColorExpression := 'COLOR';
    chart.SerieColorExpression := 'SERIECOLOR';
    chart.Series.Add.Color := $FF0000;
    chart.Series.Add.Color := $00FF00;
    chart.AutoRange := rpAutoRangeNone;
    chart.YMin := -3.5;
    chart.YMax := 12.25;

    gid := cue.GetGroupId;
    RecordRemove(chart);
    RecordRemove(lab);
    Check(FindItem(rep, 'UNDO_CHART') = nil, 'The chart was deleted');
    CheckInt(0, sec.ReportComponents.Count, 'Both components deleted');

    cue.Undo.Free;
    CheckInt(2, sec.ReportComponents.Count, 'Undo restores both components');
    chart := TRpChart(FindItem(rep, 'UNDO_CHART'));
    Check(Assigned(chart), 'Undo recreates the chart');
    CheckStr('COND', chart.GetValueCondition, 'Chart GetValueCondition restored');
    CheckStr('VAL', chart.ValueExpression, 'Chart ValueExpression restored');
    CheckStr('VALX', chart.ValueXExpression, 'Chart ValueXExpression restored');
    CheckStr('CHANGE', chart.ChangeSerieExpression, 'Chart ChangeSerieExpression restored');
    CheckStr('CAPTION', chart.CaptionExpression, 'Chart CaptionExpression restored');
    CheckStr('SERIECAPTION', chart.SerieCaption, 'Chart SerieCaption restored');
    CheckStr('CLEAR', chart.ClearExpression, 'Chart ClearExpression restored');
    CheckStr('COLOR', chart.ColorExpression, 'Chart ColorExpression restored');
    CheckStr('SERIECOLOR', chart.SerieColorExpression, 'Chart SerieColorExpression restored');
    CheckInt(2, chart.Series.Count, 'Chart series restored');
    CheckInt($FF0000, chart.Series[0].Color, 'Chart series 0 color restored');
    CheckInt($00FF00, chart.Series[1].Color, 'Chart series 1 color restored');
    CheckInt(Ord(rpAutoRangeNone), Ord(chart.AutoRange), 'Chart Y axis auto range restored');
    Check(chart.YMin = -3.5, 'Chart Y min restored');
    Check(chart.YMax = 12.25, 'Chart Y max restored');
    lab := TRpLabel(FindItem(rep, 'BIDI_LABEL'));
    Check(Assigned(lab), 'Undo recreates the label');
    CheckInt(2, lab.BidiModes.Count, 'Label BidiModes of both languages restored');
    CheckStr('BidiNo', lab.BidiModes[0], 'Label BidiModes language 0');
    CheckStr('BidiFull', lab.BidiModes[1], 'Label BidiModes language 1 (BidiFull)');
    CheckInt(0, sec.ReportComponents.IndexOf(lab), 'Label restored at its index');
    CheckInt(1, sec.ReportComponents.IndexOf(chart), 'Chart restored at its index');

    // The Y axis range survives saving in the DFM text format (it is only
    // written when not default) as well as in XML
    CheckChartRangeSaved(rep, rpStreamText);
    CheckChartRangeSaved(rep, rpStreamXML);
  finally
    rep.Free;
  end;
  LogMsg('Undo of a delete restores chart and BidiModes verified');
end;

{ L1 + L2: designer }

procedure TRegressionTests.TestDesigner(const ASamplePath: string);
var
  mf: TFRpMainFLCL;
  rep: TRpReport;
  cue, oldCue: TUndoCue;
  frame: TFRpDesignFrameLCL;
  sub, sub2: TRpSubReport;
  detail, ph: TRpSection;
  secint: TRpSectionInterface;
  panel: TRpPanelObjLCL;
  nA, nB, nC, nD, p1, p2, p3, pasted1, pasted2, phName, name2, secName2, oldFile, tmp: string;
  labA, labB: TRpLabel;
  nOps, cnt, origW, origX, origStyleA, origStyleB, phIndex, secCount, answered, i, k: Integer;
  origAutoExpand, raised: Boolean;
  op: TChangeObjectOperation;
  lst: TObjectList<TChangeObjectOperation>;
  saveUnit: TRpmUnits;
  oldRep: TRpReport;
  ms: TMemoryStream;
  garbage: AnsiString;
begin
  LogMsg('5.5: designer regression tests on TFRpMainFLCL');
  mf := TFRpMainFLCL.Create(nil);
  try
    mf.Show;
    Application.ProcessMessages;
    rep := mf.Report;
    Check(Assigned(rep) and (rep.UndoCue is TUndoCue), 'TFRpMainFLCL must start with a report and an undo cue');
    cue := TUndoCue(rep.UndoCue);
    Check(not rep.Modified and not cue.CanUndo, 'New designer report must be clean');
    frame := mf.DesignerFrame;
    sub := rep.SubReports[0].SubReport;
    detail := FindSectionOfType(sub, rpsecdetail);
    ph := FindSectionOfType(sub, rpsecpheader);
    Check(Assigned(detail) and Assigned(ph), 'New report must have a page header and a detail');
    CheckFrameInSync(frame, 'new report');

    // Components A, B, C, D in the detail section
    secint := SecIntOf(frame, detail);
    Check(Assigned(secint), 'No interface for the detail section');
    nA := secint.CreateNewComponent(dtLabel, 10, 5, 0, 0).printitem.Name;
    nB := secint.CreateNewComponent(dtLabel, 10, 30, 0, 0).printitem.Name;
    nC := secint.CreateNewComponent(dtLabel, 150, 5, 0, 0).printitem.Name;
    nD := secint.CreateNewComponent(dtLabel, 150, 30, 0, 0).printitem.Name;
    CheckStr(Join4(nA, nB, nC, nD), CompNames(detail), 'Initial component order');
    labA := TRpLabel(FindItem(rep, nA));
    labB := TRpLabel(FindItem(rep, nB));

    // ---- L2: every change updates Modified, Undo/Redo actions and history panel
    LogMsg('5.5 L2: undo cue OnChange updates the designer UI');
    mf.Structure.cueview.ClearHistory;
    Check(rep.Modified, 'Clearing the history must keep unsaved changes dirty');
    cue.MarkClean;
    Check(not rep.Modified, 'MarkClean resets Report.Modified');
    Check(not mf.BtnUndo.Enabled and not mf.BtnRedo.Enabled, 'Undo/Redo disabled with an empty clean history');
    CheckInt(0, mf.Structure.cueview.ListViewCue.Items.Count, 'History panel empty');
    Check(Copy(mf.Caption, Length(mf.Caption) - 1, 2) <> ' *', 'Title must not show * when clean');
    origX := labA.PosX;
    // Recorded directly in the cue: nothing else refreshes the UI
    cue.AddOperation(NewPosXOp(cue.GetGroupId, labA, detail, origX + 300));
    Check(rep.Modified, 'AddOperation marks Report.Modified');
    Check(mf.BtnUndo.Enabled and not mf.BtnRedo.Enabled, 'AddOperation enables Undo (OnChange)');
    CheckInt(1, mf.Structure.cueview.ListViewCue.Items.Count, 'History panel refreshed by OnChange');
    Check(mf.Structure.cueview.BUndo.Enabled, 'History panel undo button enabled');
    Check(Copy(mf.Caption, Length(mf.Caption) - 1, 2) = ' *', 'Title shows * when modified: ' + mf.Caption);
    mf.DoUndo;
    CheckInt(origX, labA.PosX, 'DoUndo restored PosX');
    Check(not rep.Modified, 'Undo back to the clean point: not modified');
    Check(not mf.BtnUndo.Enabled and mf.BtnRedo.Enabled, 'After undo: Undo disabled, Redo enabled');
    CheckInt(1, mf.Structure.cueview.ListViewCue.Items.Count, 'History panel shows the redo operation');
    mf.DoRedo;
    CheckInt(origX + 300, labA.PosX, 'DoRedo re-applied PosX');
    Check(rep.Modified and mf.BtnUndo.Enabled and not mf.BtnRedo.Enabled, 'After redo: modified, Undo enabled');
    // A designer action
    frame.SelectComponent(ChildInt(frame, nA), False);
    frame.MoveSelectedComponents(ChildInt(frame, nA), 100, 0);
    CheckInt(2, mf.Structure.cueview.ListViewCue.Items.Count, 'History panel after a move');
    // Undo/Redo called on the cue: the caller frees the returned list
    lst := cue.Undo;
    try
      Check(Assigned(lst) and (lst.Count = 1) and not lst.OwnsObjects,
        'Undo returns a non owning list with the undone operations');
    finally
      lst.Free;
    end;
    CheckInt(3, mf.Structure.cueview.ListViewCue.Items.Count, 'History panel: undo, separator and redo rows');
    Check(mf.BtnUndo.Enabled and mf.BtnRedo.Enabled, 'Both Undo and Redo enabled');
    lst := cue.Redo;
    try
      Check(Assigned(lst) and (lst.Count = 1), 'Redo returns the redone operations');
    finally
      lst.Free;
    end;
    frame.UpdateInterface(True);
    CheckFrameInSync(frame, 'after the UI integration test');

    // ---- L1: Z-order, separate actions: bring B, then D to front
    LogMsg('5.5 L1: Z-order undo/redo');
    frame.SelectComponent(ChildInt(frame, nB), False);
    frame.BringSelectionToFront;
    CheckStr(Join4(nA, nC, nD, nB), CompNames(detail), 'Bring B to front');
    frame.SelectComponent(ChildInt(frame, nD), False);
    frame.BringSelectionToFront;
    CheckStr(Join4(nA, nC, nB, nD), CompNames(detail), 'Then bring D to front');
    mf.DoUndo;
    CheckStr(Join4(nA, nC, nD, nB), CompNames(detail), 'Undo of bring D to front');
    mf.DoUndo;
    CheckStr(Join4(nA, nB, nC, nD), CompNames(detail), 'Undo of bring B to front');
    CheckFrameInSync(frame, 'after Z-order undo');
    mf.DoRedo;
    mf.DoRedo;
    CheckStr(Join4(nA, nC, nB, nD), CompNames(detail), 'Redo of both Z-order moves');
    mf.DoUndo;
    mf.DoUndo;
    CheckStr(Join4(nA, nB, nC, nD), CompNames(detail), 'Z-order restored');
    // Same with one multiple selection: one undo group
    frame.SelectComponent(ChildInt(frame, nB), False);
    frame.SelectComponent(ChildInt(frame, nD), True);
    nOps := cue.UndoOperations.Count;
    frame.BringSelectionToFront;
    CheckInt(nOps + 2, cue.UndoOperations.Count, 'Bring B,D to front: operations');
    CheckLastOpsGroup(cue, 2, otSwapUp, 'Bring B,D to front');
    CheckStr(Join4(nA, nC, nB, nD), CompNames(detail), 'Bring B,D to front order');
    mf.DoUndo;
    CheckStr(Join4(nA, nB, nC, nD), CompNames(detail), 'One undo restores A,B,C,D');
    CheckFrameInSync(frame, 'after multi Z-order undo');
    mf.DoRedo;
    CheckStr(Join4(nA, nC, nB, nD), CompNames(detail), 'Redo of the multi Z-order move');
    mf.DoUndo;

    // ---- L1: delete D then B, undo restores A,B,C,D
    LogMsg('5.5 L1: multi-delete undo order');
    origX := labB.PosY;
    frame.SelectComponent(ChildInt(frame, nD), False);
    frame.SelectComponent(ChildInt(frame, nB), True);
    nOps := cue.UndoOperations.Count;
    frame.DeleteSelection;
    CheckStr(nA + ',' + nC, CompNames(detail), 'Delete D then B');
    CheckInt(nOps + 2, cue.UndoOperations.Count, 'Delete D, B: operations');
    CheckLastOpsGroup(cue, 2, otRemove, 'Delete D, B');
    CheckInt(3, cue.UndoOperations[nOps].oldItemIndex, 'Delete: D recorded at index 3');
    CheckInt(1, cue.UndoOperations[nOps + 1].oldItemIndex, 'Delete: B recorded at index 1');
    CheckFrameInSync(frame, 'after deleting two components');
    mf.DoUndo;
    CheckStr(Join4(nA, nB, nC, nD), CompNames(detail), 'Undo of the delete restores the order');
    labB := TRpLabel(FindItem(rep, nB));
    CheckInt(origX, labB.PosY, 'Undo of the delete restores the component properties');
    CheckFrameInSync(frame, 'after undo of the delete');
    mf.DoRedo;
    CheckStr(nA + ',' + nC, CompNames(detail), 'Redo of the delete');
    mf.DoUndo;
    CheckStr(Join4(nA, nB, nC, nD), CompNames(detail), 'Components restored again');
    labA := TRpLabel(FindItem(rep, nA));
    labB := TRpLabel(FindItem(rep, nB));

    // ---- L1: inspector edits restore the model values
    LogMsg('5.5 L1: inspector edits undo/redo');
    saveUnit := rpmunits.defaultunit;
    rpmunits.defaultunit := rpUnitcms;
    try
      frame.SelectComponent(ChildInt(frame, nA), False);
      panel := mf.ObjInsp.CurrentPanel;
      Check(Assigned(panel) and (panel.CompItem = ChildInt(frame, nA)), 'Inspector shows label A');
      origW := labA.Width;
      Check(origW <> 1440, 'Label A must not already be 1440 twips wide');
      nOps := cue.UndoOperations.Count;
      panel.SetPropertyFull(SRpSWidth, '2' + DefaultFormatSettings.DecimalSeparator + '540');
      CheckInt(1440, labA.Width, 'Width "2.540" cm in twips');
      CheckInt(nOps + 1, cue.UndoOperations.Count, 'Width edit: one operation');
      op := cue.UndoOperations.Last;
      Check((op.properties.Count = 1) and (op.properties[0].propertyName = 'width') and
        (op.properties[0].oldValue = origW) and (op.properties[0].newValue = 1440),
        'Width edit recorded as model twips (width old -> 1440)');
      mf.DoUndo;
      CheckInt(origW, labA.Width, 'Undo of Width');
      mf.DoRedo;
      CheckInt(1440, labA.Width, 'Redo of Width');

      frame.SelectComponent(ChildInt(frame, nA), False);
      panel := mf.ObjInsp.CurrentPanel;
      origX := labA.PosX;
      Check(origX <> 567, 'Label A must not already be at 1 cm');
      panel.SetPropertyFull(SRpSLeft, '1' + DefaultFormatSettings.DecimalSeparator + '000');
      CheckInt(567, labA.PosX, 'Left "1.000" cm in twips');
      CheckStr('posX', cue.UndoOperations.Last.properties[0].propertyName, 'Left recorded as posX');
      mf.DoUndo;
      CheckInt(origX, labA.PosX, 'Undo of Left');
      mf.DoRedo;
      CheckInt(567, labA.PosX, 'Redo of Left');

      frame.SelectComponent(ChildInt(frame, nA), False);
      panel := mf.ObjInsp.CurrentPanel;
      Check(labA.Align = rpalnone, 'Label A starts without alignment');
      panel.SetPropertyFull(SRPAlign, AlignToStr(rpalbottom));
      Check(labA.Align = rpalbottom, 'Align set through the inspector');
      CheckStr('align', cue.UndoOperations.Last.properties[0].propertyName, 'Align recorded as align');
      mf.DoUndo;
      Check(labA.Align = rpalnone, 'Undo of Align');
      mf.DoRedo;
      Check(labA.Align = rpalbottom, 'Redo of Align');
      mf.DoUndo;

      // A boolean property of a section
      secint := SecIntOf(frame, detail);
      mf.ObjInsp.AddCompItem(secint, True);
      panel := mf.ObjInsp.CurrentPanel;
      Check(Assigned(panel) and (panel.CompItem = secint), 'Inspector shows the detail section');
      origAutoExpand := detail.AutoExpand;
      nOps := cue.UndoOperations.Count;
      panel.SetPropertyFull(SRpSAutoExpand, BoolToStr(not origAutoExpand, True));
      Check(detail.AutoExpand = not origAutoExpand, 'Section AutoExpand set through the inspector');
      CheckInt(nOps + 1, cue.UndoOperations.Count, 'Section boolean edit: one operation');
      op := cue.UndoOperations.Last;
      Check((op.componentName = detail.Name) and (op.properties[0].propertyName = 'autoExpand'),
        'Section edit recorded as autoExpand of the section');
      mf.DoUndo;
      Check(detail.AutoExpand = origAutoExpand, 'Undo of the section boolean');
      mf.DoRedo;
      Check(detail.AutoExpand = not origAutoExpand, 'Redo of the section boolean');
      mf.DoUndo;
    finally
      rpmunits.defaultunit := saveUnit;
    end;

    // ---- L1: font style (font dialog path) on two labels is one group
    LogMsg('5.5 L1: bold on two selected labels');
    frame.SelectComponent(ChildInt(frame, nA), False);
    frame.SelectComponent(ChildInt(frame, nB), True);
    CheckInt(2, mf.ObjInsp.SelectedItems.Count, 'Inspector multiple selection');
    panel := mf.ObjInsp.CurrentPanel;
    origStyleA := labA.FontStyle;
    origStyleB := labB.FontStyle;
    Check(((origStyleA and 1) = 0) and ((origStyleB and 1) = 0), 'Labels start without bold');
    nOps := cue.UndoOperations.Count;
    panel.SetPropertyFull(SrpSFontStyle, '1');
    Check((labA.FontStyle = 1) and (labB.FontStyle = 1), 'Bold applied to both selected labels');
    CheckInt(nOps + 2, cue.UndoOperations.Count, 'Bold on two labels: operations');
    CheckLastOpsGroup(cue, 2, otModify, 'Bold on two labels');
    CheckStr('fontStyle', cue.UndoOperations.Last.properties[0].propertyName, 'Bold recorded as fontStyle');
    mf.DoUndo;
    Check((labA.FontStyle = origStyleA) and (labB.FontStyle = origStyleB), 'One undo restores both styles');
    CheckInt(nOps, cue.UndoOperations.Count, 'Both style operations undone together');
    mf.DoRedo;
    Check((labA.FontStyle = 1) and (labB.FontStyle = 1), 'One redo applies bold to both');
    mf.DoUndo;

    // ---- L1: paste two items, one undo removes both, redo restores them
    LogMsg('5.5 L1: paste undo/redo');
    frame.SelectComponent(ChildInt(frame, nA), False);
    frame.SelectComponent(ChildInt(frame, nB), True);
    mf.BtnCopy.OnClick(mf.BtnCopy);
    cnt := detail.ReportComponents.Count;
    nOps := cue.UndoOperations.Count;
    mf.BtnPaste.OnClick(mf.BtnPaste);
    CheckInt(cnt + 2, detail.ReportComponents.Count, 'Paste of two components');
    pasted1 := detail.ReportComponents[cnt].Component.Name;
    pasted2 := detail.ReportComponents[cnt + 1].Component.Name;
    Check((pasted1 <> nA) and (pasted1 <> nB) and (pasted2 <> nA) and (pasted2 <> nB) and
      (pasted1 <> pasted2), 'Pasted components get new unique names');
    CheckInt(nOps + 2, cue.UndoOperations.Count, 'Paste: operations');
    CheckLastOpsGroup(cue, 2, otAdd, 'Paste');
    CheckFrameInSync(frame, 'after paste');
    mf.DoUndo;
    CheckInt(cnt, detail.ReportComponents.Count, 'One undo removes both pasted components');
    Check((FindItem(rep, pasted1) = nil) and (FindItem(rep, pasted2) = nil), 'Pasted components freed');
    CheckFrameInSync(frame, 'after undo of the paste');
    mf.DoRedo;
    CheckInt(cnt + 2, detail.ReportComponents.Count, 'Redo restores both pasted components');
    Check((FindItem(rep, pasted1) is TRpLabel) and (FindItem(rep, pasted2) is TRpLabel),
      'Redo restores the pasted components with their names');
    CheckFrameInSync(frame, 'after redo of the paste');
    mf.DoUndo;
    CheckStr(Join4(nA, nB, nC, nD), CompNames(detail), 'Detail back to A,B,C,D');

    // ---- L1: delete the displayed page header (with 3 components) from the tree
    LogMsg('5.5 L1: delete a displayed section from the structure tree');
    secint := SecIntOf(frame, ph);
    p1 := secint.CreateNewComponent(dtLabel, 10, 2, 0, 0).printitem.Name;
    p2 := secint.CreateNewComponent(dtLabel, 120, 2, 0, 0).printitem.Name;
    p3 := secint.CreateNewComponent(dtLabel, 230, 2, 0, 0).printitem.Name;
    CheckStr(p1 + ',' + p2 + ',' + p3, CompNames(ph), 'Page header components');
    phName := ph.Name;
    phIndex := sub.Sections.IndexOf(ph);
    secCount := sub.Sections.Count;
    mf.Structure.SelectDataItem(ph);
    Check(frame.CurrentSubreport = sub, 'The subreport of the page header is displayed');
    nOps := cue.UndoOperations.Count;
    answered := Guard.MsgBoxesAnswered;
    Guard.ExpectMsgBoxes := 1;
    Guard.MsgBoxAnswer := smbOK;
    mf.Structure.DeleteSelectedNode;
    CheckInt(answered + 1, Guard.MsgBoxesAnswered, 'The delete confirmation was asked');
    CheckInt(0, Guard.ExpectMsgBoxes, 'No other confirmation pending');
    ph := nil;
    CheckInt(secCount - 1, sub.Sections.Count, 'Page header deleted');
    Check(FindItem(rep, phName) = nil, 'Page header freed');
    CheckInt(nOps + 4, cue.UndoOperations.Count, 'Section delete: 3 components + section');
    CheckLastOpsGroup(cue, 4, otRemove, 'Section delete');
    for i := 0 to 2 do
      CheckInt(0, cue.UndoOperations[nOps + i].oldItemIndex, 'Section delete: components recorded at index 0');
    CheckStr(phName, cue.UndoOperations.Last.componentName, 'Section delete: section recorded last');
    CheckFrameInSync(frame, 'after deleting the displayed page header');
    CheckInt(1 + sub.Sections.Count, mf.Structure.RView.Items.Count, 'Structure tree after the delete');
    mf.DoUndo;
    CheckInt(secCount, sub.Sections.Count, 'Undo restores the page header');
    ph := sub.Sections[phIndex].Section;
    CheckStr(phName, ph.Name, 'Page header restored at its index');
    Check(ph.SectionType = rpsecpheader, 'Restored section is a page header');
    CheckStr(p1 + ',' + p2 + ',' + p3, CompNames(ph), 'Undo keeps the component order of the section');
    CheckFrameInSync(frame, 'after undo of the section delete');
    secint := SecIntOf(frame, ph);
    Check(Assigned(secint), 'Restored section has a design interface');
    for i := 0 to 2 do
      Check(TRpSizePosInterface(secint.childlist[i]).printitem = ph.ReportComponents[i].Component,
        'Design interfaces of the restored section follow the component order');
    mf.DoRedo;
    CheckInt(secCount - 1, sub.Sections.Count, 'Redo deletes the page header again');
    CheckFrameInSync(frame, 'after redo of the section delete');
    mf.DoUndo;
    ph := sub.Sections[phIndex].Section;
    CheckStr(p1 + ',' + p2 + ',' + p3, CompNames(ph), 'Page header components restored again');

    // ---- L1: add subreport, undo, redo (1 detail), delete it while displayed
    LogMsg('5.5 L1: subreport add/delete undo/redo');
    mf.Structure.SelectDataItem(sub);
    nOps := cue.UndoOperations.Count;
    mf.Structure.MNewSectionClick(mf.Structure.MSubReport);
    CheckInt(2, rep.SubReports.Count, 'Add subreport');
    sub2 := rep.SubReports[1].SubReport;
    name2 := sub2.Name;
    CheckInt(nOps + 1, cue.UndoOperations.Count, 'Add subreport: one operation');
    Check((cue.UndoOperations.Last.operation = otAdd) and (cue.UndoOperations.Last.componentName = name2),
      'Add subreport recorded as otAdd');
    Check(frame.CurrentSubreport = sub2, 'The new subreport is displayed');
    CheckFrameInSync(frame, 'after adding a subreport');
    mf.DoUndo;
    sub2 := nil;
    CheckInt(1, rep.SubReports.Count, 'Undo of add subreport');
    Check(FindItem(rep, name2) = nil, 'Undo of add subreport frees it');
    CheckFrameInSync(frame, 'after undo of add subreport (the displayed subreport was freed)');
    mf.DoRedo;
    CheckInt(2, rep.SubReports.Count, 'Redo of add subreport');
    Check(FindItem(rep, name2) is TRpSubReport, 'Redo recreates the subreport with its name');
    sub2 := TRpSubReport(FindItem(rep, name2));
    CheckInt(1, sub2.Sections.Count, 'Redo of add subreport: one section');
    Check(sub2.Sections[0].Section.SectionType = rpsecdetail, 'Redo of add subreport: a detail section');
    secName2 := sub2.Sections[0].Section.Name;
    CheckFrameInSync(frame, 'after redo of add subreport');
    // Delete it while it is displayed
    mf.Structure.SelectDataItem(sub2);
    Check(frame.CurrentSubreport = sub2, 'Selecting the subreport node displays it');
    answered := Guard.MsgBoxesAnswered;
    Guard.ExpectMsgBoxes := 1;
    Guard.MsgBoxAnswer := smbOK;
    mf.Structure.DeleteSelectedNode;
    CheckInt(answered + 1, Guard.MsgBoxesAnswered, 'The subreport delete confirmation was asked');
    sub2 := nil;
    CheckInt(1, rep.SubReports.Count, 'Displayed subreport deleted');
    Check(frame.CurrentSubreport = rep.SubReports[0].SubReport, 'The remaining subreport is displayed');
    CheckFrameInSync(frame, 'after deleting the displayed subreport');
    mf.DoUndo;
    CheckInt(2, rep.SubReports.Count, 'Undo restores the deleted subreport');
    CheckStr(name2, rep.SubReports[1].SubReport.Name, 'Subreport restored at its index');
    sub2 := rep.SubReports[1].SubReport;
    CheckInt(1, sub2.Sections.Count, 'Restored subreport has its section');
    CheckStr(secName2, sub2.Sections[0].Section.Name, 'Restored subreport section name');
    CheckFrameInSync(frame, 'after undo of the subreport delete');
    k := 0;
    for i := 0 to rep.SubReports.Count - 1 do
      k := k + 1 + rep.SubReports[i].SubReport.Sections.Count;
    CheckInt(k, mf.Structure.RView.Items.Count, 'Structure tree after the subreport undo');
    mf.DoRedo;
    CheckInt(1, rep.SubReports.Count, 'Redo deletes the subreport again');
    CheckFrameInSync(frame, 'after redo of the subreport delete');

    // ---- L2: opening an invalid file keeps the current report
    LogMsg('5.5 L2: OpenReportFile with an invalid file');
    mf.FileName := 'C:\regression\original_name.rep';
    cue.MarkClean;
    Check(cue.CanUndo, 'There must be history before the failed open');
    oldRep := mf.Report;
    oldCue := cue;
    oldFile := mf.FileName;
    nOps := cue.UndoOperations.Count;
    tmp := IncludeTrailingPathDelimiter(GetTempDir) + 'rp_corrupt_test.rep';
    for k := 0 to 1 do
    begin
      ms := TMemoryStream.Create;
      try
        if k = 0 then
        begin
          garbage := 'ZZZZ this is not a report' + #0#1#2#3#255#254;
          ms.WriteBuffer(garbage[1], Length(garbage));
        end;
        ms.SaveToFile(tmp);
      finally
        ms.Free;
      end;
      raised := False;
      try
        mf.OpenReportFile(tmp);
      except
        on E: Exception do
        begin
          raised := True;
          LogMsg('OpenReportFile raised as expected: ' + E.ClassName + ': ' + E.Message);
        end;
      end;
      Check(raised, 'OpenReportFile of an invalid file must raise');
      Check(mf.Report = oldRep, 'Failed open: the current report object survives');
      CheckStr(oldFile, mf.FileName, 'Failed open: FileName survives');
      Check(mf.Report.UndoCue = oldCue, 'Failed open: the undo cue survives');
      CheckInt(nOps, oldCue.UndoOperations.Count, 'Failed open: the history survives');
      Check(Assigned(oldCue.OnChange), 'Failed open: the cue is still hooked to the designer');
      Check(frame.Report = oldRep, 'Failed open: the design frame still shows the report');
      CheckFrameInSync(frame, 'after a failed open');
      Check(mf.BtnUndo.Enabled, 'Failed open: Undo still available');
    end;
    DeleteFile(tmp);
    // A valid file replaces report, file name and history
    mf.OpenReportFile(ASamplePath);
    Check(mf.Report <> nil, 'Valid open: report loaded');
    CheckStr(ASamplePath, mf.FileName, 'Valid open: FileName');
    Check((mf.Report.UndoCue is TUndoCue) and not TUndoCue(mf.Report.UndoCue).CanUndo,
      'Valid open: history starts empty');
    Check(not mf.Report.Modified and not mf.BtnUndo.Enabled, 'Valid open: clean and no Undo');
    CheckFrameInSync(frame, 'after opening a valid file');
    // The designer form has no name (CreateNew): the FPC reader must not give
    // the report a unique name ("_1"), that would be saved with it
    CheckStr('', mf.Report.Name, 'Valid open: the report keeps no name');
    // Its MyBase file (FISH: biolife.cds, a relative name, a connection
    // without path) is next to the report, also when the current folder is
    // another one: macOS starts the application in /
    LogMsg('5.5 L2: MyBase data next to the report, from another current folder');
    oldFile := GetCurrentDir;
    SetCurrentDir(GetTempDir(False));
    try
      mf.Report.DataInfo.ItemByName('FISH').Connect(mf.Report.DatabaseInfo, mf.Report.Params);
      Check(mf.Report.DataInfo.ItemByName('FISH').Dataset.Active, 'MyBase next to the report: FISH open');
      Check(mf.Report.DataInfo.ItemByName('FISH').Dataset.RecordCount > 0,
        'MyBase next to the report: FISH has records');
    finally
      mf.Report.DeActivateDatasets;
      SetCurrentDir(oldFile);
    end;
  finally
    mf.Hide;
    mf.Free;
  end;
  LogMsg('Designer regression tests verified');
end;

{ Item interfaces: parity with the VCL designer }

const
  PROP_SEP = #9;

// Name/type pairs, in order, of the VCL designer GetProperties
// (rpmdobinsintvcl, rpmdflabelintvcl, rpmdfchartintvcl, rpmdfbarcodeintvcl,
// rpmdfdrawintvcl, rpmdfsectionintvcl)
procedure AddVCLProps(L: TStringList; const P: array of WideString);
var
  i: Integer;
begin
  i := 0;
  while i < High(P) do
  begin
    L.Add(string(P[i]) + PROP_SEP + string(P[i + 1]));
    Inc(i, 2);
  end;
end;

procedure VCLCommonProps(L: TStringList);
begin
  // TRpSizeInterface
  AddVCLProps(L, [SrpSPrintCondition, SRpSExpression, SrpSBeforePrint, SRpSExpression,
    SrpSAfterPrint, SRpSExpression, SrpSWidth, SRpSCurrency, SrpSHeight, SRpSCurrency]);
end;

procedure VCLPosProps(L: TStringList);
begin
  VCLCommonProps(L);
  // TRpSizePosInterface
  AddVCLProps(L, [SrpSTop, SRpSCurrency, SrpSLeft, SRpSCurrency, SRPAlign, SRpSList,
    SrpSAnnotation, SRpSExpression]);
end;

procedure VCLTextProps(L: TStringList);
begin
  VCLPosProps(L);
  // TRpGenTextInterface
  AddVCLProps(L, [SrpSAlignment, SRpSList, SrpSVAlignment, SRpSList,
    SrpSWFontName, SRpSWFontName, SrpSLFontName, SRpSLFontName,
    SRpSType1Font, SRpSList, SRpSFontStep, SRpSList, SrpSFontSize, SRpSFontSize,
    SrpSFontColor, SRpSColor, SrpSFontStyle, SrpSFontStyle, SrpSRightToLeft, SRpSList,
    SrpSBackColor, SRpSColor, SrpSTransparent, SRpSBool, SrpSCutText, SRpSBool,
    SrpSWordwrap, SRpSBool, SrpSSingleLine, SRpSBool, SRpSFontRotation, SrpSString]);
end;

procedure VCLLabelProps(L: TStringList);
begin
  VCLTextProps(L);
  AddVCLProps(L, [SrpSText, SRpSString, SRpIsHtml, SRpSBool]);
end;

procedure VCLExpressionProps(L: TStringList);
begin
  VCLTextProps(L);
  AddVCLProps(L, [SrpSExpression, SRpSExpression, SRpIsHtml, SRpSBool,
    SRpSDataType, SRpSList, SrpSDisplayFormat, SRpSString, SRpMultiPage, SRpSBool,
    SRpPrintNulls, SRpSBool, SrpSIdentifier, SRpSString, SrpSAggregate, SRpSList,
    SrpSAgeGroup, SRpGroup, SrpSAgeType, SRpSList, SrpSIniValue, SRpSExpression,
    SRpSOnlyOne, SRpSBool, SRpSExportExpression, SRpSExpression,
    SRpSExportFormat, SRpSString, SRpSExportLine, SRpSInteger,
    SRpSExportPos, SRpSInteger, SRpSExportSize, SRpSInteger,
    SRpSExportDoNewLine, SRpSBool]);
end;

procedure VCLChartProps(L: TStringList);
begin
  VCLTextProps(L);
  AddVCLProps(L, [SrpSExpression, SRpSExpression, SrpSIdentifier, SRpSString,
    SrpSChartType, SRpSList, SrpSGetValueCondition, SRpSExpression,
    SrpSChangeSerieExp, SRpSExpression, SrpSChangeSerieBool, SRpSBool,
    SrpSClearExpChart, SRpSExpression, SrpSBoolClearExp, SRpSBool,
    SrpSCaptionExp, SRpSExpression, SrpSExpression + ' X', SRpSExpression,
    SrpSSerieCaptionExp, SRpSExpression, SrpSDriver, SRpSList,
    SRpSView3D, SRpSBool, SRpSView3DWalls, SRpSBool, SRpSPerspective, SRpSInteger,
    SRpSElevation, SRpSInteger, SRpSRotation, SRpSInteger, SRpSOrthogonal, SRpSBool,
    SRpSZoom, SRpSInteger, SRpSHOffset, SRpSInteger, SRpSVOffset, SRpSInteger,
    SRpSTilt, SRpSInteger, SRpDPIRes, SRpSInteger, SRpSMultibar, SRpSList,
    SrpChartHint, SRpSBool, SrpChartLegend, SRpSBool, SRpMarkType, SRpSList,
    SRpSVertAxisFSize, SRpSInteger, SRpSHorzAxisFSize, SRpSInteger,
    SRpSVertAxisFRot, SRpSInteger, SRpSHorzAxisFRot, SRpSInteger,
    SrpSValueColor, SRpSExpression, SrpSSerieColor, SRpSExpression,
    SRpAutoRange, SRpSList, SRpAutoRangeYMin, SRpSCurrency, SRpAutoRangeYMax, SRpSCurrency]);
end;

procedure VCLBarcodeProps(L: TStringList);
begin
  VCLPosProps(L);
  AddVCLProps(L, [SRpSBarcodeType, SRpSList, SRpSChecksum, SRpSBool,
    SrpSModul, SRpSCurrency, SrpSRatio, SRpSCurrency, SrpSExpression, SRpSExpression,
    SrpSDisplayFormat, SRpSString, SRpSRotation, SrpSList, SrpSColor, SRpSColor,
    SrpSBackColor, SRpSColor, SrpSTransparent, SRpSBool, SRpECCLevel, SRpSList,
    SRpNumRows, SRpInteger, SRpNumCols, SRpInteger, SRpTruncatedPDF417, SRpSBool]);
end;

procedure VCLShapeProps(L: TStringList);
begin
  VCLPosProps(L);
  AddVCLProps(L, [SrpSShape, SRpSList, SrpSPenStyle, SRpSList, SrpSPenColor, SRpSColor,
    SrpSPenWidth, SRpSString, SrpSBrushStyle, SRpSList, SrpSBrushColor, SRpSColor]);
end;

procedure VCLImageProps(L: TStringList);
begin
  VCLPosProps(L);
  AddVCLProps(L, [SRpDrawStyle, SRpSList, SrpSExpression, SRpSExpression,
    SrpSImage, SRpSImage, SRpDPIRes, SRpSString, SRpCached, SRpSList]);
end;

procedure VCLDetailProps(L: TStringList);
begin
  VCLCommonProps(L);
  // TRpSectionInterface of a detail section
  AddVCLProps(L, [SRpSAutoExpand, SRpSBool, SRpSAutoContract, SRpSBool,
    SRpSBeginPage, SRpSExpression, SRpSkipPage, SRpSBool, SRPAlignBottom, SRpSBool,
    SRPHorzDesp, SRpSBool, SRPVertDesp, SRpSBool, SRpSSkipType, SRpSList,
    SRpSSkipToPage, SRpSExpression, SRpSHSkipExpre, SRpSExpression,
    SRpSHRelativeSkip, SRpSBool, SRpSVSkipExpre, SRpSExpression,
    SRpSVRelativeSkip, SRpSBool, SRpChildSubRep, SRpSList,
    SRpSExternalPath, SRpSExternalpath, SRpSExternalData, SRpSExternalData,
    SrpSBackExpression, SRpSExpression, SrpSImage, SRpSImage, SRpDPIRes, SRpSString,
    SRpSBackStyle, SRpSList, SRpDrawStyle, SRpSList, SRpCached, SRpSList]);
end;

// Properties that the model does not store or that are not edited as a value
function PropertyWithoutUndo(const pname: WideString): Boolean;
begin
  Result := (pname = SRpAutoRange) or (pname = SRpAutoRangeYMin) or
    (pname = SRpAutoRangeYMax) or (pname = SRpSExternalData);
end;

// The interface exposes exactly the VCL properties (names, types, order),
// its values match GetProperty and every property has a model property for
// undo with a value of the recorded type
procedure CheckInterfaceProps(aint: TRpSizeInterface; expected: TStringList;
  const Context: string);
var
  lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings;
  i: Integer;
  undoName: string;
  ptype: TPropertyType;
  v: Variant;
  typeOk: Boolean;
begin
  lnames := TRpWideStrings.Create;
  ltypes := TRpWideStrings.Create;
  lvalues := TRpWideStrings.Create;
  lhints := TRpWideStrings.Create;
  lcat := TRpWideStrings.Create;
  try
    aint.GetProperties(lnames, ltypes, lvalues, lhints, lcat);
    CheckInt(expected.Count, lnames.Count, Context + ': number of properties');
    CheckInt(lnames.Count, ltypes.Count, Context + ': property types');
    CheckInt(lnames.Count, lvalues.Count, Context + ': property values');
    CheckInt(lnames.Count, lhints.Count, Context + ': property hints');
    CheckInt(lnames.Count, lcat.Count, Context + ': property categories');
    for i := 0 to lnames.Count - 1 do
    begin
      CheckStr(expected[i], string(lnames.Strings[i]) + PROP_SEP + string(ltypes.Strings[i]),
        Format('%s: property %d (name/type)', [Context, i]));
      CheckStr(string(lvalues.Strings[i]), string(aint.GetProperty(lnames.Strings[i])),
        Context + ': GetProperties value of ' + string(lnames.Strings[i]));
      undoName := InspectorUndoProperty(aint.printitem, lnames.Strings[i], ptype);
      if PropertyWithoutUndo(lnames.Strings[i]) then
        Continue;
      Check(undoName <> '', Context + ': no undo property for ' + string(lnames.Strings[i]));
      try
        v := ReadUndoPropertyValue(aint.printitem, undoName);
      except
        on E: Exception do
          Fail(Context + ': the model can not read the undo property ' + undoName +
            ' of ' + string(lnames.Strings[i]) + ': ' + E.Message);
      end;
      case ptype of
        ptInteger: typeOk := VarIsOrdinal(v);
        ptNumber: typeOk := VarIsNumeric(v);
        ptBoolean: typeOk := VarType(v) = varBoolean;
      else
        typeOk := VarIsStr(v) or VarIsEmpty(v);
      end;
      Check(typeOk, Format('%s: undo property %s of %s has the variant type %d',
        [Context, undoName, string(lnames.Strings[i]), VarType(v)]));
    end;
  finally
    lnames.Free;
    ltypes.Free;
    lvalues.Free;
    lhints.Free;
    lcat.Free;
  end;
end;

function PossibleValue(aint: TRpSizeInterface; const pname: WideString; AIndex: Integer): WideString;
var
  l: TStringList;
begin
  l := TStringList.Create;
  try
    aint.GetPropertyValues(pname, l);
    Check(l.Count > AIndex, Format('%s has less than %d possible values', [string(pname), AIndex + 1]));
    Result := l[AIndex];
  finally
    l.Free;
  end;
end;

procedure CheckRoundTrip(aint: TRpSizeInterface; const pname, value: WideString;
  const Context: string);
begin
  aint.SetProperty(pname, value);
  CheckStr(string(value), string(aint.GetProperty(pname)), Context + ': ' + string(pname) + ' round trip');
end;

function RedBitmapStream(W, H: Integer): TMemoryStream;
var
  bmp: TBitmap;
begin
  Result := TMemoryStream.Create;
  bmp := TBitmap.Create;
  try
    bmp.PixelFormat := pf24bit;
    bmp.SetSize(W, H);
    bmp.Canvas.Brush.Color := clRed;
    bmp.Canvas.Brush.Style := bsSolid;
    bmp.Canvas.FillRect(0, 0, W, H);
    bmp.SaveToStream(Result);
  finally
    bmp.Free;
  end;
  Result.Position := 0;
end;

function IsRedPixel(ACanvas: TCanvas; X, Y: Integer): Boolean;
var
  c: TColor;
begin
  c := ColorToRGB(ACanvas.Pixels[X, Y]);
  Result := (Red(c) > 200) and (Green(c) < 80) and (Blue(c) < 80);
end;

// Paints the image item as the design surface does (the image, not a
// placeholder) and looks at the middle pixel
procedure CheckImagePainted(aint: TRpSizeInterface; AExpectImage: Boolean; const Context: string);
var
  bmp: TBitmap;
  imgint: TRpImageInterface;
begin
  Check(aint is TRpImageInterface, Context + ': not an image interface');
  imgint := TRpImageInterface(aint);
  bmp := TBitmap.Create;
  try
    bmp.SetSize(60, 60);
    bmp.Canvas.Brush.Color := clWhite;
    bmp.Canvas.Brush.Style := bsSolid;
    bmp.Canvas.FillRect(0, 0, 60, 60);
    imgint.DrawImageTo(bmp.Canvas, 60, 60);
    if AExpectImage then
    begin
      Check(Assigned(imgint.DesignBitmap), Context + ': the image stream must be decoded');
      Check(IsRedPixel(bmp.Canvas, 30, 30), Format('%s: the image must be painted (pixel %x, style %d, bitmap %dx%d)',
        [Context, ColorToRGB(bmp.Canvas.Pixels[30, 30]), Ord(TRpImage(imgint.printitem).DrawStyle),
         imgint.DesignBitmap.Width, imgint.DesignBitmap.Height]));
    end
    else
    begin
      Check(not Assigned(imgint.DesignBitmap), Context + ': no image expected');
      Check(not IsRedPixel(bmp.Canvas, 30, 30), Context + ': no image must be painted');
    end;
  finally
    bmp.Free;
  end;
end;

function MenuSignature(AItem: TMenuItem): string;
var
  i: Integer;
  mi: TMenuItem;
  cmd: TRpDesignCommand;
begin
  Result := '';
  for i := 0 to AItem.Count - 1 do
  begin
    mi := AItem.Items[i];
    if i > 0 then
      Result := Result + '|';
    cmd := MenuItemDesignCommand(mi);
    if cmd <> dcNone then
      Result := Result + '#' + IntToStr(Ord(cmd))
    else
      Result := Result + mi.Caption;
    if mi.Count > 0 then
      Result := Result + '[' + MenuSignature(mi) + ']';
  end;
end;

function SearchCommandItem(AItem: TMenuItem; ACommand: TRpDesignCommand): TMenuItem;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to AItem.Count - 1 do
  begin
    if MenuItemDesignCommand(AItem.Items[i]) = ACommand then
      Exit(AItem.Items[i]);
    if AItem.Items[i].Count > 0 then
    begin
      Result := SearchCommandItem(AItem.Items[i], ACommand);
      if Assigned(Result) then
        Exit;
    end;
  end;
end;

function FindCommandItem(AItem: TMenuItem; ACommand: TRpDesignCommand): TMenuItem;
begin
  Result := SearchCommandItem(AItem, ACommand);
  if not Assigned(Result) then
    Fail('Context menu without the designer command ' + IntToStr(Ord(ACommand)));
end;

function FindCaptionItem(AItem: TMenuItem; const ACaption: string): TMenuItem;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to AItem.Count - 1 do
    if AItem.Items[i].Caption = ACaption then
      Exit(AItem.Items[i]);
  Fail('Context menu without the item ' + ACaption);
end;

procedure TRegressionTests.TestItemInterfaces;
var
  mf: TFRpMainFLCL;
  rep: TRpReport;
  cue: TUndoCue;
  frame: TFRpDesignFrameLCL;
  sub: TRpSubReport;
  detail: TRpSection;
  secint: TRpSectionInterface;
  panel: TRpPanelObjLCL;
  aint: TRpSizeInterface;
  nLab, nLab2, nExp, nShape, nImage, nBar, nChart, dc, tmp, aval: string;
  expected: TStringList;
  op: TChangeObjectOperation;
  ms: TMemoryStream;
  bmp: TBitmap;
  nOps, cnt, origW, oldSize, i: Integer;
  raised: Boolean;
  img: TRpImage;

  procedure CheckUndoProp(const AName, pname, value, undoName: string;
    AType: TPropertyType; const Context: string);
  var
    oldText: string;
    item: TRpSizeInterface;
    prop: TChangeOperationItem;
  begin
    // AName '' is the detail section
    if AName = '' then
    begin
      item := SecIntOf(frame, FindSectionOfType(rep.SubReports[0].SubReport, rpsecdetail));
      mf.ObjInsp.AddCompItem(item, True);
    end
    else
    begin
      item := ChildInt(frame, AName);
      frame.SelectComponent(item, False);
    end;
    panel := mf.ObjInsp.CurrentPanel;
    Check(Assigned(panel) and (panel.CompItem = item), Context + ': the inspector shows the item');
    oldText := item.GetProperty(pname);
    Check(oldText <> value, Context + ': the new value must be a change');
    nOps := cue.UndoOperations.Count;
    panel.SetPropertyFull(pname, value);
    CheckStr(value, item.GetProperty(pname), Context + ': value set');
    CheckInt(nOps + 1, cue.UndoOperations.Count, Context + ': one undo operation');
    op := cue.UndoOperations.Last;
    CheckStr(item.printitem.Name, op.componentName, Context + ': recorded component');
    CheckInt(1, op.properties.Count, Context + ': recorded properties');
    prop := op.properties[0];
    CheckStr(undoName, prop.propertyName, Context + ': recorded model property');
    Check(prop.propertyType = AType, Context + ': recorded property type');
    case AType of
      ptInteger: Check(VarIsOrdinal(prop.oldValue) and VarIsOrdinal(prop.newValue),
        Context + ': integer model values');
      ptBoolean: Check((VarType(prop.oldValue) = varBoolean) and (VarType(prop.newValue) = varBoolean),
        Context + ': boolean model values');
      ptNumber: Check(VarIsNumeric(prop.newValue), Context + ': number model value');
    end;
    mf.DoUndo;
    if AName = '' then
      item := SecIntOf(frame, FindSectionOfType(rep.SubReports[0].SubReport, rpsecdetail))
    else
      item := ChildInt(frame, AName);
    CheckStr(oldText, item.GetProperty(pname), Context + ': undo restores the value');
    mf.DoRedo;
    if AName = '' then
      item := SecIntOf(frame, FindSectionOfType(rep.SubReports[0].SubReport, rpsecdetail))
    else
      item := ChildInt(frame, AName);
    CheckStr(value, item.GetProperty(pname), Context + ': redo applies the value');
  end;

begin
  LogMsg('Item interfaces: properties, context menu and painting as the VCL designer');
  mf := TFRpMainFLCL.Create(nil);
  expected := TStringList.Create;
  try
    mf.Show;
    Application.ProcessMessages;
    rep := mf.Report;
    cue := TUndoCue(rep.UndoCue);
    frame := mf.DesignerFrame;
    sub := rep.SubReports[0].SubReport;
    detail := FindSectionOfType(sub, rpsecdetail);
    secint := SecIntOf(frame, detail);
    Check(Assigned(secint), 'No interface for the detail section');
    nLab := secint.CreateNewComponent(dtLabel, 10, 5, 0, 0).printitem.Name;
    nLab2 := secint.CreateNewComponent(dtLabel, 10, 40, 0, 0).printitem.Name;
    nExp := secint.CreateNewComponent(dtExpression, 150, 5, 0, 0).printitem.Name;
    nShape := secint.CreateNewComponent(dtShape, 300, 5, 0, 0).printitem.Name;
    nImage := secint.CreateNewComponent(dtImage, 10, 70, 60, 60).printitem.Name;
    nBar := secint.CreateNewComponent(dtBarcode, 150, 70, 0, 0).printitem.Name;
    nChart := secint.CreateNewComponent(dtChart, 300, 70, 0, 0).printitem.Name;

    // ---- Every item exposes the properties of the VCL designer
    LogMsg('Items: property lists of the VCL designer');
    VCLLabelProps(expected);
    CheckInterfaceProps(ChildInt(frame, nLab), expected, 'Label');
    expected.Clear;
    VCLExpressionProps(expected);
    CheckInterfaceProps(ChildInt(frame, nExp), expected, 'Expression');
    expected.Clear;
    VCLChartProps(expected);
    CheckInterfaceProps(ChildInt(frame, nChart), expected, 'Chart');
    expected.Clear;
    VCLBarcodeProps(expected);
    CheckInterfaceProps(ChildInt(frame, nBar), expected, 'Barcode');
    expected.Clear;
    VCLShapeProps(expected);
    CheckInterfaceProps(ChildInt(frame, nShape), expected, 'Shape');
    expected.Clear;
    VCLImageProps(expected);
    CheckInterfaceProps(ChildInt(frame, nImage), expected, 'Image');
    expected.Clear;
    VCLDetailProps(expected);
    CheckInterfaceProps(secint, expected, 'Detail section');
    // The inspector builds an editor for each one
    frame.SelectComponent(ChildInt(frame, nChart), False);
    panel := mf.ObjInsp.CurrentPanel;
    Check(Assigned(panel) and (panel.CompItem = ChildInt(frame, nChart)), 'Inspector shows the chart');
    expected.Clear;
    VCLChartProps(expected);
    CheckInt(expected.Count, panel.ControlsList.Count, 'Chart inspector editors');
    mf.ObjInsp.AddCompItem(secint, True);
    expected.Clear;
    VCLDetailProps(expected);
    CheckInt(expected.Count, mf.ObjInsp.CurrentPanel.ControlsList.Count, 'Section inspector editors');
    // A chart is a text item: common class with a label
    frame.SelectComponent(ChildInt(frame, nLab), False);
    frame.SelectComponent(ChildInt(frame, nChart), True);
    CheckStr('TRpGenTextInterface', mf.ObjInsp.CurrentPanel.CompItem.ClassName,
      'Common inspector class of a label and a chart');

    // ---- Set/Get round trips
    LogMsg('Items: property set/get round trips');
    aint := ChildInt(frame, nLab);
    CheckRoundTrip(aint, SrpSWordwrap, BoolToStr(True, True), 'Label');
    Check(TRpLabel(aint.printitem).WordWrap, 'Label WordWrap in the model');
    CheckRoundTrip(aint, SrpSVAlignment, SrpSAlignCenter, 'Label');
    CheckInt(AlignmentFlags_AlignVCenter, TRpLabel(aint.printitem).VAlignment, 'Label VAlignment in the model');
    CheckRoundTrip(aint, SrpSAlignment, SrpSAlignRight, 'Label');
    CheckRoundTrip(aint, SRpSType1Font, PossibleValue(aint, SRpSType1Font, 1), 'Label');
    CheckRoundTrip(aint, SRpSFontStep, PossibleValue(aint, SRpSFontStep, 1), 'Label');
    CheckRoundTrip(aint, SrpSRightToLeft, PossibleValue(aint, SrpSRightToLeft, 1), 'Label');
    CheckRoundTrip(aint, SrpSBackColor, '255', 'Label');
    CheckRoundTrip(aint, SrpSLFontName, 'Courier New', 'Label');
    CheckRoundTrip(aint, SRpSFontRotation, FormatCurr('#####0.0', 45.5), 'Label');
    CheckInt(455, TRpLabel(aint.printitem).FontRotation, 'Label FontRotation in the model');
    CheckRoundTrip(aint, SRpIsHtml, BoolToStr(True, True), 'Label');
    CheckRoundTrip(aint, SrpSAnnotation, 'ANNOT', 'Label');
    CheckStr('ANNOT', TRpLabel(aint.printitem).AnnotationExpression, 'Label annotation in the model');
    aint.SetProperty(SRpIsHtml, BoolToStr(False, True));

    aint := ChildInt(frame, nExp);
    CheckRoundTrip(aint, SrpSAggregate, SRpGroup, 'Expression');
    Check(TRpExpression(aint.printitem).Aggregate = rpAgGroup, 'Expression aggregate in the model');
    CheckRoundTrip(aint, SrpSAgeType, PossibleValue(aint, SrpSAgeType, 2), 'Expression');
    Check(TRpExpression(aint.printitem).AgType = rpagMax, 'Expression aggregate type in the model');
    CheckRoundTrip(aint, SRpSDataType, PossibleValue(aint, SRpSDataType, 1), 'Expression');
    CheckRoundTrip(aint, SRpSExportLine, '3', 'Expression');
    CheckInt(3, TRpExpression(aint.printitem).ExportLine, 'Expression export line in the model');
    CheckRoundTrip(aint, SRpMultiPage, BoolToStr(True, True), 'Expression');
    CheckRoundTrip(aint, SRpPrintNulls, BoolToStr(True, True), 'Expression');
    CheckRoundTrip(aint, SrpSIniValue, '5', 'Expression');
    CheckRoundTrip(aint, SRpSExportFormat, '0.00', 'Expression');

    aint := ChildInt(frame, nChart);
    CheckRoundTrip(aint, SrpSChartType, PossibleValue(aint, SrpSChartType, 1), 'Chart');
    CheckRoundTrip(aint, SRpSZoom, '150', 'Chart');
    CheckInt(150, TRpChart(aint.printitem).Zoom, 'Chart zoom in the model');
    CheckRoundTrip(aint, SRpSRotation, '30', 'Chart');
    CheckInt(30, TRpChart(aint.printitem).Rotation, 'Chart rotation in the model');
    CheckRoundTrip(aint, SrpSDriver, PossibleValue(aint, SrpSDriver, 1), 'Chart');
    CheckRoundTrip(aint, SRpSMultibar, PossibleValue(aint, SRpSMultibar, 1), 'Chart');
    CheckRoundTrip(aint, SRpMarkType, PossibleValue(aint, SRpMarkType, 1), 'Chart');
    CheckRoundTrip(aint, SrpSExpression + ' X', 'X+1', 'Chart');
    CheckStr('X+1', TRpChart(aint.printitem).ValueXExpression, 'Chart X expression in the model');
    CheckRoundTrip(aint, SrpChartLegend, BoolToStr(True, True), 'Chart');
    CheckRoundTrip(aint, SRpAutoRange, PossibleValue(aint, SRpAutoRange, 1), 'Chart');
    CheckRoundTrip(aint, SRpAutoRangeYMax, FormatCurr('#####0.00', 12.5), 'Chart');
    Check(TRpChart(aint.printitem).YMax = 12.5, 'Chart Y max in the model');
    CheckRoundTrip(aint, SrpSFontSize, '14', 'Chart (text property)');

    aint := ChildInt(frame, nBar);
    CheckRoundTrip(aint, SRpSBarcodeType, 'QR', 'Barcode');
    Check(TRpBarcode(aint.printitem).Typ = bcCodeQr, 'Barcode type in the model');
    CheckRoundTrip(aint, SRpSChecksum, BoolToStr(True, True), 'Barcode');
    CheckRoundTrip(aint, SrpSRatio, FormatCurr('#####0.00', 2.5), 'Barcode');
    Check(TRpBarcode(aint.printitem).Ratio = 2.5, 'Barcode ratio in the model');
    CheckRoundTrip(aint, SRpSRotation, PossibleValue(aint, SRpSRotation, 1), 'Barcode');
    CheckInt(900, TRpBarcode(aint.printitem).Rotation, 'Barcode rotation in the model');
    CheckRoundTrip(aint, SrpSColor, '255', 'Barcode');
    CheckInt(255, TRpBarcode(aint.printitem).BColor, 'Barcode color in the model');
    CheckRoundTrip(aint, SRpECCLevel, PossibleValue(aint, SRpECCLevel, 2), 'Barcode');
    CheckRoundTrip(aint, SRpNumRows, '4', 'Barcode');
    CheckRoundTrip(aint, SRpTruncatedPDF417, BoolToStr(True, True), 'Barcode');

    aint := ChildInt(frame, nShape);
    CheckRoundTrip(aint, SrpSShape, StringShapeType[rpsEllipse], 'Shape');
    Check(TRpShape(aint.printitem).Shape = rpsEllipse, 'Shape type in the model');
    CheckRoundTrip(aint, SrpSPenStyle, StringPenStyle[5], 'Shape');
    CheckInt(5, TRpShape(aint.printitem).PenStyle, 'Shape pen style (VCL psClear) in the model');
    Check(RpPenStyleToPenStyle(5) = psClear, 'Model pen style 5 is painted as psClear');
    CheckRoundTrip(aint, SrpSBrushStyle, StringBrushStyle[rpbsCross], 'Shape');
    CheckInt(Ord(rpbsCross), TRpShape(aint.printitem).BrushStyle, 'Shape brush style in the model');
    CheckRoundTrip(aint, SrpSPenColor, '255', 'Shape');

    aint := ChildInt(frame, nImage);
    CheckRoundTrip(aint, SRpDrawStyle, PossibleValue(aint, SRpDrawStyle, 1), 'Image');
    CheckRoundTrip(aint, SRpDPIRes, '200', 'Image');
    CheckInt(200, TRpImage(aint.printitem).dpires, 'Image resolution in the model');
    CheckRoundTrip(aint, SRpCached, PossibleValue(aint, SRpCached, 1), 'Image');

    CheckRoundTrip(secint, SRpSHSkipExpre, 'HSKIP', 'Section');
    CheckStr('HSKIP', detail.SkipExpreH, 'Section horizontal skip in the model');
    CheckRoundTrip(secint, SRpSVRelativeSkip, BoolToStr(True, True), 'Section');
    CheckRoundTrip(secint, SRpSBackStyle, PossibleValue(secint, SRpSBackStyle, 1), 'Section');
    CheckRoundTrip(secint, SRpDrawStyle, PossibleValue(secint, SRpDrawStyle, 1), 'Section');
    CheckRoundTrip(secint, SRpDPIRes, '150', 'Section');
    CheckRoundTrip(secint, SRpSExternalPath, 'external_test.rep', 'Section');
    secint.SetProperty(SRpSExternalPath, '');

    // ---- Inspector edits of the new properties record model values
    LogMsg('Items: undo/redo of the new inspector properties');
    CheckUndoProp(nLab, SrpSWordwrap, BoolToStr(False, True), 'wordWrap', ptBoolean, 'Label word wrap');
    CheckUndoProp(nLab, SrpSRightToLeft, PossibleValue(ChildInt(frame, nLab), SrpSRightToLeft, 2),
      'bidiModes', ptString, 'Label BiDi mode');
    CheckUndoProp(nLab, SrpSAnnotation, 'ANNOT2', 'annotationExpression', ptString, 'Label annotation');
    CheckUndoProp(nLab, SRpSType1Font, PossibleValue(ChildInt(frame, nLab), SRpSType1Font, 2),
      'type1Font', ptInteger, 'Label PDF font');
    CheckUndoProp(nExp, SrpSAggregate, SRpPage, 'aggregate', ptInteger, 'Expression aggregate');
    CheckUndoProp(nExp, SRpSExportDoNewLine, BoolToStr(True, True), 'exportDoNewLine', ptBoolean,
      'Expression export new line');
    CheckUndoProp(nExp, SrpSAgeGroup, 'GROUPTEST', 'groupName', ptString, 'Expression aggregate group');
    CheckUndoProp(nChart, SRpSZoom, '175', 'zoom', ptInteger, 'Chart zoom');
    CheckUndoProp(nChart, SrpSChartType, PossibleValue(ChildInt(frame, nChart), SrpSChartType, 2),
      'chartStyle', ptInteger, 'Chart type');
    CheckUndoProp(nChart, SrpSExpression, 'VALUE2', 'valueExpression', ptString, 'Chart value expression');
    CheckUndoProp(nBar, SRpSBarcodeType, 'Code39', 'barType', ptInteger, 'Barcode type');
    CheckUndoProp(nBar, SrpSRatio, FormatCurr('#####0.00', 3.25), 'ratio', ptNumber, 'Barcode ratio');
    CheckUndoProp(nShape, SrpSPenStyle, StringPenStyle[2], 'penStyle', ptInteger, 'Shape pen style');
    CheckUndoProp(nShape, SrpSBrushStyle, StringBrushStyle[rpbsDiagCross], 'brushStyle', ptInteger,
      'Shape brush style');
    CheckUndoProp(nImage, SRpDPIRes, '300', 'dpiRes', ptInteger, 'Image resolution');
    CheckUndoProp('', SRpSHSkipExpre, 'HSKIP2', 'skipExpreH', ptString, 'Section horizontal skip');
    CheckUndoProp('', SRpSBackStyle, PossibleValue(SecIntOf(frame, detail), SRpSBackStyle, 2),
      'backStyle', ptInteger, 'Section back style');

    // ---- Images: the inspector stream path, painting and undo of the stream
    LogMsg('Items: image stream, painting and undo');
    ms := RedBitmapStream(8, 8);
    try
      TRpImage(FindItem(rep, nImage)).DrawStyle := rpDrawStretch;
      CheckImagePainted(ChildInt(frame, nImage), False, 'Image without stream');
      frame.SelectComponent(ChildInt(frame, nImage), False);
      panel := mf.ObjInsp.CurrentPanel;
      nOps := cue.UndoOperations.Count;
      panel.SetPropertyFull(SrpSImage, ms);
      img := TRpImage(FindItem(rep, nImage));
      CheckInt(ms.Size, img.Stream.Size, 'Image loaded through the inspector');
      CheckInt(nOps + 1, cue.UndoOperations.Count, 'Image load: one undo operation');
      CheckStr('streamBase64', cue.UndoOperations.Last.properties[0].propertyName,
        'Image load recorded as streamBase64');
      Check(ChildInt(frame, nImage).GetProperty(SrpSImage) <>
        '[' + FormatFloat('###,###0.00', 0) + SRpKbytes + ']', 'Image size shown in the inspector');
      CheckImagePainted(ChildInt(frame, nImage), True, 'Image loaded');
      mf.DoUndo;
      CheckInt(0, TRpImage(FindItem(rep, nImage)).Stream.Size, 'Undo of the image load');
      CheckImagePainted(ChildInt(frame, nImage), False, 'After undo of the image load');
      mf.DoRedo;
      CheckInt(ms.Size, TRpImage(FindItem(rep, nImage)).Stream.Size, 'Redo of the image load');
      CheckImagePainted(ChildInt(frame, nImage), True, 'After redo of the image load');
      // An expression replaces the image: both recorded, stream first
      frame.SelectComponent(ChildInt(frame, nImage), False);
      panel := mf.ObjInsp.CurrentPanel;
      panel.SetPropertyFull(SrpSExpression, 'IMGEXPR');
      img := TRpImage(FindItem(rep, nImage));
      Check((img.Stream.Size = 0) and (img.Expression = 'IMGEXPR'), 'An image expression clears the stream');
      op := cue.UndoOperations.Last;
      CheckInt(2, op.properties.Count, 'Image expression: stream and expression recorded');
      CheckStr('streamBase64', op.properties[0].propertyName, 'Image expression: stream recorded first');
      CheckStr('expression', op.properties[1].propertyName, 'Image expression: expression recorded');
      mf.DoUndo;
      img := TRpImage(FindItem(rep, nImage));
      Check((img.Stream.Size = ms.Size) and (img.Expression = ''), 'Undo restores the image and the expression');
      mf.DoRedo;
      img := TRpImage(FindItem(rep, nImage));
      Check((img.Stream.Size = 0) and (img.Expression = 'IMGEXPR'), 'Redo of the image expression');
      mf.DoUndo;
      // Context menu actions: open a file, clear
      tmp := IncludeTrailingPathDelimiter(GetTempDir) + 'rp_item_image_test.bmp';
      ms.SaveToFile(tmp);
      TRpImageInterface(ChildInt(frame, nImage)).ClearImage;
      CheckInt(0, TRpImage(FindItem(rep, nImage)).Stream.Size, 'Clear image');
      TRpImageInterface(ChildInt(frame, nImage)).LoadImageFromFile(tmp);
      CheckInt(ms.Size, TRpImage(FindItem(rep, nImage)).Stream.Size, 'Load image from a file');
      CheckStr('streamBase64', cue.UndoOperations.Last.properties[0].propertyName,
        'Load image recorded as streamBase64');
      mf.DoUndo;
      CheckInt(0, TRpImage(FindItem(rep, nImage)).Stream.Size, 'Undo of the image file load');
      mf.DoUndo;
      CheckInt(ms.Size, TRpImage(FindItem(rep, nImage)).Stream.Size, 'Undo of the image clear');
      DeleteFile(tmp);
      // Section background image
      secint := SecIntOf(frame, detail);
      secint.SetPropertyUndo(SrpSImage, ms);
      CheckInt(ms.Size, detail.Stream.Size, 'Section background image');
      bmp := TBitmap.Create;
      try
        bmp.SetSize(100, 40);
        secint.DrawBackground(bmp.Canvas, 100, 40);
        Check(IsRedPixel(bmp.Canvas, 2, 2), 'The section background image is painted');
        mf.DoUndo;
        CheckInt(0, detail.Stream.Size, 'Undo of the section background image');
        secint := SecIntOf(frame, detail);
        secint.DrawBackground(bmp.Canvas, 100, 40);
        Check(not IsRedPixel(bmp.Canvas, 2, 2), 'No section background after the undo');
      finally
        bmp.Free;
      end;
    finally
      ms.Free;
    end;

    // ---- Context menus: items of the VCL designer and designer commands
    LogMsg('Items: context menus');
    dc := '#1|#2|#3|#4|-|#5|#6|-|' + TranslateStr(31, 'Align') + '[#7|#8|#9|#10|#11|#12]|-|#13';
    CheckStr(string(SRpRename) + '|' + string(SRpSetFontPropsAsDefault) + '|-|' + dc,
      MenuSignature(ChildInt(frame, nLab).PopupMenu.Items), 'Label context menu');
    Check(ChildInt(frame, nLab).PopupMenu = TRpSizePosInterface(ChildInt(frame, nLab)).ContextMenu,
      'Components show their own context menu');
    CheckStr(string(SRpRename) + '|' + string(SRpSetFontPropsAsDefault) + '|-|' + dc,
      MenuSignature(TRpSizePosInterface(ChildInt(frame, nChart)).ContextMenu.Items), 'Chart context menu');
    CheckStr(string(SRpRename) + '|-|' + dc,
      MenuSignature(TRpSizePosInterface(ChildInt(frame, nShape)).ContextMenu.Items), 'Shape context menu');
    CheckStr(string(SRpRename) + '|' + string(SrpSImage) + '[' + TranslateStr(9, 'Cut') + '|' +
      TranslateStr(10, 'Copy') + '|' + TranslateStr(11, 'Paste') + '|' + TranslateStr(42, 'Open') +
      ']|-|' + dc, MenuSignature(TRpSizePosInterface(ChildInt(frame, nImage)).ContextMenu.Items),
      'Image context menu');
    CheckStr(dc, MenuSignature(frame.DesignPopupMenu.Items), 'Design surface context menu');

    // Enabled state follows the selection
    frame.SelectComponent(ChildInt(frame, nLab), False);
    TRpSizePosInterface(ChildInt(frame, nLab)).UpdateContextMenu;
    with TRpSizePosInterface(ChildInt(frame, nLab)).ContextMenu do
    begin
      Check(FindCommandItem(Items, dcDelete).Enabled, 'Delete enabled with a selection');
      Check(FindCommandItem(Items, dcCopy).Enabled, 'Copy enabled with a selection');
      Check(not FindCommandItem(Items, dcAlignLeft).Enabled, 'Align needs two components');
    end;
    // Align left of two labels from the context menu
    TRpLabel(FindItem(rep, nLab)).PosX := 500;
    TRpLabel(FindItem(rep, nLab2)).PosX := 900;
    frame.SelectComponent(ChildInt(frame, nLab), False);
    frame.SelectComponent(ChildInt(frame, nLab2), True);
    TRpSizePosInterface(ChildInt(frame, nLab2)).UpdateContextMenu;
    Check(FindCommandItem(TRpSizePosInterface(ChildInt(frame, nLab2)).ContextMenu.Items, dcAlignLeft).Enabled,
      'Align enabled with two components');
    nOps := cue.UndoOperations.Count;
    FindCommandItem(TRpSizePosInterface(ChildInt(frame, nLab2)).ContextMenu.Items, dcAlignLeft).Click;
    CheckInt(500, TRpLabel(FindItem(rep, nLab2)).PosX, 'Align left from the context menu');
    CheckInt(nOps + 1, cue.UndoOperations.Count, 'Align left: one undo operation');
    mf.DoUndo;
    CheckInt(900, TRpLabel(FindItem(rep, nLab2)).PosX, 'Undo of align left');
    // Bring to front from the component menu
    frame.SelectComponent(ChildInt(frame, nLab), False);
    TRpSizePosInterface(ChildInt(frame, nLab)).UpdateContextMenu;
    FindCommandItem(TRpSizePosInterface(ChildInt(frame, nLab)).ContextMenu.Items, dcBringToFront).Click;
    CheckStr(nLab, detail.ReportComponents[detail.ReportComponents.Count - 1].Component.Name,
      'Bring to front from the context menu');
    mf.DoUndo;
    CheckStr(nLab, detail.ReportComponents[0].Component.Name, 'Undo of bring to front');
    // Delete from the design surface menu
    frame.SelectComponent(ChildInt(frame, nShape), False);
    frame.DesignPopupMenu.OnPopup(frame.DesignPopupMenu);
    Check(FindCommandItem(frame.DesignPopupMenu.Items, dcDelete).Enabled, 'Surface menu: delete enabled');
    FindCommandItem(frame.DesignPopupMenu.Items, dcDelete).Click;
    Check(FindItem(rep, nShape) = nil, 'Delete from the context menu');
    mf.DoUndo;
    Check(FindItem(rep, nShape) is TRpShape, 'Undo of the delete');
    CheckFrameInSync(frame, 'after the context menu delete');
    // Copy and paste from the component menu
    frame.SelectComponent(ChildInt(frame, nLab), False);
    TRpSizePosInterface(ChildInt(frame, nLab)).UpdateContextMenu;
    Check(FindCommandItem(TRpSizePosInterface(ChildInt(frame, nLab)).ContextMenu.Items, dcPaste).Enabled,
      'Paste enabled');
    FindCommandItem(TRpSizePosInterface(ChildInt(frame, nLab)).ContextMenu.Items, dcCopy).Click;
    cnt := detail.ReportComponents.Count;
    FindCommandItem(TRpSizePosInterface(ChildInt(frame, nLab)).ContextMenu.Items, dcPaste).Click;
    CheckInt(cnt + 1, detail.ReportComponents.Count, 'Paste from the context menu');
    mf.DoUndo;
    CheckInt(cnt, detail.ReportComponents.Count, 'Undo of the paste');
    // Select all from the design surface menu
    frame.DesignPopupMenu.OnPopup(frame.DesignPopupMenu);
    Check(FindCommandItem(frame.DesignPopupMenu.Items, dcSelectAll).Enabled, 'Surface menu: select all enabled');
    FindCommandItem(frame.DesignPopupMenu.Items, dcSelectAll).Click;
    cnt := 0;
    for i := 0 to frame.secinterfaces.Count - 1 do
      cnt := cnt + TRpSectionInterface(frame.secinterfaces[i]).childlist.Count;
    CheckInt(cnt, frame.SelectedItems.Count, 'Select all from the context menu');

    // Set font as default (menu item of text components)
    frame.SelectComponent(ChildInt(frame, nLab), False);
    mf.ObjInsp.CurrentPanel.SetPropertyFull(SrpSFontSize, '23');
    oldSize := rep.FontSize;
    Check(oldSize <> 23, 'The report font size must change');
    FindCaptionItem(TRpSizePosInterface(ChildInt(frame, nLab)).ContextMenu.Items,
      SRpSetFontPropsAsDefault).Click;
    CheckInt(23, rep.FontSize, 'Set font as default');
    CheckStr('REPORT', cue.UndoOperations.Last.componentName, 'Set font as default recorded on the report');
    mf.DoUndo;
    CheckInt(oldSize, rep.FontSize, 'Undo of set font as default');

    // Rename: the history follows the new name
    frame.SelectComponent(ChildInt(frame, nLab), False);
    origW := TRpLabel(FindItem(rep, nLab)).Width;
    mf.ObjInsp.CurrentPanel.SetPropertyFull(SrpSWidth, gettextfromtwips(origW + 300));
    TRpSizePosInterface(ChildInt(frame, nLab)).RenameComponent('RENAMEDLABEL');
    Check(FindItem(rep, 'RENAMEDLABEL') is TRpLabel, 'Rename');
    Check(FindItem(rep, nLab) = nil, 'The old name is free');
    CheckStr('RENAMEDLABEL', cue.UndoOperations.Last.componentName, 'The history follows the rename');
    Check(rep.Modified, 'A rename marks the report modified');
    mf.DoUndo;
    CheckInt(origW, TRpLabel(FindItem(rep, 'RENAMEDLABEL')).Width, 'Undo after a rename');
    nLab := 'RENAMEDLABEL';
    raised := False;
    try
      TRpSizePosInterface(ChildInt(frame, nLab)).RenameComponent(nLab2);
    except
      raised := True;
    end;
    Check(raised, 'Rename to an existing name must fail');

    // Multiple selection of text items: one undo group
    frame.SelectComponent(ChildInt(frame, nLab), False);
    frame.SelectComponent(ChildInt(frame, nExp), True);
    panel := mf.ObjInsp.CurrentPanel;
    CheckStr('TRpGenTextInterface', panel.CompItem.ClassName, 'Common class of a label and an expression');
    aval := BoolToStr(not TRpLabel(FindItem(rep, nLab)).CutText, True);
    nOps := cue.UndoOperations.Count;
    panel.SetPropertyFull(SrpSCutText, aval);
    CheckInt(nOps + 2, cue.UndoOperations.Count, 'Cut text on two items: operations');
    CheckLastOpsGroup(cue, 2, otModify, 'Cut text on two items');
    mf.DoUndo;
    CheckInt(nOps, cue.UndoOperations.Count, 'Both cut text operations undone together');
    CheckFrameInSync(frame, 'after the item interface tests');
  finally
    expected.Free;
    mf.Hide;
    mf.Free;
  end;
  LogMsg('Item interfaces verified');
end;

{ L2: dialogs }

procedure TRegressionTests.TestParamsDialog;
var
  rep: TRpReport;
  cue: TUndoCue;
  dlg: TFRpParamsLCL;
  p: TRpParam;
  nOps, idx: Integer;
  raised: Boolean;
begin
  LogMsg('5.5 L2: parameter definition dialog (without ShowModal)');
  rep := TRpReport.Create(nil);
  try
    rep.AddSubReport;
    rep.UndoCue := TUndoCue.Create(rep);
    cue := TUndoCue(rep.UndoCue);
    p := rep.Params.Add('PSTR');
    p.Description := 'Desc1';
    p.Value := 'abc';
    p := rep.Params.Add('PINT');
    p.ParamType := rpParamInteger;
    p.Value := 5;

    // OK path: edits in the working copy, recorded and applied on OK
    dlg := TFRpParamsLCL.Create(nil);
    try
      dlg.Report := rep;
      dlg.Params.Assign(rep.Params);
      dlg.DataInfo := rep.DataInfo;
      dlg.FillParamList;
      CheckInt(2, dlg.LParams.Items.Count, 'Params dialog: parameter list');
      CheckInt(0, dlg.LParams.ItemIndex, 'Params dialog: first parameter selected');
      Check(dlg.PageControl1.Visible, 'Params dialog: property pages visible');
      CheckStr('Desc1', dlg.EDescription.Text, 'Params dialog: description shown');
      dlg.EDescription.Text := 'Desc changed';
      dlg.EDescription.OnChange(dlg.EDescription);
      CheckStr('Desc changed', dlg.Params.ParamByName('PSTR').Description, 'Description edited in the working copy');
      CheckStr('Desc1', rep.Params.ParamByName('PSTR').Description, 'Report untouched before OK');
      dlg.LParams.ItemIndex := 1;
      dlg.LParams.OnClick(dlg.LParams);
      CheckStr('5', dlg.EValue.Text, 'Integer value shown');
      dlg.EValue.Text := '42';
      dlg.EValue.OnExit(dlg.EValue);
      CheckStr('42', VarToStr(dlg.Params.ParamByName('PINT').Value), 'Value edited in the working copy');
      dlg.BOK.OnClick(dlg.BOK);
      Check(dlg.DoOk, 'OK accepted');
      // What ShowParamDef does after the dialog is accepted
      nOps := cue.UndoOperations.Count;
      RecordParamUndoChanges(rep.Params, dlg.Params, rep);
      rep.Params.Assign(dlg.Params);
      CheckInt(nOps + 2, cue.UndoOperations.Count, 'Params OK: one modify per changed parameter');
      CheckLastOpsGroup(cue, 2, otModify, 'Params OK');
      CheckStr('Desc changed', rep.Params.ParamByName('PSTR').Description, 'Params OK applied the description');
      CheckStr('42', VarToStr(rep.Params.ParamByName('PINT').Value), 'Params OK applied the value');
      Check(rep.Modified, 'Params OK marks the report modified');
      cue.Undo.Free;
      CheckStr('Desc1', rep.Params.ParamByName('PSTR').Description, 'Undo restores the description');
      CheckStr('5', VarToStr(rep.Params.ParamByName('PINT').Value), 'Undo restores the value');
      cue.Redo.Free;
      CheckStr('Desc changed', rep.Params.ParamByName('PSTR').Description, 'Redo re-applies the description');
      CheckStr('42', VarToStr(rep.Params.ParamByName('PINT').Value), 'Redo re-applies the value');
    finally
      dlg.Free;
    end;

    // Type change resets the value, invalid integer blocks OK
    dlg := TFRpParamsLCL.Create(nil);
    try
      dlg.Report := rep;
      dlg.Params.Assign(rep.Params);
      dlg.FillParamList;
      CheckStr('abc', dlg.EValue.Text, 'String value shown');
      idx := dlg.ComboDataType.Items.IndexOf(ParamTypeToString(rpParamInteger));
      Check(idx >= 0, 'Integer type in the data type combo');
      dlg.ComboDataType.ItemIndex := idx;
      dlg.ComboDataType.OnChange(dlg.ComboDataType);
      p := dlg.Params.ParamByName('PSTR');
      Check(p.ParamType = rpParamInteger, 'Type changed to integer');
      CheckStr('0', VarToStr(p.Value), 'Changing the type resets the value to the type default');
      CheckStr('0', dlg.EValue.Text, 'Value edit shows the reset value');
      dlg.EValue.Text := 'abc';
      raised := False;
      try
        dlg.BOK.OnClick(dlg.BOK);
      except
        on E: EConvertError do
          raised := True;
      end;
      Check(raised, 'An invalid integer value must raise on OK');
      Check(not dlg.DoOk, 'An invalid integer value must block OK');
      Check(dlg.ModalResult <> mrOk, 'An invalid integer value must keep the dialog open');
    finally
      dlg.Free;
    end;

    // Deleting the last parameter hides the property pages
    dlg := TFRpParamsLCL.Create(nil);
    try
      dlg.Report := rep;
      dlg.Params.Assign(rep.Params);
      dlg.FillParamList;
      dlg.BDelete.OnClick(dlg.BDelete);
      dlg.BDelete.OnClick(dlg.BDelete);
      CheckInt(0, dlg.Params.Count, 'All parameters deleted');
      CheckInt(0, dlg.LParams.Items.Count, 'Parameter list empty');
      Check(not dlg.PageControl1.Visible, 'Deleting the last parameter hides the property pages');
      Check(not dlg.BDelete.Enabled and not dlg.BRename.Enabled, 'Delete/Rename disabled without parameters');
      dlg.BOK.OnClick(dlg.BOK);
      Check(dlg.DoOk, 'OK with no parameters');
      nOps := cue.UndoOperations.Count;
      RecordParamUndoChanges(rep.Params, dlg.Params, rep);
      rep.Params.Assign(dlg.Params);
      CheckInt(nOps + 2, cue.UndoOperations.Count, 'Removing both parameters: two operations');
      CheckLastOpsGroup(cue, 2, otRemove, 'Remove parameters');
      CheckInt(0, rep.Params.Count, 'Parameters removed from the report');
      // Regression: removed parameters used to be recorded with their values in
      // oldValue, while otRemove is restored from newValue, so undo recreated
      // them empty (and the second one raised "parameter already exists")
      cue.Undo.Free;
      CheckInt(2, rep.Params.Count, 'Undo restores the removed parameters');
      CheckStr('PSTR', rep.Params.Items[0].Name, 'Undo restores the parameter order (0)');
      CheckStr('PINT', rep.Params.Items[1].Name, 'Undo restores the parameter order (1)');
      CheckStr('Desc changed', rep.Params.ParamByName('PSTR').Description, 'Undo restores parameter properties');
      Check(rep.Params.ParamByName('PINT').ParamType = rpParamInteger, 'Undo restores the parameter type');
    finally
      dlg.Free;
    end;
  finally
    rep.Free;
  end;
  LogMsg('Parameter dialog verified');
end;

procedure TRegressionTests.TestDataConfig;
var
  rep: TRpReport;
  cue: TUndoCue;
  dlg: TFRpDInfoLCL;
  ds: TRpDataInfoItem;
  nOps: Integer;
begin
  LogMsg('5.5 L2: data configuration dialog working copies');
  rep := TRpReport.Create(nil);
  try
    rep.AddSubReport;
    rep.UndoCue := TUndoCue.Create(rep);
    cue := TUndoCue(rep.UndoCue);
    rep.DatabaseInfo.Add('CONN1');
    ds := rep.DataInfo.Add('DS1');
    ds.DatabaseAlias := 'CONN1';
    ds.SQL := 'SELECT 1';
    ds := rep.DataInfo.Add('DS2');
    ds.DatabaseAlias := 'CONN1';
    ds.SQL := 'SELECT 2';
    cue.MarkClean;

    // Cancel: working copies are discarded
    dlg := TFRpDInfoLCL.Create(nil);
    try
      dlg.Report := rep;
      Check(dlg.WorkReport.DataInfo <> rep.DataInfo, 'The dialog edits working copies');
      dlg.MonacoEditor.SQL := 'SELECT 99';
      dlg.BNewDS.OnClick(dlg.BNewDS);
      CheckInt(3, dlg.WorkReport.DataInfo.Count, 'New dataset in the working copy');
      CheckStr('SELECT 99', dlg.WorkReport.DataInfo[0].SQL, 'SQL edit saved into the working copy');
      CheckInt(2, rep.DataInfo.Count, 'Cancel: report datasets untouched');
      CheckStr('SELECT 1', rep.DataInfo[0].SQL, 'Cancel: report SQL untouched');
      Check(not dlg.Applied, 'Cancel: nothing applied');
    finally
      dlg.Free;
    end;
    CheckInt(2, rep.DataInfo.Count, 'After cancel: report unchanged');
    CheckInt(0, cue.UndoOperations.Count, 'After cancel: nothing recorded');
    Check(not cue.IsDirty and not rep.Modified, 'After cancel: report clean');

    // OK: applied and recorded as one undo group
    dlg := TFRpDInfoLCL.Create(nil);
    try
      dlg.Report := rep;
      dlg.MonacoEditor.SQL := 'SELECT 99';
      dlg.BNewDS.OnClick(dlg.BNewDS);
      nOps := cue.UndoOperations.Count;
      Check(dlg.ApplyChanges, 'OK applies the changes');
      Check(dlg.Applied, 'Applied flag after OK');
      CheckInt(3, rep.DataInfo.Count, 'OK: new dataset in the report');
      CheckStr('SELECT 99', rep.DataInfo[0].SQL, 'OK: SQL applied');
      CheckStr('CONN1', rep.DataInfo[0].DatabaseAlias, 'OK: connection kept');
      CheckInt(nOps + 2, cue.UndoOperations.Count, 'OK: one add and one modify');
      Check(cue.UndoOperations[nOps].groupId = cue.UndoOperations[nOps + 1].groupId,
        'OK: data changes recorded in one undo group');
      Check(rep.Modified, 'OK marks the report modified');
    finally
      dlg.Free;
    end;
    cue.Undo.Free;
    CheckInt(2, rep.DataInfo.Count, 'Undo of the data configuration removes the new dataset');
    CheckStr('SELECT 1', rep.DataInfo[0].SQL, 'Undo of the data configuration restores the SQL');
    Check(not rep.Modified, 'Undo back to the clean state');
    cue.Redo.Free;
    CheckInt(3, rep.DataInfo.Count, 'Redo of the data configuration');
    CheckStr('SELECT 99', rep.DataInfo[0].SQL, 'Redo restores the SQL change');

    // Reorder only: nothing to record, but the report is dirty
    cue.MarkClean;
    nOps := cue.UndoOperations.Count;
    dlg := TFRpDInfoLCL.Create(nil);
    try
      dlg.Report := rep;
      dlg.BtnDownDS.OnClick(dlg.BtnDownDS);
      CheckStr('DS2', dlg.WorkReport.DataInfo[0].Alias, 'Reorder in the working copy');
      Check(dlg.ApplyChanges, 'OK applies the reorder');
    finally
      dlg.Free;
    end;
    CheckStr('DS2', rep.DataInfo[0].Alias, 'Reorder applied (0)');
    CheckStr('DS1', rep.DataInfo[1].Alias, 'Reorder applied (1)');
    CheckInt(nOps, cue.UndoOperations.Count, 'Reorder only: no undo operation');
    Check(cue.IsDirty and rep.Modified, 'Reorder only must mark the report dirty');

    // Removing a dataset is recorded and undo restores it with its values
    cue.MarkClean;
    nOps := cue.UndoOperations.Count;
    dlg := TFRpDInfoLCL.Create(nil);
    try
      dlg.Report := rep;
      // The active dataset is the first one: DS2 after the reorder
      dlg.BDelDS.OnClick(dlg.BDelDS);
      CheckInt(2, dlg.WorkReport.DataInfo.Count, 'Dataset removed from the working copy');
      Check(dlg.ApplyChanges, 'OK applies the removal');
    finally
      dlg.Free;
    end;
    CheckInt(2, rep.DataInfo.Count, 'Dataset removal applied');
    Check(rep.DataInfo.IndexOf('DS2') < 0, 'DS2 removed from the report');
    CheckInt(nOps + 1, cue.UndoOperations.Count, 'Dataset removal: one operation');
    Check(cue.UndoOperations.Last.operation = otRemove, 'Dataset removal recorded as otRemove');
    // Regression: same oldValue/newValue mismatch as the removed parameters
    cue.Undo.Free;
    CheckInt(3, rep.DataInfo.Count, 'Undo restores the removed dataset');
    CheckInt(0, rep.DataInfo.IndexOf('DS2'), 'Removed dataset restored with its alias at its index');
    CheckStr('SELECT 2', rep.DataInfo[0].SQL, 'Removed dataset restored with its SQL');
  finally
    rep.Free;
  end;
  LogMsg('Data configuration dialog verified');
end;

procedure TRegressionTests.TestLibraryTree;
const
  LIB_ALIAS = 'RPLIBTEST';
var
  iniPath, dbPath: string;
  conn: TSQLite3Connection;
  tr: TSQLTransaction;
  list: TRpDatabaseInfoList;
  item: TRpDatabaseInfoItem;
  dia: TFRpOpenLibLCL;
  root, nSales, nMonthly, nHR: TTreeNode;
begin
  LogMsg('5.5 L2: report library tree (EditTree on a SQLite library)');
  iniPath := IncludeTrailingPathDelimiter(GetCurrentDir) + 'dbxconnections.ini';
  if FileExists(iniPath) then
  begin
    LogMsg('[TEST_SKIPPED] library tree: ' + iniPath + ' already exists, not overwritten');
    Exit;
  end;
  dbPath := IncludeTrailingPathDelimiter(GetTempDir) + 'rp_libtree_test.db';
  if FileExists(dbPath) then
    DeleteFile(dbPath);

  conn := TSQLite3Connection.Create(nil);
  tr := TSQLTransaction.Create(nil);
  try
    conn.DatabaseName := dbPath;
    conn.Transaction := tr;
    tr.DataBase := conn;
    try
      conn.Open;
    except
      on E: Exception do
      begin
        LogMsg('[TEST_SKIPPED] library tree: SQLite client library not available: ' + E.Message);
        Exit;
      end;
    end;
    tr.StartTransaction;
    conn.ExecuteDirect('CREATE TABLE REPMAN_GROUPS (GROUP_CODE INTEGER, GROUP_NAME VARCHAR(50), PARENT_GROUP INTEGER)');
    conn.ExecuteDirect('CREATE TABLE REPMAN_REPORTS (REPORT_NAME VARCHAR(50), REPORT_GROUP INTEGER, REPORT BLOB)');
    conn.ExecuteDirect('INSERT INTO REPMAN_GROUPS VALUES (1, ''Sales'', 0)');
    conn.ExecuteDirect('INSERT INTO REPMAN_GROUPS VALUES (2, ''Monthly'', 1)');
    conn.ExecuteDirect('INSERT INTO REPMAN_GROUPS VALUES (3, ''HR'', 0)');
    conn.ExecuteDirect('INSERT INTO REPMAN_REPORTS (REPORT_NAME, REPORT_GROUP) VALUES (''R_ROOT'', NULL)');
    conn.ExecuteDirect('INSERT INTO REPMAN_REPORTS (REPORT_NAME, REPORT_GROUP) VALUES (''R_SALES1'', 1)');
    conn.ExecuteDirect('INSERT INTO REPMAN_REPORTS (REPORT_NAME, REPORT_GROUP) VALUES (''R_MONTH1'', 2)');
    conn.ExecuteDirect('INSERT INTO REPMAN_REPORTS (REPORT_NAME, REPORT_GROUP) VALUES (''R_HR1'', 3)');
    conn.ExecuteDirect('INSERT INTO REPMAN_REPORTS (REPORT_NAME, REPORT_GROUP) VALUES (''R_ORPHAN'', 99)');
    tr.Commit;
    conn.Close;
  finally
    tr.Free;
    conn.Free;
  end;

  // The FPC build reads the connection from dbxconnections.ini (working dir)
  WriteTextFile(iniPath, '[' + LIB_ALIAS + ']' + LineEnding +
    'DriverName=SQLite' + LineEnding + 'Database=' + dbPath + LineEnding);
  list := TRpDatabaseInfoList.Create(nil);
  try
    item := list.Add(LIB_ALIAS);
    item.Driver := rpfiredac;
    item.LoadParams := False;
    dia := TFRpOpenLibLCL.Create(nil);
    try
      dia.EditTree(item);
      CheckInt(9, dia.ATree.Items.Count, 'Library tree nodes (root, 3 groups, 5 reports)');
      root := dia.ATree.Items.GetFirstNode;
      CheckStr(LIB_ALIAS, root.Text, 'Library tree root is the connection alias');
      CheckInt(4, root.Count, 'Root: 2 top groups and 2 reports without a known group');
      nSales := root.Items[0];
      nHR := root.Items[1];
      CheckStr('Sales', nSales.Text, 'Top group 1');
      CheckStr('HR', nHR.Text, 'Top group 2');
      CheckStr('R_ORPHAN', root.Items[2].Text, 'Report of an unknown group goes to the root');
      CheckStr('R_ROOT', root.Items[3].Text, 'Report without group at the root');
      CheckInt(2, nSales.Count, 'Sales: subgroup and report');
      nMonthly := nSales.Items[0];
      CheckStr('Monthly', nMonthly.Text, 'Nested group');
      CheckStr('R_SALES1', nSales.Items[1].Text, 'Report of the Sales group');
      CheckInt(1, nMonthly.Count, 'Monthly group reports');
      CheckStr('R_MONTH1', nMonthly.Items[0].Text, 'Report of the nested group');
      CheckInt(1, nHR.Count, 'HR group reports');
      CheckStr('R_HR1', nHR.Items[0].Text, 'Report of the HR group');
      CheckInt(1, TRpLibNodeInfo(nSales.Data).GroupCode, 'Group node data');
      dia.ATree.Selected := nMonthly.Items[0];
      CheckStr('R_MONTH1', dia.SelectedNodeReportName, 'Selected report name');
      dia.ATree.Selected := nSales;
      CheckStr('', dia.SelectedNodeReportName, 'A group node is not a report');
    finally
      dia.Free;
    end;
  finally
    list.Free;
    DeleteFile(iniPath);
    if not DeleteFile(dbPath) then
      LogMsg('Note: could not delete ' + dbPath);
  end;
  LogMsg('Library tree verified');
end;

procedure TRegressionTests.TestUserParams;
var
  rep: TRpReport;
  p: TRpParam;
  dia: TFRpRTParams;
  saved: TParamValueSearchProc;

  function FindCtrl(AClass: TClass; ATag: Integer; const ACaption: string): TControl;
  var
    i: Integer;
    c: TControl;
  begin
    Result := nil;
    for i := 0 to dia.PRight.ControlCount - 1 do
    begin
      c := dia.PRight.Controls[i];
      if (c.ClassType = AClass) and (c.Tag = ATag) and
         ((ACaption = '') or (c.Caption = ACaption)) then
      begin
        Result := c;
        Exit;
      end;
    end;
    Fail(Format('User params: control %s with tag %d not found', [AClass.ClassName, ATag]));
  end;

begin
  LogMsg('5.5 L2: user parameters form (search button and null check)');
  saved := GlobalParamValueSearch;
  rep := TRpReport.Create(nil);
  try
    rep.AddSubReport;
    p := rep.Params.Add('PSEARCH');
    p.Description := 'Search param';
    p.AllowNulls := True;
    p.Value := Null;
    p.SearchDataset := 'DSSEARCH';
    p := rep.Params.Add('PPLAIN');
    p.Description := 'Plain param';
    p.Value := 'x';

    // Without a search implementation the "..." button is hidden
    GlobalParamValueSearch := nil;
    dia := TFRpRTParams.Create(nil);
    try
      dia.params := rep.Params;
      Check(not FindCtrl(TButton, 0, '...').Visible, 'Search button hidden when the search hook is not assigned');
    finally
      dia.Free;
    end;

    GlobalParamValueSearch := FakeParamValueSearch;
    dia := TFRpRTParams.Create(nil);
    try
      dia.params := rep.Params;
      Check(FindCtrl(TButton, 0, '...').Visible, 'Search button visible with a search dataset and the hook');
      Check(not FindCtrl(TButton, 1, '...').Visible, 'No search button without a search dataset');
      Check(TCheckBox(FindCtrl(TCheckBox, 0, SRpNull)).Checked, 'Null value: null check set');
      Check(not FindCtrl(TEdit, 0, '').Visible, 'Null value: edit hidden');
      FakeSearchCalls := 0;
      dia.BSearchClick(FindCtrl(TButton, 0, '...'));
      CheckInt(1, FakeSearchCalls, 'Search hook called');
      CheckStr('PICKED', TEdit(FindCtrl(TEdit, 0, '')).Text, 'Picked value shown');
      Check(not TCheckBox(FindCtrl(TCheckBox, 0, SRpNull)).Checked, 'After a search pick the null check is cleared');
      Check(FindCtrl(TEdit, 0, '').Visible, 'After a search pick the edit is visible');
    finally
      dia.Free;
    end;
  finally
    GlobalParamValueSearch := saved;
    rep.Free;
  end;
  LogMsg('User parameters form verified');
end;

procedure TRegressionTests.TestDesignerExecute(const ASamplePath: string);
var
  des: TRpDesignerLCL;
  tmp: string;
  original: TMemoryStream;
  repBefore: TRpReport;
  res: Boolean;
  handled: Integer;
begin
  LogMsg('5.5 L2: TRpDesignerLCL.Execute (hosted designer)');
  tmp := IncludeTrailingPathDelimiter(GetTempDir) + 'rp_execute_test.rep';
  CopyFileBytes(ASamplePath, tmp);
  original := FileBytes(tmp);
  des := TRpDesignerLCL.Create(nil);
  try
    des.LoadFromFile(tmp);
    des.OnSave := ExecOnSave;

    // Unmodified: returns False, nothing saved, report kept
    repBefore := des.Report;
    FSaveCalls := 0;
    handled := Guard.DesignersHandled;
    Guard.ExpectDesigner := True;
    Guard.DesignerAction := DesignerCheckHostedAction;
    res := des.Execute;
    CheckInt(handled + 1, Guard.DesignersHandled, 'Execute showed the designer');
    Check(not res, 'Execute of an unmodified report must return False');
    CheckInt(0, FSaveCalls, 'Unmodified report: OnSave not called');
    Check(des.Report = repBefore, 'Unmodified report: the report object is kept');
    CheckFileUnchanged(tmp, original, 'Unmodified report');

    // Modified, changes discarded: returns False, report restored
    FSaveCalls := 0;
    Guard.ExpectDesigner := True;
    Guard.DesignerAction := DesignerModifyAction;
    Guard.ExpectMsgBoxes := 1;
    Guard.MsgBoxAnswer := smbNo;
    res := des.Execute;
    CheckInt(0, Guard.ExpectMsgBoxes, 'Modified report: the save question was asked');
    Check(not res, 'Discarded changes: Execute returns False');
    CheckInt(0, FSaveCalls, 'Discarded changes: OnSave not called');
    Check(des.Report.Params.IndexOf('EXEC_TEST_PARAM') < 0, 'Discarded changes: report restored');
    Check(not des.Report.Modified, 'Discarded changes: restored report unmodified');
    CheckFileUnchanged(tmp, original, 'Discarded changes');

    // Modified, changes accepted: saved through OnSave
    FSaveCalls := 0;
    FSavedReportHasParam := False;
    Guard.ExpectDesigner := True;
    Guard.DesignerAction := DesignerModifyAction;
    Guard.ExpectMsgBoxes := 1;
    Guard.MsgBoxAnswer := smbYes;
    res := des.Execute;
    CheckInt(0, Guard.ExpectMsgBoxes, 'Accepted changes: the save question was asked');
    Check(res, 'Accepted changes: Execute returns True');
    CheckInt(1, FSaveCalls, 'Accepted changes: OnSave called once');
    Check(FSavedReportHasParam, 'Accepted changes: OnSave receives the modified report');
    Check(des.Report.Params.IndexOf('EXEC_TEST_PARAM') >= 0, 'Accepted changes: modified report kept');
    CheckFileUnchanged(tmp, original, 'Accepted changes handled by OnSave');
  finally
    Guard.DesignerAction := nil;
    Guard.ExpectDesigner := False;
    des.Free;
    original.Free;
    DeleteFile(tmp);
  end;
  LogMsg('TRpDesignerLCL.Execute verified');
end;

{ Phase 7.5: the undo history travels with the report XML (BINCUE), as in
  Delphi (rpxmlstream hooks registered by rpmdundocuelcl) }

const
  // BINCUE of repman/repsamples/debugagentexample.rep, written by the Delphi
  // designer (rpmdundocue TUndoCue.ToJSON)
  DELPHI_CUE_JSON = '{"groupId":2,"undoOperations":[{"componentName":"REPORT",' +
    '"componentClass":"TRPREPORT","date":"2026-05-29T14:18:58.364Z","properties":[' +
    '{"propertyName":"pageHeight","propertyType":1,"oldValue":16837,"newValue":8120},' +
    '{"propertyName":"pageWidth","propertyType":1,"oldValue":11906,"newValue":5742},' +
    '{"propertyName":"streamFormat","propertyType":1,"oldValue":1,"newValue":3}],' +
    '"expandedProperties":true,"operation":1,"groupId":1},' +
    '{"componentName":"TRPDATAINFOITEM1","componentClass":"TRPDATAINFOITEM",' +
    '"date":"2026-06-17T13:11:19.391Z","properties":[{"propertyName":"hubSchemaId",' +
    '"propertyType":1,"oldValue":0,"newValue":34}],"expandedProperties":true,' +
    '"operation":1,"groupId":2}],"redoOperations":[]}';
  // What Delphi writes for an otAdd: \u escapes (Delphi escapes non ASCII),
  // CR LF, nulls, booleans and a double (as in repsamples/bold.rep)
  DELPHI_CUE_ESCAPES = '{"groupId":5,"undoOperations":[{"componentName":"TRpExpression0",' +
    '"componentClass":"TRPEXPRESSION","parentName":"TRpSection0","oldItemIndex":27,' +
    '"oldParentName":"TRpSection0","date":"2026-09-18T16:56:32.540Z","properties":[' +
    '{"propertyName":"posX","propertyType":1,"oldValue":null,"newValue":4824},' +
    '{"propertyName":"visible","propertyType":6,"oldValue":null,"newValue":true},' +
    '{"propertyName":"expression","propertyType":3,"oldValue":null,' +
    '"newValue":"''النص:''+\r\n#10"},' +
    '{"propertyName":"ratio","propertyType":2,"oldValue":1.5,"newValue":2.25}],' +
    '"expandedProperties":false,"operation":0,"groupId":5}],"redoOperations":[]}';

function ReportXmlOf(rep: TRpReport): string;
var
  ms: TStringStream;
  oldFormat: TRpStreamFormat;
begin
  oldFormat := rep.StreamFormat;
  ms := TStringStream.Create('');
  try
    rep.StreamFormat := rpStreamXML;
    rep.SaveToStream(ms);
    Result := ms.DataString;
  finally
    rep.StreamFormat := oldFormat;
    ms.Free;
  end;
end;

function LoadReportFromText(const AText: string): TRpReport;
var
  ms: TStringStream;
begin
  Result := TRpReport.Create(nil);
  ms := TStringStream.Create(AText);
  try
    Result.LoadFromStream(ms);
  finally
    ms.Free;
  end;
end;

procedure TestUndoCueDelphiJson;
var
  cue, cue2: TUndoCue;
  op: TChangeObjectOperation;
  json: string;
begin
  LogMsg('7.5: undo history JSON compatible with the Delphi designer');
  cue := TUndoCue.Create(nil);
  cue2 := TUndoCue.Create(nil);
  try
    cue.FromJSON(DELPHI_CUE_JSON);
    CheckInt(2, cue.UndoOperations.Count, 'Delphi cue: undo operations');
    CheckInt(0, cue.RedoOperations.Count, 'Delphi cue: redo operations');
    CheckInt(2, cue.GroupId, 'Delphi cue: groupId');
    CheckInt(1, cue.LoadCount, 'Delphi cue: LoadCount');
    op := cue.UndoOperations[0];
    Check(op.operation = otModify, 'Delphi cue: otModify');
    CheckStr('REPORT', op.componentName, 'Delphi cue: component');
    CheckInt(3, op.properties.Count, 'Delphi cue: properties');
    CheckStr('pageHeight', op.properties[0].propertyName, 'Delphi cue: property name');
    Check(op.properties[0].propertyType = ptInteger, 'Delphi cue: property type');
    CheckInt(16837, op.properties[0].oldValue, 'Delphi cue: old value');
    CheckInt(8120, op.properties[0].newValue, 'Delphi cue: new value');
    CheckStr('TRPDATAINFOITEM1', cue.UndoOperations[1].componentName, 'Delphi cue: second operation');
    CheckInt(2, cue.UndoOperations[1].groupId, 'Delphi cue: second group');
    // Written back compact (as Delphi) and read again without changes
    json := cue.ToJSON;
    Check(Copy(json, 1, 11) = '{"groupId":', 'LCL cue JSON is compact: ' + Copy(json, 1, 40));
    Check(Pos('": ', json) = 0, 'LCL cue JSON has no blanks');
    cue2.FromJSON(json);
    CheckStr(json, cue2.ToJSON, 'LCL cue JSON round trip');

    cue.FromJSON(DELPHI_CUE_ESCAPES);
    CheckInt(1, cue.UndoOperations.Count, 'Delphi escapes: operations');
    op := cue.UndoOperations[0];
    Check(op.operation = otAdd, 'Delphi escapes: otAdd');
    CheckInt(27, op.oldItemIndex, 'Delphi escapes: oldItemIndex');
    CheckStr('TRpSection0', op.parentName, 'Delphi escapes: parent');
    Check(not op.expandedProperties, 'Delphi escapes: expandedProperties');
    Check(VarIsNull(op.properties[0].oldValue), 'Delphi escapes: null old value of an otAdd');
    CheckInt(4824, op.properties[0].newValue, 'Delphi escapes: integer');
    Check(op.properties[1].newValue = True, 'Delphi escapes: boolean');
    CheckStr('''' + #$D8#$A7#$D9#$84#$D9#$86#$D8#$B5 + ':''+' + #13#10 + '#10',
      VarToStr(op.properties[2].newValue), 'Delphi escapes: \u escapes and CR LF as UTF-8');
    Check(Abs(Double(op.properties[3].newValue) - 2.25) < 1E-9, 'Delphi escapes: double');
    json := cue.ToJSON;
    cue2.FromJSON(json);
    CheckStr(json, cue2.ToJSON, 'LCL cue JSON round trip with UTF-8 text');
    CheckStr(VarToStr(op.properties[2].newValue), VarToStr(cue2.UndoOperations[0].properties[2].newValue),
      'UTF-8 text kept by the LCL JSON');
  finally
    cue2.Free;
    cue.Free;
  end;
  LogMsg('Undo history JSON compatible with Delphi verified');
end;

procedure TestUndoCueInReportXml;
var
  rep, rep2, rep3: TRpReport;
  sec, sec3: TRpSection;
  lab: TRpLabel;
  cue, cue2: TUndoCue;
  xml: string;
  oldX: Integer;
begin
  LogMsg('7.5: undo history saved and read with the report XML (BINCUE)');
  rep := NewEngineReport(sec);
  rep2 := nil;
  rep3 := nil;
  try
    cue := TUndoCue(rep.UndoCue);
    lab := AddEngineLabel(rep, sec, 'CUELAB1');
    oldX := lab.PosX;
    cue.AddOperation(NewPosXOp(cue.GetGroupId, lab, sec, oldX + 777));
    xml := ReportXmlOf(rep);
    Check(Pos('<BINCUE', xml) > 0, 'report XML carries the undo history');
    rep2 := LoadReportFromText(xml);
    Check(rep2.UndoCue is TUndoCue, 'reading the XML gives the report its undo cue');
    cue2 := TUndoCue(rep2.UndoCue);
    CheckInt(1, cue2.UndoOperations.Count, 'history read from the XML');
    CheckStr(cue.ToJSON, cue2.ToJSON, 'the same history');
    cue2.Undo.Free;
    CheckInt(oldX, TRpLabel(FindItem(rep2, 'CUELAB1')).PosX, 'the history read undoes on the loaded report');
    // An empty history is not written (as Delphi)
    rep3 := NewEngineReport(sec3);
    Check(Pos('BINCUE', ReportXmlOf(rep3)) = 0, 'no BINCUE for an empty history');
  finally
    rep3.Free;
    rep2.Free;
    rep.Free;
  end;
  LogMsg('Undo history in the report XML verified');
end;

procedure TestHistoryExtendedFrom;
var
  rep: TRpReport;
  sec: TRpSection;
  lab: TRpLabel;
  cue, other: TUndoCue;
  base, extended: string;
begin
  LogMsg('7.5: history returned by the design assistant (HistoryExtendedFrom)');
  rep := NewEngineReport(sec);
  other := TUndoCue.Create(nil);
  try
    cue := TUndoCue(rep.UndoCue);
    lab := AddEngineLabel(rep, sec, 'EXTLAB1');
    cue.AddOperation(NewPosXOp(cue.GetGroupId, lab, sec, 100));
    cue.AddOperation(NewPosXOp(cue.GetGroupId, lab, sec, 200));
    cue.MarkClean;
    base := cue.ToJSON;
    // The assistant returns the history with one operation on top
    other.FromJSON(base);
    other.AddOperation(NewPosXOp(other.GetGroupId, lab, sec, 300));
    extended := other.ToJSON;
    cue.FromJSON(extended);
    cue.HistoryExtendedFrom(2);
    CheckInt(3, cue.UndoOperations.Count, 'extended history');
    Check(rep.Modified and cue.IsDirty, 'a history extended after the clean point is dirty');
    cue.Undo.Free;
    Check(not rep.Modified, 'undoing the new operation reaches the saved state');
    // Clean point in the redo branch: unreachable after the extension
    cue.Redo.Free;
    cue.MarkClean;
    cue.Undo.Free;
    CheckInt(1, cue.RedoOperations.Count, 'one operation to redo');
    cue.FromJSON(extended);
    cue.RedoOperations.Add(TChangeObjectOperation.Create(otModify, 99));
    cue.HistoryExtendedFrom(2);
    CheckInt(0, cue.RedoOperations.Count, 'new operations discard the redo branch');
    Check(cue.IsDirty and rep.Modified, 'a clean point after the base is lost');
  finally
    other.Free;
    rep.Free;
  end;
  LogMsg('HistoryExtendedFrom verified');
end;

procedure TestDesignerKeepsHistory(const ASamplePath: string);
var
  mf: TFRpMainFLCL;
  sec: TRpSection;
  lab: TRpLabel;
  cue: TUndoCue;
  op: TChangeObjectOperation;
  tmp, sample, content: string;
  sl: TStringList;
begin
  LogMsg('7.5: the designer keeps the undo history of the reports it opens and saves');
  tmp := IncludeTrailingPathDelimiter(GetTempDir) + 'rp_bincue_test.rep';
  mf := TFRpMainFLCL.Create(nil);
  sl := TStringList.Create;
  try
    // A Delphi report with its history (repsamples/debugagentexample.rep)
    sample := ExtractFilePath(ASamplePath) + 'debugagentexample.rep';
    if FileExists(sample) then
    begin
      mf.OpenReportFile(sample);
      cue := TUndoCue(mf.Report.UndoCue);
      CheckInt(2, cue.UndoOperations.Count, 'Delphi report: history loaded with it');
      Check(not mf.Report.Modified, 'Delphi report: opened unmodified');
      Check(mf.BtnUndo.Enabled, 'Delphi report: Undo enabled');
      CheckInt(8120, mf.Report.PageHeight, 'Delphi report: page height');
      CheckInt(34, mf.Report.DataInfo.Items[0].HubSchemaId, 'Delphi report: schema of the dataset');
      mf.DoUndo;
      CheckInt(0, mf.Report.DataInfo.Items[0].HubSchemaId, 'Delphi history: undo of the dataset change');
      mf.DoUndo;
      CheckInt(16837, mf.Report.PageHeight, 'Delphi history: undo of the page height');
      CheckInt(11906, mf.Report.PageWidth, 'Delphi history: undo of the page width');
      Check(not cue.CanUndo and mf.Report.Modified, 'Delphi history undone (modified)');
      // No save question for the next report
      cue.MarkClean;
    end
    else
      LogMsg('SKIP: ' + sample + ' not found');

    // Saved as XML: the history goes with the file
    mf.NewReport;
    sec := mf.Report.SubReports[0].SubReport.Sections[mf.Report.SubReports[0].SubReport.FirstDetail].Section;
    cue := TUndoCue(mf.Report.UndoCue);
    lab := AddEngineLabel(mf.Report, sec, 'HISTLAB1');
    op := TChangeObjectOperation.Create(otAdd, cue.GetGroupId);
    op.componentName := lab.Name;
    op.componentClass := 'TRPLABEL';
    op.parentName := sec.Name;
    cue.AddAllComponentProperties(lab, op);
    cue.AddOperation(op);
    cue.AddOperation(NewPosXOp(cue.GetGroupId, lab, sec, lab.PosX + 500));
    mf.Report.StreamFormat := rpStreamXML;
    mf.SaveReportFile(tmp);
    sl.LoadFromFile(tmp);
    content := sl.Text;
    Check(Pos('<BINCUE', content) > 0, 'XML report file carries the history');
    mf.OpenReportFile(tmp);
    cue := TUndoCue(mf.Report.UndoCue);
    CheckInt(2, cue.UndoOperations.Count, 'history kept when the file is opened again');
    Check(not mf.Report.Modified, 'opened unmodified');
    mf.DoUndo;
    mf.DoUndo;
    Check(FindItem(mf.Report, 'HISTLAB1') = nil, 'the saved history undoes the saved changes');
    // The text format (the default) does not carry it, as in Delphi
    mf.Report.StreamFormat := rpStreamText;
    mf.SaveReportFile(tmp);
    mf.OpenReportFile(tmp);
    CheckInt(0, TUndoCue(mf.Report.UndoCue).UndoOperations.Count, 'text format: no history');
  finally
    sl.Free;
    mf.Free;
    DeleteFile(tmp);
  end;
  LogMsg('Designer history with the report verified');
end;

type
  // The host of the chat of TestChatSchemaList: "New local schema..." adds
  // a subschema as the local schema utility would (without its dialog)
  TChatSchemaHost = class
  public
    Chat: TFRpChatFrame;
    Configured: Integer;
    AddNew: Boolean;
    Alias: string;
    SchemaChanges: Integer;
    procedure ConfigureLocalSchemas(Sender: TObject;
      const AAlias, ASchemaName: string; AAddNew: Boolean);
    procedure SchemaChanged(Sender: TObject);
  end;

// As RpListLocalSchemaEntries: the subschemas only, never 'ALIAS=' (all the
// tables, F8); OTHER has no subschemas (or no file yet): no line
procedure FillLocalEntries(AEntries, ASizes: TStrings; AWithCompras: Boolean);
begin
  AEntries.Clear;
  ASizes.Clear;
  AEntries.Add('FBEX=Ventas');
  ASizes.Add('2,3');
  if AWithCompras then
  begin
    AEntries.Add('FBEX=Compras');
    ASizes.Add('1,2');
  end;
end;

procedure TChatSchemaHost.ConfigureLocalSchemas(Sender: TObject;
  const AAlias, ASchemaName: string; AAddNew: Boolean);
var
  LEntries, LSizes: TStringList;
begin
  Inc(Configured);
  AddNew := AAddNew;
  Alias := AAlias;
  LEntries := TStringList.Create;
  LSizes := TStringList.Create;
  try
    FillLocalEntries(LEntries, LSizes, True);
    Chat.SetLocalSchemas(LEntries, 'FBEX', LSizes);
    Chat.SelectLocalSchema(AAlias, 'Compras');
  finally
    LSizes.Free;
    LEntries.Free;
  end;
end;

procedure TChatSchemaHost.SchemaChanged(Sender: TObject);
begin
  Inc(SchemaChanges);
end;

// F5 and F8: the schema list of the AI chat, without the Hub (no network):
// the local group with the tables of each subschema and its icon, never all
// the tables of the connection (only a subschema goes to the AI), the
// actions at the end, the headers skipped, "New local schema..." through the
// host and the choice of each connection kept for the session
procedure TestChatSchemaList;
const
  SEP = ' '#$C2#$B7' ';
  LOCAL_ICON = #$E2#$9B#$81' ';
var
  LForm: TForm;
  LChat, LOther: TFRpChatFrame;
  LHost: TChatSchemaHost;
  LEntries, LSizes: TStringList;
  LCount, LNewLocal: Integer;
begin
  LogMsg('F5: the schema list of the AI chat');
  LForm := TForm.CreateNew(nil);
  LHost := TChatSchemaHost.Create;
  LEntries := TStringList.Create;
  LSizes := TStringList.Create;
  try
    LChat := TFRpChatFrame.Create(LForm);
    LChat.Parent := LForm;
    LHost.Chat := LChat;
    LChat.OnConfigureLocalSchemas := LHost.ConfigureLocalSchemas;
    LChat.OnSchemaChanged := LHost.SchemaChanged;
    Check(not LChat.HasSchemaItems, 'chat list: empty before the schemas');
    // A connection without subschemas: only the actions, nothing chosen, and
    // the chat asks for a subschema instead of sending (1984)
    LEntries.Clear;
    LSizes.Clear;
    LChat.SetLocalSchemas(LEntries, 'OTHER', LSizes);
    Check(not LChat.HasSchemaItems, 'chat list: no subschema, no schema to choose');
    CheckInt(-1, LChat.ComboSchema.ItemIndex, 'chat list: nothing chosen');
    CheckStr('', LChat.GetLocalSchemaName, 'chat list: no subschema');
    CheckStr(RpSubSchemaRequiredMessage('OTHER'), LChat.SchemaSendRefusal,
      'chat list: sending asks for a subschema');
    FillLocalEntries(LEntries, LSizes, False);
    LChat.SetLocalSchemas(LEntries, 'FBEX', LSizes);
    Check(LChat.HasSchemaItems, 'chat list: local schemas listed');
    Check(Pos(TranslateStr(1836, 'Local'), LChat.ComboSchema.Items[0]) > 0,
      'chat list: the Local header first');
    CheckStr(LOCAL_ICON + 'FBEX' + SEP + 'Ventas (2)', LChat.ComboSchema.Items[1],
      'chat list: a subschema with its icon and the tables that travel');
    LCount := LChat.ComboSchema.Items.Count;
    LNewLocal := LCount - 2;
    CheckInt(5, LCount, 'chat list: header, 1 subschema, separator and 2 actions');
    CheckStr(TranslateStr(1838, 'New local schema...'),
      LChat.ComboSchema.Items[LNewLocal], 'chat list: New local schema');
    Check(Pos(TranslateStr(1839, 'New cloud schema...'),
      LChat.ComboSchema.Items[LCount - 1]) = 1, 'chat list: New cloud schema');
    Check(Pos(TranslateStr(1842, 'This connection is not in the Hub'),
      LChat.ComboSchema.Items[LCount - 1]) > 0,
      'chat list: New cloud schema disabled on a direct connection');
    // The connection of the report: its first subschema
    CheckStr('FBEX', LChat.GetLocalSchemaAlias, 'chat list: the direct connection');
    CheckStr('Ventas', LChat.GetLocalSchemaName, 'chat list: the first subschema');
    CheckInt(1, LChat.ComboSchema.ItemIndex, 'chat list: the first subschema selected');
    CheckStr('', LChat.SchemaSendRefusal, 'chat list: a subschema can be sent');
    LChat.SelectLocalSchema('FBEX', 'Ventas');
    CheckInt(1, LChat.ComboSchema.ItemIndex, 'chat list: the subschema selected');
    // The keys of the closed list: a header is skipped, an action is not run
    LChat.ComboSchema.ItemIndex := 0;
    LChat.ComboSchema.OnChange(LChat.ComboSchema);
    CheckInt(1, LChat.ComboSchema.ItemIndex, 'chat list: a header is not chosen');
    LChat.ComboSchema.ItemIndex := LNewLocal - 1;
    LChat.ComboSchema.OnChange(LChat.ComboSchema);
    CheckInt(1, LChat.ComboSchema.ItemIndex, 'chat list: the separator is not chosen');
    CheckInt(0, LHost.Configured, 'chat list: the keys do not run an action');
    CheckStr('Ventas', LChat.GetLocalSchemaName, 'chat list: the choice stays');
    // "New local schema..." clicked: back to the schema, then the utility
    // of the connection adds one and the chat selects it
    LHost.SchemaChanges := 0;
    LChat.ComboSchema.ItemIndex := LNewLocal;
    LChat.ComboSchema.OnCloseUp(LChat.ComboSchema);
    CheckInt(1, LChat.ComboSchema.ItemIndex, 'chat list: an action is not a schema');
    Application.ProcessMessages;
    CheckInt(1, LHost.Configured, 'chat list: New local schema opens the utility');
    Check(LHost.AddNew, 'chat list: the utility starts adding a subschema');
    CheckStr('FBEX', LHost.Alias, 'chat list: of the direct connection chosen');
    CheckStr('Compras', LChat.GetLocalSchemaName, 'chat list: the new subschema selected');
    Check(LHost.SchemaChanges > 0, 'chat list: the new subschema is a change of the user');
    CheckStr(LOCAL_ICON + 'FBEX' + SEP + 'Compras (1)',
      LChat.ComboSchema.Items[LChat.ComboSchema.ItemIndex], 'chat list: the new subschema listed');
    // The chat of the next report (a new frame) starts with the subschema
    // chosen for the connection in this session
    LOther := TFRpChatFrame.Create(LForm);
    LOther.Parent := LForm;
    FillLocalEntries(LEntries, LSizes, True);
    LOther.SetLocalSchemas(LEntries, 'FBEX', LSizes);
    CheckStr('Compras', LOther.GetLocalSchemaName,
      'chat list: the choice of the connection kept for the session');
    // The Hub schemas of the list arrive later: no Hub context is lost
    LOther.SetHubContext(77, 5, '');
    CheckInt(77, LOther.GetHubDatabaseId, 'chat list: the Hub database waits for its list');
    CheckInt(5, LOther.GetHubSchemaId, 'chat list: the Hub schema waits for its list');
  finally
    LSizes.Free;
    LEntries.Free;
    LHost.Free;
    LForm.Free;
  end;
  LogMsg('Schema list of the AI chat verified');
end;

procedure RunRegressionTests(const ASamplePath: string);
var
  t: TRegressionTests;
begin
  InstallModalGuard;
  LogMsg('Testing Subphase 5.5: regression tests (undo engine, designer, dialogs)');
  t := TRegressionTests.Create;
  try
    t.TestUndoCap;
    t.TestDirtyState;
    t.TestFailingOperation;
    t.TestDeleteRestoresAll;
    t.TestDesigner(ASamplePath);
    t.TestItemInterfaces;
    t.TestParamsDialog;
    t.TestDataConfig;
    t.TestLibraryTree;
    t.TestUserParams;
    t.TestDesignerExecute(ASamplePath);
    // Phase 7.5: undo history with the report (BINCUE)
    TestUndoCueDelphiJson;
    TestUndoCueInReportXml;
    TestHistoryExtendedFrom;
    TestDesignerKeepsHistory(ASamplePath);
    // F5: the schema list of the AI chat
    TestChatSchemaList;
  finally
    t.Free;
  end;
  Check(Guard.ExpectMsgBoxes = 0, 'Expected confirmations that were never shown');
  Check(not Guard.ExpectDesigner, 'Expected designer form that was never shown');
  LogMsg('Subphase 5.5 regression tests completed successfully');
end;

initialization
  // The designer windows of the tests do not read the preferences of the
  // user (View > AI chat, shared with the VCL designer)
  RpDesignerLCLConfigFile := IncludeTrailingPathDelimiter(GetTempDir) +
    'rp_lcldesignertest_' + IntToStr(GetProcessID) + '.ini';
end.
