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
  rpreportdesignercontracts, rpaithreadslcl, rplastsav;

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
    // File > Libraries: configure, open from, save to (VCL MLibraries)
    MenuFileLibraries: TMenuItem;
    MenuFileLibConfig: TMenuItem;
    MenuFileSaveLib: TMenuItem;
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
    // Menus of the VCL designer (rpmdfmainvcl) added by BuildVCLMenus
    MenuFilePrintSetup: TMenuItem;
    MenuReportAdd: TMenuItem;
    MenuReportDeleteSection: TMenuItem;
    MenuEditSelectAllText: TMenuItem;
    MenuEditMove: TMenuItem;
    MenuEditAlign: TMenuItem;
    MenuEditHide: TMenuItem;
    MenuEditShowAll: TMenuItem;
    MenuEditAlign1_6: TMenuItem;
    MenuPreferences: TMenuItem;
    MenuPrefStatusBar: TMenuItem;
    MenuPrefObjFont: TMenuItem;
    MenuPrefTypeInfo: TMenuItem;
    MenuPrefPrintDialog: TMenuItem;
    MenuHelpDoc: TMenuItem;
    MenuHelpSysInfo: TMenuItem;
    // Last used files (VCL Lastusedfiles), listed after File > Exit
    FLastUsedFiles: TRpLastUsedStrings;
    // Object inspector font (Preferences), applied when chosen
    FObjFontName: string;
    FObjFontSize: Integer;
    FObjFontStyle: Integer;
    FObjFontColor: Integer;

    procedure BuildMenus;
    procedure BuildVCLMenus;
    function NewMenuItem(AParent: TMenuItem; const ACaption, AHint: string;
      AOnClick: TNotifyEvent): TMenuItem;
    procedure AppHint(Sender: TObject);
    procedure UpdateFileMenu;
    procedure UseFile(const AName: string);
    procedure RecentFileClick(Sender: TObject);
    procedure ApplyObjInspFont;
    procedure ApplyUnits;
    function SelectedSizePosItems: Boolean;
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
    procedure MenuFileLibConfigClick(Sender: TObject);
    procedure MenuFileSaveLibClick(Sender: TObject);
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
    procedure BtnSelectAllClick(Sender: TObject);
    procedure ComboScaleChange(Sender: TObject);
    procedure MenuViewGridClick(Sender: TObject);
    procedure MenuReportGridClick(Sender: TObject);
    procedure MenuViewUnitsClick(Sender: TObject);
    procedure MenuViewScaleClick(Sender: TObject);
    procedure MenuHelpAboutClick(Sender: TObject);
    procedure MenuHelpDocClick(Sender: TObject);
    procedure MenuHelpSysInfoClick(Sender: TObject);
    procedure MenuFilePrintSetupClick(Sender: TObject);
    procedure MenuReportAddClick(Sender: TObject);
    procedure MenuReportDeleteSectionClick(Sender: TObject);
    procedure MenuEditSelectAllTextClick(Sender: TObject);
    procedure MenuEditHideClick(Sender: TObject);
    procedure MenuEditShowAllClick(Sender: TObject);
    procedure MenuEditAlign1_6Click(Sender: TObject);
    procedure MenuPrefStatusBarClick(Sender: TObject);
    procedure MenuPrefObjFontClick(Sender: TObject);
    procedure MenuPrefTypeInfoClick(Sender: TObject);
    procedure MenuPrefPrintDialogClick(Sender: TObject);
    procedure MenuViewAIChatClick(Sender: TObject);
    procedure ApplyChatPanelVisibility;
    function GetShowAIChat: Boolean;
    procedure SetShowAIChat(Value: Boolean);
    procedure LoadDesignerPreferences;
    procedure SaveDesignerPreferences;
    procedure ResolveInitialDesignChatSchemaContext(out AHubDatabaseId,
      AHubSchemaId: Int64; out ASchemaApiKey: string);
    procedure InitializeDesignChatSchemaSelection;
    // The direct connections of the report (and their local subschemas) in
    // the schema selector of the design chat
    procedure UpdateDesignChatLocalSchemas;
    procedure ConfigureDesignChatLocalSchemas(Sender: TObject;
      const AAlias, ASchemaName: string);
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
    // Toolbar buttons (those of the VCL toolbar)
    BtnNew: TToolButton;
    BtnOpen: TToolButton;
    Sep1: TToolButton;
    BtnSave: TToolButton;
    BtnDataConfig: TToolButton;
    Sep2: TToolButton;
    BtnPrint: TToolButton;
    BtnPreview: TToolButton;
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
    BtnDelete: TToolButton;
    BtnCut: TToolButton;
    BtnCopy: TToolButton;
    BtnPaste: TToolButton;
    Sep5: TToolButton;
    BtnNudgeLeft: TToolButton;
    BtnNudgeRight: TToolButton;
    BtnNudgeUp: TToolButton;
    BtnNudgeDown: TToolButton;
    Sep6: TToolButton;
    BtnAlignLeft: TToolButton;
    BtnAlignRight: TToolButton;
    BtnAlignUp: TToolButton;
    BtnAlignDown: TToolButton;
    BtnAlignHorz: TToolButton;
    BtnAlignVert: TToolButton;
    // AChatIA of the VCL toolbar: shows or hides the AI panel
    BtnAIChat: TToolButton;

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
    // VCL ASaveToExecute after the selection: saves the report over the
    // library report, that becomes the document (restored on error)
    procedure SaveReportToLibrary(const ALibrary: string; const AReportName: WideString);
    // File > Libraries > Save to library: selection in the library dialog
    procedure SaveToLibraryAs;
    // File > Libraries > Configure libraries (VCL ALibrariesExecute): the
    // accepted connections are saved in the library configuration file
    procedure ConfigureLibraries;
    procedure SaveReportFile(const AFileName: string);
    // A blank report, without questions (also the one of the constructor)
    procedure NewReport;
    // File > New, as rpmdfmainvcl ANewExecute: the new report wizard
    // (connection, Hub schema and prompt); the design chat gets the Hub
    // context and starts with the prompt. False when it was canceled (the
    // current report stays)
    function NewReportFromWizard: Boolean;
    procedure RefreshInterface;
    procedure UpdateStatus;
    procedure UpdateTitle;
    function CheckModified: Boolean;
    function CheckSave: Boolean;
    procedure DoUndo;
    procedure DoRedo;
    // Marks the report dirty for a change that is not recorded in the cue
    procedure MarkExternalChange;
    // Commands of the VCL designer menus (rpmdfmainvcl AHide, AShowAll,
    // ASelectAllText, AAlign1_6, APrint)
    procedure HideSelection;
    procedure ShowAllHidden;
    procedure SelectAllText;
    procedure AlignSectionsToLines;
    procedure PrintCurrentReport;
    // Selects the component and property of a TRpReportException (VCL
    // MyExceptionHandler); False for other exceptions
    function SelectReportExceptionSource(E: Exception): Boolean;
    // Selects the source of the error and shows it
    procedure ShowReportError(E: Exception);
    // The Hub database of a schema of the design chat (connection wizard)
    function HubDatabaseOfSchema(AHubSchemaId: Int64): Int64;
    // Before running the report: the Reportman AI Agent connections not
    // configured on this computer go to the connection wizard
    function CheckAgentConnections: Boolean;
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
    // Report > Page setup (not in the toolbar, as in the VCL designer)
    property PageSetupMenuItem: TMenuItem read MenuReportPageSetup;
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
    // File > recent files (the repmand file of the VCL designer)
    property LastUsedFiles: TRpLastUsedStrings read FLastUsedFiles;
    property FileMenu: TMenuItem read MenuFile;
    property EditMenu: TMenuItem read MenuEdit;
    property ReportMenu: TMenuItem read MenuReport;
    property PreferencesMenu: TMenuItem read MenuPreferences;
    property HelpMenu: TMenuItem read MenuHelp;
    property StatusBarMenuItem: TMenuItem read MenuPrefStatusBar;
    property TypeInfoMenuItem: TMenuItem read MenuPrefTypeInfo;
    property PrintDialogMenuItem: TMenuItem read MenuPrefPrintDialog;
    property UnitsInchesMenuItem: TMenuItem read MenuViewUnitsInches;
    property UnitsCmMenuItem: TMenuItem read MenuViewUnitsCm;
    property StatusBarControl: TStatusBar read StatusBar;
  end;

var
  // Preferences file of the designer. Empty: the one of the VCL designer
  // (repmand in the user configuration folder); tests use a sandbox
  RpDesignerLCLConfigFile: string = '';
  // File > New runs the new report wizard (as the VCL designer); False: a
  // blank report as before
  RpDesignerLCLNewReportWizard: Boolean = True;
  // Library connections file of the designer. Empty: the one of the VCL
  // designer (repmandlib in the user configuration folder)
  RpDesignerLCLLibConfigFile: string = '';

implementation

{$R *.lfm}

uses
  // rpexpredlglcl: the dataset context of the assistants (ports of the
  // rpchatdialogvcl CollectAgentSchemaOnlyContext and
  // BuildDesignExpressionContextJson)
  IniFiles, LCLIntf, PrintersDlgs, md5, rpmdsysinfolcl, rpauthmanager, rpxmlstream, rpexpredlglcl,
  rpmdfnewreportwizardlcl, rplcllayout,
  // Report library: connections editor and tree (rpeditconnvcl, rpmdftreevcl)
  rpeditconnlcl, rpmdftreelcl,
  rplcldriver,
  // The local schema of the direct connections for the design assistant
  rplocalschemas, rpfrmlocalschemaslcl;

const
  // Width of the recent file names in the File menu (VCL C_FILENAME_WIDTH)
  C_FILENAME_WIDTH = 40;

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
    // Without the embedded files: the context does not need them
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
begin
  LScratch := TRpReport.Create(nil);
  LStream := TStringStream.Create(ADocument);
  try
    LScratch.FailIfLoadExternalError := False;
    LScratch.LoadFromStream(LStream);
  finally
    LStream.Free;
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

function LibraryConfigFileName: string;
begin
  Result := RpDesignerLCLLibConfigFile;
  if Result = '' then
    Result := Obtainininameuserconfig('', '', 'repmandlib');
end;

// Ends the transaction of a library connection after reading or saving a
// report (rpmdftreelcl.RpLibraryCommit)
procedure CommitLibraryConnection(AList: TRpDatabaseInfoList; const ALibrary: string);
var
  i: Integer;
begin
  i := AList.IndexOf(ALibrary);
  if i >= 0 then
    RpLibraryCommit(AList.Items[i]);
end;

{ TFRpMainFLCL }

constructor TFRpMainFLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  // Sizes in pixels of the screen: the LCL does not scale it again
  RpBuiltInScreenPixels(Self);
  // Room for the AI panel at the right (380) besides the design area
  Width := Scale96ToScreen(1260);
  Height := Scale96ToScreen(680);
  Caption := TranslateStr(1, 'Report Manager Designer');
  Position := poScreenCenter;
  Color := clBtnFace;
  FFileName := '';
  FOwnsReport := True;
  // Results of the dataset context worker (WM_USER + 207 of the VCL)
  FDesignMailbox := TRpAsyncMailbox.Create(HandleDesignAsyncMessage);
  FDesignMailboxRef := FDesignMailbox;

  FLastUsedFiles := TRpLastUsedStrings.Create(Self);
  FLastUsedFiles.CaseSensitive := False;
  BuildMenus;
  BuildControls;
  BuildVCLMenus;
  // View > AI chat, units, status bar... as the user left them (VCL
  // LoadConfig)
  LoadDesignerPreferences;
  if not MenuViewAIChat.Checked then
    ApplyChatPanelVisibility;
  // The hints of the menus and buttons go to the status bar (VCL AppHint)
  Application.AddOnHintHandler(AppHint);

  KeyPreview := True;
  OnKeyDown := FormKeyDown;
  OnCloseQuery := FormCloseQuery;

  // Initialize with a blank report
  NewReport;
end;

destructor TFRpMainFLCL.Destroy;
begin
  Application.RemoveOnHintHandler(AppHint);
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

  // Libraries submenu, as MLibraries of the VCL designer
  sep := TMenuItem.Create(MenuFile);
  sep.Caption := '-';
  MenuFile.Add(sep);

  MenuFileLibraries := TMenuItem.Create(MenuFile);
  MenuFileLibraries.Caption := TranslateStr(1080, 'Libraries...');
  MenuFileLibraries.Hint := TranslateStr(1081, 'Show and define report libraries');
  MenuFile.Add(MenuFileLibraries);

  MenuFileLibConfig := TMenuItem.Create(MenuFileLibraries);
  MenuFileLibConfig.Caption := SRpConfigLib;
  MenuFileLibConfig.Hint := SRpConfigLibH;
  MenuFileLibConfig.OnClick := MenuFileLibConfigClick;
  MenuFileLibraries.Add(MenuFileLibConfig);

  MenuFileOpenLib := TMenuItem.Create(MenuFileLibraries);
  MenuFileOpenLib.Caption := TranslateStr(1135, 'Open from library');
  MenuFileOpenLib.Hint := SRpOpenFromH;
  MenuFileOpenLib.OnClick := MenuFileOpenLibClick;
  MenuFileLibraries.Add(MenuFileOpenLib);

  MenuFileSaveLib := TMenuItem.Create(MenuFileLibraries);
  MenuFileSaveLib.Caption := SRpSaveTo;
  MenuFileSaveLib.Hint := SRpSaveToH;
  MenuFileSaveLib.OnClick := MenuFileSaveLibClick;
  MenuFileLibraries.Add(MenuFileSaveLib);

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

  function NewToolButton(AImage: Integer; const AHint: string;
    AOnClick: TNotifyEvent): TToolButton;
  begin
    Result := TToolButton.Create(MainToolBar);
    Result.Parent := MainToolBar;
    Result.ImageIndex := AImage;
    Result.Hint := AHint;
    Result.OnClick := AOnClick;
  end;

  function NewToolSeparator: TToolButton;
  begin
    Result := TToolButton.Create(MainToolBar);
    Result.Parent := MainToolBar;
    Result.Style := tbsSeparator;
    Result.Width := Scale96ToScreen(8);
  end;

begin
  // 1. ImageList (19x19 sharp premultiplied icons)
  ImageList1 := TImageList.Create(Self);
  ImageList1.Width := 19;
  ImageList1.Height := 19;
  LoadDesignerImageList(ImageList1);

  // 2. Toolbar: the buttons and groups of the VCL toolbar (rpmdfmainvcl),
  // AI chat at the end (BuildVCLMenus). It takes the height of its rows:
  // a narrow window wraps it instead of hiding the last buttons. Page
  // setup, parameters, the wizard, select all and front/back are in the
  // menus (and front/back in the object inspector and the context menu).
  MainToolBar := TToolBar.Create(Self);
  MainToolBar.Parent := Self;
  MainToolBar.Align := alTop;
  MainToolBar.ButtonWidth := Scale96ToScreen(26);
  MainToolBar.ButtonHeight := Scale96ToScreen(26);
  MainToolBar.AutoSize := True;
  MainToolBar.Flat := True;
  MainToolBar.ShowHint := True;
  MainToolBar.Images := ImageList1;

  BtnNew := NewToolButton(IMG_NEW,
    TranslateStr(41, 'Creates a new report') + ' (Ctrl+N)', BtnNewClick);
  BtnOpen := NewToolButton(IMG_OPEN,
    TranslateStr(43, 'Opens an existing report'), BtnOpenClick);
  Sep1 := NewToolSeparator;
  BtnSave := NewToolButton(IMG_SAVE,
    TranslateStr(47, 'Saves the current report'), BtnSaveClick);
  BtnDataConfig := NewToolButton(IMG_DATACONFIG,
    TranslateStr(132, 'Modifies data access information'), BtnDataConfigClick);
  Sep2 := NewToolSeparator;
  BtnPrint := NewToolButton(IMG_PRINT,
    TranslateStr(53, 'Print the report, you can select pages to print'), BtnPrintClick);
  BtnPreview := NewToolButton(IMG_PREVIEW,
    TranslateStr(55, 'Preview the report in the screen'), BtnPreviewClick);
  BtnUndo := NewToolButton(IMG_UNDO, TranslateStr(1481, 'Undo') + ' (Ctrl+Z)', BtnUndoClick);
  BtnRedo := NewToolButton(IMG_REDO, TranslateStr(1482, 'Redo') + ' (Ctrl+Y)', BtnRedoClick);
  Sep3 := NewToolSeparator;

  // Insertion tools: one of them is down
  BtnToolArrow := NewToolButton(IMG_ARROW, TranslateStr(81, 'Select objects'), BtnToolClick);
  BtnToolLabel := NewToolButton(IMG_LABEL, TranslateStr(82, 'Inserts a static text'),
    BtnToolClick);
  BtnToolExpr := NewToolButton(IMG_EXPRESSION, TranslateStr(83, 'Inserts a expression'),
    BtnToolClick);
  BtnToolShape := NewToolButton(IMG_SHAPE, TranslateStr(84, 'Inserts a simple drawing'),
    BtnToolClick);
  BtnToolImage := NewToolButton(IMG_IMAGE, TranslateStr(85, 'Inserts a image'), BtnToolClick);
  BtnToolChart := NewToolButton(IMG_CHART, TranslateStr(87, 'Inserts a chart'), BtnToolClick);
  BtnToolBarcode := NewToolButton(IMG_BARCODE, TranslateStr(86, 'Inserts a barcode'),
    BtnToolClick);
  BtnToolArrow.Grouped := True;
  BtnToolArrow.Style := tbsCheck;
  BtnToolLabel.Grouped := True;
  BtnToolLabel.Style := tbsCheck;
  BtnToolExpr.Grouped := True;
  BtnToolExpr.Style := tbsCheck;
  BtnToolShape.Grouped := True;
  BtnToolShape.Style := tbsCheck;
  BtnToolImage.Grouped := True;
  BtnToolImage.Style := tbsCheck;
  BtnToolChart.Grouped := True;
  BtnToolChart.Style := tbsCheck;
  BtnToolBarcode.Grouped := True;
  BtnToolBarcode.Style := tbsCheck;
  BtnToolArrow.Down := True;
  Sep4 := NewToolSeparator;

  ComboScale := TComboBox.Create(MainToolBar);
  ComboScale.Parent := MainToolBar;
  ComboScale.Style := csDropDownList;
  ComboScale.Width := Scale96ToScreen(75);
  ComboScale.Items.Add('25%');
  ComboScale.Items.Add('50%');
  ComboScale.Items.Add('75%');
  ComboScale.Items.Add('100%');
  ComboScale.Items.Add('125%');
  ComboScale.Items.Add('150%');
  ComboScale.Items.Add('200%');
  // Up to 400% as the VCL designer
  ComboScale.Items.Add('300%');
  ComboScale.Items.Add('400%');
  ComboScale.ItemIndex := 3;
  ComboScale.OnChange := ComboScaleChange;

  BtnDelete := NewToolButton(IMG_DELETE, TranslateStr(1106, 'Delete selected object'),
    BtnDeleteClick);
  BtnCut := NewToolButton(IMG_CUT, TranslateStr(12, 'Cut selected object'), BtnCutClick);
  BtnCopy := NewToolButton(IMG_COPY, TranslateStr(13, 'Copy selected object to clipboard'),
    BtnCopyClick);
  BtnPaste := NewToolButton(IMG_PASTE, TranslateStr(14, 'Paste from clipboard'), BtnPasteClick);
  Sep5 := NewToolSeparator;

  BtnNudgeLeft := NewToolButton(IMG_NAV_LEFT,
    TranslateStr(24, 'Moves the selection to the left'), BtnNudgeLeftClick);
  BtnNudgeRight := NewToolButton(IMG_NAV_RIGHT,
    TranslateStr(26, 'Moves the selection to the right'), BtnNudgeRightClick);
  BtnNudgeUp := NewToolButton(IMG_NAV_UP, TranslateStr(28, 'Moves the selection up'),
    BtnNudgeUpClick);
  BtnNudgeDown := NewToolButton(IMG_NAV_DOWN, TranslateStr(30, 'Moves the selection down'),
    BtnNudgeDownClick);
  Sep6 := NewToolSeparator;

  BtnAlignLeft := NewToolButton(IMG_ALIGN_LEFT,
    TranslateStr(32, 'Aligns selection to the left'), BtnAlignLeftClick);
  BtnAlignRight := NewToolButton(IMG_ALIGN_RIGHT,
    TranslateStr(33, 'Aligns selection to the right'), BtnAlignRightClick);
  BtnAlignUp := NewToolButton(IMG_ALIGN_TOP, TranslateStr(34, 'Aligns selection up'),
    BtnAlignUpClick);
  BtnAlignDown := NewToolButton(IMG_ALIGN_BOTTOM, TranslateStr(35, 'Aligns selection down'),
    BtnAlignDownClick);
  BtnAlignHorz := NewToolButton(IMG_SPACE_HORZ,
    TranslateStr(39, 'Aligns selection distributing horizontal space'), BtnAlignHorzClick);
  BtnAlignVert := NewToolButton(IMG_SPACE_VERT,
    TranslateStr(37, 'Aligns selection distributing vertical space'), BtnAlignVertClick);
  // AChatIA: shows or hides the AI panel (View > AI chat)
  BtnAIChat := NewToolButton(IMG_CHAT_IA,
    TranslateStr(1551, 'Show or hide the AI chat panel'), MenuViewAIChatClick);
  BtnAIChat.Style := tbsCheck;
  BtnAIChat.Down := True;

  // 3. StatusBar
  StatusBar := TStatusBar.Create(Self);
  StatusBar.Parent := Self;
  StatusBar.SimplePanel := True;

  // 4. Left Panel (Structure + Inspector)
  PLeft := TPanel.Create(Self);
  PLeft.Parent := Self;
  PLeft.Align := alLeft;
  PLeft.Width := Scale96ToScreen(235);
  PLeft.BevelOuter := bvNone;

  FStructure := TFRpStructureLCL.Create(Self);
  FStructure.Parent := PLeft;
  FStructure.Align := alTop;
  FStructure.Height := Scale96ToScreen(280);

  SplitterStruct := TSplitter.Create(PLeft);
  SplitterStruct.Parent := PLeft;
  SplitterStruct.Align := alTop;
  SplitterStruct.Height := Scale96ToScreen(5);

  FObjInsp := TFRpObjInspLCL.Create(Self);
  FObjInsp.Parent := PLeft;
  FObjInsp.Align := alClient;

  // Connect structure and object inspector
  FStructure.ObjInsp := FObjInsp;

  // 5. Main Splitter
  SplitterMain := TSplitter.Create(Self);
  SplitterMain.Parent := Self;
  SplitterMain.Align := alLeft;
  SplitterMain.Width := Scale96ToScreen(5);

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
  SplitterAI.SetBounds(19000, 0, Scale96ToScreen(5), 100);
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
  // Its MyBase files with a relative name are next to it
  if AFileName <> '' then
    RpReportFolder := ExtractFilePath(ExpandFileName(AFileName));
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
  if Assigned(BtnAIChat) then
    BtnAIChat.Down := Value;
  ApplyChatPanelVisibility;
  SaveDesignerPreferences;
end;

procedure TFRpMainFLCL.LoadDesignerPreferences;
var
  inif: TIniFile;
begin
  // The preferences of the VCL designer (same file and keys, VCL LoadConfig)
  try
    inif := TIniFile.Create(DesignerConfigFileName);
    try
      MenuViewAIChat.Checked := inif.ReadBool('Preferences', 'ShowAIChat', True);
      MenuViewUnitsCm.Checked := inif.ReadBool('Preferences', 'UnitCms', True);
      MenuViewUnitsInches.Checked := not MenuViewUnitsCm.Checked;
      MenuPrefStatusBar.Checked := inif.ReadBool('Preferences', 'StatusBar', True);
      MenuPrefTypeInfo.Checked := inif.ReadBool('Preferences', 'TypeInfo', True);
      MenuPrefPrintDialog.Checked := inif.ReadBool('Preferences', 'ShowPrintDialog', True);
      // Own keys: the font of the VCL inspector may not suit the LCL one
      FObjFontName := inif.ReadString('Preferences', 'ObjFontNameLCL', '');
      FObjFontSize := inif.ReadInteger('Preferences', 'ObjFontSizeLCL', 8);
      FObjFontColor := inif.ReadInteger('Preferences', 'ObjFontColorLCL', clWindowText);
      FObjFontStyle := inif.ReadInteger('Preferences', 'ObjFontStyleLCL', 0);
    finally
      inif.Free;
    end;
    FLastUsedFiles.LoadFromConfigFile(DesignerConfigFileName);
  except
    // An unreadable preferences file keeps the defaults
  end;
  BtnAIChat.Down := MenuViewAIChat.Checked;
  StatusBar.Visible := MenuPrefStatusBar.Checked;
  if Assigned(FStructure) and Assigned(FStructure.browser) then
    FStructure.browser.ShowDataTypes := MenuPrefTypeInfo.Checked;
  ApplyObjInspFont;
  if not MenuViewUnitsCm.Checked then
    ApplyUnits;
  UpdateFileMenu;
end;

procedure TFRpMainFLCL.SaveDesignerPreferences;
var
  inif: TIniFile;
begin
  try
    inif := TIniFile.Create(DesignerConfigFileName);
    try
      inif.WriteBool('Preferences', 'ShowAIChat', MenuViewAIChat.Checked);
      inif.WriteBool('Preferences', 'UnitCms', MenuViewUnitsCm.Checked);
      inif.WriteBool('Preferences', 'StatusBar', MenuPrefStatusBar.Checked);
      inif.WriteBool('Preferences', 'TypeInfo', MenuPrefTypeInfo.Checked);
      inif.WriteBool('Preferences', 'ShowPrintDialog', MenuPrefPrintDialog.Checked);
      if FObjFontName <> '' then
      begin
        inif.WriteString('Preferences', 'ObjFontNameLCL', FObjFontName);
        inif.WriteInteger('Preferences', 'ObjFontSizeLCL', FObjFontSize);
        inif.WriteInteger('Preferences', 'ObjFontColorLCL', FObjFontColor);
        inif.WriteInteger('Preferences', 'ObjFontStyleLCL', FObjFontStyle);
      end;
      inif.UpdateFile;
    finally
      inif.Free;
    end;
    FLastUsedFiles.SaveToConfigFile(DesignerConfigFileName);
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
  UpdateDesignChatLocalSchemas;
  FChatFrame.SetHubContext(LHubDatabaseId, LHubSchemaId, LSchemaApiKey);
  // The AI panel is optional: hidden, it makes no Hub request until shown
  if PAIPanel.Visible then
    FChatFrame.StartOnlineInitialization
  else
    FChatOnlinePending := True;
end;

procedure TFRpMainFLCL.UpdateDesignChatLocalSchemas;
var
  I, J: Integer;
  LDatabase: TRpDatabaseInfoItem;
  LEntries, LNames: TStringList;
  LPreferred: string;
begin
  if not Assigned(FChatFrame) then
    Exit;
  LEntries := TStringList.Create;
  LNames := TStringList.Create;
  try
    LPreferred := '';
    if Assigned(FReport) then
    begin
      for I := 0 to FReport.DatabaseInfo.Count - 1 do
      begin
        LDatabase := FReport.DatabaseInfo.Items[I];
        if not RpIsLocalSqlDatabase(LDatabase) then
          Continue;
        LEntries.Add(LDatabase.Alias + '=');
        try
          RpListLocalSubSchemas(LDatabase, LNames);
        except
          LNames.Clear;
        end;
        for J := 0 to LNames.Count - 1 do
          LEntries.Add(LDatabase.Alias + '=' + LNames[J]);
        if LPreferred = '' then
          LPreferred := LDatabase.Alias;
      end;
      // The connection of the first dataset, when it is a direct one
      if FReport.DataInfo.Count > 0 then
      begin
        LDatabase := FindDatabaseInfo(FReport, FReport.DataInfo.Items[0].DatabaseAlias);
        if RpIsLocalSqlDatabase(LDatabase) then
          LPreferred := LDatabase.Alias;
      end;
    end;
    FChatFrame.SetLocalSchemas(LEntries, LPreferred);
  finally
    LNames.Free;
    LEntries.Free;
  end;
end;

procedure TFRpMainFLCL.ConfigureDesignChatLocalSchemas(Sender: TObject;
  const AAlias, ASchemaName: string);
var
  LSchemaName: string;
begin
  if not Assigned(FReport) then
    Exit;
  LSchemaName := ASchemaName;
  try
    RpShowLocalSchemasDialog(FReport, AAlias, LSchemaName);
  finally
    UpdateDesignChatLocalSchemas;
  end;
  FChatFrame.SelectLocalSchema(AAlias, LSchemaName);
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
  FChatFrame.OnConfigureLocalSchemas := ConfigureDesignChatLocalSchemas;
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
    // A direct connection: its local schema travels inline and the SQL of
    // the assistant runs here (rpdesignerclientsql, in the chat worker)
    if (Result.Config.HubDatabaseId = 0) and (Result.Config.HubSchemaId = 0) then
    begin
      Result.Config.LocalAlias := FChatFrame.GetLocalSchemaAlias;
      Result.Config.LocalSchemaName := FChatFrame.GetLocalSchemaName;
    end;
    TRpAuthManager.Instance.Log(
      'Main BuildDesignChatRequest: HubDatabaseId=' + IntToStr(Result.Config.HubDatabaseId) +
      ' HubSchemaId=' + IntToStr(Result.Config.HubSchemaId) +
      ' LocalAlias=' + Result.Config.LocalAlias +
      ' SchemaApiKey=' + RpMaskSecret(Result.ApiKey));
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
  // The Hub adds the Agent connections by name only: without an entry in
  // the connections file the data could not be opened
  if Assigned(FChatFrame) and
    (RpEnsureAgentConnections(FReport.DatabaseInfo, FChatFrame.GetHubDatabaseId,
      FChatFrame.GetSchemaApiKey) > 0) then
    TRpAuthManager.Instance.Log(
      'Design chat: Reportman AI Agent connections written to the connections file');
  UpdateDesignChatLocalSchemas;
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
  MenuFileLibraries.Visible := not Value;
  MenuFileLibraries.Enabled := not Value;
  MenuFileSave.Visible := not Value;
  MenuFileSave.Enabled := not Value;
  MenuFileSaveAs.Visible := not Value;
  MenuFileSaveAs.Enabled := not Value;
  BtnNew.Visible := not Value;
  BtnOpen.Visible := not Value;
  BtnSave.Visible := not Value;
  // No recent files either: the host decides what is edited
  UpdateFileMenu;
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
    configfilelib := LibraryConfigFileName;
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
  UseFile(AFileName);
end;

procedure TFRpMainFLCL.OpenReportFromLibrary(const ALibrary: string;
  const AReportName: WideString);
var
  astream: TStream;
begin
  // The caller is responsible of CheckSave (VCL DoOpenFromLib)
  try
    astream := GetLibraryConnections.GetReportStream(ALibrary, AReportName, nil);
  finally
    // Releases the locks of the read
    CommitLibraryConnection(GetLibraryConnections, ALibrary);
  end;
  try
    OpenReportStream(astream);
  finally
    astream.Free;
  end;
  FLibraryName := ALibrary;
  FLibraryReportName := AReportName;
  UpdateStatus;
  UseFile(ALibrary + '->' + AReportName);
end;

procedure TFRpMainFLCL.SaveReportFile(const AFileName: string);
begin
  if not Assigned(FReport) then Exit;
  FReport.SaveToFile(AFileName);
  FFileName := AFileName;
  RpReportFolder := ExtractFilePath(ExpandFileName(AFileName));
  FLibraryName := '';
  FLibraryReportName := '';
  // MarkClean also resets Report.Modified
  GetUndoCue.MarkClean;
  UpdateStatus;
  UseFile(AFileName);
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
    try
      GetLibraryConnections.SaveReportStream(FLibraryName, FLibraryReportName, astream, nil);
    finally
      // SaveReportStream does not commit the SQLdb connections of the FPC
      // build: without this the report is lost when the connection closes
      CommitLibraryConnection(GetLibraryConnections, FLibraryName);
    end;
  finally
    astream.Free;
  end;
  GetUndoCue.MarkClean;
  UpdateStatus;
  UseFile(FLibraryName + '->' + FLibraryReportName);
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

function TFRpMainFLCL.NewReportFromWizard: Boolean;
var
  newRep: TRpReport;
  LPendingPrompt: string;
  LHubDatabaseId, LHubSchemaId: Int64;
  LHubApiKey: string;
  accepted: Boolean;
begin
  // rpmdfmainvcl ANewExecute. The current report stays when the wizard is
  // canceled (the VCL designer is left without a report)
  Result := False;
  if not CheckSave then
    Exit;
  newRep := CreateDesignReport;
  try
    accepted := NewModernReportWizard(newRep, LPendingPrompt, LHubDatabaseId,
      LHubSchemaId, LHubApiKey);
  except
    newRep.Free;
    raise;
  end;
  if not accepted then
  begin
    newRep.Free;
    Exit;
  end;
  InstallReport(newRep, '', False);
  Result := True;
  if not Assigned(FChatFrame) then
    Exit;
  // The Hub database, schema and API key chosen in the wizard
  UpdateDesignChatLocalSchemas;
  FChatFrame.SetHubContext(LHubDatabaseId, LHubSchemaId, LHubApiKey);
  // A prompt for the assistant shows the AI panel (the saved View > AI chat
  // preference does not change)
  if (Trim(LPendingPrompt) <> '') and (not PAIPanel.Visible) then
  begin
    MenuViewAIChat.Checked := True;
    ApplyChatPanelVisibility;
  end;
  if PAIPanel.Visible then
  begin
    FChatOnlinePending := False;
    FChatFrame.StartOnlineInitialization;
  end
  else
    FChatOnlinePending := True;
  if Trim(LPendingPrompt) <> '' then
  begin
    // The prompt of the wizard in the conversation (the VCL sends it without
    // showing it)
    FChatFrame.AddUserMessage(Trim(LPendingPrompt));
    BeginDesignChatContextRefresh(Trim(LPendingPrompt), False);
  end;
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
  if RpDesignerLCLNewReportWizard then
    NewReportFromWizard
  else
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

procedure TFRpMainFLCL.MenuFileLibConfigClick(Sender: TObject);
begin
  ConfigureLibraries;
end;

procedure TFRpMainFLCL.MenuFileSaveLibClick(Sender: TObject);
begin
  SaveToLibraryAs;
end;

procedure TFRpMainFLCL.ConfigureLibraries;
begin
  // VCL ALibrariesExecute (ShowModifyConnections, then SaveConfig)
  if ShowModifyConnections(GetLibraryConnections) then
    GetLibraryConnections.SaveToFile(LibraryConfigFileName);
end;

procedure TFRpMainFLCL.SaveToLibraryAs;
var
  alibname: string;
  arepname: WideString;
begin
  if FHostedMode then
    Exit;
  // VCL ASaveToExecute: the report is selected (or created with New report)
  // in the library dialog
  alibname := FLibraryName;
  arepname := SelectReportFromLibrary(GetLibraryConnections, alibname);
  if Length(arepname) < 1 then
    Exit;
  SaveReportToLibrary(alibname, arepname);
end;

procedure TFRpMainFLCL.SaveReportToLibrary(const ALibrary: string;
  const AReportName: WideString);
var
  oldlibname, oldfilename: string;
  oldrepname: WideString;
begin
  if not Assigned(FReport) then Exit;
  oldlibname := FLibraryName;
  oldrepname := FLibraryReportName;
  oldfilename := FFileName;
  try
    FFileName := '';
    FLibraryName := ALibrary;
    FLibraryReportName := AReportName;
    SaveToLibrary;
  except
    FLibraryName := oldlibname;
    FLibraryReportName := oldrepname;
    FFileName := oldfilename;
    UpdateStatus;
    raise;
  end;
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
    // The connections may have changed: the local ones of the design chat
    UpdateDesignChatLocalSchemas;
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
  // Report properties changed by the page setup dialog (rppagesetuplcl).
  // The embedded files are not in the undo history (see BtnPageSetupClick).
  PAGESETUP_PROPS: array[0..39] of TRpPageSetupProp = (
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
    (Name: 'ForcePaperName'; PropType: ptString),
    (Name: 'PDFConformance'; PropType: ptInteger),
    (Name: 'PDFCompressed'; PropType: ptBoolean),
    (Name: 'DocAuthor'; PropType: ptString),
    (Name: 'DocTitle'; PropType: ptString),
    (Name: 'DocSubject'; PropType: ptString),
    (Name: 'DocKeywords'; PropType: ptString),
    (Name: 'DocCreator'; PropType: ptString),
    (Name: 'DocProducer'; PropType: ptString),
    (Name: 'DocCreationDate'; PropType: ptString),
    (Name: 'DocModificationDate'; PropType: ptString),
    (Name: 'DocXMPContent'; PropType: ptString)
  );

// Name, type, description, relationship, dates and content (MD5) of the
// embedded files: tells whether the page setup changed them
function EmbeddedFilesSignature(AReport: TRpBaseReport): string;
var
  i: Integer;
  efile: TEmbeddedFile;
  digest: string;
begin
  Result := IntToStr(Length(AReport.EmbeddedFiles));
  for i := 0 to Length(AReport.EmbeddedFiles) - 1 do
  begin
    efile := AReport.EmbeddedFiles[i];
    digest := '';
    if Assigned(efile.Stream) and (efile.Stream.Size > 0) then
      digest := MD5Print(MD5Buffer(efile.Stream.Memory^, efile.Stream.Size));
    Result := Result + #1 + efile.FileName + #2 + efile.MimeType + #2 +
      efile.Description + #2 + IntToStr(Ord(efile.AFRelationShip)) + #2 +
      efile.CreationDate + #2 + efile.ModificationDate + #2 + digest;
  end;
end;

procedure TFRpMainFLCL.BtnPageSetupClick(Sender: TObject);
var
  snapshot: array[0..High(PAGESETUP_PROPS)] of Variant;
  i: Integer;
  newValue: Variant;
  cue: TUndoCue;
  op: TChangeObjectOperation;
  oldFiles: string;
begin
  if not Assigned(FReport) then Exit;
  FReport.AssertCanModify('Page setup');
  for i := 0 to High(PAGESETUP_PROPS) do
    snapshot[i] := FReport.GetItemProperty(PAGESETUP_PROPS[i].Name);
  oldFiles := EmbeddedFilesSignature(FReport);
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
    // The files embedded in the PDF are not recorded (the Delphi and C#
    // undo engines have no such property, and the history travels with the
    // design requests): the report is marked modified, as the VCL does
    if EmbeddedFilesSignature(FReport) <> oldFiles then
      cue.MarkExternalChange;
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
  if Assigned(FReport) and not CheckAgentConnections then
    Exit;
  try
    PrintCurrentReport;
  except
    on E: EAbort do
      raise;
    on E: Exception do
      ShowReportError(E);
  end;
end;

procedure TFRpMainFLCL.BtnPreviewClick(Sender: TObject);
var
  previewCtrl: TRpPreviewControl;
begin
  if not Assigned(FReport) then Exit;
  if not CheckAgentConnections then
    Exit;
  try
    previewCtrl := TRpPreviewControl.Create(nil);
    try
      previewCtrl.Report := FReport;
      rplclpreview.ShowPreview(previewCtrl, TranslateStr(54, 'Preview') + ' - ' + Caption);
    finally
      previewCtrl.Free;
    end;
  except
    on E: EAbort do
      raise;
    on E: Exception do
      ShowReportError(E);
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
  end
  // Ctrl+arrows move the selection (VCL ALeft/ARight/AUp/ADown shortcuts);
  // in a text box they keep moving by words
  else if (Shift = [ssCtrl]) and ((Key = VK_LEFT) or (Key = VK_RIGHT) or
    (Key = VK_UP) or (Key = VK_DOWN)) and
    not IsEditableTextShortcutTarget(ActiveControl) and SelectedSizePosItems then
  begin
    case Key of
      VK_LEFT: FObjInsp.MoveSelected(1, False);
      VK_RIGHT: FObjInsp.MoveSelected(2, False);
      VK_UP: FObjInsp.MoveSelected(3, False);
      VK_DOWN: FObjInsp.MoveSelected(4, False);
    end;
    Key := 0;
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
  MenuViewUnitsCm.Checked := TMenuItem(Sender).Tag = 0;
  MenuViewUnitsInches.Checked := not MenuViewUnitsCm.Checked;
  ApplyUnits;
  // Saved as the VCL UnitCms preference
  SaveDesignerPreferences;
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

{ Menus of the VCL designer (rpmdfmainvcl.dfm) that the LCL one did not have }

function TFRpMainFLCL.NewMenuItem(AParent: TMenuItem; const ACaption,
  AHint: string; AOnClick: TNotifyEvent): TMenuItem;
begin
  Result := TMenuItem.Create(AParent);
  Result.Caption := ACaption;
  Result.Hint := AHint;
  Result.OnClick := AOnClick;
end;

procedure TFRpMainFLCL.BuildVCLMenus;
var
  item, sep: TMenuItem;
begin
  // File > Printer setup..., after Print
  MenuFilePrintSetup := NewMenuItem(MenuFile, TranslateStr(56, 'Printer setup...'),
    TranslateStr(57, 'Displays printer setup dialog'), MenuFilePrintSetupClick);
  MenuFile.Insert(MenuFilePrint.MenuIndex + 1, MenuFilePrintSetup);

  // Edit > Select all text, Move, Align, Hide, Show all, Align height 1/n
  MenuEditSelectAllText := NewMenuItem(MenuEdit, TranslateStr(117, 'All text'),
    TranslateStr(118, 'Selects all text components'), MenuEditSelectAllTextClick);
  MenuEdit.Insert(MenuEditSelectAll.MenuIndex + 1, MenuEditSelectAllText);

  sep := TMenuItem.Create(MenuEdit);
  sep.Caption := '-';
  MenuEdit.Add(sep);

  // The arrow keys with Ctrl move the selection (FormKeyDown), as the VCL
  MenuEditMove := NewMenuItem(MenuEdit, TranslateStr(22, 'Move'), '', nil);
  MenuEdit.Add(MenuEditMove);
  MenuEditMove.Add(NewMenuItem(MenuEditMove, TranslateStr(23, 'Left') + #9'Ctrl+Left',
    TranslateStr(24, 'Moves the selection to the left'), BtnNudgeLeftClick));
  MenuEditMove.Add(NewMenuItem(MenuEditMove, TranslateStr(25, 'Right') + #9'Ctrl+Right',
    TranslateStr(26, 'Moves the selection to the right'), BtnNudgeRightClick));
  MenuEditMove.Add(NewMenuItem(MenuEditMove, TranslateStr(27, 'Up') + #9'Ctrl+Up',
    TranslateStr(28, 'Moves the selection up'), BtnNudgeUpClick));
  MenuEditMove.Add(NewMenuItem(MenuEditMove, TranslateStr(29, 'Down') + #9'Ctrl+Down',
    TranslateStr(30, 'Moves the selection down'), BtnNudgeDownClick));

  MenuEditAlign := NewMenuItem(MenuEdit, TranslateStr(31, 'Align'), '', nil);
  MenuEdit.Add(MenuEditAlign);
  MenuEditAlign.Add(NewMenuItem(MenuEditAlign, TranslateStr(23, 'Left'),
    TranslateStr(32, 'Aligns selection to the left'), BtnAlignLeftClick));
  MenuEditAlign.Add(NewMenuItem(MenuEditAlign, TranslateStr(25, 'Right'),
    TranslateStr(33, 'Aligns selection to the right'), BtnAlignRightClick));
  MenuEditAlign.Add(NewMenuItem(MenuEditAlign, TranslateStr(27, 'Up'),
    TranslateStr(34, 'Aligns selection up'), BtnAlignUpClick));
  MenuEditAlign.Add(NewMenuItem(MenuEditAlign, TranslateStr(29, 'Down'),
    TranslateStr(35, 'Aligns selection down'), BtnAlignDownClick));
  MenuEditAlign.Add(NewMenuItem(MenuEditAlign, TranslateStr(38, 'Horizontal space'),
    TranslateStr(39, 'Aligns selection distributing horizontal space'), BtnAlignHorzClick));
  MenuEditAlign.Add(NewMenuItem(MenuEditAlign, TranslateStr(36, 'Vertical space'),
    TranslateStr(37, 'Aligns selection distributing vertical space'), BtnAlignVertClick));

  sep := TMenuItem.Create(MenuEdit);
  sep.Caption := '-';
  MenuEdit.Add(sep);

  MenuEditHide := NewMenuItem(MenuEdit, TranslateStr(15, 'Hide'),
    TranslateStr(16, 'Hide selected objects'), MenuEditHideClick);
  MenuEdit.Add(MenuEditHide);
  MenuEditShowAll := NewMenuItem(MenuEdit, TranslateStr(17, 'Show all'),
    TranslateStr(18, 'Shows all the hiden components'), MenuEditShowAllClick);
  MenuEdit.Add(MenuEditShowAll);

  sep := TMenuItem.Create(MenuEdit);
  sep.Caption := '-';
  MenuEdit.Add(sep);

  MenuEditAlign1_6 := NewMenuItem(MenuEdit, TranslateStr(1059, 'Adjust height to 1/n inch'),
    TranslateStr(1060, 'Adjust section height to provide compatibility with dot matrix printers'),
    MenuEditAlign1_6Click);
  MenuEdit.Add(MenuEditAlign1_6);

  // Report > Add (sections and subreports) and Delete section/subreport, as
  // the structure frame buttons
  MenuReportAdd := NewMenuItem(MenuReport, TranslateStr(149, 'Add'), '', nil);
  MenuReport.Insert(0, MenuReportAdd);
  item := NewMenuItem(MenuReportAdd, TranslateStr(119, 'Page header'),
    TranslateStr(120, 'Inserts a page header in the selected subreport'), MenuReportAddClick);
  item.Tag := 1;
  MenuReportAdd.Add(item);
  item := NewMenuItem(MenuReportAdd, TranslateStr(121, 'Page footer'),
    TranslateStr(122, 'Inserts a page footer in the selected subreport'), MenuReportAddClick);
  item.Tag := 2;
  MenuReportAdd.Add(item);
  item := NewMenuItem(MenuReportAdd, TranslateStr(123, 'Group header and footer'),
    TranslateStr(124, 'Insert a group header an footer'), MenuReportAddClick);
  item.Tag := 3;
  MenuReportAdd.Add(item);
  item := NewMenuItem(MenuReportAdd, TranslateStr(125, 'Subreport'),
    TranslateStr(126, 'Insert a new subreport'), MenuReportAddClick);
  item.Tag := 4;
  MenuReportAdd.Add(item);
  item := NewMenuItem(MenuReportAdd, TranslateStr(129, 'Detail'),
    TranslateStr(130, 'Inserts a detail section in the selected subreport'), MenuReportAddClick);
  item.Tag := 5;
  MenuReportAdd.Add(item);
  MenuReportDeleteSection := NewMenuItem(MenuReport,
    TranslateStr(127, 'Delete section/subreport'),
    TranslateStr(128, 'Deletes the selected subreport or section'), MenuReportDeleteSectionClick);
  MenuReport.Add(MenuReportDeleteSection);

  // Preferences, after View
  MenuPreferences := TMenuItem.Create(MainMenu1);
  MenuPreferences.Caption := '&' + TranslateStr(5, 'Preferences');
  MainMenu1.Items.Insert(MenuView.MenuIndex + 1, MenuPreferences);
  MenuPrefStatusBar := NewMenuItem(MenuPreferences, TranslateStr(76, 'Status bar'),
    TranslateStr(77, 'Shows or hides the status bar'), MenuPrefStatusBarClick);
  MenuPrefStatusBar.Checked := True;
  MenuPreferences.Add(MenuPrefStatusBar);
  MenuPrefObjFont := NewMenuItem(MenuPreferences,
    TranslateStr(1348, 'Object inspector Font'), '', MenuPrefObjFontClick);
  MenuPreferences.Add(MenuPrefObjFont);
  MenuPrefTypeInfo := NewMenuItem(MenuPreferences, SRpTypeInfo, '', MenuPrefTypeInfoClick);
  MenuPrefTypeInfo.Checked := True;
  MenuPreferences.Add(MenuPrefTypeInfo);
  MenuPrefPrintDialog := NewMenuItem(MenuPreferences, SRpShowPrintDialog, '',
    MenuPrefPrintDialogClick);
  MenuPrefPrintDialog.Checked := True;
  MenuPreferences.Add(MenuPrefPrintDialog);

  // Help > Documentation, before About
  MenuHelpDoc := NewMenuItem(MenuHelp, TranslateStr(60, 'Documentation'),
    TranslateStr(61, 'Display Report Manager Designer Documentation'), MenuHelpDocClick);
  MenuHelp.Insert(0, MenuHelpDoc);
  // VCL ASysInfo
  MenuHelpSysInfo := NewMenuItem(MenuHelp, SRpSsysInfo, SRpSsysInfoH, MenuHelpSysInfoClick);
  MenuHelp.Insert(1, MenuHelpSysInfo);

  UpdateFileMenu;
end;

procedure TFRpMainFLCL.AppHint(Sender: TObject);
begin
  if csDestroying in ComponentState then
    Exit;
  // The hint while the mouse is over a command, the report state otherwise
  if Application.Hint <> '' then
    StatusBar.SimpleText := GetLongHint(Application.Hint)
  else
    UpdateStatus;
end;

function TFRpMainFLCL.SelectedSizePosItems: Boolean;
begin
  Result := Assigned(FObjInsp) and (FObjInsp.SelectedItems.Count > 0) and
    (FObjInsp.SelectedItems.Objects[0] is TRpSizePosInterface);
end;

procedure TFRpMainFLCL.HideSelection;
var
  i: Integer;
  aint: TRpSizePosInterface;
begin
  // VCL AHideExecute: Visible is a design time flag, not saved nor undone
  if not SelectedSizePosItems then
    Exit;
  for i := 0 to FObjInsp.SelectedItems.Count - 1 do
  begin
    if not (FObjInsp.SelectedItems.Objects[i] is TRpSizePosInterface) then
      Continue;
    aint := TRpSizePosInterface(FObjInsp.SelectedItems.Objects[i]);
    aint.Visible := False;
    aint.printitem.Visible := False;
  end;
  FDesignerFrame.ClearSelection;
end;

procedure TFRpMainFLCL.ShowAllHidden;
begin
  if Assigned(FDesignerFrame) then
  begin
    FDesignerFrame.ShowAllHidden;
    FDesignerFrame.UpdateSelection(False);
  end;
end;

procedure TFRpMainFLCL.SelectAllText;
begin
  // VCL ASelectAllTextExecute: labels and expressions
  if Assigned(FObjInsp) then
    FObjInsp.SelectAllClass('TRpGenTextInterface');
end;

procedure TFRpMainFLCL.AlignSectionsToLines;
var
  sub: TRpSubReport;
  sec: TRpSection;
  i, j, k, gid, oldTop: Integer;
  cue: TUndoCue;
  op: TChangeObjectOperation;
  oldHeights: TList<Integer>;
begin
  // VCL AAlign1_6Execute: the top margin and every section height to a
  // multiple of 1/n inch (n = Report.LinesPerInch), for dot matrix
  // printers. The changes are recorded as one undo step.
  if not Assigned(FReport) then
    Exit;
  FReport.AssertCanModify('Align height 1/n');
  oldTop := FReport.TopMargin;
  oldHeights := TList<Integer>.Create;
  try
    for i := 0 to FReport.SubReports.Count - 1 do
    begin
      sub := FReport.SubReports.Items[i].SubReport;
      for j := 0 to sub.Sections.Count - 1 do
        oldHeights.Add(sub.Sections.Items[j].Section.Height);
    end;
    FReport.AlignSectionsTo(FReport.LinesPerInch);
    cue := GetUndoCue;
    gid := -1;
    if oldTop <> FReport.TopMargin then
    begin
      gid := cue.GetGroupId;
      op := TChangeObjectOperation.Create(otModify, gid);
      op.componentName := 'REPORT';
      op.componentClass := 'TRPREPORT';
      op.parentName := '';
      op.AddProperty('topMargin', ptInteger, oldTop, FReport.TopMargin);
      cue.AddOperation(op);
    end;
    k := 0;
    for i := 0 to FReport.SubReports.Count - 1 do
    begin
      sub := FReport.SubReports.Items[i].SubReport;
      for j := 0 to sub.Sections.Count - 1 do
      begin
        sec := sub.Sections.Items[j].Section;
        if oldHeights[k] <> sec.Height then
        begin
          if gid < 0 then
            gid := cue.GetGroupId;
          op := TChangeObjectOperation.Create(otModify, gid);
          op.componentName := sec.Name;
          op.componentClass := UpperCase(sec.ClassName);
          op.AddProperty('height', ptInteger, oldHeights[k], sec.Height);
          cue.AddOperation(op);
        end;
        Inc(k);
      end;
    end;
  finally
    oldHeights.Free;
  end;
  RefreshInterface;
end;

procedure TFRpMainFLCL.PrintCurrentReport;
var
  allpages, collate, doprint: Boolean;
  frompage, topage, copies: Integer;
  pconfig: TPrinterConfig;
begin
  // VCL APrintExecute: prints with the printer, paper source, duplex and
  // orientation of the report, asking the range first (Preferences > Show
  // print dialog)
  if not Assigned(FReport) then
    Exit;
  allpages := True;
  collate := FReport.CollateCopies;
  frompage := 1;
  topage := MAX_PAGECOUNT;
  copies := FReport.Copies;
  pconfig.Changed := False;
  rplcldriver.PrinterSelection(FReport.PrinterSelect, FReport.PaperSource,
    FReport.Duplex, pconfig);
  rplcldriver.OrientationSelection(FReport.PageOrientation);
  doprint := True;
  if MenuPrefPrintDialog.Checked then
    doprint := rplcldriver.DoShowPrintDialog(allpages, frompage, topage, copies, collate);
  if not doprint then
    Exit;
  FReport.Metafile.BlockPrinterSelection := True;
  try
    rplcldriver.PrintReport(FReport, Caption, True, allpages, frompage, topage,
      copies, collate);
  finally
    FReport.Metafile.BlockPrinterSelection := False;
  end;
end;

function TFRpMainFLCL.SelectReportExceptionSource(E: Exception): Boolean;
var
  compo: TComponent;
  i, j, k: Integer;
  sub: TRpSubReport;
  sec, secsel: TRpSection;
  secint: TRpSectionInterface;
  aint: TRpSizePosInterface;
begin
  // VCL MyExceptionHandler: the subreport, section or item of the error is
  // selected, and the property in the inspector
  Result := False;
  if not ((E is TRpReportException) and Assigned(FReport) and Assigned(FStructure)) then
    Exit;
  compo := TRpReportException(E).Component;
  if not Assigned(compo) then
    Exit;
  if (compo is TRpSubReport) or (compo is TRpSection) then
  begin
    FStructure.SelectDataItem(compo);
    Result := True;
  end
  else if compo is TRpCommonComponent then
  begin
    secsel := nil;
    for i := 0 to FReport.SubReports.Count - 1 do
    begin
      sub := FReport.SubReports.Items[i].SubReport;
      for j := 0 to sub.Sections.Count - 1 do
      begin
        sec := sub.Sections.Items[j].Section;
        for k := 0 to sec.ReportComponents.Count - 1 do
          if sec.ReportComponents.Items[k].Component = compo then
          begin
            secsel := sec;
            Break;
          end;
        if Assigned(secsel) then
          Break;
      end;
      if Assigned(secsel) then
        Break;
    end;
    if not Assigned(secsel) then
      Exit;
    FStructure.SelectDataItem(secsel);
    for i := 0 to FDesignerFrame.secinterfaces.Count - 1 do
    begin
      secint := TRpSectionInterface(FDesignerFrame.secinterfaces[i]);
      if secint.printitem <> secsel then
        Continue;
      for j := 0 to secint.childlist.Count - 1 do
      begin
        aint := TRpSizePosInterface(secint.childlist[j]);
        if aint.printitem = compo then
        begin
          FDesignerFrame.SelectComponent(aint, False);
          Result := True;
          Break;
        end;
      end;
    end;
  end;
  if Result and (TRpReportException(E).PropertyName <> '') then
    FObjInsp.SelectProperty(TRpReportException(E).PropertyName);
end;

procedure TFRpMainFLCL.ShowReportError(E: Exception);
begin
  SelectReportExceptionSource(E);
  RpMessageBox(E.Message, SRpError, [smbOK], smsCritical, smbOK);
end;

function TFRpMainFLCL.HubDatabaseOfSchema(AHubSchemaId: Int64): Int64;
begin
  Result := 0;
  if Assigned(FChatFrame) then
    Result := FChatFrame.HubDatabaseOfSchema(AHubSchemaId);
end;

function TFRpMainFLCL.CheckAgentConnections: Boolean;
begin
  Result := RpCheckAgentConnections(FReport.DatabaseInfo, FReport.DataInfo, nil,
    HubDatabaseOfSchema);
end;

procedure TFRpMainFLCL.UpdateFileMenu;
var
  i, exitindex: Integer;
  alist: TStringList;
  aitem: TMenuItem;
begin
  // VCL UpdateFileMenu: the last used files after File > Exit
  exitindex := MenuFileExit.MenuIndex;
  while MenuFile.Count > exitindex + 1 do
    MenuFile.Items[MenuFile.Count - 1].Free;
  if FHostedMode or (FLastUsedFiles.LastUsed.Count = 0) then
    Exit;
  alist := TStringList.Create;
  try
    FLastUsedFiles.FillWidthShortNames(alist, C_FILENAME_WIDTH);
    aitem := TMenuItem.Create(MenuFile);
    aitem.Caption := '-';
    MenuFile.Add(aitem);
    for i := 0 to alist.Count - 1 do
    begin
      aitem := TMenuItem.Create(MenuFile);
      // '&' would become an accelerator
      aitem.Caption := StringReplace(alist[i], '&', '&&', [rfReplaceAll]);
      aitem.Hint := FLastUsedFiles.LastUsed[i];
      aitem.Tag := i;
      aitem.OnClick := RecentFileClick;
      MenuFile.Add(aitem);
    end;
  finally
    alist.Free;
  end;
end;

procedure TFRpMainFLCL.UseFile(const AName: string);
begin
  if FHostedMode or (AName = '') then
    Exit;
  FLastUsedFiles.UseString(AName);
  UpdateFileMenu;
  SaveDesignerPreferences;
end;

procedure TFRpMainFLCL.RecentFileClick(Sender: TObject);
var
  aname: string;
  apos: Integer;
begin
  // VCL OnFileClick: a file, or library->report
  if TComponent(Sender).Tag >= FLastUsedFiles.LastUsed.Count then
    Exit;
  aname := FLastUsedFiles.LastUsed[TComponent(Sender).Tag];
  if aname = '' then
    Exit;
  apos := Pos('->', aname);
  if apos = 0 then
    OpenReportFile(aname)
  else
  begin
    if not CheckSave then
      Exit;
    OpenReportFromLibrary(Copy(aname, 1, apos - 1),
      Copy(aname, apos + 2, Length(aname)));
  end;
end;

procedure TFRpMainFLCL.ApplyObjInspFont;
begin
  if (FObjFontName = '') or not Assigned(FObjInsp) then
    Exit;
  FObjInsp.Font.Name := FObjFontName;
  FObjInsp.Font.Size := FObjFontSize;
  FObjInsp.Font.Color := FObjFontColor;
  FObjInsp.Font.Style := CLXIntegerToFontStyle(FObjFontStyle);
end;

procedure TFRpMainFLCL.ApplyUnits;
begin
  // VCL UpdateUnits
  if MenuViewUnitsCm.Checked then
  begin
    rpmunits.defaultunit := rpUnitCms;
    FDesignerFrame.TopRuler.Metrics := rCms;
  end
  else
  begin
    rpmunits.defaultunit := rpUnitInchess;
    FDesignerFrame.TopRuler.Metrics := rInchess;
  end;
  if not Assigned(FReport) then
    Exit;
  if Assigned(FObjInsp) then
    FObjInsp.ClearMultiSelect;
  FDesignerFrame.UpdateInterface(True);
  FDesignerFrame.UpdateSelection(True);
end;

procedure TFRpMainFLCL.MenuHelpDocClick(Sender: TObject);
var
  aurl: string;
begin
  // VCL ADocumentationExecute: the doc folder next to the executable or the
  // web site
  aurl := ExtractFilePath(Application.ExeName) + 'doc' + PathDelim + 'index.html';
  if FileExists(aurl) then
    OpenDocument(aurl)
  else
    OpenURL('https://reportman.es');
end;

procedure TFRpMainFLCL.MenuHelpSysInfoClick(Sender: TObject);
begin
  ShowSysInfo;
end;

procedure TFRpMainFLCL.MenuFilePrintSetupClick(Sender: TObject);
var
  psetup: TPrinterSetupDialog;
begin
  psetup := TPrinterSetupDialog.Create(nil);
  try
    psetup.Execute;
  finally
    psetup.Free;
  end;
end;

procedure TFRpMainFLCL.MenuReportAddClick(Sender: TObject);
begin
  if not Assigned(FStructure) then
    Exit;
  case TComponent(Sender).Tag of
    1: FStructure.MNewSectionClick(FStructure.MPHeader);
    2: FStructure.MNewSectionClick(FStructure.MPFooter);
    3: FStructure.MNewSectionClick(FStructure.MGHeader);
    4: FStructure.MNewSectionClick(FStructure.MSubReport);
    5: FStructure.MNewSectionClick(FStructure.MDetail);
  end;
  UpdateStatus;
end;

procedure TFRpMainFLCL.MenuReportDeleteSectionClick(Sender: TObject);
begin
  if Assigned(FStructure) then
    FStructure.BDeleteClick(Sender);
  UpdateStatus;
end;

procedure TFRpMainFLCL.MenuEditSelectAllTextClick(Sender: TObject);
begin
  SelectAllText;
end;

procedure TFRpMainFLCL.MenuEditHideClick(Sender: TObject);
begin
  HideSelection;
end;

procedure TFRpMainFLCL.MenuEditShowAllClick(Sender: TObject);
begin
  ShowAllHidden;
end;

procedure TFRpMainFLCL.MenuEditAlign1_6Click(Sender: TObject);
begin
  AlignSectionsToLines;
end;

procedure TFRpMainFLCL.MenuPrefStatusBarClick(Sender: TObject);
begin
  MenuPrefStatusBar.Checked := not MenuPrefStatusBar.Checked;
  StatusBar.Visible := MenuPrefStatusBar.Checked;
  SaveDesignerPreferences;
end;

procedure TFRpMainFLCL.MenuPrefObjFontClick(Sender: TObject);
var
  dia: TFontDialog;
begin
  dia := TFontDialog.Create(nil);
  try
    dia.Font.Assign(FObjInsp.Font);
    if dia.Execute then
    begin
      FObjFontName := dia.Font.Name;
      FObjFontSize := dia.Font.Size;
      if FObjFontSize < 3 then
        FObjFontSize := 8;
      FObjFontColor := dia.Font.Color;
      FObjFontStyle := FontStyleToCLXInteger(dia.Font.Style);
      ApplyObjInspFont;
      SaveDesignerPreferences;
    end;
  finally
    dia.Free;
  end;
end;

procedure TFRpMainFLCL.MenuPrefTypeInfoClick(Sender: TObject);
begin
  MenuPrefTypeInfo.Checked := not MenuPrefTypeInfo.Checked;
  if Assigned(FStructure) and Assigned(FStructure.browser) then
    FStructure.browser.ShowDataTypes := MenuPrefTypeInfo.Checked;
  SaveDesignerPreferences;
end;

procedure TFRpMainFLCL.MenuPrefPrintDialogClick(Sender: TObject);
begin
  MenuPrefPrintDialog.Checked := not MenuPrefPrintDialog.Checked;
  SaveDesignerPreferences;
end;

end.
