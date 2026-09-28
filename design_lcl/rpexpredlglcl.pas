{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpexpredlglcl                                   }
{       Expression Builder and Evaluator Dialog for LCL }
{       with the AI expression assistant               }
{       (LCL port of rpchatdialogvcl / rpexpredlgvcl)   }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpexpredlglcl;

{ The expression editor with the AI chat of the VCL (TFRpExpredialogVCL of
  rpchatdialogvcl): the classic editor at the left and the common chat
  (TFRpChatFrame of rpfrmchatlcl) at the right, without the schema selector.
  A prompt goes to the Hub with TRpDatabaseHttp.SuggestExpressionStream,
  together with the semantic context of the evaluator (dataset columns,
  report parameters, the functions and constants with an AI help); the
  answer is streamed to the AI log, the suggested expression is checked with
  the evaluator (CheckSyntax) and, when it fails, asked once more with "fix";
  Apply replaces the expression. With a report (TRpExpreDialogLCL.Report, as
  the object inspector of the VCL does) the dialog opens the report datasets
  in the background when it is shown (PrepareLiveContext) and asks the Hub
  for the columns of the Agent (rpdbHttp) datasets.

  Without a Hub session the classic editor works as before and the chat
  shows the account card to log in.

  Differences with the VCL:
  - Threads (FPC 3.2.2 has no anonymous methods): TRpAsyncWorker subclasses
    and a TRpAsyncMailbox (rpaithreadslcl) instead of the anonymous threads
    and the WM_USER+204/205 messages.
  - Each request has its own cancel flag and version. Stop ends the busy
    state at once and the later messages of that request are dropped (the
    VCL keeps the chat busy until the worker notices the shared flag, and a
    new prompt resets that flag).
  - The suggested expression is validated in the main thread
    (TThread.Synchronize); the VCL worker uses the evaluator of the form
    from the worker thread.
  - The dialog waits for a running dataset refresh when it is destroyed, so
    that no worker keeps opening the datasets of the designer report.
  - Texts with TranslateStr (fixed English in the VCL).
  - The design mode of the VCL dialog (TRpChatMode rcmDesign) is not ported:
    nothing sets it (the design assistant is in the designer main window).
  - The context builders are functions, not methods of a form
    (BuildDesignExpressionContextJson does not create a dialog). }

// {$MODE DELPHI} and USERPDATASET, as the engine
{$I rpconf.inc}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, Buttons, Variants,
  rptypes, rpmdconsts, rpalias, rpeval, rptypeval, rpreport, rpmetafile,
  rpaithreadslcl, rpfrmchatlcl;

const
  FMaxListHelp = 5;
  SExpressionChatInitialMessage = 'Ask for help rewriting, simplifying or ' +
    'validating the current expression. Click ''Apply'' to replace the expression.';

type
  TRpRecHelp = class(TObject)
  public
    RFunction: string;
    Help: string;
    Model: string;
    Params: string;
  end;

  { TFRpExpreDialogLCL }

  TFRpExpreDialogLCL = class(TForm)
  private
    FMemoExpre: TMemo;
    FLCategory: TListBox;
    FLOperation: TListBox;
    FMemoHelp: TMemo;
    FLabelCategory: TLabel;
    FLOperationLabel: TLabel;
    FLabelHelp: TLabel;
    FPanelLeft: TPanel;
    FPanelTop: TPanel;
    FPanelCenter: TPanel;
    FPanelBottom: TPanel;
    FPanelChat: TPanel;
    FSplitterChat: TSplitter;
    FBRefresh: TButton;
    FBAdd: TButton;
    FBCheckSyn: TButton;
    FBShowResult: TButton;
    FBOK: TButton;
    FBCancel: TButton;
    FChat: TFRpChatFrame;
    FLists: array[0..FMaxListHelp - 1] of TStringList;
    FEvaluator: TRpCustomEvaluator;
    FOwnsEvaluator: Boolean;
    FDoOk: Boolean;
    FValidate: Boolean;
    FAResult: Variant;
    // AI assistant (the VCL WM_USER+204 payloads arrive through the mailbox)
    FMailbox: TRpAsyncMailbox;
    FMailboxRef: IRpAsyncMailbox;
    FExpressionCancel: IRpAsyncCancel;
    FExpressionRequestVersion: Integer;
    FExpressionCursorPosition: Integer;
    // Datasets of the report (ConfigureReportRefresh)
    FRefreshReport: TRpReport;
    FRefreshPrintDriver: TRpPrintDriver;
    FRefreshAlias: TRpAlias;
    FEmptyAlias: TRpAlias;
    FSchemaOnlyFields: TStringList;
    FSchemaOnlyErrors: TStringList;
    FRefreshVersion: Integer;
    FRefreshRunning: Boolean;
    FRefreshDone: IRpAsyncCancel;
    FAliasReady: Boolean;

    procedure SetEvaluator(const Value: TRpCustomEvaluator);
    procedure AssignEvaluator(const Value: TRpCustomEvaluator);
    procedure BuildControls;
    procedure ClearHelpLists;
    procedure ReleaseOwnedEvaluator;
    procedure AssignEmptyAlias;
    function BuildRefreshSnapshotEvaluator: TRpEvaluator;
    procedure SetSchemaOnlyContext(AFields, AErrors: TStrings);
    procedure UpdateRefreshUIState;
    procedure UpdateExpressionCursorPosition;
    procedure WaitForReportRefresh;
    procedure FocusMemo;
    procedure DeferredShow(Data: PtrInt);
    procedure HandleAsyncMessage(AMessage: TRpAsyncMessage);
    procedure HandleExpressionChatPayload(APayload: TObject);
    procedure HandleRefreshPayload(APayload: TObject);
    procedure SendExpressionPrompt(const APrompt, AExpression: string);
    procedure MemoExpreChange(Sender: TObject);
    procedure MemoExpreClick(Sender: TObject);
    procedure MemoExpreKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MemoExpreMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  protected
    procedure DoShow; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // The VCL dialog setup: the evaluator (owned or not), OK evaluates the
    // expression (AValidate) and the memo accepts new lines (AWantReturns)
    procedure InitializeDialog(const AExpression: string;
      AEvaluator: TRpCustomEvaluator; AOwnsEvaluator, AValidate,
      AWantReturns: Boolean);
    // With a report the fields come from its datasets, opened in the
    // background when the dialog is shown; ATargetAlias (optional) receives
    // them, as the alias of the VCL object inspector
    procedure ConfigureReportRefresh(AReport: TRpReport;
      APrintDriver: TRpPrintDriver; ATargetAlias: TRpAlias);
    procedure StartReportRefresh;
    // Semantic context sent to the Hub with a prompt
    function BuildExpressionSemanticContextJson: string;
    // Syntax check with the evaluator (the validation of the suggestions)
    function ValidateExpressionText(const AExpression: string;
      out AErrorMessage: string): Boolean;
    // Items of a category: 0 fields, 1 functions, 2 variables, 3 constants,
    // 4 operators
    function HelpList(ACategory: Integer): TStrings;
    // Event handlers (public for the tests)
    procedure LCategoryClick(Sender: TObject);
    procedure LOperationClick(Sender: TObject);
    procedure LOperationDblClick(Sender: TObject);
    procedure BRefreshClick(Sender: TObject);
    procedure BAddClick(Sender: TObject);
    procedure BCheckSynClick(Sender: TObject);
    procedure BShowResultClick(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure ChatSendPrompt(Sender: TObject; const APrompt, AExpression: string);
    procedure ChatApplySuggestion(Sender: TObject; const AExpression: string);
    procedure StopExpressionRequest(Sender: TObject);

    property Evaluator: TRpCustomEvaluator read FEvaluator write SetEvaluator;
    property MemoExpre: TMemo read FMemoExpre;
    property DoOk: Boolean read FDoOk write FDoOk;
    property Validate: Boolean read FValidate write FValidate;
    property AResult: Variant read FAResult write FAResult;
    // LCL additions (state for the hosts and the tests)
    property Chat: TFRpChatFrame read FChat;
    property CategoryList: TListBox read FLCategory;
    property OperationList: TListBox read FLOperation;
    property RefreshButton: TButton read FBRefresh;
    property RefreshRunning: Boolean read FRefreshRunning;
    property AliasReady: Boolean read FAliasReady;
    property OwnsEvaluator: Boolean read FOwnsEvaluator;
    property SchemaOnlyFields: TStringList read FSchemaOnlyFields;
    property SchemaOnlyErrors: TStringList read FSchemaOnlyErrors;
  end;

  TFRpChatDialogLCL = TFRpExpreDialogLCL;

  { TRpExpreDialogLCL }

  TRpExpreDialogLCL = class(TComponent)
  private
    FExpression: TStrings;
    FRpAlias: TRpAlias;
    FEvaluator: TRpEvaluator;
    FReport: TRpReport;
    FPrintDriver: TRpPrintDriver;
    procedure SetExpression(const Value: TStrings);
    procedure SetRpAlias(const Value: TRpAlias);
    procedure SetReport(const Value: TRpReport);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Execute: Boolean;

    // With a report the dialog opens its datasets (as the VCL); else the
    // evaluator with RpAlias is used
    property Report: TRpReport read FReport write SetReport;
    property PrintDriver: TRpPrintDriver read FPrintDriver write FPrintDriver;
    property Expression: TStrings read FExpression write SetExpression;
    property RpAlias: TRpAlias read FRpAlias write SetRpAlias;
    property Evaluator: TRpEvaluator read FEvaluator write FEvaluator;
  end;

  TRpChatDialogComponent = TRpExpreDialogLCL;

function ChangeExpression(const formul: string; aval: TRpCustomEvaluator): string;
function ChangeExpressionW(const formul: WideString; aval: TRpCustomEvaluator): WideString;
function ExpressionCalculateW(const formul: WideString; aval: TRpCustomEvaluator): Variant;

// Columns of the Agent (rpdbHttp) datasets of a report, asked to the Hub
// (GetTableSchema): AFields gets encoded alias/field/type entries and
// AErrors alias=message. Any thread. Without AToken the session of
// TRpAuthManager is used.
procedure CollectAgentSchemaOnlyContext(AReport: TRpReport; AFields,
  AErrors: TStrings); overload;
procedure CollectAgentSchemaOnlyContext(AReport: TRpReport; AFields,
  AErrors: TStrings; const AToken, AInstallId: string); overload;
// The context of the design assistant: the expression context of the
// report evaluator and the runtime state of every datasource
function BuildDesignExpressionContextJson(AReport: TRpReport; ARpAlias: TRpAlias;
  AOpenErrors, ASchemaOnlyFields, ASchemaOnlyErrors: TStrings;
  out AErrorMessage: string): string;
// The semantic context of the expression assistant (the VCL
// BuildExpressionSemanticContextJson without a dialog)
function RpBuildExpressionSemanticContextJson(AEvaluator: TRpCustomEvaluator;
  AReport: TRpReport; ASchemaOnlyFields: TStrings): string;
// Entries of CollectAgentSchemaOnlyContext
function SchemaFieldEntryAlias(const AEntry: string): string;
function SchemaFieldEntryFieldName(const AEntry: string): string;
function SchemaFieldEntryDataType(const AEntry: string): string;

implementation

uses
  StrUtils, DB, Math, LazUTF8, rpjsonfpc, rpdatainfo, rpparams, rpdatahttp,
  rpauthmanager, rplabelitem;

const
  CSchemaFieldSep = #1;

type
  TRpExprChatPayloadKind = (
    rpecUpdateStreamingResponse,
    rpecBeginRetry,
    rpecAddAssistantMessage,
    rpecSetSuggestedExpression,
    rpecUpdateUserProfile
  );

  // TRpQueuedExpressionChatPayload of the VCL. The texts are composed in the
  // main thread (TranslateStr): Text1 is the English default of TextId, or a
  // text of the server when TextId is 0.
  TRpExprChatPayload = class(TRpAsyncMessage)
  public
    Kind: TRpExprChatPayloadKind;
    RequestVersion: Integer;
    Actor1: string;
    ProgressId1: string;
    ChunkType1: string;
    Text1: string;
    TextId: Integer;
    LogText1: string;
    Explanation: string;
    ValidationError: string;
    Fixed: Boolean;
    StillInvalid: Boolean;
    PrefillPercent: Integer;
    InputTokens: Integer;
    OutputTokens: Integer;
    UserProfileJson: string;
  end;

  // TRpQueuedExpressionRefreshPayload of the VCL
  TRpExprRefreshPayload = class(TRpAsyncMessage)
  public
    RequestVersion: Integer;
    ErrorMessage: string;
    OpenErrors: TStringList;
    SchemaOnlyFields: TStringList;
    SchemaOnlyErrors: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

  { The expression request (the anonymous thread of SendExpressionPrompt) }

  TRpExpressionChatWorker = class(TRpAsyncWorker)
  private
    FStreamResult: TJSONObject;
    FStreamError: string;
    FValidateExpression: string;
    FValidateOk: Boolean;
    FValidateError: string;
  public
    Dialog: TFRpExpreDialogLCL;
    Cancel: IRpAsyncCancel;
    RequestVersion: Integer;
    Prompt: string;
    CurrentExpression: string;
    CursorPosition: Integer;
    AITier: string;
    AIMode: string;
    AgentSecret: string;
    AgentAiId: Int64;
    SemanticContext: string;
    Token: string;
    InstallId: string;
    destructor Destroy; override;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
    function Cancelled: Boolean;
    function NewPayload(AKind: TRpExprChatPayloadKind): TRpExprChatPayload;
    procedure PostText(const AText: string; ATextId: Integer);
    procedure ResetStreamState;
    // Main thread (Synchronize); checks OwnerGone first
    procedure SyncValidate;
    // rpdatahttp streaming callbacks (worker thread)
    procedure StreamProgress(Sender: TObject; const AActor, AStage,
      AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
      const AProgressId: string; APrefillPercent: Integer);
    procedure StreamResult(Sender: TObject; AResultJson: TJSONObject;
      const AErrorMessage: string);
    function StreamCancelRequested(Sender: TObject): Boolean;
  end;

  { The dataset refresh (the anonymous thread of StartReportRefresh) }

  TRpExpressionRefreshWorker = class(TRpAsyncWorker)
  public
    Report: TRpReport;
    RequestVersion: Integer;
    Token: string;
    InstallId: string;
    // Signalled when the report is not used any more
    Done: IRpAsyncCancel;
  protected
    procedure Run; override;
  end;

{ Schema entries: alias #1 field #1 type }

function EncodeSchemaFieldEntry(const ADatasetAlias, AFieldName,
  ADataType: string): string;
begin
  Result := Trim(ADatasetAlias) + CSchemaFieldSep + Trim(AFieldName) +
    CSchemaFieldSep + Trim(ADataType);
end;

function SchemaFieldEntryAlias(const AEntry: string): string;
var
  LPos: Integer;
begin
  LPos := Pos(CSchemaFieldSep, AEntry);
  if LPos > 0 then
    Result := Copy(AEntry, 1, LPos - 1)
  else
    Result := '';
end;

function SchemaFieldEntryFieldName(const AEntry: string): string;
var
  LFirstPos, LSecondPos: Integer;
begin
  Result := '';
  LFirstPos := Pos(CSchemaFieldSep, AEntry);
  if LFirstPos <= 0 then
    Exit;
  LSecondPos := PosEx(CSchemaFieldSep, AEntry, LFirstPos + 1);
  if LSecondPos > 0 then
    Result := Copy(AEntry, LFirstPos + 1, LSecondPos - LFirstPos - 1)
  else
    Result := Copy(AEntry, LFirstPos + 1, MaxInt);
end;

function SchemaFieldEntryDataType(const AEntry: string): string;
var
  LFirstPos, LSecondPos: Integer;
begin
  Result := '';
  LFirstPos := Pos(CSchemaFieldSep, AEntry);
  if LFirstPos <= 0 then
    Exit;
  LSecondPos := PosEx(CSchemaFieldSep, AEntry, LFirstPos + 1);
  if LSecondPos > 0 then
    Result := Copy(AEntry, LSecondPos + 1, MaxInt);
end;

function MapSchemaTypeToSemanticType(const ADataType: string): string;
var
  LType: string;
begin
  LType := LowerCase(Trim(ADataType));
  if (LType = 'system.int16') or (LType = 'system.int32') or
    (LType = 'system.int64') or (LType = 'int16') or (LType = 'int32') or
    (LType = 'int64') then
    Result := 'integer'
  else if (LType = 'system.decimal') or (LType = 'system.double') or
    (LType = 'system.single') or (LType = 'decimal') or (LType = 'double') or
    (LType = 'single') then
    Result := 'float'
  else if LType = 'system.boolean' then
    Result := 'boolean'
  else if LType = 'system.datetime' then
    Result := 'datetime'
  else if LType = 'system.byte[]' then
    Result := 'blob'
  else
    Result := 'string';
end;

function GetMappedError(AErrors: TStrings; const AAlias, AName: string): string;
var
  LIndex: Integer;
begin
  Result := '';
  if AErrors = nil then
    Exit;
  LIndex := AErrors.IndexOfName(Trim(AAlias));
  if LIndex >= 0 then
  begin
    Result := Trim(AErrors.ValueFromIndex[LIndex]);
    if Result <> '' then
      Exit;
  end;
  if Trim(AName) <> '' then
  begin
    LIndex := AErrors.IndexOfName(Trim(AName));
    if LIndex >= 0 then
      Result := Trim(AErrors.ValueFromIndex[LIndex]);
  end;
end;

// FPC 3.2.2 has no ftSingle/ftExtended (the VCL maps them to 'float')
function GetSemanticFieldDataType(AFieldType: TFieldType): string;
begin
  case AFieldType of
    ftString, ftWideString, ftFixedChar:
      Result := 'string';
    ftSmallint, ftInteger, ftWord, ftAutoInc, ftLargeint:
      Result := 'integer';
    ftFloat, ftBCD, ftFMTBcd:
      Result := 'float';
    ftCurrency:
      Result := 'currency';
    ftDate:
      Result := 'date';
    ftTime:
      Result := 'time';
    ftDateTime:
      Result := 'datetime';
    ftBoolean:
      Result := 'boolean';
    ftMemo, ftWideMemo:
      Result := 'memo';
    ftBlob, ftGraphic, ftBytes, ftVarBytes:
      Result := 'blob';
  else
    Result := 'unknown';
  end;
end;

function GetSemanticParamType(AParamType: TRpParamType): string;
begin
  case AParamType of
    rpParamString:
      Result := 'string';
    rpParamInteger:
      Result := 'integer';
    rpParamDouble:
      Result := 'float';
    rpParamDate:
      Result := 'date';
    rpParamTime:
      Result := 'time';
    rpParamDateTime:
      Result := 'datetime';
    rpParamCurrency:
      Result := 'currency';
    rpParamBool:
      Result := 'boolean';
    rpParamExpreB:
      Result := 'expression_boolean';
    rpParamExpreA:
      Result := 'expression_string';
    rpParamSubst:
      Result := 'substitution';
    rpParamList:
      Result := 'list';
    rpParamMultiple:
      Result := 'multiple';
    rpParamSubstE:
      Result := 'substitution_expression';
    rpParamSubstList:
      Result := 'substitution_list';
    rpParamInitialExpression:
      Result := 'initial_expression';
  else
    Result := 'unknown';
  end;
end;

// Text of a JSON value; nil and null are empty (Delphi returns 'null')
function JsonText(AValue: TJSONValue): string;
begin
  if (AValue = nil) or (AValue is TJSONNull) then
    Result := ''
  else
    Result := AValue.Value;
end;

// [DATASET_COLUMNS alias columns] ... [/DATASET_COLUMNS]: TStringBuilder with
// AppendLine in the VCL (sLineBreak of the platform)
function BuildDatasetColumnsBlock(const ADatasetAlias: string;
  AColumns: TStrings): string;
var
  K: Integer;
begin
  Result := '[DATASET_COLUMNS ' + ADatasetAlias + ' columns]' + sLineBreak;
  for K := 0 to AColumns.Count - 1 do
    Result := Result + AColumns[K] + sLineBreak;
  Result := Result + '[/DATASET_COLUMNS]';
end;

procedure PopulateAliasFromReport(AReport: TRpReport; ATargetAlias: TRpAlias);
var
  I: Integer;
  LItem: TRpAliasListItem;
begin
  if (ATargetAlias = nil) or (AReport = nil) then
    Exit;
  ATargetAlias.List.Clear;
  for I := 0 to AReport.DataInfo.Count - 1 do
  begin
    LItem := ATargetAlias.List.Add;
    LItem.Alias := AReport.DataInfo.Items[I].Alias;
{$IFDEF USERPDATASET}
    if AReport.DataInfo.Items[I].Cached then
      LItem.Dataset := AReport.DataInfo.Items[I].CachedDataset
    else
{$ENDIF}
      LItem.Dataset := AReport.DataInfo.Items[I].Dataset;
  end;
end;

function CloneAlias(AOwner: TComponent; ASource: TRpAlias): TRpAlias;
var
  I: Integer;
  LNewItem: TRpAliasListItem;
begin
  Result := TRpAlias.Create(AOwner);
  if ASource = nil then
    Exit;
  for I := 0 to ASource.List.Count - 1 do
  begin
    LNewItem := Result.List.Add;
    LNewItem.Alias := ASource.List.Items[I].Alias;
    LNewItem.Dataset := ASource.List.Items[I].Dataset;
  end;
end;

// The connection of a dataset, nil when it does not exist.
// TRpDatabaseInfoList.ItemByName raises instead (the VCL code expects nil):
// a dataset without a valid connection would stop the whole context.
function FindDatabaseInfo(AReport: TRpReport; const AAlias: string): TRpDatabaseInfoItem;
var
  LIndex: Integer;
begin
  Result := nil;
  LIndex := AReport.DatabaseInfo.IndexOf(AAlias);
  if LIndex >= 0 then
    Result := AReport.DatabaseInfo.Items[LIndex];
end;

{ Agent datasets }

procedure CollectAgentSchemaOnlyContext(AReport: TRpReport; AFields,
  AErrors: TStrings);
begin
  CollectAgentSchemaOnlyContext(AReport, AFields, AErrors,
    TRpAuthManager.Instance.Token, TRpAuthManager.Instance.InstallId);
end;

procedure CollectAgentSchemaOnlyContext(AReport: TRpReport; AFields,
  AErrors: TStrings; const AToken, AInstallId: string);
var
  I, J: Integer;
  LDataInfo: TRpDataInfoItem;
  LDatabaseInfo: TRpDatabaseInfoItem;
  LHttp: TRpDatabaseHttp;
  LConnectionParams: TStringList;
  LResponse: TJSONObject;
  LRoot: TJSONObject;
  LColumns: TJSONArray;
  LRows: TJSONArray;
  LColumnIndexes: TStringList;
  LRow: TJSONArray;
  LColIndex: Integer;
  LDataTypeIndex: Integer;
  LFieldName: string;
  LDataType: string;
  LAlias: string;

  function GetColumnIndex(const AName: string): Integer;
  begin
    Result := LColumnIndexes.IndexOf(LowerCase(AName));
  end;

  function ReadCellString(ARow: TJSONArray; AIndex: Integer): string;
  begin
    Result := '';
    if (ARow = nil) or (AIndex < 0) or (AIndex >= ARow.Count) then
      Exit;
    Result := JsonText(ARow.Items[AIndex]);
  end;

begin
  if AFields <> nil then
    AFields.Clear;
  if AErrors <> nil then
    AErrors.Clear;
  if AReport = nil then
    Exit;

  LConnectionParams := TStringList.Create;
  LColumnIndexes := TStringList.Create;
  try
    for I := 0 to AReport.DataInfo.Count - 1 do
    begin
      LDataInfo := AReport.DataInfo.Items[I];
      if Trim(LDataInfo.SQL) = '' then
        Continue;

      LDatabaseInfo := FindDatabaseInfo(AReport, LDataInfo.DatabaseAlias);
      if (LDatabaseInfo = nil) or (LDatabaseInfo.Driver <> rpdbHttp) then
        Continue;

      LAlias := Trim(LDataInfo.Alias);
      if LAlias = '' then
        LAlias := Trim(LDataInfo.Name);

      LHttp := TRpDatabaseHttp.Create;
      LResponse := nil;
      try
        LConnectionParams.Clear;
        LDatabaseInfo.LoadConnectionParams(LConnectionParams);
        LHttp.ApiKey := LConnectionParams.Values['ApiKey'];
        LHttp.HubDatabaseId := StrToInt64Def(LConnectionParams.Values['HubDatabaseId'], 0);
        LHttp.HubSchemaId := LDataInfo.HubSchemaId;
        if (LHttp.ApiKey = '') and (AToken <> '') then
        begin
          LHttp.Token := AToken;
          LHttp.InstallId := AInstallId;
        end;

        LResponse := LHttp.GetTableSchema(LDataInfo.SQL);
        if LResponse = nil then
          raise Exception.Create('Empty schema response.');

        LRoot := LResponse;
        if LRoot.Values['data'] is TJSONObject then
          LRoot := TJSONObject(LRoot.Values['data']);
        if not ((LRoot.Values['columns'] is TJSONArray) and (LRoot.Values['rows'] is TJSONArray)) then
          raise Exception.Create('Invalid schema response format.');

        LColumns := TJSONArray(LRoot.Values['columns']);
        LRows := TJSONArray(LRoot.Values['rows']);
        LColumnIndexes.Clear;
        for LColIndex := 0 to LColumns.Count - 1 do
          LColumnIndexes.Add(LowerCase(TJSONObject(LColumns.Items[LColIndex]).Values['name'].Value));

        LColIndex := GetColumnIndex('ColumnName');
        LDataTypeIndex := GetColumnIndex('DataType');
        for J := 0 to LRows.Count - 1 do
        begin
          if not (LRows.Items[J] is TJSONArray) then
            Continue;
          LRow := TJSONArray(LRows.Items[J]);
          LFieldName := ReadCellString(LRow, LColIndex);
          LDataType := MapSchemaTypeToSemanticType(ReadCellString(LRow, LDataTypeIndex));
          if (Trim(LFieldName) <> '') and (AFields <> nil) then
            AFields.Add(EncodeSchemaFieldEntry(LAlias, LFieldName, LDataType));
        end;
      except
        on E: Exception do
          if AErrors <> nil then
            AErrors.Values[LAlias] := E.Message;
      end;
      LResponse.Free;
      LHttp.Free;
    end;
  finally
    LColumnIndexes.Free;
    LConnectionParams.Free;
  end;
end;

{ Semantic context of the expression assistant }

function RpBuildExpressionSemanticContextJson(AEvaluator: TRpCustomEvaluator;
  AReport: TRpReport; ASchemaOnlyFields: TStrings): string;
var
  LAlias: string;
  LAliasItem: TRpAliasListItem;
  LDataset: TDataSet;
  LParam: TRpParam;
  LField: TField;
  LRoot: TJSONObject;
  LDatasetColumnsBlocks: TJSONArray;
  LFunctions: TJSONArray;
  LConstants: TJSONArray;
  LDatasetColumnsMap: TStringList;
  LMemoryVariables: TStringList;
  I, J: Integer;
  LIdentifier: TRpIdentifier;

  function CreateCatalogEntry(const AModel, AHelp: string): TJSONObject;
  begin
    Result := TJSONObject.Create;
    Result.AddPair('model', AModel);
    if Trim(AHelp) <> '' then
      Result.AddPair('help', AHelp);
  end;

  function EnsureDatasetColumnList(const ADatasetAlias: string): TStringList;
  var
    LIndex: Integer;
  begin
    LIndex := LDatasetColumnsMap.IndexOf(ADatasetAlias);
    if LIndex >= 0 then
      Result := TStringList(LDatasetColumnsMap.Objects[LIndex])
    else
    begin
      Result := TStringList.Create;
      Result.CaseSensitive := False;
      Result.Duplicates := dupIgnore;
      LDatasetColumnsMap.AddObject(ADatasetAlias, Result);
    end;
  end;

  procedure AddDatasetColumn(const ADatasetAlias, AFieldName, AFieldType: string);
  var
    LColumns: TStringList;
    LEntry: string;
  begin
    if Trim(ADatasetAlias) = '' then
      Exit;
    if Trim(AFieldName) = '' then
      Exit;
    LColumns := EnsureDatasetColumnList(ADatasetAlias);
    LEntry := AFieldName + ':' + AFieldType;
    if LColumns.IndexOf(LEntry) < 0 then
      LColumns.Add(LEntry);
  end;

  function BuildMemoryVariablesBlock(AVariables: TStrings): string;
  var
    K: Integer;
  begin
    Result := '[MEMORY_VARIABLES]' + sLineBreak;
    for K := 0 to AVariables.Count - 1 do
      Result := Result + AVariables[K] + sLineBreak;
    Result := Result + '[/MEMORY_VARIABLES]';
  end;

  procedure AddIdentifierToCategories(AIdentifier: TRpIdentifier);
  begin
    if AIdentifier is TIdenRpExpression then
      Exit;
    if Trim(AIdentifier.AIHelp) = '' then
      Exit;
    case AIdentifier.RType of
      RTypeidenfunction:
        LFunctions.AddElement(CreateCatalogEntry(AIdentifier.Model, Trim(AIdentifier.AIHelp)));
      RTypeidenconstant:
        LConstants.AddElement(CreateCatalogEntry(AIdentifier.Model, Trim(AIdentifier.AIHelp)));
    end;
  end;

begin
  LRoot := TJSONObject.Create;
  LDatasetColumnsMap := TStringList.Create;
  LMemoryVariables := TStringList.Create;
  try
    LDatasetColumnsBlocks := TJSONArray.Create;
    LFunctions := TJSONArray.Create;
    LConstants := TJSONArray.Create;
    LRoot.AddPair('datasetColumnsBlocks', LDatasetColumnsBlocks);
    LRoot.AddPair('functions', LFunctions);
    LRoot.AddPair('constants', LConstants);

    // Live columns of the datasets of the evaluator alias
    if (AEvaluator <> nil) and (AEvaluator.Rpalias <> nil) then
    begin
      for I := 0 to AEvaluator.Rpalias.List.Count - 1 do
      begin
        LAliasItem := AEvaluator.Rpalias.List.Items[I];
        if LAliasItem = nil then
          Continue;
        LDataset := LAliasItem.Dataset;
        if LDataset = nil then
          Continue;
        LAlias := LAliasItem.Alias;
        for J := 0 to LDataset.FieldCount - 1 do
        begin
          LField := LDataset.Fields[J];
          AddDatasetColumn(LAlias, LField.FieldName,
            GetSemanticFieldDataType(LField.DataType));
        end;
      end;
    end;

    // Columns of the Agent datasets (Hub schema)
    if ASchemaOnlyFields <> nil then
    begin
      for I := 0 to ASchemaOnlyFields.Count - 1 do
      begin
        if Trim(ASchemaOnlyFields[I]) = '' then
          Continue;
        AddDatasetColumn(SchemaFieldEntryAlias(ASchemaOnlyFields[I]),
          SchemaFieldEntryFieldName(ASchemaOnlyFields[I]),
          SchemaFieldEntryDataType(ASchemaOnlyFields[I]));
      end;
    end;

    // Report parameters (memory variables M.<name>)
    if AReport <> nil then
    begin
      for I := 0 to AReport.Params.Count - 1 do
      begin
        LParam := AReport.Params.Items[I];
        if LParam = nil then
          Continue;
        LMemoryVariables.Add('M.' + LParam.Name + ':' +
          GetSemanticParamType(LParam.ParamType));
      end;
    end;

    for I := 0 to LDatasetColumnsMap.Count - 1 do
      LDatasetColumnsBlocks.Add(BuildDatasetColumnsBlock(
        LDatasetColumnsMap[I], TStringList(LDatasetColumnsMap.Objects[I])));

    if LMemoryVariables.Count > 0 then
      LRoot.AddPair('memoryVariablesBlock',
        BuildMemoryVariablesBlock(LMemoryVariables));

    // Functions and constants with an AI help
    if AEvaluator <> nil then
    begin
      for I := 0 to AEvaluator.Identifiers.Count - 1 do
      begin
        LIdentifier := TRpIdentifier(AEvaluator.Identifiers.Objects[I]);
        if LIdentifier <> nil then
          AddIdentifierToCategories(LIdentifier);
      end;
    end;

    Result := LRoot.ToJSON;
  finally
    for I := 0 to LDatasetColumnsMap.Count - 1 do
      LDatasetColumnsMap.Objects[I].Free;
    LDatasetColumnsMap.Free;
    LMemoryVariables.Free;
    LRoot.Free;
  end;
end;

{ Context of the design assistant }

function BuildDesignExpressionContextJson(AReport: TRpReport; ARpAlias: TRpAlias;
  AOpenErrors, ASchemaOnlyFields, ASchemaOnlyErrors: TStrings;
  out AErrorMessage: string): string;
var
  LRoot: TJSONObject;
  LExpressionContext: TJSONObject;
  LParsed: TJSONValue;
  LRuntimeDataSources: TJSONArray;
  LTargetAlias: TRpAlias;
  LOldAlias: TRpAlias;
  LOwnAlias: Boolean;
  I: Integer;
  LDataInfo: TRpDataInfoItem;
  LRuntimeSource: TJSONObject;
  LRuntimeDatasetColumns: TStringList;
  LIssues: TJSONArray;
  LDataSourceName: string;
  LDataSourceError: string;
  LRuntimeSourceName: string;
  LDatabaseInfo: TRpDatabaseInfoItem;

  procedure AddIssue(AIssues: TJSONArray; const ASeverity, ACode,
    AMessage: string);
  var
    LIssue: TJSONObject;
  begin
    LIssue := TJSONObject.Create;
    LIssue.AddPair('severity', ASeverity);
    LIssue.AddPair('code', ACode);
    LIssue.AddPair('message', AMessage);
    AIssues.AddElement(LIssue);
  end;

  function BuildRuntimeSource(const AName, AAlias, AStatus, ASource: string;
    ARefreshRequired: Boolean; const ADatasetColumnsBlock: string;
    AIssues: TJSONArray): TJSONObject;
  var
    LRuntimeSchema: TJSONObject;
  begin
    Result := TJSONObject.Create;
    Result.AddPair('name', AName);
    if Trim(AAlias) <> '' then
      Result.AddPair('alias', AAlias);
    LRuntimeSchema := TJSONObject.Create;
    LRuntimeSchema.AddPair('status', AStatus);
    LRuntimeSchema.AddPair('source', ASource);
    LRuntimeSchema.AddPair('refreshRequired', TJSONBool.Create(ARefreshRequired));
    if Trim(ADatasetColumnsBlock) <> '' then
      LRuntimeSchema.AddPair('datasetColumnsBlock', ADatasetColumnsBlock);
    LRuntimeSchema.AddPair('issues', AIssues);
    Result.AddPair('runtimeSchema', LRuntimeSchema);
  end;

  procedure AddLiveRuntimeColumns(AColumns: TStrings; ADataset: TDataSet);
  var
    K: Integer;
    LCurrentField: TField;
  begin
    if ADataset = nil then
      Exit;
    for K := 0 to ADataset.FieldCount - 1 do
    begin
      LCurrentField := ADataset.Fields[K];
      AColumns.Add(LCurrentField.FieldName + ':' +
        GetSemanticFieldDataType(LCurrentField.DataType));
    end;
  end;

  procedure AddSchemaOnlyRuntimeColumns(AColumns: TStrings;
    const ADatasetAlias: string; ASchemaOnlyEntries: TStrings);
  var
    K: Integer;
    LEntry: string;
  begin
    if ASchemaOnlyEntries = nil then
      Exit;
    for K := 0 to ASchemaOnlyEntries.Count - 1 do
    begin
      LEntry := Trim(ASchemaOnlyEntries[K]);
      if LEntry = '' then
        Continue;
      if not SameText(Trim(SchemaFieldEntryAlias(LEntry)), Trim(ADatasetAlias)) then
        Continue;
      AColumns.Add(SchemaFieldEntryFieldName(LEntry) + ':' +
        SchemaFieldEntryDataType(LEntry));
    end;
  end;

  function BuildRuntimeDatasetColumnsBlock(const ADatasetAlias: string;
    AColumns: TStrings): string;
  begin
    if (AColumns = nil) or (AColumns.Count = 0) then
      Result := ''
    else
      Result := BuildDatasetColumnsBlock(ADatasetAlias, AColumns);
  end;

begin
  AErrorMessage := '';
  Result := '{}';
  if AReport = nil then
    Exit;

  LRoot := TJSONObject.Create;
  LOwnAlias := False;
  LTargetAlias := ARpAlias;
  LOldAlias := nil;
  try
    if LTargetAlias = nil then
    begin
      LTargetAlias := TRpAlias.Create(nil);
      LOwnAlias := True;
    end;
    if AReport.Evaluator <> nil then
      LOldAlias := AReport.Evaluator.Rpalias;

    try
      PopulateAliasFromReport(AReport, LTargetAlias);
      if AReport.Evaluator = nil then
        raise Exception.Create('The report evaluator is not available after dataset refresh.');
      AReport.Evaluator.Rpalias := LTargetAlias;
      LParsed := TJSONObject.ParseJSONValue(RpBuildExpressionSemanticContextJson(
        AReport.Evaluator, AReport, ASchemaOnlyFields));
      if LParsed is TJSONObject then
        LExpressionContext := TJSONObject(LParsed)
      else
      begin
        LParsed.Free;
        LExpressionContext := TJSONObject.Create;
      end;
    except
      on E: Exception do
      begin
        AErrorMessage := E.Message;
        LExpressionContext := TJSONObject.Create;
      end;
    end;

    LRuntimeDataSources := TJSONArray.Create;
    LRoot.AddPair('expressionContext', LExpressionContext);
    LRoot.AddPair('runtimeDataSources', LRuntimeDataSources);

    for I := 0 to AReport.DataInfo.Count - 1 do
    begin
      LDataInfo := AReport.DataInfo.Items[I];
      LDataSourceName := Trim(LDataInfo.Name);
      if LDataSourceName = '' then
        LDataSourceName := Trim(LDataInfo.Alias);
      LRuntimeDatasetColumns := TStringList.Create;
      try
        LRuntimeDatasetColumns.Duplicates := dupIgnore;
        LRuntimeDatasetColumns.CaseSensitive := False;
        LIssues := TJSONArray.Create;
        LDatabaseInfo := FindDatabaseInfo(AReport, LDataInfo.DatabaseAlias);
        if (LDatabaseInfo <> nil) and (LDatabaseInfo.Driver = rpdbHttp) then
          LRuntimeSourceName := 'agent_schema_only'
        else
          LRuntimeSourceName := 'delphi_evaluator';
        LDataSourceError := GetMappedError(AOpenErrors, LDataInfo.Alias, LDataSourceName);
        if LDataSourceError = '' then
          LDataSourceError := GetMappedError(ASchemaOnlyErrors, LDataInfo.Alias, LDataSourceName);

        if AErrorMessage = '' then
        begin
          if LRuntimeSourceName = 'agent_schema_only' then
            AddSchemaOnlyRuntimeColumns(LRuntimeDatasetColumns, LDataInfo.Alias,
              ASchemaOnlyFields)
          else
            AddLiveRuntimeColumns(LRuntimeDatasetColumns, LDataInfo.Dataset);

          if Trim(LDataSourceError) <> '' then
          begin
            if LRuntimeSourceName = 'agent_schema_only' then
              AddIssue(LIssues, 'error', 'datasource_schema_failed', LDataSourceError)
            else
              AddIssue(LIssues, 'error', 'datasource_open_failed', LDataSourceError);
            LRuntimeSource := BuildRuntimeSource(LDataSourceName, LDataInfo.Alias,
              'refresh_failed', LRuntimeSourceName, True,
              BuildRuntimeDatasetColumnsBlock(LDataInfo.Alias, LRuntimeDatasetColumns),
              LIssues);
          end
          else
          begin
            if LRuntimeDatasetColumns.Count = 0 then
              AddIssue(LIssues, 'info', 'no_live_fields',
                'No live fields were returned by the Delphi evaluator for this datasource.');
            LRuntimeSource := BuildRuntimeSource(LDataSourceName, LDataInfo.Alias,
              'live_context', LRuntimeSourceName, False,
              BuildRuntimeDatasetColumnsBlock(LDataInfo.Alias, LRuntimeDatasetColumns),
              LIssues);
          end;
        end
        else
        begin
          AddIssue(LIssues, 'error', 'refresh_failed', AErrorMessage);
          LRuntimeSource := BuildRuntimeSource(LDataSourceName, LDataInfo.Alias,
            'refresh_failed', LRuntimeSourceName, True,
            BuildRuntimeDatasetColumnsBlock(LDataInfo.Alias, LRuntimeDatasetColumns),
            LIssues);
        end;
        LRuntimeDataSources.AddElement(LRuntimeSource);
      finally
        LRuntimeDatasetColumns.Free;
      end;
    end;

    Result := LRoot.ToJSON;
  finally
    // The VCL leaves the report evaluator with an alias it frees when none
    // is given: put the previous one back
    if LOwnAlias then
    begin
      if (AReport.Evaluator <> nil) and (AReport.Evaluator.Rpalias = LTargetAlias) then
        AReport.Evaluator.Rpalias := LOldAlias;
      LTargetAlias.Free;
    end;
    LRoot.Free;
  end;
end;

{ Answers of SuggestExpressionStream (ExtractExpressionFromApiResult of the
  VCL). AErrorId: TranslateStr id of AErrorMessage, 0 for a text of the
  server. }

function ExtractExpressionFromApiResult(AResultJson: TJSONObject;
  const AStreamError: string; out AExpression, AExplanation,
  AErrorMessage: string; out AErrorId: Integer): Boolean;
var
  LValue: TJSONValue;
  LResultObj: TJSONObject;
begin
  Result := False;
  AExpression := '';
  AExplanation := '';
  AErrorId := 0;
  AErrorMessage := AStreamError;
  if AErrorMessage <> '' then
    Exit;
  if AResultJson = nil then
  begin
    AErrorMessage := 'No final response received';
    AErrorId := 1606;
    Exit;
  end;

  AErrorMessage := JsonText(AResultJson.Values['errorMessage']);
  if AErrorMessage <> '' then
    Exit;

  LValue := AResultJson.Values['result'];
  if not (LValue is TJSONObject) then
  begin
    AErrorMessage := 'Response without result';
    AErrorId := 1607;
    Exit;
  end;
  LResultObj := TJSONObject(LValue);

  AExpression := JsonText(LResultObj.Values['expression']);
  AExplanation := JsonText(LResultObj.Values['explanation']);

  if AExpression = '' then
  begin
    AErrorMessage := JsonText(LResultObj.Values['errorMessage']);
    if AErrorMessage = '' then
    begin
      if Trim(AExplanation) <> '' then
        AErrorMessage := AExplanation
      else
      begin
        AErrorMessage := 'Empty expression returned';
        AErrorId := 1608;
      end;
    end;
    Exit;
  end;

  Result := True;
end;

function GetExpressionPrefillPercent(const AStage, AChunkType: string): Integer;
begin
  if SameText(AStage, 'PreparingContext') then
    Result := 10
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

{ TRpExprRefreshPayload }

constructor TRpExprRefreshPayload.Create;
begin
  inherited Create;
  OpenErrors := TStringList.Create;
  SchemaOnlyFields := TStringList.Create;
  SchemaOnlyErrors := TStringList.Create;
end;

destructor TRpExprRefreshPayload.Destroy;
begin
  OpenErrors.Free;
  SchemaOnlyFields.Free;
  SchemaOnlyErrors.Free;
  inherited Destroy;
end;

{ TRpExpressionChatWorker }

destructor TRpExpressionChatWorker.Destroy;
begin
  FStreamResult.Free;
  inherited Destroy;
end;

function TRpExpressionChatWorker.Cancelled: Boolean;
begin
  Result := OwnerGone or ((Cancel <> nil) and Cancel.Cancelled);
end;

function TRpExpressionChatWorker.NewPayload(
  AKind: TRpExprChatPayloadKind): TRpExprChatPayload;
begin
  Result := TRpExprChatPayload.Create;
  Result.Kind := AKind;
  Result.RequestVersion := RequestVersion;
end;

procedure TRpExpressionChatWorker.PostText(const AText: string; ATextId: Integer);
var
  LPayload: TRpExprChatPayload;
begin
  LPayload := NewPayload(rpecAddAssistantMessage);
  LPayload.Text1 := AText;
  LPayload.TextId := ATextId;
  Post(LPayload);
end;

procedure TRpExpressionChatWorker.ResetStreamState;
begin
  FreeAndNil(FStreamResult);
  FStreamError := '';
end;

procedure TRpExpressionChatWorker.StreamProgress(Sender: TObject; const AActor,
  AStage, AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer);
var
  LPayload: TRpExprChatPayload;
  LPrefill: Integer;
  LPartial: Boolean;
begin
  if Cancelled then
    Exit;
  LPartial := SameText(AStage, 'ReceivingResponse') and SameText(AChunkType, 'Partial');
  LPrefill := APrefillPercent;
  if LPrefill <= 0 then
    LPrefill := GetExpressionPrefillPercent(AStage, AChunkType);
  LPayload := NewPayload(rpecUpdateStreamingResponse);
  LPayload.Actor1 := AActor;
  LPayload.ProgressId1 := AProgressId;
  LPayload.ChunkType1 := AChunkType;
  if LPartial then
    LPayload.Text1 := AChunk;
  if Trim(AChunk) <> '' then
  begin
    if LPartial then
      LPayload.LogText1 := AChunk
    else
      LPayload.LogText1 := '[' + AStage + '] ' + AChunk + sLineBreak;
  end;
  LPayload.PrefillPercent := LPrefill;
  LPayload.InputTokens := AInputTokens;
  LPayload.OutputTokens := AOutputTokens;
  Post(LPayload);
end;

procedure TRpExpressionChatWorker.StreamResult(Sender: TObject;
  AResultJson: TJSONObject; const AErrorMessage: string);
begin
  // The callback owns AResultJson ([DONE] passes nil)
  if AErrorMessage <> '' then
    FStreamError := AErrorMessage;
  if AResultJson <> nil then
  begin
    FStreamResult.Free;
    FStreamResult := AResultJson;
  end;
end;

function TRpExpressionChatWorker.StreamCancelRequested(Sender: TObject): Boolean;
begin
  Result := Cancelled;
end;

procedure TRpExpressionChatWorker.SyncValidate;
begin
  FValidateOk := False;
  FValidateError := '';
  if OwnerGone or (Dialog = nil) then
    Exit;
  FValidateOk := Dialog.ValidateExpressionText(FValidateExpression, FValidateError);
end;

procedure TRpExpressionChatWorker.HandleError(E: Exception);
begin
  if not Cancelled then
    PostText(E.Message, 0);
end;

procedure TRpExpressionChatWorker.Run;
var
  LHttp: TRpDatabaseHttp;
  LCurrentExpression: string;
  LExpression: string;
  LExplanation: string;
  LErrorMessage: string;
  LErrorId: Integer;
  LNeedRetry: Boolean;
  LPayload: TRpExprChatPayload;
begin
  LCurrentExpression := CurrentExpression;
  LNeedRetry := False;
  LHttp := TRpDatabaseHttp.Create;
  try
    LHttp.Token := Token;
    LHttp.InstallId := InstallId;
    LHttp.AITier := AITier;
    LHttp.AgentSecret := AgentSecret;
    LHttp.AgentAiId := AgentAiId;

    repeat
      ResetStreamState;
      if LNeedRetry then
        Post(NewPayload(rpecBeginRetry));

      LHttp.SuggestExpressionStream(Prompt, LCurrentExpression, CursorPosition,
        AIMode, LNeedRetry, SemanticContext, Self, StreamProgress,
        StreamResult, StreamCancelRequested);

      // Stop already updated the chat
      if Cancelled then
        Exit;

      if not ExtractExpressionFromApiResult(FStreamResult, FStreamError,
        LExpression, LExplanation, LErrorMessage, LErrorId) then
      begin
        PostText(LErrorMessage, LErrorId);
        Exit;
      end;

      if (FStreamResult <> nil) and (FStreamResult.Values['userProfile'] is TJSONObject) then
      begin
        LPayload := NewPayload(rpecUpdateUserProfile);
        LPayload.UserProfileJson := FStreamResult.Values['userProfile'].ToJSON;
        Post(LPayload);
      end;

      // Local validation with the evaluator of the dialog
      FValidateExpression := LExpression;
      SyncCall(SyncValidate);
      if Cancelled then
        Exit;

      if (not LNeedRetry) and (not FValidateOk) then
      begin
        // One automatic fix
        LCurrentExpression := LExpression;
        LNeedRetry := True;
        Continue;
      end;

      LPayload := NewPayload(rpecSetSuggestedExpression);
      LPayload.Text1 := LExpression;
      LPayload.Explanation := LExplanation;
      LPayload.Fixed := LNeedRetry;
      LPayload.StillInvalid := not FValidateOk;
      LPayload.ValidationError := FValidateError;
      Post(LPayload);
      Break;
    until False;
  finally
    LHttp.Free;
  end;
end;

{ TRpExpressionRefreshWorker }

procedure TRpExpressionRefreshWorker.Run;
var
  LPayload: TRpExprRefreshPayload;
begin
  LPayload := TRpExprRefreshPayload.Create;
  try
    try
      LPayload.RequestVersion := RequestVersion;
      try
        Report.PrepareLiveContext(LPayload.OpenErrors);
        CollectAgentSchemaOnlyContext(Report, LPayload.SchemaOnlyFields,
          LPayload.SchemaOnlyErrors, Token, InstallId);
      except
        on E: Exception do
          LPayload.ErrorMessage := E.Message;
      end;
      Post(LPayload);
      LPayload := nil;
    finally
      LPayload.Free;
    end;
  finally
    if Done <> nil then
      Done.Cancel;
  end;
end;

{ Dialog functions }

function ChangeExpression(const formul: string; aval: TRpCustomEvaluator): string;
var
  dia: TFRpExpreDialogLCL;
begin
  Result := formul;
  dia := TFRpExpreDialogLCL.Create(Application);
  try
    if not Assigned(aval) then
      dia.InitializeDialog(formul, TRpEvaluator.Create(nil), True, False, True)
    else
      dia.InitializeDialog(formul, aval, False, False, True);
    dia.ShowModal;
    if dia.DoOk then
      Result := dia.MemoExpre.Text;
  finally
    dia.Free;
  end;
end;

function ChangeExpressionW(const formul: WideString; aval: TRpCustomEvaluator): WideString;
begin
  Result := WideString(ChangeExpression(string(formul), aval));
end;

function ExpressionCalculateW(const formul: WideString; aval: TRpCustomEvaluator): Variant;
var
  dia: TFRpExpreDialogLCL;
begin
  Result := Null;
  dia := TFRpExpreDialogLCL.Create(Application);
  try
    if not Assigned(aval) then
      dia.InitializeDialog(string(formul), TRpEvaluator.Create(nil), True, True, False)
    else
      dia.InitializeDialog(string(formul), aval, False, True, False);
    dia.ShowModal;
    if dia.DoOk then
      Result := dia.AResult;
  finally
    dia.Free;
  end;
end;

{ TFRpExpreDialogLCL }

constructor TFRpExpreDialogLCL.Create(AOwner: TComponent);
var
  i: Integer;
begin
  inherited CreateNew(AOwner);
  Caption := TranslateStr(240, 'Expression build');
  Width := Scale96ToScreen(1040);
  Height := Scale96ToScreen(600);
  Constraints.MinWidth := Scale96ToScreen(760);
  Constraints.MinHeight := Scale96ToScreen(460);
  Position := poScreenCenter;
  BorderStyle := bsSizeable;
  ShowHint := True;

  for i := 0 to FMaxListHelp - 1 do
    FLists[i] := TStringList.Create;
  FMailbox := TRpAsyncMailbox.Create(HandleAsyncMessage);
  FMailboxRef := FMailbox;
  FEmptyAlias := TRpAlias.Create(Self);
  FSchemaOnlyFields := TStringList.Create;
  FSchemaOnlyErrors := TStringList.Create;
  FAliasReady := True;

  BuildControls;
  UpdateRefreshUIState;
end;

destructor TFRpExpreDialogLCL.Destroy;
var
  i: Integer;
begin
  Application.RemoveAsyncCalls(Self);
  // Running requests stop and their messages are dropped
  FMailbox.Detach;
  if FExpressionCancel <> nil then
    FExpressionCancel.Cancel;
  FExpressionCancel := nil;
  // The report is not left to a worker
  WaitForReportRefresh;
  if (FEvaluator <> nil) and (not FOwnsEvaluator) and (FEvaluator.Rpalias = FEmptyAlias) then
    FEvaluator.Rpalias := nil;
  ReleaseOwnedEvaluator;
  FEvaluator := nil;
  ClearHelpLists;
  for i := 0 to FMaxListHelp - 1 do
    FreeAndNil(FLists[i]);
  FreeAndNil(FSchemaOnlyFields);
  FreeAndNil(FSchemaOnlyErrors);
  FMailboxRef := nil;
  inherited Destroy;
end;

procedure TFRpExpreDialogLCL.BuildControls;
var
  LPanelCategory, LPanelOperation, LPanelHelp: TPanel;

  function NewPanel(AParent: TWinControl; ALeft, AWidth: Integer;
    AAlign: TAlign): TPanel;
  begin
    Result := TPanel.Create(Self);
    Result.Parent := AParent;
    Result.BevelOuter := bvNone;
    Result.Caption := '';
    // alLeft/alRight controls are ordered by Left
    Result.SetBounds(ALeft, 0, AWidth, 100);
    Result.Align := AAlign;
  end;

  // The width of the longest caption: AutoSize buttons aligned to the sides
  // fight the alignment when they do not fit (narrow window, small screen)
  // and the LCL raises "InvalidatePreferredSize loop detected"
  function ButtonWidth(const ACaptions: array of string): Integer;
  var
    LBitmap: TBitmap;
    I: Integer;
  begin
    Result := Scale96ToScreen(75);
    LBitmap := TBitmap.Create;
    try
      LBitmap.Canvas.Font := Font;
      for I := 0 to High(ACaptions) do
        Result := Max(Result, LBitmap.Canvas.TextWidth(ACaptions[I]) + Scale96ToScreen(24));
    finally
      LBitmap.Free;
    end;
  end;

  function NewButton(AParent: TWinControl; const ACaption: string;
    ALeft: Integer; AAlign: TAlign; AClick: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := AParent;
    Result.Caption := ACaption;
    Result.SetBounds(ALeft, 0, ButtonWidth([ACaption]), Scale96ToScreen(26));
    Result.BorderSpacing.Around := Scale96ToScreen(4);
    Result.Align := AAlign;
    Result.OnClick := AClick;
  end;

  function NewLabel(AParent: TWinControl; const ACaption: string): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := AParent;
    Result.Caption := ACaption;
    Result.Align := alTop;
    Result.BorderSpacing.Bottom := Scale96ToScreen(2);
  end;

begin
  // AI assistant at the right (PChatHost of the VCL dialog)
  FPanelChat := NewPanel(Self, 20000, Scale96ToScreen(390), alRight);

  FSplitterChat := TSplitter.Create(Self);
  FSplitterChat.Parent := Self;
  FSplitterChat.SetBounds(19000, 0, 5, 100);
  FSplitterChat.Align := alRight;
  FSplitterChat.ResizeAnchor := akRight;

  // Classic editor at the left
  FPanelLeft := NewPanel(Self, 0, 400, alClient);

  // Expression
  FPanelTop := NewPanel(FPanelLeft, 0, 400, alTop);
  FPanelTop.Height := Scale96ToScreen(120);
  FPanelTop.BorderSpacing.Around := Scale96ToScreen(6);

  FMemoExpre := TMemo.Create(Self);
  FMemoExpre.Parent := FPanelTop;
  FMemoExpre.Align := alClient;
  FMemoExpre.ScrollBars := ssVertical;
  FMemoExpre.Font.Name := 'Courier New';
  FMemoExpre.Font.Size := 10;
  FMemoExpre.OnChange := MemoExpreChange;
  FMemoExpre.OnClick := MemoExpreClick;
  FMemoExpre.OnKeyUp := MemoExpreKeyUp;
  FMemoExpre.OnMouseUp := MemoExpreMouseUp;

  // Buttons
  FPanelBottom := NewPanel(FPanelLeft, 0, 400, alBottom);
  FPanelBottom.Height := Scale96ToScreen(42);
  FPanelBottom.BorderSpacing.Around := Scale96ToScreen(4);

  FBCancel := NewButton(FPanelBottom, TranslateStr(94, 'Cancel'), 10000, alRight,
    BCancelClick);
  FBCancel.Cancel := True;
  FBOK := NewButton(FPanelBottom, TranslateStr(93, 'OK'), 9000, alRight, BOKClick);
  FBOK.Default := True;

  FBRefresh := NewButton(FPanelBottom, TranslateStr(1149, 'Refresh'), 0, alLeft,
    BRefreshClick);
  // Also fits its caption while refreshing
  FBRefresh.Width := ButtonWidth([string(TranslateStr(1149, 'Refresh')),
    string(TranslateStr(1609, 'Refreshing...'))]);
  FBRefresh.Hint := TranslateStr(1610, 'Reopen datasets and refresh fields');
  FBAdd := NewButton(FPanelBottom, TranslateStr(243, 'Add selection'), 1000, alLeft,
    BAddClick);
  FBCheckSyn := NewButton(FPanelBottom, TranslateStr(244, 'Syntax check'), 2000, alLeft,
    BCheckSynClick);
  FBShowResult := NewButton(FPanelBottom, TranslateStr(246, 'Show result'), 3000, alLeft,
    BShowResultClick);

  // Category, operations and help
  FPanelCenter := NewPanel(FPanelLeft, 0, 400, alClient);
  FPanelCenter.BorderSpacing.Left := Scale96ToScreen(6);
  FPanelCenter.BorderSpacing.Right := Scale96ToScreen(6);

  LPanelCategory := NewPanel(FPanelCenter, 0, Scale96ToScreen(150), alLeft);
  FLabelCategory := NewLabel(LPanelCategory, TranslateStr(241, 'Category') + ':');
  FLCategory := TListBox.Create(Self);
  FLCategory.Parent := LPanelCategory;
  FLCategory.Align := alClient;
  FLCategory.Items.Add(TranslateStr(247, 'Database fields'));
  FLCategory.Items.Add(TranslateStr(248, 'Functions'));
  FLCategory.Items.Add(TranslateStr(249, 'Variables'));
  FLCategory.Items.Add(TranslateStr(250, 'Constants'));
  FLCategory.Items.Add(TranslateStr(251, 'Operators'));
  FLCategory.OnClick := LCategoryClick;

  LPanelOperation := NewPanel(FPanelCenter, 1000, Scale96ToScreen(210), alLeft);
  LPanelOperation.BorderSpacing.Left := Scale96ToScreen(8);
  FLOperationLabel := NewLabel(LPanelOperation, TranslateStr(242, 'Operation'));
  FLOperation := TListBox.Create(Self);
  FLOperation.Parent := LPanelOperation;
  FLOperation.Align := alClient;
  FLOperation.Sorted := True;
  FLOperation.OnClick := LOperationClick;
  FLOperation.OnDblClick := LOperationDblClick;

  LPanelHelp := NewPanel(FPanelCenter, 2000, 200, alClient);
  LPanelHelp.BorderSpacing.Left := Scale96ToScreen(8);
  FLabelHelp := NewLabel(LPanelHelp, SRpDescription + ':');
  FMemoHelp := TMemo.Create(Self);
  FMemoHelp.Parent := LPanelHelp;
  FMemoHelp.Align := alClient;
  FMemoHelp.ReadOnly := True;
  FMemoHelp.ScrollBars := ssVertical;
  FMemoHelp.WordWrap := True;
  FMemoHelp.Color := clBtnFace;

  // The common chat in expression mode: no schema selector, as the VCL
  FChat := TFRpChatFrame.Create(Self);
  FChat.Parent := FPanelChat;
  FChat.Align := alClient;
  FChat.SetShowSchemaSelector(False);
  FChat.OnSendPrompt := ChatSendPrompt;
  FChat.OnApplySuggestion := ChatApplySuggestion;
  FChat.OnStopRequest := StopExpressionRequest;
  FChat.Initialize('', TranslateStr(1600, SExpressionChatInitialMessage));
end;

procedure TFRpExpreDialogLCL.ClearHelpLists;
var
  i, j: Integer;
begin
  for i := 0 to FMaxListHelp - 1 do
  begin
    if FLists[i] = nil then
      Continue;
    for j := 0 to FLists[i].Count - 1 do
      FLists[i].Objects[j].Free;
    FLists[i].Clear;
  end;
end;

procedure TFRpExpreDialogLCL.ReleaseOwnedEvaluator;
begin
  if FOwnsEvaluator and (FEvaluator <> nil) then
    FreeAndNil(FEvaluator);
  FOwnsEvaluator := False;
end;

procedure TFRpExpreDialogLCL.AssignEmptyAlias;
begin
  if FEmptyAlias <> nil then
    FEmptyAlias.List.Clear;
  // Only the evaluator of the dialog: an alias of the dialog must not stay
  // in an evaluator of somebody else
  if (FEvaluator <> nil) and FOwnsEvaluator then
    FEvaluator.Rpalias := FEmptyAlias;
end;

function TFRpExpreDialogLCL.BuildRefreshSnapshotEvaluator: TRpEvaluator;
var
  LAliasSnapshot: TRpAlias;
begin
  // The report evaluator is recreated by PrepareLiveContext in the worker:
  // the dialog uses a copy meanwhile
  Result := TRpEvaluator.Create(nil);
  if FRefreshReport <> nil then
    FRefreshReport.AddReportItemsToEvaluator(Result);
  if FAliasReady and (FRefreshAlias <> nil) then
    LAliasSnapshot := CloneAlias(Result, FRefreshAlias)
  else
    LAliasSnapshot := CloneAlias(Result, nil);
  Result.Rpalias := LAliasSnapshot;
end;

procedure TFRpExpreDialogLCL.InitializeDialog(const AExpression: string;
  AEvaluator: TRpCustomEvaluator; AOwnsEvaluator, AValidate,
  AWantReturns: Boolean);
begin
  FDoOk := False;
  FAResult := Null;
  FValidate := AValidate;
  FMemoExpre.WantReturns := AWantReturns;
  // A request of a previous use is dropped
  Inc(FExpressionRequestVersion);
  if FExpressionCancel <> nil then
    FExpressionCancel.Cancel;
  FExpressionCancel := nil;
  if (FEvaluator <> AEvaluator) and FOwnsEvaluator then
    ReleaseOwnedEvaluator;
  FOwnsEvaluator := AOwnsEvaluator;
  AssignEvaluator(AEvaluator);
  FMemoExpre.Text := AExpression;
  if FChat <> nil then
    FChat.Initialize(FMemoExpre.Text, TranslateStr(1600, SExpressionChatInitialMessage));
  FMemoExpre.SelStart := UTF8Length(FMemoExpre.Text);
  FMemoExpre.SelLength := 0;
  UpdateExpressionCursorPosition;
  FAliasReady := FEvaluator <> nil;
  UpdateRefreshUIState;
end;

procedure TFRpExpreDialogLCL.ConfigureReportRefresh(AReport: TRpReport;
  APrintDriver: TRpPrintDriver; ATargetAlias: TRpAlias);
begin
  // A refresh of the previous report is not left running
  WaitForReportRefresh;
  Inc(FRefreshVersion);
  FRefreshRunning := False;
  FRefreshReport := AReport;
  FRefreshPrintDriver := APrintDriver;
  FRefreshAlias := ATargetAlias;
  FSchemaOnlyFields.Clear;
  FSchemaOnlyErrors.Clear;
  if FRefreshReport <> nil then
  begin
    FAliasReady := False;
    AssignEmptyAlias;
  end
  else
    FAliasReady := FEvaluator <> nil;
  UpdateRefreshUIState;
end;

procedure TFRpExpreDialogLCL.SetSchemaOnlyContext(AFields, AErrors: TStrings);
begin
  FSchemaOnlyFields.Clear;
  if AFields <> nil then
    FSchemaOnlyFields.Assign(AFields);
  FSchemaOnlyErrors.Clear;
  if AErrors <> nil then
    FSchemaOnlyErrors.Assign(AErrors);
end;

procedure TFRpExpreDialogLCL.Resize;
var
  I, LNeeded, LMaxChat: Integer;
begin
  inherited Resize;
  if (FPanelChat = nil) or (FPanelBottom = nil) or (FSplitterChat = nil) then
    Exit;
  // The buttons of the classic editor must fit: in a narrow window the chat
  // gives up its width (down to a minimum)
  LNeeded := FPanelBottom.BorderSpacing.Around * 2 + Scale96ToScreen(16);
  for I := 0 to FPanelBottom.ControlCount - 1 do
    if FPanelBottom.Controls[I].Visible then
      LNeeded := LNeeded + FPanelBottom.Controls[I].Width +
        FPanelBottom.Controls[I].BorderSpacing.Around * 2;
  LMaxChat := ClientWidth - FSplitterChat.Width - LNeeded;
  if FPanelChat.Width > LMaxChat then
    FPanelChat.Width := Max(Scale96ToScreen(220), LMaxChat);
end;

procedure TFRpExpreDialogLCL.UpdateRefreshUIState;
begin
  if FBRefresh = nil then
    Exit;
  FBRefresh.Visible := FRefreshReport <> nil;
  if FRefreshRunning then
    FBRefresh.Caption := TranslateStr(1609, 'Refreshing...')
  else
    FBRefresh.Caption := TranslateStr(1149, 'Refresh');
end;

procedure TFRpExpreDialogLCL.StartReportRefresh;
var
  LWorker: TRpExpressionRefreshWorker;
begin
  if FRefreshRunning then
    Exit;
  if FRefreshReport = nil then
    Exit;

  Inc(FRefreshVersion);
  if not FOwnsEvaluator then
  begin
    AssignEvaluator(BuildRefreshSnapshotEvaluator);
    FOwnsEvaluator := True;
  end;
  FRefreshRunning := True;
  UpdateRefreshUIState;

  FRefreshDone := TRpAsyncCancel.Create;
  LWorker := TRpExpressionRefreshWorker.Create(FMailboxRef);
  LWorker.Report := FRefreshReport;
  LWorker.RequestVersion := FRefreshVersion;
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.InstallId := TRpAuthManager.Instance.InstallId;
  LWorker.Done := FRefreshDone;
  LWorker.Start;
end;

procedure TFRpExpreDialogLCL.WaitForReportRefresh;
begin
  if FRefreshDone = nil then
    Exit;
  // The worker may be waiting for the main thread (Synchronize)
  while not FRefreshDone.Cancelled do
    CheckSynchronize(10);
  FRefreshDone := nil;
end;

procedure TFRpExpreDialogLCL.HandleRefreshPayload(APayload: TObject);
var
  LPayload: TRpExprRefreshPayload;
begin
  LPayload := TRpExprRefreshPayload(APayload);
  if LPayload.RequestVersion <> FRefreshVersion then
    Exit;

  FRefreshRunning := False;
  FRefreshDone := nil;
  if LPayload.ErrorMessage <> '' then
  begin
    FAliasReady := False;
    SetSchemaOnlyContext(nil, nil);
    UpdateRefreshUIState;
    ShowMessage(LPayload.ErrorMessage);
    Exit;
  end;

  SetSchemaOnlyContext(LPayload.SchemaOnlyFields, LPayload.SchemaOnlyErrors);
  PopulateAliasFromReport(FRefreshReport, FRefreshAlias);
  if FRefreshReport <> nil then
  begin
    if FOwnsEvaluator then
      ReleaseOwnedEvaluator;
    FOwnsEvaluator := False;
    // Without a target alias the report keeps its own (the one that
    // PrepareLiveContext fills with the open datasets)
    if (FRefreshReport.Evaluator <> nil) and (FRefreshAlias <> nil) then
      FRefreshReport.Evaluator.Rpalias := FRefreshAlias;
    AssignEvaluator(FRefreshReport.Evaluator);
  end;
  FAliasReady := True;
  UpdateRefreshUIState;
end;

// Help of an operator, same texts as TFRpExpredialogVCL (translated constants)
function OperatorHelp(const AOperator: string): string;
begin
  if AOperator = '+' then
    Result := SRpOperatorSum
  else if AOperator = '-' then
    Result := SRpOperatorDif
  else if AOperator = '*' then
    Result := SRpOperatorMul
  else if AOperator = '/' then
    Result := SRpOperatorDiv
  else if (AOperator = 'AND') or (AOperator = 'OR') or (AOperator = 'NOT') then
    Result := SRpOperatorLog
  else if (AOperator = '(') or (AOperator = ')') then
    Result := ''
  else
    Result := SRpOperatorComp;
end;

procedure TFRpExpreDialogLCL.SetEvaluator(const Value: TRpCustomEvaluator);
begin
  // An evaluator given by the caller is not owned by the dialog
  if Value <> FEvaluator then
    ReleaseOwnedEvaluator;
  AssignEvaluator(Value);
end;

procedure TFRpExpreDialogLCL.AssignEvaluator(const Value: TRpCustomEvaluator);
var
  list: TStringList;
  i: Integer;
  iden: TRpIdentifier;
  rec: TRpRecHelp;
  LName: string;
  operators: array[0..14] of string = (
    '+', '-', '*', '/', 'AND', 'OR', 'NOT', '=', '<>', '<', '>', '<=', '>=', '(', ')'
  );
begin
  FEvaluator := Value;
  ClearHelpLists;

  if not Assigned(FEvaluator) then
  begin
    FLOperation.Clear;
    FMemoHelp.Clear;
    UpdateRefreshUIState;
    Exit;
  end;

  // Category 0: Database fields
  list := FLists[0];
  if FEvaluator.RpAlias <> nil then
  begin
    FEvaluator.RpAlias.FillWithFields(list);
    for i := 0 to list.Count - 1 do
    begin
      rec := TRpRecHelp.Create;
      rec.RFunction := list.Strings[i];
      rec.Help := TranslateStr(372, 'Database field') + ': ' + list.Strings[i];
      rec.Model := list.Strings[i];
      list.Objects[i] := rec;
    end;
  end;
  // Columns of the Agent datasets, from the Hub (as the VCL)
  for i := 0 to FSchemaOnlyFields.Count - 1 do
  begin
    LName := SchemaFieldEntryAlias(FSchemaOnlyFields[i]) + '.' +
      SchemaFieldEntryFieldName(FSchemaOnlyFields[i]);
    if list.IndexOf(LName) >= 0 then
      Continue;
    rec := TRpRecHelp.Create;
    rec.RFunction := LName;
    rec.Help := TranslateStr(1611, 'Field from dataset') + ' ' +
      SchemaFieldEntryAlias(FSchemaOnlyFields[i]);
    rec.Model := LName + ':' + SchemaFieldEntryDataType(FSchemaOnlyFields[i]);
    list.AddObject(rec.RFunction, rec);
  end;

  // Category 1, 2, 3: Identifiers (Functions, Variables, Constants); the
  // expression items of the report are variables, as in the VCL
  for i := 0 to FEvaluator.Identifiers.Count - 1 do
  begin
    iden := TRpIdentifier(FEvaluator.Identifiers.Objects[i]);
    if iden = nil then
      Continue;
    if iden is TIdenRpExpression then
      list := FLists[2]
    else
      case iden.RType of
        RTypeIdenFunction: list := FLists[1];
        RTypeIdenVariable: list := FLists[2];
        RTypeIdenConstant: list := FLists[3];
      else
        list := FLists[1];
      end;

    rec := TRpRecHelp.Create;
    rec.RFunction := FEvaluator.Identifiers.Strings[i];
    rec.Help := iden.Help;
    rec.Model := iden.Model;
    rec.Params := iden.AParams;
    list.AddObject(rec.RFunction, rec);
  end;

  // Category 4: Operators, with the help texts of the VCL dialog
  list := FLists[4];
  for i := Low(operators) to High(operators) do
  begin
    rec := TRpRecHelp.Create;
    rec.RFunction := operators[i];
    rec.Help := OperatorHelp(operators[i]);
    rec.Model := operators[i];
    list.AddObject(rec.RFunction, rec);
  end;

  // Select default category
  if FLCategory.Items.Count > 0 then
  begin
    if (FLCategory.ItemIndex < 0) or (FLCategory.ItemIndex >= FMaxListHelp) then
      FLCategory.ItemIndex := 1; // Functions default
    LCategoryClick(nil);
  end;
  UpdateRefreshUIState;
end;

function TFRpExpreDialogLCL.HelpList(ACategory: Integer): TStrings;
begin
  if (ACategory >= 0) and (ACategory < FMaxListHelp) then
    Result := FLists[ACategory]
  else
    Result := nil;
end;

procedure TFRpExpreDialogLCL.LCategoryClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := FLCategory.ItemIndex;
  FLOperation.Clear;
  FMemoHelp.Clear;
  if (idx >= 0) and (idx < FMaxListHelp) then
  begin
    FLOperation.Items.Assign(FLists[idx]);
    if FLOperation.Items.Count > 0 then
    begin
      FLOperation.ItemIndex := 0;
      LOperationClick(nil);
    end;
  end;
end;

procedure TFRpExpreDialogLCL.LOperationClick(Sender: TObject);
var
  idx: Integer;
  rec: TRpRecHelp;
begin
  idx := FLOperation.ItemIndex;
  if idx >= 0 then
  begin
    rec := TRpRecHelp(FLOperation.Items.Objects[idx]);
    if Assigned(rec) then
    begin
      FMemoHelp.Lines.Clear;
      // Model and parameters as the VCL dialog shows them (LModel, LParams)
      if rec.Model <> '' then
        FMemoHelp.Lines.Add(rec.Model);
      if rec.Params <> '' then
        FMemoHelp.Lines.Add(TranslateStr(152, 'Parameters') + ': ' + rec.Params);
      if rec.Help <> '' then
      begin
        FMemoHelp.Lines.Add('');
        FMemoHelp.Lines.Add(rec.Help);
      end;
    end;
  end;
end;

procedure TFRpExpreDialogLCL.LOperationDblClick(Sender: TObject);
begin
  BAddClick(Sender);
end;

procedure TFRpExpreDialogLCL.FocusMemo;
begin
  try
    if FMemoExpre.CanFocus then
      FMemoExpre.SetFocus;
  except
    // Not focusable yet (hidden form)
  end;
end;

procedure TFRpExpreDialogLCL.BRefreshClick(Sender: TObject);
begin
  StartReportRefresh;
end;

procedure TFRpExpreDialogLCL.BAddClick(Sender: TObject);
var
  idx: Integer;
begin
  // The item name, as the VCL (the model is a signature such as
  // "function Uppercase(s:string):string" or "ALIAS.FIELD:type"), at the
  // cursor (the VCL appends it)
  idx := FLOperation.ItemIndex;
  if idx >= 0 then
  begin
    FMemoExpre.SelText := FLOperation.Items[idx];
    FocusMemo;
  end;
end;

procedure TFRpExpreDialogLCL.BCheckSynClick(Sender: TObject);
var
  expr: string;
begin
  expr := Trim(FMemoExpre.Text);
  // Nothing to check in an empty expression
  if expr = '' then
    Exit;

  if not Assigned(FEvaluator) then
    Exit;
  // Untrimmed text, so PosError matches the memo positions (as in the VCL)
  FEvaluator.Expression := FMemoExpre.Text;
  try
    FEvaluator.CheckSyntax;
  except
    on E: Exception do
    begin
      FocusMemo;
      FMemoExpre.SelStart := FEvaluator.PosError;
      FMemoExpre.SelLength := 0;
      ShowMessage(SRpEvalsyntax + ': ' + E.Message);
      Exit;
    end;
  end;
  ShowMessage(TranslateStr(1490, 'Syntax is correct'));
end;

procedure TFRpExpreDialogLCL.BShowResultClick(Sender: TObject);
var
  expr: string;
begin
  expr := Trim(FMemoExpre.Text);
  // Nothing to evaluate in an empty expression
  if expr = '' then
    Exit;

  try
    if Assigned(FEvaluator) then
    begin
      FEvaluator.Expression := expr;
      FEvaluator.Evaluate;
      FAResult := FEvaluator.EvalResult;
      // Only the value, as the VCL dialog
      ShowMessage(FEvaluator.EvalResultString);
    end;
  except
    on E: Exception do
      ShowMessage(TranslateStr(355, 'Error') + ': ' + E.Message);
  end;
end;

procedure TFRpExpreDialogLCL.BOKClick(Sender: TObject);
begin
  // ExpressionCalculateW: OK evaluates the expression (as the VCL)
  if FValidate and Assigned(FEvaluator) then
  begin
    FEvaluator.Expression := FMemoExpre.Text;
    try
      FEvaluator.Evaluate;
      FAResult := FEvaluator.EvalResult;
    except
      on E: Exception do
      begin
        FocusMemo;
        FMemoExpre.SelStart := FEvaluator.PosError;
        FMemoExpre.SelLength := 0;
        ShowMessage(E.Message);
        Exit;
      end;
    end;
  end;
  FDoOk := True;
  ModalResult := mrOk;
end;

procedure TFRpExpreDialogLCL.BCancelClick(Sender: TObject);
begin
  FDoOk := False;
  ModalResult := mrCancel;
end;

procedure TFRpExpreDialogLCL.DoShow;
begin
  inherited DoShow;
  if FMemoExpre.CanFocus then
    ActiveControl := FMemoExpre;
  FMemoExpre.SelStart := UTF8Length(FMemoExpre.Text);
  FMemoExpre.SelLength := 0;
  UpdateExpressionCursorPosition;
  // The VCL posts WM_USER+201 (online initialization) and queues the layout
  Application.QueueAsyncCall(DeferredShow, 0);
  if FRefreshReport <> nil then
    StartReportRefresh;
end;

procedure TFRpExpreDialogLCL.DeferredShow(Data: PtrInt);
begin
  if (csDestroying in ComponentState) or (FChat = nil) then
    Exit;
  FChat.StartOnlineInitialization;
  if Visible then
    FChat.RefreshLayout;
end;

procedure TFRpExpreDialogLCL.UpdateExpressionCursorPosition;
begin
  if FMemoExpre <> nil then
    FExpressionCursorPosition := FMemoExpre.SelStart;
end;

procedure TFRpExpreDialogLCL.MemoExpreChange(Sender: TObject);
begin
  if csDestroying in ComponentState then
    Exit;
  UpdateExpressionCursorPosition;
  if FChat <> nil then
    FChat.SetCurrentExpression(FMemoExpre.Text);
end;

procedure TFRpExpreDialogLCL.MemoExpreClick(Sender: TObject);
begin
  UpdateExpressionCursorPosition;
end;

procedure TFRpExpreDialogLCL.MemoExpreKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  UpdateExpressionCursorPosition;
end;

procedure TFRpExpreDialogLCL.MemoExpreMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  UpdateExpressionCursorPosition;
end;

function TFRpExpreDialogLCL.BuildExpressionSemanticContextJson: string;
begin
  Result := RpBuildExpressionSemanticContextJson(FEvaluator, FRefreshReport,
    FSchemaOnlyFields);
end;

function TFRpExpreDialogLCL.ValidateExpressionText(const AExpression: string;
  out AErrorMessage: string): Boolean;
var
  LOldExpression: WideString;
begin
  AErrorMessage := '';
  if FEvaluator = nil then
  begin
    Result := Trim(AExpression) <> '';
    if not Result then
      AErrorMessage := TranslateStr(1608, 'Empty expression returned');
    Exit;
  end;

  LOldExpression := FEvaluator.Expression;
  try
    FEvaluator.Expression := AExpression;
    FEvaluator.CheckSyntax;
    Result := True;
  except
    on E: Exception do
    begin
      AErrorMessage := E.Message;
      Result := False;
    end;
  end;
  FEvaluator.Expression := LOldExpression;
end;

procedure TFRpExpreDialogLCL.ChatSendPrompt(Sender: TObject; const APrompt,
  AExpression: string);
begin
  SendExpressionPrompt(APrompt, AExpression);
end;

procedure TFRpExpreDialogLCL.SendExpressionPrompt(const APrompt,
  AExpression: string);
var
  LPrompt: string;
  LWorker: TRpExpressionChatWorker;
begin
  if FChat = nil then
    Exit;
  LPrompt := Trim(APrompt);
  if LPrompt = '' then
    Exit;

  UpdateExpressionCursorPosition;
  // A new request replaces the previous one
  if FExpressionCancel <> nil then
    FExpressionCancel.Cancel;
  FExpressionCancel := TRpAsyncCancel.Create;
  Inc(FExpressionRequestVersion);

  LWorker := TRpExpressionChatWorker.Create(FMailboxRef);
  LWorker.Dialog := Self;
  LWorker.Cancel := FExpressionCancel;
  LWorker.RequestVersion := FExpressionRequestVersion;
  LWorker.Prompt := LPrompt;
  // The memo text: the frame keeps the same through SetCurrentExpression
  LWorker.CurrentExpression := FMemoExpre.Text;
  LWorker.CursorPosition := FExpressionCursorPosition;
  LWorker.AITier := FChat.GetAITier;
  LWorker.AIMode := FChat.GetAIMode;
  LWorker.AgentSecret := FChat.GetAgentSecret;
  LWorker.AgentAiId := FChat.GetAgentAiId;
  LWorker.SemanticContext := BuildExpressionSemanticContextJson;
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.InstallId := TRpAuthManager.Instance.InstallId;
  FChat.BeginStreamingResponse;
  LWorker.Start;
end;

procedure TFRpExpreDialogLCL.StopExpressionRequest(Sender: TObject);
begin
  if (FChat = nil) or not FChat.Busy then
    Exit;
  // Later messages of the request are dropped
  Inc(FExpressionRequestVersion);
  if FExpressionCancel <> nil then
    FExpressionCancel.Cancel;
  FExpressionCancel := nil;
  FChat.FinishStreamingResponse;
  FChat.AddAssistantMessage(TranslateStr(1536, 'Generation stopped.'));
end;

procedure TFRpExpreDialogLCL.ChatApplySuggestion(Sender: TObject;
  const AExpression: string);
begin
  FMemoExpre.Text := AExpression;
  FocusMemo;
  FMemoExpre.SelStart := UTF8Length(FMemoExpre.Text);
  FMemoExpre.SelLength := 0;
  UpdateExpressionCursorPosition;
end;

procedure TFRpExpreDialogLCL.HandleAsyncMessage(AMessage: TRpAsyncMessage);
begin
  if AMessage is TRpExprChatPayload then
    HandleExpressionChatPayload(AMessage)
  else if AMessage is TRpExprRefreshPayload then
    HandleRefreshPayload(AMessage);
end;

procedure TFRpExpreDialogLCL.HandleExpressionChatPayload(APayload: TObject);
var
  LPayload: TRpExprChatPayload;
  LText: string;
  LProfile: TJSONValue;
begin
  LPayload := TRpExprChatPayload(APayload);
  if (FChat = nil) or (LPayload.RequestVersion <> FExpressionRequestVersion) then
    Exit;

  case LPayload.Kind of
    rpecUpdateStreamingResponse:
      begin
        FChat.UpdateStreamingResponse(LPayload.Actor1, LPayload.ChunkType1,
          LPayload.Text1, LPayload.PrefillPercent, LPayload.LogText1,
          LPayload.ProgressId1);
        FChat.UpdateStreamingTokens(LPayload.InputTokens,
          LPayload.OutputTokens, LPayload.ProgressId1, LPayload.PrefillPercent);
        FChat.CompleteStreamingProgress(LPayload.Actor1,
          LPayload.ChunkType1, LPayload.ProgressId1);
      end;
    rpecBeginRetry:
      begin
        FChat.AddAssistantMessage(TranslateStr(1601,
          'Local validation failed. Running one automatic fix.'));
        FChat.BeginStreamingResponse;
      end;
    rpecAddAssistantMessage:
      begin
        LText := LPayload.Text1;
        if LPayload.TextId <> 0 then
          LText := TranslateStr(LPayload.TextId, LText);
        FChat.FinishStreamingResponse;
        FChat.AddAssistantMessage(LText);
      end;
    rpecSetSuggestedExpression:
      begin
        if LPayload.StillInvalid then
        begin
          LText := TranslateStr(1602,
            'Generated expression is still invalid after one automatic fix:') +
            ' ' + LPayload.ValidationError + sLineBreak + sLineBreak;
          if Trim(LPayload.Explanation) <> '' then
            LText := LText + LPayload.Explanation + sLineBreak + sLineBreak;
          LText := LText + TranslateStr(1603,
            'You can still apply it and edit it manually.');
        end
        else if LPayload.Fixed then
        begin
          LText := TranslateStr(1604, 'Expression fixed after local validation.');
          if Trim(LPayload.Explanation) <> '' then
            LText := LText + sLineBreak + sLineBreak + LPayload.Explanation;
        end
        else if Trim(LPayload.Explanation) <> '' then
          LText := LPayload.Explanation
        else
          LText := TranslateStr(1605, 'Expression generated.');
        FChat.SetSuggestedExpression(LPayload.Text1, LText);
      end;
    rpecUpdateUserProfile:
      begin
        LProfile := TJSONObject.ParseJSONValue(LPayload.UserProfileJson);
        try
          if LProfile is TJSONObject then
            FChat.UpdateUserProfile(TJSONObject(LProfile));
        finally
          LProfile.Free;
        end;
      end;
  end;
end;

{ TRpExpreDialogLCL }

constructor TRpExpreDialogLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEvaluator := TRpEvaluator.Create(Self);
  FExpression := TStringList.Create;
end;

destructor TRpExpreDialogLCL.Destroy;
begin
  FExpression.Free;
  inherited Destroy;
end;

procedure TRpExpreDialogLCL.SetExpression(const Value: TStrings);
begin
  FExpression.Assign(Value);
end;

procedure TRpExpreDialogLCL.SetRpAlias(const Value: TRpAlias);
begin
  if FRpAlias = Value then
    Exit;
  if FRpAlias <> nil then
    FRpAlias.RemoveFreeNotification(Self);
  FRpAlias := Value;
  if FRpAlias <> nil then
    FRpAlias.FreeNotification(Self);
end;

procedure TRpExpreDialogLCL.SetReport(const Value: TRpReport);
begin
  if FReport = Value then
    Exit;
  if FReport <> nil then
    FReport.RemoveFreeNotification(Self);
  FReport := Value;
  if FReport <> nil then
    FReport.FreeNotification(Self);
end;

procedure TRpExpreDialogLCL.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FRpAlias then
      FRpAlias := nil
    else if AComponent = FEvaluator then
      FEvaluator := nil
    else if AComponent = FReport then
      FReport := nil;
  end;
end;

function TRpExpreDialogLCL.Execute: Boolean;
var
  dia: TFRpExpreDialogLCL;
begin
  dia := TFRpExpreDialogLCL.Create(Application);
  try
    if FReport <> nil then
    begin
      // The fields come from the report datasets, opened by the dialog
      dia.InitializeDialog(FExpression.Text, TRpEvaluator.Create(nil), True,
        False, True);
      dia.ConfigureReportRefresh(FReport, FPrintDriver, FRpAlias);
    end
    else
    begin
      if FEvaluator <> nil then
        FEvaluator.RpAlias := FRpAlias;
      dia.InitializeDialog(FExpression.Text, FEvaluator, False, False, True);
      dia.ConfigureReportRefresh(nil, nil, nil);
    end;
    dia.ShowModal;
    Result := dia.DoOk;
    if Result then
      FExpression.Text := dia.MemoExpre.Text;
  finally
    dia.Free;
  end;
end;

end.
