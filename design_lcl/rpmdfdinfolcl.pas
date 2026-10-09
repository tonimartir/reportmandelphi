{*******************************************************}
{                                                       }
{       Report Manager Designer - LCL                   }
{                                                       }
{       rpmdfdinfolcl                                   }
{       Database connections and datasets configuration }
{                                                       }
{*******************************************************}

unit rpmdfdinfolcl;

{$mode delphi}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, Dialogs, Menus,
  StdCtrls, ExtCtrls, ComCtrls, Buttons, Variants, DB,
  rpreport, rpdatainfo, rpparams, rpmdconsts, rptypes, rpbasereport, rpxmlstream,
  rpfrmmonacoeditorlcl, rpmdimageslcl, rpmdundocuelcl, rpmdfparamslcl,
  rpgraphutilslcl, rpaithreadslcl, rpfrmchatlcl;

type
  // "Show data": ADataset is the open dataset (nil and AError on failure)
  TRpShowDatasetEvent = procedure(Sender: TObject; ADataset: TDataset;
    const AError: string) of object;

  { TFRpDInfoLCL }

  // The dialog edits working copies of the report connections, datasets and
  // parameters (held by FWork). The report is only modified when OK is
  // pressed: the differences are recorded in the undo cue and then applied,
  // Cancel discards everything (same model as rpmdfdinfovcl).
  //
  // SQL assistant (Phase 7.3, port of TFRpDatasetsVCL): the chat at the right
  // of the SQL editor writes or refines the query of the dataset
  // (TranslateToSql, streamed), Apply puts it in the editor and in the working
  // copy (so OK records it in the undo cue), and the Audit page of the editor
  // explains the SQL (ExplainSql). Both use the Hub database and schema of the
  // dataset connection, kept in the dataset (HubSchemaId) as in the VCL.
  //
  // Data access (Phase 8, port of TFRpConnectionVCL and TFRpDatasetsVCL):
  // drivers of the FPC build with their description, connections of the
  // connections file to add (New drop down), Configure (ShowDBXConfig),
  // Connect (test), Load params / Load driver params; "Show data"
  // (rpmdfsampledatalcl), the MyBase page (files, index and master fields,
  // Modify -> ShowDataTextConfig) and the client side unions. Connection tests
  // and opening the dataset run in worker threads on copies.
  TFRpDInfoLCL = class(TForm)
  private
    FReport: TRpReport;
    FWork: TRpReport;
    FOrigDatabaseInfo: TRpDatabaseInfoList;
    FOrigDataInfo: TRpDataInfoList;
    FOrigParams: TRpParamList;
    FApplied: Boolean;
    FActiveConnIndex: Integer;
    FActiveDSIndex: Integer;
    FUpdatingControls: Boolean;
    FImageList: TImageList;
    FTabImageList: TImageList;
    // Connections file (available connections of the New drop down)
    FConAdmin: TRpConnAdmin;
    FAvailable: TStringList;
    // Workers of this session (SetReport and closing start a new one)
    FSession: Integer;
    FTestVersion: Integer;
    FTestRunning: Boolean;
    FShowDataVersion: Integer;
    FShowDataRunning: Boolean;
    FOnShowDataset: TRpShowDatasetEvent;
    FInteractive: Boolean;
    FLastMessage: string;
    FMessageCount: Integer;

    // Bottom controls
    PBottom: TPanel;
    BOk: TButton;
    BCancel: TButton;

    // Tabs
    PControl: TPageControl;
    TabConnections: TTabSheet;
    TabDatasets: TTabSheet;

    // Connection controls
    // Drivers (VCL GDriver, MHelp, BConfig)
    PConnDriver: TPanel;
    LDrivers: TListBox;
    PConnDriverInfo: TPanel;
    PConnDriverButtons: TPanel;
    BConfig: TButton;
    MHelp: TMemo;
    PopAdd: TPopupMenu;
    MNew: TMenuItem;
    PConnClient: TPanel;
    LConnections: TListBox;
    SplitterConn: TSplitter;
    PConnProps: TPanel;
    LabelConnAlias: TLabel;
    EConnAlias: TEdit;
    LabelConnDriver: TLabel;
    ComboDriver: TComboBox;
    LabelConfigFile: TLabel;
    EConfigFile: TEdit;
    BBrowseFile: TButton;
    CheckLoginPrompt: TCheckBox;
    CheckLoadParams: TCheckBox;
    CheckLoadDriverParams: TCheckBox;
    BTestConn: TButton;
    OpenDialog1: TOpenDialog;
    // Connection wizard: "Add connection" above the toolbar, the same button
    // in the middle of the tab while the report has no connections, and
    // "Configure with the wizard" for a Reportman AI Agent connection that
    // can not be opened on this computer
    PConnWizard: TPanel;
    BWizardConn: TBitBtn;
    PConnEmpty: TPanel;
    BWizardConnEmpty: TBitBtn;
    LWizardHint: TLabel;
    LAgentProblem: TLabel;
    BWizardConfigure: TBitBtn;

    PDSClient: TPanel;
    PDSTopArea: TPanel;
    LDatasets: TListBox;
    SplitterDS: TSplitter;
    PDSProps: TPanel;
    LabelDSAlias: TLabel;
    EDSAlias: TEdit;
    LabelDSConn: TLabel;
    ComboDSConn: TComboBox;
    LabelDSMaster: TLabel;
    ComboDSMaster: TComboBox;
    CheckOpenOnStart: TCheckBox;
    SplitterSQL: TSplitter;
    PSQLArea: TPanel;
    PSQLTop: TPanel;
    LabelSQL: TLabel;
    BMonacoToggle: TButton;
    BThemeToggle: TButton;
    MSQL: TMemo;
    FMonacoEditor: TFRpMonacoEditorLCL;
    FIsDarkTheme: Boolean;
    // SQL assistant
    PChatHost: TPanel;
    SplitterChat: TSplitter;
    FChat: TFRpChatFrame;
    FChatRequestVersion: Integer;
    FChatCancel: IRpAsyncCancel;
    // The running audit (nil when there is none, or it was stopped)
    FAuditCancel: IRpAsyncCancel;
    FSyncingSchemaContext: Boolean;
    // The direct connection whose local schemas the chat lists ('' = none)
    FChatLocalAlias: string;
    FMailbox: TRpAsyncMailbox;
    FMailboxRef: IRpAsyncMailbox;
    // MyBase page and unions (VCL TabMyBase, GUnions)
    PMyBaseArea: TPanel;
    LMyBase: TLabel;
    EMyBase: TEdit;
    BMyBase: TButton;
    LFields: TLabel;
    EMyBaseDefs: TEdit;
    BSearchFieldsFile: TButton;
    BModify: TButton;
    LIndexFields: TLabel;
    EIndexFields: TEdit;
    LMasterFields: TLabel;
    EMasterFields: TEdit;
    GUnions: TGroupBox;
    LabelUnions: TLabel;
    ComboUnions: TComboBox;
    CheckParallelUnion: TCheckBox;
    CheckGroupUnion: TCheckBox;
    BAddUnions: TButton;
    BDelUnions: TButton;
    LUnions: TListBox;
    OpenDialogMyBase: TOpenDialog;

    procedure BuildControls;
    procedure BuildDriverControls;
    procedure BuildMyBaseControls;
    procedure ShowInfo(const AText: string; AError: Boolean = False);
    // Connections file and drivers (VCL TFRpConnectionVCL)
    procedure LoadConAdmin;
    procedure RefreshAvailable;
    procedure FillDriverCombo(ADriver: TRpDbDriver);
    function ComboDriverValue(out ADriver: TRpDbDriver): Boolean;
    function SelectedListDriver: TRpDbDriver;
    procedure LDriversClick(Sender: TObject);
    procedure PopAddPopup(Sender: TObject);
    procedure MNewClick(Sender: TObject);
    procedure MenuAddClick(Sender: TObject);
    procedure BConfigClick(Sender: TObject);
    procedure BTestConnClick(Sender: TObject);
    procedure BuildWizardControls;
    procedure BWizardConnClick(Sender: TObject);
    procedure BWizardConfigureClick(Sender: TObject);
    procedure UpdateAgentProblem(AItem: TRpDatabaseInfoItem);
    // Datasets (VCL TFRpDatasetsVCL)
    procedure UpdateConnectionDependentUi(AItem: TRpDataInfoItem);
    procedure BShowDataClick(Sender: TObject);
    procedure BMyBaseClick(Sender: TObject);
    procedure BModifyClick(Sender: TObject);
    procedure BAddUnionsClick(Sender: TObject);
    procedure BDelUnionsClick(Sender: TObject);
    procedure SetReport(Value: TRpReport);
    procedure SaveActiveConn;
    procedure SaveActiveDS;
    procedure LoadConnDetails(Index: Integer);
    procedure LoadDSDetails(Index: Integer);
    procedure RefreshConnList;
    procedure RefreshDSList;
    procedure RefreshConnCombos;
    function UniqueItemName(const APrefix: string): string;
    function CheckCanModify: Boolean;
    function HasPendingChanges: Boolean;
    function OrderChanged: Boolean;
    procedure RecordUndoChanges;

    procedure LConnectionsClick(Sender: TObject);
    procedure LDatasetsClick(Sender: TObject);
    procedure BNewConnClick(Sender: TObject);
    procedure BDelConnClick(Sender: TObject);
    procedure BBrowseFileClick(Sender: TObject);
    procedure BNewDSClick(Sender: TObject);
    procedure BtnUpDSClick(Sender: TObject);
    procedure BtnDownDSClick(Sender: TObject);
    procedure BDelDSClick(Sender: TObject);
    procedure BtnRenameDSClick(Sender: TObject);
    procedure BParamsClick(Sender: TObject);
    procedure BMonacoToggleClick(Sender: TObject);
    procedure BThemeToggleClick(Sender: TObject);
    procedure MonacoContentChanged(Sender: TObject);
    procedure MSQLChange(Sender: TObject);
    procedure ComboDSConnChange(Sender: TObject);
    procedure PControlChange(Sender: TObject);
    procedure BOkClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    // SQL assistant (VCL TFRpDatasetsVCL)
    function ActiveDataInfo: TRpDataInfoItem;
    function CurrentSQL: string;
    procedure EnsureAdvancedEditors;
    procedure ApplyActiveDataInfoContext(ASyncSqlFromDataInfo: Boolean;
      const ASchemaApiKeyOverride: string = '');
    procedure SyncActiveSchemaContext(AHubDatabaseId, AHubSchemaId: Int64;
      const ASchemaApiKey: string = '');
    function FindSiblingHubSchemaId(ADataInfo: TRpDataInfoItem): Int64;
    function ResolveNlToSqlRuntime(ADataInfo: TRpDataInfoItem): string;
    function GetUserLanguageCode: string;
    procedure ChatApplySuggestion(Sender: TObject; const AExpression: string);
    procedure ChatSchemaChange(Sender: TObject);
    procedure ChatConfigureLocalSchemas(Sender: TObject;
      const AAlias, ASchemaName: string; AAddNew: Boolean);
    procedure UpdateChatLocalSchemas(ADatabaseInfo: TRpDatabaseInfoItem;
      AForce: Boolean);
    function DatabaseInfoOf(ADataInfo: TRpDataInfoItem): TRpDatabaseInfoItem;
    function ChatInlineConfigJson(const AAlias, ASchemaName: string): string;
    procedure ChatSendPrompt(Sender: TObject; const APrompt, AExpression: string);
    procedure ChatStopRequest(Sender: TObject);
    procedure MonacoSchemaChange(Sender: TObject);
    procedure MonacoInferenceLog(Sender: TObject; const ASource, AText: string;
      AAppendLineBreak: Boolean);
    procedure MonacoAuditSql(Sender: TObject);
    procedure MonacoStopRequest(Sender: TObject);
    procedure HandleAsyncMessage(AMessage: TRpAsyncMessage);
  protected
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    // Toolbar controls
    ToolBarConn: TToolBar;
    BNewConn: TToolButton;
    SepConn: TToolButton;
    BDelConn: TToolButton;

    ToolBarDS: TToolBar;
    BNewDS: TToolButton;
    BtnUpDS: TToolButton;
    BtnDownDS: TToolButton;
    SepDS1: TToolButton;
    BDelDS: TToolButton;
    SepDS2: TToolButton;
    BtnRenameDS: TToolButton;
    SepDS3: TToolButton;
    BShowData: TButton;
    BParams: TButton;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Applies the working copies to the report (what OK does). Returns False
    // when the report can not be modified; the dialog stays open then.
    function ApplyChanges: Boolean;
    // Operations of the buttons without their prompts (the tests use them)
    // Adds a connection of the connections file (New drop down)
    procedure AddAvailableConnection(const AName: string);
    // Adds (or selects) the connection made by the connection wizard
    procedure AddWizardConnection(const AName: string; ADriver: TRpDbDriver);
    // Selects a driver of the driver list (VCL GDriver)
    procedure SelectListDriver(ADriver: TRpDbDriver);
    // Tests the active connection in a worker (VCL BTestClick)
    procedure StartConnectionTest;
    // Opens the active dataset in a worker and shows its records (VCL
    // BShowDataClick)
    procedure StartShowData;
    // Adds a union to the active dataset (with the common fields of a
    // parallel union), removes the selected one
    procedure AddUnion(const ADataset, ACommonFields: string);
    procedure DeleteUnion;
    // Saves the controls into the working copies
    procedure SaveControls;
    property Report: TRpReport read FReport write SetReport;
    // Working copies edited by the dialog (not the report lists)
    property WorkReport: TRpReport read FWork;
    // True when OK applied changes to the report
    property Applied: Boolean read FApplied;
    property MonacoEditor: TFRpMonacoEditorLCL read FMonacoEditor;
    // Plain text editor of the "Monaco / Text" button
    property SQLMemo: TMemo read MSQL;
    // Chat of the SQL assistant (created with the first dataset)
    property Chat: TFRpChatFrame read FChat;
    // Index of the dataset being edited (-1 none)
    property ActiveDatasetIndex: Integer read FActiveDSIndex;
    property DatasetList: TListBox read LDatasets;
    // Connections tab
    property PageControl: TPageControl read PControl;
    property ConnectionsTab: TTabSheet read TabConnections;
    property DatasetsTab: TTabSheet read TabDatasets;
    property ConnectionList: TListBox read LConnections;
    property DriverList: TListBox read LDrivers;
    property DriverCombo: TComboBox read ComboDriver;
    property DriverHelp: TMemo read MHelp;
    property ConnectionAliasEdit: TEdit read EConnAlias;
    property LoginPromptCheck: TCheckBox read CheckLoginPrompt;
    property LoadParamsCheck: TCheckBox read CheckLoadParams;
    property LoadDriverParamsCheck: TCheckBox read CheckLoadDriverParams;
    property TestConnectionButton: TButton read BTestConn;
    property AddConnectionMenu: TPopupMenu read PopAdd;
    // Connection wizard buttons and the empty tab
    property AddConnectionWizardButton: TBitBtn read BWizardConn;
    property EmptyConnectionsPanel: TPanel read PConnEmpty;
    property ConfigureWizardButton: TBitBtn read BWizardConfigure;
    property AgentProblemLabel: TLabel read LAgentProblem;
    // Connections of the connections file for the driver of the driver list
    property AvailableConnections: TStringList read FAvailable;
    property ConnectionTestRunning: Boolean read FTestRunning;
    // Datasets tab
    property ConnectionCombo: TComboBox read ComboDSConn;
    property SQLArea: TPanel read PSQLArea;
    property MyBaseArea: TPanel read PMyBaseArea;
    property MyBaseFileEdit: TEdit read EMyBase;
    property MyBaseFieldsEdit: TEdit read EMyBaseDefs;
    property IndexFieldsEdit: TEdit read EIndexFields;
    property MasterFieldsEdit: TEdit read EMasterFields;
    property UnionsCombo: TComboBox read ComboUnions;
    property UnionsList: TListBox read LUnions;
    property GroupUnionCheck: TCheckBox read CheckGroupUnion;
    property ParallelUnionCheck: TCheckBox read CheckParallelUnion;
    property ShowDataRunning: Boolean read FShowDataRunning;
    // Called instead of showing the records (tests): the dataset is open
    // during the call and closed after it
    property OnShowDataset: TRpShowDatasetEvent read FOnShowDataset write FOnShowDataset;
    // False: messages are not shown (tests), only kept in LastMessage
    property Interactive: Boolean read FInteractive write FInteractive;
    property LastMessage: string read FLastMessage;
    property MessageCount: Integer read FMessageCount;
  end;

// Shows the data configuration dialog. Returns True when the report was
// modified (changes are recorded in the undo cue).
function ShowDataConfig(report: TRpReport): Boolean;

implementation

{$R *.lfm}

uses
  rpjsonfpc, rpauthmanager, rpdatahttp, rpdbxconfiglcl, rpmdfsampledatalcl,
  rpmdfdatatextlcl, rplcllayout, rpmdfnewreportwizardlcl, rplocalschemas,
  rpdesignerclientsql, rpreportdesignercontracts, rpfrmlocalschemaslcl;

type
  { "Show data" (VCL BShowDataClick): the dataset is opened in a worker on a
    copy of the working data; the result message owns the copy }

  TRpShowDataResult = class(TRpAsyncMessage)
  public
    Session: Integer;
    RequestVersion: Integer;
    DataInfoIndex: Integer;
    Report: TRpReport;
    ErrorMessage: string;
    destructor Destroy; override;
  end;

  TRpShowDataWorker = class(TRpAsyncWorker)
  public
    Session: Integer;
    RequestVersion: Integer;
    DataInfoIndex: Integer;
    // Owned until it is passed to the result
    Report: TRpReport;
    destructor Destroy; override;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
  end;

  { Messages and workers of the SQL assistant (the anonymous threads and
    TThread.Queue/Synchronize procedures of TFRpDatasetsVCL) }

  TRpSqlStreamProgress = class(TRpAsyncMessage)
  public
    RequestVersion: Integer;
    Actor: string;
    Stage: string;
    ChunkType: string;
    Chunk: string;
    ProgressId: string;
    InputTokens: Integer;
    OutputTokens: Integer;
    PrefillPercent: Integer;
  end;

  TRpSqlChatProgress = class(TRpSqlStreamProgress);
  TRpSqlAuditProgress = class(TRpSqlStreamProgress);

  TRpSqlChatResult = class(TRpAsyncMessage)
  public
    RequestVersion: Integer;
    ErrorMessage: string;
    Sql: string;
    Explanation: string;
    UserProfileJson: string;
  end;

  TRpSqlAuditResult = class(TRpAsyncMessage)
  public
    DataInfoName: string;
    ErrorMessage: string;
    Explanation: string;
    InputTokens: Integer;
    OutputTokens: Integer;
    UserProfileJson: string;
  end;

  // Common fields of the TRpDatabaseHttp requests
  TRpSqlAIWorker = class(TRpAsyncWorker)
  public
    Token: string;
    InstallId: string;
    ApiKey: string;
    HubDatabaseId: Int64;
    HubSchemaId: Int64;
    RuntimeDb: string;
    AITier: string;
    AIMode: string;
    AgentSecret: string;
    AgentAiId: Int64;
    UserLanguage: string;
    // A direct connection: the config with its schema inline (NL to SQL)
    InlineConfigJson: string;
    Cancel: IRpAsyncCancel;
  protected
    function NewHttp: TRpDatabaseHttp;
    function Cancelled: Boolean;
    function StreamCancelRequested(Sender: TObject): Boolean;
  end;

  // NLToSQL / refine (VCL ChatSendPrompt)
  TRpSqlChatWorker = class(TRpSqlAIWorker)
  public
    RequestVersion: Integer;
    Prompt: string;
    SqlToRefine: string;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
    procedure StreamProgress(Sender: TObject; const AActor, AStage,
      AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
      const AProgressId: string; APrefillPercent: Integer);
  end;

  // Explain / audit the SQL (VCL MonacoAuditSql)
  TRpSqlAuditWorker = class(TRpSqlAIWorker)
  public
    Sql: string;
    DataInfoName: string;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
    procedure StreamProgress(Sender: TObject; const AActor, AStage,
      AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
      const AProgressId: string; APrefillPercent: Integer);
  end;

function GetChatPrefillPercent(const AStage, AChunkType: string): Integer;
begin
  if SameText(AStage, 'PreparingContext') then
    Result := 15
  else if SameText(AStage, 'SendingRequest') then
    Result := 45
  else if SameText(AStage, 'ReceivingResponse') then
  begin
    if SameText(AChunkType, 'Start') then
      Result := 70
    else
      Result := 100;
  end
  else
    Result := 100;
end;

function JsonValueText(AObject: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if AObject = nil then
    Exit;
  LValue := AObject.GetValue(AName);
  if (LValue <> nil) and not (LValue is TJSONNull) then
    Result := LValue.Value;
end;

{ TRpSqlAIWorker }

function TRpSqlAIWorker.NewHttp: TRpDatabaseHttp;
begin
  Result := TRpDatabaseHttp.Create;
  Result.Token := Token;
  Result.InstallId := InstallId;
  Result.HubDatabaseId := HubDatabaseId;
  Result.HubSchemaId := HubSchemaId;
  Result.RuntimeDb := RuntimeDb;
  Result.AITier := AITier;
  Result.AgentSecret := AgentSecret;
  Result.AgentAiId := AgentAiId;
  Result.ApiKey := ApiKey;
  Result.InlineConfigJson := InlineConfigJson;
end;

function TRpSqlAIWorker.Cancelled: Boolean;
begin
  Result := OwnerGone or ((Cancel <> nil) and Cancel.Cancelled);
end;

function TRpSqlAIWorker.StreamCancelRequested(Sender: TObject): Boolean;
begin
  Result := Cancelled;
end;

{ TRpSqlChatWorker }

procedure TRpSqlChatWorker.StreamProgress(Sender: TObject; const AActor,
  AStage, AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer);
var
  LMsg: TRpSqlChatProgress;
begin
  if Cancelled then
    Exit;
  LMsg := TRpSqlChatProgress.Create;
  LMsg.RequestVersion := RequestVersion;
  LMsg.Actor := AActor;
  LMsg.Stage := AStage;
  LMsg.ChunkType := AChunkType;
  LMsg.Chunk := AChunk;
  LMsg.ProgressId := AProgressId;
  LMsg.InputTokens := AInputTokens;
  LMsg.OutputTokens := AOutputTokens;
  LMsg.PrefillPercent := APrefillPercent;
  if LMsg.PrefillPercent <= 0 then
    LMsg.PrefillPercent := GetChatPrefillPercent(AStage, AChunkType);
  Post(LMsg);
end;

procedure TRpSqlChatWorker.Run;
var
  LHttp: TRpDatabaseHttp;
  LResponse: TJSONObject;
  LVal: TJSONValue;
  LMsg: TRpSqlChatResult;
begin
  LHttp := NewHttp;
  LResponse := nil;
  LMsg := TRpSqlChatResult.Create;
  try
    LMsg.RequestVersion := RequestVersion;
    LResponse := LHttp.TranslateToSql(Prompt, SqlToRefine, AIMode, UserLanguage,
      Self, StreamProgress, StreamCancelRequested);
    // Stopped: the chat was already told
    if Cancelled then
      Exit;
    if LResponse <> nil then
    begin
      LMsg.ErrorMessage := Trim(JsonValueText(LResponse, 'errorMessage'));
      if LMsg.ErrorMessage = '' then
      begin
        LVal := LResponse.GetValue('result');
        if LVal is TJSONObject then
        begin
          LMsg.ErrorMessage := Trim(JsonValueText(TJSONObject(LVal), 'errorMessage'));
          LMsg.Sql := JsonValueText(TJSONObject(LVal), 'sql');
          LMsg.Explanation := JsonValueText(TJSONObject(LVal), 'explanation');
        end;
      end;
      LVal := LResponse.GetValue('userProfile');
      if LVal is TJSONObject then
        LMsg.UserProfileJson := LVal.ToJSON;
    end;
    Post(LMsg);
    LMsg := nil;
  finally
    LMsg.Free;
    LResponse.Free;
    LHttp.Free;
  end;
end;

procedure TRpSqlChatWorker.HandleError(E: Exception);
var
  LMsg: TRpSqlChatResult;
begin
  if Cancelled then
    Exit;
  LMsg := TRpSqlChatResult.Create;
  LMsg.RequestVersion := RequestVersion;
  LMsg.ErrorMessage := E.Message;
  Post(LMsg);
end;

{ TRpSqlAuditWorker }

procedure TRpSqlAuditWorker.StreamProgress(Sender: TObject; const AActor,
  AStage, AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer);
var
  LMsg: TRpSqlAuditProgress;
begin
  if Cancelled then
    Exit;
  LMsg := TRpSqlAuditProgress.Create;
  LMsg.Actor := AActor;
  LMsg.Stage := AStage;
  LMsg.ChunkType := AChunkType;
  LMsg.Chunk := AChunk;
  LMsg.ProgressId := AProgressId;
  LMsg.InputTokens := AInputTokens;
  LMsg.OutputTokens := AOutputTokens;
  LMsg.PrefillPercent := APrefillPercent;
  Post(LMsg);
end;

procedure TRpSqlAuditWorker.Run;
var
  LHttp: TRpDatabaseHttp;
  LResponse, LTokenUsage: TJSONObject;
  LVal: TJSONValue;
  LMsg: TRpSqlAuditResult;
begin
  LHttp := NewHttp;
  LResponse := nil;
  LMsg := TRpSqlAuditResult.Create;
  try
    LMsg.DataInfoName := DataInfoName;
    // Stopped by the Stop of the model selection, or when the dialog is
    // closed: nothing is posted
    LResponse := LHttp.ExplainSql(Sql, AIMode, UserLanguage, Self,
      StreamProgress, StreamCancelRequested);
    if Cancelled then
      Exit;
    if LResponse <> nil then
    begin
      LMsg.ErrorMessage := JsonValueText(LResponse, 'errorMessage');
      if Trim(LMsg.ErrorMessage) = '' then
      begin
        LVal := LResponse.GetValue('result');
        if LVal is TJSONObject then
        begin
          LMsg.Explanation := JsonValueText(TJSONObject(LVal), 'explanation');
          LVal := TJSONObject(LVal).GetValue('tokenUsage');
          if LVal is TJSONObject then
          begin
            LTokenUsage := TJSONObject(LVal);
            LMsg.InputTokens := StrToIntDef(JsonValueText(LTokenUsage, 'inputTokens'), 0);
            LMsg.OutputTokens := StrToIntDef(JsonValueText(LTokenUsage, 'outputTokens'), 0);
          end;
        end;
      end;
      LVal := LResponse.GetValue('userProfile');
      if LVal is TJSONObject then
        LMsg.UserProfileJson := LVal.ToJSON;
    end;
    Post(LMsg);
    LMsg := nil;
  finally
    LMsg.Free;
    LResponse.Free;
    LHttp.Free;
  end;
end;

procedure TRpSqlAuditWorker.HandleError(E: Exception);
var
  LMsg: TRpSqlAuditResult;
begin
  if Cancelled then
    Exit;
  LMsg := TRpSqlAuditResult.Create;
  LMsg.DataInfoName := DataInfoName;
  LMsg.ErrorMessage := E.Message;
  Post(LMsg);
end;

// Closes the datasets and connections of a copy of the data and frees it
procedure FreeDataCopy(var AReport: TRpReport);
var
  i: Integer;
begin
  if AReport = nil then
    Exit;
  try
    for i := AReport.DataInfo.Count - 1 downto 0 do
      AReport.DataInfo.Items[i].Disconnect;
    for i := 0 to AReport.DatabaseInfo.Count - 1 do
      AReport.DatabaseInfo.Items[i].DisConnect;
  except
    // Freeing closes them anyway
  end;
  FreeAndNil(AReport);
end;

{ TRpShowDataResult }

destructor TRpShowDataResult.Destroy;
begin
  FreeDataCopy(Report);
  inherited Destroy;
end;

{ TRpShowDataWorker }

destructor TRpShowDataWorker.Destroy;
begin
  FreeDataCopy(Report);
  inherited Destroy;
end;

procedure TRpShowDataWorker.Run;
var
  LMsg: TRpShowDataResult;
  i: Integer;
begin
  // VCL BShowDataClick: disconnect, evaluator, parameters, open
  for i := 0 to Report.DataInfo.Count - 1 do
    Report.DataInfo.Items[i].Disconnect;
  Report.InitEvaluator;
  Report.AddReportItemsToEvaluator(Report.Evaluator);
  Report.PrepareParamsBeforeOpen;
  Report.DataInfo.Items[DataInfoIndex].Connect(Report.DatabaseInfo, Report.Params);
  LMsg := TRpShowDataResult.Create;
  LMsg.Session := Session;
  LMsg.RequestVersion := RequestVersion;
  LMsg.DataInfoIndex := DataInfoIndex;
  LMsg.Report := Report;
  Report := nil;
  Post(LMsg);
end;

procedure TRpShowDataWorker.HandleError(E: Exception);
var
  LMsg: TRpShowDataResult;
begin
  LMsg := TRpShowDataResult.Create;
  LMsg.Session := Session;
  LMsg.RequestVersion := RequestVersion;
  LMsg.DataInfoIndex := DataInfoIndex;
  LMsg.ErrorMessage := E.Message;
  Post(LMsg);
end;

var
  GDataConfigDialog: TFRpDInfoLCL = nil;

function ShowDataConfig(report: TRpReport): Boolean;
begin
  Result := False;
  if not Assigned(report) then Exit;
  if GDataConfigDialog = nil then
    GDataConfigDialog := TFRpDInfoLCL.Create(Application);
  GDataConfigDialog.Report := report;
  GDataConfigDialog.ShowModal;
  Result := GDataConfigDialog.Applied;
end;

function SameStringLists(AList, BList: TStrings): Boolean;
begin
  if (AList = nil) or (BList = nil) then
    Result := AList = BList
  else
    Result := AList.Text = BList.Text;
end;

function SameDatabaseInfoItem(AItem, BItem: TRpDatabaseInfoItem): Boolean;
begin
  Result := Assigned(AItem) and Assigned(BItem) and
    (AItem.Name = BItem.Name) and
    (AItem.Alias = BItem.Alias) and
    (Integer(AItem.Driver) = Integer(BItem.Driver)) and
    (AItem.ConfigFile = BItem.ConfigFile) and
    (AItem.LoginPrompt = BItem.LoginPrompt) and
    (AItem.LoadParams = BItem.LoadParams) and
    (AItem.LoadDriverParams = BItem.LoadDriverParams) and
    (AItem.ADOConnectionString = BItem.ADOConnectionString) and
    (AItem.ProviderFactory = BItem.ProviderFactory) and
    (AItem.DotNetDriver = BItem.DotNetDriver) and
    (AItem.ReportTable = BItem.ReportTable) and
    (AItem.ReportField = BItem.ReportField) and
    (AItem.ReportSearchField = BItem.ReportSearchField) and
    (AItem.ReportGroupsTable = BItem.ReportGroupsTable);
end;

function SameDatabaseInfoList(AList, BList: TRpDatabaseInfoList): Boolean;
var
  i: Integer;
begin
  Result := Assigned(AList) and Assigned(BList) and (AList.Count = BList.Count);
  if not Result then
    Exit;
  for i := 0 to AList.Count - 1 do
  begin
    if not SameDatabaseInfoItem(AList.Items[i], BList.Items[i]) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function SameDataInfoItem(AItem, BItem: TRpDataInfoItem): Boolean;
begin
  Result := Assigned(AItem) and Assigned(BItem) and
    (AItem.Name = BItem.Name) and
    (AItem.Alias = BItem.Alias) and
    (AItem.DatabaseAlias = BItem.DatabaseAlias) and
    (AItem.DataSource = BItem.DataSource) and
    (AItem.SQL = BItem.SQL) and
    (AItem.SQLExplanation = BItem.SQLExplanation) and
    (AItem.SQLExplanationError = BItem.SQLExplanationError) and
    (AItem.HubSchemaId = BItem.HubSchemaId) and
    (AItem.SchemaName = BItem.SchemaName) and
    (AItem.MyBaseFilename = BItem.MyBaseFilename) and
    (AItem.MyBaseFields = BItem.MyBaseFields) and
    (AItem.MyBaseIndexFields = BItem.MyBaseIndexFields) and
    (AItem.MyBaseMasterFields = BItem.MyBaseMasterFields) and
    (AItem.GroupUnion = BItem.GroupUnion) and
    (AItem.OpenOnStart = BItem.OpenOnStart) and
    (AItem.ParallelUnion = BItem.ParallelUnion) and
    SameStringLists(AItem.DataUnions, BItem.DataUnions);
end;

// The MyBase properties are not undo properties (neither in the Delphi undo
// cue): a change of them marks the report modified
function SameMyBaseProperties(AItem, BItem: TRpDataInfoItem): Boolean;
begin
  Result := (AItem.MyBaseFilename = BItem.MyBaseFilename) and
    (AItem.MyBaseFields = BItem.MyBaseFields) and
    (AItem.MyBaseIndexFields = BItem.MyBaseIndexFields) and
    (AItem.MyBaseMasterFields = BItem.MyBaseMasterFields);
end;

// Value of a ptStringArray undo property (dataUnions)
function StringListToVariant(AStrings: TStrings): Variant;
var
  i: Integer;
begin
  if AStrings.Count = 0 then
  begin
    Result := VarArrayCreate([0, -1], varVariant);
    Exit;
  end;
  Result := VarArrayCreate([0, AStrings.Count - 1], varVariant);
  for i := 0 to AStrings.Count - 1 do
    Result[i] := AStrings[i];
end;

function HasMyBaseProperties(AItem: TRpDataInfoItem): Boolean;
begin
  Result := (AItem.MyBaseFilename <> '') or (AItem.MyBaseFields <> '') or
    (AItem.MyBaseIndexFields <> '') or (AItem.MyBaseMasterFields <> '');
end;

function SameDataInfoList(AList, BList: TRpDataInfoList): Boolean;
var
  i: Integer;
begin
  Result := Assigned(AList) and Assigned(BList) and (AList.Count = BList.Count);
  if not Result then
    Exit;
  for i := 0 to AList.Count - 1 do
  begin
    if not SameDataInfoItem(AList.Items[i], BList.Items[i]) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function SameParamItem(AItem, BItem: TRpParam): Boolean;
begin
  Result := Assigned(AItem) and Assigned(BItem) and
    (AItem.Name = BItem.Name) and
    (AItem.IntName = BItem.IntName) and
    (AItem.Visible = BItem.Visible) and
    (AItem.NeverVisible = BItem.NeverVisible) and
    (AItem.IsReadOnly = BItem.IsReadOnly) and
    (AItem.AllowNulls = BItem.AllowNulls) and
    (Integer(AItem.ParamType) = Integer(BItem.ParamType)) and
    (AItem.Descriptions = BItem.Descriptions) and
    (AItem.Hints = BItem.Hints) and
    (AItem.Validation = BItem.Validation) and
    (AItem.ErrorMessages = BItem.ErrorMessages) and
    (AItem.Search = BItem.Search) and
    (AItem.LookupDataset = BItem.LookupDataset) and
    (AItem.SearchDataset = BItem.SearchDataset) and
    (AItem.SearchParam = BItem.SearchParam) and
    ParamValuesEqual(AItem.Value, BItem.Value) and
    SameStringLists(AItem.Datasets, BItem.Datasets) and
    SameStringLists(AItem.Items, BItem.Items) and
    SameStringLists(AItem.Values, BItem.Values) and
    SameStringLists(AItem.Selected, BItem.Selected);
end;

function SameParamList(AList, BList: TRpParamList): Boolean;
var
  i: Integer;
begin
  Result := Assigned(AList) and Assigned(BList) and (AList.Count = BList.Count);
  if not Result then
    Exit;
  for i := 0 to AList.Count - 1 do
  begin
    if not SameParamItem(AList.Items[i], BList.Items[i]) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

constructor TFRpDInfoLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // Sizes in pixels of the screen: the LCL does not scale it again (the
  // lfm only has the form)
  RpBuiltInScreenPixels(Self);
  FActiveConnIndex := -1;
  FActiveDSIndex := -1;
  FUpdatingControls := False;
  FApplied := False;

  FWork := TRpReport.Create(Self);
  FOrigDatabaseInfo := TRpDatabaseInfoList.Create(nil);
  FOrigDataInfo := TRpDataInfoList.Create(nil);
  FOrigParams := TRpParamList.Create(nil);
  FMailbox := TRpAsyncMailbox.Create(HandleAsyncMessage);
  FMailboxRef := FMailbox;
  FAvailable := TStringList.Create;
  FInteractive := True;

  Caption := TranslateStr(1097, 'Database connections and datasets');
  Position := poScreenCenter;
  // Room for the SQL editor and the chat of the SQL assistant; it must fit
  // the screen (800x600)
  Width := Min(Scale96ToForm(1060), Screen.WorkAreaWidth - 20);
  Height := Min(Scale96ToForm(720), Screen.WorkAreaHeight - 20);

  BuildControls;
end;

destructor TFRpDInfoLCL.Destroy;
begin
  // Workers still running drop their results (and the copies of the data
  // they opened); the chat stream stops
  FMailbox.Detach;
  if FChatCancel <> nil then
    FChatCancel.Cancel;
  FChatCancel := nil;
  if FAuditCancel <> nil then
    FAuditCancel.Cancel;
  FAuditCancel := nil;
  FMailboxRef := nil;
  if GDataConfigDialog = Self then
    GDataConfigDialog := nil;
  FreeAndNil(FOrigDatabaseInfo);
  FreeAndNil(FOrigDataInfo);
  FreeAndNil(FOrigParams);
  FreeAndNil(FConAdmin);
  FreeAndNil(FAvailable);
  inherited Destroy;
end;

procedure TFRpDInfoLCL.DoClose(var CloseAction: TCloseAction);
begin
  inherited DoClose(CloseAction);
  // Answers of the workers of this session are dropped (the dialog is
  // reused by ShowDataConfig)
  Inc(FSession);
  FTestRunning := False;
  FShowDataRunning := False;
end;

procedure TFRpDInfoLCL.ShowInfo(const AText: string; AError: Boolean);
begin
  FLastMessage := AText;
  Inc(FMessageCount);
  if not FInteractive then
    Exit;
  if AError then
    RpMessageBox(AText, '', [smbOK], smsCritical)
  else
    RpShowMessage(AText);
end;

procedure TFRpDInfoLCL.BuildControls;
begin
  OpenDialog1 := TOpenDialog.Create(Self);
  OpenDialog1.Filter := TranslateStr(705, 'Any File') + ' (*.*)|*.*|' +
    'SQLite (*.db;*.sqlite;*.sqlite3)|*.db;*.sqlite;*.sqlite3|' +
    'XML/ClientDataset (*.xml;*.cds)|*.xml;*.cds';

  // Bottom buttons panel
  PBottom := TPanel.Create(Self);
  PBottom.Align := alBottom;
  PBottom.Height := Scale96ToScreen(44);
  PBottom.BevelOuter := bvNone;
  PBottom.Parent := Self;

  // No ModalResult on the OK button: BOkClick decides whether the dialog can
  // close (the report may refuse modifications)
  BOk := TButton.Create(PBottom);
  BOk.Parent := PBottom;
  BOk.Caption := TranslateStr(93, 'OK');
  BOk.Default := True;
  BOk.SetBounds(PBottom.Width - Scale96ToScreen(210), Scale96ToScreen(8), Scale96ToScreen(95), Scale96ToScreen(28));
  BOk.OnClick := BOkClick;

  BCancel := TButton.Create(PBottom);
  BCancel.Parent := PBottom;
  BCancel.Caption := TranslateStr(94, 'Cancel');
  BCancel.ModalResult := mrCancel;
  BCancel.Cancel := True;
  BCancel.SetBounds(PBottom.Width - Scale96ToScreen(105), Scale96ToScreen(8), Scale96ToScreen(95), Scale96ToScreen(28));
  BCancel.OnClick := BCancelClick;
  // Anchored to the sides (the size of the parents is not final here: fixed
  // right distances computed now can push the controls out of a small
  // window)
  BCancel.AnchorParallel(akRight, Scale96ToScreen(10), PBottom);
  BCancel.Anchors := [akTop, akRight];
  BOk.AnchorToNeighbour(akRight, Scale96ToScreen(10), BCancel);
  BOk.Anchors := [akTop, akRight];

  // PageControl
  PControl := TPageControl.Create(Self);
  PControl.Align := alClient;
  PControl.Parent := Self;

  FTabImageList := TImageList.Create(Self);
  LoadDBBrowserImageList(FTabImageList);
  PControl.Images := FTabImageList;

  FImageList := TImageList.Create(Self);
  LoadDataConfigImageList(FImageList);

  // -------------------------------------------------------------
  // TAB 1: Connections
  // -------------------------------------------------------------
  TabConnections := TTabSheet.Create(PControl);
  TabConnections.PageControl := PControl;
  TabConnections.Caption := TranslateStr(142, 'Database connections');
  TabConnections.ImageIndex := 0;

  // "Add connection" (the connection wizard) above the toolbar
  PConnWizard := TPanel.Create(TabConnections);
  PConnWizard.Parent := TabConnections;
  PConnWizard.BevelOuter := bvNone;
  PConnWizard.Align := alTop;
  PConnWizard.AutoSize := True;
  PConnWizard.Top := 0;
  BWizardConn := TBitBtn.Create(PConnWizard);
  BWizardConn.Parent := PConnWizard;
  BWizardConn.Caption := TranslateStr(1826, 'Add connection') + '...';
  BWizardConn.AutoSize := True;
  BWizardConn.BorderSpacing.Around := Scale96ToScreen(6);
  BWizardConn.Align := alLeft;
  BWizardConn.OnClick := BWizardConnClick;

  ToolBarConn := TToolBar.Create(TabConnections);
  ToolBarConn.Parent := TabConnections;
  ToolBarConn.Top := Scale96ToScreen(60);
  ToolBarConn.Align := alTop;
  ToolBarConn.Height := Scale96ToScreen(28);
  ToolBarConn.ButtonWidth := Scale96ToScreen(26);
  ToolBarConn.ButtonHeight := Scale96ToScreen(26);
  ToolBarConn.Flat := True;
  ToolBarConn.ShowHint := True;
  ToolBarConn.Images := FImageList;

  // New: a connection with the driver of the driver list; the drop down
  // (VCL PopAdd) also lists the connections of the connections file
  PopAdd := TPopupMenu.Create(Self);
  PopAdd.OnPopup := PopAddPopup;
  MNew := TMenuItem.Create(PopAdd);
  MNew.Caption := TranslateStr(40, 'New');
  MNew.OnClick := MNewClick;
  PopAdd.Items.Add(MNew);

  BNewConn := TToolButton.Create(ToolBarConn);
  BNewConn.Parent := ToolBarConn;
  BNewConn.ImageIndex := IMG_DC_NEW;
  BNewConn.Hint := TranslateStr(1103, 'Adds a new connection');
  BNewConn.Style := tbsDropDown;
  BNewConn.DropdownMenu := PopAdd;
  BNewConn.OnClick := BNewConnClick;

  SepConn := TToolButton.Create(ToolBarConn);
  SepConn.Parent := ToolBarConn;
  SepConn.Style := tbsSeparator;
  SepConn.Width := Scale96ToScreen(8);

  BDelConn := TToolButton.Create(ToolBarConn);
  BDelConn.Parent := ToolBarConn;
  BDelConn.ImageIndex := IMG_DC_DELETE;
  BDelConn.Hint := TranslateStr(1105, 'Deletes the selected connection');
  BDelConn.OnClick := BDelConnClick;

  BuildDriverControls;

  PConnClient := TPanel.Create(TabConnections);
  PConnClient.Align := alClient;
  PConnClient.BevelOuter := bvNone;
  PConnClient.Parent := TabConnections;

  LConnections := TListBox.Create(PConnClient);
  LConnections.Align := alLeft;
  LConnections.Width := Scale96ToScreen(210);
  LConnections.Parent := PConnClient;
  LConnections.OnClick := LConnectionsClick;

  SplitterConn := TSplitter.Create(PConnClient);
  SplitterConn.Align := alLeft;
  SplitterConn.Width := Scale96ToScreen(5);
  SplitterConn.Parent := PConnClient;

  PConnProps := TPanel.Create(PConnClient);
  PConnProps.Align := alClient;
  PConnProps.BevelOuter := bvNone;
  PConnProps.BorderWidth := Scale96ToScreen(10);
  PConnProps.Parent := PConnClient;

  LabelConnAlias := TLabel.Create(PConnProps);
  LabelConnAlias.Parent := PConnProps;
  LabelConnAlias.Caption := TranslateStr(400, 'Connection name') + ':';
  LabelConnAlias.SetBounds(Scale96ToScreen(10), Scale96ToScreen(12), Scale96ToScreen(200), Scale96ToScreen(16));

  EConnAlias := TEdit.Create(PConnProps);
  EConnAlias.Parent := PConnProps;
  EConnAlias.SetBounds(Scale96ToScreen(10), Scale96ToScreen(32), Scale96ToScreen(380), Scale96ToScreen(24));
  EConnAlias.AnchorParallel(akRight, Scale96ToScreen(10), PConnProps);
  EConnAlias.Anchors := [akLeft, akTop, akRight];

  LabelConnDriver := TLabel.Create(PConnProps);
  LabelConnDriver.Parent := PConnProps;
  LabelConnDriver.Caption := TranslateStr(1101, 'Database driver') + ':';
  LabelConnDriver.SetBounds(Scale96ToScreen(10), Scale96ToScreen(68), Scale96ToScreen(200), Scale96ToScreen(16));

  ComboDriver := TComboBox.Create(PConnProps);
  ComboDriver.Parent := PConnProps;
  ComboDriver.Style := csDropDownList;
  ComboDriver.SetBounds(Scale96ToScreen(10), Scale96ToScreen(88), Scale96ToScreen(380), Scale96ToScreen(24));
  ComboDriver.AnchorParallel(akRight, Scale96ToScreen(10), PConnProps);
  ComboDriver.Anchors := [akLeft, akTop, akRight];
  // The drivers of the FPC build (FillDriverCombo; a driver that is not
  // available is listed only for the connection that uses it, so the
  // connection keeps it)
  GetFpcDatabaseDrivers(ComboDriver.Items);

  LabelConfigFile := TLabel.Create(PConnProps);
  LabelConfigFile.Parent := PConnProps;
  LabelConfigFile.Caption := TranslateStr(743, 'Configuration file') + ':';
  LabelConfigFile.SetBounds(Scale96ToScreen(10), Scale96ToScreen(124), Scale96ToScreen(200), Scale96ToScreen(16));

  EConfigFile := TEdit.Create(PConnProps);
  EConfigFile.Parent := PConnProps;
  EConfigFile.SetBounds(Scale96ToScreen(10), Scale96ToScreen(144), Scale96ToScreen(340), Scale96ToScreen(24));

  BBrowseFile := TButton.Create(PConnProps);
  BBrowseFile.Parent := PConnProps;
  BBrowseFile.Caption := '...';
  BBrowseFile.SetBounds(Scale96ToScreen(355), Scale96ToScreen(144), Scale96ToScreen(35), Scale96ToScreen(24));
  BBrowseFile.AnchorParallel(akRight, Scale96ToScreen(10), PConnProps);
  BBrowseFile.Anchors := [akTop, akRight];
  BBrowseFile.OnClick := BBrowseFileClick;
  EConfigFile.AnchorToNeighbour(akRight, Scale96ToScreen(5), BBrowseFile);
  EConfigFile.Anchors := [akLeft, akTop, akRight];

  CheckLoginPrompt := TCheckBox.Create(PConnProps);
  CheckLoginPrompt.Parent := PConnProps;
  CheckLoginPrompt.Caption := TranslateStr(144, 'Login prompt');
  CheckLoginPrompt.SetBounds(Scale96ToScreen(10), Scale96ToScreen(178), Scale96ToScreen(250), Scale96ToScreen(20));

  // VCL CheckLoadParams, CheckLoadDriverParams
  CheckLoadParams := TCheckBox.Create(PConnProps);
  CheckLoadParams.Parent := PConnProps;
  CheckLoadParams.Caption := TranslateStr(145, 'Load params');
  CheckLoadParams.SetBounds(Scale96ToScreen(10), Scale96ToScreen(202), Scale96ToScreen(250), Scale96ToScreen(20));

  CheckLoadDriverParams := TCheckBox.Create(PConnProps);
  CheckLoadDriverParams.Parent := PConnProps;
  CheckLoadDriverParams.Caption := TranslateStr(146, 'Load driver params');
  CheckLoadDriverParams.SetBounds(Scale96ToScreen(10), Scale96ToScreen(226), Scale96ToScreen(250), Scale96ToScreen(20));

  // VCL BTest: connects and disconnects (in a worker thread)
  BTestConn := TButton.Create(PConnProps);
  BTestConn.Parent := PConnProps;
  BTestConn.Caption := TranslateStr(753, 'Connect');
  BTestConn.SetBounds(Scale96ToScreen(10), Scale96ToScreen(254), RpCaptionWidth(BTestConn, [BTestConn.Caption], 110),
    Scale96ToForm(28));
  BTestConn.OnClick := BTestConnClick;

  BuildWizardControls;

  // -------------------------------------------------------------
  // TAB 2: Datasets
  // -------------------------------------------------------------
  TabDatasets := TTabSheet.Create(PControl);
  TabDatasets.PageControl := PControl;
  TabDatasets.Caption := TranslateStr(148, 'Report datasets');
  TabDatasets.ImageIndex := 1;

  ToolBarDS := TToolBar.Create(TabDatasets);
  ToolBarDS.Parent := TabDatasets;
  ToolBarDS.Align := alTop;
  ToolBarDS.Height := Scale96ToScreen(28);
  ToolBarDS.ButtonWidth := Scale96ToScreen(26);
  ToolBarDS.ButtonHeight := Scale96ToScreen(26);
  ToolBarDS.Flat := True;
  ToolBarDS.ShowHint := True;
  ToolBarDS.Images := FImageList;

  BNewDS := TToolButton.Create(ToolBarDS);
  BNewDS.Parent := ToolBarDS;
  BNewDS.ImageIndex := IMG_DC_NEW;
  BNewDS.Hint := TranslateStr(539, 'New dataset');
  BNewDS.OnClick := BNewDSClick;

  BtnUpDS := TToolButton.Create(ToolBarDS);
  BtnUpDS.Parent := ToolBarDS;
  BtnUpDS.ImageIndex := IMG_DC_UP;
  BtnUpDS.Hint := TranslateStr(28, 'Moves the selection up');
  BtnUpDS.OnClick := BtnUpDSClick;

  BtnDownDS := TToolButton.Create(ToolBarDS);
  BtnDownDS.Parent := ToolBarDS;
  BtnDownDS.ImageIndex := IMG_DC_DOWN;
  BtnDownDS.Hint := TranslateStr(30, 'Moves the selection down');
  BtnDownDS.OnClick := BtnDownDSClick;

  SepDS1 := TToolButton.Create(ToolBarDS);
  SepDS1.Parent := ToolBarDS;
  SepDS1.Style := tbsSeparator;
  SepDS1.Width := Scale96ToScreen(8);

  BDelDS := TToolButton.Create(ToolBarDS);
  BDelDS.Parent := ToolBarDS;
  BDelDS.ImageIndex := IMG_DC_DELETE;
  BDelDS.Hint := TranslateStr(150, 'Delete');
  BDelDS.OnClick := BDelDSClick;

  SepDS2 := TToolButton.Create(ToolBarDS);
  SepDS2.Parent := ToolBarDS;
  SepDS2.Style := tbsSeparator;
  SepDS2.Width := Scale96ToScreen(8);

  BtnRenameDS := TToolButton.Create(ToolBarDS);
  BtnRenameDS.Parent := ToolBarDS;
  BtnRenameDS.ImageIndex := IMG_DC_RENAME;
  BtnRenameDS.Hint := TranslateStr(540, 'Rename dataset');
  BtnRenameDS.OnClick := BtnRenameDSClick;

  SepDS3 := TToolButton.Create(ToolBarDS);
  SepDS3.Parent := ToolBarDS;
  SepDS3.Style := tbsSeparator;
  SepDS3.Width := Scale96ToScreen(8);
  SepDS3.Left := BtnRenameDS.Left + BtnRenameDS.Width + 1;

  // VCL BShowData (in the dataset properties there); here in the toolbar so
  // it is at hand for the SQL and the MyBase datasets
  BShowData := TButton.Create(ToolBarDS);
  BShowData.Parent := ToolBarDS;
  BShowData.Caption := TranslateStr(156, 'Show data');
  BShowData.Width := RpCaptionWidth(BShowData, [BShowData.Caption], 90);
  BShowData.Height := Scale96ToScreen(24);
  BShowData.Left := SepDS3.Left + SepDS3.Width + 1;
  BShowData.OnClick := BShowDataClick;

  PDSClient := TPanel.Create(TabDatasets);
  PDSClient.Align := alClient;
  PDSClient.BevelOuter := bvNone;
  PDSClient.Parent := TabDatasets;

  PDSTopArea := TPanel.Create(PDSClient);
  PDSTopArea.Align := alTop;
  PDSTopArea.Height := Scale96ToScreen(170);
  PDSTopArea.BevelOuter := bvNone;
  PDSTopArea.Parent := PDSClient;

  LDatasets := TListBox.Create(PDSTopArea);
  LDatasets.Align := alLeft;
  LDatasets.Width := Scale96ToScreen(210);
  LDatasets.Parent := PDSTopArea;
  LDatasets.OnClick := LDatasetsClick;

  SplitterDS := TSplitter.Create(PDSTopArea);
  SplitterDS.Align := alLeft;
  SplitterDS.Width := Scale96ToScreen(5);
  SplitterDS.Parent := PDSTopArea;

  PDSProps := TPanel.Create(PDSTopArea);
  PDSProps.Align := alClient;
  PDSProps.BevelOuter := bvNone;
  PDSProps.BorderWidth := Scale96ToScreen(6);
  PDSProps.Parent := PDSTopArea;

  LabelDSAlias := TLabel.Create(PDSProps);
  LabelDSAlias.Parent := PDSProps;
  LabelDSAlias.Caption := TranslateStr(518, 'Alias Name') + ':';
  LabelDSAlias.SetBounds(Scale96ToScreen(10), Scale96ToScreen(6), Scale96ToScreen(160), Scale96ToScreen(16));

  EDSAlias := TEdit.Create(PDSProps);
  EDSAlias.Parent := PDSProps;
  EDSAlias.SetBounds(Scale96ToScreen(10), Scale96ToScreen(24), Scale96ToScreen(380), Scale96ToScreen(24));
  EDSAlias.AnchorParallel(akRight, Scale96ToScreen(10), PDSProps);
  EDSAlias.Anchors := [akLeft, akTop, akRight];

  LabelDSConn := TLabel.Create(PDSProps);
  LabelDSConn.Parent := PDSProps;
  LabelDSConn.Caption := TranslateStr(154, 'Connection') + ':';
  LabelDSConn.SetBounds(Scale96ToScreen(10), Scale96ToScreen(54), Scale96ToScreen(160), Scale96ToScreen(16));

  ComboDSConn := TComboBox.Create(PDSProps);
  ComboDSConn.Parent := PDSProps;
  ComboDSConn.Style := csDropDownList;
  ComboDSConn.SetBounds(Scale96ToScreen(10), Scale96ToScreen(72), Scale96ToScreen(380), Scale96ToScreen(24));
  ComboDSConn.AnchorParallel(akRight, Scale96ToScreen(10), PDSProps);
  ComboDSConn.Anchors := [akLeft, akTop, akRight];
  ComboDSConn.OnChange := ComboDSConnChange;

  LabelDSMaster := TLabel.Create(PDSProps);
  LabelDSMaster.Parent := PDSProps;
  LabelDSMaster.Caption := TranslateStr(155, 'Master dataset') + ':';
  LabelDSMaster.SetBounds(Scale96ToScreen(10), Scale96ToScreen(102), Scale96ToScreen(160), Scale96ToScreen(16));

  ComboDSMaster := TComboBox.Create(PDSProps);
  ComboDSMaster.Parent := PDSProps;
  ComboDSMaster.Style := csDropDownList;
  ComboDSMaster.SetBounds(Scale96ToScreen(10), Scale96ToScreen(120), Scale96ToScreen(240), Scale96ToScreen(24));

  CheckOpenOnStart := TCheckBox.Create(PDSProps);
  CheckOpenOnStart.Parent := PDSProps;
  CheckOpenOnStart.Caption := TranslateStr(1373, 'Open on start');
  // After the master combo (a right anchor computed before the final size
  // put it out of small windows)
  CheckOpenOnStart.SetBounds(Scale96ToScreen(262), Scale96ToScreen(122), Scale96ToScreen(180), Scale96ToScreen(20));

  SplitterSQL := TSplitter.Create(PDSClient);
  SplitterSQL.Align := alTop;
  SplitterSQL.Height := Scale96ToScreen(5);
  SplitterSQL.Parent := PDSClient;

  PSQLArea := TPanel.Create(PDSClient);
  PSQLArea.Align := alClient;
  PSQLArea.BevelOuter := bvNone;
  PSQLArea.BorderWidth := Scale96ToScreen(4);
  PSQLArea.Parent := PDSClient;

  PSQLTop := TPanel.Create(PSQLArea);
  PSQLTop.Align := alTop;
  PSQLTop.Height := Scale96ToScreen(28);
  PSQLTop.BevelOuter := bvNone;
  PSQLTop.Parent := PSQLArea;

  // The widths of the captions: the SQL editor is narrow in a 800x600 window
  // (the chat takes the right part)
  LabelSQL := TLabel.Create(PSQLTop);
  LabelSQL.Caption := ' ' + TranslateStr(159, 'Query') + ':';
  LabelSQL.SetBounds(Scale96ToScreen(4), Scale96ToScreen(6), RpCaptionWidth(Self, [LabelSQL.Caption], 40) - Scale96ToScreen(16), Scale96ToScreen(18));
  LabelSQL.Parent := PSQLTop;

  // Switches between the Monaco editor and the plain text memo
  BMonacoToggle := TButton.Create(PSQLTop);
  BMonacoToggle.Parent := PSQLTop;
  BMonacoToggle.Caption := 'Monaco / ' + TranslateStr(314, 'Text');
  BMonacoToggle.SetBounds(LabelSQL.Left + LabelSQL.Width + Scale96ToScreen(6), Scale96ToScreen(2),
    RpCaptionWidth(BMonacoToggle, [BMonacoToggle.Caption], 90), Scale96ToScreen(24));
  BMonacoToggle.OnClick := BMonacoToggleClick;

  // Switches the light / dark editor theme
  BThemeToggle := TButton.Create(PSQLTop);
  BThemeToggle.Parent := PSQLTop;
  BThemeToggle.Caption := TranslateStr(1447, 'Theme');
  BThemeToggle.SetBounds(BMonacoToggle.Left + BMonacoToggle.Width + Scale96ToScreen(6), Scale96ToScreen(2),
    RpCaptionWidth(BThemeToggle, [BThemeToggle.Caption], 70), Scale96ToScreen(24));
  BThemeToggle.OnClick := BThemeToggleClick;
  FIsDarkTheme := False;

  // Report parameters (VCL: TFRpDatasetsVCL.BParams, in its toolbar): in the
  // toolbar too, usable with the MyBase page (the SQL one is hidden then)
  BParams := TButton.Create(ToolBarDS);
  BParams.Parent := ToolBarDS;
  BParams.Caption := TranslateStr(152, 'Parameters');
  BParams.Hint := BParams.Caption;
  BParams.Width := RpCaptionWidth(BParams, [BParams.Caption], 90);
  BParams.Height := Scale96ToScreen(24);
  BParams.Left := BShowData.Left + BShowData.Width + 1;
  BParams.OnClick := BParamsClick;

  // SQL assistant at the right of the editor (VCL: PChatHost of TabSQL);
  // the chat is created with the first dataset (EnsureAdvancedEditors)
  PChatHost := TPanel.Create(PSQLArea);
  PChatHost.Align := alRight;
  // Room for the editor in a small window
  PChatHost.Width := Min(Scale96ToForm(340), Width * 2 div 5);
  PChatHost.BevelOuter := bvNone;
  PChatHost.Caption := '';
  PChatHost.Parent := PSQLArea;

  SplitterChat := TSplitter.Create(PSQLArea);
  SplitterChat.Align := alRight;
  SplitterChat.Width := Scale96ToScreen(5);
  SplitterChat.Parent := PSQLArea;
  SplitterChat.Left := PChatHost.Left - SplitterChat.Width;

  MSQL := TMemo.Create(PSQLArea);
  MSQL.Align := alClient;
  MSQL.Font.Name := 'Courier New';
  MSQL.Font.Size := 9;
  MSQL.ScrollBars := ssBoth;
  MSQL.WordWrap := False;
  MSQL.Visible := False;
  MSQL.Parent := PSQLArea;
  MSQL.OnChange := MSQLChange;

  FMonacoEditor := TFRpMonacoEditorLCL.Create(PSQLArea);
  FMonacoEditor.Align := alClient;
  FMonacoEditor.Parent := PSQLArea;
  FMonacoEditor.Visible := True;
  FMonacoEditor.OnContentChanged := MonacoContentChanged;
  FMonacoEditor.OnSchemaChanged := MonacoSchemaChange;
  FMonacoEditor.OnInferenceLog := MonacoInferenceLog;
  FMonacoEditor.OnAuditSql := MonacoAuditSql;
  FMonacoEditor.OnStopRequest := MonacoStopRequest;

  BuildMyBaseControls;

  PControl.OnChange := PControlChange;
end;

procedure TFRpDInfoLCL.BuildDriverControls;
var
  LWidth: Integer;
begin
  // VCL PTop of TFRpConnectionVCL: drivers, their description and Configure
  PConnDriver := TPanel.Create(TabConnections);
  PConnDriver.Parent := TabConnections;
  PConnDriver.Align := alTop;
  PConnDriver.BevelOuter := bvNone;
  PConnDriver.Height := Scale96ToForm(104);
  PConnDriver.Top := ToolBarConn.Top + ToolBarConn.Height + 1;

  LDrivers := TListBox.Create(PConnDriver);
  LDrivers.Parent := PConnDriver;
  LDrivers.Align := alLeft;
  LDrivers.Width := Scale96ToScreen(210);
  GetFpcDatabaseDrivers(LDrivers.Items);
  LDrivers.OnClick := LDriversClick;

  PConnDriverInfo := TPanel.Create(PConnDriver);
  PConnDriverInfo.Parent := PConnDriver;
  PConnDriverInfo.Align := alClient;
  PConnDriverInfo.BevelOuter := bvNone;

  PConnDriverButtons := TPanel.Create(PConnDriverInfo);
  PConnDriverButtons.Parent := PConnDriverInfo;
  PConnDriverButtons.Align := alTop;
  PConnDriverButtons.BevelOuter := bvNone;
  PConnDriverButtons.Height := Scale96ToForm(32);

  BConfig := TButton.Create(PConnDriverButtons);
  BConfig.Parent := PConnDriverButtons;
  BConfig.Caption := TranslateStr(143, 'Configure');
  LWidth := RpCaptionWidth(BConfig, [BConfig.Caption], 120);
  BConfig.SetBounds(Scale96ToScreen(5), Scale96ToScreen(3), LWidth, Scale96ToForm(26));
  BConfig.OnClick := BConfigClick;

  MHelp := TMemo.Create(PConnDriverInfo);
  MHelp.Parent := PConnDriverInfo;
  MHelp.Align := alClient;
  MHelp.ReadOnly := True;
  MHelp.Color := clInfoBk;
  MHelp.Font.Color := clInfoText;
  MHelp.ScrollBars := ssAutoVertical;
  MHelp.WordWrap := True;

  // Zeos: the general SQL driver of the FPC build (the VCL selects dbExpress)
  SelectListDriver(rpdatazeos);
end;

procedure TFRpDInfoLCL.BuildMyBaseControls;
var
  LLabelWidth, LSearchWidth, LModifyWidth: Integer;
  LLeftPanel: TPanel;

  function NewRow(ATop: Integer): TPanel;
  begin
    Result := TPanel.Create(PMyBaseArea);
    Result.Parent := PMyBaseArea;
    Result.BevelOuter := bvNone;
    Result.Caption := '';
    // alTop rows are ordered by Top
    Result.SetBounds(0, ATop, Scale96ToScreen(400), Scale96ToForm(30));
    Result.Align := alTop;
  end;

  function NewLabel(ARow: TPanel; const ACaption: string): TLabel;
  begin
    Result := TLabel.Create(ARow);
    Result.Parent := ARow;
    Result.Caption := ACaption;
    Result.Layout := tlCenter;
    Result.AutoSize := False;
    Result.SetBounds(0, 0, LLabelWidth, Scale96ToScreen(20));
    Result.Align := alLeft;
    Result.BorderSpacing.Left := Scale96ToScreen(4);
  end;

  function NewEdit(ARow: TPanel): TEdit;
  begin
    Result := TEdit.Create(ARow);
    Result.Parent := ARow;
    Result.Align := alClient;
    Result.BorderSpacing.Around := Scale96ToScreen(3);
  end;

  function NewButton(ARow: TPanel; const ACaption: string; AWidth, ALeft: Integer;
    AClick: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(ARow);
    Result.Parent := ARow;
    Result.Caption := ACaption;
    // Fixed width (alRight buttons ordered by Left)
    Result.SetBounds(ALeft, 0, AWidth, Scale96ToScreen(24));
    Result.Align := alRight;
    Result.BorderSpacing.Around := Scale96ToScreen(3);
    Result.OnClick := AClick;
  end;

var
  LRow: TPanel;
  LButtonsWidth: Integer;
begin
  // VCL TabMyBase: shown instead of the SQL page for MyBase connections
  PMyBaseArea := TPanel.Create(PDSClient);
  PMyBaseArea.Parent := PDSClient;
  PMyBaseArea.Align := alClient;
  PMyBaseArea.BevelOuter := bvNone;
  PMyBaseArea.BorderWidth := Scale96ToScreen(4);
  PMyBaseArea.Visible := False;

  LLabelWidth := RpCaptionWidth(Self, [TranslateStr(167, 'MyBase Filename'),
    TranslateStr(1085, 'Field defs file'), TranslateStr(164, 'Index fields'),
    TranslateStr(165, 'Master fields')], 110);
  LSearchWidth := RpCaptionWidth(Self, [TranslateStr(168, 'Search...')], 80);
  LModifyWidth := RpCaptionWidth(Self, [TranslateStr(1086, 'Modify...')], 80);

  OpenDialogMyBase := TOpenDialog.Create(Self);
  OpenDialogMyBase.Filter := 'Mybase files|*.cds;*.xml|Text files|*.txt|All files|*.*|' +
    'Inifiles|*.ini';

  LRow := NewRow(0);
  LMyBase := NewLabel(LRow, TranslateStr(167, 'MyBase Filename'));
  BMyBase := NewButton(LRow, TranslateStr(168, 'Search...'), LSearchWidth, 1000, BMyBaseClick);
  EMyBase := NewEdit(LRow);

  LRow := NewRow(100);
  LFields := NewLabel(LRow, TranslateStr(1085, 'Field defs file'));
  BModify := NewButton(LRow, TranslateStr(1086, 'Modify...'), LModifyWidth, 1100, BModifyClick);
  BSearchFieldsFile := NewButton(LRow, TranslateStr(168, 'Search...'), LSearchWidth, 1000,
    BMyBaseClick);
  EMyBaseDefs := NewEdit(LRow);

  LRow := NewRow(200);
  LIndexFields := NewLabel(LRow, TranslateStr(164, 'Index fields'));
  EIndexFields := NewEdit(LRow);

  LRow := NewRow(300);
  LMasterFields := NewLabel(LRow, TranslateStr(165, 'Master fields'));
  EMasterFields := NewEdit(LRow);

  // VCL GUnions
  GUnions := TGroupBox.Create(PMyBaseArea);
  GUnions.Parent := PMyBaseArea;
  GUnions.Caption := TranslateStr(1082, 'Dataset client side unions');
  GUnions.Align := alClient;
  GUnions.BorderSpacing.Top := Scale96ToScreen(4);

  LLeftPanel := TPanel.Create(GUnions);
  LLeftPanel.Parent := GUnions;
  LLeftPanel.BevelOuter := bvNone;
  LLeftPanel.Caption := '';
  LLeftPanel.Align := alLeft;
  LButtonsWidth := Scale96ToForm(40);
  LLeftPanel.Width := Max(Scale96ToForm(210),
    RpCaptionWidth(Self, [TranslateStr(1440, 'Parallel union'),
    TranslateStr(1084, 'Union grouping')], 150) + Scale96ToForm(24)) + LButtonsWidth;

  LabelUnions := TLabel.Create(LLeftPanel);
  LabelUnions.Parent := LLeftPanel;
  LabelUnions.Caption := TranslateStr(1083, 'Unions');
  LabelUnions.SetBounds(Scale96ToScreen(4), Scale96ToScreen(4), Scale96ToScreen(150), Scale96ToScreen(18));

  ComboUnions := TComboBox.Create(LLeftPanel);
  ComboUnions.Parent := LLeftPanel;
  ComboUnions.Style := csDropDownList;
  ComboUnions.SetBounds(Scale96ToScreen(4), Scale96ToScreen(22), LLeftPanel.Width - LButtonsWidth - Scale96ToScreen(8), Scale96ToScreen(24));

  CheckParallelUnion := TCheckBox.Create(LLeftPanel);
  CheckParallelUnion.Parent := LLeftPanel;
  CheckParallelUnion.Caption := TranslateStr(1440, 'Parallel union');
  CheckParallelUnion.Hint := TranslateStr(1441, 'The columns of each table will be added, ' +
    'the resulting table will contain all the columns of all tables, and as much rows as ' +
    'the table with the maximum number of rows');
  CheckParallelUnion.ShowHint := True;
  CheckParallelUnion.SetBounds(Scale96ToScreen(4), Scale96ToScreen(54), LLeftPanel.Width - LButtonsWidth - Scale96ToScreen(8), Scale96ToScreen(20));

  CheckGroupUnion := TCheckBox.Create(LLeftPanel);
  CheckGroupUnion.Parent := LLeftPanel;
  CheckGroupUnion.Caption := TranslateStr(1084, 'Union grouping');
  CheckGroupUnion.SetBounds(Scale96ToScreen(4), Scale96ToScreen(78), LLeftPanel.Width - LButtonsWidth - Scale96ToScreen(8), Scale96ToScreen(20));

  BAddUnions := TButton.Create(LLeftPanel);
  BAddUnions.Parent := LLeftPanel;
  BAddUnions.Caption := '>';
  BAddUnions.SetBounds(LLeftPanel.Width - LButtonsWidth, Scale96ToScreen(20), LButtonsWidth - Scale96ToScreen(6), Scale96ToScreen(28));
  BAddUnions.OnClick := BAddUnionsClick;

  BDelUnions := TButton.Create(LLeftPanel);
  BDelUnions.Parent := LLeftPanel;
  BDelUnions.Caption := '<';
  BDelUnions.SetBounds(LLeftPanel.Width - LButtonsWidth, Scale96ToScreen(56), LButtonsWidth - Scale96ToScreen(6), Scale96ToScreen(28));
  BDelUnions.OnClick := BDelUnionsClick;

  LUnions := TListBox.Create(GUnions);
  LUnions.Parent := GUnions;
  LUnions.Align := alClient;
  LUnions.BorderSpacing.Around := Scale96ToScreen(2);
end;

procedure TFRpDInfoLCL.SetReport(Value: TRpReport);
begin
  FReport := Value;
  FApplied := False;
  FActiveConnIndex := -1;
  FActiveDSIndex := -1;
  // A new session: answers of earlier workers are dropped
  Inc(FSession);
  FTestRunning := False;
  FShowDataRunning := False;
  BTestConn.Enabled := True;
  // The connections file may have changed since the last session
  LoadConAdmin;

  FWork.DatabaseInfo.Clear;
  FWork.DataInfo.Clear;
  FWork.Params.Clear;
  FOrigDatabaseInfo.Clear;
  FOrigDataInfo.Clear;
  FOrigParams.Clear;
  if Assigned(FReport) then
  begin
    // Undo operations identify items by name
    EnsureReportItemNames(FReport);
    // Snapshot of the originals (undo comparison) and working copies
    FOrigDatabaseInfo.Assign(FReport.DatabaseInfo);
    FOrigDataInfo.Assign(FReport.DataInfo);
    FOrigParams.Assign(FReport.Params);
    FWork.DatabaseInfo.Assign(FReport.DatabaseInfo);
    FWork.DataInfo.Assign(FReport.DataInfo);
    FWork.Params.Assign(FReport.Params);
  end;

  RefreshConnList;
  RefreshDSList;

  if FWork.DataInfo.Count > 0 then
    PControl.ActivePage := TabDatasets
  else
    PControl.ActivePage := TabConnections;
end;

function TFRpDInfoLCL.UniqueItemName(const APrefix: string): string;
var
  n: Integer;
begin
  // Unique in the working copies and in the report (an item removed in this
  // session must not lend its name to a new one, undo would mix them)
  n := 1;
  repeat
    Result := APrefix + IntToStr(n);
    Inc(n);
  until (FWork.FindReporItemByName(Result) = nil) and
    ((not Assigned(FReport)) or (FReport.FindReporItemByName(Result) = nil));
end;

function TFRpDInfoLCL.CheckCanModify: Boolean;
begin
  Result := (not Assigned(FReport)) or FReport.CanModify('Database configuration');
end;

procedure TFRpDInfoLCL.RefreshConnList;
var
  i: Integer;
begin
  LConnections.Items.BeginUpdate;
  try
    LConnections.Clear;
    for i := 0 to FWork.DatabaseInfo.Count - 1 do
      LConnections.Items.Add(FWork.DatabaseInfo[i].Alias);
  finally
    LConnections.Items.EndUpdate;
  end;

  if LConnections.Count > 0 then
  begin
    LConnections.ItemIndex := 0;
    LoadConnDetails(0);
  end
  else
    LoadConnDetails(-1);
end;

procedure TFRpDInfoLCL.RefreshDSList;
var
  i: Integer;
begin
  LDatasets.Items.BeginUpdate;
  try
    LDatasets.Clear;
    for i := 0 to FWork.DataInfo.Count - 1 do
      LDatasets.Items.Add(FWork.DataInfo[i].Alias);
  finally
    LDatasets.Items.EndUpdate;
  end;

  if LDatasets.Count > 0 then
  begin
    LDatasets.ItemIndex := 0;
    LoadDSDetails(0);
  end
  else
    LoadDSDetails(-1);
end;

procedure TFRpDInfoLCL.RefreshConnCombos;
var
  i: Integer;
  curDSConn, curDSMaster: string;
begin
  curDSConn := ComboDSConn.Text;
  curDSMaster := ComboDSMaster.Text;

  ComboDSConn.Items.BeginUpdate;
  try
    ComboDSConn.Clear;
    ComboDSConn.Items.Add('');
    for i := 0 to FWork.DatabaseInfo.Count - 1 do
      ComboDSConn.Items.Add(FWork.DatabaseInfo[i].Alias);
  finally
    ComboDSConn.Items.EndUpdate;
  end;
  ComboDSConn.ItemIndex := ComboDSConn.Items.IndexOf(curDSConn);

  ComboDSMaster.Items.BeginUpdate;
  try
    ComboDSMaster.Clear;
    ComboDSMaster.Items.Add('');
    for i := 0 to FWork.DataInfo.Count - 1 do
    begin
      if (FActiveDSIndex < 0) or (i <> FActiveDSIndex) then
        ComboDSMaster.Items.Add(FWork.DataInfo[i].Alias);
    end;
  finally
    ComboDSMaster.Items.EndUpdate;
  end;
  ComboDSMaster.ItemIndex := ComboDSMaster.Items.IndexOf(curDSMaster);
end;

procedure TFRpDInfoLCL.SaveActiveConn;
var
  item: TRpDatabaseInfoItem;
  driver: TRpDbDriver;
begin
  if (FActiveConnIndex < 0) or (FActiveConnIndex >= FWork.DatabaseInfo.Count) then
    Exit;

  item := FWork.DatabaseInfo[FActiveConnIndex];
  if Trim(EConnAlias.Text) <> '' then
  begin
    item.Alias := Trim(EConnAlias.Text);
    if (FActiveConnIndex < LConnections.Count) and
       (LConnections.Items[FActiveConnIndex] <> item.Alias) then
      LConnections.Items[FActiveConnIndex] := item.Alias;
  end;

  if ComboDriverValue(driver) then
    item.Driver := driver;

  item.ConfigFile := EConfigFile.Text;
  item.LoginPrompt := CheckLoginPrompt.Checked;
  item.LoadParams := CheckLoadParams.Checked;
  item.LoadDriverParams := CheckLoadDriverParams.Checked;
end;

procedure TFRpDInfoLCL.SaveActiveDS;
var
  item: TRpDataInfoItem;
begin
  if (FActiveDSIndex < 0) or (FActiveDSIndex >= FWork.DataInfo.Count) then
    Exit;

  item := FWork.DataInfo[FActiveDSIndex];
  if Trim(EDSAlias.Text) <> '' then
  begin
    item.Alias := Trim(EDSAlias.Text);
    if (FActiveDSIndex < LDatasets.Count) and
       (LDatasets.Items[FActiveDSIndex] <> item.Alias) then
      LDatasets.Items[FActiveDSIndex] := item.Alias;
  end;

  item.DatabaseAlias := ComboDSConn.Text;
  item.DataSource := ComboDSMaster.Text;
  item.OpenOnStart := CheckOpenOnStart.Checked;
  if Assigned(FMonacoEditor) and FMonacoEditor.Visible then
    item.SQL := FMonacoEditor.SQL
  else
    item.SQL := MSQL.Text;
  // MyBase page (the unions are saved when added or removed)
  item.MyBaseFilename := EMyBase.Text;
  item.MyBaseFields := EMyBaseDefs.Text;
  item.MyBaseIndexFields := EIndexFields.Text;
  item.MyBaseMasterFields := EMasterFields.Text;
  item.GroupUnion := CheckGroupUnion.Checked;
  item.ParallelUnion := CheckParallelUnion.Checked;
end;

procedure TFRpDInfoLCL.SaveControls;
begin
  SaveActiveConn;
  SaveActiveDS;
end;

procedure TFRpDInfoLCL.MonacoContentChanged(Sender: TObject);
var
  item: TRpDataInfoItem;
begin
  if FUpdatingControls then Exit;
  if Assigned(FMonacoEditor) then
  begin
    MSQL.Text := FMonacoEditor.SQL;
    // VCL MSQLChange(FMonaco): the chat refines the SQL being edited
    if FChat <> nil then
      FChat.SetCurrentExpression(FMonacoEditor.SQL);
    item := ActiveDataInfo;
    if item <> nil then
      FMonacoEditor.AuditText := item.SQLExplanation;
  end;
end;

procedure TFRpDInfoLCL.MSQLChange(Sender: TObject);
begin
  // The plain text editor ("Monaco / Text")
  if FUpdatingControls or (not MSQL.Visible) then Exit;
  if FChat <> nil then
    FChat.SetCurrentExpression(MSQL.Text);
end;

procedure TFRpDInfoLCL.ComboDSConnChange(Sender: TObject);
var
  item: TRpDataInfoItem;
  previousAlias: string;
begin
  // VCL MSQLChange(ComboConnection): the Hub context follows the connection
  if FUpdatingControls then Exit;
  item := ActiveDataInfo;
  if item = nil then Exit;
  previousAlias := item.DatabaseAlias;
  item.DatabaseAlias := ComboDSConn.Text;
  if not SameText(previousAlias, item.DatabaseAlias) then
  begin
    // The subschema was of the other connection, and a direct connection
    // never has a Hub schema
    item.SchemaName := '';
    if RpIsLocalSqlDatabase(DatabaseInfoOf(item)) then
      item.HubSchemaId := 0;
  end;
  if (item.HubSchemaId = 0) and (not SameText(previousAlias, item.DatabaseAlias)) then
    item.HubSchemaId := FindSiblingHubSchemaId(item);
  // SQL or MyBase page (VCL UpdateConnectionDependentUi)
  UpdateConnectionDependentUi(item);
  if FWork.DatabaseInfo.IndexOf(item.DatabaseAlias) < 0 then
  begin
    FMonacoEditor.SetHubContext(0, 0);
    if FChat <> nil then
    begin
      UpdateChatLocalSchemas(nil, False);
      FChat.SetHubContext(0, 0);
    end;
    Exit;
  end;
  ApplyActiveDataInfoContext(False);
end;

procedure TFRpDInfoLCL.PControlChange(Sender: TObject);
begin
  // The datasets follow the changes of the connections (new, renamed,
  // driver): VCL PControlChange assigns the connections to the datasets frame
  SaveActiveConn;
  SaveActiveDS;
  if PControl.ActivePage = TabDatasets then
    LoadDSDetails(FActiveDSIndex);
  // VCL DatasetPageChanged
  if (PControl.ActivePage = TabDatasets) and (FActiveDSIndex >= 0) then
    EnsureAdvancedEditors;
end;

procedure TFRpDInfoLCL.UpdateConnectionDependentUi(AItem: TRpDataInfoItem);
var
  index: Integer;
  isMyBase: Boolean;
begin
  index := -1;
  if AItem <> nil then
    index := FWork.DatabaseInfo.IndexOf(AItem.DatabaseAlias);
  BShowData.Enabled := (index >= 0) and (not FShowDataRunning);
  isMyBase := (index >= 0) and (FWork.DatabaseInfo[index].Driver = rpdatamybase);
  // The MyBase page replaces the SQL one (VCL TabMyBase / TabSQL)
  PMyBaseArea.Visible := isMyBase;
  PSQLArea.Visible := not isMyBase;
end;

{ SQL assistant }

function TFRpDInfoLCL.ActiveDataInfo: TRpDataInfoItem;
begin
  Result := nil;
  if (FActiveDSIndex >= 0) and (FActiveDSIndex < FWork.DataInfo.Count) then
    Result := FWork.DataInfo[FActiveDSIndex];
end;

function TFRpDInfoLCL.CurrentSQL: string;
begin
  if Assigned(FMonacoEditor) and FMonacoEditor.Visible then
    Result := FMonacoEditor.SQL
  else
    Result := MSQL.Text;
end;

function TFRpDInfoLCL.FindSiblingHubSchemaId(ADataInfo: TRpDataInfoItem): Int64;
var
  i: Integer;
  item: TRpDataInfoItem;
begin
  // The schema of another dataset of the same connection
  Result := 0;
  if (ADataInfo = nil) or (ADataInfo.DatabaseAlias = '') then
    Exit;
  // A direct connection is not in the Hub: never a Hub schema
  if RpIsLocalSqlDatabase(DatabaseInfoOf(ADataInfo)) then
    Exit;
  for i := 0 to FWork.DataInfo.Count - 1 do
  begin
    item := FWork.DataInfo[i];
    if (item <> ADataInfo) and SameText(item.DatabaseAlias, ADataInfo.DatabaseAlias) and
      (item.HubSchemaId > 0) then
      Exit(item.HubSchemaId);
  end;
end;

function TFRpDInfoLCL.ResolveNlToSqlRuntime(ADataInfo: TRpDataInfoItem): string;
var
  index: Integer;
  dbinfo: TRpDatabaseInfoItem;
  params: TStringList;
  hubDatabaseId: Int64;
begin
  // The SQL flavour the server writes: .Net for the Hub/.Net connections
  Result := '';
  if (ADataInfo = nil) or (Trim(ADataInfo.DatabaseAlias) = '') then
    Exit;
  index := FWork.DatabaseInfo.IndexOf(ADataInfo.DatabaseAlias);
  if index < 0 then
    Exit;
  dbinfo := FWork.DatabaseInfo[index];
  if dbinfo.Driver in [rpdatadriver, rpdotnet2driver] then
    Exit('ADO_Net');
  params := TStringList.Create;
  try
    dbinfo.UpdateConAdmin;
    dbinfo.ConAdmin.GetConnectionParams(dbinfo.Alias, params);
    hubDatabaseId := StrToInt64Def(params.Values['HubDatabaseId'], 0);
  finally
    params.Free;
  end;
  if hubDatabaseId > 0 then
    Result := 'ADO_Net'
  else
    Result := 'Delphi';
end;

function TFRpDInfoLCL.GetUserLanguageCode: string;
begin
  Result := TRpAuthManager.Instance.AILanguage;
end;

procedure TFRpDInfoLCL.EnsureAdvancedEditors;
begin
  if FChat = nil then
  begin
    FChat := TFRpChatFrame.Create(Self);
    FChat.Parent := PChatHost;
    FChat.Align := alClient;
    FChat.Initialize('', TranslateStr(1556, 'Write your query in natural language. ' +
      'A new SQL query will be generated based on the current SQL and the selected ' +
      'schema. Click ''Apply'' to use the generated SQL.'));
    FChat.OnApplySuggestion := ChatApplySuggestion;
    FChat.OnSchemaChanged := ChatSchemaChange;
    FChat.OnSendPrompt := ChatSendPrompt;
    FChat.OnStopRequest := ChatStopRequest;
    FChat.OnConfigureLocalSchemas := ChatConfigureLocalSchemas;
    FChat.StartOnlineInitialization;
  end;
  ApplyActiveDataInfoContext(True);
end;

procedure TFRpDInfoLCL.ApplyActiveDataInfoContext(ASyncSqlFromDataInfo: Boolean;
  const ASchemaApiKeyOverride: string);
var
  item: TRpDataInfoItem;
  dbinfo: TRpDatabaseInfoItem;
  params: TStringList;
  index: Integer;
  hubDatabaseId, hubSchemaId: Int64;
  schemaApiKey, runtimeDb, schemaName: string;
begin
  // The Hub database of the connection (dbxconnections params) and the
  // schema of the dataset, for the editor and the chat
  item := ActiveDataInfo;
  if item = nil then
    Exit;
  hubDatabaseId := 0;
  hubSchemaId := 0;
  schemaApiKey := '';
  runtimeDb := ResolveNlToSqlRuntime(item);
  dbinfo := nil;
  if Trim(item.DatabaseAlias) <> '' then
  begin
    index := FWork.DatabaseInfo.IndexOf(item.DatabaseAlias);
    if index >= 0 then
      dbinfo := FWork.DatabaseInfo[index];
  end;
  if dbinfo <> nil then
  begin
    hubSchemaId := item.HubSchemaId;
    params := TStringList.Create;
    try
      dbinfo.UpdateConAdmin;
      dbinfo.ConAdmin.GetConnectionParams(dbinfo.Alias, params);
      hubDatabaseId := StrToInt64Def(params.Values['HubDatabaseId'], 0);
      schemaApiKey := Trim(params.Values['ApiKey']);
    finally
      params.Free;
    end;
  end;
  if ASchemaApiKeyOverride <> '' then
    schemaApiKey := ASchemaApiKeyOverride;

  FMonacoEditor.SetHubContext(hubDatabaseId, hubSchemaId, schemaApiKey);
  FMonacoEditor.RuntimeDb := runtimeDb;
  if ASyncSqlFromDataInfo then
    FMonacoEditor.AuditText := item.SQLExplanation;

  if FChat <> nil then
  begin
    if ASyncSqlFromDataInfo then
      FChat.SetCurrentExpression(item.SQL)
    else
      FChat.SetCurrentExpression(CurrentSQL);
    // A direct connection: its local schemas, with the subschema of the
    // dataset while it is in the file (else all the tables)
    UpdateChatLocalSchemas(dbinfo, False);
    if RpIsLocalSqlDatabase(dbinfo) then
    begin
      FChat.SetHubContext(0, 0, '');
      schemaName := RpExistingLocalSubSchema(dbinfo, item.SchemaName);
      if not (SameText(FChat.GetLocalSchemaAlias, dbinfo.Alias) and
        SameText(FChat.GetLocalSchemaName, schemaName)) then
        FChat.SelectLocalSchema(dbinfo.Alias, schemaName);
    end
    else
      FChat.SetHubContext(hubDatabaseId, hubSchemaId, schemaApiKey);
  end;
end;

function TFRpDInfoLCL.DatabaseInfoOf(ADataInfo: TRpDataInfoItem): TRpDatabaseInfoItem;
var
  index: Integer;
begin
  Result := nil;
  if (ADataInfo = nil) or (Trim(ADataInfo.DatabaseAlias) = '') then
    Exit;
  index := FWork.DatabaseInfo.IndexOf(ADataInfo.DatabaseAlias);
  if index >= 0 then
    Result := FWork.DatabaseInfo[index];
end;

// The local schemas of the connection of the dataset in the chat; none for
// the other connections
procedure TFRpDInfoLCL.UpdateChatLocalSchemas(ADatabaseInfo: TRpDatabaseInfoItem;
  AForce: Boolean);
var
  alias: string;
  entries, sizes: TStringList;
begin
  if FChat = nil then
    Exit;
  alias := '';
  if RpIsLocalSqlDatabase(ADatabaseInfo) then
    alias := ADatabaseInfo.Alias;
  if (not AForce) and SameText(alias, FChatLocalAlias) then
    Exit;
  FChatLocalAlias := alias;
  entries := TStringList.Create;
  sizes := TStringList.Create;
  try
    if alias <> '' then
      RpListLocalSchemaEntries(ADatabaseInfo, entries, sizes);
    FChat.SetLocalSchemas(entries, alias, sizes);
  finally
    sizes.Free;
    entries.Free;
  end;
end;

procedure TFRpDInfoLCL.ChatConfigureLocalSchemas(Sender: TObject;
  const AAlias, ASchemaName: string; AAddNew: Boolean);
var
  schemaName: string;
  saved: Boolean;
begin
  schemaName := ASchemaName;
  saved := False;
  try
    saved := RpShowLocalSchemasDialog(FWork, AAlias, schemaName, AAddNew, FChat);
  finally
    UpdateChatLocalSchemas(DatabaseInfoOf(ActiveDataInfo), True);
  end;
  // The subschema saved (a new one: the one added); the chat gives it to
  // the dataset (ChatSchemaChange)
  if saved then
    FChat.SelectLocalSchema(AAlias, schemaName);
end;

// The config of NL to SQL with the schema of a direct connection inline
function TFRpDInfoLCL.ChatInlineConfigJson(const AAlias, ASchemaName: string): string;
var
  config: TRpApiDatabaseConfig;
  cursor: TCursor;
  databases: TRpDatabaseInfoList;
  index: Integer;
  json: TJSONObject;
begin
  index := FWork.DatabaseInfo.IndexOf(AAlias);
  if index < 0 then
    raise Exception.Create('The report has no connection ' + AAlias);
  config := TRpApiDatabaseConfig.Create;
  // A copy: the dialog may have the connection open (Show data)
  databases := RpCopyDatabaseInfo(FWork.DatabaseInfo[index]);
  cursor := Screen.Cursor;
  Screen.Cursor := crHourGlass;
  try
    config.LocalAlias := AAlias;
    config.LocalSchemaName := ASchemaName;
    // The schema file is generated the first time
    RpResolveLocalSchemaConfig(config, databases.Items[0], FWork.Params);
    json := config.ToJsonObject;
    try
      Result := json.ToJSON;
    finally
      json.Free;
    end;
  finally
    Screen.Cursor := cursor;
    databases.Free;
    config.Free;
  end;
end;

procedure TFRpDInfoLCL.SyncActiveSchemaContext(AHubDatabaseId, AHubSchemaId: Int64;
  const ASchemaApiKey: string);
var
  item: TRpDataInfoItem;
begin
  item := ActiveDataInfo;
  if item = nil then
    Exit;
  // A dataset on a direct connection never gets a Hub schema (the Hub list
  // of the editor or of the chat falls back to one of another database)
  if RpIsLocalSqlDatabase(DatabaseInfoOf(item)) then
    Exit;
  FSyncingSchemaContext := True;
  try
    // Kept in the working copy: OK records it (hubSchemaId)
    item.HubSchemaId := AHubSchemaId;
    ApplyActiveDataInfoContext(False, ASchemaApiKey);
  finally
    FSyncingSchemaContext := False;
  end;
end;

procedure TFRpDInfoLCL.MonacoSchemaChange(Sender: TObject);
begin
  if FSyncingSchemaContext or (FMonacoEditor = nil) then
    Exit;
  SyncActiveSchemaContext(FMonacoEditor.HubDatabaseId, FMonacoEditor.HubSchemaId,
    FMonacoEditor.GetSchemaApiKey);
end;

procedure TFRpDInfoLCL.ChatSchemaChange(Sender: TObject);
var
  item: TRpDataInfoItem;
  dbinfo: TRpDatabaseInfoItem;
begin
  if FSyncingSchemaContext or (FChat = nil) then
    Exit;
  // A direct connection keeps the subschema chosen (D3) and never takes a
  // Hub schema; loading the list is not a choice of the user
  item := ActiveDataInfo;
  dbinfo := DatabaseInfoOf(item);
  if RpIsLocalSqlDatabase(dbinfo) then
  begin
    if (not FChat.SchemaChangeFromLoad) and
      SameText(FChat.GetLocalSchemaAlias, dbinfo.Alias) and
      (item.SchemaName <> FChat.GetLocalSchemaName) then
      // Kept in the working copy: OK records it (schemaName)
      item.SchemaName := FChat.GetLocalSchemaName;
    Exit;
  end;
  // The chat also calls this after loading its list; an empty list (not
  // logged in, no network) is not a choice of the user and must not reset
  // the schema of the dataset (the VCL does)
  if (not FChat.HasSchemaItems) and (FChat.GetHubSchemaId = 0) then
    Exit;
  // Nor may the fallback of a list without the schema of the dataset (another
  // account, no access) replace it: only a choice of the user does
  if FChat.SchemaChangeFromLoad and (ActiveDataInfo <> nil) and
    (ActiveDataInfo.HubSchemaId <> 0) and
    (ActiveDataInfo.HubSchemaId <> FChat.GetHubSchemaId) then
    Exit;
  SyncActiveSchemaContext(FChat.GetHubDatabaseId, FChat.GetHubSchemaId,
    FChat.GetSchemaApiKey);
end;

procedure TFRpDInfoLCL.MonacoInferenceLog(Sender: TObject; const ASource,
  AText: string; AAppendLineBreak: Boolean);
begin
  if FChat = nil then
    Exit;
  if ASource <> '' then
    FChat.AppendLogLine('[' + ASource + '] ' + AText)
  else
    FChat.AppendLogChunk(AText, AAppendLineBreak);
end;

procedure TFRpDInfoLCL.MonacoStopRequest(Sender: TObject);
begin
  // The running audit stops; its answer is not stored
  if FAuditCancel = nil then
    Exit;
  FAuditCancel.Cancel;
  FAuditCancel := nil;
  if FMonacoEditor <> nil then
  begin
    FMonacoEditor.SetAuditBusy(False);
    FMonacoEditor.AppendLog('Audit SQL stopped.');
  end;
end;

procedure TFRpDInfoLCL.ChatStopRequest(Sender: TObject);
begin
  Inc(FChatRequestVersion);
  if FChatCancel <> nil then
    FChatCancel.Cancel;
  FChatCancel := nil;
  if FChat <> nil then
  begin
    FChat.FinishStreamingResponse;
    FChat.AddAssistantMessage(TranslateStr(1536, 'Generation stopped.'));
  end;
end;

procedure TFRpDInfoLCL.ChatApplySuggestion(Sender: TObject; const AExpression: string);
var
  item: TRpDataInfoItem;
begin
  if not CheckCanModify then
    Exit;
  EnsureAdvancedEditors;
  item := ActiveDataInfo;
  if item = nil then
    Exit;
  // An edit the user can undo in the editor; the working copy gets it now
  // and OK records it in the undo cue like any other SQL change
  FMonacoEditor.ApplySQL(AExpression);
  FUpdatingControls := True;
  try
    MSQL.Text := FMonacoEditor.SQL;
  finally
    FUpdatingControls := False;
  end;
  item.SQL := FMonacoEditor.SQL;
  FMonacoEditor.AuditText := item.SQLExplanation;
  if FChat <> nil then
  begin
    FChat.SetCurrentExpression(FMonacoEditor.SQL);
    FChat.AddAssistantMessage(TranslateStr(1557, 'SQL applied to the editor.'));
  end;
end;

procedure TFRpDInfoLCL.ChatSendPrompt(Sender: TObject; const APrompt,
  AExpression: string);
var
  prompt, sqlToRefine, inlineConfig: string;
  worker: TRpSqlChatWorker;
begin
  if FChat = nil then
    Exit;
  prompt := Trim(APrompt);
  if prompt = '' then
    Exit;
  // A direct connection: its local schema (the subschema chosen) travels
  // inline instead of a Hub schema
  inlineConfig := '';
  if FChat.GetLocalSchemaAlias <> '' then
  begin
    try
      inlineConfig := ChatInlineConfigJson(FChat.GetLocalSchemaAlias,
        FChat.GetLocalSchemaName);
    except
      on E: Exception do
      begin
        FChat.AddAssistantMessage(E.Message);
        Exit;
      end;
    end;
  end;

  // A new request supersedes the running one
  Inc(FChatRequestVersion);
  if FChatCancel <> nil then
    FChatCancel.Cancel;
  FChatCancel := TRpAsyncCancel.Create;
  sqlToRefine := Trim(AExpression);
  if sqlToRefine = '' then
    sqlToRefine := Trim(CurrentSQL);

  FChat.BeginStreamingResponse;
  if sqlToRefine <> '' then
    FChat.AppendLogLine('[Chat] Starting SQL refine request...')
  else
    FChat.AppendLogLine('[Chat] Starting NLToSQL request...');

  worker := TRpSqlChatWorker.Create(FMailboxRef);
  worker.RequestVersion := FChatRequestVersion;
  worker.Cancel := FChatCancel;
  worker.Prompt := prompt;
  worker.SqlToRefine := sqlToRefine;
  worker.Token := TRpAuthManager.Instance.Token;
  worker.InstallId := TRpAuthManager.Instance.InstallId;
  worker.HubDatabaseId := FChat.GetHubDatabaseId;
  worker.HubSchemaId := FChat.GetHubSchemaId;
  worker.InlineConfigJson := inlineConfig;
  if inlineConfig <> '' then
  begin
    worker.HubDatabaseId := 0;
    worker.HubSchemaId := 0;
  end;
  worker.ApiKey := FChat.GetSchemaApiKey;
  worker.RuntimeDb := ResolveNlToSqlRuntime(ActiveDataInfo);
  worker.AITier := FChat.GetAITier;
  worker.AIMode := FChat.GetAIMode;
  worker.AgentSecret := FChat.GetAgentSecret;
  worker.AgentAiId := FChat.GetAgentAiId;
  worker.UserLanguage := GetUserLanguageCode;
  worker.Start;
end;

procedure TFRpDInfoLCL.MonacoAuditSql(Sender: TObject);
var
  item: TRpDataInfoItem;
  sql: string;
  worker: TRpSqlAuditWorker;
begin
  if FMonacoEditor = nil then
    Exit;
  item := ActiveDataInfo;
  if item = nil then
    Exit;
  sql := CurrentSQL;
  if Trim(sql) = '' then
  begin
    FMonacoEditor.ActivateAuditTab;
    FMonacoEditor.AppendLog('Audit SQL skipped: SQL is empty.');
    Exit;
  end;

  FMonacoEditor.ActivateAuditTab;
  FMonacoEditor.SetAuditBusy(True);
  FMonacoEditor.ClearLog;
  FMonacoEditor.AppendLog('Starting SQL audit...');

  if FAuditCancel <> nil then
    FAuditCancel.Cancel;
  FAuditCancel := TRpAsyncCancel.Create;
  worker := TRpSqlAuditWorker.Create(FMailboxRef);
  worker.Cancel := FAuditCancel;
  // The explanation goes to this dataset even if another one is selected
  // when it arrives (the VCL uses the selected one)
  worker.DataInfoName := item.Name;
  worker.Sql := sql;
  worker.Token := TRpAuthManager.Instance.Token;
  worker.InstallId := TRpAuthManager.Instance.InstallId;
  worker.HubDatabaseId := FMonacoEditor.HubDatabaseId;
  worker.HubSchemaId := FMonacoEditor.HubSchemaId;
  worker.RuntimeDb := ResolveNlToSqlRuntime(item);
  worker.AITier := FMonacoEditor.AITier;
  worker.AIMode := FMonacoEditor.AIMode;
  worker.AgentSecret := FMonacoEditor.AgentSecret;
  worker.AgentAiId := FMonacoEditor.AgentAiId;
  worker.UserLanguage := GetUserLanguageCode;
  worker.Start;
end;

procedure TFRpDInfoLCL.HandleAsyncMessage(AMessage: TRpAsyncMessage);
var
  progress: TRpSqlStreamProgress;
  chatResult: TRpSqlChatResult;
  auditResult: TRpSqlAuditResult;
  profile: TJSONValue;
  item: TRpDataInfoItem;
  i: Integer;
  testResult: TRpConnectionTestResult;
  showResult: TRpShowDataResult;
  dataset: TDataset;
begin
  if AMessage is TRpConnectionTestResult then
  begin
    // Connect (VCL BTestClick)
    testResult := TRpConnectionTestResult(AMessage);
    if (testResult.Session <> FSession) or (testResult.RequestVersion <> FTestVersion) then
      Exit;
    FTestRunning := False;
    BTestConn.Enabled := True;
    ShowInfo(testResult.MessageText, not testResult.Success);
  end
  else if AMessage is TRpShowDataResult then
  begin
    // Show data: the message frees the copy (and closes it) afterwards
    showResult := TRpShowDataResult(AMessage);
    if (showResult.Session <> FSession) or (showResult.RequestVersion <> FShowDataVersion) then
      Exit;
    FShowDataRunning := False;
    UpdateConnectionDependentUi(ActiveDataInfo);
    if showResult.ErrorMessage <> '' then
    begin
      if Assigned(FOnShowDataset) then
        FOnShowDataset(Self, nil, showResult.ErrorMessage)
      else
        ShowInfo(showResult.ErrorMessage, True);
      Exit;
    end;
    dataset := showResult.Report.DataInfo.Items[showResult.DataInfoIndex].Dataset;
    if Assigned(FOnShowDataset) then
      FOnShowDataset(Self, dataset, '')
    else
      ShowDataset(dataset);
  end
  else if AMessage is TRpSqlChatProgress then
  begin
    // VCL ChatTranslateProgress
    progress := TRpSqlStreamProgress(AMessage);
    if (FChat = nil) or (progress.RequestVersion <> FChatRequestVersion) then
      Exit;
    if SameText(progress.Stage, 'ReceivingResponse') then
    begin
      if (progress.Chunk <> '') or (progress.PrefillPercent > 0) then
        FChat.UpdateStreamingResponse(progress.Actor, progress.ChunkType,
          progress.Chunk, progress.PrefillPercent, '', progress.ProgressId);
      FChat.UpdateStreamingTokens(progress.InputTokens, progress.OutputTokens,
        progress.ProgressId, progress.PrefillPercent);
      FChat.CompleteStreamingProgress(progress.Actor, progress.ChunkType,
        progress.ProgressId);
    end
    else if SameText(progress.Stage, 'Queued') then
      // The wait in the AI provider's queue: one log line, rewritten
      FChat.UpdateStreamingResponse(progress.Actor, 'Full', '', 0,
        progress.Chunk, progress.ProgressId)
    else if progress.Chunk <> '' then
      FChat.AppendLogLine('[' + progress.Stage + '] ' + progress.Chunk);
  end
  else if AMessage is TRpSqlChatResult then
  begin
    chatResult := TRpSqlChatResult(AMessage);
    if (FChat = nil) or (chatResult.RequestVersion <> FChatRequestVersion) then
      Exit;
    FChatCancel := nil;
    if chatResult.UserProfileJson <> '' then
    begin
      profile := TJSONObject.ParseJSONValue(chatResult.UserProfileJson);
      try
        if profile is TJSONObject then
          FChat.UpdateUserProfile(TJSONObject(profile));
      finally
        profile.Free;
      end;
    end;
    if Trim(chatResult.ErrorMessage) <> '' then
    begin
      FChat.FinishStreamingResponse;
      FChat.AddAssistantMessage(chatResult.ErrorMessage);
      Exit;
    end;
    if Trim(chatResult.Sql) = '' then
    begin
      FChat.FinishStreamingResponse;
      FChat.AddAssistantMessage(TranslateStr(1558, 'No SQL was returned by the service.'));
      Exit;
    end;
    FChat.SetSuggestedContent(chatResult.Sql, chatResult.Explanation,
      TranslateStr(1559, 'Suggested SQL'));
  end
  else if AMessage is TRpSqlAuditProgress then
  begin
    // VCL MonacoAuditProgress
    progress := TRpSqlStreamProgress(AMessage);
    FMonacoEditor.UpdateAITokens(progress.InputTokens, progress.OutputTokens,
      progress.ProgressId, progress.PrefillPercent);
    if SameText(progress.Stage, 'ReceivingResponse') and (progress.Chunk <> '') then
      FMonacoEditor.AppendLog(progress.Chunk)
    else if progress.Chunk <> '' then
      FMonacoEditor.AppendLog('[' + progress.Stage + '] ' + progress.Chunk);
  end
  else if AMessage is TRpSqlAuditResult then
  begin
    auditResult := TRpSqlAuditResult(AMessage);
    // Posted just before a stop: dropped
    if FAuditCancel = nil then
      Exit;
    FAuditCancel := nil;
    try
      item := nil;
      for i := 0 to FWork.DataInfo.Count - 1 do
        if SameText(FWork.DataInfo[i].Name, auditResult.DataInfoName) then
        begin
          item := FWork.DataInfo[i];
          Break;
        end;
      if item <> nil then
      begin
        if Trim(auditResult.ErrorMessage) = '' then
        begin
          item.SQLExplanation := auditResult.Explanation;
          item.SQLExplanationError := '';
          if item = ActiveDataInfo then
            FMonacoEditor.AuditText := auditResult.Explanation;
          if auditResult.InputTokens > 0 then
            FMonacoEditor.AppendLog('Audit SQL complete. Input Tokens: ' +
              IntToStr(auditResult.InputTokens) + ' Output Tokens: ' +
              IntToStr(auditResult.OutputTokens))
          else
            FMonacoEditor.AppendLog('Audit SQL complete.');
        end
        else
        begin
          item.SQLExplanation := '';
          item.SQLExplanationError := auditResult.ErrorMessage;
          if item = ActiveDataInfo then
            FMonacoEditor.AuditText := '';
          FMonacoEditor.AppendLog('Audit SQL error: ' + auditResult.ErrorMessage);
        end;
      end;
      if auditResult.UserProfileJson <> '' then
      begin
        profile := TJSONObject.ParseJSONValue(auditResult.UserProfileJson);
        try
          if profile is TJSONObject then
            TRpAuthManager.Instance.UpdateProfileFromJson(TJSONObject(profile));
        finally
          profile.Free;
        end;
      end;
    finally
      FMonacoEditor.SetAuditBusy(False);
    end;
  end;
end;

procedure TFRpDInfoLCL.BMonacoToggleClick(Sender: TObject);
begin
  if Assigned(FMonacoEditor) and FMonacoEditor.Visible then
  begin
    MSQL.Text := FMonacoEditor.SQL;
    FMonacoEditor.Visible := False;
    MSQL.Visible := True;
  end
  else
  begin
    if Assigned(FMonacoEditor) then
      FMonacoEditor.SQL := MSQL.Text;
    MSQL.Visible := False;
    if Assigned(FMonacoEditor) then
      FMonacoEditor.Visible := True;
  end;
end;

procedure TFRpDInfoLCL.BThemeToggleClick(Sender: TObject);
begin
  FIsDarkTheme := not FIsDarkTheme;
  if Assigned(FMonacoEditor) then
  begin
    if FIsDarkTheme then
      FMonacoEditor.SetTheme('vs-dark')
    else
      FMonacoEditor.SetTheme('vs');
  end;
end;

procedure TFRpDInfoLCL.LoadConnDetails(Index: Integer);
var
  item: TRpDatabaseInfoItem;
begin
  FUpdatingControls := True;
  try
    FActiveConnIndex := Index;
    // No connections: the connection wizard instead of the properties
    PConnEmpty.Visible := FWork.DatabaseInfo.Count = 0;
    PConnProps.Visible := not PConnEmpty.Visible;
    if (Index < 0) or (Index >= FWork.DatabaseInfo.Count) then
      UpdateAgentProblem(nil)
    else
      UpdateAgentProblem(FWork.DatabaseInfo[Index]);
    if (Index < 0) or (Index >= FWork.DatabaseInfo.Count) then
    begin
      FActiveConnIndex := -1;
      EConnAlias.Text := '';
      FillDriverCombo(SelectedListDriver);
      ComboDriver.ItemIndex := -1;
      EConfigFile.Text := '';
      CheckLoginPrompt.Checked := False;
      CheckLoadParams.Checked := False;
      CheckLoadDriverParams.Checked := False;
      PConnProps.Enabled := False;
      BDelConn.Enabled := False;
      Exit;
    end;

    PConnProps.Enabled := True;
    BDelConn.Enabled := True;
    item := FWork.DatabaseInfo[Index];
    EConnAlias.Text := item.Alias;
    FillDriverCombo(item.Driver);
    EConfigFile.Text := item.ConfigFile;
    CheckLoginPrompt.Checked := item.LoginPrompt;
    CheckLoadParams.Checked := item.LoadParams;
    CheckLoadDriverParams.Checked := item.LoadDriverParams;
  finally
    FUpdatingControls := False;
  end;
end;

procedure TFRpDInfoLCL.FillDriverCombo(ADriver: TRpDbDriver);
var
  i: Integer;
begin
  ComboDriver.Items.BeginUpdate;
  try
    GetFpcDatabaseDrivers(ComboDriver.Items);
    // A driver the FPC build does not have stays listed for the connection
    // that uses it: opening a report must not change it
    if not IsFpcDriverAvailable(ADriver) then
      ComboDriver.Items.AddObject(FpcDriverName(ADriver) + ' (' +
        TranslateStr(1036, 'Not available') + ')', TObject(PtrInt(Ord(ADriver))));
  finally
    ComboDriver.Items.EndUpdate;
  end;
  ComboDriver.ItemIndex := -1;
  for i := 0 to ComboDriver.Items.Count - 1 do
    if PtrInt(ComboDriver.Items.Objects[i]) = Ord(ADriver) then
    begin
      ComboDriver.ItemIndex := i;
      Break;
    end;
end;

function TFRpDInfoLCL.ComboDriverValue(out ADriver: TRpDbDriver): Boolean;
begin
  Result := ComboDriver.ItemIndex >= 0;
  if Result then
    ADriver := TRpDbDriver(PtrInt(ComboDriver.Items.Objects[ComboDriver.ItemIndex]))
  else
    ADriver := rpdatadbexpress;
end;

procedure TFRpDInfoLCL.LoadDSDetails(Index: Integer);
var
  item: TRpDataInfoItem;
begin
  FUpdatingControls := True;
  try
    FActiveDSIndex := Index;
    if (Index < 0) or (Index >= FWork.DataInfo.Count) then
      FActiveDSIndex := -1;
    RefreshConnCombos;

    if FActiveDSIndex < 0 then
    begin
      EDSAlias.Text := '';
      ComboDSConn.ItemIndex := -1;
      ComboDSMaster.ItemIndex := -1;
      CheckOpenOnStart.Checked := True;
      MSQL.Clear;
      if Assigned(FMonacoEditor) then
      begin
        FMonacoEditor.SQL := '';
        FMonacoEditor.AuditText := '';
        FMonacoEditor.SetHubContext(0, 0);
      end;
      if FChat <> nil then
      begin
        FChat.SetCurrentExpression('');
        UpdateChatLocalSchemas(nil, False);
        FChat.SetHubContext(0, 0);
      end;
      EMyBase.Text := '';
      EMyBaseDefs.Text := '';
      EIndexFields.Text := '';
      EMasterFields.Text := '';
      LUnions.Clear;
      ComboUnions.Clear;
      CheckGroupUnion.Checked := False;
      CheckParallelUnion.Checked := False;
      UpdateConnectionDependentUi(nil);
      PDSProps.Enabled := False;
      PSQLArea.Enabled := False;
      PMyBaseArea.Enabled := False;
      BDelDS.Enabled := False;
      BtnUpDS.Enabled := False;
      BtnDownDS.Enabled := False;
      BtnRenameDS.Enabled := False;
      // The parameters button stays usable without datasets
      BParams.Enabled := True;
      Exit;
    end;

    PDSProps.Enabled := True;
    PSQLArea.Enabled := True;
    PMyBaseArea.Enabled := True;
    BDelDS.Enabled := True;
    BtnUpDS.Enabled := (Index > 0);
    BtnDownDS.Enabled := (Index < FWork.DataInfo.Count - 1);
    BtnRenameDS.Enabled := True;
    item := FWork.DataInfo[Index];
    EDSAlias.Text := item.Alias;
    ComboDSConn.ItemIndex := ComboDSConn.Items.IndexOf(item.DatabaseAlias);
    ComboDSMaster.ItemIndex := ComboDSMaster.Items.IndexOf(item.DataSource);
    CheckOpenOnStart.Checked := item.OpenOnStart;
    MSQL.Text := item.SQL;
    if Assigned(FMonacoEditor) then
      FMonacoEditor.SQL := item.SQL;
    // MyBase page and unions (VCL LDatasetsClick)
    EMyBase.Text := item.MyBaseFilename;
    EMyBaseDefs.Text := item.MyBaseFields;
    EIndexFields.Text := item.MyBaseIndexFields;
    EMasterFields.Text := item.MyBaseMasterFields;
    LUnions.Items.Assign(item.DataUnions);
    CheckGroupUnion.Checked := item.GroupUnion;
    CheckParallelUnion.Checked := item.ParallelUnion;
    ComboUnions.Items.Assign(LDatasets.Items);
    if Index < ComboUnions.Items.Count then
      ComboUnions.Items.Delete(Index);
    if ComboUnions.Items.Count < 1 then
      ComboUnions.ItemIndex := -1
    else
      ComboUnions.ItemIndex := 0;
    UpdateConnectionDependentUi(item);
    // Chat and Hub context of the dataset (VCL LDatasetsClick)
    EnsureAdvancedEditors;
  finally
    FUpdatingControls := False;
  end;
end;

procedure TFRpDInfoLCL.LConnectionsClick(Sender: TObject);
begin
  if FUpdatingControls then Exit;
  SaveActiveConn;
  LoadConnDetails(LConnections.ItemIndex);
end;

procedure TFRpDInfoLCL.LDatasetsClick(Sender: TObject);
begin
  if FUpdatingControls then Exit;
  SaveActiveDS;
  LoadDSDetails(LDatasets.ItemIndex);
end;

procedure TFRpDInfoLCL.BNewConnClick(Sender: TObject);
var
  newAlias: string;
  n: Integer;
  item: TRpDatabaseInfoItem;
begin
  if not CheckCanModify then Exit;
  SaveActiveConn;

  n := FWork.DatabaseInfo.Count + 1;
  repeat
    newAlias := 'CONNECTION' + IntToStr(n);
    Inc(n);
  until FWork.DatabaseInfo.IndexOf(newAlias) < 0;

  item := FWork.DatabaseInfo.Add(newAlias);
  item.Name := UniqueItemName('TRPDATABASEINFOITEM');
  // The driver selected in the driver list (VCL MNewClick)
  item.Driver := SelectedListDriver;

  LConnections.Items.Add(newAlias);
  LConnections.ItemIndex := LConnections.Count - 1;
  LoadConnDetails(LConnections.ItemIndex);
  if EConnAlias.CanFocus then
  begin
    EConnAlias.SetFocus;
    EConnAlias.SelectAll;
  end;
end;

procedure TFRpDInfoLCL.BDelConnClick(Sender: TObject);
var
  idx: Integer;
begin
  if (FActiveConnIndex < 0) or (FActiveConnIndex >= FWork.DatabaseInfo.Count) then
    Exit;
  if not CheckCanModify then Exit;

  idx := FActiveConnIndex;
  FActiveConnIndex := -1;
  FWork.DatabaseInfo.Delete(idx);
  LConnections.Items.Delete(idx);

  if idx >= LConnections.Count then
    idx := LConnections.Count - 1;
  if idx >= 0 then
    LConnections.ItemIndex := idx;
  LoadConnDetails(idx);
end;

procedure TFRpDInfoLCL.BBrowseFileClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    EConfigFile.Text := OpenDialog1.FileName;
end;

{ Drivers and connections file (VCL TFRpConnectionVCL) }

procedure TFRpDInfoLCL.LoadConAdmin;
begin
  FreeAndNil(FConAdmin);
  try
    FConAdmin := TRpConnAdmin.Create;
  except
    // Without connections file there is nothing to add from it
    FConAdmin := nil;
  end;
  RefreshAvailable;
end;

function TFRpDInfoLCL.SelectedListDriver: TRpDbDriver;
begin
  if LDrivers.ItemIndex >= 0 then
    Result := TRpDbDriver(PtrInt(LDrivers.Items.Objects[LDrivers.ItemIndex]))
  else
    Result := rpdatazeos;
end;

procedure TFRpDInfoLCL.SelectListDriver(ADriver: TRpDbDriver);
var
  i: Integer;
begin
  for i := 0 to LDrivers.Items.Count - 1 do
    if PtrInt(LDrivers.Items.Objects[i]) = Ord(ADriver) then
    begin
      LDrivers.ItemIndex := i;
      Break;
    end;
  LDriversClick(LDrivers);
end;

procedure TFRpDInfoLCL.LDriversClick(Sender: TObject);
begin
  // VCL GDriverClick: description and connections of the driver
  MHelp.Lines.Text := FpcDriverDescription(SelectedListDriver);
  RefreshAvailable;
end;

procedure TFRpDInfoLCL.RefreshAvailable;
var
  sections: TStringList;
  i: Integer;
  driver: TRpDbDriver;
  drivername: string;
begin
  // VCL ComboAvailable: the entries of the connections file that the driver
  // opens (ResolveFpcConnectionDriver); entries without driver name are not
  // listed (the VCL lists none for MyBase)
  FAvailable.Clear;
  if (FConAdmin = nil) or (FConAdmin.config = nil) then
    Exit;
  driver := SelectedListDriver;
  sections := TStringList.Create;
  try
    FConAdmin.config.ReadSections(sections);
    for i := 0 to sections.Count - 1 do
    begin
      drivername := Trim(FConAdmin.config.ReadString(sections[i], 'DriverName', ''));
      if drivername = '' then
        Continue;
      if ResolveFpcConnectionDriver(drivername, driver) = driver then
        FAvailable.Add(sections[i]);
    end;
  finally
    sections.Free;
  end;
end;

procedure TFRpDInfoLCL.PopAddPopup(Sender: TObject);
var
  aitem: TMenuItem;
  i: Integer;
begin
  // VCL PopAddPopup: New plus the available connections
  while PopAdd.Items.Count > 1 do
    PopAdd.Items[PopAdd.Items.Count - 1].Free;
  for i := 0 to FAvailable.Count - 1 do
  begin
    aitem := TMenuItem.Create(PopAdd);
    aitem.Caption := FAvailable[i];
    // The name (a caption may get an accelerator)
    aitem.Hint := FAvailable[i];
    aitem.OnClick := MenuAddClick;
    PopAdd.Items.Add(aitem);
  end;
end;

procedure TFRpDInfoLCL.MNewClick(Sender: TObject);
begin
  BNewConnClick(Sender);
end;

procedure TFRpDInfoLCL.MenuAddClick(Sender: TObject);
begin
  AddAvailableConnection(TMenuItem(Sender).Hint);
end;

procedure TFRpDInfoLCL.AddAvailableConnection(const AName: string);
var
  conname, drivername: string;
  item: TRpDatabaseInfoItem;
  params: TStringList;
  driver: TRpDbDriver;
begin
  // VCL MenuAddClick
  conname := UpperCase(Trim(AName));
  if conname = '' then
    Exit;
  if not CheckCanModify then
    Exit;
  SaveActiveConn;
  driver := SelectedListDriver;
  if FConAdmin <> nil then
  begin
    params := TStringList.Create;
    try
      FConAdmin.GetConnectionParams(conname, params);
      drivername := Trim(params.Values['DriverName']);
    finally
      params.Free;
    end;
    driver := ResolveFpcConnectionDriver(drivername, driver);
  end;
  // Raises when the report has a connection with that name
  item := FWork.DatabaseInfo.Add(conname);
  item.Name := UniqueItemName('TRPDATABASEINFOITEM');
  item.Driver := driver;
  LConnections.Items.Add(item.Alias);
  LConnections.ItemIndex := LConnections.Count - 1;
  LoadConnDetails(LConnections.ItemIndex);
end;

procedure TFRpDInfoLCL.BuildWizardControls;

  procedure SetWand(AButton: TBitBtn; ASize: Integer);
  var
    LBitmap: TBitmap;
  begin
    LBitmap := CreateWandBitmap(Scale96ToScreen(ASize));
    try
      AButton.Glyph.Assign(LBitmap);
    finally
      LBitmap.Free;
    end;
  end;

begin
  SetWand(BWizardConn, 20);

  // The report has no connections: the wizard in the place of the
  // properties of the connection (one of both panels is visible)
  PConnEmpty := TPanel.Create(PConnClient);
  PConnEmpty.Parent := PConnClient;
  PConnEmpty.BevelOuter := bvNone;
  PConnEmpty.Align := alClient;
  PConnEmpty.Visible := False;
  BWizardConnEmpty := TBitBtn.Create(PConnEmpty);
  BWizardConnEmpty.Parent := PConnEmpty;
  BWizardConnEmpty.Caption := BWizardConn.Caption;
  BWizardConnEmpty.Font.Size := 11;
  BWizardConnEmpty.Spacing := Scale96ToScreen(10);
  BWizardConnEmpty.AutoSize := True;
  BWizardConnEmpty.AnchorHorizontalCenterTo(PConnEmpty);
  BWizardConnEmpty.AnchorVerticalCenterTo(PConnEmpty);
  BWizardConnEmpty.OnClick := BWizardConnClick;
  SetWand(BWizardConnEmpty, 32);
  LWizardHint := TLabel.Create(PConnEmpty);
  LWizardHint.Parent := PConnEmpty;
  LWizardHint.AutoSize := False;
  LWizardHint.WordWrap := True;
  LWizardHint.Alignment := taCenter;
  LWizardHint.ShowAccelChar := False;
  LWizardHint.Width := Scale96ToScreen(420);
  LWizardHint.Height := Scale96ToScreen(54);
  LWizardHint.Font.Color := clGrayText;
  LWizardHint.Caption := TranslateStr(1828, 'Connect the report to your database: ' +
    'through the Reportman Agent, or directly (SQLite, Zeos...).');
  LWizardHint.AnchorHorizontalCenterTo(PConnEmpty);
  LWizardHint.AnchorToNeighbour(akTop, Scale96ToScreen(10), BWizardConnEmpty);

  // A Reportman AI Agent connection that can not be opened on this computer
  LAgentProblem := TLabel.Create(PConnProps);
  LAgentProblem.Parent := PConnProps;
  LAgentProblem.WordWrap := True;
  LAgentProblem.ShowAccelChar := False;
  LAgentProblem.Font.Color := clMaroon;
  LAgentProblem.SetBounds(Scale96ToScreen(10), Scale96ToScreen(294), Scale96ToScreen(380),
    Scale96ToScreen(16));
  // Both sides anchored: the autosize only sets the height of the lines
  LAgentProblem.AnchorParallel(akRight, Scale96ToScreen(10), PConnProps);
  LAgentProblem.Anchors := [akLeft, akTop, akRight];
  LAgentProblem.Visible := False;
  BWizardConfigure := TBitBtn.Create(PConnProps);
  BWizardConfigure.Parent := PConnProps;
  BWizardConfigure.Caption := TranslateStr(1829, 'Configure with the wizard');
  BWizardConfigure.AutoSize := True;
  BWizardConfigure.Left := Scale96ToScreen(10);
  BWizardConfigure.AnchorToNeighbour(akTop, Scale96ToScreen(6), LAgentProblem);
  BWizardConfigure.OnClick := BWizardConfigureClick;
  BWizardConfigure.Visible := False;
  SetWand(BWizardConfigure, 16);
end;

procedure TFRpDInfoLCL.BWizardConnClick(Sender: TObject);
var
  LName: string;
  LDriver: TRpDbDriver;
begin
  if not CheckCanModify then
    Exit;
  SaveActiveConn;
  if RpConnectionWizardFunc('', 0, LName, LDriver) then
    AddWizardConnection(LName, LDriver);
end;

procedure TFRpDInfoLCL.AddWizardConnection(const AName: string; ADriver: TRpDbDriver);
var
  conname: string;
  index: Integer;
  item: TRpDatabaseInfoItem;
begin
  conname := UpperCase(Trim(AName));
  if conname = '' then
    Exit;
  // The connections file has it now (New drop down)
  LoadConAdmin;
  index := FWork.DatabaseInfo.IndexOf(conname);
  if index < 0 then
  begin
    item := FWork.DatabaseInfo.Add(conname);
    item.Name := UniqueItemName('TRPDATABASEINFOITEM');
    item.Driver := ADriver;
    LConnections.Items.Add(item.Alias);
    index := LConnections.Count - 1;
  end;
  LConnections.ItemIndex := index;
  LoadConnDetails(index);
end;

procedure TFRpDInfoLCL.BWizardConfigureClick(Sender: TObject);
var
  LName: string;
  LDriver: TRpDbDriver;
begin
  if (FActiveConnIndex < 0) or (FActiveConnIndex >= FWork.DatabaseInfo.Count) then
    Exit;
  SaveActiveConn;
  if RpConnectionWizardFunc(FWork.DatabaseInfo[FActiveConnIndex].Alias, 0, LName,
    LDriver) then
  begin
    LoadConAdmin;
    LoadConnDetails(FActiveConnIndex);
  end;
end;

procedure TFRpDInfoLCL.UpdateAgentProblem(AItem: TRpDatabaseInfoItem);
var
  LMessage: string;
begin
  if (AItem <> nil) and (AItem.Driver = rpdbHttp) and
    RpAgentConnectionProblem(AItem, LMessage) then
  begin
    LAgentProblem.Caption := LMessage;
    LAgentProblem.Visible := True;
    BWizardConfigure.Visible := True;
  end
  else
  begin
    LAgentProblem.Visible := False;
    BWizardConfigure.Visible := False;
  end;
end;

procedure TFRpDInfoLCL.BConfigClick(Sender: TObject);
var
  i: Integer;
begin
  ShowDBXConfig;
  LoadConAdmin;
  // VCL BConfigClick: the connections file may have changed; the next
  // connect reads it again
  for i := 0 to FWork.DatabaseInfo.Count - 1 do
  begin
    FWork.DatabaseInfo[i].DisConnect;
    FWork.DatabaseInfo[i].UpdateConAdmin;
  end;
  // The Hub database or the API key of the dataset connection
  if ActiveDataInfo <> nil then
    ApplyActiveDataInfoContext(False);
end;

procedure TFRpDInfoLCL.StartConnectionTest;
var
  item: TRpDatabaseInfoItem;
  copy: TRpReport;
  worker: TRpConnectionTestWorker;
begin
  // VCL BTestClick; the .Net drivers (printreport.exe) are not available
  SaveActiveConn;
  if (FActiveConnIndex < 0) or (FActiveConnIndex >= FWork.DatabaseInfo.Count) then
    Exit;
  if FTestRunning then
    Exit;
  item := FWork.DatabaseInfo[FActiveConnIndex];
  // A copy for the worker: the dialog keeps editing the working one
  copy := TRpReport.Create(nil);
  try
    copy.Params.Assign(FWork.Params);
    copy.DatabaseInfo.Add(item.Alias).Assign(item);
  except
    copy.Free;
    raise;
  end;
  Inc(FTestVersion);
  worker := TRpConnectionTestWorker.Create(FMailboxRef);
  worker.Session := FSession;
  worker.RequestVersion := FTestVersion;
  worker.Report := copy;
  FTestRunning := True;
  BTestConn.Enabled := False;
  worker.Start;
end;

procedure TFRpDInfoLCL.BTestConnClick(Sender: TObject);
begin
  StartConnectionTest;
end;

{ Datasets: show data, MyBase and unions (VCL TFRpDatasetsVCL) }

procedure TFRpDInfoLCL.StartShowData;
var
  item: TRpDataInfoItem;
  copy: TRpReport;
  worker: TRpShowDataWorker;
begin
  SaveActiveConn;
  SaveActiveDS;
  item := ActiveDataInfo;
  if (item = nil) or (Trim(item.DatabaseAlias) = '') then
    Exit;
  if FShowDataRunning then
    Exit;
  // A Reportman AI Agent connection not configured on this computer: the
  // connection wizard first
  if FInteractive and not RpCheckAgentConnections(FWork.DatabaseInfo,
    FWork.DataInfo, item) then
    Exit;
  // The worker opens a copy of the working data (master datasets and unions
  // included); the dialog keeps editing the working one
  copy := TRpReport.Create(nil);
  try
    if Assigned(FReport) then
      copy.Language := FReport.Language;
    copy.DatabaseInfo.Assign(FWork.DatabaseInfo);
    copy.DataInfo.Assign(FWork.DataInfo);
    copy.Params.Assign(FWork.Params);
  except
    copy.Free;
    raise;
  end;
  Inc(FShowDataVersion);
  worker := TRpShowDataWorker.Create(FMailboxRef);
  worker.Session := FSession;
  worker.RequestVersion := FShowDataVersion;
  worker.DataInfoIndex := FActiveDSIndex;
  worker.Report := copy;
  FShowDataRunning := True;
  BShowData.Enabled := False;
  worker.Start;
end;

procedure TFRpDInfoLCL.BShowDataClick(Sender: TObject);
begin
  StartShowData;
end;

procedure TFRpDInfoLCL.BMyBaseClick(Sender: TObject);
begin
  if Sender = BMyBase then
  begin
    OpenDialogMyBase.DefaultExt := 'cds';
    OpenDialogMyBase.FilterIndex := 1;
  end
  else
  begin
    OpenDialogMyBase.DefaultExt := 'ini';
    OpenDialogMyBase.FilterIndex := 4;
  end;
  if OpenDialogMyBase.Execute then
  begin
    if Sender = BMyBase then
      EMyBase.Text := OpenDialogMyBase.FileName
    else
      EMyBaseDefs.Text := OpenDialogMyBase.FileName;
  end;
end;

procedure TFRpDInfoLCL.BModifyClick(Sender: TObject);
var
  item: TRpDataInfoItem;
  dbinfo: TRpDatabaseInfoItem;
  index: Integer;
  path: string;
begin
  item := ActiveDataInfo;
  if item = nil then
    Exit;
  index := FWork.DatabaseInfo.IndexOf(item.DatabaseAlias);
  if index < 0 then
    Exit;
  dbinfo := FWork.DatabaseInfo[index];
  path := '';
  // The MyBase connection reads its path (Database parameter); no other
  // driver is connected here (network)
  if dbinfo.Driver = rpdatamybase then
  begin
    dbinfo.Connect(FWork.Params);
    path := dbinfo.MyBasePath;
  end;
  ShowDataTextConfig(path + EMyBaseDefs.Text, path + EMyBase.Text);
end;

procedure TFRpDInfoLCL.AddUnion(const ADataset, ACommonFields: string);
var
  item: TRpDataInfoItem;
  datasetname: string;
begin
  item := ActiveDataInfo;
  if (item = nil) or (Trim(ADataset) = '') then
    Exit;
  if not CheckCanModify then
    Exit;
  // VCL BAddUnionsClick: not twice (by the dataset name alone)
  if LUnions.Items.IndexOf(ADataset) >= 0 then
    Exit;
  datasetname := ADataset;
  if Trim(ACommonFields) <> '' then
    datasetname := datasetname + '-' + Trim(ACommonFields);
  LUnions.Items.Add(datasetname);
  item.DataUnions := LUnions.Items;
end;

procedure TFRpDInfoLCL.DeleteUnion;
var
  item: TRpDataInfoItem;
begin
  item := ActiveDataInfo;
  if (item = nil) or (LUnions.ItemIndex < 0) then
    Exit;
  if not CheckCanModify then
    Exit;
  LUnions.Items.Delete(LUnions.ItemIndex);
  item.DataUnions := LUnions.Items;
end;

procedure TFRpDInfoLCL.BAddUnionsClick(Sender: TObject);
var
  commonfields: string;
begin
  if ComboUnions.ItemIndex < 0 then
    Exit;
  commonfields := '';
  if CheckParallelUnion.Checked then
    commonfields := Trim(RpInputBox(ComboUnions.Text, SRpCommonFields, ''));
  AddUnion(ComboUnions.Text, commonfields);
end;

procedure TFRpDInfoLCL.BDelUnionsClick(Sender: TObject);
begin
  DeleteUnion;
end;

procedure TFRpDInfoLCL.BNewDSClick(Sender: TObject);
var
  newAlias: string;
  n: Integer;
  item: TRpDataInfoItem;
begin
  if not CheckCanModify then Exit;
  SaveActiveDS;

  n := FWork.DataInfo.Count + 1;
  repeat
    newAlias := 'DATASET' + IntToStr(n);
    Inc(n);
  until FWork.DataInfo.IndexOf(newAlias) < 0;

  item := FWork.DataInfo.Add(newAlias);
  item.Name := UniqueItemName('TRPDATAINFOITEM');
  item.OpenOnStart := True;
  if FWork.DatabaseInfo.Count > 0 then
    item.DatabaseAlias := FWork.DatabaseInfo[0].Alias;
  // The schema of the other datasets of the connection (VCL ANewExecute)
  if item.HubSchemaId = 0 then
    item.HubSchemaId := FindSiblingHubSchemaId(item);

  LDatasets.Items.Add(newAlias);
  LDatasets.ItemIndex := LDatasets.Count - 1;
  LoadDSDetails(LDatasets.ItemIndex);
  if EDSAlias.CanFocus then
  begin
    EDSAlias.SetFocus;
    EDSAlias.SelectAll;
  end;
end;

procedure TFRpDInfoLCL.BDelDSClick(Sender: TObject);
var
  idx, i: Integer;
  oldAlias: string;
begin
  if (FActiveDSIndex < 0) or (FActiveDSIndex >= FWork.DataInfo.Count) then
    Exit;
  if not CheckCanModify then Exit;

  idx := FActiveDSIndex;
  FActiveDSIndex := -1;
  oldAlias := FWork.DataInfo[idx].Alias;
  FWork.DataInfo.Delete(idx);
  // Remove dependences (VCL TFRpDatasetsVCL.Removedependences)
  for i := 0 to FWork.DataInfo.Count - 1 do
  begin
    if AnsiUpperCase(oldAlias) = AnsiUpperCase(FWork.DataInfo[i].DataSource) then
      FWork.DataInfo[i].DataSource := '';
  end;
  LDatasets.Items.Delete(idx);

  if idx >= LDatasets.Count then
    idx := LDatasets.Count - 1;
  if idx >= 0 then
    LDatasets.ItemIndex := idx;
  LoadDSDetails(idx);
end;

procedure TFRpDInfoLCL.BtnUpDSClick(Sender: TObject);
var
  idx: Integer;
begin
  if (FActiveDSIndex <= 0) or (FActiveDSIndex >= FWork.DataInfo.Count) then Exit;
  if not CheckCanModify then Exit;
  SaveActiveDS;
  idx := FActiveDSIndex;
  FWork.DataInfo.Swap(idx, idx - 1);
  RefreshDSList;
  if idx - 1 < LDatasets.Items.Count then
  begin
    LDatasets.ItemIndex := idx - 1;
    LoadDSDetails(idx - 1);
  end;
end;

procedure TFRpDInfoLCL.BtnDownDSClick(Sender: TObject);
var
  idx: Integer;
begin
  if (FActiveDSIndex < 0) or (FActiveDSIndex >= FWork.DataInfo.Count - 1) then Exit;
  if not CheckCanModify then Exit;
  SaveActiveDS;
  idx := FActiveDSIndex;
  FWork.DataInfo.Swap(idx, idx + 1);
  RefreshDSList;
  if idx + 1 < LDatasets.Items.Count then
  begin
    LDatasets.ItemIndex := idx + 1;
    LoadDSDetails(idx + 1);
  end;
end;

procedure TFRpDInfoLCL.BtnRenameDSClick(Sender: TObject);
var
  oldAlias, newAlias: string;
  item: TRpDataInfoItem;
begin
  if (FActiveDSIndex < 0) or (FActiveDSIndex >= FWork.DataInfo.Count) then Exit;
  SaveActiveDS;
  item := FWork.DataInfo[FActiveDSIndex];
  oldAlias := item.Alias;
  newAlias := Trim(RpInputBox(SrpRenameDataset, SRpAliasName, oldAlias));
  if (newAlias = '') or SameText(newAlias, oldAlias) then Exit;
  if FWork.DataInfo.IndexOf(newAlias) >= 0 then
    raise Exception.Create(SRpAliasExists);
  if not CheckCanModify then Exit;
  item.Alias := newAlias;
  EDSAlias.Text := item.Alias;
  RefreshDSList;
  LDatasets.ItemIndex := FWork.DataInfo.IndexOf(newAlias);
  LoadDSDetails(LDatasets.ItemIndex);
end;

procedure TFRpDInfoLCL.BParamsClick(Sender: TObject);
var
  current: Integer;
begin
  // VCL TFRpDatasetsVCL.BParamsClick: edit the working parameters, the undo
  // operations are recorded when the whole dialog is accepted
  if not CheckCanModify then Exit;
  SaveActiveConn;
  SaveActiveDS;
  current := FActiveDSIndex;
  ShowParamDef(FWork.Params, FWork.DataInfo, FWork, True);
  if current >= 0 then
    LoadDSDetails(current);
end;

function TFRpDInfoLCL.HasPendingChanges: Boolean;
begin
  Result := (not SameDatabaseInfoList(FOrigDatabaseInfo, FWork.DatabaseInfo)) or
    (not SameDataInfoList(FOrigDataInfo, FWork.DataInfo)) or
    (not SameParamList(FOrigParams, FWork.Params));
end;

function TFRpDInfoLCL.OrderChanged: Boolean;
var
  i, j: Integer;
  lastIndex: Integer;
begin
  // Undo operations restore items by name, not their relative order
  Result := False;
  lastIndex := -1;
  for i := 0 to FWork.DataInfo.Count - 1 do
  begin
    for j := 0 to FOrigDataInfo.Count - 1 do
    begin
      if SameText(FOrigDataInfo.Items[j].Name, FWork.DataInfo.Items[i].Name) then
      begin
        if j < lastIndex then
          Exit(True);
        lastIndex := j;
        Break;
      end;
    end;
  end;
  lastIndex := -1;
  for i := 0 to FWork.DatabaseInfo.Count - 1 do
  begin
    for j := 0 to FOrigDatabaseInfo.Count - 1 do
    begin
      if SameText(FOrigDatabaseInfo.Items[j].Name, FWork.DatabaseInfo.Items[i].Name) then
      begin
        if j < lastIndex then
          Exit(True);
        lastIndex := j;
        Break;
      end;
    end;
  end;
  lastIndex := -1;
  for i := 0 to FWork.Params.Count - 1 do
  begin
    for j := 0 to FOrigParams.Count - 1 do
    begin
      if SameText(FOrigParams.Items[j].IntName, FWork.Params.Items[i].IntName) then
      begin
        if j < lastIndex then
          Exit(True);
        lastIndex := j;
        Break;
      end;
    end;
  end;
end;

procedure TFRpDInfoLCL.RecordUndoChanges;
var
  undoCue: TUndoCue;
  groupId: Integer;
  i: Integer;
  origDB, newDB: TRpDatabaseInfoItem;
  origDS, newDS: TRpDataInfoItem;
  newDBInfo: TRpDatabaseInfoList;
  newDataInfo: TRpDataInfoList;
  op: TChangeObjectOperation;

  function FindDatabaseInfoByComponentName(infoList: TRpDatabaseInfoList;
    const componentName: string): TRpDatabaseInfoItem;
  var
    itemIndex: Integer;
  begin
    Result := nil;
    for itemIndex := 0 to infoList.Count - 1 do
    begin
      if SameText(infoList.Items[itemIndex].Name, componentName) then
      begin
        Result := infoList.Items[itemIndex];
        Exit;
      end;
    end;
  end;

  function FindDataInfoByComponentName(infoList: TRpDataInfoList;
    const componentName: string): TRpDataInfoItem;
  var
    itemIndex: Integer;
  begin
    Result := nil;
    for itemIndex := 0 to infoList.Count - 1 do
    begin
      if SameText(infoList.Items[itemIndex].Name, componentName) then
      begin
        Result := infoList.Items[itemIndex];
        Exit;
      end;
    end;
  end;

begin
  // Port of TFRpDInfoVCL.RecordUndoChanges
  if not Assigned(FReport) then
    Exit;
  if not Assigned(FReport.UndoCue) then
    FReport.UndoCue := TUndoCue.Create(FReport);
  undoCue := TUndoCue(FReport.UndoCue);
  groupId := undoCue.GetGroupId;
  newDBInfo := FWork.DatabaseInfo;
  newDataInfo := FWork.DataInfo;
  // DatabaseInfo changes
  for i := 0 to FOrigDatabaseInfo.Count - 1 do
  begin
    origDB := FOrigDatabaseInfo.Items[i];
    if FindDatabaseInfoByComponentName(newDBInfo, origDB.Name) = nil then
    begin
      op := TChangeObjectOperation.Create(otRemove, groupId);
      op.componentName := origDB.Name;
      op.componentClass := 'TRPDATABASEINFOITEM';
      op.oldItemIndex := i;
      // otRemove: TUndoCue.ApplyPropertiesToObject recreates the item from
      // newValue on undo (same convention as DeleteSelection)
      op.AddProperty('alias', ptString, Null, origDB.Alias);
      op.AddProperty('driver', ptInteger, Null, Integer(origDB.Driver));
      op.AddProperty('configFile', ptString, Null, origDB.ConfigFile);
      op.AddProperty('loginPrompt', ptBoolean, Null, origDB.LoginPrompt);
      op.AddProperty('loadParams', ptBoolean, Null, origDB.LoadParams);
      op.AddProperty('loadDriverParams', ptBoolean, Null, origDB.LoadDriverParams);
      op.AddProperty('connectionString', ptString, Null, origDB.ADOConnectionString);
      op.AddProperty('providerFactory', ptString, Null, origDB.ProviderFactory);
      op.AddProperty('dotNetDriver', ptInteger, Null, origDB.DotNetDriver);
      undoCue.AddOperation(op);
    end;
  end;
  for i := 0 to newDBInfo.Count - 1 do
  begin
    newDB := newDBInfo.Items[i];
    if FindDatabaseInfoByComponentName(FOrigDatabaseInfo, newDB.Name) = nil then
    begin
      op := TChangeObjectOperation.Create(otAdd, groupId);
      op.componentName := newDB.Name;
      op.componentClass := 'TRPDATABASEINFOITEM';
      op.oldItemIndex := i;
      op.AddProperty('alias', ptString, Null, newDB.Alias);
      op.AddProperty('driver', ptInteger, Null, Integer(newDB.Driver));
      op.AddProperty('configFile', ptString, Null, newDB.ConfigFile);
      op.AddProperty('loginPrompt', ptBoolean, Null, newDB.LoginPrompt);
      op.AddProperty('loadParams', ptBoolean, Null, newDB.LoadParams);
      op.AddProperty('loadDriverParams', ptBoolean, Null, newDB.LoadDriverParams);
      op.AddProperty('connectionString', ptString, Null, newDB.ADOConnectionString);
      op.AddProperty('providerFactory', ptString, Null, newDB.ProviderFactory);
      op.AddProperty('dotNetDriver', ptInteger, Null, newDB.DotNetDriver);
      undoCue.AddOperation(op);
    end;
  end;
  for i := 0 to newDBInfo.Count - 1 do
  begin
    newDB := newDBInfo.Items[i];
    origDB := FindDatabaseInfoByComponentName(FOrigDatabaseInfo, newDB.Name);
    if Assigned(origDB) then
    begin
      op := TChangeObjectOperation.Create(otModify, groupId);
      op.componentName := newDB.Name;
      op.componentClass := 'TRPDATABASEINFOITEM';
      if origDB.Alias <> newDB.Alias then
        op.AddProperty('alias', ptString, origDB.Alias, newDB.Alias);
      if Integer(origDB.Driver) <> Integer(newDB.Driver) then
        op.AddProperty('driver', ptInteger, Integer(origDB.Driver), Integer(newDB.Driver));
      if origDB.ConfigFile <> newDB.ConfigFile then
        op.AddProperty('configFile', ptString, origDB.ConfigFile, newDB.ConfigFile);
      if origDB.LoginPrompt <> newDB.LoginPrompt then
        op.AddProperty('loginPrompt', ptBoolean, origDB.LoginPrompt, newDB.LoginPrompt);
      if origDB.LoadParams <> newDB.LoadParams then
        op.AddProperty('loadParams', ptBoolean, origDB.LoadParams, newDB.LoadParams);
      if origDB.LoadDriverParams <> newDB.LoadDriverParams then
        op.AddProperty('loadDriverParams', ptBoolean, origDB.LoadDriverParams, newDB.LoadDriverParams);
      if origDB.ADOConnectionString <> newDB.ADOConnectionString then
        op.AddProperty('connectionString', ptString, origDB.ADOConnectionString, newDB.ADOConnectionString);
      if origDB.ProviderFactory <> newDB.ProviderFactory then
        op.AddProperty('providerFactory', ptString, origDB.ProviderFactory, newDB.ProviderFactory);
      if origDB.DotNetDriver <> newDB.DotNetDriver then
        op.AddProperty('dotNetDriver', ptInteger, origDB.DotNetDriver, newDB.DotNetDriver);
      if op.properties.Count > 0 then
        undoCue.AddOperation(op)
      else
        op.Free;
    end;
  end;
  // DataInfo changes
  for i := 0 to FOrigDataInfo.Count - 1 do
  begin
    origDS := FOrigDataInfo.Items[i];
    if FindDataInfoByComponentName(newDataInfo, origDS.Name) = nil then
    begin
      op := TChangeObjectOperation.Create(otRemove, groupId);
      op.componentName := origDS.Name;
      op.componentClass := 'TRPDATAINFOITEM';
      op.oldItemIndex := i;
      // otRemove: values go in newValue (see the TRPDATABASEINFOITEM case)
      op.AddProperty('alias', ptString, Null, origDS.Alias);
      op.AddProperty('databaseAlias', ptString, Null, origDS.DatabaseAlias);
      op.AddProperty('sql', ptString, Null, origDS.SQL);
      op.AddProperty('hubSchemaId', ptInteger, Null, origDS.HubSchemaId);
      if origDS.SchemaName <> '' then
        op.AddProperty('schemaName', ptString, Null, origDS.SchemaName);
      op.AddProperty('dataSource', ptString, Null, origDS.DataSource);
      op.AddProperty('groupUnion', ptBoolean, Null, origDS.GroupUnion);
      op.AddProperty('openOnStart', ptBoolean, Null, origDS.OpenOnStart);
      op.AddProperty('parallelUnion', ptBoolean, Null, origDS.ParallelUnion);
      // Both undo cues (Delphi and LCL) restore dataUnions
      if origDS.DataUnions.Count > 0 then
        op.AddProperty('dataUnions', ptStringArray, Null,
          StringListToVariant(origDS.DataUnions));
      undoCue.AddOperation(op);
    end;
  end;
  for i := 0 to newDataInfo.Count - 1 do
  begin
    newDS := newDataInfo.Items[i];
    if FindDataInfoByComponentName(FOrigDataInfo, newDS.Name) = nil then
    begin
      op := TChangeObjectOperation.Create(otAdd, groupId);
      op.componentName := newDS.Name;
      op.componentClass := 'TRPDATAINFOITEM';
      op.oldItemIndex := i;
      op.AddProperty('alias', ptString, Null, newDS.Alias);
      op.AddProperty('databaseAlias', ptString, Null, newDS.DatabaseAlias);
      op.AddProperty('sql', ptString, Null, newDS.SQL);
      op.AddProperty('hubSchemaId', ptInteger, Null, newDS.HubSchemaId);
      if newDS.SchemaName <> '' then
        op.AddProperty('schemaName', ptString, Null, newDS.SchemaName);
      op.AddProperty('dataSource', ptString, Null, newDS.DataSource);
      op.AddProperty('groupUnion', ptBoolean, Null, newDS.GroupUnion);
      op.AddProperty('openOnStart', ptBoolean, Null, newDS.OpenOnStart);
      op.AddProperty('parallelUnion', ptBoolean, Null, newDS.ParallelUnion);
      if newDS.DataUnions.Count > 0 then
        op.AddProperty('dataUnions', ptStringArray, Null,
          StringListToVariant(newDS.DataUnions));
      undoCue.AddOperation(op);
    end;
  end;
  for i := 0 to newDataInfo.Count - 1 do
  begin
    newDS := newDataInfo.Items[i];
    origDS := FindDataInfoByComponentName(FOrigDataInfo, newDS.Name);
    if Assigned(origDS) then
    begin
      op := TChangeObjectOperation.Create(otModify, groupId);
      op.componentName := newDS.Name;
      op.componentClass := 'TRPDATAINFOITEM';
      if origDS.Alias <> newDS.Alias then
        op.AddProperty('alias', ptString, origDS.Alias, newDS.Alias);
      if origDS.DatabaseAlias <> newDS.DatabaseAlias then
        op.AddProperty('databaseAlias', ptString, origDS.DatabaseAlias, newDS.DatabaseAlias);
      if origDS.SQL <> newDS.SQL then
        op.AddProperty('sql', ptString, origDS.SQL, newDS.SQL);
      if origDS.HubSchemaId <> newDS.HubSchemaId then
        op.AddProperty('hubSchemaId', ptInteger, origDS.HubSchemaId, newDS.HubSchemaId);
      if origDS.SchemaName <> newDS.SchemaName then
        op.AddProperty('schemaName', ptString, origDS.SchemaName, newDS.SchemaName);
      if origDS.DataSource <> newDS.DataSource then
        op.AddProperty('dataSource', ptString, origDS.DataSource, newDS.DataSource);
      if origDS.GroupUnion <> newDS.GroupUnion then
        op.AddProperty('groupUnion', ptBoolean, origDS.GroupUnion, newDS.GroupUnion);
      if origDS.OpenOnStart <> newDS.OpenOnStart then
        op.AddProperty('openOnStart', ptBoolean, origDS.OpenOnStart, newDS.OpenOnStart);
      if origDS.ParallelUnion <> newDS.ParallelUnion then
        op.AddProperty('parallelUnion', ptBoolean, origDS.ParallelUnion, newDS.ParallelUnion);
      if not SameStringLists(origDS.DataUnions, newDS.DataUnions) then
        op.AddProperty('dataUnions', ptStringArray,
          StringListToVariant(origDS.DataUnions),
          StringListToVariant(newDS.DataUnions));
      if op.properties.Count > 0 then
        undoCue.AddOperation(op)
      else
        op.Free;
    end;
  end;
  RecordParamUndoChanges(FOrigParams, FWork.Params, FReport, groupId);
end;

function TFRpDInfoLCL.ApplyChanges: Boolean;
var
  needsExternalMark, found: Boolean;
  i, j: Integer;
begin
  Result := True;
  SaveActiveConn;
  SaveActiveDS;
  if (not Assigned(FReport)) or (not HasPendingChanges) then
    Exit;
  if not FReport.CanModify('Database configuration') then
  begin
    Result := False;
    Exit;
  end;
  // Relative order changes (dataset up/down) can not be restored by the
  // name based undo operations: keep the report dirty for them
  needsExternalMark := OrderChanged;
  // The same for the SQL explanation of the audit (saved with the report,
  // not an undo property) and the MyBase properties (not undo properties
  // either, neither in the Delphi undo cue)
  for i := 0 to FWork.DataInfo.Count - 1 do
  begin
    found := False;
    for j := 0 to FOrigDataInfo.Count - 1 do
      if SameText(FOrigDataInfo.Items[j].Name, FWork.DataInfo.Items[i].Name) then
      begin
        found := True;
        if (FOrigDataInfo.Items[j].SQLExplanation <> FWork.DataInfo.Items[i].SQLExplanation) or
          (FOrigDataInfo.Items[j].SQLExplanationError <> FWork.DataInfo.Items[i].SQLExplanationError) or
          (not SameMyBaseProperties(FOrigDataInfo.Items[j], FWork.DataInfo.Items[i])) then
          needsExternalMark := True;
      end;
    // Added with MyBase properties: redo would recreate it without them
    if (not found) and HasMyBaseProperties(FWork.DataInfo.Items[i]) then
      needsExternalMark := True;
  end;
  // Removed with MyBase properties: undo would recreate it without them
  for j := 0 to FOrigDataInfo.Count - 1 do
    if HasMyBaseProperties(FOrigDataInfo.Items[j]) then
    begin
      found := False;
      for i := 0 to FWork.DataInfo.Count - 1 do
        if SameText(FOrigDataInfo.Items[j].Name, FWork.DataInfo.Items[i].Name) then
          found := True;
      if not found then
        needsExternalMark := True;
    end;
  RecordUndoChanges;
  FReport.DatabaseInfo.Assign(FWork.DatabaseInfo);
  FReport.DataInfo.Assign(FWork.DataInfo);
  FReport.Params.Assign(FWork.Params);
  if needsExternalMark then
    TUndoCue(FReport.UndoCue).MarkExternalChange;
  FApplied := True;
  // Next edits start from the applied state
  FOrigDatabaseInfo.Assign(FReport.DatabaseInfo);
  FOrigDataInfo.Assign(FReport.DataInfo);
  FOrigParams.Assign(FReport.Params);
end;

procedure TFRpDInfoLCL.BOkClick(Sender: TObject);
begin
  if ApplyChanges then
    ModalResult := mrOk;
end;

procedure TFRpDInfoLCL.BCancelClick(Sender: TObject);
begin
  // Working copies are discarded, the report was never touched
  ModalResult := mrCancel;
end;

initialization

finalization
  // The shared dialog is owned by Application, freed after this unit and
  // rpaithreadslcl finalize; its editor and chat must leave RpAuthEvents
  // before (they would create it again and leak it)
  FreeAndNil(GDataConfigDialog);
end.
