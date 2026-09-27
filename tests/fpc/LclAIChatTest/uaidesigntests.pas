{ Phase 7.5 tests: the AI design assistant of the LCL designer window
  (TFRpMainFLCL and its chat) against a local fake Hub (no external network).

  Covers a prompt whose streamed design is applied to the report (the model,
  the views, the modified state), the undo history that travels with the
  report XML (BINCUE: the fake Hub returns the history it received with the
  operations of its change on top, as the real one does), Ctrl+Z / Ctrl+Y of
  the change with the earlier history intact, the preprocess SQL context
  round trip, the dataset validation of a prompt, editing locked during an
  inference, Stop (inference and context refresh) and the ShowAIChat
  preference. }
unit uaidesigntests;

{$mode delphi}{$H+}
{$modeswitch nestedprocvars}

interface

// AShotsDir: screenshots of the designer are saved there when not empty
procedure RunAIDesignTests(const AShotsDir: string);

implementation

uses
  SysUtils, Classes, Types, Forms, Controls, Graphics, ExtCtrls, StdCtrls,
  ComCtrls, LCLType, IniFiles, fphttpserver, httpdefs, rpjsonfpc,
  rphttpclientfpc, rptypes, rpreport, rpsubreport, rpsection, rpprintitem,
  rplabelitem, rpdatainfo, rpdatahttp, rpauthmanager, rpbasereport,
  rpaithreadslcl, rpwebmarkdownlcl, rpfrmchatlcl, rpmdfmainlcl, rpmdundocuelcl,
  rpmdobinsintlcl, rpmdfsectionintlcl, rpxmlstream, rpgraphutilslcl,
  rpmdconsts, utestutil, ufakeserver;

const
  SLOW_MARKER = 'SLOWSTREAM';
  AI_EXPLANATION = 'Title added: **Sales report** in the page header';

type
  TCondition = function: Boolean is nested;

  { TDesignFakeHub: the Hub endpoints used by the designer window }

  TDesignFakeHub = class
  private
    FLock: TRTLCriticalSection;
    FModifiedDocument: string;
    FEchoDocument: Boolean;
    FModifyBodies: TStringList;
    FPreprocessBodies: TStringList;
    FSequence: TStringList;
    FSlowStarted: Boolean;
    function GetSlowStarted: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
      AResponse: TFPHTTPConnectionResponse);
    // The document the design requests return; AEcho: the one received
    procedure SetModifiedDocument(const ADocument: string; AEcho: Boolean);
    procedure ClearRequests;
    function ModifyCount: Integer;
    function ModifyBody(AIndex: Integer): string;
    function PreprocessCount: Integer;
    function PreprocessBody(AIndex: Integer): string;
    function Sequence: string;
    property SlowStarted: Boolean read GetSlowStarted;
  end;

  { Answers the TFRpMessageDlgVCL message boxes (RpMessageBox) from a timer,
    also inside their modal loop }

  TDialogAnswerer = class
  private
    FTimer: TTimer;
    procedure Tick(Sender: TObject);
  public
    Answer: TMessageButton;
    Answered: Integer;
    LastText: string;
    constructor Create;
    destructor Destroy; override;
    procedure Arm(AAnswer: TMessageButton);
  end;

  { TAIDesignTests }

  TAIDesignTests = class
  private
    FShotsDir: string;
    FSandbox: string;
    FHub: TFakeServer;
    FHubHandler: TDesignFakeHub;
    FAnswerer: TDialogAnswerer;
    procedure Pump(AMs: Cardinal);
    procedure WaitUntil(ACondition: TCondition; ATimeoutMs: Cardinal; const AWhat: string);
    procedure Shot(AControl: TWinControl; const AName: string);
    function NewDesigner: TFRpMainFLCL;
    procedure FreeDesigner(var AMain: TFRpMainFLCL);
    procedure SendPrompt(AMain: TFRpMainFLCL; const APrompt: string);
    procedure CheckDesignerShows(AMain: TFRpMainFLCL; const AName: string;
      AExpected: Boolean; const AContext: string);
    procedure TestDesignApplyAndUndo;
    procedure TestPreprocessSqlContext;
    procedure TestDatasetValidation;
    procedure TestInferenceLock;
    procedure TestStop;
    procedure TestShowAIChatPreference;
  public
    constructor Create(const AShotsDir: string);
    destructor Destroy; override;
    procedure Run;
  end;

{ Helpers }

function T(AId: Integer; const ADefault: string): string;
begin
  Result := TranslateStr(AId, ADefault);
end;

function ProfileJson: string;
begin
  Result := '{"userId":7,"email":"ana@example.com","userName":"Ana",' +
    '"profileImageUrl":"","accountType":1,"tierId":4,"tierName":"Pro",' +
    '"dailyMax":1000,"dailyConsumed":250,"freeInitial":100,"freeRemaining":40,' +
    '"serverDay":"2026-09-27T00:00:00Z","credits":5}';
end;

function ProgressEvent(const AChunkType, AChunk, AId: string): string;
begin
  Result := '{"actor":"AI","stage":"ReceivingResponse","chunkType":"' + AChunkType +
    '","chunk":"' + AChunk + '","id":"' + AId + '","inputTokens":120,"outputTokens":7,' +
    '"prefillPercentage":0}';
end;

// The final event of ModifyReportStream with the modified document
function ModifyResultJson(const ADocument: string): string;
var
  LRoot, LResult, LProfile: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LResult := TJSONObject.Create;
    LResult.AddPair('contextJson', '{}');
    LResult.AddPair('operationsJson', '[]');
    LResult.AddPair('modifiedReportDocument', ADocument);
    LResult.AddPair('explanation', AI_EXPLANATION);
    LResult.AddPair('errorMessage', '');
    LResult.AddPair('reportFormat', 'Xml');
    LResult.AddPair('success', TJSONBool.Create(True));
    LRoot.AddPair('result', LResult);
    LRoot.AddPair('steps', TJSONArray.Create);
    LRoot.AddPair('creditsConsumed', TJSONNumber.Create(12));
    LRoot.AddPair('debugDetails', '');
    LRoot.AddPair('errorMessage', '');
    LProfile := TJSONObject.ParseJSONValue(ProfileJson) as TJSONObject;
    LRoot.AddPair('userProfile', LProfile);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

// reportDocument of a ModifyReport request body
function RequestDocument(const ABody: string): string;
var
  LValue, LDoc: TJSONValue;
begin
  Result := '';
  LValue := TJSONObject.ParseJSONValue(ABody);
  try
    if LValue is TJSONObject then
    begin
      LDoc := TJSONObject(LValue).GetValue('reportDocument');
      if LDoc <> nil then
        Result := LDoc.Value;
    end;
  finally
    LValue.Free;
  end;
end;

function SectionOfType(AReport: TRpReport; AType: TRpSectionType): TRpSection;
var
  LSub: TRpSubReport;
  I: Integer;
begin
  Result := nil;
  LSub := AReport.SubReports[0].SubReport;
  for I := 0 to LSub.Sections.Count - 1 do
    if LSub.Sections[I].Section.SectionType = AType then
      Exit(LSub.Sections[I].Section);
end;

function FindLabel(AReport: TRpReport; const AName: string): TRpLabel;
var
  LItem: TObject;
begin
  LItem := AReport.FindReporItemByName(AName);
  if LItem is TRpLabel then
    Result := TRpLabel(LItem)
  else
    Result := nil;
end;

// A label added to ASection and recorded in the undo cue (as a paste)
function AddLabelWithUndo(AReport: TRpReport; ASection: TRpSection;
  const AName, AText: string; APosX: Integer): TRpLabel;
var
  LCue: TUndoCue;
  LOp: TChangeObjectOperation;
begin
  LCue := TUndoCue(AReport.UndoCue);
  Result := TRpLabel.Create(AReport);
  Result.Name := AName;
  Result.Text := AText;
  Result.PosX := APosX;
  Result.PosY := 60;
  Result.Width := 2600;
  Result.Height := 300;
  ASection.ReportComponents.Add.Component := Result;
  LOp := TChangeObjectOperation.Create(otAdd, LCue.GetGroupId);
  LOp.componentName := AName;
  LOp.componentClass := 'TRPLABEL';
  LOp.parentName := ASection.Name;
  LCue.AddAllComponentProperties(Result, LOp);
  LCue.AddOperation(LOp);
end;

// PosX of the label changed and recorded (as the inspector does)
procedure MoveWithUndo(AReport: TRpReport; ALabel: TRpLabel; ANewX: Integer);
var
  LCue: TUndoCue;
  LOp: TChangeObjectOperation;
  LSection: TRpSection;
  I, J: Integer;
begin
  LCue := TUndoCue(AReport.UndoCue);
  LSection := nil;
  for I := 0 to AReport.SubReports.Count - 1 do
    for J := 0 to AReport.SubReports[I].SubReport.Sections.Count - 1 do
      if AReport.SubReports[I].SubReport.Sections[J].Section.ReportComponents.IndexOf(ALabel) >= 0 then
        LSection := AReport.SubReports[I].SubReport.Sections[J].Section;
  LOp := TChangeObjectOperation.Create(otModify, LCue.GetGroupId);
  LOp.componentName := ALabel.Name;
  LOp.componentClass := 'TRPLABEL';
  if LSection <> nil then
    LOp.parentName := LSection.Name;
  LOp.AddProperty('posX', ptInteger, ALabel.PosX, ANewX);
  ALabel.PosX := ANewX;
  LCue.AddOperation(LOp);
end;

// What the design assistant returns for AXml: the same report with a title
// in the page header and MANUAL1 moved, each change recorded in the history
// that came with the document (BINCUE)
function BuildAIDocument(const AXml: string): string;
var
  LScratch: TRpReport;
  LIn, LOut: TStringStream;
  LCue: TUndoCue;
  LManual: TRpLabel;
begin
  LScratch := TRpReport.Create(nil);
  try
    LIn := TStringStream.Create(AXml);
    try
      LScratch.LoadFromStream(LIn);
    finally
      LIn.Free;
    end;
    Check(LScratch.UndoCue is TUndoCue, 'the BINCUE of the request gives the scratch report its history');
    LCue := TUndoCue(LScratch.UndoCue);
    CheckEquals(2, LCue.UndoOperations.Count, 'the history of the request (2 manual operations)');
    AddLabelWithUndo(LScratch, SectionOfType(LScratch, rpsecpheader), 'AITITLE',
      'Sales report', 2000);
    LManual := FindLabel(LScratch, 'MANUAL1');
    Check(LManual <> nil, 'MANUAL1 in the document of the request');
    MoveWithUndo(LScratch, LManual, 3000);
    LOut := TStringStream.Create('');
    try
      WriteReportXML(LScratch, LOut);
      Result := LOut.DataString;
    finally
      LOut.Free;
    end;
  finally
    LScratch.Free;
  end;
end;

{ TDesignFakeHub }

constructor TDesignFakeHub.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
  FModifyBodies := TStringList.Create;
  FPreprocessBodies := TStringList.Create;
  FSequence := TStringList.Create;
end;

destructor TDesignFakeHub.Destroy;
begin
  FSequence.Free;
  FPreprocessBodies.Free;
  FModifyBodies.Free;
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

procedure TDesignFakeHub.SetModifiedDocument(const ADocument: string; AEcho: Boolean);
begin
  EnterCriticalSection(FLock);
  try
    FModifiedDocument := ADocument;
    FEchoDocument := AEcho;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TDesignFakeHub.ClearRequests;
begin
  EnterCriticalSection(FLock);
  try
    FModifyBodies.Clear;
    FPreprocessBodies.Clear;
    FSequence.Clear;
    FSlowStarted := False;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TDesignFakeHub.ModifyCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := FModifyBodies.Count;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TDesignFakeHub.ModifyBody(AIndex: Integer): string;
begin
  EnterCriticalSection(FLock);
  try
    Result := FModifyBodies[AIndex];
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TDesignFakeHub.PreprocessCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := FPreprocessBodies.Count;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TDesignFakeHub.PreprocessBody(AIndex: Integer): string;
begin
  EnterCriticalSection(FLock);
  try
    Result := FPreprocessBodies[AIndex];
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TDesignFakeHub.Sequence: string;
begin
  EnterCriticalSection(FLock);
  try
    Result := StringReplace(Trim(FSequence.Text), LineEnding, ';', [rfReplaceAll]);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TDesignFakeHub.GetSlowStarted: Boolean;
begin
  EnterCriticalSection(FLock);
  try
    Result := FSlowStarted;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TDesignFakeHub.Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
  AResponse: TFPHTTPConnectionResponse);
var
  P, LBody, LDoc: string;
  LEcho: Boolean;
  LEvents: array of string;
  I: Integer;
begin
  P := ARequest.PathInfo;
  LBody := ARequest.Content;
  if P = '/api/userprofile/status' then
  begin
    if Pos('Bearer tok', ARequest.Authorization) = 1 then
      SendJson(AResponse, 200, '{"profile":' + ProfileJson + ',"tiers":[]}')
    else
      SendJson(AResponse, 401, '{}');
  end
  else if P = '/api/Login/email' then
    SendJson(AResponse, 200, '{"token":"tokdesign","profile":' + ProfileJson + ',"tiers":[]}')
  else if P = '/api/agent/databases' then
    SendJson(AResponse, 200, '{"databases":[],"aiEndpoints":[]}')
  else if P = '/api/Tiers' then
    SendJson(AResponse, 200, '[]')
  else if P = '/ReportDesigner/PreprocessSqlContextStream' then
  begin
    EnterCriticalSection(FLock);
    try
      FPreprocessBodies.Add(LBody);
      FSequence.Add('preprocess');
    finally
      LeaveCriticalSection(FLock);
    end;
    SetLength(LEvents, 2);
    LEvents[0] := '{"actor":"Sql","stage":"Explaining","chunk":"Explaining CLIENTS"}';
    LEvents[1] := '{"result":{"dataSources":[{"dataInfoName":"CLIENTS",' +
      '"sqlExplanation":"All the clients","errorMessage":""}]},"steps":[],' +
      '"creditsConsumed":3,"debugDetails":"","errorMessage":""}';
    SendEvents(AResponse, LEvents, 20, True, True);
  end
  else if P = '/ReportDesigner/ModifyReportStream' then
  begin
    EnterCriticalSection(FLock);
    try
      FModifyBodies.Add(LBody);
      FSequence.Add('modify');
      LDoc := FModifiedDocument;
      LEcho := FEchoDocument;
      if Pos(SLOW_MARKER, LBody) > 0 then
        FSlowStarted := True;
    finally
      LeaveCriticalSection(FLock);
    end;
    if Pos(SLOW_MARKER, LBody) > 0 then
    begin
      // 8 s of chunks: long enough for the lock and stop checks
      SetLength(LEvents, 80);
      for I := 0 to High(LEvents) do
        LEvents[I] := ProgressEvent('Partial', 'x' + IntToStr(I) + ' ', 's1');
      SendEvents(AResponse, LEvents, 100, True, True);
      Exit;
    end;
    if LEcho then
      LDoc := RequestDocument(LBody);
    SetLength(LEvents, 4);
    LEvents[0] := '{"actor":"Designer","stage":"Planning","chunk":"Planning the change"}';
    LEvents[1] := ProgressEvent('Partial', 'Adding the title', 'd1');
    LEvents[2] := ProgressEvent('End', '', 'd1');
    LEvents[3] := ModifyResultJson(LDoc);
    SendEvents(AResponse, LEvents, 20, True, True);
  end
  else
    SendText(AResponse, 404, 'text/plain', 'Unknown endpoint ' + P);
end;

{ TDialogAnswerer }

constructor TDialogAnswerer.Create;
begin
  inherited Create;
  FTimer := TTimer.Create(nil);
  FTimer.Interval := 30;
  FTimer.OnTimer := Tick;
  FTimer.Enabled := True;
  Answer := smbNo;
end;

destructor TDialogAnswerer.Destroy;
begin
  FTimer.Free;
  inherited Destroy;
end;

procedure TDialogAnswerer.Arm(AAnswer: TMessageButton);
begin
  Answer := AAnswer;
  Answered := 0;
  LastText := '';
end;

procedure TDialogAnswerer.Tick(Sender: TObject);
var
  I: Integer;
  LForm: TCustomForm;
  LDialog: TFRpMessageDlgVCL;
  LButton: TButton;
begin
  for I := 0 to Screen.CustomFormCount - 1 do
  begin
    LForm := Screen.CustomForms[I];
    if (LForm is TFRpMessageDlgVCL) and LForm.Visible and (fsModal in LForm.FormState) then
    begin
      LDialog := TFRpMessageDlgVCL(LForm);
      LastText := LDialog.LMessage.Caption;
      Inc(Answered);
      case Answer of
        smbYes: LButton := LDialog.BYes;
        smbNo: LButton := LDialog.BNo;
        smbCancel: LButton := LDialog.BCancel;
      else
        LButton := LDialog.BOk;
      end;
      Log('  answering "' + Copy(LastText, 1, 70) + '..." with ' + LButton.Caption);
      LDialog.BYesClick(LButton);
      Exit;
    end;
  end;
end;

{ TAIDesignTests }

constructor TAIDesignTests.Create(const AShotsDir: string);
begin
  inherited Create;
  FShotsDir := AShotsDir;
end;

destructor TAIDesignTests.Destroy;
begin
  inherited Destroy;
end;

procedure TAIDesignTests.Pump(AMs: Cardinal);
var
  LStart: QWord;
begin
  LStart := GetTickCount64;
  repeat
    Application.ProcessMessages;
    CheckSynchronize(0);
    Sleep(5);
  until GetTickCount64 - LStart >= AMs;
end;

procedure TAIDesignTests.WaitUntil(ACondition: TCondition; ATimeoutMs: Cardinal;
  const AWhat: string);
var
  LStart: QWord;
begin
  LStart := GetTickCount64;
  while not ACondition() do
  begin
    if GetTickCount64 - LStart > ATimeoutMs then
      Fail('timeout waiting for ' + AWhat + ' (Hub requests: ' + FHub.RequestLog + ')');
    Application.ProcessMessages;
    CheckSynchronize(0);
    Sleep(5);
  end;
  Pass(AWhat);
end;

procedure TAIDesignTests.Shot(AControl: TWinControl; const AName: string);
var
  LBitmap: TBitmap;
  LPng: TPortableNetworkGraphic;
begin
  if FShotsDir = '' then
    Exit;
  Pump(300);
  LBitmap := TBitmap.Create;
  LPng := TPortableNetworkGraphic.Create;
  try
    LBitmap.SetSize(AControl.Width, AControl.Height);
    LBitmap.Canvas.Brush.Color := clWhite;
    LBitmap.Canvas.FillRect(Rect(0, 0, LBitmap.Width, LBitmap.Height));
    AControl.PaintTo(LBitmap.Canvas, 0, 0);
    LPng.Assign(LBitmap);
    LPng.SaveToFile(IncludeTrailingPathDelimiter(FShotsDir) + AName + '.png');
    Log('  screenshot ' + AName + '.png');
  finally
    LPng.Free;
    LBitmap.Free;
  end;
end;

function TAIDesignTests.NewDesigner: TFRpMainFLCL;
begin
  Result := TFRpMainFLCL.Create(nil);
  Result.SetBounds(20, 20, 1260, 720);
  Result.Show;
  Pump(150);
end;

procedure TAIDesignTests.FreeDesigner(var AMain: TFRpMainFLCL);
begin
  // Free does not ask to save; the chat frame stops its requests
  FreeAndNil(AMain);
  Check(RpAsyncWaitIdle(10000), 'workers of the designer window finished');
end;

procedure TAIDesignTests.SendPrompt(AMain: TFRpMainFLCL; const APrompt: string);
begin
  AMain.ChatFrame.MemoPrompt.Text := APrompt;
  Check(AMain.ChatFrame.BSend.Enabled, 'Send enabled for "' + APrompt + '"');
  AMain.ChatFrame.BSendClick(nil);
end;

// The design surface shows (or not) an interface for the component AName,
// and exactly the sections of the displayed subreport
procedure TAIDesignTests.CheckDesignerShows(AMain: TFRpMainFLCL; const AName: string;
  AExpected: Boolean; const AContext: string);
var
  LSub: TRpSubReport;
  LSecInt: TRpSectionInterface;
  I, J: Integer;
  LFound: Boolean;
begin
  LSub := AMain.DesignerFrame.CurrentSubreport;
  Check(Assigned(LSub) and (AMain.Report.SubReports.IndexOf(LSub) >= 0),
    AContext + ': the design surface shows a subreport of the report');
  CheckEquals(LSub.Sections.Count, AMain.DesignerFrame.secinterfaces.Count,
    AContext + ': one section interface per section');
  LFound := False;
  for I := 0 to AMain.DesignerFrame.secinterfaces.Count - 1 do
  begin
    LSecInt := TRpSectionInterface(AMain.DesignerFrame.secinterfaces[I]);
    Check(LSecInt.printitem = LSub.Sections[I].Section,
      AContext + ': section interface ' + IntToStr(I) + ' shows its section');
    for J := 0 to LSecInt.childlist.Count - 1 do
      if SameText(TRpSizePosInterface(LSecInt.childlist[J]).printitem.Name, AName) then
        LFound := True;
  end;
  if AExpected then
    Check(LFound, AContext + ': ' + AName + ' shown on the design surface')
  else
    Check(not LFound, AContext + ': ' + AName + ' not shown on the design surface');
end;

procedure TAIDesignTests.TestDesignApplyAndUndo;
var
  LMain: TFRpMainFLCL;
  LRep: TRpReport;
  LCue: TUndoCue;
  LManual, LTitle: TRpLabel;
  LXml, LBody: string;
  LKey: Word;

  function Applied: Boolean;
  begin
    Result := LMain.DesignApplyCount > 0;
  end;

  function Idle: Boolean;
  begin
    Result := not LMain.ChatFrame.Busy;
  end;

  function ManualX: Integer;
  var
    LLabel: TRpLabel;
  begin
    LLabel := FindLabel(LRep, 'MANUAL1');
    if LLabel = nil then
      Result := -1
    else
      Result := LLabel.PosX;
  end;

begin
  Section('Design assistant: streamed design applied with its undo history');
  LMain := NewDesigner;
  try
    LRep := LMain.Report;
    LCue := TUndoCue(LRep.UndoCue);
    Check(LCue <> nil, 'the designer report has an undo cue');
    CheckContains(T(1640, 'Describe report changes here'), LMain.ChatFrame.ConversationText,
      'initial message of the design assistant');
    Check(LMain.ChatFrame.BApply.Enabled and (LMain.ChatFrame.BApply.Caption = T(1149, 'Refresh')),
      'Refresh of the design context available');
    // Earlier manual history: a label added, then moved
    LManual := AddLabelWithUndo(LRep, SectionOfType(LRep, rpsecdetail), 'MANUAL1',
      'Manual label', 500);
    MoveWithUndo(LRep, LManual, 1200);
    LMain.RefreshInterface;
    CheckEquals(2, LCue.UndoOperations.Count, 'manual history recorded');
    Check(LRep.Modified, 'report modified by the manual changes');

    LXml := LMain.SaveReportAsXml;
    CheckContains('<BINCUE', LXml, 'the report XML carries the undo history');
    FHubHandler.ClearRequests;
    FHubHandler.SetModifiedDocument(BuildAIDocument(LXml), False);
    Shot(LMain, 'design_before');

    SendPrompt(LMain, 'Add a title with the report name');
    Check(LMain.ChatFrame.Busy, 'chat busy while the assistant works');
    CheckContains('Add a title with the report name', LMain.ChatFrame.ConversationText,
      'prompt in the chat');
    WaitUntil(Applied, 20000, 'design result applied to the report');
    WaitUntil(Idle, 10000, 'chat idle after the answer');
    Pump(100);

    // The request: report XML with its history, the prompt, the context
    CheckEquals(1, FHubHandler.ModifyCount, 'one design request');
    LBody := FHubHandler.ModifyBody(0);
    CheckContains('Add a title with the report name', LBody, 'request: the prompt');
    CheckContains('BINCUE', RequestDocument(LBody), 'request: the undo history in the report XML');
    CheckContains('MANUAL1', RequestDocument(LBody), 'request: the current report');
    CheckContains('"returnModifiedDocument":true', LBody, 'request: modified document wanted');
    CheckContains('expressionContext', LBody, 'request: dataset context (existingContextJson)');
    CheckContains('runtimeDataSources', LMain.DesignChatContextJson, 'design context built');
    CheckEquals(0, FHubHandler.PreprocessCount, 'no SQL to preprocess');

    // The model: the same report object with the change of the assistant
    Check(LMain.Report = LRep, 'the report object is kept (hosted designers)');
    Check(LRep.UndoCue = LCue, 'the designer undo cue object is kept');
    LTitle := FindLabel(LRep, 'AITITLE');
    Check(LTitle <> nil, 'the title added by the assistant is in the report');
    CheckEquals('Sales report', LTitle.Text, 'title text');
    Check(SectionOfType(LRep, rpsecpheader).ReportComponents.IndexOf(LTitle) >= 0,
      'title in the page header');
    CheckEquals(3000, ManualX, 'MANUAL1 moved by the assistant');
    Check(LRep.Modified, 'report marked modified');
    Check(Pos('*', LMain.Caption) > 0, 'title bar shows the modified mark');
    Check(not LRep.BlockChanges, 'report changes unblocked after the inference');
    CheckEquals(4, LCue.UndoOperations.Count, 'history: 2 manual + 2 operations of the assistant');
    Check(not LCue.CanRedo, 'nothing to redo');
    Check(LMain.BtnUndo.Enabled, 'Undo enabled');
    CheckEquals(4, LMain.Structure.cueview.ListViewCue.Items.Count, 'history panel shows the 4 operations');
    CheckEquals(1 + LRep.SubReports[0].SubReport.Sections.Count, LMain.Structure.RView.Items.Count,
      'structure tree rebuilt');
    CheckDesignerShows(LMain, 'AITITLE', True, 'after the change');
    CheckContains('Title added', LMain.ChatFrame.ConversationText, 'explanation in the chat');
    CheckEquals(AI_EXPLANATION, LMain.ChatFrame.LastAssistantMessage, 'last assistant message');
    Shot(LMain, 'design_after');

    // Ctrl+Z / Ctrl+Y (the designer shortcut, not an edit control)
    LMain.ActiveControl := nil;
    LKey := VK_Z;
    LMain.OnKeyDown(LMain, LKey, [ssCtrl]);
    CheckEquals(0, LKey, 'Ctrl+Z handled by the designer');
    CheckEquals(1200, ManualX, 'undo: the move of the assistant reverted');
    Check(FindLabel(LRep, 'AITITLE') <> nil, 'undo is step by step: the title stays');
    LMain.DoUndo;
    Check(FindLabel(LRep, 'AITITLE') = nil, 'undo: the title of the assistant removed');
    CheckDesignerShows(LMain, 'AITITLE', False, 'after undo');
    LKey := VK_Y;
    LMain.OnKeyDown(LMain, LKey, [ssCtrl]);
    CheckEquals(0, LKey, 'Ctrl+Y handled by the designer');
    Check(FindLabel(LRep, 'AITITLE') <> nil, 'redo: the title is back');
    CheckDesignerShows(LMain, 'AITITLE', True, 'after redo');
    LMain.DoRedo;
    CheckEquals(3000, ManualX, 'redo: the move is back');
    Check(not LCue.CanRedo, 'all redone');

    // The earlier manual history still works
    LMain.DoUndo;
    LMain.DoUndo;
    LMain.DoUndo;
    CheckEquals(500, ManualX, 'manual move undone');
    LMain.DoUndo;
    Check(FindLabel(LRep, 'MANUAL1') = nil, 'manual label undone');
    Check(not LCue.CanUndo, 'whole history undone');
    Check(not LRep.Modified, 'back to the state of the new report: not modified');
    CheckDesignerShows(LMain, 'MANUAL1', False, 'after undoing everything');
    LMain.DoRedo;
    LMain.DoRedo;
    LMain.DoRedo;
    LMain.DoRedo;
    Check((FindLabel(LRep, 'AITITLE') <> nil) and (ManualX = 3000), 'everything redone');
    Check(LRep.Modified, 'modified again');
  finally
    FreeDesigner(LMain);
  end;
end;

procedure TAIDesignTests.TestPreprocessSqlContext;
var
  LMain: TFRpMainFLCL;
  LRep: TRpReport;
  LItem: TRpDataInfoItem;

  function Applied1: Boolean;
  begin
    Result := LMain.DesignApplyCount >= 1;
  end;

  function Applied2: Boolean;
  begin
    Result := LMain.DesignApplyCount >= 2;
  end;

begin
  Section('Design assistant: preprocess SQL context round trip');
  LMain := NewDesigner;
  try
    LRep := LMain.Report;
    LItem := LRep.DataInfo.Add('CLIENTS');
    LItem.Name := 'CLIENTS';
    LItem.DatabaseAlias := 'NODB';
    LItem.SQL := 'SELECT * FROM CLIENTS';
    // Not opened by the context refresh (no connection in the tests)
    LItem.OpenOnStart := False;
    Check(not LRep.Modified, 'dataset added without history: not modified yet');
    FHubHandler.ClearRequests;
    // The Hub returns the document it received (no operations of its own)
    FHubHandler.SetModifiedDocument('', True);
    SendPrompt(LMain, 'Explain the clients');
    WaitUntil(Applied1, 20000, 'design result applied');
    CheckEquals('preprocess;modify', FHubHandler.Sequence, 'SQL preprocessed before the design request');
    CheckContains('SELECT * FROM CLIENTS', FHubHandler.PreprocessBody(0), 'preprocess request: the SQL');
    CheckContains('"dataInfoName":"CLIENTS"', FHubHandler.PreprocessBody(0), 'preprocess request: the dataset');
    CheckContains('All the clients', RequestDocument(FHubHandler.ModifyBody(0)),
      'design request rebuilt with the explanation');
    CheckEquals('All the clients', LRep.DataInfo.Items[0].SQLExplanation,
      'explanation stored in the dataset (and kept by the returned document)');
    CheckContains('delphi_evaluator', LMain.DesignChatContextJson, 'dataset in the design context');
    CheckEquals(0, TUndoCue(LRep.UndoCue).UndoOperations.Count,
      'a document without operations of its change adds no history');
    Check(LRep.Modified, 'a change without its operations marks the report modified');
    // The explanation exists: the next prompt does not preprocess again
    SendPrompt(LMain, 'Explain the clients again');
    WaitUntil(Applied2, 20000, 'second design result applied');
    CheckEquals(1, FHubHandler.PreprocessCount, 'no second preprocess');
    CheckEquals(2, FHubHandler.ModifyCount, 'second design request');
  finally
    FreeDesigner(LMain);
  end;
end;

procedure TAIDesignTests.TestDatasetValidation;
var
  LMain: TFRpMainFLCL;
  LRep: TRpReport;
  LItem: TRpDataInfoItem;
  LCanceled: string;

  function Canceled: Boolean;
  begin
    Result := Pos(LCanceled, LMain.ChatFrame.ConversationText) > 0;
  end;

  function Applied: Boolean;
  begin
    Result := LMain.DesignApplyCount >= 1;
  end;

begin
  Section('Design assistant: datasets that do not open ask before sending');
  LMain := NewDesigner;
  try
    LRep := LMain.Report;
    LItem := LRep.DataInfo.Add('ORDERS');
    LItem.Name := 'ORDERS';
    LItem.DatabaseAlias := 'MISSINGDB';
    LItem.SQL := 'SELECT * FROM ORDERS';
    LItem.SQLExplanation := 'Orders';
    LItem.OpenOnStart := True;
    FHubHandler.ClearRequests;
    FHubHandler.SetModifiedDocument('', True);
    LCanceled := T(1647, 'Design request canceled after dataset validation.');
    FAnswerer.Arm(smbNo);
    SendPrompt(LMain, 'Use the orders');
    WaitUntil(Canceled, 20000, 'request canceled when the user says no');
    CheckEquals(1, FAnswerer.Answered, 'the dataset error was asked');
    CheckContains(T(1645, 'Opening datasets failed.'), FAnswerer.LastText, 'question text');
    CheckContains('ORDERS', FAnswerer.LastText, 'the dataset in the question');
    CheckEquals(0, FHubHandler.ModifyCount, 'nothing sent');
    CheckContains('datasource_open_failed', LMain.DesignChatContextJson,
      'the open error in the design context');
    Check(not LMain.ChatFrame.Busy, 'chat idle');
    FAnswerer.Arm(smbYes);
    SendPrompt(LMain, 'Use the orders');
    WaitUntil(Applied, 20000, 'request sent when the user says yes');
    CheckEquals(1, FAnswerer.Answered, 'asked again');
    CheckEquals(1, FHubHandler.ModifyCount, 'design request sent');
  finally
    FAnswerer.Arm(smbNo);
    FreeDesigner(LMain);
  end;
end;

procedure TAIDesignTests.TestInferenceLock;
var
  LMain: TFRpMainFLCL;
  LRep: TRpReport;
  LManual: TRpLabel;
  LRaised: Boolean;

  function Inferring: Boolean;
  begin
    Result := FHubHandler.SlowStarted and LRep.BlockChanges and
      (Pos('x2 ', LMain.ChatFrame.LogView.PlainText) > 0);
  end;

begin
  Section('Design assistant: editing locked during the inference');
  LMain := NewDesigner;
  try
    LRep := LMain.Report;
    LManual := AddLabelWithUndo(LRep, SectionOfType(LRep, rpsecdetail), 'MANUAL1',
      'Manual label', 500);
    LMain.RefreshInterface;
    FHubHandler.ClearRequests;
    SendPrompt(LMain, 'A long change ' + SLOW_MARKER);
    WaitUntil(Inferring, 20000, 'inference running (streaming)');
    Check(LRep.BlockChanges, 'report changes blocked during the inference');
    Check(LMain.ChatFrame.Busy, 'chat busy');

    // A change refused: the model is not touched and the inference goes on
    FAnswerer.Arm(smbNo);
    LRaised := False;
    try
      LManual.PosX := 4321;
    except
      on E: ERpReportChangesBlocked do
        LRaised := True;
    end;
    Check(LRaised, 'a model change raises while blocked');
    CheckEquals(1, FAnswerer.Answered, 'the user was asked');
    CheckContains(T(1651, 'An AI inference is in progress'), FAnswerer.LastText, 'question text');
    CheckEquals(500, LManual.PosX, 'label unchanged');
    Check(LRep.BlockChanges and LMain.ChatFrame.Busy, 'the inference goes on');
    FAnswerer.Arm(smbNo);
    LRaised := False;
    try
      LMain.DoUndo;
    except
      on E: ERpReportChangesBlocked do
        LRaised := True;
    end;
    Check(LRaised and (FAnswerer.Answered = 1), 'undo asks as well');
    Check(FindLabel(LRep, 'MANUAL1') <> nil, 'undo refused');

    // A change accepted: the inference is canceled and the change applied
    FAnswerer.Arm(smbYes);
    LManual.PosX := 4321;
    CheckEquals(1, FAnswerer.Answered, 'asked again');
    CheckEquals(4321, LManual.PosX, 'change applied');
    Check(not LRep.BlockChanges, 'report unblocked');
    Check(not LMain.ChatFrame.Busy, 'inference canceled');
    CheckContains(T(1536, 'Generation stopped.'), LMain.ChatFrame.ConversationText,
      'stop message in the chat');
    Check(RpAsyncWaitIdle(5000), 'the design worker ends');
    Pump(200);
    CheckEquals(0, LMain.DesignApplyCount, 'nothing applied');
  finally
    FAnswerer.Arm(smbNo);
    FreeDesigner(LMain);
  end;
end;

procedure TAIDesignTests.TestStop;
var
  LMain: TFRpMainFLCL;
  LRep: TRpReport;
  LStart: QWord;
  LChunks: Integer;

  function Streaming: Boolean;
  begin
    Result := FHubHandler.SlowStarted and LRep.BlockChanges and
      (Pos('x2 ', LMain.ChatFrame.LogView.PlainText) > 0);
  end;

  function Refreshed: Boolean;
  begin
    Result := Pos(T(1650, 'Context refreshed.'), LMain.ChatFrame.ConversationText) > 0;
  end;

begin
  Section('Design assistant: Stop (inference and context refresh)');
  LMain := NewDesigner;
  try
    LRep := LMain.Report;
    AddLabelWithUndo(LRep, SectionOfType(LRep, rpsecdetail), 'MANUAL1', 'Manual label', 500);
    LMain.RefreshInterface;
    FHubHandler.ClearRequests;
    SendPrompt(LMain, 'Stop me ' + SLOW_MARKER);
    WaitUntil(Streaming, 20000, 'slow design stream running');
    LMain.ChatFrame.BClearClick(nil);
    Check(not LMain.ChatFrame.Busy, 'Stop ends the busy state at once');
    Check(not LRep.BlockChanges, 'Stop unblocks the report');
    CheckContains(T(1536, 'Generation stopped.'), LMain.ChatFrame.ConversationText, 'stop message');
    LChunks := Length(LMain.ChatFrame.LogView.PlainText);
    LStart := GetTickCount64;
    Check(RpAsyncWaitIdle(4000), 'the design worker ends soon');
    Check(ElapsedMs(LStart) < 3500, Format('cancel is prompt (%d ms)', [ElapsedMs(LStart)]));
    Pump(200);
    CheckEquals(LChunks, Length(LMain.ChatFrame.LogView.PlainText), 'no chunk after the stop');
    CheckEquals(0, LMain.DesignApplyCount, 'nothing applied');
    CheckEquals(1, TUndoCue(LRep.UndoCue).UndoOperations.Count, 'history untouched');
    // The report can be edited again
    LMain.DoUndo;
    Check(FindLabel(LRep, 'MANUAL1') = nil, 'undo works after the stop');

    // Stop during the context refresh: its result is dropped
    Check(LMain.ChatFrame.BApply.Enabled, 'Refresh enabled');
    LMain.ChatFrame.BApplyClick(nil);
    Check(LMain.DesignContextRefreshRunning, 'context refresh running');
    Check(LMain.ChatFrame.Busy, 'chat busy while refreshing');
    LMain.ChatFrame.BClearClick(nil);
    Check(not LMain.DesignContextRefreshRunning and not LMain.ChatFrame.Busy,
      'Stop ends the refresh');
    Check(RpAsyncWaitIdle(5000), 'refresh worker ended');
    Pump(200);
    Check(not Refreshed, 'a stopped refresh reports nothing');
    // A refresh that is not stopped reports
    LMain.ChatFrame.BApplyClick(nil);
    WaitUntil(Refreshed, 10000, 'Context refreshed.');
    Check(not LMain.ChatFrame.Busy, 'chat idle after the refresh');
    CheckContains('expressionContext', LMain.DesignChatContextJson, 'context refreshed');
  finally
    FreeDesigner(LMain);
  end;
end;

procedure TAIDesignTests.TestShowAIChatPreference;
var
  LMain: TFRpMainFLCL;
  LIni: TIniFile;
  LFile: string;

  function SchemasRequested: Boolean;
  begin
    Result := Pos('/api/agent/databases', FHub.RequestLog) > 0;
  end;

begin
  Section('View > AI chat: saved in the designer preferences (ShowAIChat)');
  LFile := RpDesignerLCLConfigFile;
  DeleteFile(LFile);
  LMain := NewDesigner;
  try
    Check(LMain.ShowAIChat and LMain.AIChatPanel.Visible, 'AI panel visible by default');
    Check(LMain.AIChatMenuItem.Checked, 'menu checked');
    LMain.AIChatMenuItem.Click;
    Check(not LMain.ShowAIChat and not LMain.AIChatPanel.Visible, 'the menu hides the panel');
    Check(FileExists(LFile), 'preferences file written');
    LIni := TIniFile.Create(LFile);
    try
      Check(not LIni.ReadBool('Preferences', 'ShowAIChat', True),
        'Preferences/ShowAIChat=0 (the key of the VCL designer)');
    finally
      LIni.Free;
    end;
    // The designer works without the panel
    AddLabelWithUndo(LMain.Report, SectionOfType(LMain.Report, rpsecdetail), 'NOAI',
      'No AI', 100);
    LMain.RefreshInterface;
    LMain.DoUndo;
    Check(FindLabel(LMain.Report, 'NOAI') = nil, 'designer usable with the panel hidden');
  finally
    FreeDesigner(LMain);
  end;

  // A new window reads it: hidden, and no Hub request until it is shown
  FHub.ClearLog;
  LMain := NewDesigner;
  try
    Check(not LMain.ShowAIChat and not LMain.AIChatPanel.Visible, 'hidden in a new window');
    Pump(400);
    Check(not SchemasRequested, 'hidden panel: no schema request to the Hub');
    Shot(LMain, 'design_no_ai_panel');
    LMain.AIChatMenuItem.Click;
    Check(LMain.ShowAIChat and LMain.AIChatPanel.Visible, 'shown again');
    WaitUntil(SchemasRequested, 10000, 'online initialization when the panel is shown');
    LIni := TIniFile.Create(LFile);
    try
      Check(LIni.ReadBool('Preferences', 'ShowAIChat', False), 'Preferences/ShowAIChat=1');
    finally
      LIni.Free;
    end;
  finally
    FreeDesigner(LMain);
  end;
end;

procedure TAIDesignTests.Run;
var
  LIni: TStringList;
begin
  FSandbox := GetEnvironmentVariable('LOCALAPPDATA');
  if Pos('rpaichattest', FSandbox) = 0 then
    Fail('the tests must run in the sandbox (LOCALAPPDATA=' + FSandbox + ')');
  // Designer preferences and connections of the sandbox
  RpDesignerLCLConfigFile := IncludeTrailingPathDelimiter(FSandbox) + 'repmand_design.ini';
  LIni := TStringList.Create;
  try
    LIni.Add('[NOTHING]');
    LIni.SaveToFile(IncludeTrailingPathDelimiter(FSandbox) + 'dbxconnections_design.ini');
  finally
    LIni.Free;
  end;
  DBXConnectionsFileOverride := IncludeTrailingPathDelimiter(FSandbox) + 'dbxconnections_design.ini';
  RpWebMarkdownForceNative := True;

  FHubHandler := TDesignFakeHub.Create;
  FHub := TFakeServer.Create(FHubHandler.Handle);
  FAnswerer := TDialogAnswerer.Create;
  try
    FHub.Start;
    Log('  fake Hub (design) on ' + FHub.BaseURL);
    RpHttpSetUrlRewrite(HUB_API_URL, FHub.BaseURL);
    try
      Check(TRpAuthManager.Instance.LoginWithCode('ana@example.com', '123456'),
        'login with the email code (fake Hub)');
      Pump(50);
      TestDesignApplyAndUndo;
      TestPreprocessSqlContext;
      TestDatasetValidation;
      TestInferenceLock;
      TestStop;
      TestShowAIChatPreference;
      TRpAuthManager.Instance.Logout;
      Check(RpAsyncWaitIdle(10000), 'all workers finished');
    finally
      RpHttpSetUrlRewrite('', '');
    end;
  finally
    FAnswerer.Free;
    FHub.Free;
    FHubHandler.Free;
    RpDesignerLCLConfigFile := '';
  end;
  Pump(100);
end;

procedure RunAIDesignTests(const AShotsDir: string);
var
  LTests: TAIDesignTests;
begin
  LTests := TAIDesignTests.Create(AShotsDir);
  try
    LTests.Run;
  finally
    LTests.Free;
  end;
end;

end.
