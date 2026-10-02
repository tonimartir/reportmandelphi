unit umainform;

{$mode delphi}

interface

uses
  Classes, SysUtils, Variants, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls, ComCtrls, Buttons, LCLType,
  rpreport, rpsubreport, rpmdfdesignlcl, rprulerlcl, rpmunits, rpprintitem,
  rpmdobinsintlcl, rpmdfsectionintlcl, rpmdobjinsplcl, rpmdconsts,
  rplabelitem, rpdrawitem, rpmdbarcode, rpmdchart, rpsection, rptypes,
  rpmdimageslcl, rpmdfstruclcl, rpdbbrowserlcl, rpmdfdinfolcl, rpdatainfo,
  rppagesetuplcl, rplclpreview, rppreviewcontrol, rpfrmmonacoeditorlcl,
  rpexpredlglcl, rpmdfgridlcl, rpmdfaboutlcl,
  rpmdfselectfieldslcl, rpmdfwizardlcl, rpmdfextseclcl, rpcolumnar,
  rpmdfsearchlcl, rpmdfopenliblcl, rpmdfparamslcl, rprflclparams, rpparams,
  rpmdundocuelcl, rpmdcueviewlcl, rpmdfmainlcl;

type
  TMainForm = class(TForm)
    MainToolBar: TToolBar;
    ImageList1: TImageList;
    BtnNew: TToolButton;
    BtnOpen: TToolButton;
    BtnSave: TToolButton;
    BtnDataConfig: TToolButton;
    BtnPageSetup: TToolButton;
    Sep1: TToolButton;
    BtnPrint: TToolButton;
    BtnPreview: TToolButton;
    Sep2: TToolButton;
    BtnUndo: TToolButton;
    BtnRedo: TToolButton;
    Sep3: TToolButton;
    BtnToolArrow: TToolButton;
    BtnToolLabel: TToolButton;
    BtnToolExpr: TToolButton;
    BtnToolShape: TToolButton;
    BtnToolImage: TToolButton;
    BtnToolChart: TToolButton;
    BtnToolBarcode: TToolButton;
    Sep4: TToolButton;
    ComboScale: TComboBox;
    Sep5: TToolButton;
    BtnDelete: TToolButton;
    BtnCut: TToolButton;
    BtnCopy: TToolButton;
    BtnPaste: TToolButton;
    Sep6: TToolButton;
    BtnNudgeLeft: TToolButton;
    BtnNudgeRight: TToolButton;
    BtnNudgeUp: TToolButton;
    BtnNudgeDown: TToolButton;
    Sep7: TToolButton;
    BtnAlignLeft: TToolButton;
    BtnAlignRight: TToolButton;
    BtnAlignUp: TToolButton;
    BtnAlignDown: TToolButton;
    BtnAlignHorz: TToolButton;
    BtnAlignVert: TToolButton;
    PClient: TPanel;
    StatusBar: TStatusBar;
    OpenDialog: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure BtnOpenClick(Sender: TObject);
    procedure BtnToolClick(Sender: TObject);
    procedure BtnDeleteClick(Sender: TObject);
    procedure BtnToFrontClick(Sender: TObject);
    procedure BtnToBackClick(Sender: TObject);
    procedure BtnSelectAllClick(Sender: TObject);
    procedure DesignerToolChange(Sender: TObject);
    procedure BtnNewClick(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnDataConfigClick(Sender: TObject);
    procedure BtnPageSetupClick(Sender: TObject);
    procedure BtnPrintClick(Sender: TObject);
    procedure BtnPreviewClick(Sender: TObject);
    procedure BtnUndoClick(Sender: TObject);
    procedure BtnRedoClick(Sender: TObject);
    procedure BtnCutClick(Sender: TObject);
    procedure BtnCopyClick(Sender: TObject);
    procedure BtnPasteClick(Sender: TObject);
    procedure BtnNudgeLeftClick(Sender: TObject);
    procedure BtnNudgeRightClick(Sender: TObject);
    procedure BtnNudgeUpClick(Sender: TObject);
    procedure BtnNudgeDownClick(Sender: TObject);
    procedure BtnAlignLeftClick(Sender: TObject);
    procedure BtnAlignRightClick(Sender: TObject);
    procedure BtnAlignUpClick(Sender: TObject);
    procedure BtnAlignDownClick(Sender: TObject);
    procedure BtnAlignHorzClick(Sender: TObject);
    procedure BtnAlignVertClick(Sender: TObject);
    procedure ComboScaleChange(Sender: TObject);
  private
    FReport: TRpReport;
    FDesignerFrame: TFRpDesignFrameLCL;
    FObjInsp: TFRpObjInspLCL;
    FStructure: TFRpStructureLCL;
    PInspPanel: TPanel;
    SplitterInsp: TSplitter;
    SplitterStruct: TSplitter;
    FCurrentFileName: string;
    FAutoTestMode: Boolean;
    procedure AppException(Sender: TObject; E: Exception);
    function FindSampleFile(const AName: string): string;
    procedure UpdateStatus;
  public
    procedure LoadReportFile(const AFileName: string);
    procedure RunSelfTest(Data: PtrInt);
  end;

var
  MainForm: TMainForm;

procedure LogMsg(const S: string);

implementation

{$R *.lfm}

uses
  uregressiontests, uvclparitytests, udataconfigtests, upagesetuptests,
  ulibrarytests, udialoglayouttests, upaletteiconstests;

type
  TRpSizePosInterfaceAccess = class(TRpSizePosInterface);

procedure LogMsg(const S: string);
var
  f: TextFile;
  logPath: string;
begin
  logPath := ExtractFilePath(Application.ExeName) + 'selftest.log';
  try
    AssignFile(f, logPath);
    if FileExists(logPath) then
      Append(f)
    else
      Rewrite(f);
    WriteLn(f, S);
    Flush(f);
    CloseFile(f);
  except
  end;
  if IsConsole then
  begin
    try
      WriteLn(S);
    except
    end;
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  i: Integer;
begin
  LogMsg('TMainForm.FormCreate started');
  FAutoTestMode := False;
  for i := 1 to ParamCount do
  begin
    if (ParamStr(i) = '--selftest') or
       (ParamStr(i) = '--run-and-exit') then
      FAutoTestMode := True;
  end;

  LogMsg('FormCreate: creating PInspPanel');
  PInspPanel := TPanel.Create(Self);
  PInspPanel.Width := 300;
  PInspPanel.Align := alLeft;
  PInspPanel.BevelOuter := bvNone;
  PInspPanel.Parent := PClient;

  LogMsg('FormCreate: creating SplitterInsp');
  SplitterInsp := TSplitter.Create(Self);
  SplitterInsp.Align := alLeft;
  SplitterInsp.Width := 5;
  SplitterInsp.Parent := PClient;

  LogMsg('FormCreate: creating FDesignerFrame');
  FDesignerFrame := TFRpDesignFrameLCL.Create(Self);
  FDesignerFrame.Align := alClient;
  FDesignerFrame.Parent := PClient;

  LogMsg('FormCreate: creating FStructure');
  FStructure := TFRpStructureLCL.Create(Self);
  FStructure.Height := 260;
  FStructure.Align := alTop;
  FStructure.Parent := PInspPanel;

  LogMsg('FormCreate: creating SplitterStruct');
  SplitterStruct := TSplitter.Create(Self);
  SplitterStruct.Align := alTop;
  SplitterStruct.Height := 5;
  SplitterStruct.Parent := PInspPanel;

  LogMsg('FormCreate: creating FObjInsp');
  FObjInsp := TFRpObjInspLCL.Create(Self);
  FObjInsp.Align := alClient;
  FObjInsp.Parent := PInspPanel;

  LogMsg('FormCreate: linking ObjInsp and Structure');
  FDesignerFrame.ObjInsp := FObjInsp;
  FDesignerFrame.freportstructure := FStructure;
  FStructure.designframe := FDesignerFrame;
  FStructure.ObjInsp := FObjInsp;
  FDesignerFrame.OnToolChange := DesignerToolChange;

  LogMsg('FormCreate: loading icons into ImageList1');
  LoadDesignerImageList(ImageList1);
  MainToolBar.Images := ImageList1;

  Application.OnException := AppException;
  LogMsg('TMainForm.FormCreate completed');
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FReport);
end;

procedure TMainForm.AppException(Sender: TObject; E: Exception);
var
  frames: PPointer;
  i, cnt: Integer;
begin
  LogMsg('[EXCEPTION] ' + E.ClassName + ': ' + E.Message);
  LogMsg('[EXCEPTION] At: ' + BackTraceStrFunc(ExceptAddr));
  frames := ExceptFrames;
  cnt := ExceptFrameCount;
  for i := 0 to cnt - 1 do
    LogMsg('[EXCEPTION] Frame ' + IntToStr(i) + ': ' + BackTraceStrFunc(frames[i]));
  if FAutoTestMode then
  begin
    LogMsg('[TEST_FAILED] Exception (' + E.ClassName + '): ' + E.Message);
    Halt(1);
  end
  else
    ShowMessage('Exception: ' + E.ClassName + #13#10 + E.Message);
end;

procedure TMainForm.FormShow(Sender: TObject);
var
  samplePath: string;
begin
  LogMsg('FormShow called. FAutoTestMode=' + BoolToStr(FAutoTestMode, True));
  if not FAutoTestMode then
  begin
    samplePath := FindSampleFile('sample4.rep');
    if FileExists(samplePath) then
      LoadReportFile(samplePath);
  end;
end;

function TMainForm.FindSampleFile(const AName: string): string;
var
  p: string;
begin
  Result := '';
  p := ExtractFilePath(Application.ExeName) + '..' + PathDelim + '..' + PathDelim + '..' + PathDelim +
    'repman' + PathDelim + 'repsamples' + PathDelim + AName;
  if FileExists(p) then Exit(ExpandFileName(p));

  p := ExtractFilePath(Application.ExeName) + '..' + PathDelim + '..' + PathDelim + 'repsamples' + PathDelim + AName;
  if FileExists(p) then Exit(ExpandFileName(p));

  p := 'repman' + PathDelim + 'repsamples' + PathDelim + AName;
  if FileExists(p) then Exit(ExpandFileName(p));
end;

procedure TMainForm.LoadReportFile(const AFileName: string);
begin
  if not FileExists(AFileName) then
  begin
    ShowMessage('Archivo no encontrado: ' + AFileName);
    Exit;
  end;

  LogMsg('LoadReportFile: setting Report to nil');
  FStructure.Report := nil;
  FDesignerFrame.Report := nil;
  LogMsg('LoadReportFile: freeing FReport');
  FreeAndNil(FReport);
  LogMsg('LoadReportFile: creating TRpReport');
  FReport := TRpReport.Create(Self);
  LogMsg('LoadReportFile: calling LoadFromFile');
  try
    FReport.LoadFromFile(AFileName);
    FCurrentFileName := AFileName;
    LogMsg('LoadReportFile: setting Report to FReport');
    FDesignerFrame.Report := FReport;
    FStructure.Report := FReport;
    LogMsg('LoadReportFile: updating status');
    UpdateStatus;
    LogMsg('LoadReportFile: done');
  except
    on E: Exception do
    begin
      LogMsg('LoadReportFile exception: ' + E.ClassName + ': ' + E.Message);
      FreeAndNil(FReport);
      FDesignerFrame.Report := nil;
      ShowMessage('Error cargando reporte: ' + E.Message);
    end;
  end;
end;

procedure TMainForm.UpdateStatus;
var
  secCount: Integer;
  subName: string;
begin
  if Assigned(FReport) then
  begin
    StatusBar.Panels[0].Text := 'Reporte: ' + ExtractFileName(FCurrentFileName);
    secCount := 0;
    subName := '-';
    if Assigned(FDesignerFrame.CurrentSubreport) then
    begin
      secCount := FDesignerFrame.CurrentSubreport.Sections.Count;
      subName := 'SubReport (' + IntToStr(secCount) + ' secciones)';
    end;
    StatusBar.Panels[1].Text := subName;
    StatusBar.Panels[2].Text := 'Zoom: ' + IntToStr(Round(FDesignerFrame.Scale * 100)) + '%';
    StatusBar.Panels[3].Text := 'Listo';
    ComboScale.Text := IntToStr(Round(FDesignerFrame.Scale * 100)) + '%';
  end
  else
  begin
    StatusBar.Panels[0].Text := 'Reporte: Ninguno';
    StatusBar.Panels[1].Text := '-';
    StatusBar.Panels[2].Text := 'Zoom: 100%';
    StatusBar.Panels[3].Text := 'Listo';
    ComboScale.Text := '100%';
  end;
end;

procedure TMainForm.BtnOpenClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    LoadReportFile(OpenDialog.FileName);
end;



procedure TMainForm.BtnToolClick(Sender: TObject);
begin
  if Sender = BtnToolArrow then
    FDesignerFrame.ActiveTool := dtArrow
  else if Sender = BtnToolLabel then
    FDesignerFrame.ActiveTool := dtLabel
  else if Sender = BtnToolExpr then
    FDesignerFrame.ActiveTool := dtExpression
  else if Sender = BtnToolShape then
    FDesignerFrame.ActiveTool := dtShape
  else if Sender = BtnToolImage then
    FDesignerFrame.ActiveTool := dtImage
  else if Sender = BtnToolBarcode then
    FDesignerFrame.ActiveTool := dtBarcode
  else if Sender = BtnToolChart then
    FDesignerFrame.ActiveTool := dtChart;
end;

procedure TMainForm.DesignerToolChange(Sender: TObject);
begin
  case FDesignerFrame.ActiveTool of
    dtArrow: BtnToolArrow.Down := True;
    dtLabel: BtnToolLabel.Down := True;
    dtExpression: BtnToolExpr.Down := True;
    dtShape: BtnToolShape.Down := True;
    dtImage: BtnToolImage.Down := True;
    dtBarcode: BtnToolBarcode.Down := True;
    dtChart: BtnToolChart.Down := True;
  end;
end;

procedure TMainForm.BtnDeleteClick(Sender: TObject);
begin
  FDesignerFrame.DeleteSelection;
end;

procedure TMainForm.BtnToFrontClick(Sender: TObject);
begin
  FDesignerFrame.BringSelectionToFront;
end;

procedure TMainForm.BtnToBackClick(Sender: TObject);
begin
  FDesignerFrame.SendSelectionToBack;
end;

procedure TMainForm.BtnSelectAllClick(Sender: TObject);
begin
  FDesignerFrame.SelectAll;
end;

procedure TMainForm.BtnNewClick(Sender: TObject);
begin
  FDesignerFrame.Report := nil;
  FreeAndNil(FReport);
  FReport := TRpReport.Create(Self);
  FReport.SubReports.Add;
  FCurrentFileName := 'Nuevo Reporte.rep';
  FDesignerFrame.Report := FReport;
  UpdateStatus;
end;

procedure TMainForm.BtnSaveClick(Sender: TObject);
begin
  if Assigned(FReport) and (Length(FCurrentFileName) > 0) then
    ShowMessage('Guardar: ' + FCurrentFileName)
  else
    ShowMessage('No hay reporte cargado para guardar');
end;

procedure TMainForm.BtnDataConfigClick(Sender: TObject);
begin
  if not Assigned(FReport) then Exit;
  ShowDataConfig(FReport);
  if Assigned(FStructure) and Assigned(FStructure.browser) then
    FStructure.browser.Report := FReport;
  if Assigned(FDesignerFrame) then
    FDesignerFrame.UpdateSelection(False);
end;

procedure TMainForm.BtnPageSetupClick(Sender: TObject);
begin
  if not Assigned(FReport) then Exit;
  if ExecutePageSetup(FReport) then
  begin
    if Assigned(FDesignerFrame) then
    begin
      FDesignerFrame.UpdateInterface(True);
      FDesignerFrame.Refresh;
    end;
    UpdateStatus;
  end;
end;

procedure TMainForm.BtnPrintClick(Sender: TObject);
begin
  BtnPreviewClick(Sender);
end;

procedure TMainForm.BtnPreviewClick(Sender: TObject);
var
  previewCtrl: TRpPreviewControl;
begin
  if not Assigned(FReport) then Exit;
  try
    previewCtrl := TRpPreviewControl.Create(nil);
    try
      previewCtrl.Report := FReport;
      rplclpreview.ShowPreview(previewCtrl, 'Vista Previa - ' + Caption);
    finally
      previewCtrl.Free;
    end;
  except
    on E: Exception do
      ShowMessage('Error al previsualizar el informe: ' + E.Message);
  end;
end;

procedure TMainForm.BtnUndoClick(Sender: TObject);
begin
  LogMsg('Undo clicked');
end;

procedure TMainForm.BtnRedoClick(Sender: TObject);
begin
  LogMsg('Redo clicked');
end;

procedure TMainForm.BtnCutClick(Sender: TObject);
begin
  LogMsg('Cut clicked');
end;

procedure TMainForm.BtnCopyClick(Sender: TObject);
begin
  LogMsg('Copy clicked');
end;

procedure TMainForm.BtnPasteClick(Sender: TObject);
begin
  LogMsg('Paste clicked');
end;

procedure TMainForm.BtnNudgeLeftClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.MoveSelected(1, False);
end;

procedure TMainForm.BtnNudgeRightClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.MoveSelected(2, False);
end;

procedure TMainForm.BtnNudgeUpClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.MoveSelected(3, False);
end;

procedure TMainForm.BtnNudgeDownClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.MoveSelected(4, False);
end;

procedure TMainForm.BtnAlignLeftClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.AlignSelected(1);
end;

procedure TMainForm.BtnAlignRightClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.AlignSelected(2);
end;

procedure TMainForm.BtnAlignUpClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.AlignSelected(3);
end;

procedure TMainForm.BtnAlignDownClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.AlignSelected(4);
end;

procedure TMainForm.BtnAlignHorzClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.AlignSelected(5);
end;

procedure TMainForm.BtnAlignVertClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.AlignSelected(6);
end;

procedure TMainForm.ComboScaleChange(Sender: TObject);
var
  s: string;
  val: Integer;
begin
  s := ComboScale.Text;
  s := StringReplace(s, '%', '', [rfReplaceAll]);
  val := StrToIntDef(Trim(s), 100);
  if val > 0 then
  begin
    FDesignerFrame.Scale := val / 100.0;
    UpdateStatus;
  end;
end;

procedure TMainForm.RunSelfTest(Data: PtrInt);
var
  samplePath: string;
  ok: Boolean;
  secInt: TRpSectionInterface;
  comp1, comp2, newComp, newComp2, newComp3: TRpSizePosInterface;
  ruler0: TRpRulerLCL;
  expectedTop: Integer;
  origX1, origY1, origX2, origY2, deltaTwipsX, deltaTwipsY: Integer;
  origWidth: Integer;
  wStr, newWStr: string;
  frames: PPointer;
  cnt, i: Integer;
  initialChildCount, initialCompCount: Integer;
  fakeKey: Word;
  testSubrep: TRpSubReport;
  testSec: TRpSection;
  propVal: string;
  initialBrowserCount: Integer;
  testDB: TRpDatabaseInfoItem;
  testDS: TRpDataInfoItem;
  testDlg: TFRpDInfoLCL;
  testPageSetup: TFRpPageSetupVCL;
  origPageSize: TRpPageSize;
  origLeftMargin: Integer;
  testExpre: TFRpExpreDialogLCL;
  testExpreComp: TRpExpreDialogLCL;
  testGrid: TFRpGridOptionsLCL;
  testAbout: TFRpAboutBoxLCL;
  testSelFields: TFRpSelectFieldsLCL;
  testWizard: TFRpWizardLCL;
  testExtSec: TFRpExtSectionLCL;
  testColRep: TRpReport;
  testColSub: TRpSubReport;
  testColHdr, testColDet: TRpSection;
  colGen: TRpColumnar;
  testParamsDlg: TFRpParamsLCL;
  testSearchDlg: TFRpSearchParamLCL;
  testOpenLibDlg: TFRpOpenLibLCL;
  testParamItem: TRpParam;
  testCue, testCue2: TUndoCue;
  testOp: TChangeObjectOperation;
  testTargetComp: TRpCommonPosComponent;
  origCompPosX: Integer;
  cueJson: string;
  testAddLabel: TRpLabel;
  testSecItemCount: Integer;
  testTargetSec: TRpSection;
  testMainFLcl: TFRpMainFLCL;
  testCreatedComp: TRpSizePosInterface;
  testLastOp: TChangeObjectOperation;
  restoredComp: TRpCommonPosComponent;
begin
  LogMsg('RunSelfTest started');
  ok := False;
  // No test may block on a modal form: expected ones are answered, any
  // other one fails the run immediately
  InstallModalGuard;
  try
    samplePath := FindSampleFile('sample4.rep');
    if not FileExists(samplePath) then
    begin
      LogMsg('[TEST_FAILED] sample4.rep not found');
      Halt(1);
    end;

    LogMsg('RunSelfTest: loading sample4.rep');
    LoadReportFile(samplePath);
    LogMsg('RunSelfTest: LoadReportFile done');
    Show;
    LogMsg('RunSelfTest: Show done');
    Application.ProcessMessages;
    LogMsg('RunSelfTest: ProcessMessages done');

    if not Assigned(FReport) then
    begin
      LogMsg('[TEST_FAILED] Failed to load FReport');
      Halt(1);
    end;

    if FDesignerFrame.secinterfaces.Count = 0 then
    begin
      LogMsg('[TEST_FAILED] No section interfaces created in designer frame');
      Halt(1);
    end;

    LogMsg('Testing components in sample4.rep');
    for expectedTop := 0 to FDesignerFrame.secinterfaces.Count - 1 do
    begin
      secInt := TRpSectionInterface(FDesignerFrame.secinterfaces[expectedTop]);
      LogMsg(Format('Section %d child count: %d', [expectedTop, secInt.childlist.Count]));
      for origX1 := 0 to secInt.childlist.Count - 1 do
      begin
        comp1 := TRpSizePosInterface(secInt.childlist[origX1]);
        LogMsg(Format('Selecting section %d child %d: class %s', [expectedTop, origX1, comp1.ClassName]));
        FDesignerFrame.SelectComponent(comp1, False);
        Application.ProcessMessages;
      end;
    end;

    LogMsg('Testing Zoom with component selected');
    try
      ComboScale.Text := '50%';
      ComboScaleChange(ComboScale);
      LogMsg('Zoom 50% applied');
    except
      on E: Exception do
      begin
        LogMsg('Exception during Zoom 50%: ' + E.ClassName + ': ' + E.Message);
        LogMsg('At: ' + BackTraceStrFunc(ExceptAddr));
        frames := ExceptFrames;
        cnt := ExceptFrameCount;
        for i := 0 to cnt - 1 do
          LogMsg('Frame ' + IntToStr(i) + ': ' + BackTraceStrFunc(frames[i]));
        raise;
      end;
    end;
    ComboScale.Text := '100%';
    ComboScaleChange(ComboScale);
    LogMsg('Zoom 100% applied');

    // Test Units
    FDesignerFrame.TopRuler.Metrics := rInchess;
    FDesignerFrame.TopRuler.Metrics := rCms;

    // Test other sample
    samplePath := FindSampleFile('bold.rep');
    if FileExists(samplePath) then
    begin
      LoadReportFile(samplePath);
      if FDesignerFrame.secinterfaces.Count = 0 then
      begin
        LogMsg('[TEST_FAILED] Failed on bold.rep');
        Halt(1);
      end;
    end;

    // Test component selection and resizing
    if FDesignerFrame.secinterfaces.Count > 0 then
    begin
      secInt := TRpSectionInterface(FDesignerFrame.secinterfaces[0]);
      if secInt.childlist.Count > 0 then
      begin
        comp1 := TRpSizePosInterface(secInt.childlist[0]);

        // 1. Single selection -> black handles shown, Selected is False
        FDesignerFrame.SelectComponent(comp1, False);
        if FDesignerFrame.SelectedItems.Count <> 1 then
        begin
          LogMsg('[TEST_FAILED] SelectedItems.Count should be 1');
          Halt(1);
        end;
        if comp1.Selected then
        begin
          LogMsg('[TEST_FAILED] Single-selected component should not have Selected=True');
          Halt(1);
        end;
        if FDesignerFrame.SizeModifier.Control <> comp1 then
        begin
          LogMsg('[TEST_FAILED] SizeModifier.Control not assigned to selected component');
          Halt(1);
        end;

        // 1.1 Object Inspector verification for single selection
        if FObjInsp.CompItem <> comp1 then
        begin
          LogMsg('[TEST_FAILED] ObjInsp.CompItem should be comp1');
          Halt(1);
        end;
        if FObjInsp.SelectedItems.Count <> 1 then
        begin
          LogMsg('[TEST_FAILED] ObjInsp.SelectedItems.Count should be 1');
          Halt(1);
        end;

        // 1.2 Test reading and setting property through inspector
        origWidth := TRpCommonPosComponent(comp1.printitem).Width;
        wStr := FObjInsp.CompItem.GetProperty(SRpSWidth);
        if Length(wStr) = 0 then
        begin
          LogMsg('[TEST_FAILED] ObjInsp could not get Width property');
          Halt(1);
        end;

        newWStr := gettextfromtwips(origWidth + 720);
        FObjInsp.CompItem.SetProperty(SRpSWidth, newWStr);
        if TRpCommonPosComponent(comp1.printitem).Width <> (origWidth + 720) then
        begin
          LogMsg('[TEST_FAILED] Setting Width via ObjInsp did not update printitem');
          Halt(1);
        end;
        // Restore width
        FObjInsp.CompItem.SetProperty(SRpSWidth, gettextfromtwips(origWidth));

        // 2. Multi-selection (Shift) -> grey corners, black handles hidden
        if secInt.childlist.Count > 1 then
        begin
          comp2 := TRpSizePosInterface(secInt.childlist[1]);
          FDesignerFrame.SelectComponent(comp2, True);
          if FDesignerFrame.SelectedItems.Count <> 2 then
          begin
            LogMsg('[TEST_FAILED] SelectedItems.Count should be 2 after Shift-select');
            Halt(1);
          end;
          // Verify ObjInsp multi-selection
          if FObjInsp.SelectedItems.Count <> 2 then
          begin
            LogMsg('[TEST_FAILED] ObjInsp.SelectedItems.Count should be 2 after Shift-select');
            Halt(1);
          end;
          if not comp1.Selected or not comp2.Selected then
          begin
            LogMsg('[TEST_FAILED] Multi-selected components must have Selected=True');
            Halt(1);
          end;
          if FDesignerFrame.SizeModifier.Control <> nil then
          begin
            LogMsg('[TEST_FAILED] SizeModifier.Control must be nil during multi-select');
            Halt(1);
          end;

          // 2.5 Multi-selection move test: drag comp1, comp2 moves with it
          origX1 := TRpCommonPosComponent(comp1.printitem).PosX;
          origY1 := TRpCommonPosComponent(comp1.printitem).PosY;
          origX2 := TRpCommonPosComponent(comp2.printitem).PosX;
          origY2 := TRpCommonPosComponent(comp2.printitem).PosY;

          TRpSizePosInterfaceAccess(comp1).MouseDown(mbLeft, [], 10, 10);
          TRpSizePosInterfaceAccess(comp1).FBlocked := False;
          TRpSizePosInterfaceAccess(comp1).MouseUp(mbLeft, [], 60, 30);

          deltaTwipsX := TRpCommonPosComponent(comp1.printitem).PosX - origX1;
          deltaTwipsY := TRpCommonPosComponent(comp1.printitem).PosY - origY1;

          if (deltaTwipsX = 0) and (deltaTwipsY = 0) then
          begin
            LogMsg('[TEST_FAILED] Drag did not move leader component');
            Halt(1);
          end;

          if (TRpCommonPosComponent(comp2.printitem).PosX - origX2 <> deltaTwipsX) or
             (TRpCommonPosComponent(comp2.printitem).PosY - origY2 <> deltaTwipsY) then
          begin
            LogMsg('[TEST_FAILED] Multi-move did not move comp2 by identical delta');
            Halt(1);
          end;

          if FDesignerFrame.SelectedItems.Count <> 2 then
          begin
            LogMsg('[TEST_FAILED] Multi-selection should be preserved after moving');
            Halt(1);
          end;

          // Also test MoveSelectedComponents clamping to 0,0
          FDesignerFrame.MoveSelectedComponents(comp1, -999999, -999999);
          if (TRpCommonPosComponent(comp1.printitem).PosX < 0) or
             (TRpCommonPosComponent(comp1.printitem).PosY < 0) or
             (TRpCommonPosComponent(comp2.printitem).PosX < 0) or
             (TRpCommonPosComponent(comp2.printitem).PosY < 0) then
          begin
            LogMsg('[TEST_FAILED] MoveSelectedComponents allowed negative position');
            Halt(1);
          end;
        end;

        // 3. Clear selection -> nothing selected, no black handles
        FDesignerFrame.ClearSelection;
        if FDesignerFrame.SelectedItems.Count <> 0 then
        begin
          LogMsg('[TEST_FAILED] SelectedItems.Count should be 0 after ClearSelection');
          Halt(1);
        end;
        if FObjInsp.SelectedItems.Count <> 0 then
        begin
          LogMsg('[TEST_FAILED] ObjInsp.SelectedItems.Count should be 0 after ClearSelection');
          Halt(1);
        end;
        if comp1.Selected then
        begin
          LogMsg('[TEST_FAILED] Component should have Selected=False after ClearSelection');
          Halt(1);
        end;
        if FDesignerFrame.SizeModifier.Control <> nil then
        begin
          LogMsg('[TEST_FAILED] SizeModifier.Control must be nil after ClearSelection');
          Halt(1);
        end;
      end;

      // 4. Test ruler vertical scrolling synchronization
      FDesignerFrame.SectionScrollBox.VertScrollBar.Position := 80;
      FDesignerFrame.SectionScrollBox.ScrollBy(0, -80);
      if FDesignerFrame.leftrulers.Count > 0 then
      begin
        ruler0 := TRpRulerLCL(FDesignerFrame.leftrulers[0]);
        expectedTop := TRpSectionInterface(FDesignerFrame.secinterfaces[0]).Top - FDesignerFrame.SectionScrollBox.VertScrollBar.Position;
        if ruler0.Top <> expectedTop then
        begin
          LogMsg(Format('[TEST_FAILED] Ruler Top mismatch: got %d, expected %d', [ruler0.Top, expectedTop]));
          Halt(1);
        end;
      end;
    end;

    // 5. Test Subphase 3.2: Tool palette, Component creation, Z-order, and Deletion
    LogMsg('Testing Subphase 3.2 features...');
    // 5.1 Tool switching and Esc shortcut
    FDesignerFrame.ActiveTool := dtLabel;
    if (FDesignerFrame.ActiveTool <> dtLabel) or not BtnToolLabel.Down then
    begin
      LogMsg('[TEST_FAILED] ActiveTool := dtLabel did not update tool or button');
      Halt(1);
    end;

    // Simulate Escape key in SectionKeyDown
    fakeKey := VK_ESCAPE;
    FDesignerFrame.SectionKeyDown(Self, fakeKey, []);
    if (FDesignerFrame.ActiveTool <> dtArrow) or not BtnToolArrow.Down then
    begin
      LogMsg('[TEST_FAILED] Escape did not reset ActiveTool to dtArrow');
      Halt(1);
    end;

    // 5.2 Component creation via secInt.CreateNewComponent
    secInt := TRpSectionInterface(FDesignerFrame.secinterfaces[0]);
    initialChildCount := secInt.childlist.Count;
    initialCompCount := TRpSection(secInt.printitem).ReportComponents.Count;

    newComp := secInt.CreateNewComponent(dtLabel, 30, 30, 100, 25);
    if not Assigned(newComp) or not (newComp.printitem is TRpLabel) then
    begin
      LogMsg('[TEST_FAILED] CreateNewComponent(dtLabel) failed');
      Halt(1);
    end;
    if Length(newComp.printitem.Name) = 0 then
    begin
      LogMsg('[TEST_FAILED] New component has empty name');
      Halt(1);
    end;
    if TRpLabel(newComp.printitem).Text <> SRpSampleTextToLabels then
    begin
      LogMsg('[TEST_FAILED] New label text mismatch');
      Halt(1);
    end;
    if secInt.childlist.Count <> initialChildCount + 1 then
    begin
      LogMsg('[TEST_FAILED] Section childlist count did not increase by 1');
      Halt(1);
    end;
    if TRpSection(secInt.printitem).ReportComponents.Count <> initialCompCount + 1 then
    begin
      LogMsg('[TEST_FAILED] Section ReportComponents count did not increase by 1');
      Halt(1);
    end;
    if (FDesignerFrame.SelectedItems.Count <> 1) or (FDesignerFrame.SelectedItems[0] <> newComp) then
    begin
      LogMsg('[TEST_FAILED] New component was not automatically selected');
      Halt(1);
    end;
    if FObjInsp.CompItem <> newComp then
    begin
      LogMsg('[TEST_FAILED] Object Inspector not inspecting new component');
      Halt(1);
    end;

    // Insert an expression
    newComp2 := secInt.CreateNewComponent(dtExpression, 140, 30, 100, 25);
    if not Assigned(newComp2) or not (newComp2.printitem is TRpExpression) then
    begin
      LogMsg('[TEST_FAILED] CreateNewComponent(dtExpression) failed');
      Halt(1);
    end;
    if secInt.childlist.Count <> initialChildCount + 2 then
    begin
      LogMsg('[TEST_FAILED] Section childlist count did not increase to +2');
      Halt(1);
    end;

    // Insert a shape
    newComp3 := secInt.CreateNewComponent(dtShape, 30, 65, 80, 40);
    if not Assigned(newComp3) or not (newComp3.printitem is TRpShape) then
    begin
      LogMsg('[TEST_FAILED] CreateNewComponent(dtShape) failed');
      Halt(1);
    end;
    if TRpShape(newComp3.printitem).Shape <> rpsRectangle then
    begin
      LogMsg('[TEST_FAILED] New shape is not rpsRectangle');
      Halt(1);
    end;
    if secInt.childlist.Count <> initialChildCount + 3 then
    begin
      LogMsg('[TEST_FAILED] Section childlist count did not increase to +3');
      Halt(1);
    end;

    // 5.3 Z-Order: SendSelectionToBack and BringSelectionToFront
    // newComp3 is currently selected
    FDesignerFrame.SendSelectionToBack;
    if TRpSection(secInt.printitem).ReportComponents[0].Component <> newComp3.printitem then
    begin
      LogMsg('[TEST_FAILED] SendSelectionToBack did not move component to index 0');
      Halt(1);
    end;

    FDesignerFrame.BringSelectionToFront;
    if TRpSection(secInt.printitem).ReportComponents[TRpSection(secInt.printitem).ReportComponents.Count - 1].Component <> newComp3.printitem then
    begin
      LogMsg('[TEST_FAILED] BringSelectionToFront did not move component to last index');
      Halt(1);
    end;

    // 5.4 SelectAll
    FDesignerFrame.SelectAll;
    if FDesignerFrame.SelectedItems.Count < initialChildCount + 3 then
    begin
      LogMsg('[TEST_FAILED] SelectAll did not select all components');
      Halt(1);
    end;

    // 5.5 DeleteSelection
    // Select newComp and newComp2
    FDesignerFrame.ClearSelection;
    FDesignerFrame.SelectComponent(newComp, False);
    FDesignerFrame.SelectComponent(newComp2, True);
    if FDesignerFrame.SelectedItems.Count <> 2 then
    begin
      LogMsg('[TEST_FAILED] Could not select newComp and newComp2');
      Halt(1);
    end;

    FDesignerFrame.DeleteSelection;
    if FDesignerFrame.SelectedItems.Count <> 0 then
    begin
      LogMsg('[TEST_FAILED] DeleteSelection should clear selected items');
      Halt(1);
    end;
    if (secInt.childlist.IndexOf(newComp) >= 0) or (secInt.childlist.IndexOf(newComp2) >= 0) then
    begin
      LogMsg('[TEST_FAILED] Deleted items still found in childlist');
      Halt(1);
    end;
    if (TRpSection(secInt.printitem).ReportComponents.IndexOf(newComp.printitem) >= 0) or
       (TRpSection(secInt.printitem).ReportComponents.IndexOf(newComp2.printitem) >= 0) then
    begin
      LogMsg('[TEST_FAILED] Deleted items still found in section components');
      Halt(1);
    end;
    if secInt.childlist.Count <> initialChildCount + 1 then
    begin
      LogMsg('[TEST_FAILED] childlist count mismatch after deleting 2 components');
      Halt(1);
    end;

    // Delete newComp3 via SectionKeyDown VK_DELETE
    FDesignerFrame.SelectComponent(newComp3, False);
    fakeKey := VK_DELETE;
    FDesignerFrame.SectionKeyDown(Self, fakeKey, []);
    if secInt.childlist.Count <> initialChildCount then
    begin
      LogMsg('[TEST_FAILED] childlist count should be back to initial after deleting newComp3');
      Halt(1);
    end;
    if TRpSection(secInt.printitem).ReportComponents.Count <> initialCompCount then
    begin
      LogMsg('[TEST_FAILED] ReportComponents count should be back to initial');
      Halt(1);
    end;

    // 5.6 Interactive mouse placement test
    FDesignerFrame.ActiveTool := dtBarcode;
    secInt.SectionControl.ExecuteMouseDown(mbLeft, [], 40, 40);
    secInt.SectionControl.ExecuteMouseUp(mbLeft, [], 40, 40);
    if FDesignerFrame.ActiveTool <> dtArrow then
    begin
      LogMsg('[TEST_FAILED] Mouse placement should reset ActiveTool to dtArrow');
      Halt(1);
    end;
    if secInt.childlist.Count <> initialChildCount + 1 then
    begin
      LogMsg('[TEST_FAILED] Mouse placement did not create a new component');
      Halt(1);
    end;
    newComp := TRpSizePosInterface(secInt.childlist[secInt.childlist.Count - 1]);
    if not (newComp.printitem is TRpBarcode) then
    begin
      LogMsg('[TEST_FAILED] Interactive component is not a TRpBarcode');
      Halt(1);
    end;
    // Clean up created barcode
    FDesignerFrame.SelectComponent(newComp, False);
    FDesignerFrame.DeleteSelection;
    if secInt.childlist.Count <> initialChildCount then
    begin
      LogMsg('[TEST_FAILED] Clean up after interactive placement failed');
      Halt(1);
    end;

    // 5.7 Test toolbar ImageList and ComboScale zoom
    if ImageList1.Count < 36 then
    begin
      LogMsg(Format('[TEST_FAILED] ImageList1 should contain 36 icons, got %d', [ImageList1.Count]));
      Halt(1);
    end;
    // 19x19 at 96 ppi, scaled to the screen (rpmdimageslcl)
    if (ImageList1.Width <> MulDiv(19, Screen.PixelsPerInch, 96)) or
      (ImageList1.Height <> MulDiv(19, Screen.PixelsPerInch, 96)) then
    begin
      LogMsg(Format('[TEST_FAILED] ImageList1 dimensions must be 19x19 at 96 ppi (%d at %d ppi), got %dx%d',
        [MulDiv(19, Screen.PixelsPerInch, 96), Screen.PixelsPerInch, ImageList1.Width, ImageList1.Height]));
      Halt(1);
    end;
    ComboScale.Text := '150%';
    ComboScale.OnChange(ComboScale);
    if Abs(FDesignerFrame.Scale - 1.5) > 0.001 then
    begin
      LogMsg(Format('[TEST_FAILED] ComboScale zoom failed: expected 1.5, got %f', [FDesignerFrame.Scale]));
      Halt(1);
    end;
    ComboScale.Text := '100%';
    ComboScale.OnChange(ComboScale);
    if Abs(FDesignerFrame.Scale - 1.0) > 0.001 then
    begin
      LogMsg(Format('[TEST_FAILED] ComboScale reset zoom failed: expected 1.0, got %f', [FDesignerFrame.Scale]));
      Halt(1);
    end;

    // 5.8 Test Subphase 3.3 Structure Tree and Browser
    LogMsg('Testing Subphase 3.3: Structure Tree & Data Browser...');
    if not Assigned(FStructure) or not Assigned(FStructure.RView) then
    begin
      LogMsg('[TEST_FAILED] FStructure or RView not assigned');
      Halt(1);
    end;
    if FStructure.RView.Items.Count = 0 then
    begin
      LogMsg('[TEST_FAILED] RView has 0 nodes after loading report');
      Halt(1);
    end;
    if not (TObject(FStructure.RView.Items[0].Data) is TRpSubReport) then
    begin
      LogMsg('[TEST_FAILED] RView root node is not TRpSubReport');
      Halt(1);
    end;
    if (FStructure.RView.Items.Count < 2) or not (TObject(FStructure.RView.Items[1].Data) is TRpSection) then
    begin
      LogMsg('[TEST_FAILED] RView child node is not TRpSection');
      Halt(1);
    end;
    // Test SelectDataItem
    secInt := TRpSectionInterface(FDesignerFrame.secinterfaces[0]);
    FStructure.SelectDataItem(secInt.printitem);
    if not Assigned(FStructure.RView.Selected) or (FStructure.RView.Selected.Data <> secInt.printitem) then
    begin
      LogMsg('[TEST_FAILED] SelectDataItem did not select section node');
      Halt(1);
    end;
    // Test browser (Data tab)
    if not Assigned(FStructure.browser) or not Assigned(FStructure.browser.ATree) then
    begin
      LogMsg('[TEST_FAILED] FStructure.browser not assigned');
      Halt(1);
    end;
    if FStructure.browser.ATree.Items.Count = 0 then
    begin
      LogMsg('[TEST_FAILED] browser.ATree has 0 nodes after setting report');
      Halt(1);
    end;

    // Test dynamic section addition and moving via Structure Frame
    testSubrep := FStructure.FindSelectedSubreport;
    testSec := testSubrep.AddDetail;
    FStructure.CreateInterface;
    if FStructure.RView.Items.Count <> 3 then
    begin
      LogMsg(Format('[TEST_FAILED] Expected 3 tree nodes after AddDetail, got %d', [FStructure.RView.Items.Count]));
      Halt(1);
    end;
    FStructure.SelectDataItem(testSec);
    if FStructure.RView.Selected.Data <> testSec then
    begin
      LogMsg('[TEST_FAILED] SelectDataItem did not select newly added testSec');
      Halt(1);
    end;
    FStructure.BUpClick(FStructure.BUp);
    if testSubrep.Sections.Items[0].Section <> testSec then
    begin
      LogMsg('[TEST_FAILED] BUpClick did not move testSec up');
      Halt(1);
    end;
    FStructure.BDownClick(FStructure.BDown);
    if testSubrep.Sections.Items[1].Section <> testSec then
    begin
      LogMsg('[TEST_FAILED] BDownClick did not move testSec down');
      Halt(1);
    end;
    testSubrep.FreeSection(testSec);
    FStructure.CreateInterface;
    if FStructure.RView.Items.Count <> 2 then
    begin
      LogMsg('[TEST_FAILED] FreeSection did not restore node count to 2');
      Halt(1);
    end;

    // Reload sample4.rep and verify all 9 tree nodes (1 subrep + 8 sections)
    samplePath := FindSampleFile('sample4.rep');
    LoadReportFile(samplePath);
    if FStructure.RView.Items.Count <> 9 then
    begin
      LogMsg(Format('[TEST_FAILED] Expected 9 tree nodes for sample4.rep, got %d', [FStructure.RView.Items.Count]));
      Halt(1);
    end;
    LogMsg(Format('Structure Tree OK: %d tree nodes, %d browser nodes', [FStructure.RView.Items.Count, FStructure.browser.ATree.Items.Count]));

    // -----------------------------------------------------------------
    // Testing Subphase 3.4: Report & Data Structure Configuration Interface
    // -----------------------------------------------------------------
    LogMsg('Testing Subphase 3.4: Report & Data Structure Configuration...');

    // 1. Verify section properties in Object Inspector
    secInt := TRpSectionInterface(FDesignerFrame.secinterfaces[0]);
    FStructure.SelectDataItem(secInt.printitem);
    if not Assigned(FObjInsp.CompItem) then
    begin
      LogMsg('[TEST_FAILED] FObjInsp has no active CompItem for section');
      Halt(1);
    end;
    propVal := secInt.GetProperty(SRpSAutoExpand);
    LogMsg('Section AutoExpand=' + propVal);
    secInt.SetProperty(SRpSAutoExpand, BoolToStr(not StrToBool(propVal), True));
    if secInt.GetProperty(SRpSAutoExpand) = propVal then
    begin
      LogMsg('[TEST_FAILED] SetProperty failed to change AutoExpand');
      Halt(1);
    end;
    // Restore
    secInt.SetProperty(SRpSAutoExpand, propVal);

    // 2. Test group section properties
    testSec := nil;
    for i := 0 to FReport.SubReports[0].SubReport.Sections.Count - 1 do
    begin
      if FReport.SubReports[0].SubReport.Sections[i].Section.SectionType = rpsecgheader then
      begin
        testSec := FReport.SubReports[0].SubReport.Sections[i].Section;
        break;
      end;
    end;
    if Assigned(testSec) then
    begin
      FStructure.SelectDataItem(testSec);
      secInt := nil;
      for i := 0 to FDesignerFrame.secinterfaces.Count - 1 do
      begin
        if TRpSectionInterface(FDesignerFrame.secinterfaces[i]).printitem = testSec then
        begin
          secInt := TRpSectionInterface(FDesignerFrame.secinterfaces[i]);
          break;
        end;
      end;
      if Assigned(secInt) then
      begin
        secInt.SetProperty(SRpSGroupExpression, 'TEST_CHANGE_EXPR');
        if secInt.GetProperty(SRpSGroupExpression) <> 'TEST_CHANGE_EXPR' then
        begin
          LogMsg('[TEST_FAILED] SetProperty failed to change ChangeExpression on group section');
          Halt(1);
        end;
        LogMsg('Group ChangeExpression verified: ' + secInt.GetProperty(SRpSGroupExpression));
      end;
    end;

    // 3. Test SubReport selection in Structure Tree
    testSubrep := FReport.SubReports[0].SubReport;
    FStructure.SelectDataItem(testSubrep);
    if FStructure.RView.Selected.Data <> testSubrep then
    begin
      LogMsg('[TEST_FAILED] SelectDataItem failed to select subreport');
      Halt(1);
    end;
    LogMsg('Subreport display name: ' + testSubrep.GetDisplayName(True));

    // 4. Test Data access configuration & programmatic addition of Connections/Datasets
    initialBrowserCount := FStructure.browser.ATree.Items.Count;
    testDB := FReport.DatabaseInfo.Add('TEST_DB_AUTO');
    testDB.Driver := rpdatadriver;
    testDS := FReport.DataInfo.Add('TEST_DS_AUTO');
    testDS.DatabaseAlias := 'TEST_DB_AUTO';
    testDS.SQL := 'SELECT 1 AS COL1;';
    testDS.OpenOnStart := True;

    FStructure.browser.Report := FReport;
    if FStructure.browser.ATree.Items.Count <= initialBrowserCount then
    begin
      LogMsg(Format('[TEST_FAILED] Expected browser node count > %d, got %d',
        [initialBrowserCount, FStructure.browser.ATree.Items.Count]));
      Halt(1);
    end;
    LogMsg(Format('Data structure updated: browser nodes went from %d to %d',
      [initialBrowserCount, FStructure.browser.ATree.Items.Count]));

    // Test TFRpDInfoLCL form instantiation and data loading
    testDlg := TFRpDInfoLCL.Create(nil);
    try
      testDlg.Report := FReport;
      if (testDlg.BNewConn.ImageIndex <> IMG_DC_NEW) or
         (testDlg.BDelConn.ImageIndex <> IMG_DC_DELETE) or
         (testDlg.BNewDS.ImageIndex <> IMG_DC_NEW) or
         (testDlg.BtnUpDS.ImageIndex <> IMG_DC_UP) or
         (testDlg.BtnDownDS.ImageIndex <> IMG_DC_DOWN) or
         (testDlg.BDelDS.ImageIndex <> IMG_DC_DELETE) or
         (testDlg.BtnRenameDS.ImageIndex <> IMG_DC_RENAME) then
      begin
        LogMsg('[TEST_FAILED] TFRpDInfoLCL toolbar button ImageIndex mismatch');
        Halt(1);
      end;
      LogMsg('TFRpDInfoLCL successfully loaded report data info and verified toolbar icons');
    finally
      testDlg.Free;
    end;

    // Clean up test database and dataset
    FReport.DataInfo.Delete(FReport.DataInfo.IndexOf('TEST_DS_AUTO'));
    FReport.DatabaseInfo.Delete(FReport.DatabaseInfo.IndexOf('TEST_DB_AUTO'));
    FStructure.browser.Report := FReport;
    if FStructure.browser.ATree.Items.Count <> initialBrowserCount then
    begin
      LogMsg('[TEST_FAILED] Browser node count did not restore after deleting test items');
      Halt(1);
    end;
    LogMsg('Subphase 3.4 verification completed successfully');

    // -----------------------------------------------------------------
    // Testing Subphase 3.5: Page Setup & Monaco SQL Integration
    // -----------------------------------------------------------------
    LogMsg('Testing Subphase 3.5: Page Setup & Monaco SQL Integration...');

    // 1. Verify BtnPageSetup toolbar button
    if not Assigned(BtnPageSetup) then
    begin
      LogMsg('[TEST_FAILED] BtnPageSetup not assigned');
      Halt(1);
    end;
    if BtnPageSetup.ImageIndex <> IMG_PAGESETUP then
    begin
      LogMsg(Format('[TEST_FAILED] BtnPageSetup ImageIndex mismatch: got %d, expected %d',
        [BtnPageSetup.ImageIndex, IMG_PAGESETUP]));
      Halt(1);
    end;
    LogMsg(Format('BtnPageSetup verified on MainToolBar with icon index %d', [IMG_PAGESETUP]));

    // 2. Test TFRpPageSetupVCL instantiation and controls
    testPageSetup := TFRpPageSetupVCL.Create(nil);
    try
      LogMsg('TFRpPageSetupVCL successfully instantiated and verified');
    finally
      testPageSetup.Free;
    end;

    // 3. Test programmatic report page property modification
    origLeftMargin := FReport.LeftMargin;
    FReport.LeftMargin := origLeftMargin + 720; // 0.5 in / 1.27 cm
    FReport.DocTitle := 'Subphase 3.5 Verified Report';
    FReport.PDFConformance := TPDFConformanceType.PDF_A_3;

    if FReport.LeftMargin <> origLeftMargin + 720 then
    begin
      LogMsg('[TEST_FAILED] FReport LeftMargin modification failed');
      Halt(1);
    end;
    if FReport.DocTitle <> 'Subphase 3.5 Verified Report' then
    begin
      LogMsg('[TEST_FAILED] FReport DocTitle modification failed');
      Halt(1);
    end;
    if FReport.PDFConformance <> TPDFConformanceType.PDF_A_3 then
    begin
      LogMsg('[TEST_FAILED] FReport PDFConformance modification failed');
      Halt(1);
    end;

    // Restore original margins
    FReport.LeftMargin := origLeftMargin;
    LogMsg('Report page properties verified');

    // 3. Test Monaco SQL editor in TFRpDInfoLCL
    testDlg := TFRpDInfoLCL.Create(nil);
    try
      testDlg.Report := FReport;
      if not Assigned(testDlg.MonacoEditor) then
      begin
        LogMsg('[TEST_FAILED] TFRpDInfoLCL MonacoEditor instance not assigned');
        Halt(1);
      end;
      // Test setting and getting SQL through Monaco editor
      testDlg.MonacoEditor.SQL := 'SELECT CustomerID, CompanyName FROM Customers WHERE Active = 1;';
      if testDlg.MonacoEditor.SQL <> 'SELECT CustomerID, CompanyName FROM Customers WHERE Active = 1;' then
      begin
        LogMsg('[TEST_FAILED] MonacoEditor SQL property readback mismatch');
        Halt(1);
      end;
      LogMsg('Monaco SQL editor in TFRpDInfoLCL verified');
    finally
      testDlg.Free;
    end;
    LogMsg('Subphase 3.5 verification completed successfully');

    // -----------------------------------------------------------------
    // Testing Subphase 4.1: Auxiliary Dialogs (Expression, Grid, About)
    // -----------------------------------------------------------------
    LogMsg('Testing Subphase 4.1: Auxiliary Dialogs...');

    // 1. Expression Dialog
    testExpre := TFRpExpreDialogLCL.Create(nil);
    try
      testExpre.Evaluator := FReport.Evaluator;
      testExpre.MemoExpre.Text := '10 * 5';
      if testExpre.MemoExpre.Text <> '10 * 5' then
      begin
        LogMsg('[TEST_FAILED] TFRpExpreDialogLCL MemoExpre mismatch');
        Halt(1);
      end;
      LogMsg('TFRpExpreDialogLCL verified');
    finally
      testExpre.Free;
    end;

    testExpreComp := TRpExpreDialogLCL.Create(nil);
    try
      testExpreComp.Evaluator := FReport.Evaluator;
      testExpreComp.Expression.Text := '1 + 2 * 3';
      if Trim(testExpreComp.Expression.Text) <> '1 + 2 * 3' then
      begin
        LogMsg('[TEST_FAILED] TRpExpreDialogLCL Expression mismatch');
        Halt(1);
      end;
      LogMsg('TRpExpreDialogLCL component verified');
    finally
      testExpreComp.Free;
    end;

    // 2. Grid Options Dialog
    testGrid := TFRpGridOptionsLCL.Create(nil);
    try
      testGrid.Report := FReport;
      LogMsg('TFRpGridOptionsLCL verified');
    finally
      testGrid.Free;
    end;

    // 3. About Box Dialog
    testAbout := TFRpAboutBoxLCL.Create(nil);
    try
      LogMsg('TFRpAboutBoxLCL verified');
    finally
      testAbout.Free;
    end;
    LogMsg('Subphase 4.1 verification completed successfully');

    // -----------------------------------------------------------------
    // Testing Subphase 4.2: Wizards & Section Dialogs
    // -----------------------------------------------------------------
    LogMsg('Testing Subphase 4.2: Wizards & Section Dialogs...');

    // 1. Columnar Layout Generator
    testColRep := TRpReport.Create(nil);
    try
      testColSub := testColRep.AddSubReport;
      testColHdr := testColSub.AddPageHeader;
      testColDet := testColSub.Sections.Items[testColSub.FirstDetail].Section;
      colGen := TRpColumnar.Create;
      try
        colGen.Report := testColRep;
        colGen.AddColumn(10, 'TEST_EXPR', '', 'Test Header', '', '', '');
        if testColDet.ReportComponents.Count = 0 then
        begin
          LogMsg('[TEST_FAILED] TRpColumnar did not create expression component in detail section');
          Halt(1);
        end;
        if testColHdr.ReportComponents.Count = 0 then
        begin
          LogMsg('[TEST_FAILED] TRpColumnar did not create label component in header section');
          Halt(1);
        end;
        LogMsg('TRpColumnar columnar layout generation verified');
      finally
        colGen.Free;
      end;
    finally
      testColRep.Free;
    end;

    // 2. Field Selection Panel
    testSelFields := TFRpSelectFieldsLCL.Create(nil);
    try
      testSelFields.Report := FReport;
      testSelFields.UpdateDatasets;
      if testSelFields.ComboDataset.Items.Count = 0 then
      begin
        LogMsg('[TEST_FAILED] TFRpSelectFieldsLCL ComboDataset is empty for sample report');
        Halt(1);
      end;
      testSelFields.fieldlist.Add('CUSTOMER_NAME');
      testSelFields.LSelected.Items.Add('CUSTOMER_NAME');
      testSelFields.LSelected.Checked[0] := True;
      if (testSelFields.LSelected.Items.Count <> 1) or not testSelFields.LSelected.Checked[0] then
      begin
        LogMsg('[TEST_FAILED] TFRpSelectFieldsLCL selected field list failed');
        Halt(1);
      end;
      LogMsg('TFRpSelectFieldsLCL panel verified');
    finally
      testSelFields.Free;
    end;

    // 3. Report Wizard Dialog
    testWizard := TFRpWizardLCL.Create(nil);
    try
      testWizard.Report := FReport;
      if testWizard.FromTemplate then
      begin
        LogMsg('[TEST_FAILED] TFRpWizardLCL FromTemplate should be False initially');
        Halt(1);
      end;
      testWizard.FromTemplate := True;
      if not testWizard.FromTemplate then
      begin
        LogMsg('[TEST_FAILED] TFRpWizardLCL FromTemplate property assignment failed');
        Halt(1);
      end;
      LogMsg('TFRpWizardLCL report wizard form verified');
    finally
      testWizard.Free;
    end;

    // 4. External Section Dialog
    testExtSec := TFRpExtSectionLCL.Create(nil);
    try
      testExtSec.Report := FReport;
      testExtSec.Section := TRpSection(TRpSectionInterface(FDesignerFrame.secinterfaces[0]).printitem);
      if (testExtSec.Report <> FReport) or not Assigned(testExtSec.Section) then
      begin
        LogMsg('[TEST_FAILED] TFRpExtSectionLCL Report or Section property assignment failed');
        Halt(1);
      end;
      LogMsg('TFRpExtSectionLCL external section form verified');
    finally
      testExtSec.Free;
    end;
    LogMsg('Subphase 4.2 verification completed successfully');
 
     // -----------------------------------------------------------------
     // Testing Subphase 4.3: Parameters, Search & Report Library Dialogs
     // -----------------------------------------------------------------
     LogMsg('Testing Subphase 4.3: Parameters, Search & Report Library Dialogs...');

     // 1. Parameter definition dialog (TFRpParamsLCL)
     LogMsg('4.3.1 Creating TFRpParamsLCL');
     testParamsDlg := TFRpParamsLCL.Create(nil);
     LogMsg('4.3.1 TFRpParamsLCL Created');
     try
       testParamsDlg.Report := FReport;
       LogMsg('4.3.1 Calling FillParamList 1');
       testParamsDlg.FillParamList;
       LogMsg('4.3.1 FillParamList 1 done');
       // Add a test parameter to report
       testParamItem := FReport.Params.Add('SUBPHASE43_TEST');
       testParamItem.Value := 'TestVal123';
       testParamsDlg.Params.Assign(FReport.Params);
       LogMsg('4.3.1 Calling FillParamList 2');
       testParamsDlg.FillParamList;
       LogMsg('4.3.1 FillParamList 2 done');
       if testParamsDlg.LParams.Items.IndexOf('SUBPHASE43_TEST') < 0 then
       begin
         LogMsg('[TEST_FAILED] TFRpParamsLCL did not find added parameter in list');
         Halt(1);
       end;
       LogMsg('TFRpParamsLCL parameter definition form verified');
     finally
       testParamsDlg.Free;
     end;

     // 2. Parameter value search dialog (TFRpSearchParamLCL)
     testSearchDlg := TFRpSearchParamLCL.Create(nil);
     try
       if (testSearchDlg.GridData = nil) or (testSearchDlg.ESearch = nil) then
       begin
         LogMsg('[TEST_FAILED] TFRpSearchParamLCL controls not initialized');
         Halt(1);
       end;
       LogMsg('TFRpSearchParamLCL parameter search dialog verified');
     finally
       testSearchDlg.Free;
     end;

     // 3. Database report library dialog (TFRpOpenLibLCL)
     testOpenLibDlg := TFRpOpenLibLCL.Create(nil);
     try
       if (testOpenLibDlg.ComboLibrary = nil) or (testOpenLibDlg.ATree = nil) then
       begin
         LogMsg('[TEST_FAILED] TFRpOpenLibLCL controls not initialized');
         Halt(1);
       end;
       LogMsg('TFRpOpenLibLCL report library dialog verified');
     finally
       testOpenLibDlg.Free;
     end;

     // 4. Verify GlobalParamValueSearch hook registration
     if not Assigned(rprflclparams.GlobalParamValueSearch) then
     begin
       LogMsg('[TEST_FAILED] rprflclparams.GlobalParamValueSearch not registered');
       Halt(1);
     end;
     LogMsg('GlobalParamValueSearch hook registration verified');

     LogMsg('Subphase 4.3 verification completed successfully');

     // -----------------------------------------------------------------
     // Testing Subphase 5.1: Undo Cue Engine in FPC/LCL
     // -----------------------------------------------------------------
     LogMsg('Testing Subphase 5.1: Undo Cue Engine in FPC/LCL...');

     testCue := TUndoCue.Create(FReport);
     try
       // 1. Initial state and group ID generation
       if (testCue.UndoOperations.Count <> 0) or (testCue.RedoOperations.Count <> 0) then
       begin
         LogMsg('[TEST_FAILED] TUndoCue operations not empty initially');
         Halt(1);
       end;
       if testCue.GetGroupId <> 1 then
       begin
         LogMsg('[TEST_FAILED] TUndoCue initial GetGroupId should be 1');
         Halt(1);
       end;
       if testCue.GetGroupId <> 2 then
       begin
         LogMsg('[TEST_FAILED] TUndoCue subsequent GetGroupId should be 2');
         Halt(1);
       end;

       // 2. Test otModify on a report component
       secInt := TRpSectionInterface(FDesignerFrame.secinterfaces[0]);
       testTargetSec := TRpSection(secInt.printitem);
       testTargetComp := TRpCommonPosComponent(TRpSizePosInterface(secInt.childlist[0]).printitem);
       origCompPosX := testTargetComp.PosX;

       testOp := TChangeObjectOperation.Create(otModify, testCue.GetGroupId);
       testOp.componentName := testTargetComp.Name;
       testOp.componentClass := testTargetComp.ClassName;
       testOp.parentName := testTargetSec.Name;
       testOp.AddProperty('posX', ptInteger, origCompPosX, origCompPosX + 500);

       // Apply modification directly to component
       testTargetComp.PosX := origCompPosX + 500;
       testCue.AddOperation(testOp);

       if (testCue.UndoOperations.Count <> 1) or (testCue.RedoOperations.Count <> 0) then
       begin
         LogMsg('[TEST_FAILED] TUndoCue AddOperation state incorrect');
         Halt(1);
       end;

       // Test Undo
       testCue.Undo.Free;
       if testTargetComp.PosX <> origCompPosX then
       begin
         LogMsg(Format('[TEST_FAILED] TUndoCue Undo did not restore PosX: got %d, expected %d',
           [testTargetComp.PosX, origCompPosX]));
         Halt(1);
       end;
       if (testCue.UndoOperations.Count <> 0) or (testCue.RedoOperations.Count <> 1) then
       begin
         LogMsg('[TEST_FAILED] TUndoCue state after Undo incorrect');
         Halt(1);
       end;

       // Test Redo
       testCue.Redo.Free;
       if testTargetComp.PosX <> origCompPosX + 500 then
       begin
         LogMsg(Format('[TEST_FAILED] TUndoCue Redo did not re-apply PosX: got %d, expected %d',
           [testTargetComp.PosX, origCompPosX + 500]));
         Halt(1);
       end;
       if (testCue.UndoOperations.Count <> 1) or (testCue.RedoOperations.Count <> 0) then
       begin
         LogMsg('[TEST_FAILED] TUndoCue state after Redo incorrect');
         Halt(1);
       end;

       // Restore position via Undo
       testCue.Undo.Free;
       if testTargetComp.PosX <> origCompPosX then
       begin
         LogMsg('[TEST_FAILED] TUndoCue second Undo failed to restore PosX');
         Halt(1);
       end;

       // 3. Test otAdd and otRemove
       testSecItemCount := testTargetSec.ReportComponents.Count;

       testAddLabel := TRpLabel.Create(FReport);
       testAddLabel.Name := 'TEST_UNDO_LABEL';
       testAddLabel.Text := 'UndoTestContent';
       testAddLabel.PosX := 100;
       testAddLabel.PosY := 100;
       testAddLabel.Width := 1000;
       testAddLabel.Height := 300;
       testTargetSec.ReportComponents.Add.Component := testAddLabel;

       testOp := TChangeObjectOperation.Create(otAdd, testCue.GetGroupId);
       testOp.componentName := testAddLabel.Name;
       testOp.componentClass := 'TRPLABEL';
       testOp.parentName := testTargetSec.Name;
       testCue.AddAllComponentProperties(testAddLabel, testOp);
       testCue.AddOperation(testOp);

       if testTargetSec.ReportComponents.Count <> testSecItemCount + 1 then
       begin
         LogMsg('[TEST_FAILED] Added component not in section');
         Halt(1);
       end;

       // Undo Add -> removes component from section
       testCue.Undo.Free;
       if testTargetSec.ReportComponents.Count <> testSecItemCount then
       begin
         LogMsg('[TEST_FAILED] TUndoCue Undo otAdd did not remove component from section');
         Halt(1);
       end;

       // Redo Add -> re-creates component in section
       testCue.Redo.Free;
       if testTargetSec.ReportComponents.Count <> testSecItemCount + 1 then
       begin
         LogMsg('[TEST_FAILED] TUndoCue Redo otAdd did not re-create component in section');
         Halt(1);
       end;

       // Undo Add again to clean up
       testCue.Undo.Free;
       if testTargetSec.ReportComponents.Count <> testSecItemCount then
       begin
         LogMsg('[TEST_FAILED] TUndoCue cleanup Undo otAdd failed');
         Halt(1);
       end;

       // 4. Test JSON serialization and deserialization
       cueJson := testCue.ToJSON;
       if (Length(cueJson) = 0) or (Pos('groupId', cueJson) = 0) then
       begin
         LogMsg('[TEST_FAILED] TUndoCue ToJSON produced invalid output');
         Halt(1);
       end;

       testCue2 := TUndoCue.Create(FReport);
       try
         testCue2.FromJSON(cueJson);
         if testCue2.GroupId <> testCue.GroupId then
         begin
          LogMsg(Format('[TEST_FAILED] TUndoCue FromJSON GroupId mismatch: got %d, expected %d',
             [testCue2.GroupId, testCue.GroupId]));
           Halt(1);
         end;
         if testCue2.RedoOperations.Count <> testCue.RedoOperations.Count then
         begin
           LogMsg('[TEST_FAILED] TUndoCue FromJSON RedoOperations count mismatch');
           Halt(1);
         end;
         LogMsg('TUndoCue JSON roundtrip serialization verified');
       finally
         testCue2.Free;
       end;

       LogMsg('TUndoCue property modification, component addition/removal and serialization verified');
     finally
       testCue.Free;
     end;

     LogMsg('Subphase 5.1 verification completed successfully');

     // Subphase 5.2: TFRpCueViewLCL & Structure TabHistory integration
     LogMsg('Testing Subphase 5.2: TFRpCueViewLCL and Visual Undo Cue Panel');
     if not Assigned(FStructure.TabHistory) then
     begin
       LogMsg('[TEST_FAILED] FStructure.TabHistory is nil');
       Halt(1);
     end;
     if not Assigned(FStructure.cueview) then
     begin
       LogMsg('[TEST_FAILED] FStructure.cueview is nil');
       Halt(1);
     end;
     if not Assigned(FStructure.cueview.ListViewCue) then
     begin
       LogMsg('[TEST_FAILED] FStructure.cueview.ListViewCue is nil');
       Halt(1);
     end;
     if FStructure.cueview.ListViewCue.Columns.Count < 4 then
     begin
       LogMsg('[TEST_FAILED] FStructure.cueview.ListViewCue expected at least 4 columns');
       Halt(1);
     end;

     // Ensure report has an undo cue
     if not Assigned(FReport.UndoCue) then
       FReport.UndoCue := TUndoCue.Create(FReport);

     testCue := TUndoCue(FReport.UndoCue);
     testCue.Clear;
     FStructure.cueview.RefreshList;

     if FStructure.cueview.ListViewCue.Items.Count <> 0 then
     begin
       LogMsg('[TEST_FAILED] cueview ListViewCue not empty after Clear');
       Halt(1);
     end;
     if FStructure.cueview.BUndo.Enabled or FStructure.cueview.BRedo.Enabled then
     begin
       LogMsg('[TEST_FAILED] cueview BUndo/BRedo should be disabled when empty');
       Halt(1);
     end;

     // Add an operation on a real component
     secInt := TRpSectionInterface(FDesignerFrame.secinterfaces[0]);
     testTargetSec := TRpSection(secInt.printitem);
     testTargetComp := TRpCommonPosComponent(TRpSizePosInterface(secInt.childlist[0]).printitem);
     origCompPosX := testTargetComp.PosX;
     testOp := TChangeObjectOperation.Create(otModify, testCue.GetGroupId);
     testOp.componentName := testTargetComp.Name;
     testOp.componentClass := testTargetComp.ClassName;
     testOp.parentName := testTargetSec.Name;
     testOp.AddProperty('posX', ptInteger, origCompPosX, origCompPosX + 200);
     testTargetComp.PosX := origCompPosX + 200;
     testCue.AddOperation(testOp);

     FStructure.cueview.RefreshList;
     if FStructure.cueview.ListViewCue.Items.Count <> 1 then
     begin
       LogMsg(Format('[TEST_FAILED] cueview expected 1 item, got %d', [FStructure.cueview.ListViewCue.Items.Count]));
       Halt(1);
     end;
     if not FStructure.cueview.BUndo.Enabled then
     begin
       LogMsg('[TEST_FAILED] cueview BUndo should be enabled after AddOperation');
       Halt(1);
     end;
     if FStructure.cueview.BRedo.Enabled then
     begin
       LogMsg('[TEST_FAILED] cueview BRedo should be disabled after AddOperation');
       Halt(1);
     end;

     // Undo via cueview BUndo click
     FStructure.cueview.BUndoClick(nil);
     if FStructure.cueview.BUndo.Enabled then
     begin
       LogMsg('[TEST_FAILED] cueview BUndo should be disabled after Undo');
       Halt(1);
     end;
     if not FStructure.cueview.BRedo.Enabled then
     begin
       LogMsg('[TEST_FAILED] cueview BRedo should be enabled after Undo');
       Halt(1);
     end;

     // Redo via cueview BRedo click
     FStructure.cueview.BRedoClick(nil);
     if not FStructure.cueview.BUndo.Enabled then
     begin
       LogMsg('[TEST_FAILED] cueview BUndo should be enabled after Redo');
       Halt(1);
     end;
     if FStructure.cueview.BRedo.Enabled then
     begin
       LogMsg('[TEST_FAILED] cueview BRedo should be disabled after Redo');
       Halt(1);
     end;

     // Undo again to restore original PosX
     FStructure.cueview.BUndoClick(nil);

     // Clear the history (BClearClick asks for confirmation first: use the
     // non interactive ClearHistory it calls)
     FStructure.cueview.ClearHistory;
     if (FStructure.cueview.ListViewCue.Items.Count <> 0) or
        FStructure.cueview.BUndo.Enabled or FStructure.cueview.BRedo.Enabled or
        FStructure.cueview.BClear.Enabled then
     begin
       LogMsg('[TEST_FAILED] cueview state invalid after ClearHistory');
       Halt(1);
     end;

     // Test TFRpMainFLCL instantiation & cue integration
     testMainFLcl := TFRpMainFLCL.Create(nil);
     try
       testMainFLcl.Report := FReport;
       testMainFLcl.UpdateStatus;
       if testMainFLcl.BtnUndo.Enabled or testMainFLcl.BtnRedo.Enabled then
       begin
         LogMsg('[TEST_FAILED] TFRpMainFLCL BtnUndo/BtnRedo should be disabled with empty cue');
         Halt(1);
       end;
     finally
       testMainFLcl.Free;
     end;

     LogMsg('Subphase 5.2 verification completed successfully');

     // -----------------------------------------------------------------
     // Subphase 5.3: Action Instrumentation (Move, Resize, Add, Remove, Swap, Insp)
     // -----------------------------------------------------------------
     LogMsg('Testing Subphase 5.3: Action Instrumentation...');

     testCue := TUndoCue(FReport.UndoCue);
     testCue.Clear;
     FStructure.cueview.RefreshList;

     // 1. Test Component Creation on Canvas records otAdd
     secInt := TRpSectionInterface(FDesignerFrame.secinterfaces[0]);
     testCreatedComp := secInt.CreateNewComponent(dtLabel, 50, 50, 1500, 350);
     if not Assigned(testCreatedComp) then
     begin
       LogMsg('[TEST_FAILED] CreateNewComponent returned nil');
       Halt(1);
     end;
     if not testCue.CanUndo or (testCue.UndoOperations.Count <> 1) then
     begin
       LogMsg('[TEST_FAILED] CreateNewComponent did not record undo operation in cue');
       Halt(1);
     end;
     testLastOp := testCue.UndoOperations.Last;
     if testLastOp.operation <> otAdd then
     begin
       LogMsg('[TEST_FAILED] CreateNewComponent expected otAdd operation');
       Halt(1);
     end;
     if testLastOp.componentName <> testCreatedComp.printitem.Name then
     begin
       LogMsg('[TEST_FAILED] CreateNewComponent operation componentName mismatch');
       Halt(1);
     end;
     if FStructure.cueview.ListViewCue.Items.Count <> 1 then
     begin
       LogMsg('[TEST_FAILED] cueview ListViewCue not updated after CreateNewComponent');
       Halt(1);
     end;
     LogMsg('CreateNewComponent otAdd undo recording verified: ' + testLastOp.componentName);

     // 2. Test Component Move records otModify
     origCompPosX := TRpCommonPosComponent(testCreatedComp.printitem).PosX;
     FDesignerFrame.SelectComponent(testCreatedComp, False);
     FDesignerFrame.MoveSelectedComponents(testCreatedComp, 250, 150);
     if testCue.UndoOperations.Count <> 2 then
     begin
       LogMsg('[TEST_FAILED] MoveSelectedComponents did not record undo operation');
       Halt(1);
     end;
     testLastOp := testCue.UndoOperations.Last;
     if testLastOp.operation <> otModify then
     begin
       LogMsg('[TEST_FAILED] MoveSelectedComponents expected otModify operation');
       Halt(1);
     end;
     if TRpCommonPosComponent(testCreatedComp.printitem).PosX = origCompPosX then
     begin
       LogMsg('[TEST_FAILED] MoveSelectedComponents did not change component PosX');
       Halt(1);
     end;
     LogMsg('MoveSelectedComponents otModify undo recording verified');

     // 3. Test Object Inspector SetPropertyFull records otModify
     FObjInsp.AddCompItem(testCreatedComp, True);
     TRpPanelObjLCL(FObjInsp.FindPanelForClass(testCreatedComp)).SetPropertyFull(SrpSText, 'ModifiedByInspector');
     if testCue.UndoOperations.Count <> 3 then
     begin
       LogMsg('[TEST_FAILED] SetPropertyFull did not record undo operation');
       Halt(1);
     end;
     testLastOp := testCue.UndoOperations.Last;
     // The label text is recorded with the standard undo name 'allStrings'
     // (model property Text), not the inspector display name
     if (testLastOp.operation <> otModify) or (testLastOp.properties.Count <> 1) or
        (testLastOp.properties[0].propertyName <> 'allStrings') or
        (VarToStr(testLastOp.properties[0].newValue) <> 'ModifiedByInspector') then
     begin
       if testLastOp.properties.Count > 0 then
         LogMsg(Format('[TEST_FAILED] SetPropertyFull undo operation mismatch: expected otModify allStrings -> ModifiedByInspector, got op %d prop %s -> %s',
           [Ord(testLastOp.operation), testLastOp.properties[0].propertyName,
            VarToStr(testLastOp.properties[0].newValue)]))
       else
         LogMsg('[TEST_FAILED] SetPropertyFull undo operation has no properties');
       Halt(1);
     end;
     if TRpLabel(testCreatedComp.printitem).Text <> 'ModifiedByInspector' then
     begin
       LogMsg('[TEST_FAILED] SetPropertyFull did not change the label text');
       Halt(1);
     end;
     LogMsg('Object Inspector SetPropertyFull otModify undo recording verified');

     // 4. Test Component Deletion records otRemove
     wStr := testCreatedComp.printitem.Name;
     FDesignerFrame.SelectComponent(testCreatedComp, False);
     FDesignerFrame.DeleteSelection;
     if testCue.UndoOperations.Count <> 4 then
     begin
       LogMsg('[TEST_FAILED] DeleteSelection did not record undo operation');
       Halt(1);
     end;
     testLastOp := testCue.UndoOperations.Last;
     if testLastOp.operation <> otRemove then
     begin
       LogMsg('[TEST_FAILED] DeleteSelection expected otRemove operation');
       Halt(1);
     end;
     LogMsg('DeleteSelection otRemove undo recording verified');

     // 5. Test Undo restores deleted component
     testCue.Undo.Free;
     restoredComp := nil;
     for i := 0 to TRpSection(secInt.printitem).ReportComponents.Count - 1 do
     begin
       if TRpSection(secInt.printitem).ReportComponents[i].Component.Name = wStr then
       begin
         restoredComp := TRpCommonPosComponent(TRpSection(secInt.printitem).ReportComponents[i].Component);
         break;
       end;
     end;
     if not Assigned(restoredComp) then
     begin
       LogMsg('[TEST_FAILED] Undo did not restore deleted component to section');
       Halt(1);
     end;
     LogMsg('Undo restore component verified');

     // Recreate visual wrappers so FDesignerFrame has visual interfaces for the restored component
     FDesignerFrame.UpdateInterface(True);
     secInt := TRpSectionInterface(FDesignerFrame.secinterfaces[0]);
     testCreatedComp := nil;
     for i := 0 to secInt.childlist.Count - 1 do
     begin
       if TRpSizePosInterface(secInt.childlist[i]).printitem.Name = wStr then
       begin
         testCreatedComp := TRpSizePosInterface(secInt.childlist[i]);
         break;
       end;
     end;
     if not Assigned(testCreatedComp) then
     begin
       LogMsg('[TEST_FAILED] Visual wrapper not found for restored component');
       Halt(1);
     end;

     // 6. Test SendSelectionToBack / BringSelectionToFront records swap.
     // The restored component is the last one of the section: bringing it to
     // front is a no-op and records nothing, so it is sent to back first.
     FDesignerFrame.SelectComponent(testCreatedComp, False);
     testSecItemCount := TRpSection(secInt.printitem).ReportComponents.Count;
     if TRpSection(secInt.printitem).ReportComponents.IndexOf(restoredComp) <> testSecItemCount - 1 then
     begin
       LogMsg(Format('[TEST_FAILED] Restored component expected at last index %d, got %d',
         [testSecItemCount - 1, TRpSection(secInt.printitem).ReportComponents.IndexOf(restoredComp)]));
       Halt(1);
     end;
     cnt := testCue.UndoOperations.Count;
     FDesignerFrame.BringSelectionToFront;
     if testCue.UndoOperations.Count <> cnt then
     begin
       LogMsg('[TEST_FAILED] BringSelectionToFront on the last component must record nothing');
       Halt(1);
     end;
     FDesignerFrame.SendSelectionToBack;
     testLastOp := testCue.UndoOperations.Last;
     if (testCue.UndoOperations.Count <> cnt + 1) or (testLastOp.operation <> otSwapDown) then
     begin
       LogMsg('[TEST_FAILED] SendSelectionToBack expected one otSwapDown');
       Halt(1);
     end;
     if TRpSection(secInt.printitem).ReportComponents.IndexOf(restoredComp) <> 0 then
     begin
       LogMsg('[TEST_FAILED] SendSelectionToBack did not move the component to index 0');
       Halt(1);
     end;
     FDesignerFrame.BringSelectionToFront;
     testLastOp := testCue.UndoOperations.Last;
     if (testCue.UndoOperations.Count <> cnt + 2) or (testLastOp.operation <> otSwapUp) then
     begin
       LogMsg('[TEST_FAILED] BringSelectionToFront expected one otSwapUp');
       Halt(1);
     end;
     if TRpSection(secInt.printitem).ReportComponents.IndexOf(restoredComp) <> testSecItemCount - 1 then
     begin
       LogMsg('[TEST_FAILED] BringSelectionToFront did not move the component to the last index');
       Halt(1);
     end;
     // Undo both moves: back to the last index (bring to front undone), then
     // index 0 is undone to the last index again
     testCue.Undo.Free;
     if TRpSection(secInt.printitem).ReportComponents.IndexOf(restoredComp) <> 0 then
     begin
       LogMsg('[TEST_FAILED] Undo of BringSelectionToFront did not restore index 0');
       Halt(1);
     end;
     testCue.Undo.Free;
     if TRpSection(secInt.printitem).ReportComponents.IndexOf(restoredComp) <> testSecItemCount - 1 then
     begin
       LogMsg('[TEST_FAILED] Undo of SendSelectionToBack did not restore the last index');
       Halt(1);
     end;
     FDesignerFrame.UpdateInterface(True);
     LogMsg('BringSelectionToFront / SendSelectionToBack undo recording verified');

     // 7. Test Section Swap via MoveSection
     testSubrep := FReport.SubReports[0].SubReport;
     testColDet := testSubrep.AddDetail;
     testColDet.Name := 'TEST_DET_UNDO';
     FStructure.CreateInterface;
     testCue.Clear;
     FStructure.MoveSection(testColDet, True, False, -1);
     if testCue.UndoOperations.Count = 0 then
     begin
       LogMsg('[TEST_FAILED] MoveSection did not record undo operation');
       Halt(1);
     end;
     testLastOp := testCue.UndoOperations.Last;
     if testLastOp.operation <> otSwapUp then
     begin
       LogMsg('[TEST_FAILED] MoveSection expected otSwapUp');
       Halt(1);
     end;
     testCue.Undo.Free;
     LogMsg('MoveSection swap undo/redo recording verified');
     // Clean up added test detail section
     testSubrep.FreeSection(testColDet);
     FStructure.CreateInterface;

     LogMsg('Subphase 5.3 verification completed successfully');

     // Subphase 5.5 regression tests (uregressiontests.pas)
     RunRegressionTests(FindSampleFile('sample4.rep'));
     // Commands of the VCL designer ported after phase 7
     RunVCLParityTests(FindSampleFile('sample4.rep'));
     // Phase 8: data access configuration (udataconfigtests.pas)
     RunDataConfigTests;
     // Phase 8: page setup, printer configuration and system information
     RunPageSetupTests;
     // Phase 8: report library (ulibrarytests.pas)
     RunLibraryTests;
     // Every page of the dialogs: no control cut or covered
     RunDialogLayoutTests;
     // The icons of the components on the Lazarus palette, in 3 sizes
     RunPaletteIconTests;

     ok := True;
    LogMsg('[TEST_PASSED] LCL Designer Test OK');
  except
    on E: Exception do
    begin
      LogMsg('[TEST_FAILED] Exception (' + E.ClassName + '): ' + E.Message);
      LogMsg('[TEST_FAILED] At: ' + BackTraceStrFunc(ExceptAddr));
    end;
  end;

  if ok then
    Halt(0)
  else
    Halt(1);
end;

end.
