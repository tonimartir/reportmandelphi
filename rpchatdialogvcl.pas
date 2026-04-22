{*******************************************************}
{                                                       }
{       Rpchatdialogvcl                                 }
{       A Helper for building expresions with help      }
{       Report Manager                                  }
{                                                       }
{       Copyright (c) 1994-2019 Toni Martir             }
{       toni@reportman.es                                   }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{                                                       }
{*******************************************************}

unit rpchatdialogvcl;

interface

{$I rpconf.inc}
{$R rpexpredlg.dcr}

uses
  Winapi.Windows,
  SysUtils, StrUtils, Classes,
  DB,rptypes,
  Graphics,Controls, Forms, Dialogs, Messages,
  StdCtrls, ExtCtrls,Buttons,
  System.JSON, System.Threading,
  rpalias,rpeval, rptypeval,rpgraphutilsvcl,
{$IFDEF USEEVALHASH}
  rphashtable,rpstringhash,
{$ENDIF}
{$IFDEF USEVARIANTS}
  Variants,
{$ENDIF}
  rpdatainfo,
  rpparams,
  rpmdconsts, rpfrmchatvcl, rpdatahttp, rpreport, rpmetafile, rpxmlstream,
  rpreportdesignercontracts;

const
 FMaxlisthelp=5;
 SExpressionChatInitialMessage='Ask for help rewriting, simplifying or validating the current expression. Click ''Apply'' to replace the expression.';
 SDesignChatInitialMessage='Describe the required changes or ask how the current report works. The selected schema will be used as a reference.';
type
  TRpChatMode = (rcmExpression, rcmDesign);

  TRpQueuedExpressionChatPayloadKind = (
    rpqecUpdateStreamingResponse,
    rpqecBeginRetry,
    rpqecGenerationStopped,
    rpqecAddAssistantMessage,
    rpqecSetSuggestedExpression,
    rpqecUpdateUserProfile,
    rpqecApplyDesignResult
  );

  TRpQueuedExpressionChatPayload = class(TObject)
  public
    Kind: TRpQueuedExpressionChatPayloadKind;
    RequestVersion: Integer;
    Actor1: string;
    ChunkType1: string;
    Text1: string;
    Text2: string;
    PrefillPercent: Integer;
    InputTokens: Integer;
    OutputTokens: Integer;
    UserProfile: TJSONObject;
    destructor Destroy; override;
  end;

  TRpQueuedExpressionRefreshPayload = class(TObject)
  public
    RequestVersion: Integer;
    ErrorMessage: string;
    OpenErrors: TStringList;
    SchemaOnlyFields: TStringList;
    SchemaOnlyErrors: TStringList;
    destructor Destroy; override;
  end;

  TRpRecHelp=class(TObject)
  public
    rfunction:string;
    help:string;
    model:string;
    params:string;
  end;

  TRpExpreDialogVCL = class(TComponent)
  private
    { Private declarations }
    FExpresion:TStrings;
    FRpalias:TRpalias;
    Fevaluator:TRpEvaluator;
    FReport: TRpReport;
    FPrintDriver: TRpPrintDriver;
    procedure setexpresion(valor:TStrings);
    procedure SetRpalias(Rpalias1:TRpalias);
  protected
    { Protected declarations }
    procedure Notification(AComponent:TComponent;Operation:TOperation);override;
  public
    { Public declarations }
    constructor Create(AOwner:TComponent);override;
    destructor Destroy;override;
    function Execute:Boolean;
    property Report: TRpReport read FReport write FReport;
    property PrintDriver: TRpPrintDriver read FPrintDriver write FPrintDriver;
  published
    { Published declarations }
    property Expresion:TStrings read FExpresion write setexpresion;
    property Rpalias:TRpalias read FRpalias
     write SetRpalias;
    property evaluator:TRpEvaluator read Fevaluator write Fevaluator;
  end;

  TRpChatDialogComponent = TRpExpreDialogVCL;

  TFRpExpredialogVCL = class(TForm)
    PLeftHost: TPanel;
    PBottom: TPanel;
    LabelCategory: TLabel;
    LOperation: TLabel;
    LModel: TLabel;
    LHelp: TLabel;
    LParams: TLabel;
    LItems: TListBox;
    BCancel: TButton;
    BOK: TButton;
    LCategory: TListBox;
    PAlClient: TPanel;
    SplitterChat: TSplitter;
    PChatHost: TPanel;
    PExpressionHost: TPanel;
    MemoExpre: TMemo;
    Panel1: TPanel;
    BRefresh: TButton;
    BShowResult: TButton;
    BCheckSyn: TButton;
    BAdd: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure LCategoryClick(Sender: TObject);
    procedure LItemsClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure BCheckSynClick(Sender: TObject);
    procedure BShowResultClick(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure LItemsDblClick(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure MemoExpreChange(Sender: TObject);
    procedure BRefreshClick(Sender: TObject);
  private
    { Private declarations }
    validate:Boolean;
    dook:boolean;
    AResult:Variant;
    Fevaluator:TRpCustomEvaluator;
    FOwnsEvaluator: Boolean;
    FChatMode: TRpChatMode;
    FCancelExpressionRequest: Boolean;
    FChat: TFRpChatFrame;
    FExpressionCursorPosition: Integer;
    FExpressionStreamError: string;
    FExpressionStreamResult: TJSONObject;
    FRefreshReport: TRpReport;
    FRefreshPrintDriver: TRpPrintDriver;
    FRefreshAlias: TRpAlias;
    FEmptyAlias: TRpAlias;
    FSchemaOnlyFields: TStringList;
    FSchemaOnlyErrors: TStringList;
    FRefreshVersion: Integer;
    FRefreshRunning: Boolean;
    FAliasReady: Boolean;
    FDesignRequestVersion: Integer;
    llistes:array[0..FMaxlisthelp-1] of TStringlist;
    procedure ClearHelpLists;
    procedure ConfigureReportRefresh(AReport: TRpReport;
      APrintDriver: TRpPrintDriver; ATargetAlias: TRpAlias);
    procedure InitializeDialog(const AExpression: string;
      AEvaluator: TRpCustomEvaluator; AOwnsEvaluator, AValidate,
      AWantReturns: Boolean; AChatMode: TRpChatMode = rcmExpression);
    function BuildRefreshSnapshotEvaluator: TRpEvaluator;
    function CloneAlias(AOwner: TComponent; ASource: TRpAlias): TRpAlias;
    procedure ReleaseOwnedEvaluator;
    procedure AssignEmptyAlias;
    function BuildExpressionSemanticContextJson: string;
    function ExpressionStreamCancelRequested(Sender: TObject): Boolean;
    procedure ExpressionStreamProgress(Sender: TObject; const AActor, AStage,
        AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer);
    procedure ExpressionStreamResult(Sender: TObject; AResultJson: TJSONObject;
      const AErrorMessage: string);
    function ExtractExpressionFromApiResult(AResultJson: TJSONObject;
      out AExpression, AExplanation, AErrorMessage: string): Boolean;
    function GetDesignPrefillPercent(const AStage, AChunkType: string): Integer;
    function GetExpressionPrefillPercent(const AStage, AChunkType: string): Integer;
    procedure DesignStreamProgress(Sender: TObject; const AActor, AStage,
      AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer);
    procedure ResetExpressionStreamState;
    procedure StopExpressionRequest(Sender: TObject);
    function BuildDesignChatRequestForFrame(Sender: TObject;
      const APrompt: string): TRpApiModifyReportRequest;
    function BuildPreprocessSqlContextRequestForFrame(Sender: TObject):
      TRpApiPreprocessSqlContextRequest;
    procedure ApplyModifiedReportDocumentFromFrame(Sender: TObject;
      const AModifiedReportDocument: string);
    function BuildDesignChatRequest(const APrompt: string): TRpApiModifyReportRequest;
    function BuildPreprocessSqlContextRequest: TRpApiPreprocessSqlContextRequest;
    procedure ApplyPreprocessSqlContextResult(
      AResult: TRpApiPreprocessSqlContextResult);
    procedure ApplyPreprocessSqlContextResultFromFrame(Sender: TObject;
      AResult: TRpApiPreprocessSqlContextResult);
    procedure ApplyModifiedReportDocumentToRefreshReport(
      const AModifiedReportDocument: string);
    function SaveRefreshReportAsXml: string;
    function ValidateExpressionText(const AExpression: string;
      out AErrorMessage: string): Boolean;
    procedure UpdateExpressionCursorPosition;
    procedure ChatApplySuggestion(Sender: TObject; const AExpression: string);
    procedure ChatSendPrompt(Sender: TObject; const APrompt, AExpression: string);
    procedure SendExpressionPrompt(const APrompt, AExpression: string);
    procedure SendDesignPrompt(const APrompt, AExpression: string);
    procedure MemoExpreClick(Sender: TObject);
    procedure MemoExpreKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MemoExpreMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure WMHandleExpressionChatPayload(var Message: TMessage); message WM_USER + 204;
    procedure WMHandleExpressionRefresh(var Message: TMessage); message WM_USER + 205;
    procedure WMStartOnlineInitialization(var Message: TMessage); message WM_USER + 201;
    procedure PopulateAliasFromReport(ATargetAlias: TRpAlias);
    procedure PostExpressionChatPayload(APayload: TRpQueuedExpressionChatPayload);
    procedure StartReportRefresh;
    procedure SetSchemaOnlyContext(AFields, AErrors: TStrings);
    procedure SetChatMode(AMode: TRpChatMode);
    procedure UpdateRefreshUIState;
    procedure Setevaluator(aval:TRpCustomEvaluator);
  public
    { Public declarations }
    property evaluator:TRpCustomEvaluator read fevaluator write setevaluator;
    property ChatMode: TRpChatMode read FChatMode write SetChatMode;
  end;

  TFRpChatDialogVCL = TFRpExpredialogVCL;

function ChangeExpression(formul:string;aval:TRpCustomEvaluator):string;
function ChangeExpressionW(formul:Widestring;aval:TRpCustomEvaluator):Widestring;
function ExpressionCalculateW(formul:Widestring;aval:TRpCustomEvaluator):Variant;
procedure CollectAgentSchemaOnlyContext(AReport: TRpReport; AFields,
  AErrors: TStrings);
function BuildDesignExpressionContextJson(AReport: TRpReport; ARpAlias: TRpAlias;
  AOpenErrors, ASchemaOnlyFields, ASchemaOnlyErrors: TStrings;
  out AErrorMessage: string): string;



implementation

{$R *.dfm}
uses rplabelitem, rpauthmanager;

const
  CSchemaFieldSep = #1;

var
 GSharedExpreDialogVCL: TFRpExpredialogVCL = nil;

destructor TRpQueuedExpressionChatPayload.Destroy;
begin
 if UserProfile <> nil then
  UserProfile.Free;
 inherited Destroy;
end;

destructor TRpQueuedExpressionRefreshPayload.Destroy;
begin
 if OpenErrors <> nil then
  OpenErrors.Free;
 if SchemaOnlyFields <> nil then
  SchemaOnlyFields.Free;
 if SchemaOnlyErrors <> nil then
  SchemaOnlyErrors.Free;
 inherited Destroy;
end;

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
 LFirstPos: Integer;
 LSecondPos: Integer;
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
 LFirstPos: Integer;
 LSecondPos: Integer;
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

procedure CollectAgentSchemaOnlyContext(AReport: TRpReport; AFields,
  AErrors: TStrings);
var
 I: Integer;
 J: Integer;
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
  var
   LValue: TJSONValue;
  begin
   Result := '';
   if (ARow = nil) or (AIndex < 0) or (AIndex >= ARow.Count) then
    Exit;
   LValue := ARow.Items[AIndex];
   if (LValue <> nil) and (not (LValue is TJSONNull)) then
     Result := LValue.Value;
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

   LDatabaseInfo := AReport.DatabaseInfo.ItemByName(LDataInfo.DatabaseAlias);
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
    if (LHttp.ApiKey = '') and (TRpAuthManager.Instance.Token <> '') then
    begin
      LHttp.Token := TRpAuthManager.Instance.Token;
      LHttp.InstallId := TRpAuthManager.Instance.InstallId;
    end;

    LResponse := LHttp.GetTableSchema(LDataInfo.SQL);
    if LResponse = nil then
      raise Exception.Create('Empty schema response.');

    LRoot := LResponse;
    if (LRoot.Values['data'] <> nil) and (LRoot.Values['data'] is TJSONObject) then
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

function GetSharedExpreDialogVCL: TFRpExpredialogVCL;
begin
 if GSharedExpreDialogVCL=nil then
  GSharedExpreDialogVCL:=TFRpExpredialogVCL.Create(Application);
 Result:=GSharedExpreDialogVCL;
end;

function GetSemanticFieldDataType(AFieldType: TFieldType): string;
begin
 case AFieldType of
  ftString, ftWideString, ftFixedChar:
    Result := 'string';
  ftSmallint, ftInteger, ftWord, ftAutoInc, ftLargeint:
    Result := 'integer';
  ftFloat, ftBCD, ftFMTBcd, ftSingle, ftExtended:
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

function BuildDesignExpressionContextJson(AReport: TRpReport; ARpAlias: TRpAlias;
  AOpenErrors, ASchemaOnlyFields, ASchemaOnlyErrors: TStrings;
  out AErrorMessage: string): string;
var
  dia: TFRpExpredialogVCL;
  LRoot: TJSONObject;
  LExpressionContext: TJSONObject;
  LRuntimeDataSources: TJSONArray;
  LTargetAlias: TRpAlias;
  LOwnAlias: Boolean;
  I: Integer;
  J: Integer;
  LDataInfo: TRpDataInfoItem;
  LRuntimeSource: TJSONObject;
  LRuntimeSchema: TJSONObject;
  LRuntimeFields: TJSONArray;
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
    ARefreshRequired: Boolean; AFields, AIssues: TJSONArray): TJSONObject;
  begin
    Result := TJSONObject.Create;
    Result.AddPair('name', AName);
    if Trim(AAlias) <> '' then
      Result.AddPair('alias', AAlias);

    LRuntimeSchema := TJSONObject.Create;
    LRuntimeSchema.AddPair('status', AStatus);
    LRuntimeSchema.AddPair('source', ASource);
    LRuntimeSchema.AddPair('refreshRequired', TJSONBool.Create(ARefreshRequired));
    LRuntimeSchema.AddPair('fields', AFields);
    LRuntimeSchema.AddPair('issues', AIssues);
    Result.AddPair('runtimeSchema', LRuntimeSchema);
  end;

  function BuildRuntimeFieldObject(const ADatasetAlias, AFieldName,
    AFieldType: string; ASize: Integer = 0): TJSONObject;
  begin
    Result := TJSONObject.Create;
    Result.AddPair('name', ADatasetAlias + '.' + AFieldName);
    Result.AddPair('dataset', ADatasetAlias);
    Result.AddPair('field', AFieldName);
    Result.AddPair('dataType', AFieldType);
    if SameText(AFieldType, 'string') and (ASize > 0) then
      Result.AddPair('size', TJSONNumber.Create(ASize));
  end;

  procedure AddLiveRuntimeFields(AFields: TJSONArray; const ADatasetAlias: string;
    ADataset: TDataSet);
  var
    K: Integer;
    LCurrentField: TField;
  begin
    if ADataset = nil then
      Exit;

    for K := 0 to ADataset.FieldCount - 1 do
    begin
      LCurrentField := ADataset.Fields[K];
      AFields.AddElement(BuildRuntimeFieldObject(ADatasetAlias,
        LCurrentField.FieldName,
        GetSemanticFieldDataType(LCurrentField.DataType),
        LCurrentField.Size));
    end;
  end;

  procedure AddSchemaOnlyRuntimeFields(AFields: TJSONArray;
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

      AFields.AddElement(BuildRuntimeFieldObject(ADatasetAlias,
        SchemaFieldEntryFieldName(LEntry),
        SchemaFieldEntryDataType(LEntry)));
    end;
  end;

begin
  AErrorMessage := '';
  Result := '{}';
  if AReport = nil then
    Exit;

  dia := TFRpExpredialogVCL.Create(nil);
  LRoot := TJSONObject.Create;
  LOwnAlias := False;
  LTargetAlias := nil;
  try
    if ARpAlias <> nil then
      LTargetAlias := ARpAlias
    else
    begin
      LTargetAlias := TRpAlias.Create(dia);
      LOwnAlias := True;
    end;

    dia.ConfigureReportRefresh(AReport, nil, LTargetAlias);
    dia.SetSchemaOnlyContext(ASchemaOnlyFields, ASchemaOnlyErrors);
    try
      dia.PopulateAliasFromReport(LTargetAlias);
      if AReport.Evaluator = nil then
        raise Exception.Create('The report evaluator is not available after dataset refresh.');

      AReport.Evaluator.Rpalias := LTargetAlias;
      dia.Setevaluator(AReport.Evaluator);
      dia.FAliasReady := True;
      LExpressionContext := TJSONObject.ParseJSONValue(
        dia.BuildExpressionSemanticContextJson) as TJSONObject;
      if LExpressionContext = nil then
        LExpressionContext := TJSONObject.Create;
    except
      on E: Exception do
      begin
        AErrorMessage := E.Message;
        dia.FAliasReady := False;
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
      LRuntimeFields := TJSONArray.Create;
      LIssues := TJSONArray.Create;
      LDatabaseInfo := AReport.DatabaseInfo.ItemByName(LDataInfo.DatabaseAlias);
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
          AddSchemaOnlyRuntimeFields(LRuntimeFields, LDataInfo.Alias,
            ASchemaOnlyFields)
        else
          AddLiveRuntimeFields(LRuntimeFields, LDataInfo.Alias,
            LDataInfo.Dataset);

        if Trim(LDataSourceError) <> '' then
        begin
          if LRuntimeSourceName = 'agent_schema_only' then
            AddIssue(LIssues, 'error', 'datasource_schema_failed', LDataSourceError)
          else
            AddIssue(LIssues, 'error', 'datasource_open_failed', LDataSourceError);

          LRuntimeSource := BuildRuntimeSource(
            LDataSourceName,
            LDataInfo.Alias,
            'refresh_failed',
            LRuntimeSourceName,
            True,
            LRuntimeFields,
            LIssues);
        end
        else
        begin
          if LRuntimeFields.Count = 0 then
          AddIssue(LIssues, 'info', 'no_live_fields',
            'No live fields were returned by the Delphi evaluator for this datasource.');

          LRuntimeSource := BuildRuntimeSource(
            LDataSourceName,
            LDataInfo.Alias,
            'live_context',
            LRuntimeSourceName,
            False,
            LRuntimeFields,
            LIssues);
        end;
      end
      else
      begin
        AddIssue(LIssues, 'error', 'refresh_failed', AErrorMessage);
        LRuntimeSource := BuildRuntimeSource(
          LDataSourceName,
          LDataInfo.Alias,
          'refresh_failed',
          LRuntimeSourceName,
          True,
          LRuntimeFields,
          LIssues);
      end;

      LRuntimeDataSources.AddElement(LRuntimeSource);
    end;

    Result := LRoot.ToJSON;
  finally
    if LOwnAlias and (LTargetAlias <> nil) then
      LTargetAlias.Free;
    LRoot.Free;
    dia.Free;
  end;
end;



constructor TRpExpreDialogVCL.create(AOwner:TComponent);
begin
 inherited create(AOwner);
 Fevaluator:=TRpEvaluator.Create(Self);
 FExpresion:=TStringList.Create;
end;

destructor TRpExpreDialogVCL.destroy;
begin
 FExpresion.free;

 inherited destroy;
end;

procedure TRpExpreDialogVCL.SetRpalias(Rpalias1:TRpalias);
begin
 FRpalias:=Rpalias1;
end;

procedure TRpExpreDialogVCL.setexpresion(valor:TStrings);
begin
 FExpresion.assign(valor);
end;

procedure TRpExpreDialogVCL.Notification(AComponent:TComponent;Operation:TOperation);
begin
 inherited Notification(AComponent,Operation);
 if Operation=opRemove then
 begin
  if AComponent=FRpalias then
   Rpalias:=nil
  else
   if AComponent=Fevaluator then
    Fevaluator:=nil;
 end;
end;


procedure TFRpExpredialogVCL.FormCreate(Sender: TObject);
var
 i:integer;
begin
 inherited;
 ActiveControl:=MemoExpre;
 MemoExpre.OnChange := MemoExpreChange;
 MemoExpre.OnClick := MemoExpreClick;
 MemoExpre.OnKeyUp := MemoExpreKeyUp;
 MemoExpre.OnMouseUp := MemoExpreMouseUp;
 FCancelExpressionRequest := False;
 FChatMode := rcmExpression;
 FExpressionCursorPosition := MemoExpre.SelStart;
 FExpressionStreamError := '';
 FExpressionStreamResult := nil;
 FOwnsEvaluator := False;
 FRefreshReport := nil;
 FRefreshPrintDriver := nil;
 FRefreshAlias := nil;
 FRefreshVersion := 0;
 FRefreshRunning := False;
 FAliasReady := True;
 FDesignRequestVersion := 0;
 FEmptyAlias := TRpAlias.Create(Self);
 FSchemaOnlyFields := TStringList.Create;
 FSchemaOnlyErrors := TStringList.Create;
 FChat := TFRpChatFrame.Create(Self);
 FChat.Parent := PChatHost;
 FChat.Align := alClient;
 FChat.SetShowSchemaSelector(False);
 FChat.OnSendPrompt := ChatSendPrompt;
 FChat.OnApplySuggestion := ChatApplySuggestion;
 FChat.OnStopRequest := StopExpressionRequest;
 FChat.Initialize(MemoExpre.Text, SExpressionChatInitialMessage);
 FChat.RefreshLayout;
 for i:=0 to FMaxlisthelp-1 do
 begin
  llistes[i]:=TStringList.create;
 end;

 BOK.Caption:=TranslateStr(93,BOK.Caption);
 BCancel.Caption:=TranslateStr(94,BCancel.Caption);
// LExpression.Caption:=TranslateStr(239,LExpression.Caption);
 Caption:=TranslateStr(240,Caption);
 LabelCategory.Caption:=TranslateStr(241,LabelCategory.Caption);
 LOperation.Caption:=TranslateStr(242,LOperation.Caption);
 BAdd.Caption:=TranslateStr(243,BAdd.Caption);
 BRefresh.Caption:='Refresh';
 BCheckSyn.Caption:=TranslateStr(244,BCheckSyn.Caption);
 BShowResult.Caption:=TranslateStr(246,BShowResult.Caption);
 LCategory.Items.Strings[0]:=TranslateStr(247,LCategory.Items.Strings[0]);
 LCategory.Items.Strings[1]:=TranslateStr(248,LCategory.Items.Strings[1]);
 LCategory.Items.Strings[2]:=TranslateStr(249,LCategory.Items.Strings[2]);
 LCategory.Items.Strings[3]:=TranslateStr(250,LCategory.Items.Strings[3]);
 LCategory.Items.Strings[4]:=TranslateStr(251,LCategory.Items.Strings[4]);
 
end;

procedure TFRpExpredialogVCL.ConfigureReportRefresh(AReport: TRpReport;
  APrintDriver: TRpPrintDriver; ATargetAlias: TRpAlias);
begin
 FRefreshReport := AReport;
 FRefreshPrintDriver := APrintDriver;
 FRefreshAlias := ATargetAlias;
 if FSchemaOnlyFields <> nil then
  FSchemaOnlyFields.Clear;
 if FSchemaOnlyErrors <> nil then
  FSchemaOnlyErrors.Clear;
 FRefreshVersion := 0;
 FRefreshRunning := False;
 if FRefreshReport <> nil then
 begin
  FAliasReady := False;
  AssignEmptyAlias;
 end
 else
  FAliasReady := evaluator <> nil;
 UpdateRefreshUIState;
end;

procedure TFRpExpredialogVCL.SetSchemaOnlyContext(AFields, AErrors: TStrings);
begin
 if FSchemaOnlyFields <> nil then
 begin
  FSchemaOnlyFields.Clear;
  if AFields <> nil then
    FSchemaOnlyFields.Assign(AFields);
 end;
 if FSchemaOnlyErrors <> nil then
 begin
  FSchemaOnlyErrors.Clear;
  if AErrors <> nil then
    FSchemaOnlyErrors.Assign(AErrors);
 end;
end;

procedure TFRpExpredialogVCL.ReleaseOwnedEvaluator;
begin
 if FOwnsEvaluator and (Fevaluator<>nil) then
 begin
  Fevaluator.Free;
  Fevaluator:=nil;
 end;
 FOwnsEvaluator:=False;
end;

procedure TFRpExpredialogVCL.ClearHelpLists;
var
 i,j:integer;
begin
 for i:=0 to FMaxlisthelp-1 do
 begin
  if llistes[i]=nil then
   continue;
  for j:=0 to llistes[i].count-1 do
   llistes[i].objects[j].free;
  llistes[i].clear;
 end;
end;

procedure TFRpExpredialogVCL.InitializeDialog(const AExpression: string;
  AEvaluator: TRpCustomEvaluator; AOwnsEvaluator, AValidate,
  AWantReturns: Boolean; AChatMode: TRpChatMode = rcmExpression);
begin
 dook:=False;
 AResult:=Null;
 validate:=AValidate;
 SetChatMode(AChatMode);
 MemoExpre.WantReturns:=AWantReturns;
 FCancelExpressionRequest:=False;
 ResetExpressionStreamState;
 if (Fevaluator<>AEvaluator) and FOwnsEvaluator then
  ReleaseOwnedEvaluator;
 FOwnsEvaluator:=AOwnsEvaluator;
 Setevaluator(AEvaluator);
 MemoExpre.Text:=AExpression;
 if FChat<>nil then
 begin
  if FChatMode = rcmDesign then
   FChat.Initialize(MemoExpre.Text, SDesignChatInitialMessage)
  else
   FChat.Initialize(MemoExpre.Text, SExpressionChatInitialMessage);
 end;
 MemoExpre.SelStart:=Length(MemoExpre.Text);
 MemoExpre.SelLength:=0;
 UpdateExpressionCursorPosition;
   FAliasReady := evaluator <> nil;
   UpdateRefreshUIState;
end;

function TFRpExpredialogVCL.CloneAlias(AOwner: TComponent;
  ASource: TRpAlias): TRpAlias;
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

function TFRpExpredialogVCL.BuildRefreshSnapshotEvaluator: TRpEvaluator;
var
 LAliasSnapshot: TRpAlias;
begin
 Result := TRpEvaluator.Create(nil);
 if FRefreshReport <> nil then
  FRefreshReport.AddReportItemsToEvaluator(Result);

 if FAliasReady and (FRefreshAlias <> nil) then
  LAliasSnapshot := CloneAlias(Result, FRefreshAlias)
 else
  LAliasSnapshot := CloneAlias(Result, nil);

 Result.Rpalias := LAliasSnapshot;
end;

  procedure TFRpExpredialogVCL.AssignEmptyAlias;
  begin
   if FEmptyAlias <> nil then
    FEmptyAlias.List.Clear;
   if evaluator <> nil then
    evaluator.Rpalias := FEmptyAlias;
  end;

procedure TFRpExpredialogVCL.Setevaluator(aval:TRpCustomEvaluator);
var
 lista1:Tstringlist;
 i:integer;
 iden:TRpIdentifier;
 rec:TRpRecHelp;
{$IFDEF USEEVALHASH}
 ait:TstrHashIterator;
{$ENDIF}
begin
 Fevaluator:=Aval;
 ClearHelpLists;
 if aval=nil then
 begin
  UpdateRefreshUIState;
  exit;
 end;
 lista1:=llistes[0];
 if aval.Rpalias<>nil then
 begin
  aval.Rpalias.fillwithfields(lista1);
  for i:=0 to lista1.count -1 do
  begin
   rec:=TRpRecHelp.Create;
   rec.rfunction:=lista1.strings[i];
   lista1.Objects[i]:=rec;
  end;
 end;
 if FSchemaOnlyFields <> nil then
 begin
  for i := 0 to FSchemaOnlyFields.Count - 1 do
  begin
   if lista1.IndexOf(SchemaFieldEntryAlias(FSchemaOnlyFields[i]) + '.' +
     SchemaFieldEntryFieldName(FSchemaOnlyFields[i])) >= 0 then
     Continue;
   rec := TRpRecHelp.Create;
   rec.rfunction := SchemaFieldEntryAlias(FSchemaOnlyFields[i]) + '.' +
     SchemaFieldEntryFieldName(FSchemaOnlyFields[i]);
   rec.help := 'Field from dataset ' + SchemaFieldEntryAlias(FSchemaOnlyFields[i]);
   rec.model := rec.rfunction + ':' + SchemaFieldEntryDataType(FSchemaOnlyFields[i]);
   lista1.AddObject(rec.rfunction, rec);
  end;
 end;
{$IFDEF USEEVALHASH}
 ait:=aval.identifiers.getiterator;
 while ait.hasnext do
 begin
  ait.next;
  iden:=TRpIdentifier(ait.GetValue);
{$ENDIF}
{$IFNDEF USEEVALHASH}
 for i:=0 to aval.identifiers.Count-1 do
 begin
  iden:=TRpIdentifier(aval.identifiers.Objects[i]);
{$ENDIF}

  if iden is TIdenRpExpression then
  begin
   lista1:=llistes[2];
  end
  else
  begin
   case iden.RType of
    RTypeidenfunction:
     begin
     lista1:=llistes[1];
     end;
    RTypeidenvariable:
     begin
      lista1:=llistes[2];
     end;
    RTypeidenconstant:
     begin
      lista1:=llistes[3];
     end;
   end;
  end;
  rec:=TRpRecHelp.Create;
{$IFDEF USEEVALHASH}
  rec.rfunction:=ait.GetKey;
{$ENDIF}
{$IFNDEF USEEVALHASH}
  rec.rfunction:=aval.identifiers.Strings[i];
{$ENDIF}
  rec.help:=iden.Help;
  rec.model:=iden.model;
  rec.params:=iden.aparams;
  lista1.addobject(rec.rfunction,rec);
 end;
 lista1:=llistes[4];
 // +
 rec:=TRpRecHelp.create;
 rec.rfunction:='+';
 rec.help:=SRpOperatorSum;
 lista1.addobject(rec.rfunction,rec);
 // -
 rec:=TRpRecHelp.create;
 rec.rfunction:='-';
 rec.help:=SRpOperatorDif;
 lista1.addobject(rec.rfunction,rec);
 // *
 rec:=TRpRecHelp.create;
 rec.rfunction:='*';
 rec.help:=SRpOperatorMul;
 lista1.addobject(rec.rfunction,rec);
 // /
 rec:=TRpRecHelp.create;
 rec.rfunction:='/';
 rec.help:=SRpOperatorDiv;
 lista1.addobject(rec.rfunction,rec);
 // =
 rec:=TRpRecHelp.create;
 rec.rfunction:='=';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // ==
 rec:=TRpRecHelp.create;
 rec.rfunction:='==';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // >=
 rec:=TRpRecHelp.create;
 rec.rfunction:='>=';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // <=
 rec:=TRpRecHelp.create;
 rec.rfunction:='<=';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // >
 rec:=TRpRecHelp.create;
 rec.rfunction:='>';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // <
 rec:=TRpRecHelp.create;
 rec.rfunction:='<';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // <>
 rec:=TRpRecHelp.create;
 rec.rfunction:='<>';
 rec.help:=SRpOperatorComp;
 lista1.addobject(rec.rfunction,rec);
 // AND
 rec:=TRpRecHelp.create;
 rec.rfunction:='AND';
 rec.help:=SRpOperatorLog;
 lista1.addobject(rec.rfunction,rec);
 // OR
 rec:=TRpRecHelp.create;
 rec.rfunction:='OR';
 rec.help:=SRpOperatorLog;
 lista1.addobject(rec.rfunction,rec);
 // NOT
 rec:=TRpRecHelp.create;
 rec.rfunction:='NOT';
 rec.help:=SRpOperatorLog;
 lista1.addobject(rec.rfunction,rec);
 // ;
 rec:=TRpRecHelp.create;
 rec.rfunction:=';';
 rec.help:=SRpOperatorSep;
 rec.params:=SRpOperatorSepP;
 lista1.addobject(rec.rfunction,rec);
 // IIF
 rec:=TRpRecHelp.create;
 rec.rfunction:='IIF';
 rec.help:=SRpOperatorDec;
 rec.Model:=SRpOperatorDecM;
 rec.params:=SRpOperatorDecP;
 lista1.addobject(rec.rfunction,rec);

 LCategory.Itemindex:=0;
 LCategoryClick(self);
 UpdateRefreshUIState;
end;

procedure TFRpExpredialogVCL.FormDestroy(Sender: TObject);
var
 i:integer;
begin
  inherited;
 ReleaseOwnedEvaluator;
 if FExpressionStreamResult <> nil then
  FExpressionStreamResult.Free;
 ClearHelpLists;
 for i:=0 to FMaxlisthelp-1 do
  llistes[i].free;
 if FSchemaOnlyFields <> nil then
  FSchemaOnlyFields.Free;
 if FSchemaOnlyErrors <> nil then
  FSchemaOnlyErrors.Free;
 if GSharedExpreDialogVCL=Self then
  GSharedExpreDialogVCL:=nil;
end;

procedure TFRpExpredialogVCL.FormShow(Sender: TObject);
var
  LQueueProc: TThreadProcedure;
begin
  inherited;
  ActiveControl:=MemoExpre;
  if MemoExpre.CanFocus then
    MemoExpre.SetFocus;
  MemoExpre.SelStart:=Length(MemoExpre.Text);
  MemoExpre.SelLength:=0;
  UpdateExpressionCursorPosition;
  if HandleAllocated then
    PostMessage(Handle, WM_USER + 201, 0, 0);
  if FChat <> nil then
  begin
    LQueueProc :=
      procedure
      begin
        if (FChat <> nil) and Visible then
          FChat.RefreshLayout;
      end;
    TThread.Queue(nil, LQueueProc);
  end;
  if FRefreshReport <> nil then
    StartReportRefresh;
end;

procedure TFRpExpredialogVCL.WMStartOnlineInitialization(var Message: TMessage);
begin
  if FChat<>nil then
    FChat.StartOnlineInitialization;
end;

procedure TFRpExpredialogVCL.PostExpressionChatPayload(
  APayload: TRpQueuedExpressionChatPayload);
begin
  if APayload = nil then
    Exit;
  if HandleAllocated then
    PostMessage(Handle, WM_USER + 204, WPARAM(APayload), 0)
  else
    APayload.Free;
end;

procedure TFRpExpredialogVCL.WMHandleExpressionChatPayload(var Message: TMessage);
var
  LPayload: TRpQueuedExpressionChatPayload;
begin
  LPayload := TRpQueuedExpressionChatPayload(Message.WParam);
  try
    if (LPayload = nil) or (FChat = nil) then
      Exit;

    case LPayload.Kind of
      rpqecUpdateStreamingResponse:
        begin
          FChat.UpdateStreamingResponse(LPayload.Actor1, LPayload.ChunkType1, LPayload.Text1, LPayload.PrefillPercent);
          FChat.UpdateStreamingTokens(LPayload.InputTokens, LPayload.OutputTokens);
        end;
      rpqecBeginRetry:
        begin
          FChat.AddAssistantMessage('Local validation failed. Running one automatic fix.');
          FChat.BeginStreamingResponse;
        end;
      rpqecGenerationStopped:
        begin
          FChat.FinishStreamingResponse;
          FChat.AddAssistantMessage('Generation stopped.');
        end;
      rpqecAddAssistantMessage:
        begin
          if (LPayload.RequestVersion <> 0) and
            (LPayload.RequestVersion <> FDesignRequestVersion) then
            Exit;
          FChat.FinishStreamingResponse;
          FChat.AddAssistantMessage(LPayload.Text1);
        end;
      rpqecSetSuggestedExpression:
        FChat.SetSuggestedExpression(LPayload.Text1, LPayload.Text2);
      rpqecUpdateUserProfile:
        begin
          if LPayload.UserProfile <> nil then
          begin
            FChat.UpdateUserProfile(LPayload.UserProfile);
            LPayload.UserProfile := nil;
          end;
        end;
      rpqecApplyDesignResult:
        begin
          if LPayload.RequestVersion <> FDesignRequestVersion then
            Exit;

          if (LPayload.InputTokens > 0) or (LPayload.OutputTokens > 0) then
            FChat.UpdateStreamingTokens(LPayload.InputTokens, LPayload.OutputTokens);

          FChat.FinishStreamingResponse;
          if LPayload.UserProfile <> nil then
          begin
            FChat.UpdateUserProfile(LPayload.UserProfile);
            LPayload.UserProfile := nil;
          end;

          if Trim(LPayload.Text1) <> '' then
          begin
            try
              ApplyModifiedReportDocumentToRefreshReport(LPayload.Text1);
            except
              on E: Exception do
              begin
                FChat.AddAssistantMessage(
                  'The server returned a modified report, but it could not be loaded: ' + E.Message);
                Exit;
              end;
            end;
          end;

          if Trim(LPayload.Text2) <> '' then
            FChat.AddAssistantMessage(LPayload.Text2)
          else if Trim(LPayload.Text1) <> '' then
            FChat.AddAssistantMessage('Report updated.')
          else
            FChat.AddAssistantMessage('No report changes were returned.');
        end;
    end;
  finally
    LPayload.Free;
  end;
end;

procedure TFRpExpredialogVCL.UpdateRefreshUIState;
begin
 PBottom.Visible := FChatMode = rcmExpression;
 BCheckSyn.Visible := FChatMode = rcmExpression;
 BShowResult.Visible := FChatMode = rcmExpression;
 BRefresh.Visible := (FChatMode = rcmExpression) and (FRefreshReport <> nil);
 if FRefreshRunning then
  BRefresh.Caption := 'Refreshing...'
 else
  BRefresh.Caption := 'Refresh';
end;

procedure TFRpExpredialogVCL.SetChatMode(AMode: TRpChatMode);
begin
 if FChatMode = AMode then
 begin
  if FChat <> nil then
  begin
     FChat.SetShowSchemaSelector(FChatMode = rcmDesign);
   if FChatMode = rcmDesign then
   begin
    FChat.OnBuildDesignRequest := BuildDesignChatRequestForFrame;
    FChat.OnBuildPreprocessSqlContextRequest := BuildPreprocessSqlContextRequestForFrame;
    FChat.OnApplyDesignResult := ApplyModifiedReportDocumentFromFrame;
    FChat.OnApplyPreprocessSqlContextResult := ApplyPreprocessSqlContextResultFromFrame;
   end
   else
   begin
    FChat.OnBuildDesignRequest := nil;
    FChat.OnBuildPreprocessSqlContextRequest := nil;
    FChat.OnApplyDesignResult := nil;
    FChat.OnApplyPreprocessSqlContextResult := nil;
   end;
  end;
  UpdateRefreshUIState;
  Exit;
 end;

 FChatMode := AMode;
 if FChatMode = rcmDesign then
  validate := False;
 if FChat <> nil then
 begin
  FChat.SetShowSchemaSelector(FChatMode = rcmDesign);
  if FChatMode = rcmDesign then
  begin
   FChat.OnBuildDesignRequest := BuildDesignChatRequestForFrame;
    FChat.OnBuildPreprocessSqlContextRequest := BuildPreprocessSqlContextRequestForFrame;
   FChat.OnApplyDesignResult := ApplyModifiedReportDocumentFromFrame;
    FChat.OnApplyPreprocessSqlContextResult := ApplyPreprocessSqlContextResultFromFrame;
  end
  else
  begin
   FChat.OnBuildDesignRequest := nil;
    FChat.OnBuildPreprocessSqlContextRequest := nil;
   FChat.OnApplyDesignResult := nil;
    FChat.OnApplyPreprocessSqlContextResult := nil;
  end;
 end;
 UpdateRefreshUIState;
end;

procedure TFRpExpredialogVCL.PopulateAliasFromReport(ATargetAlias: TRpAlias);
var
 I: Integer;
 LItem: TRpAliasListItem;
begin
 if (ATargetAlias = nil) or (FRefreshReport = nil) then
  Exit;

 ATargetAlias.List.Clear;
 for I := 0 to FRefreshReport.DataInfo.Count - 1 do
 begin
  LItem := ATargetAlias.List.Add;
  LItem.Alias := FRefreshReport.DataInfo.Items[I].Alias;
{$IFDEF USERPDATASET}
  if FRefreshReport.DataInfo.Items[I].Cached then
   LItem.Dataset := FRefreshReport.DataInfo.Items[I].CachedDataset
  else
{$ENDIF}
   LItem.Dataset := FRefreshReport.DataInfo.Items[I].Dataset;
 end;
end;

procedure TFRpExpredialogVCL.StartReportRefresh;
var
 LWorker: TThread;
 LRequestVersion: Integer;
 LReport: TRpReport;
begin
 if FRefreshRunning then
  Exit;
 if (FRefreshReport = nil) then
  Exit;

 Inc(FRefreshVersion);
 LRequestVersion := FRefreshVersion;
 LReport := FRefreshReport;
 if not FOwnsEvaluator then
 begin
  Setevaluator(BuildRefreshSnapshotEvaluator);
  FOwnsEvaluator := True;
 end;
 FRefreshRunning := True;
 UpdateRefreshUIState;

 LWorker := TThread.CreateAnonymousThread(
   procedure
   var
    LPayload: TRpQueuedExpressionRefreshPayload;
    LOpenErrors: TStringList;
    LSchemaOnlyFields: TStringList;
    LSchemaOnlyErrors: TStringList;
   begin
    LPayload := TRpQueuedExpressionRefreshPayload.Create;
    LOpenErrors := TStringList.Create;
    LSchemaOnlyFields := TStringList.Create;
    LSchemaOnlyErrors := TStringList.Create;
    try
      LPayload.RequestVersion := LRequestVersion;
      try
        LReport.PrepareLiveContext(LOpenErrors);
        CollectAgentSchemaOnlyContext(LReport, LSchemaOnlyFields, LSchemaOnlyErrors);
        LPayload.OpenErrors := TStringList.Create;
        LPayload.OpenErrors.Assign(LOpenErrors);
        LPayload.SchemaOnlyFields := TStringList.Create;
        LPayload.SchemaOnlyFields.Assign(LSchemaOnlyFields);
        LPayload.SchemaOnlyErrors := TStringList.Create;
        LPayload.SchemaOnlyErrors.Assign(LSchemaOnlyErrors);
      except
        on E: Exception do
          LPayload.ErrorMessage := E.Message;
      end;

      if HandleAllocated then
        PostMessage(Handle, WM_USER + 205, WPARAM(LPayload), 0)
      else
        LPayload.Free;
      LPayload := nil;
    finally
      LSchemaOnlyErrors.Free;
      LSchemaOnlyFields.Free;
      LOpenErrors.Free;
      LPayload.Free;
    end;
   end);
 LWorker.FreeOnTerminate := True;
 LWorker.Start;
end;

procedure TFRpExpredialogVCL.WMHandleExpressionRefresh(var Message: TMessage);
var
 LPayload: TRpQueuedExpressionRefreshPayload;
begin
 LPayload := TRpQueuedExpressionRefreshPayload(Message.WParam);
 try
  if LPayload = nil then
    Exit;
  if LPayload.RequestVersion <> FRefreshVersion then
    Exit;

  FRefreshRunning := False;
  if LPayload.ErrorMessage <> '' then
  begin
    FAliasReady := False;
    SetSchemaOnlyContext(nil, nil);
    UpdateRefreshUIState;
    RpShowMessage(LPayload.ErrorMessage);
    Exit;
  end;

  SetSchemaOnlyContext(LPayload.SchemaOnlyFields, LPayload.SchemaOnlyErrors);
  PopulateAliasFromReport(FRefreshAlias);
  if FRefreshReport <> nil then
  begin
    if FOwnsEvaluator then
      ReleaseOwnedEvaluator;
    FOwnsEvaluator := False;
    if FRefreshReport.Evaluator <> nil then
      FRefreshReport.Evaluator.Rpalias := FRefreshAlias;
    Setevaluator(FRefreshReport.Evaluator);
  end;
  FAliasReady := True;
  UpdateRefreshUIState;
 finally
  LPayload.Free;
 end;
end;
procedure TFRpExpredialogVCL.MemoExpreChange(Sender: TObject);
begin
 UpdateExpressionCursorPosition;
 if FChat <> nil then
  FChat.SetCurrentExpression(MemoExpre.Text);
end;

procedure TFRpExpredialogVCL.UpdateExpressionCursorPosition;
begin
 if MemoExpre <> nil then
  FExpressionCursorPosition := MemoExpre.SelStart;
end;

procedure TFRpExpredialogVCL.MemoExpreClick(Sender: TObject);
begin
 UpdateExpressionCursorPosition;
end;

procedure TFRpExpredialogVCL.MemoExpreKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
 UpdateExpressionCursorPosition;
end;

procedure TFRpExpredialogVCL.MemoExpreMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
 UpdateExpressionCursorPosition;
end;

procedure TFRpExpredialogVCL.ResetExpressionStreamState;
begin
 if FExpressionStreamResult <> nil then
 begin
  FExpressionStreamResult.Free;
  FExpressionStreamResult := nil;
 end;
 FExpressionStreamError := '';
end;

function TFRpExpredialogVCL.ExpressionStreamCancelRequested(Sender: TObject): Boolean;
begin
 Result := FCancelExpressionRequest;
end;

function TFRpExpredialogVCL.GetExpressionPrefillPercent(const AStage,
  AChunkType: string): Integer;
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

  function TFRpExpredialogVCL.GetDesignPrefillPercent(const AStage,
    AChunkType: string): Integer;
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
    else if SameText(AStage, 'ApplyingOperations') then
      Result := 95
    else
      Result := 100;
  end;

procedure TFRpExpredialogVCL.ExpressionStreamProgress(Sender: TObject; const AActor,
  AStage, AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer);
var
 LChunk: string;
 LPayload: TRpQueuedExpressionChatPayload;
 LPrefill: Integer;
begin
 LChunk := '';
 if SameText(AStage, 'ReceivingResponse') and SameText(AChunkType, 'Partial') then
  LChunk := AChunk;
 LPrefill := GetExpressionPrefillPercent(AStage, AChunkType);
 LPayload := TRpQueuedExpressionChatPayload.Create;
 LPayload.Kind := rpqecUpdateStreamingResponse;
 LPayload.Actor1 := AActor;
 LPayload.ChunkType1 := AChunkType;
 LPayload.Text1 := LChunk;
 LPayload.PrefillPercent := LPrefill;
 LPayload.InputTokens := AInputTokens;
 LPayload.OutputTokens := AOutputTokens;
 PostExpressionChatPayload(LPayload);
end;

procedure TFRpExpredialogVCL.DesignStreamProgress(Sender: TObject; const AActor,
  AStage, AChunkType, AChunk: string; AInputTokens,
  AOutputTokens: Integer);
var
  LChunk: string;
  LPayload: TRpQueuedExpressionChatPayload;
  LPrefill: Integer;
begin
  LChunk := '';
  if Trim(AChunk) <> '' then
  begin
    if SameText(AStage, 'ReceivingResponse') then
      LChunk := AChunk
    else
      LChunk := '[' + AStage + '] ' + AChunk + sLineBreak;
  end;
  LPrefill := GetDesignPrefillPercent(AStage, AChunkType);
  LPayload := TRpQueuedExpressionChatPayload.Create;
  LPayload.Kind := rpqecUpdateStreamingResponse;
  LPayload.Actor1 := AActor;
  LPayload.ChunkType1 := AChunkType;
  LPayload.Text1 := LChunk;
  LPayload.PrefillPercent := LPrefill;
  LPayload.InputTokens := AInputTokens;
  LPayload.OutputTokens := AOutputTokens;
  PostExpressionChatPayload(LPayload);
end;

procedure TFRpExpredialogVCL.ExpressionStreamResult(Sender: TObject;
  AResultJson: TJSONObject; const AErrorMessage: string);
begin
 if AErrorMessage <> '' then
  FExpressionStreamError := AErrorMessage;
 if AResultJson <> nil then
 begin
  if FExpressionStreamResult <> nil then
   FExpressionStreamResult.Free;
  FExpressionStreamResult := AResultJson;
 end;
end;

function TFRpExpredialogVCL.ExtractExpressionFromApiResult(
  AResultJson: TJSONObject; out AExpression, AExplanation,
  AErrorMessage: string): Boolean;
var
 LResultObj: TJSONObject;
begin
 Result := False;
 AExpression := '';
 AExplanation := '';
 AErrorMessage := FExpressionStreamError;
 if AErrorMessage <> '' then
  Exit;
 if AResultJson = nil then
 begin
  AErrorMessage := 'No final response received';
  Exit;
 end;

 if (AResultJson.Values['errorMessage'] <> nil) and
   (AResultJson.Values['errorMessage'].Value <> '') then
 begin
  AErrorMessage := AResultJson.Values['errorMessage'].Value;
  Exit;
 end;

 LResultObj := AResultJson.Values['result'] as TJSONObject;
 if LResultObj = nil then
 begin
  AErrorMessage := 'Response without result';
  Exit;
 end;

 if LResultObj.Values['expression'] <> nil then
  AExpression := LResultObj.Values['expression'].Value;
 if LResultObj.Values['explanation'] <> nil then
  AExplanation := LResultObj.Values['explanation'].Value;

 if AExpression = '' then
 begin
  if (LResultObj.Values['errorMessage'] <> nil) and
    (LResultObj.Values['errorMessage'].Value <> '') then
    AErrorMessage := LResultObj.Values['errorMessage'].Value
  else
  if Trim(AExplanation) <> '' then
    AErrorMessage := AExplanation
  else
    AErrorMessage := 'Empty expression returned';
  Exit;
 end;

 Result := True;
end;

function TFRpExpredialogVCL.ValidateExpressionText(const AExpression: string;
  out AErrorMessage: string): Boolean;
var
 LOldExpression: string;
begin
 AErrorMessage := '';
 if FChatMode = rcmDesign then
 begin
  Result := Trim(AExpression) <> '';
  if not Result then
    AErrorMessage := 'Empty design content returned';
  Exit;
 end;

 if evaluator = nil then
 begin
  Result := Trim(AExpression) <> '';
  if not Result then
    AErrorMessage := 'Empty expression returned';
  Exit;
 end;

 LOldExpression := evaluator.Expression;
 try
  evaluator.Expression := AExpression;
  evaluator.CheckSyntax;
  Result := True;
 except
  on E: Exception do
  begin
   AErrorMessage := E.Message;
   Result := False;
  end;
 end;
 evaluator.Expression := LOldExpression;
end;

procedure TFRpExpredialogVCL.StopExpressionRequest(Sender: TObject);
begin
 if FChatMode <> rcmDesign then
  FCancelExpressionRequest := True;
end;

function TFRpExpredialogVCL.BuildDesignChatRequestForFrame(Sender: TObject;
  const APrompt: string): TRpApiModifyReportRequest;
begin
 Result := BuildDesignChatRequest(APrompt);
end;

function TFRpExpredialogVCL.BuildPreprocessSqlContextRequestForFrame(
  Sender: TObject): TRpApiPreprocessSqlContextRequest;
begin
 Result := BuildPreprocessSqlContextRequest;
end;

procedure TFRpExpredialogVCL.ApplyPreprocessSqlContextResultFromFrame(
  Sender: TObject; AResult: TRpApiPreprocessSqlContextResult);
begin
 ApplyPreprocessSqlContextResult(AResult);
end;

procedure TFRpExpredialogVCL.ApplyModifiedReportDocumentFromFrame(
  Sender: TObject; const AModifiedReportDocument: string);
begin
 ApplyModifiedReportDocumentToRefreshReport(AModifiedReportDocument);
end;

function TFRpExpredialogVCL.SaveRefreshReportAsXml: string;
var
 LStream: TStringStream;
begin
 Result := '';
 if FRefreshReport = nil then
  Exit;

 LStream := TStringStream.Create('', TEncoding.UTF8);
 try
  WriteReportXML(FRefreshReport, LStream);
  Result := LStream.DataString;
 finally
  LStream.Free;
 end;
end;

function TFRpExpredialogVCL.BuildDesignChatRequest(
  const APrompt: string): TRpApiModifyReportRequest;
begin
 Result := TRpApiModifyReportRequest.Create;
 Result.AITier := RpAITierTypeFromString(FChat.GetAITier);
 Result.Mode := RpReportDesignerModeFromString(FChat.GetAIMode);
 Result.ReportDocument := SaveRefreshReportAsXml;
 Result.ReportFormat := rdfXml;
 Result.ReturnModifiedDocument := True;
 Result.SimplifiedPrompt := False;
 Result.UserLanguage := TRpAuthManager.Instance.AILanguage;
 Result.ApiKey := FChat.GetSchemaApiKey;
 Result.Config.HubDatabaseId := FChat.GetHubDatabaseId;
 Result.Config.HubSchemaId := FChat.GetHubSchemaId;
 TRpAuthManager.Instance.Log(
  'BuildDesignChatRequest: HubDatabaseId=' + IntToStr(Result.Config.HubDatabaseId) +
  ' HubSchemaId=' + IntToStr(Result.Config.HubSchemaId) +
  ' SchemaApiKey=' + Result.ApiKey);
 Result.UserInstructions.Add(APrompt);
 if Result.AITier = ratLocalAgent then
 begin
  Result.AgentSecret := FChat.GetAgentSecret;
  Result.AgentAiId := FChat.GetAgentAiId;
  Result.HasAgentAiId := Result.AgentAiId <> 0;
 end;
end;

  function TFRpExpredialogVCL.BuildPreprocessSqlContextRequest: TRpApiPreprocessSqlContextRequest;
  var
   I: Integer;
   LConnectionParams: TStringList;
   LDataInfo: TRpDataInfoItem;
   LDataSource: TRpApiPreprocessSqlContextDataSource;
   LDatabaseInfo: TRpDatabaseInfoItem;
   LDataInfoName: string;
  begin
   Result := nil;
   if (FRefreshReport = nil) or (FChat = nil) then
    Exit;

   LConnectionParams := TStringList.Create;
   try
    for I := 0 to FRefreshReport.DataInfo.Count - 1 do
    begin
     LDataInfo := FRefreshReport.DataInfo.Items[I];
     if Trim(LDataInfo.SQL) = '' then
      Continue;
     if Trim(LDataInfo.SQLExplanation) <> '' then
      Continue;
     if Trim(LDataInfo.SQLExplanationError) <> '' then
      Continue;

     if Result = nil then
     begin
      Result := TRpApiPreprocessSqlContextRequest.Create;
      Result.AITier := RpAITierTypeFromString(FChat.GetAITier);
      Result.Mode := RpReportDesignerModeFromString(FChat.GetAIMode);
      Result.UserLanguage := TRpAuthManager.Instance.AILanguage;
      Result.ApiKey := FChat.GetSchemaApiKey;
      Result.Config.HubDatabaseId := FChat.GetHubDatabaseId;
      Result.Config.HubSchemaId := FChat.GetHubSchemaId;
      if Result.AITier = ratLocalAgent then
      begin
       Result.AgentSecret := FChat.GetAgentSecret;
       Result.AgentAiId := FChat.GetAgentAiId;
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

     LDatabaseInfo := FRefreshReport.DatabaseInfo.ItemByName(LDataInfo.DatabaseAlias);
     if (LDatabaseInfo <> nil) and (LDatabaseInfo.Driver = rpdbHttp) then
     begin
      LConnectionParams.Clear;
      LDatabaseInfo.LoadConnectionParams(LConnectionParams);
      LDataSource.Config.HubDatabaseId := StrToInt64Def(LConnectionParams.Values['HubDatabaseId'], 0);
      LDataSource.Config.HubSchemaId := StrToInt64Def(LConnectionParams.Values['HubSchemaId'], 0);
     end;

     Result.DataSources.Add(LDataSource);
    end;

    if (Result <> nil) and (Result.DataSources.Count = 0) then
    begin
     Result.Free;
     Result := nil;
    end;
   finally
    LConnectionParams.Free;
   end;
  end;

  procedure TFRpExpredialogVCL.ApplyPreprocessSqlContextResult(
    AResult: TRpApiPreprocessSqlContextResult);
  var
   I: Integer;
   J: Integer;
   LDataInfo: TRpDataInfoItem;
   LDataInfoName: string;
   LResultItem: TRpApiPreprocessSqlContextDataSourceResult;
  begin
   if (FRefreshReport = nil) or (AResult = nil) then
    Exit;

   for I := 0 to AResult.DataSources.Count - 1 do
   begin
    if not (AResult.DataSources[I] is TRpApiPreprocessSqlContextDataSourceResult) then
     Continue;

    LResultItem := TRpApiPreprocessSqlContextDataSourceResult(AResult.DataSources[I]);
    for J := 0 to FRefreshReport.DataInfo.Count - 1 do
    begin
     LDataInfo := FRefreshReport.DataInfo.Items[J];
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

procedure TFRpExpredialogVCL.ApplyModifiedReportDocumentToRefreshReport(
  const AModifiedReportDocument: string);
var
 LStream: TStringStream;
begin
 if (FRefreshReport = nil) or (Trim(AModifiedReportDocument) = '') then
  Exit;

 LStream := TStringStream.Create(AModifiedReportDocument, TEncoding.UTF8);
 try
	 FRefreshReport.DeActivateDatasets;
	 FRefreshReport.FreeSubreports;
	 FRefreshReport.DataInfo.Clear;
	 FRefreshReport.DatabaseInfo.Clear;
	 FRefreshReport.Params.Clear;
  FRefreshReport.LoadFromStream(LStream);
  if not FOwnsEvaluator then
  begin
   Setevaluator(BuildRefreshSnapshotEvaluator);
   FOwnsEvaluator := True;
  end;
  FAliasReady := False;
  if FRefreshPrintDriver <> nil then
   StartReportRefresh
  else
   UpdateRefreshUIState;
 finally
  LStream.Free;
 end;
end;

function TFRpExpredialogVCL.BuildExpressionSemanticContextJson: string;
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
 I: Integer;
 J: Integer;
 LIdentifier: TRpIdentifier;
{$IFDEF USEEVALHASH}
 LIterator: TstrHashIterator;
{$ENDIF}
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

  function CreateCatalogEntry(const AModel, AHelp: string): TJSONObject;
  begin
    Result := TJSONObject.Create;
    Result.AddPair('model', AModel);
    if Trim(AHelp) <> '' then
      Result.AddPair('help', AHelp);
  end;

  function CreateIdentifierObject(AIdentifier: TRpIdentifier): TJSONObject;
  var
    LAIHelp: string;
  begin
    LAIHelp := Trim(AIdentifier.AIHelp);
    Result := CreateCatalogEntry(AIdentifier.Model, LAIHelp);
  end;

  function CreateParameterObject(AParam: TRpParam): TJSONObject;
  var
    LDatasets: TJSONArray;
    LHelp: string;
    LDatasetName: string;
    J: integer;
  begin
    Result := TJSONObject.Create;
    Result.AddPair('model', 'parameter ' + 'M.' + AParam.Name + ':' + GetSemanticParamType(AParam.ParamType));

    LDatasets := TJSONArray.Create;
    for J := 0 to AParam.Datasets.Count - 1 do
    begin
      LDatasetName := Trim(AParam.Datasets[J]);
      if LDatasetName <> '' then
        LDatasets.Add(LDatasetName);
    end;
    Result.AddPair('datasets', LDatasets);

    LHelp := Trim(AParam.Description);
    if LHelp = '' then
      LHelp := Trim(AParam.Hint);
    if LHelp <> '' then
      Result.AddPair('help', LHelp);
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

  function BuildDatasetColumnsBlock(const ADatasetAlias: string;
    AColumns: TStrings): string;
  var
    K: Integer;
    LBuilder: TStringBuilder;
  begin
    LBuilder := TStringBuilder.Create;
    try
      LBuilder.Append('[DATASET_COLUMNS ').Append(ADatasetAlias)
        .AppendLine(' columns]');
      for K := 0 to AColumns.Count - 1 do
        LBuilder.AppendLine(AColumns[K]);
      LBuilder.Append('[/DATASET_COLUMNS]');
      Result := LBuilder.ToString;
    finally
      LBuilder.Free;
    end;
  end;

  function BuildMemoryVariablesBlock(AVariables: TStrings): string;
  var
    K: Integer;
    LBuilder: TStringBuilder;
  begin
    LBuilder := TStringBuilder.Create;
    try
      LBuilder.AppendLine('[MEMORY_VARIABLES]');
      for K := 0 to AVariables.Count - 1 do
        LBuilder.AppendLine(AVariables[K]);
      LBuilder.Append('[/MEMORY_VARIABLES]');
      Result := LBuilder.ToString;
    finally
      LBuilder.Free;
    end;
  end;

  procedure AddIdentifierToCategories(AIdentifier: TRpIdentifier);
  begin
    if AIdentifier is TIdenRpExpression then
      Exit;

    if Trim(AIdentifier.AIHelp) = '' then
      Exit;

    case AIdentifier.RType of
      RTypeidenfunction:
        LFunctions.AddElement(CreateIdentifierObject(AIdentifier));
      RTypeidenconstant:
        LConstants.AddElement(CreateIdentifierObject(AIdentifier));
    end;
  end;
begin
 if FChatMode = rcmDesign then
 begin
  Result := '{}';
  Exit;
 end;

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

  if (evaluator <> nil) and (evaluator.Rpalias <> nil) then
  begin
    for I := 0 to evaluator.Rpalias.List.Count - 1 do
    begin
      LAliasItem := evaluator.Rpalias.List.Items[I];
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

  if FSchemaOnlyFields <> nil then
  begin
    for I := 0 to FSchemaOnlyFields.Count - 1 do
    begin
      if Trim(FSchemaOnlyFields[I]) = '' then
        Continue;
      AddDatasetColumn(SchemaFieldEntryAlias(FSchemaOnlyFields[I]),
        SchemaFieldEntryFieldName(FSchemaOnlyFields[I]),
        SchemaFieldEntryDataType(FSchemaOnlyFields[I]));
    end;
  end;

  if FRefreshReport <> nil then
  begin
    for I := 0 to FRefreshReport.Params.Count - 1 do
    begin
      LParam := FRefreshReport.Params[I];
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

  if evaluator <> nil then
  begin
{$IFDEF USEEVALHASH}
   LIterator := evaluator.Identifiers.GetIterator;
   while LIterator.HasNext do
   begin
    LIterator.Next;
    LIdentifier := TRpIdentifier(LIterator.GetValue);
    AddIdentifierToCategories(LIdentifier);
   end;
{$ENDIF}
{$IFNDEF USEEVALHASH}
   for I := 0 to evaluator.Identifiers.Count - 1 do
   begin
    LIdentifier := TRpIdentifier(evaluator.Identifiers.Objects[I]);
    AddIdentifierToCategories(LIdentifier);
   end;
{$ENDIF}
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

procedure TFRpExpredialogVCL.LCategoryClick(Sender: TObject);
begin
  inherited;
 Litems.items.Assign(llistes[lcategory.itemindex]);
 Lhelp.Caption:='';
 Lparams.caption:='';
 Lmodel.caption:='';
end;

procedure TFRpExpredialogVCL.LItemsClick(Sender: TObject);
begin
  inherited;
 if litems.itemindex>-1 then
 begin
  Lhelp.caption:=(llistes[lcategory.itemindex].objects[litems.itemindex]
      As TRpRecHelp).help;
  Lparams.caption:=(llistes[lcategory.itemindex].objects[litems.itemindex]
      As TRpRecHelp).params;
  Lmodel.caption:=(llistes[lcategory.itemindex].objects[litems.itemindex]
      As TRpRecHelp).model;
 end
 else
 begin
  Lhelp.Caption:='';
  Lparams.caption:='';
  Lmodel.caption:='';
 end;
end;

procedure TFRpExpredialogVCL.BCheckSynClick(Sender: TObject);
begin
  inherited;
 evaluator.Expression:=Memoexpre.text;
 try
  evaluator.CheckSyntax;
 except
  on E:Exception do
  begin
   MemoExpre.SetFocus;
   MemoExpre.SelStart:=evaluator.PosError;
   MemoExpre.SelLength:=0;
   raise Exception.Create(E.Message);
  end;
 end;
end;

procedure TFRpExpredialogVCL.BShowResultClick(Sender: TObject);
begin
 evaluator.Expression:=Memoexpre.text;
 try
  evaluator.evaluate;
 except
   On E:TRpEvalException do
  begin
   MemoExpre.SetFocus;
   MemoExpre.SelStart:=E.ErrorPosition;
   MemoExpre.SelLength:=0;
   raise Exception.Create(E.MEssage + ' at position ' + IntToStr(E.ErrorPosition));
  end;
  On E:Exception do
  begin
   MemoExpre.SetFocus;
   MemoExpre.SelStart:=evaluator.PosError;
   MemoExpre.SelLength:=0;
   raise Exception.Create(E.MEssage);
  end;

 end;
 RpShowmessage(TRpValueToString(evaluator.EvalResult));
end;

procedure TFRpExpredialogVCL.BRefreshClick(Sender: TObject);
begin
 StartReportRefresh;
end;

procedure TFRpExpredialogVCL.BitBtn1Click(Sender: TObject);
begin
  inherited;
 if litems.itemindex>-1 then
  memoexpre.text:=memoexpre.text+litems.Items.strings[litems.itemindex];
end;

procedure TFRpExpredialogVCL.LItemsDblClick(Sender: TObject);
begin
  inherited;
 if litems.itemindex>-1 then
  memoexpre.text:=memoexpre.text+litems.Items.strings[litems.itemindex];
end;

procedure TFRpExpredialogVCL.ChatSendPrompt(Sender: TObject; const APrompt,
  AExpression: string);
begin
 case FChatMode of
  rcmDesign:
   SendDesignPrompt(APrompt, AExpression);
 else
   SendExpressionPrompt(APrompt, AExpression);
 end;
end;

procedure TFRpExpredialogVCL.SendExpressionPrompt(const APrompt,
  AExpression: string);
var
 LAITier: string;
 LAIMode: string;
 LAgentSecret: string;
 LAgentAiId: Int64;
 LCursorPosition: Integer;
 LPrompt: string;
 LSemanticContext: string;
 LWorker: TThread;
begin
 if FChat = nil then
  Exit;

 LPrompt := Trim(APrompt);
 if LPrompt = '' then
  Exit;

 LAITier := FChat.GetAITier;
 LAIMode := FChat.GetAIMode;
 LAgentSecret := FChat.GetAgentSecret;
 LAgentAiId := FChat.GetAgentAiId;
 UpdateExpressionCursorPosition;
 LCursorPosition := FExpressionCursorPosition;
 LSemanticContext := BuildExpressionSemanticContextJson;

 FCancelExpressionRequest := False;
 ResetExpressionStreamState;
 FChat.BeginStreamingResponse;

 LWorker := TThread.CreateAnonymousThread(
   procedure
   var
    LCurrentExpression: string;
    LErrorMessage: string;
    LExpression: string;
      LExplanation: string;
      LChatPayload: TRpQueuedExpressionChatPayload;
    LHttp: TRpDatabaseHttp;
    LNeedRetry: Boolean;
    LRetryMessage: string;
    LUserProfile: TJSONObject;
   begin
    LCurrentExpression := AExpression;
    LNeedRetry := False;
    LRetryMessage := '';
    LHttp := TRpDatabaseHttp.Create;
    try
        try
          LHttp.Token := TRpAuthManager.Instance.Token;
          LHttp.InstallId := TRpAuthManager.Instance.InstallId;
          LHttp.AITier := LAITier;
          LHttp.AgentSecret := LAgentSecret;
          LHttp.AgentAiId := LAgentAiId;

          repeat
            ResetExpressionStreamState;
            if LNeedRetry then
            begin
              LChatPayload := TRpQueuedExpressionChatPayload.Create;
              LChatPayload.Kind := rpqecBeginRetry;
              PostExpressionChatPayload(LChatPayload);
            end;

            LHttp.SuggestExpressionStream(LPrompt, LCurrentExpression, LCursorPosition,
              LAIMode, LNeedRetry, LSemanticContext, Self, ExpressionStreamProgress,
              ExpressionStreamResult, ExpressionStreamCancelRequested);

            if FCancelExpressionRequest then
            begin
              LChatPayload := TRpQueuedExpressionChatPayload.Create;
              LChatPayload.Kind := rpqecGenerationStopped;
              PostExpressionChatPayload(LChatPayload);
              Exit;
            end;

            if not ExtractExpressionFromApiResult(FExpressionStreamResult,
              LExpression, LExplanation, LErrorMessage) then
            begin
              LChatPayload := TRpQueuedExpressionChatPayload.Create;
              LChatPayload.Kind := rpqecAddAssistantMessage;
              LChatPayload.Text1 := LErrorMessage;
              PostExpressionChatPayload(LChatPayload);
              Exit;
            end;

            LUserProfile := nil;
            if (FExpressionStreamResult <> nil) and (FExpressionStreamResult.Values['userProfile'] is TJSONObject) then
              LUserProfile := TJSONObject((FExpressionStreamResult.Values['userProfile'] as TJSONObject).Clone);
            if LUserProfile <> nil then
            begin
              LChatPayload := TRpQueuedExpressionChatPayload.Create;
              LChatPayload.Kind := rpqecUpdateUserProfile;
              LChatPayload.UserProfile := LUserProfile;
              LUserProfile := nil;
              PostExpressionChatPayload(LChatPayload);
            end;

            if (not LNeedRetry) and (not ValidateExpressionText(LExpression, LErrorMessage)) then
            begin
              LCurrentExpression := LExpression;
              LNeedRetry := True;
              Continue;
            end;

            if LNeedRetry and (not ValidateExpressionText(LExpression, LErrorMessage)) then
            begin
              if Trim(LExplanation) <> '' then
                LRetryMessage := 'Generated expression is still invalid after one automatic fix: ' +
                  LErrorMessage + sLineBreak + sLineBreak + LExplanation +
                  sLineBreak + sLineBreak + 'You can still apply it and edit it manually.'
              else
                LRetryMessage := 'Generated expression is still invalid after one automatic fix: ' +
                  LErrorMessage + sLineBreak + sLineBreak +
                  'You can still apply it and edit it manually.';

              LChatPayload := TRpQueuedExpressionChatPayload.Create;
              LChatPayload.Kind := rpqecSetSuggestedExpression;
              LChatPayload.Text1 := LExpression;
              LChatPayload.Text2 := LRetryMessage;
              PostExpressionChatPayload(LChatPayload);
              Exit;
            end;

            if LNeedRetry then
          begin
            if Trim(LExplanation) <> '' then
              LRetryMessage := 'Expression fixed after local validation.' +
                sLineBreak + sLineBreak + LExplanation
            else
              LRetryMessage := 'Expression fixed after local validation.';
          end
            else
          begin
            if Trim(LExplanation) <> '' then
              LRetryMessage := LExplanation
            else
              LRetryMessage := 'Expression generated.';
          end;

            LChatPayload := TRpQueuedExpressionChatPayload.Create;
            LChatPayload.Kind := rpqecSetSuggestedExpression;
            LChatPayload.Text1 := LExpression;
            LChatPayload.Text2 := LRetryMessage;
            PostExpressionChatPayload(LChatPayload);
            Break;
          until False;
        except
          on E: Exception do
          begin
            LChatPayload := TRpQueuedExpressionChatPayload.Create;
            LChatPayload.Kind := rpqecAddAssistantMessage;
            LChatPayload.Text1 := E.Message;
            PostExpressionChatPayload(LChatPayload);
          end;
        end;
    finally
      LHttp.Free;
    end;
  end);
 LWorker.FreeOnTerminate := True;
 LWorker.Start;
end;

procedure TFRpExpredialogVCL.SendDesignPrompt(const APrompt,
  AExpression: string);
var
 LPrompt: string;
 LPreprocessRequest: TRpApiPreprocessSqlContextRequest;
 LRequest: TRpApiModifyReportRequest;
 LRequestVersion: Integer;
 LSelectedHubDatabaseId: Int64;
 LSelectedHubSchemaId: Int64;
 LWorker: TThread;
begin
 if FChat = nil then
  Exit;

 LPrompt := Trim(APrompt);
 if LPrompt = '' then
  Exit;

 if FRefreshReport = nil then
 begin
  FChat.AddAssistantMessage('Design mode requires a report instance to serialize and send to the API.');
  Exit;
 end;

 LPreprocessRequest := BuildPreprocessSqlContextRequest;
 LRequest := BuildDesignChatRequest(LPrompt);
 if Trim(LRequest.ReportDocument) = '' then
 begin
  LPreprocessRequest.Free;
  LRequest.Free;
  FChat.AddAssistantMessage('Unable to serialize the current report to XML.');
  Exit;
 end;

 Inc(FDesignRequestVersion);
 LRequestVersion := FDesignRequestVersion;
 LSelectedHubDatabaseId := FChat.GetHubDatabaseId;
 LSelectedHubSchemaId := FChat.GetHubSchemaId;
 FCancelExpressionRequest := False;
 FChat.BeginStreamingResponse;

 LWorker := TThread.CreateAnonymousThread(
   procedure
   var
    LChatPayload: TRpQueuedExpressionChatPayload;
    LHttp: TRpDatabaseHttp;
      LPreprocessResponse: TRpApiPreprocessSqlContextResult;
      LPreprocessUserProfile: TJSONObject;
    LResponse: TRpApiModifyReportResult;
      I: Integer;
   begin
    LHttp := TRpDatabaseHttp.Create;
      LPreprocessResponse := nil;
      LPreprocessUserProfile := nil;
    LResponse := nil;
    try
      try
        LHttp.Token := TRpAuthManager.Instance.Token;
        LHttp.InstallId := TRpAuthManager.Instance.InstallId;
        LHttp.AITier := RpAITierTypeToString(LRequest.AITier);
        LHttp.HubDatabaseId := LSelectedHubDatabaseId;
        LHttp.HubSchemaId := LSelectedHubSchemaId;
        LHttp.AgentSecret := LRequest.AgentSecret;
        if LRequest.HasAgentAiId then
          LHttp.AgentAiId := LRequest.AgentAiId;

        if LPreprocessRequest <> nil then
        begin
          LPreprocessResponse := LHttp.PreprocessSqlContext(LPreprocessRequest, Self,
            DesignStreamProgress, ExpressionStreamCancelRequested);

          if FCancelExpressionRequest then
          begin
            LChatPayload := TRpQueuedExpressionChatPayload.Create;
            LChatPayload.Kind := rpqecGenerationStopped;
            LChatPayload.RequestVersion := LRequestVersion;
            PostExpressionChatPayload(LChatPayload);
            Exit;
          end;

          if (LPreprocessResponse <> nil) and (Trim(LPreprocessResponse.ErrorMessage) <> '') then
            raise Exception.Create(LPreprocessResponse.ErrorMessage);

          TThread.Synchronize(nil,
            procedure
            begin
              ApplyPreprocessSqlContextResult(LPreprocessResponse);
              LRequest.ReportDocument := SaveRefreshReportAsXml;
            end);

          if Trim(LRequest.ReportDocument) = '' then
            raise Exception.Create('Unable to serialize the current report to XML after preprocessing SQL context.');

          if (LPreprocessResponse <> nil) and (Trim(LPreprocessResponse.UserProfileJson) <> '') and
            (not SameText(Trim(LPreprocessResponse.UserProfileJson), 'null')) then
            LPreprocessUserProfile := TJSONObject.ParseJSONValue(LPreprocessResponse.UserProfileJson) as TJSONObject;
        end;

        LResponse := LHttp.ModifyReport(LRequest, Self, DesignStreamProgress,
          ExpressionStreamCancelRequested);

        if FCancelExpressionRequest then
        begin
          LChatPayload := TRpQueuedExpressionChatPayload.Create;
          LChatPayload.Kind := rpqecGenerationStopped;
          LChatPayload.RequestVersion := LRequestVersion;
          PostExpressionChatPayload(LChatPayload);
          Exit;
        end;

        if (LResponse <> nil) and (Trim(LResponse.ErrorMessage) <> '') then
        begin
          LChatPayload := TRpQueuedExpressionChatPayload.Create;
          LChatPayload.Kind := rpqecAddAssistantMessage;
          LChatPayload.RequestVersion := LRequestVersion;
          LChatPayload.Text1 := LResponse.ErrorMessage;
          PostExpressionChatPayload(LChatPayload);
          Exit;
        end;

        if (LResponse <> nil) and (Trim(LResponse.ResultData.ErrorMessage) <> '') then
        begin
          LChatPayload := TRpQueuedExpressionChatPayload.Create;
          LChatPayload.Kind := rpqecAddAssistantMessage;
          LChatPayload.RequestVersion := LRequestVersion;
          LChatPayload.Text1 := LResponse.ResultData.ErrorMessage;
          PostExpressionChatPayload(LChatPayload);
          Exit;
        end;

        LChatPayload := TRpQueuedExpressionChatPayload.Create;
        LChatPayload.Kind := rpqecApplyDesignResult;
        LChatPayload.RequestVersion := LRequestVersion;
        if LPreprocessResponse <> nil then
        begin
          for I := 0 to LPreprocessResponse.Steps.Count - 1 do
          begin
            if LPreprocessResponse.Steps[I] is TRpTokenUsage then
            begin
              Inc(LChatPayload.InputTokens,
                TRpTokenUsage(LPreprocessResponse.Steps[I]).InputTokens);
              Inc(LChatPayload.OutputTokens,
                TRpTokenUsage(LPreprocessResponse.Steps[I]).OutputTokens);
            end;
          end;
        end;
        if LResponse <> nil then
        begin
          LChatPayload.Text1 := LResponse.ResultData.ModifiedReportDocument;
          LChatPayload.Text2 := LResponse.ResultData.Explanation;
          for I := 0 to LResponse.Steps.Count - 1 do
          begin
            if LResponse.Steps[I] is TRpTokenUsage then
            begin
              Inc(LChatPayload.InputTokens,
                TRpTokenUsage(LResponse.Steps[I]).InputTokens);
              Inc(LChatPayload.OutputTokens,
                TRpTokenUsage(LResponse.Steps[I]).OutputTokens);
            end;
          end;
          if (Trim(LResponse.UserProfileJson) <> '') and
            (not SameText(Trim(LResponse.UserProfileJson), 'null')) then
            LChatPayload.UserProfile := TJSONObject.ParseJSONValue(LResponse.UserProfileJson) as TJSONObject;
        end;
        if (LChatPayload.UserProfile = nil) and (LPreprocessUserProfile <> nil) then
        begin
          LChatPayload.UserProfile := LPreprocessUserProfile;
          LPreprocessUserProfile := nil;
        end;
        PostExpressionChatPayload(LChatPayload);
      except
        on E: Exception do
        begin
          LChatPayload := TRpQueuedExpressionChatPayload.Create;
          LChatPayload.Kind := rpqecAddAssistantMessage;
          LChatPayload.RequestVersion := LRequestVersion;
          LChatPayload.Text1 := E.Message;
          PostExpressionChatPayload(LChatPayload);
        end;
      end;
    finally
      LPreprocessUserProfile.Free;
      LPreprocessResponse.Free;
      LResponse.Free;
      LHttp.Free;
      LPreprocessRequest.Free;
      LRequest.Free;
    end;
   end);
 LWorker.FreeOnTerminate := True;
 LWorker.Start;
end;

procedure TFRpExpredialogVCL.ChatApplySuggestion(Sender: TObject;
  const AExpression: string);
begin
 MemoExpre.Text := AExpression;
 MemoExpre.SetFocus;
 MemoExpre.SelStart := Length(MemoExpre.Text);
 MemoExpre.SelLength := 0;
 UpdateExpressionCursorPosition;
end;


function ChangeExpression(formul:string;aval:TRpCustomEvaluator):string;
var
 dia:TFRpExpredialogVCL;
begin
  dia:=GetSharedExpreDialogVCL;
  if not assigned(aval) then
   dia.InitializeDialog(formul,TRpEvaluator.Create(nil),True,False,True)
  else
   dia.InitializeDialog(formul,aval,False,False,True);
  result:=formul;
  dia.showmodal;
  if dia.dook then
   result:=dia.MemoExpre.text;
end;

function ChangeExpressionW(formul:Widestring;aval:TRpCustomEvaluator):Widestring;
var
 dia:TFRpExpredialogVCL;
begin
  dia:=GetSharedExpreDialogVCL;
  if not assigned(aval) then
   dia.InitializeDialog(formul,TRpEvaluator.Create(nil),True,False,True)
  else
   dia.InitializeDialog(formul,aval,False,False,True);
  result:=formul;
  dia.showmodal;
  if dia.dook then
   result:=dia.MemoExpre.text;
end;

function ExpressionCalculateW(formul:Widestring;aval:TRpCustomEvaluator):Variant;
var
 dia:TFRpExpredialogVCL;
begin
  Result:=Null;
  dia:=GetSharedExpreDialogVCL;
  if not assigned(aval) then
   dia.InitializeDialog(formul,TRpEvaluator.Create(nil),True,True,False)
  else
   dia.InitializeDialog(formul,aval,False,True,False);
  result:=dia.AResult;
  dia.showmodal;
  if dia.dook then
   result:=dia.AResult;
end;


function TRpExpreDialogVCL.Execute:Boolean;
var
 dia:TFRpExpredialogVCL;
begin
  dia:=GetSharedExpreDialogVCL;
  if FReport <> nil then
  begin
   dia.InitializeDialog(Expresion.text,TRpEvaluator.Create(nil),True,False,True);
   dia.ConfigureReportRefresh(FReport, FPrintDriver, FRpalias);
  end
  else
  begin
   Fevaluator.Rpalias:=FRpalias;
   dia.InitializeDialog(Expresion.text,Fevaluator,False,False,True);
   dia.ConfigureReportRefresh(nil, nil, nil);
  end;
  dia.ShowModal;
  result:=dia.dook;
  if result then
   Expresion.text:=dia.MemoExpre.text;
end;

procedure TFRpExpredialogVCL.BOKClick(Sender: TObject);
begin
 if validate then
 begin
  evaluator.Expression:=Memoexpre.text;
  try
   evaluator.evaluate;
   AResult:=evaluator.EvalResult;
  except
   on E:Exception do
   begin
    MemoExpre.SetFocus;
    MemoExpre.SelStart:=evaluator.PosError;
    MemoExpre.SelLength:=0;
    Raise Exception.Create(E.MEssage);
   end;
  end;
 end;
 dook:=true;
 Close;
end;

initialization

finalization
 if GSharedExpreDialogVCL<>nil then
  GSharedExpreDialogVCL.Free;

end.
