unit umainform;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls, ComCtrls,
  rpreport, rpsubreport, rpmdfdesignlcl, rprulerlcl, rpmunits, rpprintitem,
  rpmdobinsintlcl, rpmdfsectionintlcl, rpmdobjinsplcl, rpmdconsts;

type
  TMainForm = class(TForm)
    PTop: TPanel;
    PClient: TPanel;
    StatusBar: TStatusBar;
    BtnOpen: TButton;
    BtnSample4: TButton;
    BtnBold: TButton;
    BtnHtml: TButton;
    LblSubrep: TLabel;
    CbSubreport: TComboBox;
    LblZoom: TLabel;
    BtnZoom50: TButton;
    BtnZoom75: TButton;
    BtnZoom100: TButton;
    BtnZoom150: TButton;
    ChkGrid: TCheckBox;
    CbUnits: TComboBox;
    OpenDialog: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure BtnOpenClick(Sender: TObject);
    procedure BtnSample4Click(Sender: TObject);
    procedure BtnBoldClick(Sender: TObject);
    procedure BtnHtmlClick(Sender: TObject);
    procedure CbSubreportChange(Sender: TObject);
    procedure BtnZoomClick(Sender: TObject);
    procedure ChkGridChange(Sender: TObject);
    procedure CbUnitsChange(Sender: TObject);
  private
    FReport: TRpReport;
    FDesignerFrame: TFRpDesignFrameLCL;
    FObjInsp: TFRpObjInspLCL;
    PInspPanel: TPanel;
    SplitterInsp: TSplitter;
    FCurrentFileName: string;
    FAutoTestMode: Boolean;
    procedure AppException(Sender: TObject; E: Exception);
    function FindSampleFile(const AName: string): string;
    procedure RefreshSubreportList;
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
  PInspPanel.Align := alRight;
  PInspPanel.BevelOuter := bvNone;
  PInspPanel.Parent := PClient;

  LogMsg('FormCreate: creating SplitterInsp');
  SplitterInsp := TSplitter.Create(Self);
  SplitterInsp.Align := alRight;
  SplitterInsp.Width := 5;
  SplitterInsp.Parent := PClient;

  LogMsg('FormCreate: creating FDesignerFrame');
  FDesignerFrame := TFRpDesignFrameLCL.Create(Self);
  FDesignerFrame.Align := alClient;
  FDesignerFrame.Parent := PClient;

  LogMsg('FormCreate: creating FObjInsp');
  FObjInsp := TFRpObjInspLCL.Create(Self);
  FObjInsp.Align := alClient;
  FObjInsp.Parent := PInspPanel;

  LogMsg('FormCreate: linking ObjInsp');
  FDesignerFrame.ObjInsp := FObjInsp;
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
  p := ExtractFilePath(Application.ExeName) + '..\..\..\repman\repsamples\' + AName;
  if FileExists(p) then Exit(ExpandFileName(p));

  p := ExtractFilePath(Application.ExeName) + '..\..\repsamples\' + AName;
  if FileExists(p) then Exit(ExpandFileName(p));

  p := 'repman\repsamples\' + AName;
  if FileExists(p) then Exit(ExpandFileName(p));

  p := 'C:\desarrollo\prog\toni\reportman\repman\repsamples\' + AName;
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
    LogMsg('LoadReportFile: refreshing subreport list');
    RefreshSubreportList;
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

procedure TMainForm.RefreshSubreportList;
var
  i: Integer;
begin
  CbSubreport.Items.Clear;
  if Assigned(FReport) then
  begin
    for i := 0 to FReport.SubReports.Count - 1 do
      CbSubreport.Items.Add('SubReport ' + IntToStr(i + 1));
    if CbSubreport.Items.Count > 0 then
      CbSubreport.ItemIndex := 0;
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
  end
  else
  begin
    StatusBar.Panels[0].Text := 'Reporte: Ninguno';
    StatusBar.Panels[1].Text := '-';
    StatusBar.Panels[2].Text := 'Zoom: 100%';
    StatusBar.Panels[3].Text := 'Listo';
  end;
end;

procedure TMainForm.BtnOpenClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    LoadReportFile(OpenDialog.FileName);
end;

procedure TMainForm.BtnSample4Click(Sender: TObject);
var
  p: string;
begin
  p := FindSampleFile('sample4.rep');
  if Length(p) > 0 then
    LoadReportFile(p)
  else
    ShowMessage('No se pudo encontrar sample4.rep');
end;

procedure TMainForm.BtnBoldClick(Sender: TObject);
var
  p: string;
begin
  p := FindSampleFile('bold.rep');
  if Length(p) > 0 then
    LoadReportFile(p)
  else
    ShowMessage('No se pudo encontrar bold.rep');
end;

procedure TMainForm.BtnHtmlClick(Sender: TObject);
var
  p: string;
begin
  p := FindSampleFile('htmltest.rep');
  if Length(p) > 0 then
    LoadReportFile(p)
  else
    ShowMessage('No se pudo encontrar htmltest.rep');
end;

procedure TMainForm.CbSubreportChange(Sender: TObject);
begin
  if Assigned(FReport) and (CbSubreport.ItemIndex >= 0) and
     (CbSubreport.ItemIndex < FReport.SubReports.Count) then
  begin
    FDesignerFrame.SelectSubReport(FReport.SubReports[CbSubreport.ItemIndex].SubReport);
    UpdateStatus;
  end;
end;

procedure TMainForm.BtnZoomClick(Sender: TObject);
var
  nScale: Double;
begin
  LogMsg('BtnZoomClick: started');
  nScale := TButton(Sender).Tag / 100.0;
  LogMsg('BtnZoomClick: scale=' + FloatToStr(nScale));
  if nScale > 0 then
  begin
    LogMsg('BtnZoomClick: calling FDesignerFrame.Scale := nScale');
    FDesignerFrame.Scale := nScale;
    LogMsg('BtnZoomClick: calling UpdateStatus');
    UpdateStatus;
    LogMsg('BtnZoomClick: completed');
  end;
end;

procedure TMainForm.ChkGridChange(Sender: TObject);
begin
  if Assigned(FReport) then
  begin
    FReport.GridVisible := ChkGrid.Checked;
    FDesignerFrame.UpdateInterface(False);
  end;
end;

procedure TMainForm.CbUnitsChange(Sender: TObject);
begin
  if CbUnits.ItemIndex = 0 then
  begin
    rpmunits.defaultunit := rpUnitCms;
    FDesignerFrame.TopRuler.Metrics := rCms;
  end
  else
  begin
    rpmunits.defaultunit := rpUnitInchess;
    FDesignerFrame.TopRuler.Metrics := rInchess;
  end;
  FDesignerFrame.UpdateInterface(False);
end;

procedure TMainForm.RunSelfTest(Data: PtrInt);
var
  samplePath: string;
  ok: Boolean;
  secInt: TRpSectionInterface;
  comp1, comp2: TRpSizePosInterface;
  ruler0: TRpRulerLCL;
  expectedTop: Integer;
  origX1, origY1, origX2, origY2, deltaTwipsX, deltaTwipsY: Integer;
  origWidth: Integer;
  wStr, newWStr: string;
  frames: PPointer;
  cnt, i: Integer;
begin
  LogMsg('RunSelfTest started');
  ok := False;
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
      BtnZoom50.Click;
      LogMsg('Zoom 50% clicked');
    except
      on E: Exception do
      begin
        LogMsg('Exception during BtnZoom50.Click: ' + E.ClassName + ': ' + E.Message);
        LogMsg('At: ' + BackTraceStrFunc(ExceptAddr));
        frames := ExceptFrames;
        cnt := ExceptFrameCount;
        for i := 0 to cnt - 1 do
          LogMsg('Frame ' + IntToStr(i) + ': ' + BackTraceStrFunc(frames[i]));
        raise;
      end;
    end;
    BtnZoom100.Click;
    LogMsg('Zoom 100% clicked');

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
