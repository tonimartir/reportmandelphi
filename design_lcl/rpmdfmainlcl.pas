{*******************************************************}
{                                                       }
{       Report Manager Designer - LCL                   }
{                                                       }
{       rpmdfmainlcl.pas                                }
{       Main reusable report designer form for LCL      }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpmdfmainlcl;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Variants,
  Generics.Collections,
  ExtCtrls, StdCtrls, ComCtrls, Menus, LCLType, Clipbrd,
  rpdatainfo, rpparams, rpmdshfolder,
  rpreport, rpsubreport, rpmdfdesignlcl, rprulerlcl, rpmunits,
  rpmdobinsintlcl, rpmdfsectionintlcl, rpmdobjinsplcl, rpmdconsts,
  rplabelitem, rpdrawitem, rpmdbarcode, rpmdchart, rpsection, rptypes,
  rpprintitem,
  rpmdimageslcl, rpmdfstruclcl, rpdbbrowserlcl, rpmdfdinfolcl,
  rppagesetuplcl, rplclpreview, rppreviewcontrol,
  rpmdfgridlcl, rpmdfaboutlcl,
  rpmdfselectfieldslcl, rpmdfwizardlcl, rpmdfextseclcl,
  rpmdfsearchlcl, rpmdfopenliblcl, rpmdfparamslcl, rprflclparams,
  rpmdundocuelcl, rpgraphutilslcl, rpfrmchatlcl, rpbasereport,
  rpreportdesignercontracts, rpaithreadslcl;

type
  TFRpMainFLCL = class(TForm)
  private
    // Design assistant (the chat of rpmdfmainvcl): dataset context of the
    // requests, refreshed in a worker thread
    FDesignMailbox: TRpAsyncMailbox;
    FDesignMailboxRef: IRpAsyncMailbox;
    FDesignContextRefreshVersion: Integer;
    FDesignChatContextJson: string;
    FDesignChatContextInitialized: Boolean;
    FDesignChatPendingPrompt: string;
    FDesignChatValidatedPrompt: string;
    FDesignContextRefreshRunning: Boolean;
    // Report changes blocked by this form during an inference
    FDesignInferenceDepth: Integer;
    FDesignApplyCount: Integer;
    // The report content is being replaced: the views are detached
    FReplacingReport: Boolean;
    // The online initialization of the hidden AI panel waits until it is shown
    FChatOnlinePending: Boolean;
    FReport: TRpReport;
    FFileName: string;
    FOwnsReport: Boolean;
    // Report library (designer global connections, VCL RpAlias1.Connections)
    FLibConnections: TRpDatabaseInfoList;
    FLibraryName: string;
    FLibraryReportName: WideString;
    // Hosted by TRpDesignerLCL: no file actions, the host saves the report
    FHostedMode: Boolean;
    FSaveAccepted: Boolean;

    // Visual Controls
    MainMenu1: TMainMenu;
    MainToolBar: TToolBar;
    ImageList1: TImageList;
    PLeft: TPanel;
    SplitterStruct: TSplitter;
    SplitterMain: TSplitter;
    PClient: TPanel;
    StatusBar: TStatusBar;
    // AI panel at the right (the chat tab of rpmdfmainvcl)
    PAIPanel: TPanel;
    SplitterAI: TSplitter;

    // Frames
    FDesignerFrame: TFRpDesignFrameLCL;
    FObjInsp: TFRpObjInspLCL;
    FStructure: TFRpStructureLCL;
    FChatFrame: TFRpChatFrame;

    // Menu items
    MenuFile: TMenuItem;
    MenuFileNew: TMenuItem;
    MenuFileNewWizard: TMenuItem;
    MenuFileOpen: TMenuItem;
    MenuFileOpenLib: TMenuItem;
    MenuFileSave: TMenuItem;
    MenuFileSaveAs: TMenuItem;
    MenuFilePageSetup: TMenuItem;
    MenuFilePreview: TMenuItem;
    MenuFilePrint: TMenuItem;
    MenuFileExit: TMenuItem;
    MenuEdit: TMenuItem;
    MenuEditUndo: TMenuItem;
    MenuEditRedo: TMenuItem;
    MenuEditCut: TMenuItem;
    MenuEditCopy: TMenuItem;
    MenuEditPaste: TMenuItem;
    MenuEditDelete: TMenuItem;
    MenuEditSelectAll: TMenuItem;
    MenuView: TMenuItem;
    MenuViewGrid: TMenuItem;
    MenuViewGridConfig: TMenuItem;
    MenuViewRulers: TMenuItem;
    MenuViewUnits: TMenuItem;
    MenuViewUnitsCm: TMenuItem;
    MenuViewUnitsInches: TMenuItem;
    MenuViewScale50: TMenuItem;
    MenuViewScale100: TMenuItem;
    MenuViewScale150: TMenuItem;
    MenuViewScale200: TMenuItem;
    MenuViewAIChat: TMenuItem;
    MenuReport: TMenuItem;
    MenuReportDataConfig: TMenuItem;
    MenuReportPageSetup: TMenuItem;
    MenuReportGridOptions: TMenuItem;
    MenuReportWizard: TMenuItem;
    MenuReportParams: TMenuItem;
    MenuReportUserParams: TMenuItem;
    MenuHelp: TMenuItem;
    MenuHelpAbout: TMenuItem;

    procedure BuildMenus;
    procedure BuildControls;
    procedure EnsureUndoCue;
    procedure SetReport(Value: TRpReport);
    procedure SetFileName(const Value: string);
    procedure SetHostedMode(Value: Boolean);
    procedure CueChanged(Sender: TObject);
    procedure ReportReadError(Reader: TReader; const Message: string;
      var Handled: Boolean);
    function CreateDesignReport: TRpReport;
    function LoadDesignReport(AStream: TStream): TRpReport;
    procedure DetachReport;
    // AKeepHistory: the undo history loaded with the report (BINCUE) is kept,
    // as in the VCL designer; new reports start with an empty one
    procedure InstallReport(ANewReport: TRpReport; const AFileName: string;
      AKeepHistory: Boolean);
    function GetUndoCue: TUndoCue;
    function GetLibraryConnections: TRpDatabaseInfoList;
    function SaveCurrentReport: Boolean;
    procedure SaveToLibrary;

    // Event handlers
    procedure BtnNewClick(Sender: TObject);
    procedure BtnNewWizardClick(Sender: TObject);
    procedure MenuReportWizardClick(Sender: TObject);
    procedure BtnOpenClick(Sender: TObject);
    procedure MenuFileOpenLibClick(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnSaveAsClick(Sender: TObject);
    procedure BtnDataConfigClick(Sender: TObject);
    procedure BtnParamsClick(Sender: TObject);
    procedure MenuReportUserParamsClick(Sender: TObject);
    procedure BtnPageSetupClick(Sender: TObject);
    procedure BtnPrintClick(Sender: TObject);
    procedure BtnPreviewClick(Sender: TObject);
    procedure BtnUndoClick(Sender: TObject);
    procedure BtnRedoClick(Sender: TObject);
    procedure BtnToolClick(Sender: TObject);
    procedure BtnDeleteClick(Sender: TObject);
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
    procedure BtnToFrontClick(Sender: TObject);
    procedure BtnToBackClick(Sender: TObject);
    procedure BtnSelectAllClick(Sender: TObject);
    procedure ComboScaleChange(Sender: TObject);
    procedure MenuViewGridClick(Sender: TObject);
    procedure MenuReportGridClick(Sender: TObject);
    procedure MenuViewUnitsClick(Sender: TObject);
    procedure MenuViewScaleClick(Sender: TObject);
    procedure MenuHelpAboutClick(Sender: TObject);
    procedure MenuViewAIChatClick(Sender: TObject);
    procedure ApplyChatPanelVisibility;
    function GetShowAIChat: Boolean;
    procedure SetShowAIChat(Value: Boolean);
    procedure LoadDesignerPreferences;
    procedure SaveDesignerPreferences;
    procedure ResolveInitialDesignChatSchemaContext(out AHubDatabaseId,
      AHubSchemaId: Int64; out ASchemaApiKey: string);
    procedure InitializeDesignChatSchemaSelection;
    // Design assistant, as rpmdfmainvcl
    procedure ConfigureDesignChat;
    procedure ConfigureReportChangeBlocking;
    function ReportBlockChanges(Sender: TRpBaseReport; const AReason: string): Boolean;
    procedure DesignInferenceBegin(Sender: TObject);
    procedure DesignInferenceEnd(Sender: TObject);
    function BuildDesignChatRequestForFrame(Sender: TObject;
      const APrompt: string): TRpApiModifyReportRequest;
    function BuildPreprocessSqlContextRequestForFrame(Sender: TObject):
      TRpApiPreprocessSqlContextRequest;
    procedure ApplyModifiedReportDocumentFromFrame(Sender: TObject;
      const AModifiedReportDocument: string);
    procedure ApplyPreprocessSqlContextResultFromFrame(Sender: TObject;
      AResult: TRpApiPreprocessSqlContextResult);
    procedure StopDesignChatRequest(Sender: TObject);
    procedure RefreshDesignChatContext(Sender: TObject);
    procedure ResetDesignChatContextCache;
    procedure CancelDesignChat;
    procedure BeginDesignChatContextRefresh(const APendingPrompt: string;
      ANotifyOnSuccess: Boolean);
    procedure HandleDesignAsyncMessage(AMessage: TRpAsyncMessage);
    function BuildDesignDatasetErrorMessage(AOpenErrors: TStrings;
      const AErrorMessage: string): string;
    function ConfirmDesignPromptWithDatasetErrors(
      const ADatasetErrorMessage: string): Boolean;
    procedure UpdateDesignContextProgress(AActive: Boolean; const AStatus: string);
    procedure BeginReportReplace;
    procedure EndReportReplace;
    procedure MenuFileExitClick(Sender: TObject);
    procedure DesignerToolChange(Sender: TObject);
    procedure StructureUndoRedo(Sender: TObject);
    function GetShortcutFocusedControl: TWinControl;
    function IsEditableTextShortcutTarget(AControl: TWinControl): Boolean;
    function ShouldHandleDesignerUndoShortcut: Boolean;
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  public
    // Toolbar buttons
    BtnNew: TToolButton;
    BtnNewWizard: TToolButton;
    BtnOpen: TToolButton;
    Sep1: TToolButton;
    BtnSave: TToolButton;
    BtnDataConfig: TToolButton;
    BtnParams: TToolButton;
    BtnPageSetup: TToolButton;
    Sep2: TToolButton;
    BtnPrint: TToolButton;
    BtnPreview: TToolButton;
    Sep3: TToolButton;
    BtnUndo: TToolButton;
    BtnRedo: TToolButton;
    Sep4: TToolButton;
    BtnToolArrow: TToolButton;
    BtnToolLabel: TToolButton;
    BtnToolExpr: TToolButton;
    BtnToolShape: TToolButton;
    BtnToolImage: TToolButton;
    BtnToolChart: TToolButton;
    BtnToolBarcode: TToolButton;
    Sep5: TToolButton;
    ComboScale: TComboBox;
    Sep6: TToolButton;
    BtnDelete: TToolButton;
    BtnCut: TToolButton;
    BtnCopy: TToolButton;
    BtnPaste: TToolButton;
    Sep7: TToolButton;
    BtnNudgeLeft: TToolButton;
    BtnNudgeRight: TToolButton;
    BtnNudgeUp: TToolButton;
    BtnNudgeDown: TToolButton;
    Sep8: TToolButton;
    BtnAlignLeft: TToolButton;
    BtnAlignRight: TToolButton;
    BtnAlignUp: TToolButton;
    BtnAlignDown: TToolButton;
    BtnAlignHorz: TToolButton;
    BtnAlignVert: TToolButton;
    Sep9: TToolButton;
    BtnToFront: TToolButton;
    BtnToBack: TToolButton;
    BtnSelectAll: TToolButton;

    // Dialogs
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Loads the file into a new report; the current report is replaced only
    // when the load succeeds (errors are raised, nothing is lost).
    procedure OpenReportFile(const AFileName: string);
    // Same rollback-safe load from a stream (library reports)
    procedure OpenReportStream(AStream: TStream);
    procedure OpenReportFromLibrary(const ALibrary: string; const AReportName: WideString);
    procedure SaveReportFile(const AFileName: string);
    procedure NewReport;
    procedure RefreshInterface;
    procedure UpdateStatus;
    procedure UpdateTitle;
    function CheckModified: Boolean;
    function CheckSave: Boolean;
    procedure DoUndo;
    procedure DoRedo;
    // Marks the report dirty for a change that is not recorded in the cue
    procedure MarkExternalChange;
    procedure EmbedInControl(AParent: TWinControl);
    // Design assistant (rpmdfmainvcl). The request carries the report XML
    // with the undo history (BINCUE), the chat schema and the dataset
    // context of the last refresh.
    function BuildDesignChatRequest(const APrompt: string): TRpApiModifyReportRequest;
    function BuildPreprocessSqlContextRequest: TRpApiPreprocessSqlContextRequest;
    procedure ApplyPreprocessSqlContextResult(AResult: TRpApiPreprocessSqlContextResult);
    // The report XML the assistant receives (with the undo history)
    function SaveReportAsXml: string;
    // Reloads the document returned by the assistant into the same report
    // object and refreshes the designer (rpmdfmainvcl). Its undo history
    // comes with it (BINCUE, with the operations of the change on top of the
    // previous ones): Undo reverts the change step by step. A document that
    // does not load raises and leaves the report as it was.
    procedure ApplyModifiedReportDocument(const AModifiedReportDocument: string);

    property Report: TRpReport read FReport write SetReport;
    property FileName: string read FFileName write SetFileName;
    property LibraryName: string read FLibraryName;
    property LibraryReportName: WideString read FLibraryReportName;
    property LibraryConnections: TRpDatabaseInfoList read GetLibraryConnections;
    property DesignerFrame: TFRpDesignFrameLCL read FDesignerFrame;
    property ObjInsp: TFRpObjInspLCL read FObjInsp;
    property Structure: TFRpStructureLCL read FStructure;
    // AI chat panel (account, model, schema and chat) with the design
    // assistant, as in rpmdfmainvcl
    property ChatFrame: TFRpChatFrame read FChatFrame;
    property AIChatPanel: TPanel read PAIPanel;
    // View > AI chat; saved in the designer preferences (Preferences/
    // ShowAIChat of the repmand file, as the VCL designer)
    property ShowAIChat: Boolean read GetShowAIChat write SetShowAIChat;
    property AIChatMenuItem: TMenuItem read MenuViewAIChat;
    // Dataset context sent with the design requests (JSON)
    property DesignChatContextJson: string read FDesignChatContextJson;
    property DesignContextRefreshRunning: Boolean read FDesignContextRefreshRunning;
    // Documents applied by ApplyModifiedReportDocument
    property DesignApplyCount: Integer read FDesignApplyCount;
    // Hides New/Open/Save/Save as (TRpDesignerLCL, as rpmdesignervcl does);
    // closing a modified report then asks whether the changes are accepted
    property HostedMode: Boolean read FHostedMode write SetHostedMode;
    // Hosted mode: True when the user accepted the changes on close
    property SaveAccepted: Boolean read FSaveAccepted;
  end;

var
  // Preferences file of the designer. Empty: the one of the VCL designer
  // (repmand in the user configuration folder); tests use a sandbox
  RpDesignerLCLConfigFile: string = '';

implementation

{$R *.lfm}

uses
  // rpexpredlglcl: the dataset context of the assistants (ports of the
  // rpchatdialogvcl CollectAgentSchemaOnlyContext and
  // BuildDesignExpressionContextJson)
  IniFiles, rpauthmanager, rpxmlstream, rpexpredlglcl;

const
  SDesignChatInitialMessage =
    'Describe report changes here or ask for assistance. Any change can be undone.';

type
  { Dataset context of the design requests (the payload of WM_USER + 207 in
    rpmdfmainvcl). ContextReport is the copy of the report whose datasets the
    worker opened; the payload owns it. }
  TRpDesignContextPayload = class(TRpAsyncMessage)
  public
    RequestVersion: Integer;
    ErrorMessage: string;
    OpenErrors: TStringList;
    SchemaOnlyFields: TStringList;
    SchemaOnlyErrors: TStringList;
    ContextReport: TRpReport;
    constructor Create;
    destructor Destroy; override;
  end;

  { The anonymous thread of BeginDesignChatContextRefresh: opens the datasets
    of a copy of the report (PrepareLiveContext) and reads the schema of the
    Reportman Agent datasets }
  TRpDesignContextWorker = class(TRpAsyncWorker)
  public
    RequestVersion: Integer;
    Report: TRpReport;
    // Session of the Hub, read in the main thread
    Token: string;
    InstallId: string;
    destructor Destroy; override;
  protected
    procedure Run; override;
  end;

constructor TRpDesignContextPayload.Create;
begin
  inherited Create;
  OpenErrors := TStringList.Create;
  SchemaOnlyFields := TStringList.Create;
  SchemaOnlyErrors := TStringList.Create;
end;

destructor TRpDesignContextPayload.Destroy;
begin
  ContextReport.Free;
  SchemaOnlyErrors.Free;
  SchemaOnlyFields.Free;
  OpenErrors.Free;
  inherited Destroy;
end;

// The connection of a dataset, nil when it does not exist.
// TRpDatabaseInfoList.ItemByName raises instead: the VCL code that expects
// nil from it fails with a dataset without a valid connection.
function FindDatabaseInfo(AReport: TRpReport; const AAlias: string): TRpDatabaseInfoItem;
var
  LIndex: Integer;
begin
  Result := nil;
  LIndex := AReport.DatabaseInfo.IndexOf(AAlias);
  if LIndex >= 0 then
    Result := AReport.DatabaseInfo.Items[LIndex];
end;

{ Report documents }

// A copy of the report for the dataset context: the worker opens its
// datasets, never the ones of the report being designed (binary stream as
// SaveToStream, without restoring the initial parameter values)
function CreateContextReportCopy(AReport: TRpReport): TRpReport;
var
  LStream: TMemoryStream;
  LFiles: TList;
  I: Integer;
begin
  LFiles := TList.Create;
  LStream := TMemoryStream.Create;
  try
    // Without the embedded files: the context does not need them, and under
    // FPC TRpBaseReport.WriteEmbeddedFiles/ReadEmbeddedFiles pass a TBytes
    // variable to TStream.Write/Read (it has no TBytes overload in FPC)
    for I := 0 to Length(AReport.EmbeddedFiles) - 1 do
      LFiles.Add(AReport.EmbeddedFiles[I]);
    SetLength(AReport.EmbeddedFiles, 0);
    try
      LStream.WriteComponent(AReport);
    finally
      SetLength(AReport.EmbeddedFiles, LFiles.Count);
      for I := 0 to LFiles.Count - 1 do
        AReport.EmbeddedFiles[I] := TEmbeddedFile(LFiles[I]);
    end;
    LStream.Position := 0;
    Result := TRpReport.Create(nil);
    try
      Result.FailIfLoadExternalError := False;
      Result.LoadFromStream(LStream);
    except
      Result.Free;
      raise;
    end;
  finally
    LStream.Free;
    LFiles.Free;
  end;
end;

// Raises when ADocument does not load (into a scratch report)
procedure CheckReportDocumentLoads(const ADocument: string);
var
  LScratch: TRpReport;
  LStream: TStringStream;
  I: Integer;
begin
  LScratch := TRpReport.Create(nil);
  LStream := TStringStream.Create(ADocument);
  try
    LScratch.FailIfLoadExternalError := False;
    LScratch.LoadFromStream(LStream);
  finally
    LStream.Free;
    // TRpBaseReport.Destroy does not free the embedded files
    for I := 0 to Length(LScratch.EmbeddedFiles) - 1 do
      LScratch.EmbeddedFiles[I].Free;
    SetLength(LScratch.EmbeddedFiles, 0);
    LScratch.Free;
  end;
end;

// Frees every item of the report. TRpBaseReport.Clear (what the VCL calls
// before reloading) only removes the sections and components from the
// report, which leaks them, and FreeSubreports leaves them owned by it: the
// load would then find duplicate names.
procedure ClearReportItems(AReport: TRpReport);
var
  I: Integer;
  LSubReport: TRpSubReport;
begin
  AReport.DeActivateDatasets;
  for I := 0 to AReport.SubReports.Count - 1 do
  begin
    LSubReport := AReport.SubReports.Items[I].SubReport;
    if Assigned(LSubReport) then
      LSubReport.FreeSections;
  end;
  AReport.FreeSubreports;
  AReport.DataInfo.Clear;
  AReport.DatabaseInfo.Clear;
  AReport.Params.Clear;
  // Items that were in no section are owned by the report as well; it owns
  // nothing else
  for I := AReport.ComponentCount - 1 downto 0 do
    AReport.Components[I].Free;
end;

// Loads ADocument into the same report object (the owner, the host of a
// hosted designer and the undo cue keep it), as rpmdfmainvcl
// ApplyModifiedReportDocument: the report properties that the document does
// not contain keep their values. The XML readers append embedded files: a
// document without them keeps the ones of the report.
procedure ReplaceReportContent(AReport: TRpReport; const ADocument: string);
var
  LCue: TObject;
  LStream: TStringStream;
  LOldFiles: TList;
  I: Integer;
begin
  AReport.AssertCanModify('ReplaceReportContent');
  LCue := AReport.UndoCue;
  LStream := TStringStream.Create(ADocument);
  LOldFiles := TList.Create;
  try
    ClearReportItems(AReport);
    for I := 0 to Length(AReport.EmbeddedFiles) - 1 do
      LOldFiles.Add(AReport.EmbeddedFiles[I]);
    SetLength(AReport.EmbeddedFiles, 0);
    AReport.LoadFromStream(LStream);
    if (LOldFiles.Count > 0) and (Length(AReport.EmbeddedFiles) = 0) then
    begin
      SetLength(AReport.EmbeddedFiles, LOldFiles.Count);
      for I := 0 to LOldFiles.Count - 1 do
        AReport.EmbeddedFiles[I] := TEmbeddedFile(LOldFiles[I]);
      LOldFiles.Clear;
    end;
  finally
    for I := 0 to LOldFiles.Count - 1 do
      TObject(LOldFiles[I]).Free;
    LOldFiles.Free;
    LStream.Free;
    // The BINCUE of the document was loaded into this cue object
    AReport.UndoCue := LCue;
  end;
end;

{ TRpDesignContextWorker }

destructor TRpDesignContextWorker.Destroy;
begin
  Report.Free;
  inherited Destroy;
end;

procedure TRpDesignContextWorker.Run;
var
  LPayload: TRpDesignContextPayload;
begin
  LPayload := TRpDesignContextPayload.Create;
  try
    LPayload.RequestVersion := RequestVersion;
    try
      Report.PrepareLiveContext(LPayload.OpenErrors);
      CollectAgentSchemaOnlyContext(Report, LPayload.SchemaOnlyFields,
        LPayload.SchemaOnlyErrors, Token, InstallId);
    except
      on E: Exception do
      begin
        LPayload.ErrorMessage := E.Message;
        LPayload.OpenErrors.Clear;
        LPayload.SchemaOnlyFields.Clear;
        LPayload.SchemaOnlyErrors.Clear;
      end;
    end;
    LPayload.ContextReport := Report;
    Report := nil;
    Post(LPayload);
    LPayload := nil;
  finally
    LPayload.Free;
  end;
end;

function DesignerConfigFileName: string;
begin
  Result := RpDesignerLCLConfigFile;
  if Result = '' then
    Result := Obtainininameuserconfig('', '', 'repmand');
end;

{ TFRpMainFLCL }

constructor TFRpMainFLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  // Room for the AI panel at the right (380) besides the design area
  Width := 1260;
  Height := 680;
  Caption := TranslateStr(1, 'Report Manager Designer');
  Position := poScreenCenter;
  Color := clBtnFace;
  FFileName := '';
  FOwnsReport := True;
  // Results of the dataset context worker (WM_USER + 207 of the VCL)
  FDesignMailbox := TRpAsyncMailbox.Create(HandleDesignAsyncMessage);
  FDesignMailboxRef := FDesignMailbox;

  BuildMenus;
  BuildControls;
  // View > AI chat as the user left it (VCL LoadConfig)
  LoadDesignerPreferences;
  if not MenuViewAIChat.Checked then
    ApplyChatPanelVisibility;

  KeyPreview := True;
  OnKeyDown := FormKeyDown;
  OnCloseQuery := FormCloseQuery;

  // Initialize with a blank report
  NewReport;
end;

destructor TFRpMainFLCL.Destroy;
begin
  // A context refresh still running drops its result; the chat frame
  // (destroyed with the form) stops its own request
  if Assigned(FDesignMailbox) then
    FDesignMailbox.Detach;
  FDesignMailboxRef := nil;
  FDesignMailbox := nil;
  if Assigned(FChatFrame) then
  begin
    FChatFrame.OnBuildDesignRequest := nil;
    FChatFrame.OnBuildPreprocessSqlContextRequest := nil;
    FChatFrame.OnApplyDesignResult := nil;
    FChatFrame.OnApplyPreprocessSqlContextResult := nil;
    FChatFrame.OnDesignInferenceBegin := nil;
    FChatFrame.OnDesignInferenceEnd := nil;
    FChatFrame.OnStopRequest := nil;
    FChatFrame.OnRefreshContext := nil;
  end;
  // Also unhooks the undo cue of a report owned by someone else
  DetachReport;
  FreeAndNil(FLibConnections);
  inherited Destroy;
end;

procedure TFRpMainFLCL.BuildMenus;
var
  sep: TMenuItem;
begin
  MainMenu1 := TMainMenu.Create(Self);

  // Translated with the same ids as the VCL designer (rpmdfmainvcl); the
  // top level menus get a '&' for the Alt access

  // File Menu
  MenuFile := TMenuItem.Create(MainMenu1);
  MenuFile.Caption := '&' + TranslateStr(0, 'File');
  MainMenu1.Items.Add(MenuFile);

  MenuFileNew := TMenuItem.Create(MenuFile);
  MenuFileNew.Caption := TranslateStr(40, 'New');
  MenuFileNew.ShortCut := ShortCut(VK_N, [ssCtrl]);
  MenuFileNew.OnClick := BtnNewClick;
  MenuFile.Add(MenuFileNew);

  MenuFileNewWizard := TMenuItem.Create(MenuFile);
  MenuFileNewWizard.Caption := TranslateStr(1491, 'Report wizard');
  MenuFileNewWizard.ShortCut := ShortCut(VK_N, [ssCtrl, ssShift]);
  MenuFileNewWizard.OnClick := BtnNewWizardClick;
  MenuFile.Add(MenuFileNewWizard);

  MenuFileOpen := TMenuItem.Create(MenuFile);
  MenuFileOpen.Caption := TranslateStr(42, 'Open');
  MenuFileOpen.ShortCut := ShortCut(VK_O, [ssCtrl]);
  MenuFileOpen.OnClick := BtnOpenClick;
  MenuFile.Add(MenuFileOpen);

  MenuFileOpenLib := TMenuItem.Create(MenuFile);
  MenuFileOpenLib.Caption := TranslateStr(1135, 'Open from library');
  MenuFileOpenLib.OnClick := MenuFileOpenLibClick;
  MenuFile.Add(MenuFileOpenLib);

  MenuFileSave := TMenuItem.Create(MenuFile);
  MenuFileSave.Caption := TranslateStr(46, 'Save');
  MenuFileSave.ShortCut := ShortCut(VK_S, [ssCtrl]);
  MenuFileSave.OnClick := BtnSaveClick;
  MenuFile.Add(MenuFileSave);

  MenuFileSaveAs := TMenuItem.Create(MenuFile);
  MenuFileSaveAs.Caption := TranslateStr(48, 'Save as...');
  MenuFileSaveAs.OnClick := BtnSaveAsClick;
  MenuFile.Add(MenuFileSaveAs);

  sep := TMenuItem.Create(MenuFile);
  sep.Caption := '-';
  MenuFile.Add(sep);

  MenuFilePageSetup := TMenuItem.Create(MenuFile);
  MenuFilePageSetup.Caption := TranslateStr(50, 'Page setup...');
  MenuFilePageSetup.OnClick := BtnPageSetupClick;
  MenuFile.Add(MenuFilePageSetup);

  sep := TMenuItem.Create(MenuFile);
  sep.Caption := '-';
  MenuFile.Add(sep);

  MenuFilePreview := TMenuItem.Create(MenuFile);
  MenuFilePreview.Caption := TranslateStr(54, 'Preview');
  MenuFilePreview.ShortCut := ShortCut(VK_P, [ssCtrl]);
  MenuFilePreview.OnClick := BtnPreviewClick;
  MenuFile.Add(MenuFilePreview);

  MenuFilePrint := TMenuItem.Create(MenuFile);
  MenuFilePrint.Caption := TranslateStr(52, 'Print...');
  MenuFilePrint.OnClick := BtnPrintClick;
  MenuFile.Add(MenuFilePrint);

  sep := TMenuItem.Create(MenuFile);
  sep.Caption := '-';
  MenuFile.Add(sep);

  MenuFileExit := TMenuItem.Create(MenuFile);
  MenuFileExit.Caption := TranslateStr(44, 'Exit');
  MenuFileExit.OnClick := MenuFileExitClick;
  MenuFile.Add(MenuFileExit);

  // Edit Menu
  MenuEdit := TMenuItem.Create(MainMenu1);
  MenuEdit.Caption := '&' + TranslateStr(3, 'Edit');
  MainMenu1.Items.Add(MenuEdit);

  MenuEditUndo := TMenuItem.Create(MenuEdit);
  MenuEditUndo.Caption := TranslateStr(1481, 'Undo');
  MenuEditUndo.ShortCut := ShortCut(VK_Z, [ssCtrl]);
  MenuEditUndo.OnClick := BtnUndoClick;
  MenuEdit.Add(MenuEditUndo);

  MenuEditRedo := TMenuItem.Create(MenuEdit);
  MenuEditRedo.Caption := TranslateStr(1482, 'Redo');
  MenuEditRedo.ShortCut := ShortCut(VK_Y, [ssCtrl]);
  MenuEditRedo.OnClick := BtnRedoClick;
  MenuEdit.Add(MenuEditRedo);

  sep := TMenuItem.Create(MenuEdit);
  sep.Caption := '-';
  MenuEdit.Add(sep);

  MenuEditCut := TMenuItem.Create(MenuEdit);
  MenuEditCut.Caption := TranslateStr(9, 'Cut');
  MenuEditCut.ShortCut := ShortCut(VK_X, [ssCtrl]);
  MenuEditCut.OnClick := BtnCutClick;
  MenuEdit.Add(MenuEditCut);

  MenuEditCopy := TMenuItem.Create(MenuEdit);
  MenuEditCopy.Caption := TranslateStr(10, 'Copy');
  MenuEditCopy.ShortCut := ShortCut(VK_C, [ssCtrl]);
  MenuEditCopy.OnClick := BtnCopyClick;
  MenuEdit.Add(MenuEditCopy);

  MenuEditPaste := TMenuItem.Create(MenuEdit);
  MenuEditPaste.Caption := TranslateStr(11, 'Paste');
  MenuEditPaste.ShortCut := ShortCut(VK_V, [ssCtrl]);
  MenuEditPaste.OnClick := BtnPasteClick;
  MenuEdit.Add(MenuEditPaste);

  sep := TMenuItem.Create(MenuEdit);
  sep.Caption := '-';
  MenuEdit.Add(sep);

  MenuEditDelete := TMenuItem.Create(MenuEdit);
  MenuEditDelete.Caption := TranslateStr(1142, 'Delete selection');
  MenuEditDelete.ShortCut := ShortCut(VK_DELETE, []);
  MenuEditDelete.OnClick := BtnDeleteClick;
  MenuEdit.Add(MenuEditDelete);

  MenuEditSelectAll := TMenuItem.Create(MenuEdit);
  MenuEditSelectAll.Caption := TranslateStr(1445, 'Select all');
  MenuEditSelectAll.ShortCut := ShortCut(VK_A, [ssCtrl]);
  MenuEditSelectAll.OnClick := BtnSelectAllClick;
  MenuEdit.Add(MenuEditSelectAll);

  // View Menu
  MenuView := TMenuItem.Create(MainMenu1);
  MenuView.Caption := '&' + TranslateStr(740, 'View');
  MainMenu1.Items.Add(MenuView);

  MenuViewGrid := TMenuItem.Create(MenuView);
  MenuViewGrid.Caption := TranslateStr(7, 'Grid');
  MenuViewGrid.Checked := True;
  MenuViewGrid.OnClick := MenuViewGridClick;
  MenuView.Add(MenuViewGrid);

  MenuViewGridConfig := TMenuItem.Create(MenuView);
  MenuViewGridConfig.Caption := TranslateStr(179, 'Grid Options');
  MenuViewGridConfig.OnClick := MenuReportGridClick;
  MenuView.Add(MenuViewGridConfig);

  // Measurement units: submenu, as MMeasurement in the VCL
  MenuViewUnits := TMenuItem.Create(MenuView);
  MenuViewUnits.Caption := TranslateStr(62, 'Measurement');
  MenuView.Add(MenuViewUnits);

  MenuViewUnitsCm := TMenuItem.Create(MenuViewUnits);
  MenuViewUnitsCm.Caption := TranslateStr(63, 'Cm');
  MenuViewUnitsCm.Checked := True;
  MenuViewUnitsCm.RadioItem := True;
  MenuViewUnitsCm.Tag := 0;
  MenuViewUnitsCm.OnClick := MenuViewUnitsClick;
  MenuViewUnits.Add(MenuViewUnitsCm);

  MenuViewUnitsInches := TMenuItem.Create(MenuViewUnits);
  MenuViewUnitsInches.Caption := TranslateStr(65, 'Inches');
  MenuViewUnitsInches.RadioItem := True;
  MenuViewUnitsInches.Tag := 1;
  MenuViewUnitsInches.OnClick := MenuViewUnitsClick;
  MenuViewUnits.Add(MenuViewUnitsInches);

  sep := TMenuItem.Create(MenuView);
  sep.Caption := '-';
  MenuView.Add(sep);

  // Scales: just the percentage (language independent)
  MenuViewScale50 := TMenuItem.Create(MenuView);
  MenuViewScale50.Caption := '50%';
  MenuViewScale50.Tag := 50;
  MenuViewScale50.OnClick := MenuViewScaleClick;
  MenuView.Add(MenuViewScale50);

  MenuViewScale100 := TMenuItem.Create(MenuView);
  MenuViewScale100.Caption := '100%';
  MenuViewScale100.Tag := 100;
  MenuViewScale100.OnClick := MenuViewScaleClick;
  MenuView.Add(MenuViewScale100);

  MenuViewScale150 := TMenuItem.Create(MenuView);
  MenuViewScale150.Caption := '150%';
  MenuViewScale150.Tag := 150;
  MenuViewScale150.OnClick := MenuViewScaleClick;
  MenuView.Add(MenuViewScale150);

  MenuViewScale200 := TMenuItem.Create(MenuView);
  MenuViewScale200.Caption := '200%';
  MenuViewScale200.Tag := 200;
  MenuViewScale200.OnClick := MenuViewScaleClick;
  MenuView.Add(MenuViewScale200);

  sep := TMenuItem.Create(MenuView);
  sep.Caption := '-';
  MenuView.Add(sep);

  // AChatIA of the VCL designer: shows or hides the AI panel
  MenuViewAIChat := TMenuItem.Create(MenuView);
  MenuViewAIChat.Caption := TranslateStr(1550, 'AI chat');
  MenuViewAIChat.Hint := TranslateStr(1551, 'Show or hide the AI chat panel');
  MenuViewAIChat.Checked := True;
  MenuViewAIChat.OnClick := MenuViewAIChatClick;
  MenuView.Add(MenuViewAIChat);

  // Report Menu
  MenuReport := TMenuItem.Create(MainMenu1);
  MenuReport.Caption := '&' + TranslateStr(2, 'Report');
  MainMenu1.Items.Add(MenuReport);

  MenuReportDataConfig := TMenuItem.Create(MenuReport);
  MenuReportDataConfig.Caption := TranslateStr(131, 'Data access configuration');
  MenuReportDataConfig.OnClick := BtnDataConfigClick;
  MenuReport.Add(MenuReportDataConfig);

  MenuReportPageSetup := TMenuItem.Create(MenuReport);
  MenuReportPageSetup.Caption := TranslateStr(50, 'Page setup...');
  MenuReportPageSetup.OnClick := BtnPageSetupClick;
  MenuReport.Add(MenuReportPageSetup);

  MenuReportGridOptions := TMenuItem.Create(MenuReport);
  MenuReportGridOptions.Caption := TranslateStr(179, 'Grid Options');
  MenuReportGridOptions.OnClick := MenuReportGridClick;
  MenuReport.Add(MenuReportGridOptions);

  // The wizard on the current report (adds field columns)
  MenuReportWizard := TMenuItem.Create(MenuReport);
  MenuReportWizard.Caption := TranslateStr(1491, 'Report wizard');
  MenuReportWizard.OnClick := MenuReportWizardClick;
  MenuReport.Add(MenuReportWizard);

  MenuReportParams := TMenuItem.Create(MenuReport);
  MenuReportParams.Caption := TranslateStr(133, 'Parameter definition');
  MenuReportParams.OnClick := BtnParamsClick;
  MenuReport.Add(MenuReportParams);

  MenuReportUserParams := TMenuItem.Create(MenuReport);
  MenuReportUserParams.Caption := TranslateStr(135, 'Parameter values');
  MenuReportUserParams.OnClick := MenuReportUserParamsClick;
  MenuReport.Add(MenuReportUserParams);

  // Help Menu
  MenuHelp := TMenuItem.Create(MainMenu1);
  MenuHelp.Caption := '&' + TranslateStr(6, 'Help');
  MainMenu1.Items.Add(MenuHelp);

  MenuHelpAbout := TMenuItem.Create(MenuHelp);
  MenuHelpAbout.Caption := TranslateStr(58, 'About Report Manager');
  MenuHelpAbout.OnClick := MenuHelpAboutClick;
  MenuHelp.Add(MenuHelpAbout);
end;

procedure TFRpMainFLCL.BuildControls;
begin
  // 1. ImageList (19x19 sharp premultiplied icons)
  ImageList1 := TImageList.Create(Self);
  ImageList1.Width := 19;
  ImageList1.Height := 19;
  LoadDesignerImageList(ImageList1);

  // 2. Toolbar
  MainToolBar := TToolBar.Create(Self);
  MainToolBar.Parent := Self;
  MainToolBar.Align := alTop;
  MainToolBar.Height := 32;
  MainToolBar.ButtonWidth := 26;
  MainToolBar.ButtonHeight := 26;
  MainToolBar.Flat := True;
  MainToolBar.ShowHint := True;
  MainToolBar.Images := ImageList1;

  BtnNew := TToolButton.Create(MainToolBar);
  BtnNew.Parent := MainToolBar;
  BtnNew.ImageIndex := IMG_NEW;
  BtnNew.Hint := TranslateStr(41, 'Creates a new report') + ' (Ctrl+N)';
  BtnNew.OnClick := BtnNewClick;

  BtnNewWizard := TToolButton.Create(MainToolBar);
  BtnNewWizard.Parent := MainToolBar;
  BtnNewWizard.ImageIndex := IMG_NEW;
  BtnNewWizard.Hint := TranslateStr(1491, 'Report wizard') + ' (Ctrl+Shift+N)';
  BtnNewWizard.OnClick := BtnNewWizardClick;

  BtnOpen := TToolButton.Create(MainToolBar);
  BtnOpen.Parent := MainToolBar;
  BtnOpen.ImageIndex := IMG_OPEN;
  BtnOpen.Hint := TranslateStr(43, 'Opens an existing report');
  BtnOpen.OnClick := BtnOpenClick;

  BtnSave := TToolButton.Create(MainToolBar);
  BtnSave.Parent := MainToolBar;
  BtnSave.ImageIndex := IMG_SAVE;
  BtnSave.Hint := TranslateStr(47, 'Saves the current report');
  BtnSave.OnClick := BtnSaveClick;

  BtnPageSetup := TToolButton.Create(MainToolBar);
  BtnPageSetup.Parent := MainToolBar;
  BtnPageSetup.ImageIndex := IMG_PAGESETUP;
  BtnPageSetup.Hint := TranslateStr(51, 'Configures the page for the report');
  BtnPageSetup.OnClick := BtnPageSetupClick;

  BtnDataConfig := TToolButton.Create(MainToolBar);
  BtnDataConfig.Parent := MainToolBar;
  BtnDataConfig.ImageIndex := IMG_DATACONFIG;
  BtnDataConfig.Hint := TranslateStr(132, 'Modifies data access information');
  BtnDataConfig.OnClick := BtnDataConfigClick;

  BtnParams := TToolButton.Create(MainToolBar);
  BtnParams.Parent := MainToolBar;
  BtnParams.ImageIndex := IMG_USERPARAMS;
  BtnParams.Hint := TranslateStr(134, 'Shows parameter definition for the report and data configuration');
  BtnParams.OnClick := BtnParamsClick;

  Sep1 := TToolButton.Create(MainToolBar);
  Sep1.Parent := MainToolBar;
  Sep1.Style := tbsSeparator;
  Sep1.Width := 8;

  BtnPrint := TToolButton.Create(MainToolBar);
  BtnPrint.Parent := MainToolBar;
  BtnPrint.ImageIndex := IMG_PRINT;
  BtnPrint.Hint := TranslateStr(53, 'Print the report, you can select pages to print');
  BtnPrint.OnClick := BtnPrintClick;

  BtnPreview := TToolButton.Create(MainToolBar);
  BtnPreview.Parent := MainToolBar;
  BtnPreview.ImageIndex := IMG_PREVIEW;
  BtnPreview.Hint := TranslateStr(55, 'Preview the report in the screen');
  BtnPreview.OnClick := BtnPreviewClick;

  Sep2 := TToolButton.Create(MainToolBar);
  Sep2.Parent := MainToolBar;
  Sep2.Style := tbsSeparator;
  Sep2.Width := 8;

  BtnUndo := TToolButton.Create(MainToolBar);
  BtnUndo.Parent := MainToolBar;
  BtnUndo.ImageIndex := IMG_UNDO;
  BtnUndo.Hint := TranslateStr(1481, 'Undo') + ' (Ctrl+Z)';
  BtnUndo.OnClick := BtnUndoClick;

  BtnRedo := TToolButton.Create(MainToolBar);
  BtnRedo.Parent := MainToolBar;
  BtnRedo.ImageIndex := IMG_REDO;
  BtnRedo.Hint := TranslateStr(1482, 'Redo') + ' (Ctrl+Y)';
  BtnRedo.OnClick := BtnRedoClick;

  Sep3 := TToolButton.Create(MainToolBar);
  Sep3.Parent := MainToolBar;
  Sep3.Style := tbsSeparator;
  Sep3.Width := 8;

  BtnToolArrow := TToolButton.Create(MainToolBar);
  BtnToolArrow.Parent := MainToolBar;
  BtnToolArrow.ImageIndex := IMG_ARROW;
  BtnToolArrow.Hint := TranslateStr(81, 'Select objects');
  BtnToolArrow.Grouped := True;
  BtnToolArrow.Style := tbsCheck;
  BtnToolArrow.Down := True;
  BtnToolArrow.OnClick := BtnToolClick;

  BtnToolLabel := TToolButton.Create(MainToolBar);
  BtnToolLabel.Parent := MainToolBar;
  BtnToolLabel.ImageIndex := IMG_LABEL;
  BtnToolLabel.Hint := TranslateStr(82, 'Inserts a static text');
  BtnToolLabel.Grouped := True;
  BtnToolLabel.Style := tbsCheck;
  BtnToolLabel.OnClick := BtnToolClick;

  BtnToolExpr := TToolButton.Create(MainToolBar);
  BtnToolExpr.Parent := MainToolBar;
  BtnToolExpr.ImageIndex := IMG_EXPRESSION;
  BtnToolExpr.Hint := TranslateStr(83, 'Inserts a expression');
  BtnToolExpr.Grouped := True;
  BtnToolExpr.Style := tbsCheck;
  BtnToolExpr.OnClick := BtnToolClick;

  BtnToolShape := TToolButton.Create(MainToolBar);
  BtnToolShape.Parent := MainToolBar;
  BtnToolShape.ImageIndex := IMG_SHAPE;
  BtnToolShape.Hint := TranslateStr(84, 'Inserts a simple drawing');
  BtnToolShape.Grouped := True;
  BtnToolShape.Style := tbsCheck;
  BtnToolShape.OnClick := BtnToolClick;

  BtnToolImage := TToolButton.Create(MainToolBar);
  BtnToolImage.Parent := MainToolBar;
  BtnToolImage.ImageIndex := IMG_IMAGE;
  BtnToolImage.Hint := TranslateStr(85, 'Inserts a image');
  BtnToolImage.Grouped := True;
  BtnToolImage.Style := tbsCheck;
  BtnToolImage.OnClick := BtnToolClick;

  BtnToolChart := TToolButton.Create(MainToolBar);
  BtnToolChart.Parent := MainToolBar;
  BtnToolChart.ImageIndex := IMG_CHART;
  BtnToolChart.Hint := TranslateStr(87, 'Inserts a chart');
  BtnToolChart.Grouped := True;
  BtnToolChart.Style := tbsCheck;
  BtnToolChart.OnClick := BtnToolClick;

  BtnToolBarcode := TToolButton.Create(MainToolBar);
  BtnToolBarcode.Parent := MainToolBar;
  BtnToolBarcode.ImageIndex := IMG_BARCODE;
  BtnToolBarcode.Hint := TranslateStr(86, 'Inserts a barcode');
  BtnToolBarcode.Grouped := True;
  BtnToolBarcode.Style := tbsCheck;
  BtnToolBarcode.OnClick := BtnToolClick;

  Sep4 := TToolButton.Create(MainToolBar);
  Sep4.Parent := MainToolBar;
  Sep4.Style := tbsSeparator;
  Sep4.Width := 8;

  ComboScale := TComboBox.Create(MainToolBar);
  ComboScale.Parent := MainToolBar;
  ComboScale.Style := csDropDownList;
  ComboScale.Width := 75;
  ComboScale.Items.Add('25%');
  ComboScale.Items.Add('50%');
  ComboScale.Items.Add('75%');
  ComboScale.Items.Add('100%');
  ComboScale.Items.Add('125%');
  ComboScale.Items.Add('150%');
  ComboScale.Items.Add('200%');
  ComboScale.ItemIndex := 3;
  ComboScale.OnChange := ComboScaleChange;

  Sep5 := TToolButton.Create(MainToolBar);
  Sep5.Parent := MainToolBar;
  Sep5.Style := tbsSeparator;
  Sep5.Width := 8;

  BtnDelete := TToolButton.Create(MainToolBar);
  BtnDelete.Parent := MainToolBar;
  BtnDelete.ImageIndex := IMG_DELETE;
  BtnDelete.Hint := TranslateStr(1106, 'Delete selected object');
  BtnDelete.OnClick := BtnDeleteClick;

  BtnCut := TToolButton.Create(MainToolBar);
  BtnCut.Parent := MainToolBar;
  BtnCut.ImageIndex := IMG_CUT;
  BtnCut.Hint := TranslateStr(12, 'Cut selected object');
  BtnCut.OnClick := BtnCutClick;

  BtnCopy := TToolButton.Create(MainToolBar);
  BtnCopy.Parent := MainToolBar;
  BtnCopy.ImageIndex := IMG_COPY;
  BtnCopy.Hint := TranslateStr(13, 'Copy selected object to clipboard');
  BtnCopy.OnClick := BtnCopyClick;

  BtnPaste := TToolButton.Create(MainToolBar);
  BtnPaste.Parent := MainToolBar;
  BtnPaste.ImageIndex := IMG_PASTE;
  BtnPaste.Hint := TranslateStr(14, 'Paste from clipboard');
  BtnPaste.OnClick := BtnPasteClick;

  Sep6 := TToolButton.Create(MainToolBar);
  Sep6.Parent := MainToolBar;
  Sep6.Style := tbsSeparator;
  Sep6.Width := 8;

  BtnNudgeLeft := TToolButton.Create(MainToolBar);
  BtnNudgeLeft.Parent := MainToolBar;
  BtnNudgeLeft.ImageIndex := IMG_NAV_LEFT;
  BtnNudgeLeft.Hint := TranslateStr(24, 'Moves the selection to the left');
  BtnNudgeLeft.OnClick := BtnNudgeLeftClick;

  BtnNudgeRight := TToolButton.Create(MainToolBar);
  BtnNudgeRight.Parent := MainToolBar;
  BtnNudgeRight.ImageIndex := IMG_NAV_RIGHT;
  BtnNudgeRight.Hint := TranslateStr(26, 'Moves the selection to the right');
  BtnNudgeRight.OnClick := BtnNudgeRightClick;

  BtnNudgeUp := TToolButton.Create(MainToolBar);
  BtnNudgeUp.Parent := MainToolBar;
  BtnNudgeUp.ImageIndex := IMG_NAV_UP;
  BtnNudgeUp.Hint := TranslateStr(28, 'Moves the selection up');
  BtnNudgeUp.OnClick := BtnNudgeUpClick;

  BtnNudgeDown := TToolButton.Create(MainToolBar);
  BtnNudgeDown.Parent := MainToolBar;
  BtnNudgeDown.ImageIndex := IMG_NAV_DOWN;
  BtnNudgeDown.Hint := TranslateStr(30, 'Moves the selection down');
  BtnNudgeDown.OnClick := BtnNudgeDownClick;

  Sep7 := TToolButton.Create(MainToolBar);
  Sep7.Parent := MainToolBar;
  Sep7.Style := tbsSeparator;
  Sep7.Width := 8;

  BtnAlignLeft := TToolButton.Create(MainToolBar);
  BtnAlignLeft.Parent := MainToolBar;
  BtnAlignLeft.ImageIndex := IMG_ALIGN_LEFT;
  BtnAlignLeft.Hint := TranslateStr(32, 'Aligns selection to the left');
  BtnAlignLeft.OnClick := BtnAlignLeftClick;

  BtnAlignRight := TToolButton.Create(MainToolBar);
  BtnAlignRight.Parent := MainToolBar;
  BtnAlignRight.ImageIndex := IMG_ALIGN_RIGHT;
  BtnAlignRight.Hint := TranslateStr(33, 'Aligns selection to the right');
  BtnAlignRight.OnClick := BtnAlignRightClick;

  BtnAlignUp := TToolButton.Create(MainToolBar);
  BtnAlignUp.Parent := MainToolBar;
  BtnAlignUp.ImageIndex := IMG_ALIGN_TOP;
  BtnAlignUp.Hint := TranslateStr(34, 'Aligns selection up');
  BtnAlignUp.OnClick := BtnAlignUpClick;

  BtnAlignDown := TToolButton.Create(MainToolBar);
  BtnAlignDown.Parent := MainToolBar;
  BtnAlignDown.ImageIndex := IMG_ALIGN_BOTTOM;
  BtnAlignDown.Hint := TranslateStr(35, 'Aligns selection down');
  BtnAlignDown.OnClick := BtnAlignDownClick;

  BtnAlignHorz := TToolButton.Create(MainToolBar);
  BtnAlignHorz.Parent := MainToolBar;
  BtnAlignHorz.ImageIndex := IMG_ALIGN_HCENTER;
  BtnAlignHorz.Hint := TranslateStr(39, 'Aligns selection distributing horizontal space');
  BtnAlignHorz.OnClick := BtnAlignHorzClick;

  BtnAlignVert := TToolButton.Create(MainToolBar);
  BtnAlignVert.Parent := MainToolBar;
  BtnAlignVert.ImageIndex := IMG_ALIGN_VCENTER;
  BtnAlignVert.Hint := TranslateStr(37, 'Aligns selection distributing vertical space');
  BtnAlignVert.OnClick := BtnAlignVertClick;

  Sep8 := TToolButton.Create(MainToolBar);
  Sep8.Parent := MainToolBar;
  Sep8.Style := tbsSeparator;
  Sep8.Width := 8;

  BtnToFront := TToolButton.Create(MainToolBar);
  BtnToFront.Parent := MainToolBar;
  BtnToFront.ImageIndex := IMG_NAV_UP;
  BtnToFront.Hint := TranslateStr(671, 'To Front');
  BtnToFront.OnClick := BtnToFrontClick;

  BtnToBack := TToolButton.Create(MainToolBar);
  BtnToBack.Parent := MainToolBar;
  BtnToBack.ImageIndex := IMG_NAV_DOWN;
  BtnToBack.Hint := TranslateStr(672, 'To Back');
  BtnToBack.OnClick := BtnToBackClick;

  BtnSelectAll := TToolButton.Create(MainToolBar);
  BtnSelectAll.Parent := MainToolBar;
  BtnSelectAll.ImageIndex := IMG_ALIGN_HCENTER;
  BtnSelectAll.Hint := TranslateStr(20, 'Selects all components of the report') + ' (Ctrl+A)';
  BtnSelectAll.OnClick := BtnSelectAllClick;

  // 3. StatusBar
  StatusBar := TStatusBar.Create(Self);
  StatusBar.Parent := Self;
  StatusBar.SimplePanel := True;

  // 4. Left Panel (Structure + Inspector)
  PLeft := TPanel.Create(Self);
  PLeft.Parent := Self;
  PLeft.Align := alLeft;
  PLeft.Width := 235;
  PLeft.BevelOuter := bvNone;

  FStructure := TFRpStructureLCL.Create(Self);
  FStructure.Parent := PLeft;
  FStructure.Align := alTop;
  FStructure.Height := 280;

  SplitterStruct := TSplitter.Create(PLeft);
  SplitterStruct.Parent := PLeft;
  SplitterStruct.Align := alTop;
  SplitterStruct.Height := 5;

  FObjInsp := TFRpObjInspLCL.Create(Self);
  FObjInsp.Parent := PLeft;
  FObjInsp.Align := alClient;

  // Connect structure and object inspector
  FStructure.ObjInsp := FObjInsp;

  // 5. Main Splitter
  SplitterMain := TSplitter.Create(Self);
  SplitterMain.Parent := Self;
  SplitterMain.Align := alLeft;
  SplitterMain.Width := 5;

  // 6. AI panel at the right: account card, model, schema and chat (the
  // chat tab of the VCL designer). alRight controls are ordered by Left.
  PAIPanel := TPanel.Create(Self);
  PAIPanel.Parent := Self;
  PAIPanel.BevelOuter := bvNone;
  PAIPanel.Caption := '';
  PAIPanel.SetBounds(20000, 0, Scale96ToScreen(380), 100);
  PAIPanel.Align := alRight;

  SplitterAI := TSplitter.Create(Self);
  SplitterAI.Parent := Self;
  SplitterAI.SetBounds(19000, 0, 5, 100);
  SplitterAI.Align := alRight;
  SplitterAI.ResizeAnchor := akRight;

  FChatFrame := TFRpChatFrame.Create(Self);
  FChatFrame.Parent := PAIPanel;
  FChatFrame.Align := alClient;
  ConfigureDesignChat;

  // 7. Client Area (Canvas Frame)
  PClient := TPanel.Create(Self);
  PClient.Parent := Self;
  PClient.Align := alClient;
  PClient.BevelOuter := bvNone;

  FDesignerFrame := TFRpDesignFrameLCL.Create(Self);
  FDesignerFrame.Parent := PClient;
  FDesignerFrame.Align := alClient;
  FDesignerFrame.ObjInsp := FObjInsp;
  FDesignerFrame.freportstructure := FStructure;
  FDesignerFrame.OnToolChange := DesignerToolChange;
  // Clipboard commands of the design surface context menus
  FDesignerFrame.OnCutSelection := BtnCutClick;
  FDesignerFrame.OnCopySelection := BtnCopyClick;
  FDesignerFrame.OnPasteSelection := BtnPasteClick;

  FObjInsp.DesignFrame := FDesignerFrame;
  FStructure.designframe := FDesignerFrame;
  FStructure.OnUndoRedo := StructureUndoRedo;

  // 8. Dialogs
  OpenDialog1 := TOpenDialog.Create(Self);
  OpenDialog1.Title := TranslateStr(214, 'Open report');
  OpenDialog1.Filter := TranslateStr(704, 'Report File') + ' (*.rep)|*.rep|' +
    TranslateStr(705, 'Any File') + ' (*.*)|*.*';

  SaveDialog1 := TSaveDialog.Create(Self);
  SaveDialog1.Title := TranslateStr(213, 'Save report as');
  SaveDialog1.Filter := OpenDialog1.Filter;
  SaveDialog1.DefaultExt := 'rep';
end;

procedure TFRpMainFLCL.EnsureUndoCue;
begin
  if not Assigned(FReport) then
    Exit;
  if not Assigned(FReport.UndoCue) then
    FReport.UndoCue := TUndoCue.Create(FReport);
  // Cues created elsewhere (dialogs) are hooked too
  TUndoCue(FReport.UndoCue).OnChange := CueChanged;
end;

function TFRpMainFLCL.GetUndoCue: TUndoCue;
begin
  EnsureUndoCue;
  if Assigned(FReport) then
    Result := TUndoCue(FReport.UndoCue)
  else
    Result := nil;
end;

procedure TFRpMainFLCL.CueChanged(Sender: TObject);
begin
  // Any history or dirty state change: title '*', status bar, Undo/Redo
  // buttons and the history panel
  if csDestroying in ComponentState then
    Exit;
  // The report is being reloaded (the history comes with it): refreshed at
  // the end of the replacement
  if FReplacingReport then
    Exit;
  UpdateStatus;
  if Assigned(FStructure) and Assigned(FStructure.cueview) then
    FStructure.cueview.RefreshList;
end;

procedure TFRpMainFLCL.MarkExternalChange;
var
  cue: TUndoCue;
begin
  cue := GetUndoCue;
  if Assigned(cue) then
    cue.MarkExternalChange;
end;

procedure TFRpMainFLCL.ReportReadError(Reader: TReader; const Message: string;
  var Handled: Boolean);
begin
  // Same as TFRpMainFVCL.OnReadError
  Handled := RpMessageBox(SRpErrorReadingReport + #10 + Message + #10 + SRpIgnoreError,
    SRpWarning, [smbYes, smbNo], smsWarning, smbYes) = smbYes;
end;

function TFRpMainFLCL.CreateDesignReport: TRpReport;
begin
  // Same settings as the VCL designer (rpmdfmainvcl DoOpenStream/ANewExecute)
  Result := TRpReport.Create(Self);
  Result.IsDesignTime := True;
  Result.OnReadError := ReportReadError;
  Result.FailIfLoadExternalError := False;
end;

function TFRpMainFLCL.LoadDesignReport(AStream: TStream): TRpReport;
begin
  Result := CreateDesignReport;
  try
    Result.LoadFromStream(AStream);
  except
    Result.Free;
    raise;
  end;
end;

procedure TFRpMainFLCL.DetachReport;
begin
  if Assigned(FReport) then
  begin
    if Assigned(FReport.UndoCue) and (FReport.UndoCue is TUndoCue) then
      TUndoCue(FReport.UndoCue).OnChange := nil;
    // A report of a host outlives the form: no handler of it, not blocked
    FReport.OnBlockChanges := nil;
    FReport.BlockChanges := False;
  end;
  FDesignInferenceDepth := 0;
  if Assigned(FDesignerFrame) then
    FDesignerFrame.Report := nil;
  if Assigned(FStructure) then
    FStructure.Report := nil;
  if FOwnsReport and Assigned(FReport) then
    FreeAndNil(FReport)
  else
    FReport := nil;
end;

procedure TFRpMainFLCL.InstallReport(ANewReport: TRpReport; const AFileName: string;
  AKeepHistory: Boolean);
var
  cue: TUndoCue;
begin
  // A design request of the current report must not reach the new one
  CancelDesignChat;
  // The new report is complete: only now the current one is released
  DetachReport;
  FReport := ANewReport;
  FOwnsReport := True;
  FFileName := AFileName;
  FLibraryName := '';
  FLibraryReportName := '';
  cue := GetUndoCue;
  if not AKeepHistory then
    cue.Clear;
  cue.MarkClean;
  ConfigureReportChangeBlocking;
  ResetDesignChatContextCache;
  RefreshInterface;
  // The VCL designer creates a new chat for every report
  if Assigned(FChatFrame) then
    FChatFrame.Initialize('', TranslateStr(1640, SDesignChatInitialMessage));
  InitializeDesignChatSchemaSelection;
end;

procedure TFRpMainFLCL.SetReport(Value: TRpReport);
var
  cue: TUndoCue;
begin
  if FReport = Value then Exit;
  CancelDesignChat;
  DetachReport;
  FReport := Value;
  FOwnsReport := False;
  FLibraryName := '';
  FLibraryReportName := '';
  if Assigned(FReport) then
  begin
    // The history may come with the report (BINCUE): its current state is
    // the saved one unless the host says it is modified
    cue := GetUndoCue;
    if not FReport.Modified then
      cue.MarkClean;
    ConfigureReportChangeBlocking;
    ResetDesignChatContextCache;
    RefreshInterface;
    if Assigned(FChatFrame) then
      FChatFrame.Initialize('', TranslateStr(1640, SDesignChatInitialMessage));
    InitializeDesignChatSchemaSelection;
  end
  else
    UpdateStatus;
end;

procedure TFRpMainFLCL.MenuViewAIChatClick(Sender: TObject);
begin
  // AChatIAExecute: apply and save the preference
  SetShowAIChat(not MenuViewAIChat.Checked);
end;

function TFRpMainFLCL.GetShowAIChat: Boolean;
begin
  Result := MenuViewAIChat.Checked;
end;

procedure TFRpMainFLCL.SetShowAIChat(Value: Boolean);
begin
  MenuViewAIChat.Checked := Value;
  ApplyChatPanelVisibility;
  SaveDesignerPreferences;
end;

procedure TFRpMainFLCL.LoadDesignerPreferences;
var
  inif: TIniFile;
begin
  // Preferences/ShowAIChat of the VCL designer (same file and key)
  try
    inif := TIniFile.Create(DesignerConfigFileName);
    try
      MenuViewAIChat.Checked := inif.ReadBool('Preferences', 'ShowAIChat', True);
    finally
      inif.Free;
    end;
  except
    // An unreadable preferences file keeps the defaults
  end;
end;

procedure TFRpMainFLCL.SaveDesignerPreferences;
var
  inif: TIniFile;
begin
  try
    inif := TIniFile.Create(DesignerConfigFileName);
    try
      inif.WriteBool('Preferences', 'ShowAIChat', MenuViewAIChat.Checked);
      inif.UpdateFile;
    finally
      inif.Free;
    end;
  except
    // A preference that can not be saved does not stop the designer
  end;
end;

procedure TFRpMainFLCL.ApplyChatPanelVisibility;
begin
  PAIPanel.Visible := MenuViewAIChat.Checked;
  SplitterAI.Visible := MenuViewAIChat.Checked;
  if PAIPanel.Visible then
  begin
    // The splitter must stay at the left of the panel
    SplitterAI.Left := PAIPanel.Left - SplitterAI.Width;
    FChatFrame.RefreshLayout;
    // The panel was hidden when the report was opened: no Hub requests
    // until the user shows it
    if FChatOnlinePending then
    begin
      FChatOnlinePending := False;
      FChatFrame.StartOnlineInitialization;
    end;
  end;
end;

// The Hub database and schema of the report for the chat: the schema saved
// in the first dataset and its Reportman Agent (rpdbHttp) connection, or the
// first Agent connection (as rpmdfmainvcl)
procedure TFRpMainFLCL.ResolveInitialDesignChatSchemaContext(out AHubDatabaseId,
  AHubSchemaId: Int64; out ASchemaApiKey: string);
var
  LDataInfo: TRpDataInfoItem;
  LDatabaseInfo: TRpDatabaseInfoItem;
  LConnectionParams: TStringList;
  I: Integer;
  LHasPersistedSchema: Boolean;
begin
  AHubDatabaseId := 0;
  AHubSchemaId := 0;
  ASchemaApiKey := '';
  LHasPersistedSchema := False;
  if not Assigned(FReport) then
    Exit;
  if FReport.DataInfo.Count > 0 then
  begin
    LDataInfo := FReport.DataInfo.Items[0];
    if (LDataInfo <> nil) and (LDataInfo.HubSchemaId > 0) then
    begin
      LHasPersistedSchema := True;
      AHubSchemaId := LDataInfo.HubSchemaId;
      LDatabaseInfo := FindDatabaseInfo(FReport, LDataInfo.DatabaseAlias);
      if (LDatabaseInfo <> nil) and (LDatabaseInfo.Driver = rpdbHttp) then
      begin
        LConnectionParams := TStringList.Create;
        try
          LDatabaseInfo.LoadConnectionParams(LConnectionParams);
          AHubDatabaseId := StrToInt64Def(LConnectionParams.Values['HubDatabaseId'], 0);
          ASchemaApiKey := Trim(LConnectionParams.Values['ApiKey']);
        finally
          LConnectionParams.Free;
        end;
        if AHubDatabaseId > 0 then
          Exit;
      end;
    end;
  end;
  for I := 0 to FReport.DatabaseInfo.Count - 1 do
  begin
    LDatabaseInfo := FReport.DatabaseInfo.Items[I];
    if (LDatabaseInfo <> nil) and (LDatabaseInfo.Driver = rpdbHttp) then
    begin
      LConnectionParams := TStringList.Create;
      try
        LDatabaseInfo.LoadConnectionParams(LConnectionParams);
        AHubDatabaseId := StrToInt64Def(LConnectionParams.Values['HubDatabaseId'], 0);
        ASchemaApiKey := Trim(LConnectionParams.Values['ApiKey']);
      finally
        LConnectionParams.Free;
      end;
      if AHubDatabaseId > 0 then
      begin
        // Let the chat pick the first schema only when none is saved
        if not LHasPersistedSchema then
          AHubSchemaId := 0;
        Exit;
      end;
    end;
  end;
end;

procedure TFRpMainFLCL.InitializeDesignChatSchemaSelection;
var
  LHubDatabaseId, LHubSchemaId: Int64;
  LSchemaApiKey: string;
begin
  if not Assigned(FChatFrame) then
    Exit;
  ResolveInitialDesignChatSchemaContext(LHubDatabaseId, LHubSchemaId, LSchemaApiKey);
  FChatFrame.SetHubContext(LHubDatabaseId, LHubSchemaId, LSchemaApiKey);
  // The AI panel is optional: hidden, it makes no Hub request until shown
  if PAIPanel.Visible then
    FChatFrame.StartOnlineInitialization
  else
    FChatOnlinePending := True;
end;

{ Design assistant (rpmdfmainvcl) }

procedure TFRpMainFLCL.ConfigureDesignChat;
begin
  FChatFrame.OnBuildDesignRequest := BuildDesignChatRequestForFrame;
  FChatFrame.OnBuildPreprocessSqlContextRequest := BuildPreprocessSqlContextRequestForFrame;
  FChatFrame.OnApplyDesignResult := ApplyModifiedReportDocumentFromFrame;
  FChatFrame.OnApplyPreprocessSqlContextResult := ApplyPreprocessSqlContextResultFromFrame;
  FChatFrame.OnDesignInferenceBegin := DesignInferenceBegin;
  FChatFrame.OnDesignInferenceEnd := DesignInferenceEnd;
  FChatFrame.OnStopRequest := StopDesignChatRequest;
  FChatFrame.OnRefreshContext := RefreshDesignChatContext;
  FChatFrame.SetRefreshAction(True);
end;

procedure TFRpMainFLCL.ConfigureReportChangeBlocking;
begin
  if Assigned(FReport) then
    FReport.OnBlockChanges := ReportBlockChanges;
end;

function TFRpMainFLCL.ReportBlockChanges(Sender: TRpBaseReport;
  const AReason: string): Boolean;
begin
  // A change while the assistant works: it is applied only if the user
  // cancels the inference
  Result := False;
  if RpMessageBox(TranslateStr(1651, 'An AI inference is in progress. Modifying ' +
    'the report now cancels it. Do you want to cancel it and apply the change?'),
    SRpWarning, [smbYes, smbNo], smsWarning, smbYes, smbNo) = smbYes then
  begin
    if Assigned(FChatFrame) then
      FChatFrame.AISelectionStopRequest(Self);
    Sender.BlockChanges := False;
    FDesignInferenceDepth := 0;
    Result := True;
  end;
end;

procedure TFRpMainFLCL.DesignInferenceBegin(Sender: TObject);
begin
  // Both requests of a validated prompt are built: the next prompt refreshes
  // the dataset context again (the VCL cleared it only on a stop)
  FDesignChatValidatedPrompt := '';
  if Assigned(FReport) then
  begin
    FReport.BeginBlockChanges;
    Inc(FDesignInferenceDepth);
  end;
end;

procedure TFRpMainFLCL.DesignInferenceEnd(Sender: TObject);
begin
  if Assigned(FReport) and (FDesignInferenceDepth > 0) then
  begin
    Dec(FDesignInferenceDepth);
    FReport.EndBlockChanges;
  end;
end;

procedure TFRpMainFLCL.StopDesignChatRequest(Sender: TObject);
begin
  Inc(FDesignContextRefreshVersion);
  FDesignContextRefreshRunning := False;
  FDesignChatPendingPrompt := '';
  FDesignChatValidatedPrompt := '';
  if Assigned(FReport) then
    FReport.BlockChanges := False;
  FDesignInferenceDepth := 0;
  UpdateDesignContextProgress(False, '');
end;

procedure TFRpMainFLCL.CancelDesignChat;
begin
  if not Assigned(FChatFrame) then
    Exit;
  if FChatFrame.Busy or FDesignContextRefreshRunning then
    // Stops the stream of the frame, then StopDesignChatRequest
    FChatFrame.AISelectionStopRequest(Self)
  else
    StopDesignChatRequest(Self);
end;

procedure TFRpMainFLCL.ResetDesignChatContextCache;
begin
  FDesignChatContextJson := '';
  FDesignChatContextInitialized := False;
  FDesignChatPendingPrompt := '';
  FDesignChatValidatedPrompt := '';
end;

procedure TFRpMainFLCL.UpdateDesignContextProgress(AActive: Boolean;
  const AStatus: string);
begin
  if AActive then
    StatusBar.SimpleText := AStatus
  else if not (csDestroying in ComponentState) then
    UpdateStatus;
  if Assigned(FChatFrame) then
  begin
    if AActive then
    begin
      if not FDesignContextRefreshRunning then
        FChatFrame.BeginProgress('System', AStatus)
      else
        FChatFrame.UpdateProgress(AStatus);
    end
    else
      FChatFrame.FinishProgress;
  end;
end;

function TFRpMainFLCL.SaveReportAsXml: string;
var
  LStream: TStringStream;
begin
  Result := '';
  if not Assigned(FReport) then
    Exit;
  // With the undo history (BINCUE, rpmdundocuelcl hooks), as in Delphi
  LStream := TStringStream.Create('');
  try
    WriteReportXML(FReport, LStream);
    Result := LStream.DataString;
  finally
    LStream.Free;
  end;
end;

function TFRpMainFLCL.BuildDesignChatRequest(
  const APrompt: string): TRpApiModifyReportRequest;
begin
  Result := TRpApiModifyReportRequest.Create;
  try
    Result.AITier := RpAITierTypeFromString(FChatFrame.GetAITier);
    Result.Mode := RpReportDesignerModeFromString(FChatFrame.GetAIMode);
    Result.ReportDocument := SaveReportAsXml;
    Result.ReportFormat := rdfXml;
    Result.ExistingContextJson := FDesignChatContextJson;
    Result.ReturnModifiedDocument := True;
    Result.SimplifiedPrompt := False;
    Result.UserLanguage := TRpAuthManager.Instance.AILanguage;
    Result.ApiKey := FChatFrame.GetSchemaApiKey;
    Result.Config.HubDatabaseId := FChatFrame.GetHubDatabaseId;
    Result.Config.HubSchemaId := FChatFrame.GetHubSchemaId;
    TRpAuthManager.Instance.Log(
      'Main BuildDesignChatRequest: HubDatabaseId=' + IntToStr(Result.Config.HubDatabaseId) +
      ' HubSchemaId=' + IntToStr(Result.Config.HubSchemaId) +
      ' SchemaApiKey=' + Result.ApiKey);
    Result.UserInstructions.Add(APrompt);
    if Result.AITier = ratLocalAgent then
    begin
      Result.AgentSecret := FChatFrame.GetAgentSecret;
      Result.AgentAiId := FChatFrame.GetAgentAiId;
      Result.HasAgentAiId := Result.AgentAiId <> 0;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TFRpMainFLCL.BuildPreprocessSqlContextRequest: TRpApiPreprocessSqlContextRequest;
var
  I: Integer;
  LConnectionParams: TStringList;
  LDataInfo: TRpDataInfoItem;
  LDataSource: TRpApiPreprocessSqlContextDataSource;
  LDatabaseInfo: TRpDatabaseInfoItem;
  LDataInfoName: string;
begin
  // The datasets whose SQL has no explanation yet
  Result := nil;
  if (not Assigned(FReport)) or (not Assigned(FChatFrame)) then
    Exit;
  LConnectionParams := TStringList.Create;
  try
    try
      for I := 0 to FReport.DataInfo.Count - 1 do
      begin
        LDataInfo := FReport.DataInfo.Items[I];
        if Trim(LDataInfo.SQL) = '' then
          Continue;
        if Trim(LDataInfo.SQLExplanation) <> '' then
          Continue;
        if Trim(LDataInfo.SQLExplanationError) <> '' then
          Continue;
        if Result = nil then
        begin
          Result := TRpApiPreprocessSqlContextRequest.Create;
          Result.AITier := RpAITierTypeFromString(FChatFrame.GetAITier);
          Result.Mode := RpReportDesignerModeFromString(FChatFrame.GetAIMode);
          Result.UserLanguage := TRpAuthManager.Instance.AILanguage;
          Result.ApiKey := FChatFrame.GetSchemaApiKey;
          Result.Config.HubDatabaseId := FChatFrame.GetHubDatabaseId;
          Result.Config.HubSchemaId := FChatFrame.GetHubSchemaId;
          if Result.AITier = ratLocalAgent then
          begin
            Result.AgentSecret := FChatFrame.GetAgentSecret;
            Result.AgentAiId := FChatFrame.GetAgentAiId;
            Result.HasAgentAiId := Result.AgentAiId <> 0;
          end;
        end;
        LDataSource := TRpApiPreprocessSqlContextDataSource.Create;
        LDataInfoName := Trim(LDataInfo.Name);
        if LDataInfoName = '' then
          LDataInfoName := Trim(LDataInfo.Alias);
        LDataSource.DataInfoName := LDataInfoName;
        LDataSource.DatabaseAlias := LDataInfo.DatabaseAlias;
        LDataSource.Sql := LDataInfo.SQL;
        LDatabaseInfo := FindDatabaseInfo(FReport, LDataInfo.DatabaseAlias);
        if (LDatabaseInfo <> nil) and (LDatabaseInfo.Driver = rpdbHttp) then
        begin
          LConnectionParams.Clear;
          LDatabaseInfo.LoadConnectionParams(LConnectionParams);
          LDataSource.Config.HubDatabaseId := StrToInt64Def(LConnectionParams.Values['HubDatabaseId'], 0);
          LDataSource.Config.HubSchemaId := LDataInfo.HubSchemaId;
        end;
        Result.DataSources.Add(LDataSource);
      end;
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    LConnectionParams.Free;
  end;
end;

procedure TFRpMainFLCL.ApplyPreprocessSqlContextResult(
  AResult: TRpApiPreprocessSqlContextResult);
var
  I, J: Integer;
  LDataInfo: TRpDataInfoItem;
  LDataInfoName: string;
  LResultItem: TRpApiPreprocessSqlContextDataSourceResult;
begin
  // The explanations are a cache of the report (saved with it, like the VCL
  // they do not mark it modified)
  if (not Assigned(FReport)) or (AResult = nil) then
    Exit;
  for I := 0 to AResult.DataSources.Count - 1 do
  begin
    if not (AResult.DataSources[I] is TRpApiPreprocessSqlContextDataSourceResult) then
      Continue;
    LResultItem := TRpApiPreprocessSqlContextDataSourceResult(AResult.DataSources[I]);
    for J := 0 to FReport.DataInfo.Count - 1 do
    begin
      LDataInfo := FReport.DataInfo.Items[J];
      LDataInfoName := Trim(LDataInfo.Name);
      if LDataInfoName = '' then
        LDataInfoName := Trim(LDataInfo.Alias);
      if not SameText(LDataInfoName, LResultItem.DataInfoName) then
        Continue;
      if Trim(LResultItem.SqlExplanation) <> '' then
      begin
        LDataInfo.SQLExplanation := LResultItem.SqlExplanation;
        LDataInfo.SQLExplanationError := '';
      end
      else
      begin
        LDataInfo.SQLExplanation := '';
        LDataInfo.SQLExplanationError := LResultItem.ErrorMessage;
      end;
      Break;
    end;
  end;
end;

function TFRpMainFLCL.BuildDesignChatRequestForFrame(Sender: TObject;
  const APrompt: string): TRpApiModifyReportRequest;
var
  LPrompt: string;
begin
  // A prompt is sent after refreshing the dataset context: the first call
  // starts the refresh and returns nil, the refresh sends it again
  Result := nil;
  if (not Assigned(FChatFrame)) or (not Assigned(FReport)) then
    Exit;
  LPrompt := Trim(APrompt);
  if LPrompt = '' then
    Exit;
  if SameText(FDesignChatValidatedPrompt, LPrompt) then
  begin
    Result := BuildDesignChatRequest(LPrompt);
    Exit;
  end;
  if not FDesignContextRefreshRunning then
    BeginDesignChatContextRefresh(LPrompt, False);
end;

function TFRpMainFLCL.BuildPreprocessSqlContextRequestForFrame(
  Sender: TObject): TRpApiPreprocessSqlContextRequest;
begin
  Result := BuildPreprocessSqlContextRequest;
end;

procedure TFRpMainFLCL.ApplyPreprocessSqlContextResultFromFrame(Sender: TObject;
  AResult: TRpApiPreprocessSqlContextResult);
begin
  ApplyPreprocessSqlContextResult(AResult);
end;

procedure TFRpMainFLCL.ApplyModifiedReportDocumentFromFrame(Sender: TObject;
  const AModifiedReportDocument: string);
begin
  ApplyModifiedReportDocument(AModifiedReportDocument);
end;

procedure TFRpMainFLCL.BeginReportReplace;
begin
  FReplacingReport := True;
  // The views reference items that the reload frees
  if Assigned(FDesignerFrame) then
    FDesignerFrame.Report := nil;
  if Assigned(FStructure) then
    FStructure.Report := nil;
end;

procedure TFRpMainFLCL.EndReportReplace;
begin
  FReplacingReport := False;
  RefreshInterface;
end;

procedure TFRpMainFLCL.ApplyModifiedReportDocument(
  const AModifiedReportDocument: string);
var
  cue: TUndoCue;
  baseCount, loads: Integer;
begin
  if (not Assigned(FReport)) or (Trim(AModifiedReportDocument) = '') then
    Exit;
  // The inference is over
  FReport.BlockChanges := False;
  FDesignInferenceDepth := 0;
  FDesignChatValidatedPrompt := '';
  // A document that does not load leaves the report untouched (the VCL
  // clears the report first)
  CheckReportDocumentLoads(AModifiedReportDocument);
  cue := GetUndoCue;
  baseCount := cue.UndoOperations.Count;
  loads := cue.LoadCount;
  BeginReportReplace;
  try
    ReplaceReportContent(FReport, AModifiedReportDocument);
  finally
    EndReportReplace;
  end;
  // The history travels with the document (BINCUE): the server returns the
  // one it received with the operations of its change on top, so Undo
  // reverts the change step by step and the earlier history stays
  if (cue.LoadCount <> loads) and (cue.UndoOperations.Count > baseCount) then
    cue.HistoryExtendedFrom(baseCount)
  else
    // A change without its operations can not be undone: modified until saved
    cue.MarkExternalChange;
  Inc(FDesignApplyCount);
  UpdateStatus;
end;

procedure TFRpMainFLCL.RefreshDesignChatContext(Sender: TObject);
begin
  BeginDesignChatContextRefresh('', True);
end;

procedure TFRpMainFLCL.BeginDesignChatContextRefresh(const APendingPrompt: string;
  ANotifyOnSuccess: Boolean);
var
  LWorker: TRpDesignContextWorker;
  LCopy: TRpReport;
  LStatus: string;
begin
  if (not Assigned(FChatFrame)) or (not Assigned(FReport)) then
    Exit;
  if FDesignContextRefreshRunning then
    Exit;
  // The worker opens the datasets of a copy: the designer keeps editing its
  // report meanwhile (the VCL opens them on the designed report)
  try
    LCopy := CreateContextReportCopy(FReport);
  except
    on E: Exception do
    begin
      FChatFrame.AddAssistantMessage(TranslateStr(1648, 'Context refresh failed') +
        ': ' + E.Message);
      Exit;
    end;
  end;
  FChatFrame.SetBusy(True);
  FDesignChatPendingPrompt := APendingPrompt;
  Inc(FDesignContextRefreshVersion);
  FDesignContextRefreshRunning := True;
  if Trim(APendingPrompt) <> '' then
    LStatus := TranslateStr(1641, 'Opening datasets...')
  else if ANotifyOnSuccess then
    LStatus := TranslateStr(1642, 'Refreshing design context...')
  else
    LStatus := TranslateStr(1643, 'Initializing design context...');
  UpdateDesignContextProgress(True, LStatus);
  LWorker := TRpDesignContextWorker.Create(FDesignMailboxRef);
  LWorker.RequestVersion := FDesignContextRefreshVersion;
  LWorker.Report := LCopy;
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.InstallId := TRpAuthManager.Instance.InstallId;
  LWorker.Start;
end;

function TFRpMainFLCL.BuildDesignDatasetErrorMessage(AOpenErrors: TStrings;
  const AErrorMessage: string): string;
var
  I: Integer;
  LName, LValue: string;
begin
  Result := Trim(AErrorMessage);
  if (AOpenErrors = nil) or (AOpenErrors.Count = 0) then
    Exit;
  if Result <> '' then
    Result := Result + sLineBreak + sLineBreak;
  Result := Result + TranslateStr(1644, 'Some datasets could not be opened:');
  for I := 0 to AOpenErrors.Count - 1 do
  begin
    LName := Trim(AOpenErrors.Names[I]);
    LValue := Trim(AOpenErrors.ValueFromIndex[I]);
    if LName <> '' then
      Result := Result + sLineBreak + '- ' + LName + ': ' + LValue
    else
      Result := Result + sLineBreak + '- ' + LValue;
  end;
end;

function TFRpMainFLCL.ConfirmDesignPromptWithDatasetErrors(
  const ADatasetErrorMessage: string): Boolean;
var
  LMessage: string;
begin
  LMessage := Trim(ADatasetErrorMessage);
  if LMessage = '' then
    Exit(True);
  LMessage := TranslateStr(1645, 'Opening datasets failed.') + sLineBreak + sLineBreak +
    LMessage + sLineBreak + sLineBreak +
    TranslateStr(1646, 'Do you want to send the design request to the assistant anyway?');
  Result := RpMessageBox(LMessage, SRpWarning, [smbYes, smbNo], smsWarning,
    smbYes, smbNo) = smbYes;
end;

procedure TFRpMainFLCL.HandleDesignAsyncMessage(AMessage: TRpAsyncMessage);
var
  LPayload: TRpDesignContextPayload;
  LErrorMessage, LPendingPrompt, LDatasetErrorMessage: string;
begin
  // WMHandleDesignContextPayload of the VCL
  if not (AMessage is TRpDesignContextPayload) then
    Exit;
  LPayload := TRpDesignContextPayload(AMessage);
  if LPayload.RequestVersion <> FDesignContextRefreshVersion then
    Exit;
  FDesignContextRefreshRunning := False;
  LErrorMessage := '';
  if Trim(LPayload.ErrorMessage) <> '' then
  begin
    FDesignChatContextJson := '';
    FDesignChatContextInitialized := False;
    LErrorMessage := LPayload.ErrorMessage;
  end
  else
  begin
    // No alias of the designer: the evaluator of the copy gets its own
    FDesignChatContextJson := BuildDesignExpressionContextJson(LPayload.ContextReport,
      nil, LPayload.OpenErrors, LPayload.SchemaOnlyFields, LPayload.SchemaOnlyErrors,
      LErrorMessage);
    FDesignChatContextInitialized := Trim(FDesignChatContextJson) <> '';
  end;
  UpdateDesignContextProgress(False, '');
  if Assigned(FChatFrame) then
    FChatFrame.SetBusy(False);
  LPendingPrompt := Trim(FDesignChatPendingPrompt);
  FDesignChatPendingPrompt := '';
  LDatasetErrorMessage := BuildDesignDatasetErrorMessage(LPayload.OpenErrors,
    LErrorMessage);
  if not Assigned(FChatFrame) then
    Exit;

  if LPendingPrompt <> '' then
  begin
    if not ConfirmDesignPromptWithDatasetErrors(LDatasetErrorMessage) then
    begin
      FDesignChatValidatedPrompt := '';
      FChatFrame.AddAssistantMessage(TranslateStr(1647,
        'Design request canceled after dataset validation.'));
      Exit;
    end;
    FDesignChatValidatedPrompt := LPendingPrompt;
    FChatFrame.StartDesignPrompt(LPendingPrompt);
    Exit;
  end;

  if Trim(LErrorMessage) <> '' then
  begin
    FChatFrame.AddAssistantMessage(TranslateStr(1648, 'Context refresh failed') +
      ': ' + LErrorMessage);
    Exit;
  end;
  if Trim(LDatasetErrorMessage) <> '' then
    FChatFrame.AddAssistantMessage(TranslateStr(1649,
      'Context refreshed with dataset errors.') + sLineBreak + LDatasetErrorMessage)
  else
    FChatFrame.AddAssistantMessage(TranslateStr(1650, 'Context refreshed.'));
end;

procedure TFRpMainFLCL.SetHostedMode(Value: Boolean);
begin
  FHostedMode := Value;
  // rpmdesignervcl: ANew/AOpen/ASave/ASaveAs.Visible:=false. Disabled too, so
  // their shortcuts do nothing
  MenuFileNew.Visible := not Value;
  MenuFileNew.Enabled := not Value;
  MenuFileNewWizard.Visible := not Value;
  MenuFileNewWizard.Enabled := not Value;
  MenuFileOpen.Visible := not Value;
  MenuFileOpen.Enabled := not Value;
  MenuFileOpenLib.Visible := not Value;
  MenuFileOpenLib.Enabled := not Value;
  MenuFileSave.Visible := not Value;
  MenuFileSave.Enabled := not Value;
  MenuFileSaveAs.Visible := not Value;
  MenuFileSaveAs.Enabled := not Value;
  BtnNew.Visible := not Value;
  BtnNewWizard.Visible := not Value;
  BtnOpen.Visible := not Value;
  BtnSave.Visible := not Value;
end;

procedure TFRpMainFLCL.UpdateTitle;
var
  sTitle: string;
begin
  sTitle := TranslateStr(1, 'Report Manager Designer') + ' - [';
  if Length(FFileName) > 0 then
    sTitle := sTitle + ExtractFileName(FFileName) + ']'
  else if Length(FLibraryReportName) > 0 then
    sTitle := sTitle + FLibraryName + '->' + FLibraryReportName + ']'
  else
    sTitle := sTitle + TranslateStr(501, 'Untitled') + ']';
  if Assigned(FReport) and FReport.Modified then
    sTitle := sTitle + ' *';
  Caption := sTitle;
end;

procedure TFRpMainFLCL.SetFileName(const Value: string);
begin
  FFileName := Value;
  UpdateTitle;
end;

function TFRpMainFLCL.CheckModified: Boolean;
begin
  Result := Assigned(FReport) and FReport.Modified;
end;

function TFRpMainFLCL.CheckSave: Boolean;
var
  res: TMessageButton;
begin
  Result := True;
  if not CheckModified then
    Exit;

  res := RpMessageBox(SRpReportChanged, SRpWarning, [smbYes, smbNo, smbCancel],
    smsWarning, smbYes, smbCancel);

  case res of
    smbYes:
      begin
        if FHostedMode then
          // The host (TRpDesignerLCL.Execute) saves the report
          FSaveAccepted := True
        else
          Result := SaveCurrentReport;
      end;
    smbNo:
      begin
        if FHostedMode then
          FSaveAccepted := False;
        Result := True;
      end;
  else
    Result := False;
  end;
end;

function TFRpMainFLCL.SaveCurrentReport: Boolean;
begin
  // VCL ASaveExecute: file, then library, then Save as
  Result := True;
  if Length(FFileName) > 0 then
    SaveReportFile(FFileName)
  else if Length(FLibraryReportName) > 0 then
    SaveToLibrary
  else if SaveDialog1.Execute then
    SaveReportFile(SaveDialog1.FileName)
  else
    Result := False;
end;

procedure TFRpMainFLCL.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  try
    CanClose := CheckSave;
  except
    // A failed save must not close the designer; the error is shown
    CanClose := False;
    raise;
  end;
end;

function TFRpMainFLCL.GetLibraryConnections: TRpDatabaseInfoList;
var
  configfilelib: string;
begin
  if not Assigned(FLibConnections) then
  begin
    FLibConnections := TRpDatabaseInfoList.Create(nil);
    // Same library configuration file as the VCL designer
    configfilelib := Obtainininameuserconfig('', '', 'repmandlib');
    if FileExists(configfilelib) then
      FLibConnections.LoadFromFile(configfilelib);
  end;
  Result := FLibConnections;
end;

procedure TFRpMainFLCL.OpenReportStream(AStream: TStream);
var
  newRep: TRpReport;
begin
  // On error the current report, file name and frames stay untouched
  newRep := LoadDesignReport(AStream);
  // The undo history saved with the report (XML, BINCUE) is kept
  InstallReport(newRep, '', True);
end;

procedure TFRpMainFLCL.OpenReportFile(const AFileName: string);
var
  astream: TFileStream;
  newRep: TRpReport;
begin
  if not FileExists(AFileName) then
  begin
    ShowMessage(TranslateStr(731, 'Not found') + ': ' + AFileName);
    Exit;
  end;

  if not CheckSave then
    Exit;

  astream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    // Load into a new report first: a load error is raised and nothing of
    // the current report (file name, frames, undo history) is lost
    newRep := LoadDesignReport(astream);
  finally
    astream.Free;
  end;
  InstallReport(newRep, AFileName, True);
end;

procedure TFRpMainFLCL.OpenReportFromLibrary(const ALibrary: string;
  const AReportName: WideString);
var
  astream: TStream;
begin
  // The caller is responsible of CheckSave (VCL DoOpenFromLib)
  astream := GetLibraryConnections.GetReportStream(ALibrary, AReportName, nil);
  try
    OpenReportStream(astream);
  finally
    astream.Free;
  end;
  FLibraryName := ALibrary;
  FLibraryReportName := AReportName;
  UpdateStatus;
end;

procedure TFRpMainFLCL.SaveReportFile(const AFileName: string);
begin
  if not Assigned(FReport) then Exit;
  FReport.SaveToFile(AFileName);
  FFileName := AFileName;
  FLibraryName := '';
  FLibraryReportName := '';
  // MarkClean also resets Report.Modified
  GetUndoCue.MarkClean;
  UpdateStatus;
end;

procedure TFRpMainFLCL.SaveToLibrary;
var
  astream: TMemoryStream;
begin
  if not Assigned(FReport) then Exit;
  // VCL DoSave, library branch
  astream := TMemoryStream.Create;
  try
    FReport.SaveToStream(astream);
    astream.Seek(0, soFromBeginning);
    GetLibraryConnections.SaveReportStream(FLibraryName, FLibraryReportName, astream, nil);
  finally
    astream.Free;
  end;
  GetUndoCue.MarkClean;
  UpdateStatus;
end;

procedure TFRpMainFLCL.NewReport;
var
  newRep: TRpReport;
  subrep: TRpSubReport;
begin
  if not CheckSave then
    Exit;

  newRep := CreateDesignReport;
  try
    subrep := newRep.AddSubReport;
    subrep.AddPageHeader;
    subrep.AddDetail;
    subrep.AddPageFooter;
  except
    newRep.Free;
    raise;
  end;
  InstallReport(newRep, '', False);
end;

procedure TFRpMainFLCL.RefreshInterface;
begin
  if not Assigned(FReport) then Exit;

  EnsureUndoCue;

  if Assigned(FDesignerFrame) then
  begin
    FDesignerFrame.Report := FReport;
    FDesignerFrame.UpdateInterface(True);
    FDesignerFrame.UpdateSelection(False);
  end;

  if Assigned(FStructure) then
  begin
    FStructure.Report := FReport;
    if Assigned(FStructure.browser) then
      FStructure.browser.Report := FReport;
  end;

  UpdateStatus;
end;

procedure TFRpMainFLCL.UpdateStatus;
var
  sInfo: string;
  cue: TUndoCue;
begin
  UpdateTitle;

  if not Assigned(FReport) then
  begin
    StatusBar.SimpleText := '';
    BtnUndo.Enabled := False;
    BtnRedo.Enabled := False;
    MenuEditUndo.Enabled := False;
    MenuEditRedo.Enabled := False;
    Exit;
  end;

  // Subreports, scale, file and '*' when modified (as the title)
  sInfo := TranslateStr(125, 'Subreport') + ': ' +
    IntToStr(FReport.SubReports.Count) + ' | ' +
    IntToStr(Round(FDesignerFrame.Scale * 100)) + '%';
  if Length(FFileName) > 0 then
    sInfo := sInfo + ' | ' + ExtractFileName(FFileName);
  if FReport.Modified then
    sInfo := sInfo + ' | *';
  StatusBar.SimpleText := sInfo;
  // Undo/redo may change the grid visibility
  MenuViewGrid.Checked := FReport.GridVisible;

  if Assigned(FReport.UndoCue) then
  begin
    cue := TUndoCue(FReport.UndoCue);
    BtnUndo.Enabled := cue.CanUndo;
    BtnRedo.Enabled := cue.CanRedo;
    MenuEditUndo.Enabled := cue.CanUndo;
    MenuEditRedo.Enabled := cue.CanRedo;
  end
  else
  begin
    BtnUndo.Enabled := False;
    BtnRedo.Enabled := False;
    MenuEditUndo.Enabled := False;
    MenuEditRedo.Enabled := False;
  end;
end;

procedure TFRpMainFLCL.EmbedInControl(AParent: TWinControl);
begin
  BorderStyle := bsNone;
  Parent := AParent;
  Align := alClient;
  Visible := True;
end;

procedure TFRpMainFLCL.BtnNewClick(Sender: TObject);
begin
  NewReport;
end;

procedure TFRpMainFLCL.BtnNewWizardClick(Sender: TObject);
var
  newRep: TRpReport;
  accepted: Boolean;
begin
  if not CheckSave then
    Exit;
  newRep := CreateDesignReport;
  try
    accepted := NewReportWizard(newRep, False);
  except
    newRep.Free;
    raise;
  end;
  if not accepted then
  begin
    newRep.Free;
    Exit;
  end;
  // From here the new report is owned by the form (never freed twice even
  // if refreshing the interface raises); history starts clean
  InstallReport(newRep, '', False);
end;

procedure TFRpMainFLCL.MenuReportWizardClick(Sender: TObject);
var
  cue: TUndoCue;
begin
  if not Assigned(FReport) then
    Exit;
  FReport.AssertCanModify('Report wizard');
  EnsureUndoCue;
  if NewReportWizard(FReport, True) then
  begin
    // The columns created by the wizard are not recorded as undo operations
    // and may reuse names of the history: restart the history keeping the
    // report dirty
    cue := GetUndoCue;
    cue.Clear;
    cue.MarkExternalChange;
    RefreshInterface;
  end;
end;

procedure TFRpMainFLCL.BtnOpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    OpenReportFile(OpenDialog1.FileName);
end;

procedure TFRpMainFLCL.MenuFileOpenLibClick(Sender: TObject);
var
  alibname: string;
  arepname: WideString;
begin
  // VCL AOpenFromExecute: the designer library connections (repmandlib),
  // not the report connections
  if not CheckSave then
    Exit;
  alibname := FLibraryName;
  arepname := SelectReportFromLibrary(GetLibraryConnections, alibname);
  if Length(arepname) < 1 then
    Exit;
  OpenReportFromLibrary(alibname, arepname);
end;

procedure TFRpMainFLCL.BtnSaveClick(Sender: TObject);
begin
  if FHostedMode then
    Exit;
  SaveCurrentReport;
end;

procedure TFRpMainFLCL.BtnSaveAsClick(Sender: TObject);
begin
  if FHostedMode then
    Exit;
  if SaveDialog1.Execute then
    SaveReportFile(SaveDialog1.FileName);
end;

procedure TFRpMainFLCL.BtnDataConfigClick(Sender: TObject);
begin
  if not Assigned(FReport) then Exit;
  // The dialog records the undo operations of the accepted changes
  EnsureUndoCue;
  if ShowDataConfig(FReport) then
  begin
    if Assigned(FStructure) and Assigned(FStructure.browser) then
      FStructure.browser.Report := FReport;
    if Assigned(FDesignerFrame) then
      FDesignerFrame.UpdateSelection(False);
  end;
end;

procedure TFRpMainFLCL.BtnParamsClick(Sender: TObject);
begin
  if not Assigned(FReport) then Exit;
  FReport.AssertCanModify('Report parameters');
  // ShowParamDef records the undo operations when the dialog is accepted
  EnsureUndoCue;
  ShowParamDef(FReport.Params, FReport.DataInfo, FReport);
  if Assigned(FStructure) and Assigned(FStructure.browser) then
    FStructure.browser.Report := FReport;
end;

procedure TFRpMainFLCL.MenuReportUserParamsClick(Sender: TObject);
var
  origParams: TRpParamList;
begin
  if not Assigned(FReport) then Exit;
  EnsureUndoCue;
  origParams := TRpParamList.Create(nil);
  try
    origParams.Assign(FReport.Params);
    try
      rprflclparams.ShowUserParams(FReport.Params);
    finally
      // The dialog (and the lookup / initial value refresh done before it)
      // changes the parameter values stored in the report
      RecordParamUndoChanges(origParams, FReport.Params, FReport);
    end;
  finally
    origParams.Free;
  end;
end;

type
  TRpPageSetupProp = record
    Name: string;
    PropType: TPropertyType;
  end;

const
  // Report properties changed by the page setup dialog (rppagesetuplcl)
  PAGESETUP_PROPS: array[0..28] of TRpPageSetupProp = (
    (Name: 'LinesPerInch'; PropType: ptInteger),
    (Name: 'Copies'; PropType: ptInteger),
    (Name: 'CollateCopies'; PropType: ptBoolean),
    (Name: 'TwoPass'; PropType: ptBoolean),
    (Name: 'PreviewAbout'; PropType: ptBoolean),
    (Name: 'PrintOnlyIfDataAvailable'; PropType: ptBoolean),
    (Name: 'ReportAction'; PropType: ptInteger),
    (Name: 'Pagesize'; PropType: ptInteger),
    (Name: 'PagesizeQt'; PropType: ptInteger),
    (Name: 'PageHeight'; PropType: ptInteger),
    (Name: 'PageWidth'; PropType: ptInteger),
    (Name: 'CustomPageWidth'; PropType: ptInteger),
    (Name: 'CustomPageHeight'; PropType: ptInteger),
    (Name: 'LeftMargin'; PropType: ptInteger),
    (Name: 'RightMargin'; PropType: ptInteger),
    (Name: 'TopMargin'; PropType: ptInteger),
    (Name: 'BottomMargin'; PropType: ptInteger),
    (Name: 'PageOrientation'; PropType: ptInteger),
    (Name: 'PrinterSelect'; PropType: ptInteger),
    (Name: 'PageBackColor'; PropType: ptInteger),
    (Name: 'Language'; PropType: ptInteger),
    (Name: 'PrinterFonts'; PropType: ptInteger),
    (Name: 'PreviewStyle'; PropType: ptInteger),
    (Name: 'PreviewMargins'; PropType: ptBoolean),
    (Name: 'PreviewWindow'; PropType: ptInteger),
    (Name: 'StreamFormat'; PropType: ptInteger),
    (Name: 'PaperSource'; PropType: ptInteger),
    (Name: 'Duplex'; PropType: ptInteger),
    (Name: 'ForcePaperName'; PropType: ptString)
  );

procedure TFRpMainFLCL.BtnPageSetupClick(Sender: TObject);
var
  snapshot: array[0..High(PAGESETUP_PROPS)] of Variant;
  i: Integer;
  newValue: Variant;
  cue: TUndoCue;
  op: TChangeObjectOperation;
begin
  if not Assigned(FReport) then Exit;
  FReport.AssertCanModify('Page setup');
  for i := 0 to High(PAGESETUP_PROPS) do
    snapshot[i] := FReport.GetItemProperty(PAGESETUP_PROPS[i].Name);
  if ExecutePageSetup(FReport) then
  begin
    // Same as rppagesetupvcl.SaveOptions: one otModify on REPORT with the
    // changed properties
    cue := GetUndoCue;
    op := TChangeObjectOperation.Create(otModify, cue.GetGroupId);
    op.componentName := 'REPORT';
    op.componentClass := 'TRPREPORT';
    op.parentName := '';
    for i := 0 to High(PAGESETUP_PROPS) do
    begin
      newValue := FReport.GetItemProperty(PAGESETUP_PROPS[i].Name);
      if not ParamValuesEqual(snapshot[i], newValue) then
        op.AddProperty(PAGESETUP_PROPS[i].Name, PAGESETUP_PROPS[i].PropType,
          snapshot[i], newValue);
    end;
    if op.properties.Count > 0 then
      cue.AddOperation(op)
    else
      op.Free;
    if Assigned(FDesignerFrame) then
    begin
      FDesignerFrame.UpdateInterface(True);
      FDesignerFrame.Refresh;
    end;
    UpdateStatus;
  end;
end;

procedure TFRpMainFLCL.BtnPrintClick(Sender: TObject);
begin
  BtnPreviewClick(Sender);
end;

procedure TFRpMainFLCL.BtnPreviewClick(Sender: TObject);
var
  previewCtrl: TRpPreviewControl;
begin
  if not Assigned(FReport) then Exit;
  try
    previewCtrl := TRpPreviewControl.Create(nil);
    try
      previewCtrl.Report := FReport;
      rplclpreview.ShowPreview(previewCtrl, TranslateStr(54, 'Preview') + ' - ' + Caption);
    finally
      previewCtrl.Free;
    end;
  except
    on E: Exception do
      ShowMessage(TranslateStr(355, 'Error') + ': ' + E.Message);
  end;
end;

function TFRpMainFLCL.GetShortcutFocusedControl: TWinControl;
begin
  Result := nil;
  if Assigned(Screen.ActiveCustomForm) then
    Result := Screen.ActiveCustomForm.ActiveControl;
  if (Result = nil) and Assigned(Screen.ActiveForm) then
    Result := Screen.ActiveForm.ActiveControl;
  if Result = nil then
    Result := ActiveControl;
end;

function TFRpMainFLCL.IsEditableTextShortcutTarget(AControl: TWinControl): Boolean;
begin
  Result := False;
  if not Assigned(AControl) then
    Exit;
  if AControl is TCustomEdit then
  begin
    Result := not TCustomEdit(AControl).ReadOnly;
    Exit;
  end;
  if AControl is TComboBox then
    Result := TComboBox(AControl).Style <> csDropDownList;
end;

function TFRpMainFLCL.ShouldHandleDesignerUndoShortcut: Boolean;
begin
  Result := not IsEditableTextShortcutTarget(GetShortcutFocusedControl);
end;

procedure TFRpMainFLCL.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Shift = [ssCtrl]) and (Key = VK_Z) and ShouldHandleDesignerUndoShortcut then
  begin
    Key := 0;
    DoUndo;
  end
  else if ((Shift = [ssCtrl]) and (Key = VK_Y) or (Shift = [ssCtrl, ssShift]) and (Key = VK_Z)) and ShouldHandleDesignerUndoShortcut then
  begin
    Key := 0;
    DoRedo;
  end;
end;

procedure TFRpMainFLCL.DoUndo;
var
  cue: TUndoCue;
  ops: TObjectList<TChangeObjectOperation>;
begin
  if not Assigned(FReport) then Exit;
  FReport.AssertCanModify('Undo');
  cue := GetUndoCue;
  if not cue.CanUndo then Exit;
  ops := nil;
  try
    ops := cue.Undo;
  finally
    // The returned list does not own the operations, but the caller owns it.
    // Rebuild the display even if an operation failed midway.
    ops.Free;
    if Assigned(FStructure) then
    begin
      if Assigned(FStructure.cueview) then
        FStructure.cueview.RefreshList;
      FStructure.CueUndoRedo(Self);
    end;
    UpdateStatus;
  end;
end;

procedure TFRpMainFLCL.DoRedo;
var
  cue: TUndoCue;
  ops: TObjectList<TChangeObjectOperation>;
begin
  if not Assigned(FReport) then Exit;
  FReport.AssertCanModify('Redo');
  cue := GetUndoCue;
  if not cue.CanRedo then Exit;
  ops := nil;
  try
    ops := cue.Redo;
  finally
    ops.Free;
    if Assigned(FStructure) then
    begin
      if Assigned(FStructure.cueview) then
        FStructure.cueview.RefreshList;
      FStructure.CueUndoRedo(Self);
    end;
    UpdateStatus;
  end;
end;

procedure TFRpMainFLCL.BtnUndoClick(Sender: TObject);
begin
  if (Sender = MenuEditUndo) and not ShouldHandleDesignerUndoShortcut then
    Exit;
  DoUndo;
end;

procedure TFRpMainFLCL.BtnRedoClick(Sender: TObject);
begin
  if (Sender = MenuEditRedo) and not ShouldHandleDesignerUndoShortcut then
    Exit;
  DoRedo;
end;

procedure TFRpMainFLCL.StructureUndoRedo(Sender: TObject);
begin
  if Assigned(FDesignerFrame) then
  begin
    FDesignerFrame.UpdateInterface(True);
    FDesignerFrame.UpdateSelection(False);
  end;
  if Assigned(FStructure) and Assigned(FReport) then
    FStructure.Report := FReport;
  UpdateStatus;
end;

procedure TFRpMainFLCL.BtnToolClick(Sender: TObject);
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
  else if Sender = BtnToolChart then
    FDesignerFrame.ActiveTool := dtChart
  else if Sender = BtnToolBarcode then
    FDesignerFrame.ActiveTool := dtBarcode;
end;

procedure TFRpMainFLCL.DesignerToolChange(Sender: TObject);
begin
  case FDesignerFrame.ActiveTool of
    dtArrow: BtnToolArrow.Down := True;
    dtLabel: BtnToolLabel.Down := True;
    dtExpression: BtnToolExpr.Down := True;
    dtShape: BtnToolShape.Down := True;
    dtImage: BtnToolImage.Down := True;
    dtChart: BtnToolChart.Down := True;
    dtBarcode: BtnToolBarcode.Down := True;
  end;
end;

procedure TFRpMainFLCL.BtnDeleteClick(Sender: TObject);
begin
  if Assigned(FDesignerFrame) then
    FDesignerFrame.DeleteSelection;
end;

procedure TFRpMainFLCL.BtnCutClick(Sender: TObject);
begin
  BtnCopyClick(Sender);
  BtnDeleteClick(Sender);
end;

procedure TFRpMainFLCL.BtnCopyClick(Sender: TObject);
var
  acompo: TComponent;
  pitem: TRpCommonComponent;
  i: Integer;
begin
  if not Assigned(FObjInsp) or (FObjInsp.SelectedItems.Count < 1) then Exit;
  if not (FObjInsp.SelectedItems.Objects[0] is TRpSizePosInterface) then Exit;
  acompo := TRpReport.Create(nil);
  try
    acompo.Name := 'TheOwner';
    for i := 0 to FObjInsp.SelectedItems.Count - 1 do
    begin
      pitem := TRpSizePosInterface(FObjInsp.SelectedItems.Objects[i]).printitem;
      pitem.oldowner := pitem.Owner;
      pitem.Owner.RemoveComponent(pitem);
      acompo.InsertComponent(pitem);
    end;
    Clipboard.SetComponent(acompo);
    for i := 0 to FObjInsp.SelectedItems.Count - 1 do
    begin
      pitem := TRpSizePosInterface(FObjInsp.SelectedItems.Objects[i]).printitem;
      acompo.RemoveComponent(pitem);
      pitem.oldowner.InsertComponent(pitem);
    end;
  finally
    acompo.Free;
  end;
end;

procedure TFRpMainFLCL.BtnPasteClick(Sender: TObject);
var
  section: TRpSection;
  secint: TRpSectionInterface;
  compo, acompo: TComponent;
  i: Integer;
  alist: TList;
  pitem: TRpCommonPosComponent;
  ident: string;
  cue: TUndoCue;
  op: TChangeObjectOperation;
  groupId: Integer;
begin
  if not Assigned(FReport) then Exit;
  if not Assigned(FObjInsp) or (FObjInsp.SelectedItems.Count < 1) then Exit;
  if (FObjInsp.SelectedItems.Objects[0] is TRpSectionInterface) then
    secint := TRpSectionInterface(FObjInsp.CompItem)
  else
    secint := TRpSectionInterface(TRpSizePosInterface(FObjInsp.SelectedItems.Objects[0]).SectionInt);
  if not Assigned(secint) then Exit;
  FReport.AssertCanModify('Paste');
  FObjInsp.ClearMultiSelect;
  section := TRpSection(secint.printitem);
  cue := GetUndoCue;
  groupId := -1;
  acompo := TRpReport.Create(nil);
  try
    acompo.Name := 'AOwner';
    compo := Clipboard.GetComponent(acompo, acompo);
    if not Assigned(compo) then Exit;
    alist := TList.Create;
    try
      for i := 0 to compo.ComponentCount - 1 do
      begin
        alist.Add(compo.Components[i]);
        if compo.Components[i] is TRpExpression then
        begin
          ident := TRpExpression(compo.Components[i]).Identifier;
          if (Length(ident) > 0) and (FReport.Identifiers.IndexOf(ident) >= 0) then
            TRpExpression(compo.Components[i]).Identifier := '';
        end;
      end;
      for i := 0 to alist.Count - 1 do
      begin
        if not (TObject(alist[i]) is TRpCommonPosComponent) then Continue;
        pitem := TRpCommonPosComponent(alist[i]);
        compo.RemoveComponent(pitem);
        // A fresh unique name: the clipboard name may exist in the report or
        // in the undo history
        pitem.Name := '';
        section.ReportComponents.Add.Component := pitem;
        if section.IsExternal then
          section.InsertComponent(pitem)
        else
          FReport.InsertComponent(pitem);
        GenerateNewName(pitem);
        FObjInsp.AddCompItem(secint.CreateChild(pitem), False);
        // Record the pasted component (APasteExecute): one otAdd per item,
        // all of them in the same group so a single undo removes the paste
        if groupId < 0 then
          groupId := cue.GetGroupId;
        op := TChangeObjectOperation.Create(otAdd, groupId);
        op.componentName := pitem.Name;
        op.componentClass := UpperCase(pitem.ClassName);
        op.parentName := section.Name;
        cue.AddAllComponentProperties(pitem, op);
        cue.AddOperation(op);
      end;
      if Assigned(FDesignerFrame) then
        FDesignerFrame.UpdateInterface(True);
    finally
      alist.Free;
    end;
  finally
    acompo.Free;
  end;
end;

procedure TFRpMainFLCL.BtnNudgeLeftClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.MoveSelected(1, False);
end;

procedure TFRpMainFLCL.BtnNudgeRightClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.MoveSelected(2, False);
end;

procedure TFRpMainFLCL.BtnNudgeUpClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.MoveSelected(3, False);
end;

procedure TFRpMainFLCL.BtnNudgeDownClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.MoveSelected(4, False);
end;

procedure TFRpMainFLCL.BtnAlignLeftClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.AlignSelected(1);
end;

procedure TFRpMainFLCL.BtnAlignRightClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.AlignSelected(2);
end;

procedure TFRpMainFLCL.BtnAlignUpClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.AlignSelected(3);
end;

procedure TFRpMainFLCL.BtnAlignDownClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.AlignSelected(4);
end;

procedure TFRpMainFLCL.BtnAlignHorzClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.AlignSelected(5);
end;

procedure TFRpMainFLCL.BtnAlignVertClick(Sender: TObject);
begin
  if Assigned(FObjInsp) then FObjInsp.AlignSelected(6);
end;

procedure TFRpMainFLCL.BtnToFrontClick(Sender: TObject);
begin
  FDesignerFrame.BringSelectionToFront;
end;

procedure TFRpMainFLCL.BtnToBackClick(Sender: TObject);
begin
  FDesignerFrame.SendSelectionToBack;
end;

procedure TFRpMainFLCL.BtnSelectAllClick(Sender: TObject);
begin
  FDesignerFrame.SelectAll;
end;

procedure TFRpMainFLCL.ComboScaleChange(Sender: TObject);
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

procedure TFRpMainFLCL.MenuViewGridClick(Sender: TObject);
var
  cue: TUndoCue;
  op: TChangeObjectOperation;
  oldVisible: Boolean;
begin
  if not Assigned(FReport) then
  begin
    MenuViewGrid.Checked := not MenuViewGrid.Checked;
    Exit;
  end;
  FReport.AssertCanModify('Grid');
  MenuViewGrid.Checked := not MenuViewGrid.Checked;
  oldVisible := FReport.GridVisible;
  FReport.GridVisible := MenuViewGrid.Checked;
  if oldVisible <> FReport.GridVisible then
  begin
    // GridVisible is saved with the report: record it
    cue := GetUndoCue;
    op := TChangeObjectOperation.Create(otModify, cue.GetGroupId);
    op.componentName := 'REPORT';
    op.componentClass := 'TRPREPORT';
    op.parentName := '';
    op.AddProperty('gridVisible', ptBoolean, oldVisible, FReport.GridVisible);
    cue.AddOperation(op);
  end;
  FDesignerFrame.UpdateInterface(False);
end;

procedure TFRpMainFLCL.MenuReportGridClick(Sender: TObject);
begin
  if Assigned(FReport) then
  begin
    // ModifyGridProperties records the undo operation on OK
    EnsureUndoCue;
    if Assigned(FObjInsp) then
      FObjInsp.ClearMultiSelect;
    ModifyGridProperties(FReport);
    MenuViewGrid.Checked := FReport.GridVisible;
    if Assigned(FDesignerFrame) then
      FDesignerFrame.UpdateInterface(True);
  end;
end;

procedure TFRpMainFLCL.MenuViewUnitsClick(Sender: TObject);
begin
  if TMenuItem(Sender).Tag = 0 then
  begin
    rpmunits.defaultunit := rpUnitCms;
    MenuViewUnitsCm.Checked := True;
    MenuViewUnitsInches.Checked := False;
    FDesignerFrame.TopRuler.Metrics := rCms;
  end
  else
  begin
    rpmunits.defaultunit := rpUnitInchess;
    MenuViewUnitsCm.Checked := False;
    MenuViewUnitsInches.Checked := True;
    FDesignerFrame.TopRuler.Metrics := rInchess;
  end;
  FDesignerFrame.UpdateInterface(False);
end;

procedure TFRpMainFLCL.MenuViewScaleClick(Sender: TObject);
begin
  ComboScale.Text := IntToStr(TMenuItem(Sender).Tag) + '%';
  ComboScaleChange(ComboScale);
end;

procedure TFRpMainFLCL.MenuHelpAboutClick(Sender: TObject);
begin
  ShowAbout;
end;

procedure TFRpMainFLCL.MenuFileExitClick(Sender: TObject);
begin
  Close;
end;

end.
